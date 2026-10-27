import 'package:dio/dio.dart';

import 'service_auth.dart';

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
    // TEMP-DIAG: temporary redacted HTTP logging for live session (revert after).
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (Object? o) {
          final raw = o?.toString() ?? '';
          final redacted = raw.split('\n').map((line) {
            var out = line.replaceAllMapped(
              RegExp(
                r'^(.*?(?:x-api-key|authorization)\s*:\s*).+$',
                caseSensitive: false,
              ),
              (m) => '${m.group(1)}***',
            );
            if (out.length > 500) {
              out = out.substring(0, 500);
            }
            return out;
          }).join('\n');
          // ignore: avoid_print
          print(redacted);
        },
      ),
    );
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

  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.patch(
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
