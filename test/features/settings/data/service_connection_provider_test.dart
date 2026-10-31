import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/settings/data/service_connection_provider.dart';
import 'package:seekarr/features/settings/domain/service_key.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';

void main() {
  test('navidrome connection check returns disconnected on status:failed', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'subsonic-response': {
          'status': 'failed',
          'error': {'message': 'Wrong username or password'},
        },
      }));
      await request.response.close();
    });

    final url = 'http://127.0.0.1:${server.port}';
    final settings = SettingsModel(
      navidromeUrl: url,
      navidromeUsername: 'user',
      navidromePassword: 'pass',
    );

    final result = await testServiceConnection(ServiceKey.navidrome, settings);
    expect(result.ok, isFalse);
    expect(result.detail, contains('Wrong username or password'));
  });

  test('navidrome connection check returns connected on status:ok', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'subsonic-response': {'status': 'ok'},
      }));
      await request.response.close();
    });

    final url = 'http://127.0.0.1:${server.port}';
    final settings = SettingsModel(
      navidromeUrl: url,
      navidromeUsername: 'user',
      navidromePassword: 'pass',
    );

    final result = await testServiceConnection(ServiceKey.navidrome, settings);
    expect(result.ok, isTrue);
  });

  test('nzbget test connection reports not supported (PR1 stub)', () async {
    const settings = SettingsModel(
      nzbgetUrl: 'http://127.0.0.1:6789',
      nzbgetUsername: 'user',
      nzbgetPassword: 'pass',
    );

    final result = await testServiceConnection(ServiceKey.nzbget, settings);
    expect(result.ok, isFalse);
    expect(result.detail, 'Not yet supported');
  });

  test('npm test connection reports not supported (PR1 stub)', () async {
    const settings = SettingsModel(
      npmUrl: 'http://127.0.0.1:81',
      npmIdentity: 'admin@example.com',
      npmPassword: 'pass',
    );

    final result = await testServiceConnection(ServiceKey.npm, settings);
    expect(result.ok, isFalse);
    expect(result.detail, 'Not yet supported');
  });

  test('unconfigured nzbget/npm report not configured', () async {
    const settings = SettingsModel();
    expect(
      (await testServiceConnection(ServiceKey.nzbget, settings)).detail,
      'Not configured',
    );
    expect(
      (await testServiceConnection(ServiceKey.npm, settings)).detail,
      'Not configured',
    );
  });
}
