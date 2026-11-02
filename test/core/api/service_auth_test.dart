import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/core/api/service_auth.dart';

void main() {
  group('BasicAuth', () {
    test('encodes user:pass as a Basic header', () {
      final auth = BasicAuth('user', 'pass');

      expect(
        auth.headers()['Authorization'],
        'Basic ${base64Encode(utf8.encode('user:pass'))}',
      );
      expect(
        base64Decode(auth.headers()['Authorization']!.substring(6)),
        utf8.encode('user:pass'),
      );
    });

    test('sends no query params', () {
      expect(BasicAuth('user', 'pass').queryParams(), isEmpty);
    });

    test('encodes an empty password without crashing', () {
      final header = BasicAuth('user', '').headers()['Authorization'];

      expect(header, isNotNull);
      expect(base64Decode(header!.substring(6)), utf8.encode('user:'));
    });
  });
}
