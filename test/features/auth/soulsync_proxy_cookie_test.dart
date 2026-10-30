import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:seekarr/features/auth/presentation/soulsync_web_login_screen.dart';

WebViewCookie _cookie(String name, String value) =>
    WebViewCookie(name: name, value: value, domain: '.piracyhub.win');

void main() {
  group('findSoulSyncSessionCookie', () {
    test('returns the proxy session when minted', () {
      expect(
        findSoulSyncSessionCookie([
          _cookie('_soulsync_proxy', 'proxy123'),
          _cookie('session', 'abc123'),
        ]),
        '_soulsync_proxy=proxy123',
      );
    });

    test('ignores the app profile cookie alone (authenticates nothing)', () {
      expect(
        findSoulSyncSessionCookie([
          _cookie('_soulsync_proxy', ''),
          _cookie('session', 'abc123'),
        ]),
        isNull,
      );
    });

    test('returns null when the proxy cookie is absent', () {
      expect(
        findSoulSyncSessionCookie([_cookie('session', 'abc123')]),
        isNull,
      );
    });

    test('returns null for an empty jar', () {
      expect(findSoulSyncSessionCookie(const []), isNull,
      );
    });
  });
}
