import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:seekarr/core/utils/dynamic_map_utils.dart';
import 'package:seekarr/core/utils/url_utils.dart';

class WizarrException implements Exception {
  final String message;
  final int? httpStatus;
  final int? code;

  const WizarrException({
    required this.message,
    this.httpStatus,
    this.code,
  });

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
  };

  final String baseUrl;
  final String apiKey;

  late final Dio _dio;
  final String _apiKey;

  WizarrClient({
    required String url,
    required String apiKey,
    Dio? dio,
  })  : baseUrl = UrlUtils.normalizeBaseUrl(url),
        apiKey = apiKey.trim(),
        _apiKey = apiKey.trim() {
    _dio = dio ??
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
      _dio.options.headers['X-API-Key'] = _apiKey;
    }
  }

  String? _pathForKey(String key) {
    final lower = key.toLowerCase();
    if (lower.contains('invitation')) return '/api/invitations';
    if (lower.contains('user')) return '/api/users';
    return null;
  }

  Future<dynamic> rpc(String service, String method,
      [Map<String, dynamic>? params]) async {
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
          headers: {'X-API-Key': _apiKey},
          responseType: ResponseType.plain,
        ),
      );
      return _decode(response.data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final parsed = _extractError(e.response?.data);
      final message = parsed ?? (status == 401 ? 'Unauthorized' : 'Request failed');
      throw WizarrException(
        message: message,
        httpStatus: status,
        code: null,
      );
    }
  }

  // Aliases for callers that prefer a different verb.
  Future<dynamic> call(String service, String method,
          [Map<String, dynamic>? params]) =>
      rpc(service, method, params);
  Future<dynamic> request(String service, String method,
          [Map<String, dynamic>? params]) =>
      rpc(service, method, params);
  Future<dynamic> invoke(String service, String method,
          [Map<String, dynamic>? params]) =>
      rpc(service, method, params);

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
        options: Options(
          headers: {'X-API-Key': _apiKey},
          responseType: ResponseType.plain,
        ),
      );
      response.data = _decode(response.data);
      return response;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final parsed = _extractError(e.response?.data);
      final message = parsed ?? (status == 401 ? 'Unauthorized' : 'Request failed');
      throw WizarrException(
        message: message,
        httpStatus: status,
        code: null,
      );
    }
  }

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

  String? _extractError(dynamic data) {
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
    if (err is String && err.trim().isNotEmpty) return err.trim();
    final message = map['message'] ?? map['detail'] ?? map['msg'];
    if (message != null) {
      final text = message.toString().trim();
      if (text.isNotEmpty) return text;
    }
    if (err != null) {
      final text = err.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  void close({bool force = false}) {
    _dio.close(force: force);
  }
}
