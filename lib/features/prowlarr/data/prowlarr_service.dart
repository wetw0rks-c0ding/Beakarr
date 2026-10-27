import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/api/api_client.dart';
import 'package:dio/dio.dart';
import 'package:seekarr/core/api/service_auth.dart';
import 'package:seekarr/features/prowlarr/domain/models/prowlarr_health_item.dart';
import 'package:seekarr/features/prowlarr/domain/models/prowlarr_indexer.dart';
import 'package:seekarr/features/prowlarr/domain/models/prowlarr_search_result.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';

final prowlarrServiceProvider = Provider<ProwlarrService>((ref) {
  final settings = ref.watch(currentSettingsProvider);
  if (settings.prowlarrUrl.isEmpty || settings.prowlarrApiKey.isEmpty) {
    throw Exception('Prowlarr not configured');
  }
  return ProwlarrService(
    ApiClient(
      baseUrl: settings.prowlarrUrl,
      auth: ApiKeyHeaderAuth(settings.prowlarrApiKey),
    ),
  );
});

/// Service for interacting with Prowlarr API.
class ProwlarrService {
  final ApiClient client;

  ProwlarrService(this.client);

  /// Fetches all available indexers.
  Future<List<ProwlarrIndexer>> getIndexers() async {
    try {
      final response = await client.get('/api/v1/indexer');
      final data = response.data as List<dynamic>;
      return (data as List<Map<String, dynamic>>).map((json) {
        return ProwlarrIndexer.fromJson(json);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Enables or disables an indexer by ID.
  Future<void> setIndexerEnabled(int id, bool enabled) async {
    try {
      final response = await client.get('/api/v1/indexer/$id');
      final item = response.data as Map<String, dynamic>;
      item['enable'] = enabled;
      await client.put(
        '/api/v1/indexer/$id',
        data: item,
      );
    } catch (_) {
      rethrow;
    }
  }

  /// Fetches the health status of Prowlarr.
  Future<ProwlarrHealthItem> getHealth() async {
    try {
      final response = await client.get('/api/v1/system/status');
      return ProwlarrHealthItem.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      throw Exception('Prowlarr connection check failed');
    }
  }

  /// Fetches history records.
  Future<List<Map<String, dynamic>>> getHistory({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await client.get(
        '/api/v1/history',
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
        },
      );
      return (response.data as Map<String, dynamic>)['records'] ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Searches for releases.
  Future<List<ProwlarrSearchResult>> search(String query, {CancelToken? cancelToken}) async {
    try {
      final response = await client.post('/api/v1/indexer/search', data: {
        'query': query,
      }, cancelToken: cancelToken);

      if (response.data is List<dynamic>) {
        return (response.data as List<dynamic>)
            .map((item) => ProwlarrSearchResult.fromJson(item))
            .toList();
      } else if (response.data is Map<String, dynamic>) {
        final releases = response.data['releases'] ??
            (response.data['data'] as List<dynamic>);
        return (releases as List<Map<String, dynamic>>).map((json) {
          return ProwlarrSearchResult.fromJson(json);
        }).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Triggers a release grab for the given GUID and indexer ID.
  Future<void> grabRelease({
    required String guid,
    required int indexerId,
  }) async {
    try {
      await client.post(
        '/api/v1/release',
        data: {
          'guid': guid,
          'indexerId': indexerId,
        },
      );
    } catch (_) {
      rethrow;
    }
  }
}
