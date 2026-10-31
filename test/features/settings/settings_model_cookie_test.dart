import 'package:flutter_test/flutter_test.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';
import 'package:seekarr/features/settings/domain/service_key.dart';

void main() {
  group('SettingsModel soulsync configured-matrix', () {
    test('URL + cookie configured', () {
      final s = SettingsModel(soulsyncUrl: 'http://s', soulsyncProxyCookie: 'c');
      expect(s.isServiceConfigured(ServiceKey.soulsync), true);
    });
    test('URL + key configured', () {
      final s = SettingsModel(soulsyncUrl: 'http://s', soulsyncApiKey: 'k');
      expect(s.isServiceConfigured(ServiceKey.soulsync), true);
    });
    test('URL-only not configured', () {
      final s = SettingsModel(soulsyncUrl: 'http://s');
      expect(s.isServiceConfigured(ServiceKey.soulsync), false);
    });
    test('cookie only (no URL) not configured', () {
      final s = SettingsModel(soulsyncProxyCookie: 'c');
      expect(s.isServiceConfigured(ServiceKey.soulsync), false);
    });
    test('copyWithSoulSync passes cookie', () {
      final s = SettingsModel(soulsyncUrl: 'u').copyWithSoulSync(proxyCookie: 'v');
      expect(s.soulsyncProxyCookie, 'v');
      expect(s.soulsyncUrl, 'u');
    });
  });
}
