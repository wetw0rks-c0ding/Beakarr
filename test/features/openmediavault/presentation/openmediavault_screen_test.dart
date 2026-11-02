import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/openmediavault/data/openmediavault_providers.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_system_info.dart';
import 'package:seekarr/features/openmediavault/presentation/openmediavault_screen.dart';
import 'package:seekarr/features/openmediavault/presentation/widgets/omv_stat_tile.dart';

void main() {
  testWidgets('OpenMediaVaultScreen renders tabs and system info', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          omvSystemInfoProvider.overrideWith(
            (ref) async => const OmvSystemInfo(
              hostname: 'bertha',
              version: '7.4.17 (Sandworm)',
            ),
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

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Storage'), findsOneWidget);
    expect(find.text('Disks'), findsOneWidget);
    expect(find.text('Services'), findsOneWidget);
    expect(find.byType(OmvStatTile), findsWidgets);
    expect(find.text('bertha'), findsOneWidget);
  });

  testWidgets('OMV tab switcher navigates between tabs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          omvSystemInfoProvider.overrideWith(
            (ref) async => const OmvSystemInfo(
              hostname: 'bertha',
              version: '7.4.17 (Sandworm)',
            ),
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

    await tester.tap(find.text('Storage'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('No filesystems'), findsOneWidget);

    await tester.tap(find.text('Disks'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('No disks'), findsOneWidget);

    await tester.tap(find.text('Services'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('No services'), findsOneWidget);

    await tester.tap(find.text('Overview'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('bertha'), findsOneWidget);
  });
}
