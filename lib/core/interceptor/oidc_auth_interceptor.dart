import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:seekarr/features/auth/data/oidc_session_service.dart';
import 'package:seekarr/features/auth/data/sonarr_oidc_session_provider.dart';
import 'package:flutter/foundation.dart';

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
  final String? baseUrl;

  OidcAuthInterceptor(this._session, {required String issuerUrl, required String clientId, this.serviceKey, this.baseUrl})
      : _clientId = clientId,
        _issuerUrl = issuerUrl;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final svc = serviceKey ?? 'unknown';
    final allowBearer = bearerCapableServices[svc] ?? false;
    if (allowBearer && _issuerUrl.isNotEmpty && baseUrl != null && baseUrl!.isNotEmpty && _oidcService) {
      // Origin-scoped: a foreign absolute URL through this client never
      // receives the Sonarr service token (matches the onError guard).
      if (!_isServiceOrigin(options.uri)) {
        handler.next(options);
        return;
      }
      final session = SonarrOidcSessionProvider.getSonarrSession(_host);
      if (session != null && !session.isExpired()) {
        options.headers['Authorization'] = 'Bearer ${session.serviceToken}';
      }
    } else if (allowBearer && _issuerUrl.isNotEmpty && !_oidcService) {
      // Slice-1 raw Authentik Bearer for non-pilot services only. Pilot
      // services (Sonarr, ArrStack Radarr) authenticate via exchanged
      // service tokens — never the raw Authentik pair.
      final token = await _session.accessToken;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  // Slice-1 Seekarr-UI refresh helper. Unused by the Sonarr pilot (which
  // uses [_doSonarrRefresh]), retained for the remaining slice-1 Bearer
  // services until they migrate to per-service pairs.
  // ignore: unused_element
  Future<RefreshOutcome> _doRefresh() =>
      _session.refresh(_issuerUrl, _clientId);

  /// Per-service Authentik identity (Sonarr pilot; Radarr shares this path
  /// in ArrStack mode): the exchange `subject_token` must be minted by the
  /// expected provider. The Seekarr-UI pair (`aud=seekarr`) is never sent
  /// to *arr hosts — in ArrStack mode the shared pair is the base pair.
  String get _sonarrIssuer =>
      OidcSessionService.perServiceIssuer(_issuerUrl, 'sonarr');
  String get _sonarrClientId =>
      OidcSessionService.perServiceClientId('sonarr', _issuerUrl);

  /// Services whose requests may carry/exchange OIDC tokens. Sonarr always
  /// (pilot: owns a per-provider identity); Radarr only in ArrStack mode,
  /// where the shared pair is valid fleet-wide. Other services keep the
  /// API-key path until their forks land.
  bool get _oidcService =>
      serviceKey == 'sonarr' ||
      (serviceKey == 'radarr' && _useBasePair);

  /// ArrStack single-tile mode: the fleet shares the main pair minted by
  /// the main login. Per-service keys stay for the legacy per-provider
  /// layout; in ArrStack mode they are neither read nor written here.
  bool get _useBasePair => OidcSessionService.isArrstackMode(_issuerUrl);
  Future<RefreshOutcome> _doSonarrRefresh() => _useBasePair
      ? _session.refresh(_issuerUrl, _clientId)
      : _session.refreshFor('sonarr', _sonarrIssuer, _sonarrClientId);
  Future<String?> _sonarrAuthToken() =>
      _useBasePair ? _session.accessToken : _session.accessTokenFor('sonarr');
  Future<void> _clearSonarrAuth() =>
      _useBasePair ? _session.clear() : _session.clearFor('sonarr');

  /// Service-side rejection (fork 401/403 on a live identity): drop only
  /// the cached Sonarr service token, never the shared identity — one
  /// service's refusal must not log the fleet out. Refresh-dead paths
  /// keep using [_clearSonarrAuth].
  /// Verified safe in ArrStack mode: the live identity lives in the base
  /// pair ([_useBasePair]), which `clearFor` never touches — per-service
  /// keys are neither read nor written on that path (see [_sonarrAuthToken],
  /// [_hasSonarrIdentity], and the hidden Sonarr login row).
  Future<void> _clearSonarrServiceOnly() =>
      _session.clearFor('sonarr');

  /// Mint a fresh service token with the live identity, or null when no
  /// identity exists or the exchange is refused. Never clears anything.
  Future<String?> _freshServiceToken(String urlBase) async {
    final auth = await _sonarrAuthToken();
    if (auth == null || auth.isEmpty) return null;
    if (!await _postExchange(urlBase, auth)) return null;
    final s = SonarrOidcSessionProvider.getSonarrSession(urlBase);
    if (s != null && s.isExpired()) return null;
    return s?.serviceToken;
  }

  /// Whether any Authentik identity material exists (access or refresh).
  /// Virgin state (never logged in) must keep the plain API-key error path.
  Future<bool> _hasSonarrIdentity() async {
    final a = await _sonarrAuthToken();
    if (a != null && a.isNotEmpty) return true;
    final r = _useBasePair
        ? await _session.refreshToken
        : await _session.refreshTokenFor('sonarr');
    return r != null && r.isNotEmpty;
  }

  Future<bool> _postExchange(String urlBase, String authToken) async {
    // Radarr-style stored URLs may carry a trailing slash; without this
    // the exchange/me paths gain a double slash and the fork's auth
    // middleware 401s before routing (verified live: //api → empty 401).
    urlBase = urlBase.trim().replaceAll(RegExp(r'/+$'), '');
    try {
      final res = await http.post(
        Uri.parse('$urlBase/api/auth/oidc/exchange'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $authToken'},
        body: jsonEncode(<String, String>{'subject_token': authToken}),
      );
      if (kDebugMode) debugPrint('Sonarr OIDC exchange -> ${res.statusCode}');
      if (res.statusCode != 200 && kDebugMode) {
        final snippet = res.body.length > 200 ? res.body.substring(0, 200) : res.body;
        debugPrint('Sonarr OIDC exchange body: $snippet');
        // Temporary mismatch diagnostic: iss/aud/exp only, never sub/token.
        try {
          String norm(String s) => s.replaceAll('-', '+').replaceAll('_', '/');
          String pad(String s) => s + '=' * ((4 - s.length % 4) % 4);
          final parts = authToken.split('.');
          if (parts.length == 3) {
            final header = jsonDecode(
                    utf8.decode(base64.decode(pad(norm(parts[0])))))
                as Map<String, dynamic>;
            final payload = jsonDecode(
                    utf8.decode(base64.decode(pad(norm(parts[1])))))
                as Map<String, dynamic>;
            debugPrint('Sonarr OIDC subject-token iss=${payload['iss']} '
                'aud=${payload['aud']} exp=${payload['exp']} '
                'iat=${payload['iat']} kid=${header['kid']} '
                'now=${DateTime.now().millisecondsSinceEpoch ~/ 1000}');
          }
        } catch (_) {}
      }
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final token = body['token'] as String?;
        if (token == null || token.isEmpty) return false;
        final meRes = await http.get(Uri.parse('$urlBase/api/auth/me'), headers: {'Authorization': 'Bearer $token'});
        if (meRes.statusCode == 200) {
          final meBody = jsonDecode(meRes.body) as Map<String, dynamic>;
          SonarrOidcSessionProvider.update(urlBase, <String, dynamic>{
            ...body,
            'permissions': meBody['permissions'] ?? body['permissions'] ?? <String>[],
            'role': meBody['role'] ?? body['role'] ?? 'ReadOnly',
          });
          if (kDebugMode) debugPrint('Sonarr OIDC cached for $urlBase');
          return true;
        }
        SonarrOidcSessionProvider.update(urlBase, body);
        return true;
      }
      return res.statusCode == 401 ? false : false;
    } catch (e) {
      if (kDebugMode) debugPrint('Exchange error: $e');
      return false;
    }
  }

  /// True when [requestUri] belongs to the configured Sonarr origin.
  /// Guards every Bearer attach/retry below: an absolute-URL request to a
  /// foreign origin passing through the Sonarr client must never receive
  /// the Sonarr service token.
  /// Canonical host key: no trailing slash, so the service-token cache,
  /// exchange URLs, and origin check all agree regardless of how the
  /// stored service URL was typed (Radarr ships with one).
  String get _host =>
      (baseUrl ?? '').trim().replaceAll(RegExp(r'/+$'), '');

  bool _isServiceOrigin(Uri requestUri) {
    final base = Uri.tryParse(_host);
    if (base == null || !base.hasScheme || base.host.isEmpty) return false;
    int portOf(Uri u) =>
        u.hasPort ? u.port : (u.scheme == 'https' ? 443 : 80);
    return requestUri.scheme == base.scheme &&
        requestUri.host == base.host &&
        portOf(requestUri) == portOf(base);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    if (kDebugMode && status == 401) {
      final carried = (err.requestOptions.headers['Authorization'] as String?)
              ?.startsWith('Bearer ') ??
          false;
      // Redacted: query parameters can carry API keys and configured
      // URLs can embed userinfo; log origin + path only.
      String safe(Uri u) {
        final port = u.hasPort ? ':${u.port}' : '';
        return '${u.scheme}://${u.host}$port${u.path}';
      }
      debugPrint('Sonarr OIDC onError status=$status '
          'serviceKey=$serviceKey baseUrl=${safe(Uri.tryParse(baseUrl ?? '') ?? Uri())} carried=$carried '
          'origin=${_isServiceOrigin(err.requestOptions.uri)} '
          'uri=${safe(err.requestOptions.uri)}');
    }
    if (status == 401 && baseUrl != null && baseUrl!.isNotEmpty && _oidcService) {
      if (!_isServiceOrigin(err.requestOptions.uri)) {
        handler.next(err);
        return;
      }
      final carriedBearer = (err.requestOptions.headers['Authorization'] as String?)?.startsWith('Bearer ') ?? false;
      if (!carriedBearer) {
        // Lazy first exchange (Branch 3): the API-key path 401'd (blank or
        // invalid key) and we hold a Sonarr Authentik identity but no
        // service token yet. Exchange once and retry with the service
        // token. No identity or failed exchange → fall through to the
        // normal API-key error path untouched.
        try {
          if (kDebugMode) {
            debugPrint('Sonarr OIDC lazy 401 for $baseUrl '
                'identity=${(await _sonarrAuthToken())?.isNotEmpty == true}');
          }
          // Belt-and-braces: getSonarrSession already evicts expired
          // entries, but a session valid at lookup must never be retried
          // if it aged out during the exchange calls above.
          var cached = SonarrOidcSessionProvider.getSonarrSession(_host);
          if (cached != null && cached.isExpired()) cached = null;
          if (cached == null) {
            var firstAuth = await _sonarrAuthToken();
            if (firstAuth == null || firstAuth.isEmpty) {
              // A prior rejected refresh drops the access token but keeps
              // the refresh token: try once to recover the identity.
              // No refresh token → rejected, no side effects.
              if (await _doSonarrRefresh() == RefreshOutcome.refreshed) {
                firstAuth = await _sonarrAuthToken();
              }
            }
            if (firstAuth != null && firstAuth.isNotEmpty) {
              if (!await _postExchange(_host, firstAuth)) {
                // Identity may be stale while a refresh token exists:
                // refresh once and retry the exchange before giving up.
                if (await _doSonarrRefresh() == RefreshOutcome.refreshed) {
                  final again = await _sonarrAuthToken();
                  if (again != null && again.isNotEmpty) {
                    await _postExchange(_host, again);
                  }
                }
              }
              // Re-read: another in-flight request may have warmed the
              // cache while this one was exchanging.
              cached = SonarrOidcSessionProvider.getSonarrSession(_host);
              if (cached != null && cached.isExpired()) cached = null;
            }
          }
          if (cached != null) {
            // Copy: a failed retry must not leave the service token in
            // err.requestOptions, which handler.next(err) forwards below
            // past the Authorization cleanup at the end of onError.
            final opts = err.requestOptions.copyWith(
              headers: <String, dynamic>{
                ...err.requestOptions.headers,
                'Authorization': 'Bearer ${cached.serviceToken}',
              },
            );
            try {
              final retry =
                  await Dio(BaseOptions(baseUrl: _host)).fetch(opts);
              handler.resolve(retry);
              return;
            } catch (_) {}
          }
        } catch (_) {}
        handler.next(err);
        return;
      }
      try {
        // Virgin state (never logged in): keep the plain API-key error
        // path untouched.
        if (!await _hasSonarrIdentity()) {
          handler.next(err);
          return;
        }
        // The carried Bearer was rejected server-side. The cached token
        // may be stale (rotation, fork restart): mint a fresh one with
        // the live identity first, replacing the rejected token.
        var token = await _freshServiceToken(_host);
        if (token == null) {
          // Live identity failed too: recover via refresh, then exchange
          // exactly once more.
          final outcome = await _doSonarrRefresh();
          if (outcome == RefreshOutcome.refreshed) {
            token = await _freshServiceToken(_host);
          } else if (outcome == RefreshOutcome.rejected) {
            // Identity confirmed dead: drop it plus every cached service
            // token fleet-wide (a sibling host's cache would only 401).
            await _clearSonarrAuth();
            SonarrOidcSessionProvider.clearAll();
            handler.reject(DioException(requestOptions: err.requestOptions, error: 'Session expired — log in again', response: err.response));
            return;
          } else {
            // Transient (network blip): keep the identity, pass the
            // original error through untouched.
            handler.next(err);
            return;
          }
        }
        if (token != null) {
          final opts = err.requestOptions.copyWith(
            headers: <String, dynamic>{
              ...err.requestOptions.headers,
              'Authorization': 'Bearer $token',
            },
          );
          try {
            final retry = await Dio(BaseOptions(baseUrl: _host)).fetch(opts);
            handler.resolve(retry);
            return;
          } catch (_) {}
        } else {
          // Identity live but service refused twice: drop the service
          // token only; the shared identity stays valid for the fleet.
          await _clearSonarrServiceOnly();
          SonarrOidcSessionProvider.clear(_host);
          handler.reject(DioException(requestOptions: err.requestOptions, error: 'Session expired — log in again', response: err.response));
          return;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Interceptor error: $e');
      }
    }
    if (err.requestOptions.headers['Authorization'] != null) {
      err.requestOptions.headers.remove('Authorization');
    }
    handler.next(err);
  }
}
