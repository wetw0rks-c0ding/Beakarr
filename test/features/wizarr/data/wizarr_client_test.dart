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
      headers: {Headers.contentTypeHeader: ['application/json']},
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
    final adapter = _ScriptAdapter(script: [(401, {'error': 'Unauthorized'})]);
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
    final adapter = _ScriptAdapter(script: [(200, {'invitations': [], 'count': 0})]);
    final client = _client(adapter);
    final data = await client.rpc('Invitation', 'getAll');
    expect(data, isA<Map>());
  });

  test('sends X-API-Key header', () async {
    final adapter = _ScriptAdapter(script: [(200, {'invitations': [], 'count': 0})]);
    final client = _client(adapter, apiKey: 'secret');
    await client.rpc('Invitation', 'getAll');
    expect(adapter.requests.single.headers['X-API-Key'], 'secret');
  });
}
