import 'package:flutter_test/flutter_test.dart';
import 'package:seekarr/features/auth/data/callback_uri_helper.dart';

void main() {
  group('CallbackUriHelper', () {
    test('isCallbackUri returns true for valid callback URI', () {
      final uri = Uri.parse('seekarr://oauth/callback?code=abc123');
      expect(CallbackUriHelper.isCallbackUri(uri), isTrue);
    });

    test('isCallbackUri returns false for wrong scheme', () {
      final uri = Uri.parse('https://example.com/oauth/callback');
      expect(CallbackUriHelper.isCallbackUri(uri), isFalse);
    });

    test('isCallbackUri returns false for wrong path segments', () {
      final uri = Uri.parse('seekarr://oauth/other?code=abc123');
      expect(CallbackUriHelper.isCallbackUri(uri), isFalse);
    });

    test('isCallbackUri handles query parameters without error', () {
      final uri = Uri.parse('seekarr://oauth/callback?code=xyz789&state=abc');
      expect(CallbackUriHelper.isCallbackUri(uri), isTrue);
    });

    test('extractCode returns code from valid callback URI', () {
      final uri = Uri.parse('seekarr://oauth/callback?code=test123456');
      expect(CallbackUriHelper.extractCode(uri), equals('test123456'));
    });

    test('extractCode returns trimmed code', () {
      final uri = Uri.parse('seekarr://oauth/callback?code=  code123  ');
      expect(CallbackUriHelper.extractCode(uri), equals('code123'));
    });

    test('extractCode returns null when no code parameter', () {
      final uri = Uri.parse('seekarr://oauth/callback');
      expect(CallbackUriHelper.extractCode(uri), isNull);
    });

    test('extractError extracts error from callback URI', () {
      final uri = Uri.parse('seekarr://oauth/callback?error=invalid_grant');
      expect(CallbackUriHelper.extractError(uri), equals('invalid_grant'));
    });

    test('extractError returns null when no error parameter', () {
      final uri = Uri.parse('seekarr://oauth/callback?code=abc123');
      expect(CallbackUriHelper.extractError(uri), isNull);
    });

    test('handles lowercase scheme correctly', () {
      final uri = Uri.parse('SEEKARR://OAUTH/CALLBACK?code=xyz');
      expect(CallbackUriHelper.isCallbackUri(uri), isTrue);
    });

    test('handles URI with no path segments after callback', () {
      final uri = Uri.parse('seekarr://oauth/callback');
      expect(CallbackUriHelper.isCallbackUri(uri), isTrue);
      expect(CallbackUriHelper.extractCode(uri), isNull);
    });
  });
}
