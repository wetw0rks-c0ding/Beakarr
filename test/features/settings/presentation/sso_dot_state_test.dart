import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/auth/data/oidc_session_service.dart';
import 'package:seekarr/features/settings/presentation/auth_settings_screen.dart';

void main() {
  group('ssoDotStateFor', () {
    test('cached service token wins (SSO proven live)', () {
      final s = ssoDotStateFor(
        hasValidSession: true,
        identity: SessionStatus.disabled,
        hasApiKey: false,
      );
      expect(s.$1, Colors.green);
      expect(s.$2, 'Connected (SSO)');
    });

    test('active identity + api key is green (key path, SSO idle)', () {
      final s = ssoDotStateFor(
        hasValidSession: false,
        identity: SessionStatus.active,
        hasApiKey: true,
      );
      expect(s.$1, Colors.green);
      expect(s.$2, 'Connected (API key)');
    });

    test('active identity without key or token is orange', () {
      final s = ssoDotStateFor(
        hasValidSession: false,
        identity: SessionStatus.active,
        hasApiKey: false,
      );
      expect(s.$1, Colors.orange);
      expect(s.$2, 'Connecting / error');
    });

    test('error identity without key or token is orange', () {
      final s = ssoDotStateFor(
        hasValidSession: false,
        identity: SessionStatus.error,
        hasApiKey: false,
      );
      expect(s.$1, Colors.orange);
    });

    test('no identity is red even with an api key (not SSO)', () {
      final s = ssoDotStateFor(
        hasValidSession: false,
        identity: SessionStatus.disabled,
        hasApiKey: true,
      );
      expect(s.$1, Colors.red);
      expect(s.$2, 'No connection');
    });
  });
}
