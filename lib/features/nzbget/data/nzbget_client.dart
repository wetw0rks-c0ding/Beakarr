import 'package:dio/dio.dart';

import 'package:seekarr/core/api/api_client.dart';
import 'package:seekarr/core/api/service_auth.dart';
import 'package:seekarr/core/utils/dynamic_map_utils.dart';
import 'package:seekarr/core/utils/url_utils.dart';

/// Raised when NZBGet answers an RPC call with an `error` object.
///
/// [code] is the JSON-RPC / NZBGet error code (e.g. `-32602` for a params
/// arity mismatch) and [message] is the server's text, safe to show verbatim.
class NzbgetRpcException implements Exception {
  final int code;
  final String message;

  const NzbgetRpcException(this.code, this.message);

  @override
  String toString() => 'NzbgetRpcException: RPC $code: $message';
}

/// Raised when NZBGet rejects the HTTP Basic credentials (HTTP 401).
class NzbgetAuthException implements Exception {
  final String message;

  const NzbgetAuthException(this.message);

  @override
  String toString() => 'NzbgetAuthException: $message';
}

/// JSON-RPC transport for NZBGet's `POST /jsonrpc` endpoint.
///
/// Owns the envelope only — no endpoint knowledge. Auth is stateless HTTP
/// Basic (NZBGet has no login call and no cookie), so every request carries the
/// credential and there is no session state to invalidate.
class NzbgetClient {
  static const Duration _timeout = Duration(seconds: 10);

  final ApiClient _api;
  final String baseUrl;

  int _nextId = 1;

  NzbgetClient({
    required String url,
    required String username,
    required String password,
    ApiClient? apiClient,
  }) : baseUrl = UrlUtils.normalizeBaseUrl(url),
       _api =
           apiClient ??
           ApiClient(
             baseUrl: UrlUtils.normalizeBaseUrl(url),
             auth: BasicAuth(username, password),
           );

  /// Invokes [method] with positional [params] and returns the unwrapped
  /// `result` value.
  ///
  /// NZBGet requires every documented parameter to be present — never trim
  /// [params] to "default" a trailing argument.
  Future<dynamic> call(String method, [List<dynamic> params = const []]) async {
    final id = _nextId++;
    final Response<dynamic> response;
    try {
      response = await _api
          .post(
            '/jsonrpc',
            data: {
              'version': '1.1',
              'id': id,
              'method': method,
              'params': params,
            },
          )
          .timeout(_timeout);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const NzbgetAuthException('HTTP 401');
      }
      rethrow;
    }

    final root = mapOrNull(response.data);
    if (root == null) return null;

    final error = mapOrNull(root['error']);
    if (error != null) {
      throw NzbgetRpcException(
        intOrNull(error['code']) ?? 0,
        stringOrNull(error['message']) ?? 'Unknown error',
      );
    }
    return root['result'];
  }

  /// Server version without the leading `v` (e.g. `24.3`).
  Future<String> getVersion() async {
    final result = await call('version');
    return result?.toString().trim() ?? '';
  }

  void close({bool force = false}) {
    _api.close(force: force);
  }
}
