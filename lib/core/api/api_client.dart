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
        );

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
