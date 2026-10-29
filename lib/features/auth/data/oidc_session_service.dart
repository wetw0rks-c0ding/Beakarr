import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:seekarr/features/auth/data/sonarr_oidc_session_provider.dart';
import 'package:seekarr/features/settings/data/settings_service.dart';

/// Session status strings.
enum SessionStatus { disabled, active, error }

/// App-level OIDC session service using Authentik discovery + PKCE.
/// Outcome of an Authentik refresh attempt.
///
/// Only [rejected] means the identity is confirmed dead and its stored
/// tokens safe to clear. [transient] (network error, unparseable reply)
/// must never clear: the identity may be fine, and in ArrStack mode a
/// wrongful clear logs the whole fleet out.
enum RefreshOutcome { refreshed, rejected, transient }

class OidcSessionService {
  final SecureSettingsStore _store;
  static const String _kAccess = 'oidc_access_token';
  static const String _kRefresh = 'oidc_refresh_token';
  static const String _kExpiry = 'oidc_token_expiry';
  static const String _kPkceV = 'oidc_pkce_verifier';

  OidcSessionService(this._store);

  Future<bool> get isActive async => (await accessToken) != null;

  Future<String?> get accessToken => _store.read(key: _kAccess);
  Future<String?> get refreshToken => _store.read(key: _kRefresh);
  Future<String?> get pkceVerifier => _store.read(key: _kPkceV);

  Future<int?> expiryEpoch() async {
    final s = await _store.read(key: _kExpiry);
    return s == null ? null : int.tryParse(s);
  }

  /// Session status: Disabled, Active (with expiry), or Error.
  Future<SessionStatus> sessionState() async {
    final token = await accessToken;
    if (token == null) {
      return SessionStatus.disabled;
    }
    final expiry = await expiryEpoch();
    if (expiry != null &&
        DateTime.now().millisecondsSinceEpoch >= expiry * 1000) {
      return SessionStatus.error;
    }
    return SessionStatus.active;
  }

