class BazarrSeries {
  final int sonarrSeriesId;
  final String title;
  final String year;
  final int tvdbId;
  final bool monitored;
  final String? overview;
  final String? path;
  final String? poster;
  final String? fanart;
  final int profileId;
  final String? seriesType;
  final List<String> tags;
  final int episodeFileCount;
  final int episodeMissingCount;
  final Map<String, dynamic>? audioLanguage; // object
  BazarrSeries({
    required this.sonarrSeriesId,
    required this.title,
    required this.year,
    this.tvdbId = 0,
    this.monitored = true,
    this.overview,
    this.path,
    this.poster,
    this.fanart,
    required this.profileId,
    this.seriesType,
    this.tags = const [],
    this.episodeFileCount = 0,
    this.episodeMissingCount = 0,
    this.audioLanguage,
  });
  factory BazarrSeries.fromJson(Map<String, dynamic> j) => BazarrSeries(
        sonarrSeriesId: ((j['sonarrSeriesId'] as num?) ?? 0).toInt(),
        title: (j['title'] ?? '').toString(),
        year: (j['year'] ?? '').toString(),
        tvdbId: ((j['tvdbId'] as num?) ?? 0).toInt(),
        monitored: j['monitored'] == true,
        overview: j['overview']?.toString(),
        path: j['path']?.toString(),
        poster: j['poster']?.toString(),
        fanart: j['fanart']?.toString(),
        profileId: ((j['profileId'] as num?) ?? 0).toInt(),
        seriesType: j['seriesType']?.toString(),
        tags: ((j['tags'] as List<dynamic>?) ?? []).map((e) => e.toString()).toList(),
        episodeFileCount: ((j['episodeFileCount'] as num?) ?? 0).toInt(),
        episodeMissingCount: ((j['episodeMissingCount'] as num?) ?? 0).toInt(),
        audioLanguage: j['audio_language'] is Map ? Map<String, dynamic>.from(j['audio_language']) : null,
      );
}
