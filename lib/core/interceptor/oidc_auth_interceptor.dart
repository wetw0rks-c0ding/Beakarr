import 'package:dio/dio.dart';
import 'package:seekarr/features/auth/data/oidc_session_service.dart';

final Map<String, bool> bearerCapableServices = {
  'seerr': true,
  'radarr': true,
  'sonarr': true,
  'lidarr': true,
  'prowlarr': true,
  'bazarr': true,
  'qbittorrent': false,
};

class OidcAuthInterceptor extends Interceptor {
  final OidcSessionService _session;
  final String _clientId;
  final String _issuerUrl;
  final String? serviceKey;
  Future<bool>? _refreshFuture;

  OidcAuthInterceptor(this._session, {required String issuerUrl, required String clientId, this.serviceKey})
      : _clientId = clientId,
        _issuerUrl = issuerUrl;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final serviceKey = this.serviceKey ?? _inferServiceFromPath(options.path);
    final allowBearer = bearerCapableServices[serviceKey] ?? false;
    if (allowBearer && _issuerUrl.isNotEmpty) {
      final token = await _session.accessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    if (status == 401) {
      final svcKey = this.serviceKey ?? _inferServiceFromPath(err.requestOptions.path);
      final allowBearer = bearerCapableServices[svcKey] ?? false;
      final carriedBearer = (err.requestOptions.headers['Authorization'] as String?)?.startsWith('Bearer ') ?? false;
      if (!allowBearer || !carriedBearer) {
        handler.next(err);
        return;
      }
      try {
        if (_refreshFuture == null) {
          _refreshFuture = _doRefresh();
        }
        final ok = await _refreshFuture!;
        if (ok) {
          final opts = err.requestOptions;
          final newToken = await _session.accessToken();
          if (newToken != null && newToken.isNotEmpty) {
            opts.headers['Authorization'] = 'Bearer $newToken';
          }
          try {
            final retry = await Dio().fetch(opts);
            handler.resolve(retry);
            return;
          } catch (_) {
            // fall through to rethrow
          }
        }
      } finally {
        _refreshFuture = null;
      }
    }
    handler.next(err);
  }

  Future<bool> _doRefresh() async {
    return await _session.refresh(_issuerUrl, _clientId);
  }

  String _inferServiceFromPath(String path) => serviceKey ?? 'unknown';
}
