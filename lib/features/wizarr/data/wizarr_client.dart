import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:seekarr/core/utils/dynamic_map_utils.dart';
import 'package:seekarr/core/utils/url_utils.dart';

class WizarrException implements Exception {
  final String message;
  final int? httpStatus;
  final int? code;

  const WizarrException({required this.message, this.httpStatus, this.code});

  @override
  String toString() => 'WizarrException: $message';
}

class WizarrClient {
  static const _userAgent = 'Beakarr';

  static const _readOnly = <String>{
    'Invitation.getAll',
    'Invitations.getAll',
    'Invitation.list',
    'Invitations.list',
    'User.getAll',
    'Users.getAll',
    'User.list',
    'Users.list',
    'Server.getAll',
    'Servers.getAll',
    'Server.list',
    'Servers.list',
    'Library.getAll',
    'Libraries.getAll',
    'Library.list',
    'Libraries.list',
  };

  // Sole v1 mutation exception — see spec Phase 2 (POST /api/invitations).
  static const _createOnly = <String>{
    'Invitation.create',
  };

  final String baseUrl;
  final String apiKey;

  late final Dio _dio;

  WizarrClient({required String url, required String apiKey, Dio? dio})
    : baseUrl = UrlUtils.normalizeBaseUrl(url),
      apiKey = apiKey.trim() {
    _dio =
        dio ??
        Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            headers: const {'Accept': 'application/json'},
          ),
        );
    _dio.options.headers['User-Agent'] = _userAgent;
    if (dio == null) {
      _dio.options.headers['X-API-Key'] = this.apiKey;
    }
  }

  String? _pathForKey(String key) {
    final lower = key.toLowerCase();
    // Exact path mappings for servers and libraries endpoints (incl. plural/list aliases)
    if (key == 'Server.getAll' ||
        key == 'Servers.getAll' ||
        key == 'Server.list' ||
        key == 'Servers.list') {
      return '/api/servers';
    }
    if (key == 'Library.getAll' ||
        key == 'Libraries.getAll' ||
        key == 'Library.list' ||
        key == 'Libraries.list') {
      return '/api/libraries';
    }
    // Invitation paths: create uses exact path, getAll uses generic fallback
    if (lower.contains('invitation.create')) return '/api/invitations';
    if (lower.contains('invitation.getall')) return '/api/invitations';
    if (lower.contains('invitation.list')) return '/api/invitations';
    // User paths: same pattern
    if (lower.contains('user.getall')) return '/api/users';
    if (lower.contains('user.list')) return '/api/users';
    return null;
  }

  Future<dynamic> rpc(
    String service,
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    final key = '$service.$method';
    // rpc() is for read-only operations via GET. Mutations must use post().
    if (!_readOnly.contains(key)) {
      throw StateError('Wizarr RPC "$key" is not in the read-only allowlist');
    }
    return _rpcGet(service, method, params);
  }

  /// POST endpoint for mutation operations (createInvitation, etc.)
  /// Only allowed methods are listed in [_createOnly].
  Future<dynamic> post(
    String service,
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    final key = '$service.$method';
    if (!_createOnly.contains(key)) {
      throw StateError('Wizarr RPC "$key" is not in the POST allowlist');
    }
    // Exact literal path — never via the fuzzy _pathForKey (GET-only).
    const path = '/api/invitations';
    try {
      final payload = Map<String, dynamic>.from({
        if (params != null && params.isNotEmpty) ...params,
      });
      final response = await _dio.post<dynamic>(
        path,
        data: payload.isEmpty ? null : payload,
        options: Options(
          headers: {'X-API-Key': apiKey},
          responseType: ResponseType.plain,
        ),
      );
      final status = response.statusCode ?? 500;
      
      // Handle 4xx/5xx errors with JSON or HTML bodies
      if (status >= 400) {
        final parsed = _extractError(response.data);
        final message =
            parsed?.$1 ?? ('Request failed');
        throw WizarrException(
          message: message,
          httpStatus: status,
          code: parsed?.$2,
        );
      }
      
      // Handle 200 OK with non-JSON bodies (likely HTML error pages)
      final decoded = _decode(response.data);
      if (decoded is String && decoded.contains('<html')) {
        throw WizarrException(
          message: 'Unexpected HTML response on success',
          httpStatus: status,
        );
      }
      
      return decoded;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 500;
      final respData = e.response?.data;
      final parsed = _extractError(respData);
      
      // For mock tests where status is 2xx but we still got a DioException,
      // extract error from the response if available
      if (status < 400 && e.response != null) {
        final respParsed = _extractError(respData);
        final respMessage = respParsed?.$1 ?? 'Request failed';
        throw WizarrException(
          message: respMessage,
          httpStatus: status,
          code: respParsed?.$2,
        );
      }
      
      final message =
          parsed?.$1 ?? (status == 401 ? 'Unauthorized' : 'Request failed');
      throw WizarrException(
        message: message,
        httpStatus: status,
        code: parsed?.$2,
      );
    }
  }

  Future<dynamic> _rpcGet(
    String service,
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    final key = '$service.$method';
    if (!_readOnly.contains(key)) {
      throw StateError('Wizarr RPC "$key" is not in the read-only allowlist');
    }
    final path = _pathForKey(key) ?? '/api/$method';
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: params,
        options: Options(
          headers: {'X-API-Key': apiKey},
          responseType: ResponseType.plain,
        ),
      );
      final status = response.statusCode ?? 500;
      
      // Handle 4xx/5xx errors with JSON or HTML bodies
      if (status >= 400) {
        final parsed = _extractError(response.data);
        final message =
            parsed?.$1 ?? ('Request failed');
        throw WizarrException(
          message: message,
          httpStatus: status,
          code: parsed?.$2,
        );
      }
      
      // Handle 200 OK with non-JSON bodies (likely HTML error pages)
      final decoded = _decode(response.data);
      if (decoded is String && decoded.contains('<html')) {
        throw WizarrException(
          message: 'Unexpected HTML response on success',
          httpStatus: status,
        );
      }
      
      return decoded;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 500;
      final respData = e.response?.data;
      final parsed = _extractError(respData);
      
      // For mock tests where status is 2xx but we still got a DioException,
      // extract error from the response if available
      if (status < 400 && e.response != null) {
        final respParsed = _extractError(respData);
        final respMessage = respParsed?.$1 ?? 'Request failed';
        throw WizarrException(
          message: respMessage,
          httpStatus: status,
          code: respParsed?.$2,
        );
      }
      
      final message =
          parsed?.$1 ?? (status == 401 ? 'Unauthorized' : 'Request failed');
      throw WizarrException(
        message: message,
        httpStatus: status,
        code: parsed?.$2,
      );
    }
  }

  // Aliases for callers that prefer a different verb.
  Future<dynamic> call(
    String service,
    String method, [
    Map<String, dynamic>? params,
  ]) => rpc(service, method, params);
  Future<dynamic> request(
    String service,
    String method, [
    Map<String, dynamic>? params,
  ]) => rpc(service, method, params);
  Future<dynamic> invoke(
    String service,
    String method, [
    Map<String, dynamic>? params,
  ]) => rpc(service, method, params);

  dynamic _decode(dynamic data) {
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) return data;
      try {
        return jsonDecode(trimmed);
      } catch (_) {
        return data;
      }
    }
    return data;
  }

  (String, int?)? _extractError(dynamic data) {
    dynamic decoded = data;
    if (decoded is String) {
      try {
        decoded = jsonDecode(decoded);
      } catch (_) {
        // leave as string
      }
    }
    final map = mapOrNull(decoded);
    if (map == null) return null;
    final err = map['error'];
    if (err != null) {
      final em = mapOrNull(err);
      final message = em != null
          ? (em['message']?.toString() ?? err.toString())
          : err.toString();
      final text = message.trim();
      if (text.isNotEmpty) {
        final code = em != null
            ? intOrNull(em['code'])
            : intOrNull(map['code']);
        return (text, code);
      }
    }
    final message = map['message'] ?? map['detail'] ?? map['msg'];
    if (message != null) {
      final text = message.toString().trim();
      if (text.isNotEmpty) {
        return (text, intOrNull(map['code']));
      }
    }
    return null;
  }

  void close({bool force = false}) {
    _dio.close(force: force);
  }
}
