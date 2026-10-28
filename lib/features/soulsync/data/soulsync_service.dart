import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/api/api_client.dart';
import 'package:seekarr/core/api/service_auth.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_profile.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_wishlist_item.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_download.dart';

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

/// Digs one level into envelope data: SoulSync returns
/// `data: {tracks: [...]}` / `{downloads: [...]}` rather than bare lists.
dynamic _asNestedList(dynamic value) {
  if (value is List) return value;
  if (value is Map<String, dynamic>) {
    for (final key in const [
      'tracks',
      'downloads',
      'results',
      'items',
      'data',
    ]) {
      final nested = value[key];
      if (nested is List) return nested;
    }
  }
  return value;
}

class SoulSyncService {
  final ApiClient client;

  SoulSyncService(this.client);

  Future<List<SoulSyncProfile>> getProfiles() async {
    try {
      final response = await client.get('/api/v1/profiles').timeout(const Duration(seconds: 5));
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
      final response = await client.get('/api/v1/wishlist').timeout(const Duration(seconds: 5));
      final data = _asNestedList(unwrapSoulSyncEnvelope(response.data));
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
      final response = await client.get('/api/v1/downloads').timeout(const Duration(seconds: 5));
      final data = _asNestedList(unwrapSoulSyncEnvelope(response.data));
      return _asListOfMaps(data)
          .map(SoulSyncDownload.fromJson)
          .toList(growable: false);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  /// Triggers a music download (`POST /api/v1/request`).
  ///
  /// Returns the `request_id` for status polling. This is the API-key
  /// counterpart to the web UI's external-source search: the
  /// session-only `/api/enhanced-search` cannot be used with keys.
  Future<String> requestDownload(String query) async {
    try {
      final response = await client
          .post('/api/v1/request', data: {'query': query})
          .timeout(const Duration(seconds: 15));
      final data = unwrapSoulSyncEnvelope(response.data);
      if (data is Map) {
        final id = data['request_id'] ?? data['requestId'] ?? data['id'];
        if (id != null) return id.toString();
      }
      return 'Requested';
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }
}
