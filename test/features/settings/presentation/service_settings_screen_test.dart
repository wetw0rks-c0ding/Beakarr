import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/data/settings_service.dart';
import 'package:seekarr/features/settings/domain/service_key.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';
import 'package:seekarr/features/settings/presentation/service_settings_screen.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_profile.dart';

import '../../../test_helpers/fake_secure_settings_store.dart';

void main() {
  String? clipboardText;

  setUp(() {
    clipboardText = null;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final arguments = call.arguments as Map<dynamic, dynamic>?;
            clipboardText = arguments?['text'] as String?;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('ServiceSettingsScreen', () {
    testWidgets('renders the selected service title, save action, and fields', (
      tester,
    ) async {
      await _pumpServiceSettings(tester, service: ServiceKey.radarr);

      expect(find.text('Radarr Settings'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Server URL'), findsOneWidget);
      expect(find.text('API Key'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('pre-populates the URL and API key fields', (tester) async {
      await _pumpServiceSettings(
        tester,
        service: ServiceKey.radarr,
        settings: const SettingsModel(
          radarrUrl: 'https://radarr.local',
          radarrApiKey: 'radarr-key',
        ),
      );

      final urlField = tester.widget<TextField>(_fieldByLabel('Server URL'));
      final apiKeyField = tester.widget<TextField>(_fieldByLabel('API Key'));

      expect(urlField.controller?.text, 'https://radarr.local');
      expect(apiKeyField.controller?.text, 'radarr-key');
    });

    testWidgets('nzbget uses username+password fields, both required', (
      tester,
    ) async {
      await _pumpServiceSettings(
        tester,
        service: ServiceKey.nzbget,
        settings: const SettingsModel(
          nzbgetUrl: 'http://nzbget:6789',
          nzbgetUsername: 'nzuser',
          nzbgetPassword: 'nzpass',
        ),
      );

      expect(find.text('NZBGet Settings'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('API Key'), findsNothing);
      // No 'Optional' hints: both fields required.
      expect(find.text('Optional'), findsNothing);

      final urlField = tester.widget<TextField>(_fieldByLabel('Server URL'));
      final userField = tester.widget<TextField>(_fieldByLabel('Username'));
      expect(urlField.controller?.text, 'http://nzbget:6789');
      expect(userField.controller?.text, 'nzuser');
    });

    testWidgets('npm labels the identity field Email', (tester) async {
      await _pumpServiceSettings(
        tester,
        service: ServiceKey.npm,
        settings: const SettingsModel(
          npmUrl: 'http://npm:81',
          npmIdentity: 'admin@example.com',
        ),
      );

      expect(find.text('Nginx PM Settings'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('API Key'), findsNothing);
      expect(
        find.text(
          'The email you sign in to Nginx Proxy Manager with.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders the service icon in the header', (tester) async {
      await _pumpServiceSettings(tester, service: ServiceKey.lidarr);

      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    });

    testWidgets('validates that the server URL is required', (tester) async {
      await _pumpServiceSettings(tester, service: ServiceKey.radarr);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Server URL is required'), findsOneWidget);
    });

    testWidgets('validates that the API key is required', (tester) async {
      await _pumpServiceSettings(tester, service: ServiceKey.radarr);

      await tester.enterText(
        _fieldByLabel('Server URL'),
        'https://radarr.local',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('API Key is required'), findsOneWidget);
    });

    testWidgets('soulsync shows the saved profile hint without loading', (
      tester,
    ) async {
      // Regression: the profile list is transient (gone on every open),
      // which read as "the profile disappeared". The saved value must
      // stay visible even when the list never loads (unreachable host:
      // auto-load fails silently, no crash, no dropdown).
      await _pumpServiceSettings(
        tester,
        service: ServiceKey.soulsync,
        settings: const SettingsModel(
          soulsyncUrl: 'https://unreachable.invalid',
          soulsyncApiKey: 'key',
          soulsyncProfileId: '7',
        ),
      );

      expect(find.text('Saved profile: 7'), findsOneWidget);
      expect(find.text('Load profiles'), findsOneWidget);
    });

    group('resolveSoulSyncProfileSelection', () {
      SoulSyncProfile p(String id) => SoulSyncProfile(id: id, name: 'n$id');

      test('keeps the saved id when still present (no silent switch)', () {
        expect(
          resolveSoulSyncProfileSelection(
            profiles: [p('1'), p('2')],
            savedId: '2',
          ),
          '2',
        );
      });

      test('nulls a stale id missing from a fresh list (safe re-pick)', () {
        expect(
          resolveSoulSyncProfileSelection(
            profiles: [p('1'), p('2')],
            savedId: '9',
          ),
          isNull,
        );
      });

      test('auto-selects first with no saved id (fresh setup)', () {
        expect(
          resolveSoulSyncProfileSelection(
            profiles: [p('1'), p('2')],
            savedId: null,
          ),
          '1',
        );
      });

      test('failed/empty load keeps the saved id untouched', () {
        expect(
          resolveSoulSyncProfileSelection(profiles: const [], savedId: '7'),
          '7',
        );
      });
    });

    group('soulSyncDropdownValue', () {
      SoulSyncProfile p(String id) => SoulSyncProfile(id: id, name: 'n$id');

      test('passes through an id that matches a loaded item', () {
        expect(
          soulSyncDropdownValue(profiles: [p('1'), p('2')], selectedId: '2'),
          '2',
        );
      });

      test('nulls a stale id so the dropdown shows the re-pick hint', () {
        expect(
          soulSyncDropdownValue(profiles: [p('1'), p('2')], selectedId: '9'),
          isNull,
        );
      });

      test('nulls empty and null selections', () {
        expect(
          soulSyncDropdownValue(profiles: [p('1')], selectedId: null),
          isNull,
        );
        expect(
          soulSyncDropdownValue(profiles: [p('1')], selectedId: ''),
          isNull,
        );
      });
    });

    testWidgets('failed test connection never clobbers saved values', (
      tester,
    ) async {
      // Regression guard for the test-without-save trap: a failing
      // Test Connection must leave stored settings untouched (unreachable
      // host fails fast; nothing is persisted on failure).
      final harness = await _pumpServiceSettings(
        tester,
        service: ServiceKey.soulsync,
        settings: const SettingsModel(
          soulsyncUrl: 'https://unreachable.invalid',
          soulsyncApiKey: 'key',
          soulsyncProfileId: '7',
        ),
      );

      await tester.tap(find.text('Test Connection'));
      await tester.pumpAndSettle();

      expect(
        harness.container.read(settingsProvider).soulsyncProfileId,
        '7',
      );
      expect(
        harness.container.read(settingsProvider).soulsyncUrl,
        'https://unreachable.invalid',
      );
    });

    testWidgets('copy button writes the API key to the clipboard', (
      tester,
    ) async {
      await _pumpServiceSettings(
        tester,
        service: ServiceKey.radarr,
        settings: const SettingsModel(radarrApiKey: 'copy-me'),
      );

      await tester.tap(find.byTooltip('Copy API key'));
      await tester.pumpAndSettle();

      expect(clipboardText, 'copy-me');
      expect(find.text('API key copied to clipboard'), findsOneWidget);
    });

    testWidgets('save updates only the selected service and pops the route', (
      tester,
    ) async {
      final harness = await _pumpServiceSettings(
        tester,
        service: ServiceKey.sonarr,
        settings: const SettingsModel(
          radarrUrl: 'https://radarr.local',
          radarrApiKey: 'radarr-key',
          sonarrUrl: 'https://old-sonarr.local',
          sonarrApiKey: 'old-key',
        ),
      );

      await tester.enterText(
        _fieldByLabel('Server URL'),
        'https://sonarr.local',
      );
      await tester.enterText(_fieldByLabel('API Key'), 'sonarr-key');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final updated = harness.container.read(settingsProvider);
      expect(updated.radarrUrl, 'https://radarr.local');
      expect(updated.radarrApiKey, 'radarr-key');
      expect(updated.sonarrUrl, 'https://sonarr.local');
      expect(updated.sonarrApiKey, 'sonarr-key');

      expect(find.text('LauncherPage'), findsOneWidget);
      expect(find.text('Sonarr settings saved'), findsOneWidget);
    });
  });
}

Finder _fieldByLabel(String labelText) {
  return find.byWidgetPredicate((widget) {
    if (widget is! TextField) {
      return false;
    }

    return widget.decoration?.labelText == labelText;
  });
}

Future<_SettingsHarness> _pumpServiceSettings(
  WidgetTester tester, {
  required ServiceKey service,
  SettingsModel settings = const SettingsModel(),
}) async {
  final prefs = await SharedPreferences.getInstance();
  final settingsService = SettingsService(prefs, FakeSecureSettingsStore());
  final container = ProviderContainer(
    overrides: [
      initialSettingsProvider.overrideWith((ref) => settings),
      settingsServiceProvider.overrideWith((ref) => settingsService),
    ],
  );

  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: _ServiceSettingsLauncher(service: service)),
    ),
  );
  await tester.pumpAndSettle();

  return _SettingsHarness(container);
}

class _ServiceSettingsLauncher extends StatefulWidget {
  const _ServiceSettingsLauncher({required this.service});

  final ServiceKey service;

  @override
  State<_ServiceSettingsLauncher> createState() =>
      _ServiceSettingsLauncherState();
}

class _ServiceSettingsLauncherState extends State<_ServiceSettingsLauncher> {
  bool _pushed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_pushed) {
      return;
    }

    _pushed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ServiceSettingsScreen(service: widget.service),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('LauncherPage')));
  }
}

class _SettingsHarness {
  const _SettingsHarness(this.container);

  final ProviderContainer container;
}
