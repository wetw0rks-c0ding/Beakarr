import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/npm/domain/models/npm_certificate.dart';
import 'package:seekarr/features/npm/domain/models/npm_proxy_host.dart';
import 'package:seekarr/features/npm/presentation/npm_provider.dart';
import 'package:seekarr/features/npm/presentation/npm_screen.dart';
import 'package:seekarr/features/npm/presentation/widgets/npm_summary_bar.dart';

NpmProxyHost _host() => NpmProxyHost.fromJson(const {
  'id': 1,
  'domain_names': ['app.example.com'],
  'forward_scheme': 'http',
  'forward_host': 'internal',
  'forward_port': 8080,
  'enabled': 1,
  'certificate_id': 7,
});

NpmCertificate _cert() => NpmCertificate.fromJson(const {
  'id': 7,
  'provider': 'letsencrypt',
  'nice_name': 'app',
  'domain_names': ['app.example.com'],
  'expires_on': '2030-01-01T00:00:00.000Z',
});

void main() {
  testWidgets('NpmScreen renders the summary bar above the lists', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          npmHostsProvider.overrideWith((ref) async => [_host()]),
          npmCertificatesProvider.overrideWith((ref) async => [_cert()]),
        ],
        child: const MaterialApp(home: NpmScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(NpmSummaryBar), findsOneWidget);
    expect(find.textContaining('1 host'), findsOneWidget);
    expect(find.text('app.example.com'), findsWidgets);
  });
}
