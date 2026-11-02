/// How close a certificate is to its expiry date.
///
/// NPM renews certificates daily and Let's Encrypt issues 90-day certs that
/// renew inside 30 days, so "inside 30 days" means the renewal is failing;
/// inside 7 days is "act now".
enum CertExpiryStatus { ok, expiringSoon, critical, expired, unknown }

/// Classifies [expiresOn] relative to [now] (defaults to `DateTime.now()`).
///
/// Comparison is done in UTC so a `now` in a non-UTC zone (or a local-time
/// `expiresOn`) cannot shift the result across a day boundary.
CertExpiryStatus certExpiryStatus(DateTime? expiresOn, {DateTime? now}) {
  if (expiresOn == null) return CertExpiryStatus.unknown;
  final remaining = expiresOn.toUtc().difference(
    (now ?? DateTime.now()).toUtc(),
  );
  if (remaining.isNegative) return CertExpiryStatus.expired;
  if (remaining.inDays < 7) return CertExpiryStatus.critical;
  if (remaining.inDays < 30) return CertExpiryStatus.expiringSoon;
  return CertExpiryStatus.ok;
}

/// Human-readable expiry text used by the certificates tab and host chip.
///
/// * `ok` — "expires in 74 d"
/// * `expiringSoon` — "expires in 12 d"
/// * `critical` — "expires in 3 d"
/// * `expired` — "expired 2 d ago"
/// * `unknown` — "no expiry data"
String certExpiryLabel(
  DateTime? expiresOn, {
  DateTime? now,
  CertExpiryStatus? status,
}) {
  if (expiresOn == null) return 'no expiry data';
  final resolved = status ?? certExpiryStatus(expiresOn, now: now);
  final remaining = expiresOn.toUtc().difference(
    (now ?? DateTime.now()).toUtc(),
  );
  if (resolved == CertExpiryStatus.expired) {
    return 'expired ${remaining.abs().inDays} d ago';
  }
  if (remaining.inDays == 0) return 'expires today';
  return 'expires in ${remaining.inDays} d';
}

/// Ordering for "worst certificate wins" chips: higher is more urgent.
///
/// [CertExpiryStatus.unknown] ranks lowest — missing expiry data must not
/// hide a certificate that is actually running out.
int certExpirySeverity(CertExpiryStatus status) {
  switch (status) {
    case CertExpiryStatus.expired:
      return 3;
    case CertExpiryStatus.critical:
      return 2;
    case CertExpiryStatus.expiringSoon:
      return 1;
    case CertExpiryStatus.ok:
      return 0;
    case CertExpiryStatus.unknown:
      return -1;
  }
}
