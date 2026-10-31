import 'dart:convert';

enum OidcValidationError { badOrigin, unreachable, slug404, notOidc, missingEndpoints }

class OidcValidationResult {
  final bool valid;
  final String? canonicalIssuer; // trimmed + stripped trailing slash; doc issuer verbatim normalized same way
  final String? error;
  final OidcValidationError? errorType;
  const OidcValidationResult({required this.valid, this.canonicalIssuer, this.error, this.errorType});
}

class OidcPresetValidator {
  final Future<dynamic> Function(String url) fetch;
  const OidcPresetValidator({required this.fetch});

  /// Best-effort JSON decode; null when the body is not JSON at all.
  static Map<String, dynamic>? _tryDecodeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<OidcValidationResult> validate({required String origin, required String slug}) async {
    // Normalization
    var o = origin.trim();
    while (o.endsWith('/')) o = o.substring(0, o.length - 1);
    var s = slug.trim().toLowerCase();
    if (o.isEmpty || !o.startsWith('http')) return const OidcValidationResult(valid: false, error: 'Invalid origin', errorType: OidcValidationError.badOrigin);
    final url = '$o/application/o/$s/.well-known/openid-configuration';
    try {
      final resp = await fetch(url);
      if (resp == null) return const OidcValidationResult(valid: false, error: 'Unreachable', errorType: OidcValidationError.unreachable);
      // Mock/real interface: assume resp is Map or has .statusCode and body
      // Map: already-decoded metadata (unit-test seam). String: raw
      // body — a decode failure means 200-with-non-JSON (captive
      // portal, HTML error page), i.e. not OIDC metadata, never a
      // transport error.
      final dynamic body = resp is Map
          ? resp
          : (resp is String ? _tryDecodeJson(resp) : null);
      if (body is! Map) return const OidcValidationResult(valid: false, error: 'Not OIDC metadata', errorType: OidcValidationError.notOidc);
      final issuerVal = body['issuer'];
      final auth = body['authorization_endpoint'];
      final token = body['token_endpoint'];
      if (issuerVal is! String || issuerVal.trim().isEmpty) return const OidcValidationResult(valid: false, error: 'Missing issuer', errorType: OidcValidationError.notOidc);
      if (auth == null || auth is! String || auth.trim().isEmpty || token == null || token is! String || token.trim().isEmpty) return const OidcValidationResult(valid: false, error: 'Missing endpoints', errorType: OidcValidationError.missingEndpoints);
      final canon = issuerVal.trim().replaceAll(RegExp(r'/+$'), '');
      return OidcValidationResult(valid: true, canonicalIssuer: canon);
    } catch (e) {
      // Treat any fetch failure (network, 404, bad JSON) as unreachable/404; distinguish by message if possible
      final msg = e.toString();
      if (msg.contains('404') || msg.contains('Not Found')) return const OidcValidationResult(valid: false, error: 'Slug not found', errorType: OidcValidationError.slug404);
      return const OidcValidationResult(valid: false, error: 'Unreachable', errorType: OidcValidationError.unreachable);
    }
  }

  static bool isNoOp({required String settingsIssuer, required String settingsClientId, required String presetIssuer, required String presetClientId}) {
    final n1 = settingsIssuer.trim().replaceAll(RegExp(r'/+$'), '');
    final n2 = presetIssuer.trim().replaceAll(RegExp(r'/+$'), '');
    return n1 == n2 && settingsClientId.trim() == presetClientId.trim();
  }
}
