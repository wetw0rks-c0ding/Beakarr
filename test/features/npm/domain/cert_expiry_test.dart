import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/npm/domain/cert_expiry.dart';

void main() {
  final now = DateTime.utc(2026, 10, 31, 12);

  group('certExpiryStatus', () {
    test('null expiry is unknown', () {
      expect(certExpiryStatus(null, now: now), CertExpiryStatus.unknown);
    });

    test('more than 30 days is ok', () {
      expect(
        certExpiryStatus(
          now.add(const Duration(days: 30, minutes: 1)),
          now: now,
        ),
        CertExpiryStatus.ok,
      );
    });

    test('exactly 30 days is still ok', () {
      expect(
        certExpiryStatus(now.add(const Duration(days: 30)), now: now),
        CertExpiryStatus.ok,
      );
    });

    test('just under 30 days is expiring soon', () {
      expect(
        certExpiryStatus(
          now.add(const Duration(days: 30) - const Duration(minutes: 1)),
          now: now,
        ),
        CertExpiryStatus.expiringSoon,
      );
    });

    test('exactly 7 days is expiring soon', () {
      expect(
        certExpiryStatus(now.add(const Duration(days: 7)), now: now),
        CertExpiryStatus.expiringSoon,
      );
    });

    test('just under 7 days is critical', () {
      expect(
        certExpiryStatus(
          now.add(const Duration(days: 7) - const Duration(minutes: 1)),
          now: now,
        ),
        CertExpiryStatus.critical,
      );
    });

    test('zero remaining is critical, not expired', () {
      expect(certExpiryStatus(now, now: now), CertExpiryStatus.critical);
    });

    test('one second in the past is expired', () {
      expect(
        certExpiryStatus(now.subtract(const Duration(seconds: 1)), now: now),
        CertExpiryStatus.expired,
      );
    });

    test('days in the past are expired', () {
      expect(
        certExpiryStatus(now.subtract(const Duration(days: 45)), now: now),
        CertExpiryStatus.expired,
      );
    });

    test('compares in UTC when now is a non-UTC instant', () {
      // Same instant, different wall clock: a local-time `now` must not shift
      // the day boundary.
      final expiresOn = DateTime.utc(2026, 11, 10, 12);
      final localNow = now.toLocal();

      expect(
        certExpiryStatus(expiresOn, now: localNow),
        CertExpiryStatus.expiringSoon,
      );
    });

    test('normalises a local expiresOn to UTC', () {
      final expiresOn = now.add(const Duration(days: 3)).toLocal();
      expect(certExpiryStatus(expiresOn, now: now), CertExpiryStatus.critical);
    });
  });

  group('certExpiryLabel', () {
    test('ok reads "expires in N d"', () {
      expect(
        certExpiryLabel(now.add(const Duration(days: 74)), now: now),
        'expires in 74 d',
      );
    });

    test('expiring soon reads "expires in N d"', () {
      expect(
        certExpiryLabel(now.add(const Duration(days: 12)), now: now),
        'expires in 12 d',
      );
    });

    test('critical reads "expires in N d"', () {
      expect(
        certExpiryLabel(now.add(const Duration(days: 3)), now: now),
        'expires in 3 d',
      );
    });

    test('same-day expiry reads "expires today"', () {
      expect(
        certExpiryLabel(now.add(const Duration(hours: 5)), now: now),
        'expires today',
      );
    });

    test('expired reads "expired N d ago"', () {
      expect(
        certExpiryLabel(now.subtract(const Duration(days: 2)), now: now),
        'expired 2 d ago',
      );
    });

    test('unknown reads "no expiry data"', () {
      expect(certExpiryLabel(null, now: now), 'no expiry data');
    });

    test('accepts a precomputed status', () {
      expect(
        certExpiryLabel(
          now.add(const Duration(days: 12)),
          now: now,
          status: CertExpiryStatus.expired,
        ),
        'expired 12 d ago',
      );
    });
  });

  group('certExpirySeverity', () {
    test('orders expired above critical above expiring soon above ok', () {
      expect(
        certExpirySeverity(CertExpiryStatus.expired),
        greaterThan(certExpirySeverity(CertExpiryStatus.critical)),
      );
      expect(
        certExpirySeverity(CertExpiryStatus.critical),
        greaterThan(certExpirySeverity(CertExpiryStatus.expiringSoon)),
      );
      expect(
        certExpirySeverity(CertExpiryStatus.expiringSoon),
        greaterThan(certExpirySeverity(CertExpiryStatus.ok)),
      );
      expect(
        certExpirySeverity(CertExpiryStatus.unknown),
        lessThan(certExpirySeverity(CertExpiryStatus.ok)),
      );
    });
  });
}
