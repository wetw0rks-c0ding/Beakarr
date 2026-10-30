import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:seekarr/features/auth/presentation/soulsync_web_login_screen.dart';

WebViewCookie _cookie(String name, String value) =>
    WebViewCookie(name: name, value: value, domain: '.piracyhub.win');

void main() {
  group('findSoulSyncSessionCookie', () {
    test('proxy session gates, app session travels with it', () {
      expect(
        findSoulSyncSessionCookie([
          _cookie('_soulsync_proxy', 'proxy123'),
          _cookie('session', 'abc123'),
          _cookie('color-scheme', 'dark'),
        ]),
        '_soulsync_proxy=proxy123; session=abc123',
      );
    });

    test('proxy session alone finishes', () {
      expect(
        findSoulSyncSessionCookie([_cookie('_soulsync_proxy', 'proxy123')]),
        '_soulsync_proxy=proxy123',
      );
    });

    test('stale app cookie alone never finishes (flash-close trap)', () {
      expect(
        findSoulSyncSessionCookie([
          _cookie('_soulsync_proxy', ''),
          _cookie('session', 'abc123'),
        ]),
        isNull,
      );
    });

    test('empty proxy placeholder alone never finishes', () {
      expect(
        findSoulSyncSessionCookie([
          _cookie('_soulsync_proxy', ''),
          _cookie('color-scheme', 'dark'),
        ]),
        isNull,
      );
    });

    test('returns null for an empty jar', () {
      expect(findSoulSyncSessionCookie(const []), isNull,
      );
    });
  });
}
