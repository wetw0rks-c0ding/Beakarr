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
}
