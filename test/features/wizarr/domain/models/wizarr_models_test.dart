import 'package:flutter_test/flutter_test.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_invitation.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_user.dart';

/// Fixture matching the live Wizarr v3 `Invitation` schema
/// (`/api/swagger.json`, verified 2026-11-01) with identifying values.
const Map<String, dynamic> liveInvitation = {
  'id': 7,
  'code': 'GUEST42',
  'url': 'http://bertha:5691/j/GUEST42',
  'status': 'active',
  'created': '2026-10-20T10:00:00Z',
  'expires': '2026-11-20T10:00:00Z',
  'used_at': null,
  'used_by': null,
  'duration': '30 days',
  'unlimited': false,
  'specific_libraries': ['Movies', 'TV Shows'],
  'display_name': 'Weekend Guest',
  'server_names': ['Plex'],
  'uses_global_setting': true,
};

/// Fixture matching the live Wizarr v3 `User` schema.
const Map<String, dynamic> liveUser = {
  'id': 3,
  'username': 'guest42',
  'email': 'guest@example.com',
  'server': 'Plex',
  'server_type': 'plex',
  'expires': '2026-11-20T10:00:00Z',
  'created_at': '2026-10-20T10:00:00Z',
};

void main() {
  test('invitation tolerates missing/null/extra keys', () {
    final inv = WizarrInvitation.fromJson({'foo': 'bar'});
    expect(inv.code, isNull);
    expect(inv.inviteUrl, isNull);
    expect(inv.displayName, isNull);
    expect(inv.serverNames, isEmpty);
    expect(inv.unlimited, isFalse);
    expect(inv.expiresAt, isNull);
    expect(inv.createdAt, isNull);
    expect(inv.usesLeft, 1);
    expect(inv.isExpired, isFalse);
    expect(inv.isExhausted, isFalse);
    expect(inv.statusLabel, isNotEmpty);
  });

  test('invitation parses live v3 shape', () {
    final inv = WizarrInvitation.fromJson(liveInvitation);
    expect(inv.id, 7);
    expect(inv.code, 'GUEST42');
    expect(inv.inviteUrl, 'http://bertha:5691/j/GUEST42');
    expect(inv.status, 'active');
    expect(inv.displayName, 'Weekend Guest');
    expect(inv.serverNames, ['Plex']);
    expect(inv.unlimited, isFalse);
    expect(inv.usedAt, isNull);
    expect(inv.usedBy, isNull);
    expect(inv.duration, '30 days');
    expect(inv.usesLeft, 1);
    expect(inv.isExhausted, isFalse);
  });

  test('consumed single-use invitation is exhausted', () {
    final inv = WizarrInvitation.fromJson({
      ...liveInvitation,
      'used_at': '2026-10-21T10:00:00Z',
      'used_by': 'guest42',
    });
    expect(inv.usesLeft, 0);
    expect(inv.isExhausted, isTrue);
    expect(inv.statusLabel, 'Used up');
  });

  test('unlimited invitation never exhausts', () {
    final inv = WizarrInvitation.fromJson({
      ...liveInvitation,
      'unlimited': true,
      'used_at': '2026-10-21T10:00:00Z',
    });
    expect(inv.usesLeft, isNull);
    expect(inv.isExhausted, isFalse);
    expect(inv.statusLabel, isNot('Used up'));
  });

  test('server expired status wins over future date', () {
    final inv = WizarrInvitation.fromJson({
      ...liveInvitation,
      'status': 'expired',
    });
    expect(inv.isExpired, isTrue);
    expect(inv.statusLabel, 'Expired');
  });

  test('past expiry date marks expired', () {
    final inv = WizarrInvitation.fromJson({
      ...liveInvitation,
      'status': 'active',
      'expires': '2020-01-01T00:00:00Z',
    });
    expect(inv.isExpired, isTrue);
    expect(inv.statusLabel, 'Expired');
  });

  test('invitation expiring exactly now is expired', () {
    final inv = WizarrInvitation(expiresAt: DateTime.now());
    expect(inv.isExpired, isTrue);
  });

  test('user tolerates missing keys', () {
    final u = WizarrUser.fromJson({});
    expect(u.username, isNull);
    expect(u.server, isNull);
    expect(u.serverType, isNull);
    expect(u.email, isNull);
    expect(u.expiresAt, isNull);
    expect(u.createdAt, isNull);
  });

  test('user parses live v3 shape', () {
    final u = WizarrUser.fromJson(liveUser);
    expect(u.id, 3);
    expect(u.username, 'guest42');
    expect(u.email, 'guest@example.com');
    expect(u.server, 'Plex');
    expect(u.serverType, 'plex');
    expect(u.expiresAt, isNotNull);
    expect(u.createdAt, isNotNull);
  });
}
