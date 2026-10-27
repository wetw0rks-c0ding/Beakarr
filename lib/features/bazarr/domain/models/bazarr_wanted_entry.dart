class BazarrWantedEntry {
  final String type; // 'episode' or 'movie'
  final int seriesId;
  final int season;
  final int episode;
  final int movieId;
  final String title;
  BazarrWantedEntry({required this.type, this.seriesId = 0, this.season = 0, this.episode = 0, this.movieId = 0, required this.title});
  factory BazarrWantedEntry.fromJson(Map<String, dynamic> j) => BazarrWantedEntry(
        type: (j['type'] ?? '').toString(),
        seriesId: ((j['series_id'] as num?) ?? (j['seriesId'] as num?) ?? 0).toInt(),
        season: ((j['season'] as num?) ?? 0).toInt(),
        episode: ((j['episode'] as num?) ?? 0).toInt(),
        movieId: ((j['movie_id'] as num?) ?? (j['movieId'] as num?) ?? 0).toInt(),
        title: (j['title'] ?? '').toString(),
      );
}
