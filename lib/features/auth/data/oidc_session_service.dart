import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:seekarr/features/settings/data/settings_service.dart';

/// App-level OIDC session service using Authentik discovery + PKCE.
/// No openid_client dependency — hand-rolled to stay pure Dart / safe for xcross.
class OidcSessionService {
  final SecureSettingsStore _store;
  static const _kAccess = 'oidc_access_token';
  static const _kRefresh = 'oidc_refresh_token';
  static const _kExpiry = 'oidc_token_expiry';
  static const _kPkceV = 'oidc_pkce_verifier';

  OidcSessionService(this._store);

  Future<bool> isActive() async => (await accessToken()) != null;

  Future<String?> accessToken() => _store.read(key: _kAccess);
  Future<String?> refreshToken() => _store.read(key: _kRefresh);
  Future<int?> expiryEpoch() async {
    final s = await _store.read(key: _kExpiry);
    return s == null ? null : int.tryParse(s);
  }

  /// Discovery from `.well-known/openid-configuration`; pure http.
  Future<Map<String, dynamic>> discover(String issuerUrl) async {
    final url = '$issuerUrl/.well-known/openid-configuration';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('OIDC discovery failed: ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> saveTokens({required String access, required String refresh, required int expiryEpoch, String? pkceVerifier}) async {
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

  /// Refresh flow: POST to token endpoint with refresh_token + client_id.
  Future<bool> refresh(String issuerUrl, String clientId) async {
    final refresh = await refreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    final config = await discover(issuerUrl);
    final tokenUrl = config['token_endpoint'] as String?;
    if (tokenUrl == null) return false;
    final res = await http.post(
      Uri.parse(tokenUrl),
      body: {
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
