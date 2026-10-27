import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/data/settings_service.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';
import 'package:seekarr/features/settings/presentation/settings_region_screen.dart';

import '../../../test_helpers/fake_secure_settings_store.dart';

void main() {
  group('SettingsRegionScreen', () {
    testWidgets('renders the title, description, and all common regions', (
      tester,
    ) async {
      await _pumpRegionScreen(tester);

      expect(find.text('Region'), findsOneWidget);
      expect(find.textContaining('release dates'), findsOneWidget);

      expect(find.byType(RadioListTile<String>), findsWidgets);

      await tester.scrollUntilVisible(find.text('Russia (RU)'), 500);
      await tester.pumpAndSettle();

      expect(find.text('Russia (RU)'), findsOneWidget);
    });

    testWidgets('selects US by default', (tester) async {
      await _pumpRegionScreen(tester);
      final semantics = tester.ensureSemantics();

      try {
        expect(
          tester.getSemantics(_regionTile('US')),
          isSemantics(hasCheckedState: true, isChecked: true),
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('normalizes configured regions to uppercase', (tester) async {
      await _pumpRegionScreen(
        tester,
        settings: const SettingsModel(region: 'jp'),
      );
      final semantics = tester.ensureSemantics();

      try {
        await tester.scrollUntilVisible(find.text('Japan (JP)'), 300);
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(_regionTile('JP')),
          isSemantics(hasCheckedState: true, isChecked: true),
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('renders region labels in the expected format', (tester) async {
      await _pumpRegionScreen(tester);

      expect(find.text('United States (US)'), findsOneWidget);
      expect(find.text('United Kingdom (GB)'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Japan (JP)'), 300);
      await tester.pumpAndSettle();

      expect(find.text('Japan (JP)'), findsOneWidget);
    });

    testWidgets('tapping a region updates settings state', (tester) async {
      final harness = await _pumpRegionScreen(tester);
      final semantics = tester.ensureSemantics();

      try {
        await tester.scrollUntilVisible(find.text('Japan (JP)'), 300);
        await tester.tap(find.text('Japan (JP)'));
        await tester.pumpAndSettle();

        expect(harness.container.read(settingsProvider).region, 'JP');

        expect(
          tester.getSemantics(_regionTile('JP')),
          isSemantics(hasCheckedState: true, isChecked: true),
        );
      } finally {
        semantics.dispose();
      }
    });
  });
}

Future<_SettingsHarness> _pumpRegionScreen(
  WidgetTester tester, {
  SettingsModel settings = const SettingsModel(),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final service = SettingsService(prefs, FakeSecureSettingsStore());

  final container = ProviderContainer(
    overrides: [
      initialSettingsProvider.overrideWith((ref) => settings),
      settingsServiceProvider.overrideWith((ref) => service),
    ],
  );

  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsRegionScreen()),
    ),
  );
  await tester.pumpAndSettle();

  return _SettingsHarness(container);
}

Finder _regionTile(String value) {
  return find.byWidgetPredicate(
    (widget) => widget is RadioListTile<String> && widget.value == value,
  );
}

class _SettingsHarness {
  const _SettingsHarness(this.container);

  final ProviderContainer container;
}
