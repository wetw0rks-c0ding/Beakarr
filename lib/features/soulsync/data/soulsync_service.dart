import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/api/api_client.dart';
import 'package:seekarr/core/api/service_auth.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_profile.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_wishlist_item.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_download.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_discover_item.dart';

final soulsyncServiceProvider = Provider<SoulSyncService>((ref) {
  final settings = ref.watch(currentSettingsProvider);
  if (settings.soulsyncUrl.isEmpty ||
      (settings.soulsyncApiKey.isEmpty && settings.soulsyncProxyCookie.isEmpty)) {
    throw Exception('SoulSync not configured');
  }
  return SoulSyncService(
    ApiClient(
      baseUrl: settings.soulsyncUrl,
      auth: SoulSyncAuth(
        settings.soulsyncApiKey,
        profileId: settings.soulsyncProfileId,
        proxyCookie: settings.soulsyncProxyCookie,
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
      'profiles',
      'artists',
      'releases',
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
      final data = _asNestedList(unwrapSoulSyncEnvelope(response.data));
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

  /// One discovery-pool page (`GET /api/v1/discover/pool`).
  ///
  /// Returns the items plus whether further pages exist. Callers page
  /// explicitly so large pools are never silently truncated.
  Future<({List<SoulSyncDiscoverItem> items, bool hasNext})>
  getDiscoveryPoolPage({int page = 1, int limit = 100}) async {
    try {
      final response = await client
          .get(
            '/api/v1/discover/pool',
            queryParameters: {'page': page, 'limit': limit},
          )
          .timeout(const Duration(seconds: 15));
      final root = response.data;
      final data = _asNestedList(unwrapSoulSyncEnvelope(root));
      final items = _asListOfMaps(
        data,
      ).map(SoulSyncDiscoverItem.fromJson).toList(growable: false);
      final pagination = root is Map ? root['pagination'] : null;
      final hasNext =
          pagination is Map && pagination['has_next'] == true;
      return (items: items, hasNext: hasNext);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  /// Discovery pool recommendations (`GET /api/v1/discover/pool`).
  ///
  /// Convenience for callers that only need the first page.
  Future<List<SoulSyncDiscoverItem>> getDiscoveryPool() async {
    final page = await getDiscoveryPoolPage();
    return page.items;
  }

  /// Similar artists (`GET /api/v1/discover/similar-artists`).
  Future<List<SoulSyncDiscoverItem>> getSimilarArtists() async {
    try {
      final response = await client
          .get('/api/v1/discover/similar-artists')
          .timeout(const Duration(seconds: 15));
      final data = _asNestedList(unwrapSoulSyncEnvelope(response.data));
      return _asListOfMaps(data)
          .map(SoulSyncDiscoverItem.fromJson)
          .toList(growable: false);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  /// Recent releases from watched artists (`GET /api/v1/discover/recent-releases`).
  Future<List<SoulSyncDiscoverItem>> getRecentReleases() async {
    try {
      final response = await client
          .get('/api/v1/discover/recent-releases')
          .timeout(const Duration(seconds: 15));
      final data = _asNestedList(unwrapSoulSyncEnvelope(response.data));
      return _asListOfMaps(data)
          .map(SoulSyncDiscoverItem.fromJson)
          .toList(growable: false);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  /// Discovery bubble snapshots (`GET /api/v1/discover/bubbles`).
  ///
  /// Shape: `data.snapshots.<type>.data.bubbles[]` (a snapshot type may be
  /// null when never generated). Each item keeps its snapshot type label.
  Future<List<SoulSyncDiscoverItem>> getDiscoveryBubbles() async {
    try {
      final response = await client
          .get('/api/v1/discover/bubbles')
          .timeout(const Duration(seconds: 15));
      final data = unwrapSoulSyncEnvelope(response.data);
      final items = <SoulSyncDiscoverItem>[];
      final snapshots =
          data is Map<String, dynamic> ? data['snapshots'] : null;
      if (snapshots is Map) {
        for (final entry in snapshots.entries) {
          final type = entry.key.toString();
          final snapshot = entry.value;
          final bubbles = snapshot is Map
              ? (snapshot['data'] is Map
                  ? (snapshot['data'] as Map)['bubbles']
                  : null)
              : null;
          if (bubbles is List) {
            for (final bubble in bubbles.whereType<Map>()) {
              items.add(
                SoulSyncDiscoverItem.fromBubble(
                  Map<String, dynamic>.from(bubble),
                  type,
                ),
              );
            }
          }
        }
      }
      return items;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }
}
