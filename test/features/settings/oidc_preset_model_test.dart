import 'package:flutter_test/flutter_test.dart';
import 'package:seekarr/features/settings/domain/oidc_preset.dart';

void main() {
  group('OidcPreset round-trip', () {
    test('toJson/fromJson', () {
      final p = OidcPreset(name: 'My', issuer: 'https://i/', clientId: 'id');
      final r = OidcPreset.fromJson(p.toJson());
      expect(r.name, 'My');
    });
    test('malformed skips without throw', () {
      expect(OidcPreset.tryFromJson({}), isNull);
      expect(OidcPreset.tryFromJson({'name': 'ok', 'clientId': 'c'}), isNull); // missing issuer
      expect(OidcPreset.tryFromJson({'name': 12, 'issuer': 'i', 'clientId': 'c'}), isNull);
    });
  });
}
