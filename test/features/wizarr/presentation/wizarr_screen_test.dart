import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/wizarr/data/wizarr_providers.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_invitation.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_user.dart';
import 'package:seekarr/features/wizarr/presentation/wizarr_screen.dart';
import 'package:seekarr/features/wizarr/presentation/widgets/wizarr_invite_tile.dart';
import 'package:seekarr/features/wizarr/presentation/widgets/wizarr_user_tile.dart';

WizarrInvitation _liveInvite() => const WizarrInvitation(
      code: 'code-123',
      inviteUrl: 'https://example.com/j/code-123',
      server: 'Plex',
      serverType: 'plex',
      maxUses: 5,
      usedCount: 2,
      expiresAt: null,
      createdAt: null,
    );

WizarrUser _liveUser() => const WizarrUser(
      username: 'alice',
      server: 'Plex',
      serverType: 'plex',
      email: 'alice@example.com',
      lastActiveAt: null,
    );

void main() {
  testWidgets('WizarrScreen renders tabs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wizarrInvitationsProvider.overrideWith((ref) async => const []),
          wizarrUsersProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: WizarrScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Invitations'), findsOneWidget);
    expect(find.text('Users'), findsOneWidget);
  });

  testWidgets('empty state per tab', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wizarrInvitationsProvider.overrideWith((ref) async => const []),
          wizarrUsersProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: WizarrScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('No invitations'), findsOneWidget);

    await tester.tap(find.text('Users'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('No users'), findsOneWidget);
  });

  testWidgets('tab switch renders both tabs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wizarrInvitationsProvider.overrideWith((ref) async => [_liveInvite()]),
          wizarrUsersProvider.overrideWith((ref) async => [_liveUser()]),
        ],
        child: const MaterialApp(home: WizarrScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(WizarrInviteTile), findsOneWidget);

    await tester.tap(find.text('Users'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(WizarrUserTile), findsOneWidget);

    await tester.tap(find.text('Invitations'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(WizarrInviteTile), findsOneWidget);
  });

  testWidgets('live-shaped populated models render', (tester) async {
    final liveInvite = WizarrInvitation.fromJson(const {
      'code': 'live-code',
      'inviteUrl': 'https://wizarr.example.com/j/live-code',
      'invite_url': 'https://wizarr.example.com/j/live-code',
      'server': 'Jellyfin',
      'serverName': 'Jellyfin',
      'serverType': 'jellyfin',
      'server_type': 'jellyfin',
      'maxUses': 10,
      'max_uses': 10,
      'usedCount': 3,
      'used_count': 3,
      'expiresAt': '2030-01-01T00:00:00.000Z',
      'expires_at': '2030-01-01T00:00:00.000Z',
      'createdAt': '2024-01-01T00:00:00.000Z',
      'created_at': '2024-01-01T00:00:00.000Z',
    });
    final liveUser = WizarrUser.fromJson(const {
      'username': 'bob',
      'server': 'Jellyfin',
      'serverName': 'Jellyfin',
      'serverType': 'jellyfin',
      'server_type': 'jellyfin',
      'email': 'bob@example.com',
      'lastActiveAt': '2024-06-01T00:00:00.000Z',
      'last_active_at': '2024-06-01T00:00:00.000Z',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wizarrInvitationsProvider.overrideWith((ref) async => [liveInvite]),
          wizarrUsersProvider.overrideWith((ref) async => [liveUser]),
        ],
        child: const MaterialApp(home: WizarrScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(WizarrInviteTile), findsOneWidget);
    expect(find.text('live-code'), findsOneWidget);

    await tester.tap(find.text('Users'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(WizarrUserTile), findsOneWidget);
    expect(find.text('bob'), findsOneWidget);
  });
}