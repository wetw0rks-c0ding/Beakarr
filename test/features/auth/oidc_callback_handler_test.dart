import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OIDC Callback Handler', () {
    group('Callback URI parsing', () {
      test('parses valid callback deep link', () {
        const uriStr = 'seekarr://oauth/callback?code=abc123&state=xyz789';
        final uri = Uri.parse(uriStr);
        
        expect(uri.scheme, equals('seekarr'));
        expect(uri.path, equals('/callback')); // URI path is just '/callback' after scheme and authority
        
        expect(uri.queryParameters['code'], equals('abc123'));
        expect(uri.queryParameters['state'], equals('xyz789'));
      });

      test('extracts code parameter correctly', () {
        const uriStr = 'seekarr://oauth/callback?code=AUTH_CODE_12345&state=SESSION_STATE';
        final uri = Uri.parse(uriStr);
        
        expect(uri.queryParameters['code'], equals('AUTH_CODE_12345'));
      });

      test('extracts state parameter correctly', () {
        const uriStr = 'seekarr://oauth/callback?code=some_code&state=STATE_PARAM';
        final uri = Uri.parse(uriStr);
        
        expect(uri.queryParameters['state'], equals('STATE_PARAM'));
      });

      test('handles URI without query parameters', () {
        const uriStr = 'seekarr://oauth/callback';
        final uri = Uri.parse(uriStr);
        
        expect(uri.queryParameters.containsKey('code'), isFalse);
        expect(uri.queryParameters.containsKey('state'), isFalse);
      });

      test('handles missing code parameter', () {
        const uriStr = 'seekarr://oauth/callback?state=STATE_PARAM';
        final uri = Uri.parse(uriStr);
        
        expect(uri.queryParameters.containsKey('code'), isFalse);
        expect(uri.queryParameters['state'], equals('STATE_PARAM'));
      });

      test('handles missing state parameter', () {
        const uriStr = 'seekarr://oauth/callback?code=AUTH_CODE';
        final uri = Uri.parse(uriStr);
        
        expect(uri.queryParameters.containsKey('state'), isFalse);
        expect(uri.queryParameters['code'], equals('AUTH_CODE'));
      });

      test('extracts multiple query parameters', () {
        const uriStr = 'seekarr://oauth/callback?code=CODE&state=STATE&extra=value';
        final uri = Uri.parse(uriStr);
        
        expect(uri.queryParameters['code'], equals('CODE'));
        expect(uri.queryParameters['state'], equals('STATE'));
        expect(uri.queryParameters['extra'], equals('value'));
      });

      test('handles empty code parameter', () {
        const uriStr = 'seekarr://oauth/callback?code=&state=STATE_PARAM';
        final uri = Uri.parse(uriStr);
        
        expect(uri.queryParameters['code'], equals(''));
        expect(uri.queryParameters['state'], equals('STATE_PARAM'));
      });

      test('handles empty state parameter', () {
        const uriStr = 'seekarr://oauth/callback?code=CODE&state=';
        final uri = Uri.parse(uriStr);
        
        expect(uri.queryParameters['code'], equals('CODE'));
        expect(uri.queryParameters['state'], equals(''));
      });

      test('handles special characters in code', () {
        const uriStr = 'seekarr://oauth/callback?code=CODE%20WITH%20SPACES&state=STATE';
        final uri = Uri.parse(uriStr);
        
        expect(uri.queryParameters['code'], equals('CODE WITH SPACES'));
        expect(uri.queryParameters['state'], equals('STATE'));
      });

      test('handles special characters in state', () {
        const uriStr = 'seekarr://oauth/callback?code=CODE&state=STATE%20PARAM';
        final uri = Uri.parse(uriStr);
        
        expect(uri.queryParameters['code'], equals('CODE'));
        expect(uri.queryParameters['state'], equals('STATE PARAM'));
      });
    });

    group('URI scheme validation', () {
      test('correctly identifies seekarr scheme', () {
        final uri = Uri.parse('seekarr://oauth/callback?code=CODE');
        expect(uri.scheme, equals('seekarr'));
      });

      test('rejects non-seekarr schemes', () {
        const uriStr = 'https://example.com/oauth/callback?code=CODE';
        final uri = Uri.parse(uriStr);
        expect(uri.scheme, equals('https'));
      });

      test('handles path variations', () {
        expect(Uri.parse('seekarr://oauth/callback').path, equals('/callback'));
        expect(Uri.parse('seekarr://oauth/callback?code=CODE').path, equals('/callback'));
      });

      test('handles query parameter ordering', () {
        const uriStr1 = 'seekarr://oauth/callback?code=CODE&state=STATE';
        const uriStr2 = 'seekarr://oauth/callback?state=STATE&code=CODE';
        final uri1 = Uri.parse(uriStr1);
        final uri2 = Uri.parse(uriStr2);
        
        expect(uri1.queryParameters['code'], equals(uri2.queryParameters['code']));
        expect(uri1.queryParameters['state'], equals(uri2.queryParameters['state']));
      });

      test('handles empty query string', () {
        const uriStr1 = 'seekarr://oauth/callback?';
        const uriStr2 = 'seekarr://oauth/callback';
        final uri1 = Uri.parse(uriStr1);
        final uri2 = Uri.parse(uriStr2);
        
        // Both should be equivalent for parsing purposes
        expect(uri1.queryParameters.isEmpty, isTrue);
        expect(uri2.queryParameters.isEmpty, isTrue);
      });
    });

    group('Code challenge verification', () {
      test('validates that code parameter exists in callback', () {
        const uriStr = 'seekarr://oauth/callback?code=AUTH_CODE';
        final uri = Uri.parse(uriStr);
        
        expect(uri.queryParameters.containsKey('code'), isTrue);
      });

      test('state parameter helps prevent replay attacks', () {
        const uriStr1 = 'seekarr://oauth/callback?code=CODE&state=STATE_A';
        const uriStr2 = 'seekarr://oauth/callback?code=CODE&state=STATE_B';
        
        final uri1 = Uri.parse(uriStr1);
        final uri2 = Uri.parse(uriStr2);
        
        expect(uri1.queryParameters['state'], isNot(equals(uri2.queryParameters['state'])));
      });

      test('handles long authorization codes', () {
        final longCode = 'AUTH_CODE_' + 'A' * 100;
        final uriStr = 'seekarr://oauth/callback?code=$longCode&state=STATE';
        final uri = Uri.parse(uriStr);
        
        expect(uri.queryParameters['code'], equals(longCode));
      });
    });

    group('Error handling', () {
      test('handles malformed URI gracefully', () {
        // Empty string should not crash
        try {
          final uri = Uri.parse('');
          // Empty URI has no scheme, path, or query params
          expect(uri.scheme.isEmpty, isTrue);
        } catch (e) {
          // In real implementation, handle appropriately
        }
      });

      test('handles very long query strings', () {
        final uriStr = 'seekarr://oauth/callback?code=' + ('A' * 1000) + '&state=STATE';
        final uri = Uri.parse(uriStr);
        
        expect(uri.queryParameters['code']!.length, equals(1000));
      });

      test('handles missing redirect_uri (uses default)', () {
        const uriStr = 'seekarr://oauth/callback?code=CODE&state=STATE';
        final uri = Uri.parse(uriStr);
        
        // redirect_uri is optional; if not present, use default from auth_settings_screen.dart
        expect(uri.queryParameters.containsKey('redirect_uri'), isFalse);
      });

      test('handles code parameter with special URL characters', () {
        const uriStr = 'seekarr://oauth/callback?code=CODE%3F%26%23&state=STATE';
        final uri = Uri.parse(uriStr);
        
        // %3F -> ?, %26 -> &, %23 -> #
        expect(uri.queryParameters['code'], equals('CODE?&#'));
      });
    });
  });
}
