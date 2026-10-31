import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/openmediavault/data/openmediavault_providers.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_system_info.dart';
import 'package:seekarr/features/openmediavault/presentation/openmediavault_screen.dart';

void main() {
  testWidgets('OMV overview renders with live-shaped values', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          omvSystemInfoProvider.overrideWith(
            (ref) async => OmvSystemInfo.fromJson(const {
              'hostname': 'bertha.local',
              'version': '7.7.24-7 (Sandworm)',
              'kernel': 'Linux 6.12.85+deb12-amd64',
              'uptime': 90000.0,
              'loadAverage': {'1min': 8.56, '5min': 8.69, '15min': 8.08},
              'cpuModelName': 'Intel N100',
              'cpuCores': 4,
              'memTotal': '16777216',
              'memUsed': '12480000',
            }),
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

    expect(find.text('bertha.local'), findsOneWidget);
    expect(find.textContaining('Sandworm'), findsOneWidget);
    expect(find.textContaining('74%'), findsOneWidget);
  });
}
