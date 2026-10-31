import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/openmediavault/data/openmediavault_providers.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_system_info.dart';
import 'package:seekarr/features/openmediavault/presentation/openmediavault_screen.dart';
import 'package:seekarr/features/openmediavault/presentation/widgets/omv_usage_bar.dart';

/// Regression net for the blank-screen root cause: OmvUsageBar rendered
/// with a non-null memory ratio once crashed layout (unbounded-width
/// Expanded) and blanked the whole screen in release builds. The canned
/// screen test never caught it because its fixture has no memory data.
Future<void> pumpOverview(
  WidgetTester tester,
  Map<String, dynamic> systemInfo,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        omvSystemInfoProvider.overrideWith(
          (ref) async => OmvSystemInfo.fromJson(systemInfo),
        ),
        omvFilesystemsProvider.overrideWith((ref) async => const []),
        omvDisksProvider.overrideWith((ref) async => const []),
        omvSmartDevicesProvider.overrideWith((ref) async => const []),
        omvServicesProvider.overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(home: OpenMediaVaultScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('OMV overview renders with live-shaped values', (tester) async {
    await pumpOverview(tester, const {
      'hostname': 'bertha.local',
      'version': '7.7.24-7 (Sandworm)',
      'kernel': 'Linux 6.12.85+deb12-amd64',
      'uptime': 90000.0,
      'loadAverage': {'1min': 8.56, '5min': 8.69, '15min': 8.08},
      'cpuModelName': 'Intel N100',
      'cpuCores': 4,
      'memTotal': '16777216',
      'memUsed': '12480000',
    });

    expect(find.text('bertha.local'), findsOneWidget);
    expect(find.textContaining('Sandworm'), findsOneWidget);
    expect(find.textContaining('74%'), findsOneWidget);
    expect(find.byType(OmvUsageBar), findsOneWidget);
  });

  testWidgets('OMV overview handles memory boundaries', (tester) async {
    // memTotal missing: em-dash, no usage bar (previously the crash path
    // rendered nothing at all, so absence of the bar + presence of the
    // tile is the assertion).
    await pumpOverview(tester, const {'hostname': 'bertha'});
    expect(find.text('bertha'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
    expect(find.byType(OmvUsageBar), findsNothing);
  });

  testWidgets('OMV overview renders full memory usage', (tester) async {
    await pumpOverview(tester, const {
      'hostname': 'bertha',
      'memTotal': '100',
      'memUsed': '100',
    });

    expect(find.textContaining('100%'), findsOneWidget);
    expect(find.byType(OmvUsageBar), findsOneWidget);
  });

  testWidgets('OMV overview renders zero memory usage', (tester) async {
    await pumpOverview(tester, const {
      'hostname': 'bertha',
      'memTotal': '100',
      'memUsed': '0',
    });

    expect(find.textContaining('0%'), findsOneWidget);
    expect(find.byType(OmvUsageBar), findsOneWidget);
  });

  testWidgets('OMV overview falls back to raw unparseable memory strings', (
    tester,
  ) async {
    await pumpOverview(tester, const {
      'hostname': 'bertha',
      'memTotal': 'abc',
      'memUsed': 'def',
    });

    // Defensive fallback: show the raw strings rather than crashing.
    expect(find.text('def / abc'), findsOneWidget);
    expect(find.byType(OmvUsageBar), findsNothing);
  });
}
