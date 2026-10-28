import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/auth/data/oidc_loopback_listener.dart';

void main() {
  test('loopback listener returns the authorization code', () async {
    final future = OidcLoopbackListener.awaitCode(
      timeout: const Duration(seconds: 10),
    );
    final client = HttpClient();
    try {
      final req = await client.getUrl(
        Uri.parse('${OidcLoopbackListener.redirectUri}?code=abc123'),
      );
      final res = await req.close();
      expect(res.statusCode, HttpStatus.ok);
      await res.drain<void>();
    } finally {
      client.close();
    }
    expect(await future, 'abc123');
  });

  test('loopback listener surfaces provider error', () async {
    // Attach the error handler synchronously: a future that completes with
    // an error before any listener subscribes is reported to the zone as
    // unhandled even if awaited later.
    Object? caught;
    final future = OidcLoopbackListener.awaitCode(
      timeout: const Duration(seconds: 10),
    ).then<void>((_) {}, onError: (Object e) {
      caught = e;
    });
    final client = HttpClient();
    try {
      final req = await client.getUrl(
        Uri.parse('${OidcLoopbackListener.redirectUri}?error=access_denied'),
      );
      final res = await req.close();
      await res.drain<void>();
    } finally {
      client.close();
    }
    await future;
    expect(caught, isA<Exception>());
  });
}
