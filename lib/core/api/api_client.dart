import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'service_auth.dart';

/// Debug-only HTTP trace with secrets redacted. Active in debug builds so
/// on-device diagnosis (adb logcat) shows exact status codes and failures
/// without leaking API keys. Silent in release/profile builds.
class _RedactedLogInterceptor extends Interceptor {
  void _log(String message) => debugPrint('[http] $message');

  Map<String, dynamic> _safeHeaders(Map<String, dynamic> headers) {
    final copy = Map<String, dynamic>.of(headers);
    for (final key in copy.keys.toList()) {
      final lower = key.toString().toLowerCase();
      if (lower.contains('api-key') ||
          lower == 'authorization' ||
          lower.contains('token')) {
        copy[key] = '***';
      }
    }
    return copy;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _log('--> ${options.method} ${options.uri}');
    _log('    headers=${_safeHeaders(options.headers)}');
    if (options.queryParameters.isNotEmpty) {
      _log('    query=${options.queryParameters}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final data = response.data;
    final preview = data == null
        ? 'null'
        : data is String && data.length > 200
            ? '${data.substring(0, 200)}…'
            : data.runtimeType.toString();
    _log('<-- ${response.statusCode} ${response.requestOptions.uri} ($preview)');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log(
      '<!! ${err.type} ${err.message ?? ''} uri=${err.requestOptions.uri} '
      'status=${err.response?.statusCode}',
    );
    handler.next(err);
  }
}

class ApiClient {
  final Dio _dio;
  final ServiceAuth auth;

  ApiClient({
    required String baseUrl,
    required this.auth,
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            headers: {
              ...auth.headers(),
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ) {
    if (kDebugMode) {
      _dio.interceptors.add(_RedactedLogInterceptor());
    }
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) {
    return _dio.get(
      path,
      queryParameters: {...auth.queryParams(), ...queryParameters ?? {}},
      cancelToken: cancelToken,
    );
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) {
    return _dio.post(
      path,
      data: data,
      queryParameters: {...auth.queryParams(), ...queryParameters ?? {}},
      cancelToken: cancelToken,
    );
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.put(
      path,
      data: data,
      queryParameters: {...auth.queryParams(), ...queryParameters ?? {}},
    );
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.delete(
      path,
      data: data,
      queryParameters: {...auth.queryParams(), ...queryParameters ?? {}},
    );
  }

  void close({bool force = false}) {
    _dio.close(force: force);
  }
}
