import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seekarr/core/api/api_client.dart';
import 'package:seekarr/core/api/service_auth.dart';
import 'package:seekarr/features/prowlarr/data/prowlarr_service.dart';
import 'package:seekarr/features/prowlarr/domain/models/prowlarr_search_result.dart';
import 'package:seekarr/features/services/presentation/services_provider.dart';

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
  test('results provider returns fake items for a query', () async {
    final container = ProviderContainer(
      overrides: [
        prowlarrServiceProvider.overrideWithValue(_FakeProwlarrService()),
      ],
    );
    addTearDown(container.dispose);
    container.read(prowlarrSearchQueryProvider.notifier).state = 'mad max';
    final results = await container.read(prowlarrSearchResultsProvider.future);
    expect(results.length, 3);
  });
}
