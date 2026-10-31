import 'package:flutter_test/flutter_test.dart';
import 'package:seekarr/features/settings/domain/oidc_preset.dart';
import 'package:seekarr/features/settings/domain/oidc_preset_validator.dart';

void main() {
  group('OidcPreset model', () {
    test('round-trip', () {
      final p = OidcPreset(name: 'A', issuer: 'https://i/', clientId: 'c');
      expect(OidcPreset.tryFromJson(p.toJson())!.name, p.name);
    });
    test('malformed JSON skips', () {
      expect(OidcPreset.tryFromJson({'name': 'x'}), isNull);
      expect(OidcPreset.tryFromJson({'name': '', 'issuer': 'i', 'clientId': 'c'}), isNull);
      expect(OidcPreset.tryFromJson({'name': 'n', 'issuer': '  ', 'clientId': 'c'}), isNull);
    });
  });
  group('validation matrix', () {
    test('bad origin', () async {
      final v = OidcPresetValidator(fetch: (_) async => null);
      final r = await v.validate(origin: 'not-url', slug: 'x');
      expect(r.valid, false);
      expect(r.errorType, OidcValidationError.badOrigin);
    });
    test('unreachable', () async {
      final v = OidcPresetValidator(fetch: (_) async => throw Exception('fail'));
      final r = await v.validate(origin: 'https://a', slug: 'x');
      expect(r.valid, false);
      expect(r.errorType, OidcValidationError.unreachable);
    });
    test('slug 404', () async {
      final v = OidcPresetValidator(fetch: (_) async => throw Exception('404 Not Found'));
      final r = await v.validate(origin: 'https://a', slug: 'bad');
      expect(r.valid, false);
      expect(r.errorType, OidcValidationError.slug404);
    });
    test('non-OIDC doc / missing endpoints', () async {
      final v = OidcPresetValidator(fetch: (_) async => {'not': 'oidc'});
      final r = await v.validate(origin: 'https://a', slug: 's');
      expect(r.valid, false);
      expect(r.errorType, OidcValidationError.notOidc);
    });
    test('200-with-HTML body is notOidc, not unreachable', () async {
      final v = OidcPresetValidator(
        fetch: (_) async => '<html><body>Captive portal</body></html>',
      );
      final r = await v.validate(origin: 'https://a', slug: 's');
      expect(r.valid, false);
      expect(r.errorType, OidcValidationError.notOidc);
    });
    test('happy path with doc-issuer-canonicalization', () async {
      final v = OidcPresetValidator(fetch: (_) async => {
        'issuer': 'https://auth.example.com/application/o/arrstack/',
        'authorization_endpoint': 'https://auth.example.com/application/o/authorize/',
        'token_endpoint': 'https://auth.example.com/application/o/token/',
      });
      final r = await v.validate(origin: 'https://auth.example.com/', slug: 'arrstack');
      expect(r.valid, true);
      expect(r.canonicalIssuer, 'https://auth.example.com/application/o/arrstack');
    });
  });
  group('no-op equality', () {
    test('both match -> no-op', () {
      expect(OidcPresetValidator.isNoOp(
        settingsIssuer: 'https://i/', settingsClientId: 'c',
        presetIssuer: 'https://i/', presetClientId: 'c',
      ), true);
    });
    test('different issuer -> not no-op', () {
      expect(OidcPresetValidator.isNoOp(
        settingsIssuer: 'https://a/', settingsClientId: 'c',
        presetIssuer: 'https://b/', presetClientId: 'c',
      ), false);
    });
    test('same issuer diff client -> not no-op', () {
      expect(OidcPresetValidator.isNoOp(
        settingsIssuer: 'https://i/', settingsClientId: 'c1',
        presetIssuer: 'https://i/', presetClientId: 'c2',
      ), false);
    });
  });
}
