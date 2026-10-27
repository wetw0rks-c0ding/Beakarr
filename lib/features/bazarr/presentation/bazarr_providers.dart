import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seekarr/features/bazarr/data/bazarr_service.dart';
import 'package:seekarr/features/bazarr/domain/models/bazarr_series.dart';
import 'package:seekarr/features/bazarr/domain/models/bazarr_movie.dart';
import 'package:seekarr/features/bazarr/domain/models/bazarr_wanted_entry.dart';
import 'package:seekarr/features/bazarr/domain/models/bazarr_provider.dart';
import 'package:seekarr/features/bazarr/domain/models/bazarr_subtitle.dart';

final bazarrSeriesProvider = FutureProvider.autoDispose<List<BazarrSeries>>((ref) async {
  final s = ref.watch(bazarrServiceProvider);
  return s.getSeries();
});

final bazarrMoviesProvider = FutureProvider.autoDispose<List<BazarrMovie>>((ref) async {
  final s = ref.watch(bazarrServiceProvider);
  return s.getMovies();
});

final bazarrWantedMoviesProvider = FutureProvider.autoDispose<List<BazarrWantedEntry>>((ref) async => ref.watch(bazarrServiceProvider).getWantedMovies());
final bazarrWantedEpisodesProvider = FutureProvider.autoDispose<List<BazarrWantedEntry>>((ref) async => ref.watch(bazarrServiceProvider).getWantedEpisodes());
final bazarrProvidersProvider = FutureProvider.autoDispose<List<BazarrProvider>>((ref) async => ref.watch(bazarrServiceProvider).getProviders());

final bazarrEpisodeSubtitlesProvider = FutureProvider.autoDispose.family<List<BazarrSubtitle>, ({int seriesId, int season, int episode})>((ref, p) async {
  return ref.watch(bazarrServiceProvider).getEpisodeSubtitles(seriesId: p.seriesId, season: p.season, episode: p.episode);
});
final bazarrMovieSubtitlesProvider = FutureProvider.autoDispose.family<List<BazarrSubtitle>, int>((ref, movieId) async {
  return ref.watch(bazarrServiceProvider).getMovieSubtitles(movieId: movieId);
});
