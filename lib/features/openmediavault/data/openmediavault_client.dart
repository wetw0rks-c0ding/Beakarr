import 'package:dio/dio.dart';

import 'package:seekarr/core/utils/dynamic_map_utils.dart';
import 'package:seekarr/core/utils/url_utils.dart';

class OpenMediaVaultException implements Exception {
  final String message;
  final int? httpStatus;
  final int? code;

  const OpenMediaVaultException({
    required this.message,
    this.httpStatus,
    this.code,
  });

  @override
  String toString() => 'OpenMediaVaultException: $message';
}

class OpenMediaVaultClient {
  static const sessionHeader = 'X-OPENMEDIAVAULT-SESSIONID';
  static const _userAgent = 'Beakarr';

  static const _readOnly = <String>{
    'Session.login',
    'Session.logout',
    'System.getInformation',
    'FileSystemMgmt.getList',
    'FileSystemMgmt.enumerateMountedFilesystems',
    'DiskMgmt.getList',
    'Smart.getList',
    'Smart.getInformation',
    'Services.getStatus',
  };

  final String baseUrl;
  final String username;
  final String password;

  late final Dio _dio;

  String? _sessionId;
  bool _authenticated = false;
  Map<String, dynamic>? _permissions;
  Future<bool>? _loginInFlight;

  OpenMediaVaultClient({
    required String url,
    required this.username,
    required this.password,
    Dio? dio,
  }) : baseUrl = UrlUtils.normalizeBaseUrl(url) {
    _dio =
        dio ??
        Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 10),
          ),
        );
    // Applied to the owned client AND any injected one (tests): the
    // session stays bound to this UA server-side, so it must not vary.
    _dio.options.headers['User-Agent'] = _userAgent;
    _dio.options.headers['Content-Type'] = 'application/json';
    _dio.options.contentType = 'application/json';

    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final alreadyRetried =
              error.requestOptions.extra['skipAuthRetry'] == true;
          if (status != 401 || alreadyRetried) {
            handler.next(error);
            return;
          }
          _sessionId = null;
          _authenticated = false;
          try {
            await login();
          } catch (_) {
            handler.next(error);
            return;
          }
          error.requestOptions.extra['skipAuthRetry'] = true;
          if (_sessionId != null) {
            error.requestOptions.headers[sessionHeader] = _sessionId;
          }
          try {
            final response = await _dio.fetch<dynamic>(error.requestOptions);
            handler.resolve(response);
          } catch (_) {
            handler.next(error);
          }
        },
      ),
    );
  }

  bool get isAuthenticated => _authenticated;
  String? get sessionId => _sessionId;
  Map<String, dynamic>? get permissions => _permissions;

  Future<bool> login() {
    final inflight = _loginInFlight;
    if (inflight != null) return inflight;
    return _guardedLogin();
  }

  Future<bool> _guardedLogin() async {
    final future = _doLogin();
    _loginInFlight = future;
    try {
      return await future;
    } finally {
      _loginInFlight = null;
    }
  }

  Future<bool> _doLogin() async {
    try {
      final response = await _dio.post<dynamic>(
        '/rpc.php',
        data: <String, dynamic>{
          'service': 'Session',
          'method': 'login',
          'params': <String, dynamic>{
            'username': username,
            'password': password,
          },
        },
        options: Options(extra: const {'skipAuthRetry': true}),
      );
      return _handleLoginResponse(response.data, response.statusCode);
    } on DioException catch (e) {
      final parsed = _extractError(e.response?.data);
      if (parsed != null) {
        throw OpenMediaVaultException(
          message: parsed.$1,
          httpStatus: e.response?.statusCode,
          code: parsed.$2,
        );
      }
      rethrow;
    }
  }

  bool _handleLoginResponse(dynamic data, int? statusCode) {
    final map = mapOrNull(data) ?? const <String, dynamic>{};
    final err = _extractError(map);
    if (err != null) {
      throw OpenMediaVaultException(
        message: err.$1,
        httpStatus: statusCode,
        code: err.$2,
      );
    }
    final resp = mapOrNull(map['response']) ?? const <String, dynamic>{};
    _authenticated = resp['authenticated'] == true;
    _permissions = mapOrNull(resp['permissions']);
    final sid = resp['sessionid']?.toString() ?? '';
    if (sid.isNotEmpty) {
      _sessionId = sid;
    }
    return _authenticated;
  }

  (String, int?)? _extractError(dynamic data) {
    final map = mapOrNull(data);
    if (map == null) return null;
    final err = map['error'];
    if (err == null) return null;
    final em = mapOrNull(err);
    final message = em != null
        ? (em['message']?.toString() ?? err.toString())
        : err.toString();
    final code = em != null ? intOrNull(em['code']) : null;
    return (message, code);
  }

  Future<dynamic> rpc(String service, String method,
      [Map<String, dynamic>? params]) async {
    final key = '$service.$method';
    if (!_readOnly.contains(key)) {
      throw StateError(
        'OpenMediaVault RPC "$key" is not in the read-only allowlist',
      );
    }
    if (!_authenticated) {
      await login();
    }

    final payload = <String, dynamic>{
      'service': service,
      'method': method,
      'params': params ?? const <String, dynamic>{},
    };

    try {
      final response = await _dio.post<dynamic>(
        '/rpc.php',
        data: payload,
        options: Options(
          headers: _sessionId != null
              ? <String, dynamic>{sessionHeader: _sessionId}
              : null,
          extra: const {'skipAuthRetry': false},
        ),
      );
      final map = mapOrNull(response.data) ?? const <String, dynamic>{};
      final parsed = _extractError(map);
      if (parsed != null) {
        throw OpenMediaVaultException(
          message: parsed.$1,
          httpStatus: response.statusCode,
          code: parsed.$2,
        );
      }
      return map['response'];
    } on DioException catch (e) {
      final parsed = _extractError(e.response?.data);
      if (parsed != null) {
        throw OpenMediaVaultException(
          message: parsed.$1,
          httpStatus: e.response?.statusCode,
          code: parsed.$2,
        );
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    if (!_authenticated) return;
    try {
      await rpc('Session', 'logout', const <String, dynamic>{});
    } catch (_) {
      // best-effort
    }
  }

  void close({bool logout = false}) {
    if (logout) {
      // Best-effort; do not await (dio closes immediately after).
      // ignore: unawaited_futures
      this.logout();
    }
    _dio.close(force: true);
  }
}