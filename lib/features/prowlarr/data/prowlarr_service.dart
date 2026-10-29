import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/api/api_client.dart';
import 'package:dio/dio.dart';
import 'package:seekarr/core/api/service_auth.dart';
import 'package:seekarr/features/prowlarr/domain/models/prowlarr_health_item.dart';
import 'package:seekarr/features/prowlarr/domain/models/prowlarr_history_record.dart';
import 'package:seekarr/features/prowlarr/domain/models/prowlarr_indexer.dart';
import 'package:seekarr/features/prowlarr/domain/models/prowlarr_search_result.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/auth/data/oidc_session_service.dart';

final prowlarrServiceProvider = Provider<ProwlarrService>((ref) {
  final settings = ref.watch(currentSettingsProvider);
  if (settings.prowlarrUrl.isEmpty ||
      (settings.prowlarrApiKey.isEmpty &&
          !OidcSessionService.isArrstackMode(settings.oidcIssuer))) {
    throw Exception('Prowlarr not configured');
  }
  // Prowlarr has no per-provider login: only wire OIDC in ArrStack
  // mode, where the shared pair is valid. Otherwise the plain
  // API-key client, byte-identical to before.
  final isArrstack = OidcSessionService.isArrstackMode(settings.oidcIssuer);
  final store = ref.watch(secureSettingsStoreProvider);
  return ProwlarrService(
    ApiClient(
      baseUrl: settings.prowlarrUrl,
      auth: ApiKeyHeaderAuth(settings.prowlarrApiKey),
      serviceKey: 'prowlarr',
      session: isArrstack ? OidcSessionService(store) : null,
      issuerUrl: isArrstack ? settings.oidcIssuer : null,
      clientId: isArrstack ? settings.oidcClientId : null,
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
      final data = response.data;
      return (data as List).map((e) => ProwlarrIndexer.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        rethrow;
      }
      rethrow;
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

  /// Fetches health-check records from Prowlarr.
  Future<List<ProwlarrHealthItem>> getHealth() async {
    try {
      final response = await client.get('/api/v1/health');
      final data = response.data;
      if (data is List) {
        return data
            .map((e) => ProwlarrHealthItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        rethrow;
      }
      rethrow;
    }
  }

  /// Fetches history records (paged response).
  Future<List<ProwlarrHistoryRecord>> getHistory({
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
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final records = data['records'];
        if (records is List) {
          return records
              .map((e) => ProwlarrHistoryRecord.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      if (data is List) {
        return data
            .map((e) => ProwlarrHistoryRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        rethrow;
      }
      rethrow;
    }
  }

  /// Searches for releases using Prowlarr v1 API: GET /api/v1/search with query parameter.
  Future<List<ProwlarrSearchResult>> search(String query, {CancelToken? cancelToken}) async {
    try {
      final response = await client.get('/api/v1/search', queryParameters: {'query': query}, cancelToken: cancelToken);

      if (response.data is List) {
        return (response.data as List).map((e) => ProwlarrSearchResult.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        rethrow;
      }
      rethrow;
    }
  }

  /// Triggers a release grab using Prowlarr v1 API: POST /api/v1/search with guid and indexerId.
  Future<void> grabRelease({
    required String guid,
    required int indexerId,
  }) async {
    try {
      await client.post(
        '/api/v1/search',
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
