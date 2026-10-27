import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dio/dio.dart';
import 'package:seekarr/core/api/api_client.dart';
import 'package:seekarr/core/api/service_auth.dart';
import 'package:seekarr/features/prowlarr/data/prowlarr_service.dart';
import 'package:seekarr/features/prowlarr/domain/models/prowlarr_search_result.dart';
import 'package:seekarr/features/search/presentation/global_search_provider.dart';
import 'package:seekarr/features/search/presentation/search_screen.dart';

import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';

class _FakeProwlarrService extends ProwlarrService {
  _FakeProwlarrService()
      : super(ApiClient(baseUrl: 'http://localhost:1', auth: ApiKeyHeaderAuth('x')));

  @override
  Future<List<ProwlarrSearchResult>> search(
    String query, {
    CancelToken? cancelToken,
  }) async {
    return const [
      ProwlarrSearchResult(
        indexer: 'idx',
        indexerId: 1,
        title: 'LowSeed',
        protocol: 'torrent',
        size: 100,
        age: 10,
        seeders: 5,
        categories: [],
      ),
      ProwlarrSearchResult(
        indexer: 'idx',
        indexerId: 2,
        title: 'HighSeed',
        protocol: 'torrent',
        size: 200,
        age: 1,
        seeders: 50,
        categories: [],
      ),
      ProwlarrSearchResult(
        indexer: 'idx',
        indexerId: 3,
        title: 'NullSeed',
        protocol: 'torrent',
        size: 50,
        age: 30,
        seeders: null,
        categories: [],
      ),
    ];
  }
}

void main() {
  testWidgets('sorts prowlarr global results', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSettingsProvider.overrideWith(
            (ref) => const SettingsModel(
              prowlarrUrl: 'http://prowlarr.local:9696',
              prowlarrApiKey: 'key',
            ),
          ),
          prowlarrServiceProvider.overrideWithValue(_FakeProwlarrService()),
          globalSearchQueryProvider.overrideWith((ref) => 'x'),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    List<String> orderedTitles() {
      final titles = ['LowSeed', 'HighSeed', 'NullSeed'];
      final offsets = <String, double>{};
      for (final t in titles) {
        final finder = find.text(t);
        if (finder.evaluate().isEmpty) continue;
        offsets[t] = tester.getTopLeft(finder.first).dy;
      }
      final sorted = offsets.keys.toList()
        ..sort((a, b) => offsets[a]!.compareTo(offsets[b]!));
      return sorted;
    }

    // Size ascending
    await tester.tap(find.byIcon(Icons.sort_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Size ↑'));
    await tester.pumpAndSettle();

    expect(orderedTitles(), ['NullSeed', 'LowSeed', 'HighSeed']);

    // Seeds descending -> null last
    await tester.tap(find.byIcon(Icons.sort_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seeds ↓'));
    await tester.pumpAndSettle();

    expect(orderedTitles(), ['HighSeed', 'LowSeed', 'NullSeed']);
  });
}