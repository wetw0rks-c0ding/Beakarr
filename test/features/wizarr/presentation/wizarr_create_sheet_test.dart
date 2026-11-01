import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';
import 'package:seekarr/features/wizarr/data/wizarr_client.dart';
import 'package:seekarr/features/wizarr/data/wizarr_providers.dart';
import 'package:seekarr/features/wizarr/data/wizarr_service.dart';
import 'package:seekarr/features/wizarr/data/wizarr_create_defaults.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_library.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_server.dart';
import 'package:seekarr/features/wizarr/presentation/wizarr_create_sheet.dart';

class _Adapter implements HttpClientAdapter {
  int callCount = 0;
  final List<RequestOptions> requests = [];
  Map<String, dynamic>? capturedBody;

  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    requests.add(options);
    try {
      dynamic raw = options.data;
      if (raw is String && raw.isNotEmpty) raw = jsonDecode(raw);
      if (raw is Map) capturedBody = Map<String, dynamic>.from(raw);
    } catch (_) {}
    const rb = '{"invitation":{"code":"abc","url":"/j/abc"}}';
    return ResponseBody.fromBytes(
      rb.codeUnits,
      201,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }
}

WizarrService makeService(_Adapter adapter, {String url = 'https://wizarr.example.com'}) {
  final dio = Dio(BaseOptions(baseUrl: url));
  dio.httpClientAdapter = adapter;
  return WizarrService(WizarrClient(url: url, apiKey: 'k', dio: dio));
}

WizarrService makeCustomService(
  HttpClientAdapter adapter, {
  String url = 'https://wizarr.example.com',
}) {
  final dio = Dio(BaseOptions(baseUrl: url));
  dio.httpClientAdapter = adapter;
  return WizarrService(WizarrClient(url: url, apiKey: 'k', dio: dio));
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status, this.body);
  final int status;
  final String body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(
      utf8.encode(body),
      status,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }
}

class _ThrowingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'SocketException: Connection failed (OS Error: Network is unreachable, errno = 51)',
    );
  }
}

Future<SharedPreferences> makePrefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

