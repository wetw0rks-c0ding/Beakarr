import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/core/api/api_client.dart';
import 'package:seekarr/core/api/service_auth.dart';
import 'package:seekarr/features/soulsync/data/soulsync_service.dart';

void main() {
  test('unwraps SoulSync envelope data', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'success': true,
          'data': [
            {'id': '1', 'title': 'Wish One'},
          ],
        }),
      );
      await request.response.close();
    });

    final service = SoulSyncService(
      ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        auth: SoulSyncAuth('sk_test', profileId: '7'),
      ),
    );

    final items = await service.getWishlist();
    expect(items, hasLength(1));
    expect(items.first.title, 'Wish One');

    await server.close();
  });

  test('failed envelope throws', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'success': false, 'data': []}));
      await request.response.close();
    });

    final service = SoulSyncService(
      ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        auth: SoulSyncAuth('sk_test'),
      ),
    );

    var threw = false;
    try {
      await service.getWishlist();
    } on StateError {
      threw = true;
    }
    expect(threw, isTrue);

    await server.close();
  });

  test('profile header is sent on requests', () async {
    String? profileHeader;
    String? authHeader;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      profileHeader = request.headers.value('x-profile-id');
      authHeader = request.headers.value('authorization');
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'success': true, 'data': []}));
      await request.response.close();
    });

    final service = SoulSyncService(
      ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        auth: SoulSyncAuth('sk_test', profileId: '42'),
      ),
    );

    await service.getWishlist();
    expect(profileHeader, '42');
    expect(authHeader, 'Bearer sk_test');

    await server.close();
  });

  test('wishlist parses nested tracks with real field names', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'success': true,
          'data': {
            'tracks': [
              {
                'id': 48561,
                'track_name': 'Your Cheatin Heart',
                'artist_name': 'Elvis Presley',
                'album_name': "Rock 'N Roll Medley, Vol. 4",
                'failure_reason': 'No matching track found',
              },
            ],
          },
        }),
      );
      await request.response.close();
    });

    final service = SoulSyncService(
      ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        auth: const SoulSyncAuth('sk_test'),
      ),
    );

    final items = await service.getWishlist();
    expect(items, hasLength(1));
    expect(items.first.title, 'Your Cheatin Heart');
    expect(items.first.artist, 'Elvis Presley');
    expect(items.first.album, "Rock 'N Roll Medley, Vol. 4");
    expect(items.first.reason, 'No matching track found');

    await server.close();
  });

  test('requestDownload posts query and returns request id', () async {
    String? method;
    String? path;
    Map<String, dynamic>? body;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      method = request.method;
      path = request.uri.path;
      final raw = await request
          .cast<List<int>>()
          .transform(const Utf8Decoder())
          .join();
      body = jsonDecode(raw) as Map<String, dynamic>;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'success': true,
          'data': {'request_id': 'req-1'},
        }),
      );
      await request.response.close();
    });

    final service = SoulSyncService(
      ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        auth: const SoulSyncAuth('sk_test'),
      ),
    );

    final requestId = await service.requestDownload('Artist - Track');
    expect(method, 'POST');
    expect(path, '/api/v1/request');
    expect(body?['query'], 'Artist - Track');
    expect(requestId, 'req-1');

    await server.close();
  });

  test('requestDownload throws on failed envelope', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'success': false,
          'data': null,
          'error': {'code': 'BAD_REQUEST', 'message': 'Missing query'},
        }),
      );
      await request.response.close();
    });

    final service = SoulSyncService(
      ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        auth: const SoulSyncAuth('sk_test'),
      ),
    );

    await expectLater(
      service.requestDownload(''),
      throwsA(isA<StateError>()),
    );

    await server.close();
  });
}
