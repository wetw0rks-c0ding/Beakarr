import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:seekarr/features/auth/presentation/soulsync_web_login_screen.dart';

WebViewCookie _cookie(String name, String value) =>
    WebViewCookie(name: name, value: value, domain: '.piracyhub.win');

void main() {
  group('findSoulSyncSessionCookie', () {
    test('returns the live session value when present and non-empty', () {
      expect(
        findSoulSyncSessionCookie([
          _cookie('_soulsync_proxy', ''),
          _cookie('session', 'abc123'),
        ]),
        'abc123',
      );
    });

    test('ignores the always-empty proxy placeholder alone', () {
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
