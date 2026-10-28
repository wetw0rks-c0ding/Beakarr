import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';
import 'package:dio/dio.dart';

import 'package:seekarr/core/api/api_client.dart';
import 'package:seekarr/core/api/service_auth.dart';
import 'package:seekarr/core/utils/arr_activity_display.dart';
import 'package:seekarr/core/utils/dynamic_map_utils.dart';
import 'package:seekarr/features/discover/data/seerr_service.dart';
import 'package:seekarr/features/discover/presentation/discover_provider.dart';
import 'package:seekarr/features/movies/data/radarr_service.dart';
import 'package:seekarr/features/movies/presentation/movies_provider.dart';
import 'package:seekarr/features/music/data/lidarr_service.dart';
import 'package:seekarr/features/music/presentation/music_provider.dart';
import 'package:seekarr/features/navidrome/data/navidrome_service.dart';
import 'package:seekarr/features/soulsync/data/soulsync_service.dart';
import 'package:seekarr/features/prowlarr/data/prowlarr_service.dart';
import 'package:seekarr/features/prowlarr/domain/models/prowlarr_history_record.dart';
import 'package:seekarr/features/prowlarr/domain/models/prowlarr_indexer.dart';
import 'package:seekarr/features/prowlarr/domain/models/prowlarr_search_result.dart';
import 'package:seekarr/features/series/data/sonarr_service.dart';
import 'package:seekarr/features/series/presentation/series_provider.dart';
import 'package:seekarr/features/qbittorrent/data/qbittorrent_client.dart';
import 'package:seekarr/features/qbittorrent/presentation/qbittorrent_provider.dart';
import 'package:seekarr/features/services/domain/service_summary.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/domain/service_key.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';

final serviceSummaryProvider =
    FutureProvider.family<ServiceSummary, ServiceKey>((ref, service) async {
      final settings = ref.watch(currentSettingsProvider);
      return _loadServiceSummary(ref, service, settings);
    });

typedef ServiceStatusClientFactory =
    ApiClient Function({required String baseUrl, required ServiceAuth auth});

final serviceStatusClientFactoryProvider = Provider<ServiceStatusClientFactory>(
  (ref) =>
      ({required String baseUrl, required ServiceAuth auth}) =>
          ApiClient(baseUrl: baseUrl, auth: auth),
);

Future<ServiceSummary> _loadServiceSummary(
  Ref ref,
  ServiceKey service,
  SettingsModel settings,
) async {
  final host = service.extractHost(settings.urlFor(service)) ?? '';
  if (!settings.isServiceConfigured(service)) {
    return _offlineSummary(service, host: host);
  }

  final String? version;
  try {
    version = await _loadVersion(ref, settings, service);
  } catch (_) {
    return _offlineSummary(service, host: host);
  }

  final itemCount = await _loadItemCountOrNull(ref, service);

  return ServiceSummary(
    service: service,
    status: ServiceSummaryStatus.online,
    host: host,
    version: version,
    itemCount: itemCount,
    itemLabel: service.itemLabel,
  );
}

ServiceSummary _offlineSummary(ServiceKey service, {required String host}) {
  return ServiceSummary(
    service: service,
    status: ServiceSummaryStatus.offline,
    host: host,
    version: null,
    itemCount: null,
    itemLabel: service.itemLabel,
  );
}

Future<String?> _loadVersion(
  Ref ref,
  SettingsModel settings,
  ServiceKey service,
) async {
  if (service == ServiceKey.qbittorrent) {
    final client = QbittorrentClient(
      url: settings.qbittorrentUrl,
      username: settings.qbittorrentUsername.isNotEmpty
          ? settings.qbittorrentUsername
          : null,
      password: settings.qbittorrentPassword.isNotEmpty
          ? settings.qbittorrentPassword
          : null,
    );
    try {
      final version = await client.getVersion().timeout(
        const Duration(seconds: 5),
      );
      client.close();
      return version.isNotEmpty ? version : null;
    } catch (_) {
      client.close();
      return null;
    }
  }

  if (service == ServiceKey.navidrome) {
    final client = ApiClient(
      baseUrl: settings.navidromeUrl,
      auth: SubsonicAuth(settings.navidromeUsername, settings.navidromePassword),
    );
    try {
      final response = await client
          .get('/rest/ping.view')
          .timeout(const Duration(seconds: 5));
      final data = response.data;
      if (!isSubsonicOk(data)) {
        throw StateError('Navidrome request failed');
      }
      if (data is Map<String, dynamic>) {
        final sub = data['subsonic-response'];
        if (sub is Map<String, dynamic>) {
          return (sub['serverVersion'] ?? sub['version'])?.toString();
        }
      }
      return null;
    } catch (_) {
      rethrow;
    } finally {
      client.close();
    }
  }

  if (service == ServiceKey.soulsync) {
    final client = ApiClient(
      baseUrl: settings.soulsyncUrl,
      auth: SoulSyncAuth(
        settings.soulsyncApiKey,
        profileId: settings.soulsyncProfileId,
      ),
    );
    try {
      await client.get('/api/v1/profiles').timeout(const Duration(seconds: 5));
      return null;
    } catch (_) {
      rethrow;
    } finally {
      client.close();
    }
  }

  final createClient = ref.watch(serviceStatusClientFactoryProvider);
  final client = createClient(
    baseUrl: settings.urlFor(service),
    auth: ApiKeyHeaderAuth(settings.apiKeyFor(service)),
  );

  try {
    final response = await client
        .get(_statusEndpointFor(service))
        .timeout(const Duration(seconds: 5));
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return (data['version'] ?? data['appVersion'])?.toString();
    }
    return null;
  } finally {
    client.close();
  }
}

