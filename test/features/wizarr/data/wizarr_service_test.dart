import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/wizarr/data/wizarr_client.dart';
import 'package:seekarr/features/wizarr/data/wizarr_service.dart';


class _MockAdapter implements HttpClientAdapter {
  _MockAdapter({this.data});
  dynamic data;
  final List<RequestOptions> requests = [];
  int get callCount => requests.length;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = data is String ? data : jsonEncode(data);
    return ResponseBody.fromBytes(
      utf8.encode(body),
      200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }
}

WizarrService _service(dynamic data) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
  final adapter = _MockAdapter(data: data);
  dio.httpClientAdapter = adapter;
  return WizarrService(WizarrClient(url: 'http://localhost', apiKey: 'k', dio: dio));
}

void main() {
  test('getInvitations tolerates {data:[...]} envelope', () async {
    final service = _service({
      'data': [
        {'code': 'a', 'maxUses': 2, 'usedCount': 1},
      ],
    });
    final list = await service.getInvitations();
    expect(list, hasLength(1));
    expect(list.first.code, 'a');
  });

  test('getInvitations tolerates bare array', () async {
    final service = _service([
      {'code': 'b'},
    ]);
    final list = await service.getInvitations();
    expect(list, hasLength(1));
    expect(list.first.code, 'b');
  });

  test('getInvitations tolerates {invitations:[...]} envelope', () async {
    final service = _service({
      'invitations': [
        {'code': 'c'},
      ],
      'count': 1,
    });
    final list = await service.getInvitations();
    expect(list, hasLength(1));
  });

  test('getUsers tolerates both shapes', () async {
    final s1 = _service({
      'data': [
        {'username': 'u1', 'server': 'Plex', 'server_type': 'plex'},
      ],
    });
    expect(await s1.getUsers(), hasLength(1));

    final s2 = _service([
      {'username': 'u2'},
    ]);
    expect(await s2.getUsers(), hasLength(1));
  });

  test('empty list', () async {
    final service = _service({'invitations': [], 'count': 0});
    expect(await service.getInvitations(), isEmpty);
  });
}
