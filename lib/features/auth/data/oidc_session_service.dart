import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:seekarr/features/settings/data/settings_service.dart';

/// Session status strings.
enum SessionStatus {
  disabled,
  active, 
  error;
}

/// App-level OIDC session service using Authentik discovery + PKCE.
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
    if (expiry != null && DateTime.now().millisecondsSinceEpoch >= expiry * 1000) {
      return SessionStatus.error;
    }
    return SessionStatus.active;
  }

  /// Discovery from `.well-known/openid-configuration`; pure http.
  Future<Map<String, dynamic>> discover(String issuerUrl) async {
    final base = issuerUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final url = '$base/.well-known/openid-configuration';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('OIDC discovery failed: ${res.statusCode}');
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
    if (pkceVerifier != null) await _store.write(key: _kPkceV, value: pkceVerifier);
  }

  Future<void> clear() async {
    await _store.delete(key: _kAccess);
    await _store.delete(key: _kRefresh);
    await _store.delete(key: _kExpiry);
    await _store.delete(key: _kPkceV);
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
          expiryEpoch: DateTime.now().millisecondsSinceEpoch ~/ 1000 + (body['expires_in'] as int? ?? 3600),
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

  /// Refresh flow.
  Future<bool> refresh(String issuerUrl, String clientId) async {
    final refresh = await refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    final config = await discover(issuerUrl);
    final tokenUrl = config['token_endpoint'] as String?;
    if (tokenUrl == null) return false;
    final res = await http.post(
      Uri.parse(tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: <String, String>{
        'grant_type': 'refresh_token',
        'refresh_token': refresh,
        'client_id': clientId,
      },
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      await saveTokens(
        access: body['access_token'] as String,
        refresh: body['refresh_token'] as String? ?? refresh,
        expiryEpoch: DateTime.now().millisecondsSinceEpoch ~/ 1000 + (body['expires_in'] as int? ?? 3600),
      );
      return true;
    }
    return false;
  }
}

