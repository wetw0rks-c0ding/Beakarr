import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:seekarr/features/services/domain/service_summary.dart';
import 'package:seekarr/features/services/presentation/services_status_overview.dart';
import 'package:seekarr/features/services/presentation/services_provider.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/domain/service_key.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';

/// Decisive test for the dashboard-tile navigation report: pump the REAL
/// ServiceStatusGrid (not stubs) with a REAL GoRouter, tap the Prowlarr
/// tile, and assert the route actually changes. If this passes, on-device
/// taps are ghost taps (timing/overlay), not a navigation bug.
void main() {
  testWidgets('tapping a service tile navigates to the service route', (
    tester,
  ) async {
    const settings = SettingsModel(
      prowlarrUrl: 'https://prowlarr.local:9696/',
      oidcIssuer: 'https://auth.example/application/o/arrstack/',
      oidcClientId: 'arrstack',
    );
    final summary = ServiceSummary(
      service: ServiceKey.prowlarr,
      status: ServiceSummaryStatus.offline,
      host: 'prowlarr.local:9696',
      version: null,
      itemCount: null,
      itemLabel: ServiceKey.prowlarr.itemLabel,
    );

    final router = GoRouter(
      initialLocation: '/services',
      routes: [
        GoRoute(
          path: '/services',
          builder: (_, __) => const Scaffold(body: ServiceStatusGrid()),
        ),
        GoRoute(
          path: '/services/prowlarr',
          builder: (_, __) =>
              const Scaffold(body: Text('PROWLARR-DEST-MARKER')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSettingsProvider.overrideWithValue(settings),
          serviceSummaryProvider(
            ServiceKey.prowlarr,
          ).overrideWith((ref) async => summary),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Prowlarr').first);
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/services/prowlarr');
    expect(find.text('PROWLARR-DEST-MARKER'), findsOneWidget);
  });
}
