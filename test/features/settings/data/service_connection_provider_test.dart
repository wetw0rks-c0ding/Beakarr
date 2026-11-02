import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/settings/data/service_connection_provider.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
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

  test('npm test connection reports connected on token + hosts', () async {
    final server = await _npmServer(
      hostsBody: [
        {
          'id': 1,
          'domain_names': ['app.example.com'],
          'enabled': true,
        },
      ],
    );
    final settings = SettingsModel(
      npmUrl: 'http://127.0.0.1:${server.port}',
      npmIdentity: 'admin@example.com',
      npmPassword: 'pass',
    );

    final result = await testServiceConnection(ServiceKey.npm, settings);
    expect(result.ok, isTrue);
    expect(
      server.paths,
      containsAll(['/api/tokens', '/api/nginx/proxy-hosts']),
    );
    expect(server.loginBodies.single['identity'], 'admin@example.com');
    expect(server.loginBodies.single['secret'], 'pass');
  });

  test('npm test connection reports HTTP 401', () async {
    final server = await _npmServer(tokenStatus: 401);
    final settings = SettingsModel(
      npmUrl: 'http://127.0.0.1:${server.port}',
      npmIdentity: 'admin@example.com',
      npmPassword: 'wrong',
    );

    final result = await testServiceConnection(ServiceKey.npm, settings);
    expect(result.ok, isFalse);
    expect(result.detail, 'HTTP 401');
  });

  test('npm test connection surfaces the server error message', () async {
    final server = await _npmServer(
      tokenStatus: 400,
      tokenBody: {
        'error': {'message': 'Invalid email or password'},
      },
    );
    final settings = SettingsModel(
      npmUrl: 'http://127.0.0.1:${server.port}',
      npmIdentity: 'admin@example.com',
      npmPassword: 'wrong',
    );

    final result = await testServiceConnection(ServiceKey.npm, settings);
    expect(result.ok, isFalse);
    expect(result.detail, contains('Invalid email or password'));
  });

  test('npm test connection surfaces the 2FA message', () async {
    final server = await _npmServer(twoFactor: true);
    final settings = SettingsModel(
      npmUrl: 'http://127.0.0.1:${server.port}',
      npmIdentity: 'admin@example.com',
      npmPassword: 'pass',
    );

    final result = await testServiceConnection(ServiceKey.npm, settings);
    expect(result.ok, isFalse);
    expect(result.detail, contains('2FA'));
  });

  test('npm connection check is disconnected on a 401', () async {
    final server = await _npmServer(tokenStatus: 401);
    final settings = SettingsModel(
      npmUrl: 'http://127.0.0.1:${server.port}',
      npmIdentity: 'admin@example.com',
      npmPassword: 'wrong',
    );
    final container = ProviderContainer(
      overrides: [currentSettingsProvider.overrideWith((ref) => settings)],
    );
    addTearDown(container.dispose);

    final result = await container.read(
      serviceConnectionProvider(ServiceKey.npm).future,
    );
    expect(result, ServiceConnectionStatus.disconnected);
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

  group('OpenMediaVault connection', () {
    Future<HttpServer> _omvServer({
      String role = 'admin',
      int loginStatus = 200,
      Map<String, dynamic>? loginBody,
    }) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        request.response.headers.contentType = ContentType.json;
        if (decoded['service'] == 'Session' && decoded['method'] == 'login') {
          request.response.statusCode = loginStatus;
          request.response.write(
            jsonEncode(
              loginBody ??
                  {
                    'response': {
                      'authenticated': true,
                      'sessionid': 'sid-1',
                      'permissions': {'role': role},
                    },
                    'error': null,
                  },
            ),
          );
        } else {
          request.response.write(
            jsonEncode({
              'response': {'version': '7.4.17 (Sandworm)'},
              'error': null,
            }),
          );
        }
        await request.response.close();
      });
      return server;
    }

    SettingsModel _omvSettings(HttpServer server) => SettingsModel(
      openmediavaultUrl: 'http://127.0.0.1:${server.port}',
      openmediavaultUsername: 'admin',
      openmediavaultPassword: 'pass',
    );

    test('connected with admin role', () async {
      final server = await _omvServer();
      final result = await testServiceConnection(
        ServiceKey.openmediavault,
        _omvSettings(server),
      );
      expect(result.ok, isTrue);
    });

    test('bad credentials surface the server message', () async {
      final server = await _omvServer(
        loginStatus: 400,
        loginBody: {
          'response': null,
          'error': {'message': 'Incorrect username or password.'},
        },
      );
      final result = await testServiceConnection(
        ServiceKey.openmediavault,
        _omvSettings(server),
      );
      expect(result.ok, isFalse);
      expect(result.detail, contains('Incorrect username'));
    });

    test('non-admin login is not reported as connected', () async {
      final server = await _omvServer(role: 'user');
      final settings = _omvSettings(server);
      final result = await testServiceConnection(
        ServiceKey.openmediavault,
        settings,
      );
      expect(result.ok, isFalse);
      expect(result.detail, contains('administrator'));
    });
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

/// Minimal Nginx Proxy Manager server: answers `/api/tokens` and
/// `/api/nginx/proxy-hosts`, recording paths and login bodies so the
/// handshake is assertable.
class _FakeNpmServer {
  final HttpServer _server;
  final List<String> paths = [];
  final List<Map<String, dynamic>> loginBodies = [];

  _FakeNpmServer(this._server);

  int get port => _server.port;
}

Future<_FakeNpmServer> _npmServer({
  bool twoFactor = false,
  int tokenStatus = 200,
  Map<String, dynamic>? tokenBody,
  int hostsStatus = 200,
  List<dynamic> hostsBody = const [],
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final fake = _FakeNpmServer(server);
  addTearDown(() => server.close(force: true));

  server.listen((request) async {
    fake.paths.add(request.uri.path);
    final body = await utf8.decoder.bind(request).join();

    request.response.headers.contentType = ContentType.json;
    if (request.uri.path == '/api/tokens') {
      if (body.isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          fake.loginBodies.add(Map<String, dynamic>.from(decoded));
        }
      }
      request.response.statusCode = tokenStatus;
      request.response.write(
        jsonEncode(
          tokenBody ??
              (twoFactor
                  ? {'requires_2fa': true}
                  : {
                      'token': 'tok-1',
                      'expires': DateTime.now()
                          .toUtc()
                          .add(const Duration(hours: 1))
                          .toIso8601String(),
                    }),
        ),
      );
    } else {
      request.response.statusCode = hostsStatus;
      request.response.write(jsonEncode(hostsBody));
    }
    await request.response.close();
  });

  return fake;
}
