import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/npm/domain/models/npm_certificate.dart';
import 'package:seekarr/features/npm/domain/models/npm_proxy_host.dart';
import 'package:seekarr/features/npm/presentation/npm_provider.dart';

NpmProxyHost _host(int id, List<String> domains) =>
    NpmProxyHost(id: id, domainNames: domains, enabled: true);

NpmCertificate _cert(int id, Duration fromNow) => NpmCertificate(
  id: id,
  provider: 'letsencrypt',
  niceName: 'cert-$id',
  expiresOn: DateTime.now().toUtc().add(fromNow),
);

ProviderContainer _container({
  List<NpmProxyHost> hosts = const [],
  List<NpmCertificate> certificates = const [],
}) {
  return ProviderContainer(
    overrides: [
      npmHostsProvider.overrideWith((ref) async => hosts),
      npmCertificatesProvider.overrideWith((ref) async => certificates),
    ],
  );
}

/// Reads the filtered host list after the underlying future settles.
Future<List<NpmProxyHost>> _filteredHosts(
  ProviderContainer container,
  String query,
) async {
  final subscription = container.listen(npmFilteredHostsProvider, (_, __) {});
  addTearDown(subscription.close);

  container.read(npmHostQueryProvider.notifier).state = query;
  await container.read(npmHostsProvider.future);
  await Future<void>.delayed(Duration.zero);

  return container.read(npmFilteredHostsProvider).asData?.value ?? const [];
}

void main() {
  group('npmFilteredHostsProvider', () {
    final hosts = [
      _host(1, ['app.example.com', 'www.example.com']),
      _host(2, ['media.lan']),
      _host(3, ['app-media.example.com']),
    ];

    test('returns every host for an empty query', () async {
      final container = _container(hosts: hosts);
      addTearDown(container.dispose);

      expect(await _filteredHosts(container, ''), hasLength(3));
    });

    test('filters case-insensitively across every domain name', () async {
      final container = _container(hosts: hosts);
      addTearDown(container.dispose);

      expect((await _filteredHosts(container, 'APP')).map((host) => host.id), [
        1,
        3,
      ], reason: 'app matches the primary domain of 1 and 3');
      expect(
        (await _filteredHosts(container, 'www.example')).map((host) => host.id),
        [1],
        reason: 'a secondary domain must be searchable too',
      );
    });

    test('returns no hosts when nothing matches', () async {
      final container = _container(hosts: hosts);
      addTearDown(container.dispose);

      expect(await _filteredHosts(container, 'nope'), isEmpty);
    });

    test('trims surrounding whitespace from the query', () async {
      final container = _container(hosts: hosts);
      addTearDown(container.dispose);

      expect(await _filteredHosts(container, '  media.lan  '), hasLength(1));
    });
  });

  group('npmWorstCertificateProvider', () {
    test('picks the most urgent certificate', () async {
      final container = _container(
        certificates: [
          _cert(1, const Duration(days: 100)),
          _cert(2, const Duration(days: 12)),
          _cert(3, const Duration(days: 3)),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        npmWorstCertificateProvider,
        (_, __) {},
      );
      addTearDown(subscription.close);

      await container.read(npmCertificatesProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(npmWorstCertificateProvider).asData?.value?.id, 3);
    });

    test('an expired certificate outranks everything', () async {
      final container = _container(
        certificates: [
          _cert(1, const Duration(days: 3)),
          _cert(2, const Duration(days: -2)),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        npmWorstCertificateProvider,
        (_, __) {},
      );
      addTearDown(subscription.close);

      await container.read(npmCertificatesProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(npmWorstCertificateProvider).asData?.value?.id, 2);
    });

    test('is null when every certificate is healthy', () async {
      final container = _container(
        certificates: [
          _cert(1, const Duration(days: 74)),
          _cert(2, const Duration(days: 40)),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        npmWorstCertificateProvider,
        (_, __) {},
      );
      addTearDown(subscription.close);

      await container.read(npmCertificatesProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(npmWorstCertificateProvider).asData?.value, isNull);
    });
  });

  group('npmTabProvider', () {
    test('defaults to the hosts tab', () {
      final container = _container();
      addTearDown(container.dispose);

      expect(container.read(npmTabProvider), 0);
    });
  });
}
