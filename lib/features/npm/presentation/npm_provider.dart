import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';

import 'package:seekarr/features/npm/data/npm_service.dart';
import 'package:seekarr/features/npm/domain/cert_expiry.dart';
import 'package:seekarr/features/npm/domain/models/npm_certificate.dart';
import 'package:seekarr/features/npm/domain/models/npm_proxy_host.dart';

/// Proxy hosts, read-only. No polling: NPM changes only when the user edits
/// it, so pull-to-refresh is the refresh mechanism.
final npmHostsProvider = FutureProvider.autoDispose<List<NpmProxyHost>>((
  ref,
) async {
  final service = ref.watch(npmServiceProvider);
  return service.getProxyHosts();
});

final npmCertificatesProvider =
    FutureProvider.autoDispose<List<NpmCertificate>>((ref) async {
      final service = ref.watch(npmServiceProvider);
      return service.getCertificates();
    });

/// Hosts-tab search box.
final npmHostQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Hosts (`0`) or certificates (`1`).
final npmTabProvider = StateProvider<int>((ref) => 0);

/// [npmHostsProvider] narrowed by [npmHostQueryProvider] across every domain
/// name, case-insensitively.
final npmFilteredHostsProvider =
    Provider.autoDispose<AsyncValue<List<NpmProxyHost>>>((ref) {
      final query = ref.watch(npmHostQueryProvider).trim();
      final hosts = ref.watch(npmHostsProvider);
      if (query.isEmpty) return hosts;
      return hosts.whenData(
        (items) => items
            .where((host) => host.matchesQuery(query))
            .toList(growable: false),
      );
    });

/// The certificate that needs attention most urgently, or `null` when no
/// certificate is inside a warning window. Drives the summary chip.
final npmWorstCertificateProvider =
    Provider.autoDispose<AsyncValue<NpmCertificate?>>((ref) {
      return ref
          .watch(npmCertificatesProvider)
          .whenData(worstExpiringCertificate);
    });

/// Expired > critical (<7 d) > expiring soon (<30 d); `ok` and `unknown` do
/// not raise a chip.
NpmCertificate? worstExpiringCertificate(
  List<NpmCertificate> certificates, {
  DateTime? now,
}) {
  NpmCertificate? worst;
  var worstSeverity = 0;
  for (final certificate in certificates) {
    final severity = certExpirySeverity(certificate.expiryStatus(now: now));
    if (severity > worstSeverity) {
      worst = certificate;
      worstSeverity = severity;
    }
  }
  return worst;
}
