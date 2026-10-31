import 'package:flutter_test/flutter_test.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_invitation.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_user.dart';

void main() {
  test('invitation tolerates missing/null/extra keys', () {
    final inv = WizarrInvitation.fromJson({'foo': 'bar'});
    expect(inv.code, isNull);
    expect(inv.inviteUrl, isNull);
    expect(inv.server, isNull);
    expect(inv.serverType, isNull);
    expect(inv.maxUses, isNull);
    expect(inv.usedCount, isNull);
    expect(inv.expiresAt, isNull);
    expect(inv.createdAt, isNull);
    expect(inv.usesLeft, isNull);
    expect(inv.isExpired, isFalse);
    expect(inv.isExhausted, isFalse);
    expect(inv.statusLabel, isNotEmpty);
  });

  test('invitation with null expiry + zero maxUses renders status', () {
    final inv = WizarrInvitation.fromJson({
      'code': 'abc',
      'maxUses': 0,
      'usedCount': 0,
    });
    expect(inv.statusLabel, isNotEmpty);
    expect(inv.usesLeft, isNull);
    expect(() => inv.statusLabel, returnsNormally);
  });

  test('invitation expiring exactly now is expired', () {
    final inv = WizarrInvitation(expiresAt: DateTime.now());
    expect(inv.isExpired, isTrue);
  });

  test('invitation parses snake_case and computes', () {
    final inv = WizarrInvitation.fromJson({
      'code': 'xyz',
      'invite_url': 'http://x/j/xyz',
      'server': 'Plex',
      'server_type': 'plex',
      'max_uses': 5,
      'used_count': 2,
      'expires_at': '2020-01-01T00:00:00Z',
      'created_at': '2019-01-01T00:00:00Z',
    });
    expect(inv.code, 'xyz');
    expect(inv.inviteUrl, 'http://x/j/xyz');
    expect(inv.maxUses, 5);
    expect(inv.usedCount, 2);
    expect(inv.usesLeft, 3);
    expect(inv.isExpired, isTrue);
    expect(inv.statusLabel, 'Expired');
  });

  test('user tolerates missing keys', () {
    final u = WizarrUser.fromJson({});
    expect(u.username, isNull);
    expect(u.server, isNull);
    expect(u.serverType, isNull);
    expect(u.email, isNull);
    expect(u.lastActiveAt, isNull);
  });

  test('user parses fields', () {
    final u = WizarrUser.fromJson({
      'username': 'bob',
      'server': 'Jellyfin',
      'server_type': 'jellyfin',
      'email': 'bob@example.com',
      'last_active_at': '2024-01-01T00:00:00Z',
    });
    expect(u.username, 'bob');
    expect(u.server, 'Jellyfin');
    expect(u.serverType, 'jellyfin');
    expect(u.email, 'bob@example.com');
    expect(u.lastActiveAt, isNotNull);
  });
}
