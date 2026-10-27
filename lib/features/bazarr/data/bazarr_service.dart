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

class BazarrService {
  final ApiClient client;
  BazarrService(this.client);

  Future<Map<String, dynamic>> getSystemStatus() async {
    try {
      final response = await client.get('/api/system/status');
      return response.data as Map<String, dynamic>;
    } catch (e) { if (e is DioException && e.type == DioExceptionType.cancel) rethrow; rethrow; }
  }

  Future<List<BazarrSeries>> getSeries() async {
    try {
      final response = await client.get('/api/series');
      final data = response.data;
      if (data is List) return data.map((e) => BazarrSeries.fromJson(e as Map<String, dynamic>)).toList();
      return [];
    } catch (e) { if (e is DioException && e.type == DioExceptionType.cancel) rethrow; rethrow; }
  }

  Future<List<BazarrEpisode>> getSeriesEpisodes({required int seriesId}) async {
    try {
      final response = await client.get('/api/series/$seriesId/episodes');
      final data = response.data;
      if (data is List) return data.map((e) => BazarrEpisode.fromJson(e as Map<String, dynamic>)).toList();
      return [];
    } catch (e) { if (e is DioException && e.type == DioExceptionType.cancel) rethrow; rethrow; }
  }

  Future<List<BazarrMovie>> getMovies() async {
    try {
      final response = await client.get('/api/movies');
      final data = response.data;
      if (data is List) return data.map((e) => BazarrMovie.fromJson(e as Map<String, dynamic>)).toList();
      return [];
    } catch (e) { if (e is DioException && e.type == DioExceptionType.cancel) rethrow; rethrow; }
  }

  Future<List<BazarrWantedEntry>> getWantedMovies() async {
    try {
      final response = await client.get('/api/wanted/movies');
      final data = response.data;
      if (data is List) return data.map((e) => BazarrWantedEntry.fromJson(e as Map<String, dynamic>)).toList();
      return [];
    } catch (e) { if (e is DioException && e.type == DioExceptionType.cancel) rethrow; rethrow; }
  }

  Future<List<BazarrWantedEntry>> getWantedEpisodes() async {
    try {
      final response = await client.get('/api/wanted/episodes');
      final data = response.data;
      if (data is List) return data.map((e) => BazarrWantedEntry.fromJson(e as Map<String, dynamic>)).toList();
      return [];
    } catch (e) { if (e is DioException && e.type == DioExceptionType.cancel) rethrow; rethrow; }
  }

  Future<List<BazarrSubtitle>> getEpisodeSubtitles({required int seriesId, required int season, required int episode}) async {
    try {
      // Subtitles returned within episode metadata via documented /api/series/{id}/episodes (https://github.com/morpheus65535/bazarr)
      final response = await client.get('/api/series/$seriesId/episodes');
      final data = response.data;
      if (data is List) {
        // Find matching episode by season/episode and extract subtitles
        for (final item in data) {
          final map = item as Map<String, dynamic>;
          if (map['season'] == season && map['episode'] == episode) {
            final subs = map['subtitles'] as List<dynamic>?;
            if (subs != null) return subs.map((e) => BazarrSubtitle.fromJson(e as Map<String, dynamic>)).toList();
          }
        }
      }
      return [];
    } catch (e) { if (e is DioException && e.type == DioExceptionType.cancel) rethrow; rethrow; }
  }

  Future<List<BazarrSubtitle>> searchEpisodeSubtitles({required int seriesId, required int season, required int episode, CancelToken? cancelToken}) async {
    try {
      // Bazarr subtitle search uses query params, not nested segments (see https://wiki.bazarr.media/ + https://github.com/morpheus65535/bazarr)
      final response = await client.get('/api/subtitles/search', queryParameters: {'seriesid': seriesId, 'season': season, 'episode': episode}, cancelToken: cancelToken);
      final data = response.data;
      if (data is List) return data.map((e) => BazarrSubtitle.fromJson(e as Map<String, dynamic>)).toList();
      return [];
    } catch (e) { if (e is DioException && e.type == DioExceptionType.cancel) rethrow; rethrow; }
  }

  Future<void> downloadEpisodeSubtitle({required int seriesId, required int season, required int episode, required String language, required String provider}) async {
    try { await client.post('/api/subtitles/download', data: {'seriesid': seriesId, 'season': season, 'episode': episode, 'language': language, 'provider': provider}); } catch (e) { if (e is DioException && e.type == DioExceptionType.cancel) rethrow; rethrow; }
  }

  Future<void> deleteEpisodeSubtitle({required int seriesId, required int season, required int episode, required String language, required String provider}) async {
    try { await client.delete('/api/subtitles/delete', queryParameters: {'seriesid': seriesId, 'season': season, 'episode': episode, 'language': language, 'provider': provider}); } catch (e) { if (e is DioException && e.type == DioExceptionType.cancel) rethrow; rethrow; }
  }

  Future<List<BazarrSubtitle>> getMovieSubtitles({required int movieId}) async {
    try {
      final response = await client.get('/api/movies/$movieId/subtitles');
      final data = response.data;
      if (data is List) return data.map((e) => BazarrSubtitle.fromJson(e as Map<String, dynamic>)).toList();
      return [];
    } catch (e) { if (e is DioException && e.type == DioExceptionType.cancel) rethrow; rethrow; }
  }

  Future<List<BazarrSubtitle>> searchMovieSubtitles({required int movieId, CancelToken? cancelToken}) async {
    try {
      final response = await client.get('/api/subtitles/search', queryParameters: {'movieid': movieId}, cancelToken: cancelToken);
      final data = response.data;
      if (data is List) return data.map((e) => BazarrSubtitle.fromJson(e as Map<String, dynamic>)).toList();
      return [];
    } catch (e) { if (e is DioException && e.type == DioExceptionType.cancel) rethrow; rethrow; }
  }

  Future<void> downloadMovieSubtitle({required int movieId, required String language, required String provider}) async {
    try { await client.post('/api/subtitles/download', data: {'movieid': movieId, 'language': language, 'provider': provider}); } catch (e) { if (e is DioException && e.type == DioExceptionType.cancel) rethrow; rethrow; }
  }

  Future<void> deleteMovieSubtitle({required int movieId, required String language, required String provider}) async {
    try { await client.delete('/api/subtitles/delete', queryParameters: {'movieid': movieId, 'language': language, 'provider': provider}); } catch (e) { if (e is DioException && e.type == DioExceptionType.cancel) rethrow; rethrow; }
  }

  Future<List<BazarrProvider>> getProviders() async {
    try {
      final response = await client.get('/api/providers');
      final data = response.data;
      if (data is List) return data.map((e) => BazarrProvider.fromJson(e as Map<String, dynamic>)).toList();
      return [];
    } catch (e) { if (e is DioException && e.type == DioExceptionType.cancel) rethrow; rethrow; }
  }
}
