import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/auth/data/pkce.dart';

void main() {
  group('OIDC Token Exchange', () {
    test('generates valid PKCE code verifier and challenge', () {
      final pkce = generatePkce();
      
      expect(pkce.codeVerifier, isNotEmpty);
      expect(pkce.codeChallenge, isNotEmpty);
    });

    group('PKCE generation', () {
      test('generates unique code verifier each time', () {
        final pkce1 = generatePkce();
        final pkce2 = generatePkce();
        
        expect(pkce1.codeVerifier, isNot(equals(pkce2.codeVerifier)));
      });

      test('code challenge is base64url encoded', () {
        final pkce = generatePkce();
        
        // Check that the challenge contains only valid base64url characters
        final validChars = RegExp(r'^[A-Za-z0-9_-]*$');
        expect(pkce.codeChallenge, matches(validChars));
      });

      test('verifier and challenge have expected lengths', () {
        final pkce = generatePkce();
        
        // Verifier is 43 chars (base64url encoded 32 bytes)
        expect(pkce.codeVerifier.length, equals(43));
        // Challenge is also base64url encoded
        expect(pkce.codeChallenge.isNotEmpty, isTrue);
      });

      test('code verifier does not contain padding', () {
        final pkce = generatePkce();
        
        // The = character should be stripped for PKCE
        expect(pkce.codeVerifier.contains('='), isFalse);
      });

      test('code challenge does not contain padding', () {
        final pkce = generatePkce();
        
        // The = character should be stripped for PKCE
        expect(pkce.codeChallenge.contains('='), isFalse);
      });

      test('verifier and challenge are same length', () {
        final pkce = generatePkce();
        
        expect(pkce.codeVerifier.length, equals(pkce.codeChallenge.length));
      });
    });
  });
}