  /// Discovery from `.well-known/openid-configuration`; pure http.
  Future<Map<String, dynamic>> discover(String issuerUrl) async {
    final base = issuerUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final url = '$base/.well-known/openid-configuration';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200)
      throw Exception('OIDC discovery failed: ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> saveTokens({
    required String access,
    required String refresh,
    required int expiryEpoch,
    String? pkceVerifier,
  }) async {
    await _store.write(key: _kAccess, value: access);
    await _store.write(key: _kRefresh, value: refresh);
    await _store.write(key: _kExpiry, value: expiryEpoch.toString());
    if (pkceVerifier != null)
      await _store.write(key: _kPkceV, value: pkceVerifier);
  }

  Future<void> clear() async {
    await _store.delete(key: _kAccess);
    await _store.delete(key: _kRefresh);
    await _store.delete(key: _kExpiry);
    await _store.delete(key: _kPkceV);
  }

  // ---------------------------------------------------------------------------
  // Per-service Authentik sessions (sonarr, radarr, lidarr, …).
  //
  // Each *arr has its own Authentik provider (`.../o/<app>/`, `aud=<app>`),
  // so the app holds one Authentik token pair per service in addition to the
  // Seekarr-UI session above. The Sonarr pilot uses the `sonarr` pair as the
  // `subject_token` for `POST /api/auth/oidc/exchange`; the `seekarr` pair
  // is never sent to *arr hosts.
  // ---------------------------------------------------------------------------

  /// Services with their own Authentik provider (per-service PKCE).
  static const List<String> perServiceApps = <String>[
    'sonarr',
    'radarr',
    'lidarr',
    'prowlarr',
    'bazarr',
    'seerr',
  ];

  static String _accessFor(String service) => 'oidc_access_token_$service';
  static String _refreshFor(String service) => 'oidc_refresh_token_$service';
  static String _expiryFor(String service) => 'oidc_token_expiry_$service';
  static String _pkceFor(String service) => 'oidc_pkce_verifier_$service';

  /// True when [baseIssuer] is the single-tile ArrStack provider.
  /// In this mode every *arr service exchanges the same Authentik pair
  /// (`iss .../o/arrstack/`, `aud=arrstack`); per-service PKCE is skipped.
  static bool isArrstackMode(String baseIssuer) {
    final trimmed = baseIssuer.trim().replaceAll(RegExp(r'/+$'), '');
    return trimmed.endsWith('/o/arrstack');
  }

  /// Shared ArrStack issuer (normalized) for all services.
  static String get arrstackIssuer =>
      'https://auth.piracyhub.win/application/o/arrstack/';

  /// Shared ArrStack client id for all services.
  static String get arrstackClientId => 'arrstack';

  /// Derive a per-service issuer from the configured base issuer.
  ///
  /// ArrStack mode: the base issuer itself (one tile for the fleet).
  ///
  /// The base is normally the Seekarr provider issuer
  /// (`https://auth.<host>/application/o/seekarr/`); per-service issuers
  /// share the origin (`https://auth.<host>/application/o/<service>/`).
  /// If [baseIssuer] is already a per-service issuer, re-deriving for the
  /// same service is idempotent.
  static String perServiceIssuer(String baseIssuer, String service) {
    final trimmed = baseIssuer.trim().replaceAll(RegExp(r'/+$'), '');
    // ArrStack mode: one tile for the fleet, base issuer as-is.
    if (isArrstackMode(baseIssuer)) return '$trimmed/';
    if (trimmed.isEmpty || service.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return '';
    final origin =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    return '$origin/application/o/$service/';
  }

  /// Authentik client_id convention: one client per app, named for the app.
  /// ArrStack mode: every service shares the single `arrstack` client.
  static String perServiceClientId(String service, [String baseIssuer = '']) {
    if (baseIssuer.isNotEmpty && isArrstackMode(baseIssuer)) {
      return arrstackClientId;
    }
    return service;
  }

  Future<String?> accessTokenFor(String service) =>
      _store.read(key: _accessFor(service));

  Future<String?> refreshTokenFor(String service) =>
      _store.read(key: _refreshFor(service));

  Future<String?> pkceVerifierFor(String service) =>
      _store.read(key: _pkceFor(service));

  Future<int?> expiryEpochFor(String service) async {
    final s = await _store.read(key: _expiryFor(service));
    return s == null ? null : int.tryParse(s);
  }

  Future<SessionStatus> sessionStateFor(String service) async {
    final token = await accessTokenFor(service);
    if (token == null || token.isEmpty) return SessionStatus.disabled;
    final expiry = await expiryEpochFor(service);
    if (expiry != null &&
        DateTime.now().millisecondsSinceEpoch >= expiry * 1000) {
      return SessionStatus.error;
    }
    return SessionStatus.active;
  }

  Future<void> saveTokensFor({
    required String service,
    required String access,
    required String refresh,
    required int expiryEpoch,
    String? pkceVerifier,
  }) async {
    await _store.write(key: _accessFor(service), value: access);
    await _store.write(key: _refreshFor(service), value: refresh);
    await _store.write(key: _expiryFor(service), value: expiryEpoch.toString());
    if (pkceVerifier != null) {
      await _store.write(key: _pkceFor(service), value: pkceVerifier);
    }
  }

  Future<void> clearFor(String service) async {
    await _store.delete(key: _accessFor(service));
    await _store.delete(key: _refreshFor(service));
    await _store.delete(key: _expiryFor(service));
    await _store.delete(key: _pkceFor(service));
  }

  /// Persist only a PKCE verifier for [service] (login-flow start).
  /// Unlike [saveTokensFor], this never touches the stored token pair, so
  /// cancelling a login cannot wipe an existing session.
  Future<void> savePkceVerifierFor(String service, String verifier) =>
      _store.write(key: _pkceFor(service), value: verifier);

  Future<void> deletePkceVerifierFor(String service) =>
      _store.delete(key: _pkceFor(service));

  /// Exchange an authorization code against a per-service provider.
  /// Stores the resulting pair under the per-service keys.
  Future<bool> exchangeTokenFor({
    required String service,
    required String issuerUrl,
    required String clientId,
    required String authorizationCode,
    required String pkceVerifier,
    required String redirectUri,
  }) async {
    try {
      final config = await discover(issuerUrl);
      final tokenUrl = config['token_endpoint'] as String?;
      if (tokenUrl == null) {
        throw Exception('No token endpoint in OIDC discovery');
      }
      final res = await http.post(
        Uri.parse(tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: <String, String>{
          'grant_type': 'authorization_code',
          'code': authorizationCode,
          'redirect_uri': redirectUri,
          'code_verifier': pkceVerifier,
          'client_id': clientId,
        },
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        await saveTokensFor(
          service: service,
          access: body['access_token'] as String,
          refresh: body['refresh_token'] as String? ?? '',
          expiryEpoch:
              DateTime.now().millisecondsSinceEpoch ~/ 1000 +
              (body['expires_in'] as int? ?? 3600),
        );
        await _store.delete(key: _pkceFor(service));
        return true;
      } else if (res.statusCode == 400) {
        final errorBody = jsonDecode(res.body) as Map<String, dynamic>?;
        final error = errorBody?['error'] as String?;
        final errorMessage = errorBody?['error_description'] ?? error;
        throw Exception('Token exchange failed: $errorMessage');
      }
      throw Exception('Token exchange HTTP error: ${res.statusCode}');
    } catch (_) {
      await _store.delete(key: _pkceFor(service));
      rethrow;
    }
  }

  /// Refresh a per-service Authentik pair. Never throws. Clears only the
  /// per-service access token on [RefreshOutcome.rejected], keeping the
  /// refresh token. Concurrent callers for one service share a single
  /// token call (see [_inflightRefreshes]). Never touches the
  /// Seekarr-UI session.
  Future<RefreshOutcome> refreshFor(
    String service,
    String issuerUrl,
    String clientId,
  ) {
    final existing = _inflightRefreshes[service];
    if (existing != null) return existing;
    final fut = _refreshForInner(service, issuerUrl, clientId);
    _inflightRefreshes[service] = fut;
    fut
        .whenComplete(() {
          if (identical(_inflightRefreshes[service], fut)) {
            _inflightRefreshes.remove(service);
          }
        })
        .then((_) {}, onError: (_) {});
    return fut;
  }

  Future<RefreshOutcome> _refreshForInner(
    String service,
    String issuerUrl,
    String clientId,
  ) async {
    try {
      final storedRefresh = await refreshTokenFor(service);
      if (storedRefresh == null || storedRefresh.isEmpty) {
        return RefreshOutcome.rejected;
      }
      final config = await discover(issuerUrl);
      final tokenUrl = config['token_endpoint'] as String?;
      if (tokenUrl == null) return RefreshOutcome.rejected;
      final res = await http.post(
        Uri.parse(tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: <String, String>{
          'grant_type': 'refresh_token',
          'refresh_token': storedRefresh,
          'client_id': clientId,
        },
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        await saveTokensFor(
          service: service,
          access: body['access_token'] as String,
          refresh: body['refresh_token'] as String? ?? storedRefresh,
          expiryEpoch:
              DateTime.now().millisecondsSinceEpoch ~/ 1000 +
              (body['expires_in'] as int? ?? 3600),
        );
        return RefreshOutcome.refreshed;
      }
      if (res.statusCode == 400 || res.statusCode == 401) {
        await _store.delete(key: _accessFor(service));
        return RefreshOutcome.rejected;
      }
      return RefreshOutcome.transient;
    } catch (_) {
      return RefreshOutcome.transient;
    }
  }

  Future<void> clearAll() async {
    await _store.delete(key: _kAccess);
    await _store.delete(key: _kRefresh);
    await _store.delete(key: _kExpiry);
    await _store.delete(key: _kPkceV);
    for (final svc in perServiceApps) {
      await clearFor(svc);
    }
    SonarrOidcSessionProvider.clearAll();
  }

  /// Token exchange endpoint.
  Future<bool> exchangeToken({
    required String issuerUrl,
    required String clientId,
    required String authorizationCode,
    required String pkceVerifier,
    required String redirectUri,
  }) async {
    try {
      final config = await discover(issuerUrl);
      final tokenUrl = config['token_endpoint'] as String?;
      if (tokenUrl == null) {
        throw Exception('No token endpoint in OIDC discovery');
      }
      final res = await http.post(
        Uri.parse(tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: <String, String>{
          'grant_type': 'authorization_code',
          'code': authorizationCode,
          'redirect_uri': redirectUri,
          'code_verifier': pkceVerifier,
          'client_id': clientId,
        },
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        await saveTokens(
          access: body['access_token'] as String,
          refresh: body['refresh_token'] as String? ?? '',
          expiryEpoch:
              DateTime.now().millisecondsSinceEpoch ~/ 1000 +
              (body['expires_in'] as int? ?? 3600),
        );
        await _store.delete(key: _kPkceV);
        return true;
      } else if (res.statusCode == 400) {
        final errorBody = jsonDecode(res.body) as Map<String, dynamic>?;
        final error = errorBody?['error'] as String?;
        final errorMessage = errorBody?['error_description'] ?? error;
        throw Exception('Token exchange failed: $errorMessage');
      }
      throw Exception('Token exchange HTTP error: ${res.statusCode}');
    } catch (e) {
      await _store.delete(key: _kPkceV);
      rethrow;
    }
  }

  /// Joined in-flight refreshes: concurrent 401s share one token call so
  /// a rotating refresh token cannot be consumed twice. Key '' = base pair.
  static final Map<String, Future<RefreshOutcome>> _inflightRefreshes = {};

  /// Refresh flow - exchanges Authentik token for new access token.
  /// [RefreshOutcome.rejected] (400/401, no token/endpoint) is the only
  /// outcome that permits clearing; 429/5xx and exceptions are
  /// [RefreshOutcome.transient] and must never clear.
  Future<RefreshOutcome> refresh(String issuerUrl, String clientId) {
    final existing = _inflightRefreshes[''];
    if (existing != null) return existing;
    final fut = _refreshInner(issuerUrl, clientId);
    _inflightRefreshes[''] = fut;
    fut
        .whenComplete(() {
          if (identical(_inflightRefreshes[''], fut))
            _inflightRefreshes.remove('');
        })
        .then((_) {}, onError: (_) {});
    return fut;
  }

  Future<RefreshOutcome> _refreshInner(
    String issuerUrl,
    String clientId,
  ) async {
    try {
      final refreshToken = await this.refreshToken;
      if (refreshToken == null || refreshToken.isEmpty) {
        return RefreshOutcome.rejected;
      }
      final config = await discover(issuerUrl);
      final tokenUrl = config['token_endpoint'] as String?;
      if (tokenUrl == null) return RefreshOutcome.rejected;

      final res = await http.post(
        Uri.parse(tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: <String, String>{
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': clientId,
        },
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        await saveTokens(
          access: body['access_token'] as String,
          refresh: body['refresh_token'] as String? ?? refreshToken,
          expiryEpoch:
              DateTime.now().millisecondsSinceEpoch ~/ 1000 +
              (body['expires_in'] as int? ?? 3600),
        );
        return RefreshOutcome.refreshed;
      }

      // Definitive rejection only on 400/401 (invalid_grant etc.).
      // 429/5xx are transient: leave the store untouched for retry.
      if (res.statusCode == 400 || res.statusCode == 401) {
        await _store.delete(key: _kAccess);
        return RefreshOutcome.rejected;
      }
      return RefreshOutcome.transient;
    } catch (_) {
      // Network error or other exception - transient, keep everything.
      return RefreshOutcome.transient;
    }
  }

  /// Validate session status (Active, Expired, or No Session).
  Future<SessionStatus> validateSession() async {
    return await sessionState();
  }

  /// Get permissions cache for a specific host.
  List<String> getPermissionsCache(String baseUrl) {
    return SonarrOidcSessionProvider.getPermissions(baseUrl);
  }

  /// Get role from cache for a specific host.
  String getRoleCache(String baseUrl) {
    return SonarrOidcSessionProvider.getRole(baseUrl);
  }

  /// Check if there's a valid session for a host.
  bool hasValidSession(String baseUrl) {
    return SonarrOidcSessionProvider.hasValidSession(baseUrl);
  }
}
