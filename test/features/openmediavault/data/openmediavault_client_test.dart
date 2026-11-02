import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/openmediavault/data/openmediavault_client.dart';

/// Scriptable adapter: dequeues (status, body) per call and records
/// every request for assertions.
class _ScriptAdapter implements HttpClientAdapter {
  _ScriptAdapter({required this.script});

  final List<(int, dynamic)> script;
  int callIndex = 0;
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final step = callIndex < script.length ? script[callIndex] : script.last;
    callIndex++;
    final body = step.$2 is String ? step.$2 as String : jsonEncode(step.$2);
    return ResponseBody.fromBytes(
      Uint8List.fromList(utf8.encode(body)),
      step.$1,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }
}

OpenMediaVaultClient _client(
  HttpClientAdapter adapter, {
  String url = 'http://localhost',
  String user = 'admin',
  String pw = 'pass',
}) {
  final dio = Dio(BaseOptions(baseUrl: url));
  dio.httpClientAdapter = adapter;
  return OpenMediaVaultClient(url: url, username: user, password: pw, dio: dio);
}

Map<String, dynamic> _loginBody(String sid) => {
  'response': {
    'authenticated': true,
    'sessionid': sid,
    'permissions': {'role': 'admin'},
  },
  'error': null,
};

void main() {
  group('OpenMediaVaultClient login', () {
    test('posts Session.login and caches the session id', () async {
      final adapter = _ScriptAdapter(
        script: [(200, _loginBody('sid-1'))],
      );
      final client = _client(adapter);

      await client.login();

      expect(adapter.callIndex, 1);
      final payload = adapter.requests.single.data as Map;
      expect(payload['service'], 'Session');
      expect(payload['method'], 'login');
      expect(client.sessionId, 'sid-1');
      expect(client.isAuthenticated, isTrue);
      expect(client.permissions?['role'], 'admin');
    });

    test('empty session id never clobbers the cache', () async {
      final adapter = _ScriptAdapter(
        script: [
          (200, _loginBody('sid-1')),
          (200, _loginBody('')),
        ],
      );
      final client = _client(adapter);

      await client.login();
      await client.login();

      expect(client.sessionId, 'sid-1');
    });

    test('bad credentials throw once with the server message', () async {
      final adapter = _ScriptAdapter(
        script: [
          (
            400,
            {
              'response': null,
              'error': {'message': 'Incorrect username or password.'},
            },
          ),
        ],
      );
      final client = _client(adapter);

      Object? error;
      try {
        await client.login();
      } catch (e) {
        error = e;
      }
      expect(error, isA<OpenMediaVaultException>());
      expect(
        (error as OpenMediaVaultException).message,
        contains('Incorrect username or password'),
      );
      // No retry on 400: exactly one POST.
      expect(adapter.callIndex, 1);
      expect(client.isAuthenticated, isFalse);
    });

    test('sends stable UA and session header on rpc', () async {
      final adapter = _ScriptAdapter(
        script: [
          (200, _loginBody('sid-9')),
          (
            200,
            {
              'response': {'version': '7.4.17 (Sandworm)'},
              'error': null,
            },
          ),
        ],
      );
      final client = _client(adapter);

      await client.rpc('System', 'getInformation');

      final rpcRequest = adapter.requests.last;
      expect(rpcRequest.headers['User-Agent'], 'Beakarr');
      final sessionHeaders = adapter.requests
          .map((r) => r.headers[OpenMediaVaultClient.sessionHeader])
          .toList();
      expect(sessionHeaders, contains('sid-9'));
    });
  });

  group('OpenMediaVaultClient read-only guard', () {
    test('non-allowlisted calls throw before any HTTP', () async {
      final adapter = _ScriptAdapter(script: const []);
      final client = _client(adapter);

      for (final call in [
        ('System', 'reboot'),
        ('FileSystemMgmt', 'umountByDir'),
        ('Smart', 'executeScheduledTest'),
        ('Services', 'enable'),
      ]) {
        expect(
          () => client.rpc(call.$1, call.$2),
          throwsStateError,
        );
      }
      expect(adapter.callIndex, 0);
    });

    test('allowlisted reads pass the guard', () async {
      final adapter = _ScriptAdapter(
        script: [
          (200, _loginBody('s')),
          (
            200,
            {
              'response': {'version': 'x'},
              'error': null,
            },
          ),
        ],
      );
      final client = _client(adapter);

      await client.rpc('System', 'getInformation');
      expect(adapter.callIndex, 2);
    });
  });

  group('OpenMediaVaultClient 401 recovery', () {
    test('expired session re-logins once and retries', () async {
      final adapter = _ScriptAdapter(
        script: [
          (200, _loginBody('sid-1')),
          (401, {'response': null, 'error': 'Unauthorized'}),
          (200, _loginBody('sid-2')),
          (
            200,
            {
              'response': {'version': '7.4.17'},
              'error': null,
            },
          ),
        ],
      );
      final client = _client(adapter);
      await client.login();

      final result = await client.rpc('System', 'getInformation');

      expect((result as Map)['version'], '7.4.17');
      expect(adapter.callIndex, 4);
      expect(client.sessionId, 'sid-2');
    });

    test('double 401 never loops', () async {
      final adapter = _ScriptAdapter(
        script: [
          (200, _loginBody('sid-1')),
          (401, {'response': null, 'error': 'Unauthorized'}),
          (200, _loginBody('sid-2')),
          (401, {'response': null, 'error': 'Unauthorized'}),
        ],
      );
      final client = _client(adapter);
      await client.login();

      await expectLater(() => client.rpc('System', 'getInformation'), throwsA(anything));
      expect(adapter.callIndex, 4);
    });
  });
}
