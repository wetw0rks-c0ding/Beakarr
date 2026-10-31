import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/settings/data/service_connection_provider.dart';
import 'package:seekarr/features/settings/domain/service_key.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';

void main() {
  test(
    'navidrome connection check returns disconnected on status:failed',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'subsonic-response': {
              'status': 'failed',
              'error': {'message': 'Wrong username or password'},
            },
          }),
        );
        await request.response.close();
      });

      final url = 'http://127.0.0.1:${server.port}';
      final settings = SettingsModel(
        navidromeUrl: url,
        navidromeUsername: 'user',
        navidromePassword: 'pass',
      );

      final result = await testServiceConnection(
        ServiceKey.navidrome,
        settings,
      );
      expect(result.ok, isFalse);
      expect(result.detail, contains('Wrong username or password'));
    },
  );

  test('navidrome connection check returns connected on status:ok', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'subsonic-response': {'status': 'ok'},
        }),
      );
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

  test('nzbget test connection reports connected on version+status', () async {
    final server = await _nzbgetServer(
      (method) => {'version': '1.1', 'id': 1, 'result': true, 'error': null},
    );
    final settings = SettingsModel(
      nzbgetUrl: 'http://127.0.0.1:${server.port}',
      nzbgetUsername: 'user',
      nzbgetPassword: 'pass',
    );

    final result = await testServiceConnection(ServiceKey.nzbget, settings);
    expect(result.ok, isTrue);
    expect(server.methods, containsAll(['version', 'status']));
  });

  test('nzbget test connection reports HTTP 401', () async {
    final server = await _nzbgetServer(
      (method) => {'version': '1.1', 'id': 1, 'result': null},
      statusCode: 401,
    );
    final settings = SettingsModel(
      nzbgetUrl: 'http://127.0.0.1:${server.port}',
      nzbgetUsername: 'user',
      nzbgetPassword: 'wrong',
    );

    final result = await testServiceConnection(ServiceKey.nzbget, settings);
    expect(result.ok, isFalse);
    expect(result.detail, 'HTTP 401');
  });

  test('nzbget test connection surfaces an RPC error detail', () async {
    final server = await _nzbgetServer(
      (method) => {
        'version': '1.1',
        'id': 1,
        'result': null,
        'error': {'code': -32000, 'message': 'Access denied'},
      },
    );
    final settings = SettingsModel(
      nzbgetUrl: 'http://127.0.0.1:${server.port}',
      nzbgetUsername: 'add-only',
      nzbgetPassword: 'pass',
    );

    final result = await testServiceConnection(ServiceKey.nzbget, settings);
    expect(result.ok, isFalse);
    expect(result.detail, startsWith('RPC -32000:'));
    expect(result.detail, contains('Access denied'));
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

/// Minimal NZBGet JSON-RPC server for health-check tests; records the method
/// of each call so tests can assert the version→status handshake.
class _FakeNzbgetServer {
  final HttpServer _server;
  final List<String> methods = [];

  _FakeNzbgetServer(this._server);

  int get port => _server.port;
}

Future<_FakeNzbgetServer> _nzbgetServer(
  Map<String, dynamic> Function(String method) respond, {
  int statusCode = 200,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final fake = _FakeNzbgetServer(server);
  addTearDown(() => server.close(force: true));

  server.listen((request) async {
    final body = await utf8.decoder.bind(request).join();
    var method = '';
    if (body.isNotEmpty) {
      final decoded = jsonDecode(body);
      if (decoded is Map) method = decoded['method']?.toString() ?? '';
    }
    fake.methods.add(method);

    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(respond(method)));
    await request.response.close();
  });

  return fake;
}
