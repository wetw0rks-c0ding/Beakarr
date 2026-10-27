import 'package:dio/dio.dart';
import 'package:seekarr/features/auth/data/oidc_session_service.dart';

/// Per-service Bearer map: when issuer configured, all Bearer-capable
/// services get Authorization header; API key retained as fallback when
/// no active OIDC session.
final Map<String, bool> bearerCapableServices = {
  'seerr': true,
  'radarr': true,
  'sonarr': true,
  'lidarr': true,
  'prowlarr': true,
  'bazarr': true,
  'qbittorrent': false, // username/password auth, not Bearer
};

class OidcAuthInterceptor extends Interceptor {
  final OidcSessionService _session;
  final String _clientId;
  final String _issuerUrl;
  final String? serviceKey; // e.g. 'seerr', 'radarr' — set by ApiClient
  bool _refreshing = false;

  OidcAuthInterceptor(this._session, {required String issuerUrl, required String clientId, this.serviceKey})
      : _clientId = clientId,
        _issuerUrl = issuerUrl;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Only inject Bearer when session active AND per-service map allows.
    final serviceKey = this.serviceKey ?? _inferServiceFromPath(options.path);
    final allowBearer = bearerCapableServices[serviceKey] ?? false;
    if (allowBearer && _issuerUrl.isNotEmpty) {
      final token = await _session.accessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    // If no session / no bearer: existing ApiClient auth headers remain (API key etc).
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_refreshing) {
      _refreshing = true;
      final ok = await _session.refresh(_issuerUrl, _clientId);
      _refreshing = false;
      if (ok) {
        // Retry once with refreshed token.
        final opts = err.requestOptions;
        final newToken = await _session.accessToken();
        if (newToken != null) opts.headers['Authorization'] = 'Bearer $newToken';
        try {
          final retry = await Dio().fetch(opts);
          handler.resolve(retry);
          return;
        } catch (_) {
          // fall through to rethrow
        }
      }
    }
    handler.next(err); // rethrow if refresh failed / second failure
  }

  String _inferServiceFromPath(String path) => serviceKey ?? 'unknown';
}
