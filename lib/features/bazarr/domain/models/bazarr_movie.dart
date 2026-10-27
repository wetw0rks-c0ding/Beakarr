class BazarrMovie {
  final int radarrId;
  final String title;
  final String year;
  final bool monitored;
  final String? overview;
  final String? path;
  final String? poster;
  final String? sceneName;
  final List<String> tags;
  final Map<String, dynamic>? missingSubtitles;
  final int profileId;
  BazarrMovie({
    required this.radarrId,
    required this.title,
    required this.year,
    this.monitored = true,
    this.overview,
    this.path,
    this.poster,
    this.sceneName,
    this.tags = const [],
    this.missingSubtitles,
    required this.profileId,
  });
  factory BazarrMovie.fromJson(Map<String, dynamic> j) => BazarrMovie(
        radarrId: ((j['radarrId'] as num?) ?? 0).toInt(),
        title: (j['title'] ?? '').toString(),
        year: (j['year'] ?? '').toString(),
        monitored: j['monitored'] == true,
        overview: j['overview']?.toString(),
        path: j['path']?.toString(),
        poster: j['poster']?.toString(),
        sceneName: j['sceneName']?.toString(),
        tags: ((j['tags'] as List<dynamic>?) ?? []).map((e) => e.toString()).toList(),
        missingSubtitles: j['missing_subtitles'] is Map ? Map<String, dynamic>.from(j['missing_subtitles']) : null,
        profileId: ((j['profileId'] as num?) ?? 0).toInt(),
      );
}
