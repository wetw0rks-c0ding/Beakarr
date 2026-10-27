import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seekarr/core/api/api_client.dart';
import 'package:dio/dio.dart';
import 'package:seekarr/core/api/service_auth.dart';
import 'package:seekarr/features/bazarr/domain/models/bazarr_series.dart';
import 'package:seekarr/features/bazarr/domain/models/bazarr_episode.dart';
import 'package:seekarr/features/bazarr/domain/models/bazarr_movie.dart';
import 'package:seekarr/features/bazarr/domain/models/bazarr_subtitle.dart';
import 'package:seekarr/features/bazarr/domain/models/bazarr_provider.dart';
import 'package:seekarr/features/bazarr/domain/models/bazarr_wanted_entry.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';

final bazarrServiceProvider = Provider<BazarrService>((ref) {
  final settings = ref.watch(currentSettingsProvider);
  if (settings.bazarrUrl.isEmpty || settings.bazarrApiKey.isEmpty) {
    throw Exception('Bazarr not configured');
  }
  return BazarrService(
    ApiClient(
      baseUrl: settings.bazarrUrl,
      auth: ApiKeyHeaderAuth(settings.bazarrApiKey),
    ),
  );
});

List<dynamic> _parseEnvelopedData(dynamic data) {
  if (data is Map) {
    final d = data['data'];
    if (d is List) return d;
    return [];
  }
  if (data is List) return data; // defensive bare array
  return [];
}

class BazarrService {
  final ApiClient client;
  BazarrService(this.client);

  Future<Map<String, dynamic>> getSystemStatus() async {
    try {
      final response = await client.get('/api/system/status');
      return (response.data as Map<String, dynamic>?) ?? {};
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  // 1. LISTS ARE ENVELOPED (bazarr/api/series/series.py -> get_response_model: data + total)
  Future<List<BazarrSeries>> getSeries() async {
    try {
      final response = await client.get('/api/series');
      final items = _parseEnvelopedData(response.data);
      return items.map((e) => BazarrSeries.fromJson((e as Map<String, dynamic>?) ?? {})).toList();
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  // 4. EPISODES: /api/episodes REQUIRES seriesid[] (bazarr/api/episodes/episodes.py)
  // Returns {'data': [...]}. Our old /api/series/$id/episodes path is WRONG.
  Future<List<BazarrEpisode>> getSeriesEpisodes({required int seriesId}) async {
    try {
      final response = await client.get('/api/episodes', queryParameters: {'seriesid[]': seriesId});
      final items = _parseEnvelopedData(response.data);
      return items.map((e) => BazarrEpisode.fromJson((e as Map<String, dynamic>?) ?? {})).toList();
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  // 3. MOVIES: /api/movies -> {data[], total} (bazarr/api/movies/movies.py)
  Future<List<BazarrMovie>> getMovies() async {
    try {
      final response = await client.get('/api/movies');
      final items = _parseEnvelopedData(response.data);
      return items.map((e) => BazarrMovie.fromJson((e as Map<String, dynamic>?) ?? {})).toList();
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  // 5. WANTED movies: /api/movies/wanted -> {data[], total} (bazarr/api/movies/wanted.py)
  Future<List<BazarrWantedEntry>> getWantedMovies() async {
    try {
      final response = await client.get('/api/movies/wanted');
      final items = _parseEnvelopedData(response.data);
      return items.map((e) => BazarrWantedEntry.fromJson((e as Map<String, dynamic>?) ?? {})).toList();
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  // 5. WANTED episodes: /api/episodes/wanted -> {data[], total} (bazarr/api/episodes/wanted.py)
  Future<List<BazarrWantedEntry>> getWantedEpisodes() async {
    try {
      final response = await client.get('/api/episodes/wanted');
      final items = _parseEnvelopedData(response.data);
      return items.map((e) => BazarrWantedEntry.fromJson((e as Map<String, dynamic>?) ?? {})).toList();
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  // Subtitle embedded in episode metadata via /api/episodes with episodeid[] if needed.
  // Replaced old /api/series/$id/episodes search logic with direct episode fetch.
  Future<List<BazarrSubtitle>> getEpisodeSubtitles({required int seriesId, required int episodeId}) async {
    try {
      final response = await client.get('/api/episodes', queryParameters: {
        'seriesid[]': seriesId,
        'episodeid[]': episodeId,
      });
      final items = _parseEnvelopedData(response.data);
      for (final item in items) {
        final map = (item as Map<String, dynamic>?) ?? {};
        final subs = map['subtitles'] as List<dynamic>?;
        if (subs != null) {
          return subs.map((e) => BazarrSubtitle.fromJson((e as Map<String, dynamic>?) ?? {})).toList();
        }
      }
      return [];
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  // 7. NO per-provider search endpoint exists (verified against source files above).
  // Changed to download-best semantics. Caller passes language only.
  // Source files (episodes_subtitles.py, movies_subtitles.py) do PATCH directly.
  Future<void> downloadBestSubtitles({
    required int seriesId,
    required int episodeId,
    required String language,
    String forced = 'False',
    String hi = 'False',
  }) async {
    try {
      await client.patch('/api/episodes/subtitles', data: {
        'seriesid': seriesId,
        'episodeid': episodeId,
        'language': language,
        'forced': forced,
        'hi': hi,
      });
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  // 6. SUBTITLE DOWNLOAD (episode): PATCH /api/episodes/subtitles (bazarr/api/episodes/episodes_subtitles.py)
  Future<void> downloadEpisodeSubtitle({
    required int seriesId,
    required int episodeId,
    required String language,
    String forced = 'False',
    String hi = 'False',
  }) async {
    try {
      await client.patch('/api/episodes/subtitles', data: {
        'seriesid': seriesId,
        'episodeid': episodeId,
        'language': language,
        'forced': forced,
        'hi': hi,
      });
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  // 6. SUBTITLE DELETE (episode): DELETE /api/episodes/subtitles + path (bazarr/api/episodes/episodes_subtitles.py)
  Future<void> deleteEpisodeSubtitle({required int seriesId, required int episodeId, required String language, required String path}) async {
    try {
      await client.delete('/api/episodes/subtitles', queryParameters: {
        'seriesid': seriesId,
        'episodeid': episodeId,
        'language': language,
        'path': path,
      });
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  // Movie subtitles via /api/movies/subtitles (bazarr/api/movies/movies_subtitles.py)
  Future<void> downloadMovieSubtitle({
    required int radarrId,
    required String language,
    String forced = 'False',
    String hi = 'False',
  }) async {
    try {
      await client.patch('/api/movies/subtitles', data: {
        'radarrid': radarrId,
        'language': language,
        'forced': forced,
        'hi': hi,
      });
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  Future<void> deleteMovieSubtitle({required int radarrId, required String language, required String path}) async {
    try {
      await client.delete('/api/movies/subtitles', queryParameters: {
        'radarrid': radarrId,
        'language': language,
        'path': path,
      });
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  // 8. PROVIDERS: /api/providers -> {data[]} (bazarr/api/providers/providers.py); POST action: reset
  Future<List<BazarrProvider>> getProviders() async {
    try {
      final response = await client.get('/api/providers');
      final items = _parseEnvelopedData(response.data);
      return items.map((e) => BazarrProvider.fromJson((e as Map<String, dynamic>?) ?? {})).toList();
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  Future<void> resetProviders() async {
    try {
      await client.post('/api/providers', data: {'action': 'reset'});
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }
}
