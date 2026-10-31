import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:seekarr/features/auth/presentation/soulsync_web_login_screen.dart';

WebViewCookie _cookie(String name, String value) =>
    WebViewCookie(name: name, value: value, domain: '.piracyhub.win');

void main() {
  group('findSoulSyncSessionCookie', () {
    test('captures the app session cookie when non-empty', () {
      expect(
        findSoulSyncSessionCookie([
          _cookie('_soulsync_proxy', ''),
          _cookie('session', 'abc123'),
        ]),
        'session=abc123',
      );
    });

    test('ignores the empty proxy placeholder', () {
      expect(
        findSoulSyncSessionCookie([
          _cookie('_soulsync_proxy', ''),
          _cookie('color-scheme', 'dark'),
        ]),
        isNull,
      );
    });

    test('returns null when the session cookie is absent', () {
      expect(
        findSoulSyncSessionCookie([_cookie('color-scheme', 'dark')]),
        isNull,
      );
    });

    test('returns null for an empty jar', () {
      expect(findSoulSyncSessionCookie(const []), isNull,
      );
    });
  });
}
