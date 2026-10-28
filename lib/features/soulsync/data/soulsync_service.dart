import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/api/api_client.dart';
import 'package:seekarr/core/api/service_auth.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_profile.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_wishlist_item.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_download.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_discover_result.dart';

final soulsyncServiceProvider = Provider<SoulSyncService>((ref) {
  final settings = ref.watch(currentSettingsProvider);
  if (settings.soulsyncUrl.isEmpty || settings.soulsyncApiKey.isEmpty) {
    throw Exception('SoulSync not configured');
  }
  return SoulSyncService(
    ApiClient(
      baseUrl: settings.soulsyncUrl,
      auth: SoulSyncAuth(
        settings.soulsyncApiKey,
        profileId: settings.soulsyncProfileId,
      ),
    ),
  );
});

/// Unwraps a SoulSync `{success, data, pagination}` envelope defensively.
///
/// Tolerates bare data (list or map) and throws on a failed envelope so
/// callers can surface the failure. List endpoints swallow to [] at the
/// call site.
dynamic unwrapSoulSyncEnvelope(dynamic data) {
  if (data is Map) {
    final success = data['success'];
    if (success != null && success != true) {
      throw StateError('SoulSync request failed');
    }
    if (data.containsKey('data')) {
      return data['data'];
    }
  }
  return data;
}

List<Map<String, dynamic>> _asListOfMaps(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }
  return const <Map<String, dynamic>>[];
}

class SoulSyncService {
  final ApiClient client;

  SoulSyncService(this.client);

  Future<List<SoulSyncProfile>> getProfiles() async {
    try {
      final response = await client.get('/api/v1/profiles');
      final data = unwrapSoulSyncEnvelope(response.data);
      return _asListOfMaps(data)
          .map(SoulSyncProfile.fromJson)
          .toList(growable: false);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  Future<List<SoulSyncWishlistItem>> getWishlist() async {
    try {
      final response = await client.get('/api/v1/wishlist');
      final data = unwrapSoulSyncEnvelope(response.data);
      return _asListOfMaps(data)
          .map(SoulSyncWishlistItem.fromJson)
          .toList(growable: false);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  Future<List<SoulSyncDownload>> getDownloads() async {
    try {
      final response = await client.get('/api/v1/downloads');
      final data = unwrapSoulSyncEnvelope(response.data);
      return _asListOfMaps(data)
          .map(SoulSyncDownload.fromJson)
          .toList(growable: false);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  Future<List<SoulSyncDiscoverResult>> search(String query) async {
    // 60 req/min limit: keep search single-shot and debounce in UI.
    try {
      final response = await client.get(
        '/api/v1/discover/search',
        queryParameters: {'q': query},
      );
      final data = unwrapSoulSyncEnvelope(response.data);
      return _asListOfMaps(data)
          .map(SoulSyncDiscoverResult.fromJson)
          .toList(growable: false);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }
}