String _statusEndpointFor(ServiceKey service) {
  switch (service) {
    case ServiceKey.seerr:
      return '/api/v1/status';
    case ServiceKey.radarr:
    case ServiceKey.sonarr:
      return '/api/v3/system/status';
    case ServiceKey.lidarr:
      return '/api/v1/system/status';
    case ServiceKey.qbittorrent:
      return '/api/v2/app/version';
    case ServiceKey.prowlarr:
      return '/api/v1/system/status';
    case ServiceKey.bazarr:
      return '/api/system/status';
    case ServiceKey.navidrome:
      return '/rest/ping.view';
    case ServiceKey.soulsync:
      return '/api/v1/profiles';
  }
}

Future<int> _loadItemCount(Ref ref, ServiceKey service) async {
  switch (service) {
    case ServiceKey.seerr:
      return (await ref.watch(seerrServiceProvider).getRequests()).length;
    case ServiceKey.radarr:
      return (await ref.watch(radarrServiceProvider).getMovies()).length;
    case ServiceKey.sonarr:
      return (await ref.watch(sonarrServiceProvider).getSeries()).length;
    case ServiceKey.lidarr:
      return (await ref.watch(lidarrServiceProvider).getArtists()).length;
    case ServiceKey.qbittorrent:
      return (await ref.watch(qbittorrentServiceProvider).getTorrents()).length;
    case ServiceKey.prowlarr:
      // Fetch indexers and count them
      final createClient = ref.watch(serviceStatusClientFactoryProvider);
      final settings = ref.read(currentSettingsProvider);
      final client = createClient(
        baseUrl: settings.urlFor(service),
        auth: ApiKeyHeaderAuth(settings.apiKeyFor(service)),
      );
      int? count;
      try {
        final response = await client
            .get('/api/v1/indexer')
            .timeout(const Duration(seconds: 5));
        final data = response.data;
        if (data is List) {
          count = data.length;
        }
      } catch (_) {
        // Error propagated via null return
      } finally {
        client.close();
      }
      if (count == null) {
        throw StateError('Prowlarr indexer count unavailable');
      }
      return count;
    case ServiceKey.bazarr:
      final createClient = ref.watch(serviceStatusClientFactoryProvider);
      final settings = ref.read(currentSettingsProvider);
      final client = createClient(
        baseUrl: settings.urlFor(service),
        auth: ApiKeyHeaderAuth(settings.apiKeyFor(service)),
      );
      int? count;
      try {
        int wantedCount(dynamic data) {
          if (data is Map) {
            final total = data['total'];
            if (total is int) return total;
            final items = data['data'];
            if (items is List) return items.length;
            return 0;
          }
          if (data is List) return data.length;
          return 0;
        }

        final ep = await client.get('/api/episodes/wanted', queryParameters: {'start': 0, 'length': 1}).timeout(const Duration(seconds: 5));
        final mv = await client.get('/api/movies/wanted', queryParameters: {'start': 0, 'length': 1}).timeout(const Duration(seconds: 5));
        count = wantedCount(ep.data) + wantedCount(mv.data);
      } catch (_) {
        // Error propagated via null return
      } finally {
        client.close();
      }
      return count ?? 0;
    case ServiceKey.navidrome:
      final createClient = ref.watch(serviceStatusClientFactoryProvider);
      final settings = ref.read(currentSettingsProvider);
      final client = createClient(
        baseUrl: settings.navidromeUrl,
        auth: SubsonicAuth(settings.navidromeUsername, settings.navidromePassword),
      );
      int? count;
      try {
        final response = await client
            .get('/rest/getArtists.view')
            .timeout(const Duration(seconds: 5));
        final data = response.data;
        if (!isSubsonicOk(data)) {
          throw StateError('Navidrome request failed');
        }
        if (data is Map<String, dynamic>) {
          final sub = data['subsonic-response'];
          if (sub is Map<String, dynamic>) {
            final artists = sub['artists'];
            if (artists is Map<String, dynamic>) {
              final index = artists['index'];
              if (index is List) {
                count = 0;
                for (final i in index) {
                  if (i is Map<String, dynamic>) {
                    final a = i['artist'];
                    if (a is List) count = (count ?? 0) + a.length;
                  }
                }
              }
            }
          }
        }
      } catch (_) {
      } finally {
        client.close();
      }
      if (count == null) {
        throw StateError('Navidrome artist count unavailable');
      }
      return count;
    case ServiceKey.soulsync:
      try {
        return (await ref.watch(soulsyncServiceProvider).getWishlist()).length;
      } catch (_) {
        throw StateError('SoulSync wishlist count unavailable');
      }
  }
}

