import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seekarr/features/settings/data/settings_backup_service.dart';
import 'package:seekarr/features/settings/data/backup_exceptions.dart';
import 'package:seekarr/features/settings/data/settings_service.dart';
import '../../../../test/test_helpers/fake_secure_settings_store.dart';

void main() {
  late SharedPreferences prefs;
  late FakeSecureSettingsStore secure;
  late SettingsBackupService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    secure = FakeSecureSettingsStore();
    service = SettingsBackupService(prefs: prefs, secureStore: secure);
  });

  test('round-trip preserves prefs types + secure', () async {
    await prefs.setBool('b', true);
    await prefs.setInt('i', 42);
    await prefs.setDouble('d', 3.14);
    await prefs.setString('s', 'hello');
    await secure.write(key: 'api', value: 'secret');
    final env = await service.exportBackup(password: 'password123');
    final result = await service.importBackup(env, password: 'password123');
    expect(result.prefs['b'], true);
    expect(result.prefs['i'], 42);
    expect(result.prefs['d'], 3.14);
    expect(result.prefs['s'], 'hello');
    expect(result.secure['api'], 'secret');
  });

  test('token keys excluded from payload', () async {
    await prefs.setString('oidc_access_token_sonarr', 't');
    await prefs.setString('region', 'US');
    await secure.write(key: 'oidc_access_token_sonarr', value: 'tok');
    final env = await service.exportBackup(password: 'pw');
    final import = await service.importBackup(env, password: 'pw');
    expect(import.prefs.containsKey('oidc_access_token_sonarr'), false);
    expect(import.prefs['region'], 'US');
    expect(import.secure.containsKey('oidc_access_token_sonarr'), false);
  });

  test('wrong password throws BackupWrongPasswordException', () async {
    await prefs.setString('k', 'v');
    final env = await service.exportBackup(password: 'pw');
    await expectLater(service.importBackup(env, password: 'bad'), throwsA(isA<BackupWrongPasswordException>()));
  });

  test('tampered ct throws BackupCorruptException', () async {
    await prefs.setString('k', 'v');
    final env = json.decode(await service.exportBackup(password: 'pw')) as Map<String, dynamic>;
    env['ct'] = base64.encode([0, 1, 2]);
    await expectLater(service.importBackup(json.encode(env), password: 'pw'), throwsA(isA<BackupCorruptException>()));
  });

  test('v:99 throws BackupUnsupportedVersionException', () async {
    await prefs.setString('k', 'v');
    final env = json.decode(await service.exportBackup(password: 'pw')) as Map<String, dynamic>;
    env['v'] = 99;
    await expectLater(service.importBackup(json.encode(env), password: 'pw'), throwsA(isA<BackupUnsupportedVersionException>()));
  });

  test('empty password throws', () async {
    await expectLater(service.exportBackup(password: ''), throwsA(isA<ArgumentError>()));
  });
}
