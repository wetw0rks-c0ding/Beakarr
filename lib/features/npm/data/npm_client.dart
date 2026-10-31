import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:seekarr/core/utils/dynamic_map_utils.dart';
import 'package:seekarr/core/utils/url_utils.dart';

/// Raised when Nginx Proxy Manager rejects the credentials (HTTP 401).
class NpmAuthException implements Exception {
  final String message;

  const NpmAuthException(this.message);

  @override
  String toString() => 'NpmAuthException: $message';
}

/// Raised when the account requires a TOTP code, which v1 does not implement.
///
/// A `requires_2fa` response is a hard stop: the token exchange cannot be
/// completed without `POST /api/tokens/2fa`.
class NpmTwoFactorRequiredException implements Exception {
  static const String defaultMessage =
      'This account has 2FA enabled — API token auth is not supported';

  final String message;

  const NpmTwoFactorRequiredException([this.message = defaultMessage]);

  @override
  String toString() => 'NpmTwoFactorRequiredException: $message';
}

/// Transport for Nginx Proxy Manager's `/api/tokens` + `/api/nginx/*` REST API.
///
/// Owns the credential→token handshake, the in-memory token cache, expiry
/// tracking and the one-shot 401 re-login. Deliberately standalone (not
/// `ApiClient`) so the token-exchange body never passes through a request-body
/// logger, and **no `LogInterceptor` is installed here** — `identity`,
/// `secret` and the bearer token must never reach the console.
class NpmClient {
  static const Duration _requestTimeout = Duration(seconds: 15);

  /// Trust a server-provided expiry only with this much headroom.
  static const Duration _expirySafetyMargin = Duration(seconds: 60);

  /// Used when neither `expires` nor a JWT `exp` claim is available.
  static const Duration _fallbackLifetime = Duration(minutes: 30);

  final String baseUrl;
  final String identity;
  final String password;
  late final Dio _dio;

  String? _token;
  DateTime? _expires;
  Future<void>? _loginInFlight;

  NpmClient({
    required String url,
    required String identity,
    required String password,
    Dio? dio,
  }) : baseUrl = UrlUtils.normalizeBaseUrl(url),
       identity = identity.trim(),
       password = password {
    _dio =
        dio ??
        Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 10),
            headers: const {'Accept': 'application/json'},
          ),
        );
    _dio.interceptors.add(InterceptorsWrapper(onError: _onError));
  }

  bool get hasCredentials => identity.isNotEmpty && password.isNotEmpty;

  /// True while the cached token exists and is not within the safety margin
  /// of its expiry.
  bool get isTokenFresh {
    final token = _token;
    final expires = _expires;
    if (token == null || token.isEmpty || expires == null) return false;
    return DateTime.now().isBefore(expires.subtract(_expirySafetyMargin));
  }

  /// Logs in unless a usable token is already cached.
  ///
  /// Concurrent callers share one login: the first sets [_loginInFlight] and
  /// the rest await the same future.
  Future<void> ensureAuthenticated() async {
    if (isTokenFresh) return;
    final inflight = _loginInFlight;
    if (inflight != null) return inflight;
    final future = login();
    _loginInFlight = future;
    try {
      await future;
    } finally {
      _loginInFlight = null;
    }
  }

  /// `POST /api/tokens` → bearer token + expiry.
  ///
  /// I/O and parse failures clear the cache so the next call retries instead
  /// of reusing a half-initialised session.
  Future<void> login() async {
    if (!hasCredentials) {
      throw const NpmAuthException('Missing credentials');
    }
    final Response<dynamic> response;
    try {
      response = await _dio
          .post<dynamic>(
            '/api/tokens',
            data: {'identity': identity, 'secret': password},
            options: Options(extra: const {'skipAuthRetry': true}),
          )
          .timeout(_requestTimeout);
    } on DioException catch (e) {
      _clearToken();
      if (e.response?.statusCode == 401) {
        throw const NpmAuthException('HTTP 401');
      }
      rethrow;
    }

    final data = mapOrNull(response.data) ?? const <String, dynamic>{};
    if (data['requires_2fa'] == true) {
      _clearToken();
      throw const NpmTwoFactorRequiredException();
    }

    final token = stringOrNull(data['token']);
    if (token == null) {
      _clearToken();
      throw const NpmAuthException('Token response did not include a token');
    }

    _token = token;
    _expires =
        _parseExpires(data['expires']) ??
        _jwtExpiry(token) ??
        DateTime.now().add(_fallbackLifetime);
  }

  /// Bearer-authenticated GET. Authenticates first, then retries once on 401
  /// via the interceptor installed in the constructor.
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    await ensureAuthenticated();
    return _dio
        .get<T>(
          path,
          queryParameters: query,
          cancelToken: cancelToken,
          options: Options(headers: {'Authorization': 'Bearer $_token'}),
        )
        .timeout(_requestTimeout);
  }

  void close({bool force = false}) {
    _dio.close(force: force);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final isAuthFailure = error.response?.statusCode == 401;
    final alreadyRetried = error.requestOptions.extra['skipAuthRetry'] == true;
    if (!isAuthFailure || alreadyRetried || !hasCredentials) {
      handler.next(error);
      return;
    }

    // Force a fresh login: the cached token is what the server just rejected.
    _clearToken();
    try {
      await ensureAuthenticated();
    } catch (_) {
      handler.next(error);
      return;
    }

    final options = error.requestOptions;
    options.extra['skipAuthRetry'] = true;
    final token = _token;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } catch (_) {
      // A second 401 (or a transport failure) propagates as the original
      // error — the interceptor never loops.
      handler.next(error);
    }
  }

  void _clearToken() {
    _token = null;
    _expires = null;
  }

  static DateTime? _parseExpires(dynamic value) {
    final text = stringOrNull(value);
    if (text == null) return null;
    return DateTime.tryParse(text);
  }

  /// Decodes the payload segment's `exp` claim (seconds since epoch).
  ///
  /// The signature is deliberately not verified — we are the client, not the
  /// issuer.
  static DateTime? _jwtExpiry(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = mapOrNull(payload)?['exp'];
      final seconds = exp is num
          ? exp.toInt()
          : int.tryParse(exp?.toString() ?? '');
      if (seconds == null || seconds <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    } catch (_) {
      return null;
    }
  }
}