Future<int?> _loadItemCountOrNull(Ref ref, ServiceKey service) async {
  try {
    return await _loadItemCount(ref, service);
  } catch (_) {
    return null;
  }
}

final servicesTrendingProvider = discoverTrendingProvider;
final servicesRequestsProvider = requestsProvider;
final servicesMoviesProvider = moviesProvider;
final servicesSeriesProvider = seriesProvider;
final servicesMusicProvider = musicProvider;

// Prowlarr providers
final prowlarrIndexersProvider = FutureProvider.autoDispose<List<ProwlarrIndexer>>(
  (ref) async {
    final service = ref.watch(prowlarrServiceProvider);
    return await service.getIndexers();
  },
);

/// Current search query for the Prowlarr search screen.
final prowlarrSearchQueryProvider = StateProvider<String>((ref) => '');

/// Sort state for displayed Prowlarr search results (global search section).
enum ProwlarrSortField { seeds, size, age }

class ProwlarrSort {
  final ProwlarrSortField field;
  final bool ascending;

  const ProwlarrSort({
    this.field = ProwlarrSortField.seeds,
    this.ascending = false,
  });

  @override
  bool operator ==(Object other) =>
      other is ProwlarrSort &&
      other.field == field &&
      other.ascending == ascending;

  @override
  int get hashCode => Object.hash(field, ascending);
}

final prowlarrSortProvider = StateProvider<ProwlarrSort>(
  (ref) => const ProwlarrSort(),
);

/// Search results driven by [prowlarrSearchQueryProvider].
final prowlarrSearchResultsProvider = FutureProvider<List<ProwlarrSearchResult>>((
  ref,
) async {
  final query = ref.watch(prowlarrSearchQueryProvider).trim();
  if (query.isEmpty) {
    return const [];
  }

  final token = CancelToken();
  ref.onDispose(token.cancel);

  try {
    final service = ref.read(prowlarrServiceProvider);
    return await service.search(query, cancelToken: token);
  } on DioException catch (e) {
    if (e.type == DioExceptionType.cancel) {
      return const [];
    }
    rethrow;
  }
});

/// History records for the Prowlarr indexers screen.
final prowlarrHistoryProvider = FutureProvider.autoDispose<List<ProwlarrHistoryRecord>>((
  ref,
) async {
  final service = ref.watch(prowlarrServiceProvider);
  return await service.getHistory();
});

final radarrQueuedMovieIdsProvider = FutureProvider<Set<int>>((ref) async {
  return _loadQueuedIds(
    () => ref.watch(radarrServiceProvider).getQueue(),
    (item) => intOrNull(mapOrNull(item['movie'])?['id'] ?? item['movieId']),
  );
});

final sonarrQueuedSeriesIdsProvider = FutureProvider<Set<int>>((ref) async {
  return _loadQueuedIds(
    () => ref.watch(sonarrServiceProvider).getQueue(),
    (item) => intOrNull(mapOrNull(item['series'])?['id'] ?? item['seriesId']),
  );
});