Future<void> pumpSheet(
  WidgetTester tester, {
  required HttpClientAdapter adapter,
  List<WizarrServer> servers = const [WizarrServer(id: 1, name: 'Plex', serverType: 'plex')],
  List<WizarrLibrary> libraries = const [],
  SharedPreferences? prefs,
}) async {
  final service = makeCustomService(adapter);
  final p = prefs ?? await makePrefs();
  await tester.pumpWidget(ProviderScope(overrides: [
    sharedPreferencesProvider.overrideWith((ref) => p),
    wizarrServiceProvider.overrideWith((ref) => service),
    wizarrServersProvider.overrideWith((ref) async => servers),
    wizarrLibrariesProvider.overrideWith((ref) async => libraries),
    currentSettingsProvider.overrideWith((ref) => SettingsModel(wizarrUrl: 'https://wizarr.example.com', wizarrApiKey: 'k')),
  ], child: const MaterialApp(home: WizarrCreateSheet())));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('empty servers state', (tester) async {
    final adapter = _Adapter();
    await pumpSheet(tester, adapter: adapter, servers: []);
    expect(find.text('No servers'), findsOneWidget);
    final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(btn.onPressed, isNull);
  });

  testWidgets('validation: tap Create with no server selected (empty list) -> no POST', (tester) async {
    final adapter = _Adapter();
    await pumpSheet(tester, adapter: adapter, servers: []);
    // button disabled; attempt tap
    await tester.tap(find.text('Create'), warnIfMissed: false);
    await tester.pump();
    expect(adapter.callCount, 0);
    expect(find.text('No servers'), findsOneWidget);
  });

  testWidgets('unlimited on disables duration and sends unlimited', (tester) async {
    final adapter = _Adapter();
    await pumpSheet(tester, adapter: adapter);
    await tester.pump();
    // find duration field
    // toggle the Unlimited switch specifically
    await tester.tap(find.widgetWithText(SwitchListTile, 'Allow downloads').first, warnIfMissed: false);
    await tester.pump();
    // Simpler: set state by tapping the Switch that follows 'Unlimited' text
    // We'll just verify field enabled status by locating TextField with label Duration
    // Toggle unlimited switch: find Switch whose ancestor contains Text('Unlimited')
    // Use a more direct approach: tap the second Switch in the tree
    // (Unlimited switch is before duration field)
    // Already toggled? Uncertain. Let's do explicit: find all Switch widgets
    final switches = find.byType(Switch);
    // The unlimited switch is the one right after 'Unlimited' label; index 0 is unlimited? permissions switches are SwitchListTile (Switch inside). Order: unlimited Switch (index0), then 3 SwitchListTile switches. So unlimited is index0.
    await tester.tap(switches.at(0));
    await tester.pump();
    // duration field should be disabled
    final durationField = tester.widget<TextField>(find.widgetWithText(TextField, 'Duration (days)'));
    expect(durationField.enabled, isFalse);
    // submit
    await tester.ensureVisible(find.text('Create'));
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(adapter.callCount, 1);
    expect(adapter.capturedBody?['duration'], 'unlimited');
  });

  testWidgets('expiry Never sends null expires_in_days', (tester) async {
    final adapter = _Adapter();
    await pumpSheet(tester, adapter: adapter);
    // select Never segment
    await tester.tap(find.text('Never'));
    await tester.pump();
    await tester.ensureVisible(find.text('Create'));
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(adapter.callCount, 1);
    expect(adapter.capturedBody?['expires_in_days'], isNull);
  });

  testWidgets('deselecting server prunes its library from submit and snapshot', (tester) async {
    final adapter = _Adapter();
    final prefs = await makePrefs();
    await pumpSheet(
      tester,
      adapter: adapter,
      servers: const [
        WizarrServer(id: 1, name: 'ServerA', serverType: 'plex'),
        WizarrServer(id: 2, name: 'ServerB', serverType: 'plex'),
      ],
      libraries: const [
        WizarrLibrary(id: 10, name: 'LibA', serverId: 1, serverName: 'ServerA'),
        WizarrLibrary(id: 20, name: 'LibB', serverId: 2, serverName: 'ServerB'),
      ],
      prefs: prefs,
    );
    // select LibA
    await tester.ensureVisible(find.text('LibA'));
    await tester.pump();
    await tester.tap(find.text('LibA'));
    await tester.pump();
    // deselect ServerA
    await tester.ensureVisible(find.text('ServerA'));
    await tester.pump();
    await tester.tap(find.text('ServerA'));
    await tester.pump();
    // submit
    await tester.ensureVisible(find.text('Create'));
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(adapter.callCount, 1);
    final libs = adapter.capturedBody?['library_ids'] as List?;
    expect(libs == null || !libs.contains(10), isTrue);
    // persisted snapshot
    final d = loadCreateDefaults(prefs);
    expect(d.libraryIds.contains(10), isFalse);
  });

  testWidgets('success shows full url and copy affordance', (tester) async {
    final adapter = _Adapter();
    await pumpSheet(tester, adapter: adapter);
    await tester.ensureVisible(find.text('Create'));
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('https://wizarr.example.com/j/abc'), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsOneWidget);
  });

  testWidgets('server error surfaces message, no crash', (tester) async {
    final adapter = _StatusAdapter(
      400,
      '{"error": {"message": "pick a server"}}',
    );
    await pumpSheet(tester, adapter: adapter);
    await tester.ensureVisible(find.text('Create'));
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('pick a server'), findsOneWidget);
  });

  testWidgets('network failure shows clean error, no internals', (
    tester,
  ) async {
    final adapter = _ThrowingAdapter();
    await pumpSheet(tester, adapter: adapter);
    await tester.ensureVisible(find.text('Create'));
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Client maps transport failures to a clean WizarrException.
    expect(find.text('Request failed'), findsOneWidget);
  });
}
