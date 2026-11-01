import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/wizarr/data/wizarr_client.dart';

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
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

WizarrClient _client(HttpClientAdapter adapter, {String apiKey = '  key  '}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
  dio.httpClientAdapter = adapter;
  return WizarrClient(url: 'http://localhost', apiKey: apiKey, dio: dio);
}

void main() {
  test('trims api key', () {
    final client = WizarrClient(url: 'http://localhost', apiKey: '  secret  ');
    expect(client.apiKey, 'secret');
  });

  test('non-allowlisted throws StateError before HTTP', () async {
    final adapter = _ScriptAdapter(script: const []);
    final client = _client(adapter);
    expect(() => client.rpc('Invitation', 'create'), throwsStateError);
    expect(adapter.callIndex, 0);
  });

  test('401 maps to WizarrException message', () async {
    final adapter = _ScriptAdapter(
      script: [
        (401, {'error': 'Unauthorized'}),
      ],
    );
    final client = _client(adapter);
    Object? error;
    try {
      await client.rpc('Invitation', 'getAll');
    } catch (e) {
      error = e;
    }
    expect(error, isA<WizarrException>());
    expect((error as WizarrException).httpStatus, 401);
    expect((error).message, contains('Unauthorized'));
  });

  test('401 with HTML body does not crash', () async {
    final adapter = _ScriptAdapter(script: [(401, '<html>login</html>')]);
    final client = _client(adapter);
    Object? error;
    try {
      await client.rpc('Invitation', 'getAll');
    } catch (e) {
      error = e;
    }
    expect(error, isA<WizarrException>());
    expect((error as WizarrException).httpStatus, 401);
  });

  test('allowlisted read returns data', () async {
    final adapter = _ScriptAdapter(
      script: [
        (200, {'invitations': [], 'count': 0}),
      ],
    );
    final client = _client(adapter);
    final data = await client.rpc('Invitation', 'getAll');
    expect(data, isA<Map>());
  });

  test('extracts int code from error envelope', () async {
    final adapter = _ScriptAdapter(
      script: [
        (
          400,
          {
            'error': {'message': 'Bad request', 'code': 42},
          },
        ),
      ],
    );
    final client = _client(adapter);
    Object? error;
    try {
      await client.rpc('Invitation', 'getAll');
    } catch (e) {
      error = e;
    }
    expect(error, isA<WizarrException>());
    expect((error as WizarrException).code, 42);
    expect(error.message, contains('Bad request'));
  });

  test('sends X-API-Key header', () async {
    final adapter = _ScriptAdapter(
      script: [
        (200, {'invitations': [], 'count': 0}),
      ],
    );
    final client = _client(adapter, apiKey: 'secret');
    await client.rpc('Invitation', 'getAll');
    expect(adapter.requests.single.headers['X-API-Key'], 'secret');
  });

  test('Invitation.create posts, Invitation.delete still throws', () async {
    final adapter = _ScriptAdapter(script: [(201, {'message': 'ok', 'invitation': {'code': 'n'}})]);
    final client = _client(
      adapter,
      apiKey: 'secret',
    );
    // post method is allowlisted and posts
    final response = await client.post('Invitation', 'create', {
      'server_ids': [1],
      'expires_in_days': 7,
      'duration': '7d',
      'unlimited': false,
      'library_ids': [],
      'allow_downloads': true,
      'allow_live_tv': true,
      'allow_mobile_uploads': true,
    });
    expect(response, isA<Map>());
    final data = response as Map<String, dynamic>;
    expect(data['message'], 'ok');
    expect((data['invitation'] as Map<String, dynamic>)['code'], 'n');

    // delete is still blocked (not in _createOnly nor _readOnly)
    expect(
      () => client.post('Invitation', 'delete'),
      throwsA(isA<StateError>()),
    );
  });

  test('400 envelope message surfaces', () async {
    final adapter = _ScriptAdapter(
      script: [(400, {'error': {'message': 'pick a server'}})],
    );
    final client = _client(adapter);
    Object? error;
    try {
      await client.post('Invitation', 'create', {});
    } catch (e) {
      error = e;
    }
    expect(error, isA<WizarrException>());
    expect((error as WizarrException).message, contains('pick a server'));
  });

  test('HTML 200 body throws WizarrException', () async {
    final adapter = _ScriptAdapter(script: [(200, '<html>login</html>')]);
    final client = _client(adapter);
    Object? error;
    try {
      await client.post('Invitation', 'create', {});
    } catch (e) {
      error = e;
    }
    expect(error, isA<WizarrException>());
  });

  test('Server.getAll and Library.getAll are allowlisted', () async {
    final adapter = _ScriptAdapter(
      script: [
        (200, {'servers': [], 'count': 0}),
        (200, {'libraries': [], 'count': 0}),
      ],
    );
    final client = _client(adapter);
    final servers = await client.rpc('Server', 'getAll');
    expect(servers, isA<Map>());
    final libraries = await client.rpc('Library', 'getAll');
    expect(libraries, isA<Map>());
  });

  test('Server.getAll and Library getAll have exact paths', () async {
    final adapter = _ScriptAdapter(
      script: [
        (200, {'servers': []}),
      ],
    );
    final client = _client(adapter);
    await client.rpc('Server', 'getAll');
    expect(adapter.requests.single.path, '/api/servers');
  });

  test('Library.getAll has exact path', () async {
    final adapter = _ScriptAdapter(
      script: [
        (200, {'libraries': []}),
      ],
    );
    final client = _client(adapter);
    await client.rpc('Library', 'getAll');
    expect(adapter.requests.single.path, '/api/libraries');
  });

  test('post uses exact path for Invitation.create', () async {
    final adapter = _ScriptAdapter(
      script: [
        (201, {'invitation': {'code': 'x'}}),
      ],
    );
    final client = _client(adapter);
    await client.post('Invitation', 'create', {});
    expect(adapter.requests.single.path, '/api/invitations');
  });

  test('post to other methods still throws StateError', () async {
    final adapter = _ScriptAdapter(script: const []);
    final client = _client(adapter);
    expect(
      () => client.post('User', 'getAll'),
      throwsStateError,
    );
    expect(adapter.callIndex, 0);
  });

  test('Invitation.getAll still works (not blocked)', () async {
    final adapter = _ScriptAdapter(
      script: [(200, {'invitations': []})],
    );
    final client = _client(adapter);
    await client.rpc('Invitation', 'getAll');
    expect(adapter.callIndex, 1);
  });
}