final lidarrQueuedArtistIdsProvider = FutureProvider<Set<int>>((ref) async {
  final service = ref.watch(lidarrServiceProvider);

  try {
    final queueItems = (await service.getQueue())
        .whereType<Map>()
        .map(stringKeyMap)
        .toList(growable: false);
    final artistIds = <int>{};
    final unresolvedAlbumIds = <int>{};

    for (final item in queueItems) {
      final artistId = intOrNull(
        mapOrNull(item['artist'])?['id'] ??
            mapOrNull(item['album'])?['artistId'] ??
            item['artistId'],
      );
      if (artistId != null && artistId > 0) {
        artistIds.add(artistId);
      }

      final albumId = intOrNull(
        mapOrNull(item['album'])?['id'] ?? item['albumId'],
      );
      if (albumId != null && albumId > 0) {
        unresolvedAlbumIds.add(albumId);
      }
    }

    if (unresolvedAlbumIds.isEmpty) {
      return artistIds;
    }

    final artists = await service.getArtists();
    for (final artist in artists) {
      if (unresolvedAlbumIds.isEmpty) {
        break;
      }
      if (artist.albumCount <= 0) {
        continue;
      }

      try {
        final albums = await service.getAlbums(artist.id);
        final matchedAlbumIds = albums
            .where((album) => unresolvedAlbumIds.contains(album.id))
            .map((album) => album.id)
            .toSet();
        if (matchedAlbumIds.isEmpty) {
          continue;
        }

        artistIds.add(artist.id);
        unresolvedAlbumIds.removeAll(matchedAlbumIds);
      } catch (_) {
        continue;
      }
    }

    return artistIds;
  } catch (_) {
    return const <int>{};
  }
});

final servicesQueueProvider = FutureProvider<List<ServiceQueueItem>>((
  ref,
) async {
  final results = await Future.wait([
    _loadServiceQueueItems(ref, ServiceKey.radarr),
    _loadServiceQueueItems(ref, ServiceKey.sonarr),
  ]);

  return results.expand((items) => items).take(3).toList(growable: false);
});

class ServiceQueueItem {
  final ServiceKey service;
  final String title;
  final String subtitle;
  final double? progress;
  final String? warning;

  const ServiceQueueItem({
    required this.service,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.warning,
  });
}

Future<Set<int>> _loadQueuedIds(
  Future<List<dynamic>> Function() loadItems,
  int? Function(Map<String, dynamic> item) idExtractor,
) async {
  try {
    return (await loadItems())
        .whereType<Map>()
        .map(stringKeyMap)
        .map(idExtractor)
        .whereType<int>()
        .where((id) => id > 0)
        .toSet();
  } catch (_) {
    return const <int>{};
  }
}

Future<List<ServiceQueueItem>> _loadServiceQueueItems(
  Ref ref,
  ServiceKey service,
) async {
  try {
    final items = switch (service) {
      ServiceKey.radarr => await ref.watch(radarrServiceProvider).getQueue(),
      ServiceKey.sonarr => await ref.watch(sonarrServiceProvider).getQueue(),
      ServiceKey.prowlarr => const <dynamic>[], // No queue endpoint yet
      ServiceKey.seerr ||
      ServiceKey.lidarr ||
      ServiceKey.qbittorrent ||
      ServiceKey.bazarr ||
      ServiceKey.navidrome ||
      ServiceKey.soulsync => const <dynamic>[],
    };
    return items
        .whereType<Map>()
        .map((item) => _queueItemFromMap(service, item))
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

ServiceQueueItem _queueItemFromMap(ServiceKey service, Map item) {
  final typedItem = stringKeyMap(item);
  final title =
      arrPrimaryMediaTitle(typedItem) ??
      arrReleaseTitle(typedItem) ??
      'Unknown release';
  final quality = _queueQualityLabel(typedItem['quality']);
  final subtitle = joinDisplayParts([
    _queueTypeLabel(service),
    if (service == ServiceKey.sonarr) arrEpisodeCode(typedItem),
    quality,
    arrReleaseTitle(typedItem),
  ]);

  return ServiceQueueItem(
    service: service,
    title: title,
    subtitle: subtitle,
    progress: queueProgress(typedItem),
    warning: arrQueueWarningMessage(typedItem),
  );
}

String _queueTypeLabel(ServiceKey service) {
  return switch (service) {
    ServiceKey.radarr => 'Movie',
    ServiceKey.sonarr => 'Series',
    ServiceKey.lidarr => 'Music',
    ServiceKey.prowlarr => 'Indexer',
    ServiceKey.bazarr => 'Subtitle',
    ServiceKey.navidrome => 'Artist',
    ServiceKey.soulsync => 'Wishlist',
    ServiceKey.seerr || ServiceKey.qbittorrent => service.title,
  };
}

String? _queueQualityLabel(dynamic value) {
  if (value is Map) {
    final quality = mapOrNull(value['quality']);
    return stringOrNull(quality?['name']) ?? stringOrNull(value['name']);
  }

  return stringOrNull(value);
}
