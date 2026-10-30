import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seekarr/core/api/api_client.dart';
import 'package:seekarr/core/api/service_auth.dart';
import 'package:seekarr/features/prowlarr/data/prowlarr_service.dart';
import 'package:seekarr/features/prowlarr/domain/models/prowlarr_search_result.dart';
import 'package:seekarr/features/prowlarr/presentation/search_screen.dart';


/// Reproduces the on-device symptom: type "mad max", tap search,
/// expect result cards. Uses REAL captured server items.
class _FakeProwlarrService extends ProwlarrService {
  _FakeProwlarrService()
    : super(
        ApiClient(
          baseUrl: 'http://localhost:1',
          auth: ApiKeyHeaderAuth('x'),
        ),
      );

  @override
  Future<List<ProwlarrSearchResult>> search(
    String query, {
    CancelToken? cancelToken,
  }) async {
    final raw = File('test/testdata/prowlarr_madmax.json').readAsStringSync();
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => ProwlarrSearchResult.fromJson(e as Map<String, dynamic>))
        .take(3)
        .toList();
  }
}

void main() {
  testWidgets('typing mad max and tapping search shows result cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prowlarrServiceProvider.overrideWithValue(_FakeProwlarrService()),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'mad max');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    debugPrint(
      'DIAG progress=${find.byType(CircularProgressIndicator).evaluate().length} '
      'errors=${find.textContaining('Error:').evaluate().length} '
      'listviews=${find.byType(ListView).evaluate().length} '
      'cards=${find.textContaining('Mad Max').evaluate().length}',
    );
    expect(
      find.textContaining('Mad Max'),
      findsWidgets,
      reason: 'TYPING PATH: debounced typing alone should show cards',
    );
    await tester.tap(find.byIcon(Icons.search).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Mad Max'), findsWidgets);
  });
}
