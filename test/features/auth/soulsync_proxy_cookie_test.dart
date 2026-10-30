import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:seekarr/features/auth/presentation/soulsync_web_login_screen.dart';

WebViewCookie _cookie(String name, String value) =>
    WebViewCookie(name: name, value: value, domain: '.piracyhub.win');

void main() {
  group('findSoulSyncProxyCookie', () {
    test('returns the session value when present and non-empty', () {
      expect(
        findSoulSyncProxyCookie([
          _cookie('color-scheme', 'dark'),
          _cookie('_soulsync_proxy', 'abc123'),
        ]),
        'abc123',
      );
    });

    test('ignores an empty placeholder cookie (logged-out state)', () {
      expect(
        findSoulSyncProxyCookie([
          _cookie('_soulsync_proxy', ''),
          _cookie('color-scheme', 'dark'),
        ]),
        isNull,
      );
    });

    test('returns null when the cookie is absent', () {
      expect(
        findSoulSyncProxyCookie([_cookie('color-scheme', 'dark')]),
        isNull,
      );
    });

    test('returns null for an empty jar', () {
      expect(findSoulSyncProxyCookie(const []), isNull);
    });
  });
}
