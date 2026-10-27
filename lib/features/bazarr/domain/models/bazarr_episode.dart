class BazarrEpisode {
  final int sonarrEpisodeId;
  final int sonarrSeriesId;
  final int season;
  final int episode;
  final String title;
  final bool monitored;
  final String? path;
  final String? sceneName;
  final List<BazarrSubtitle> subtitles;
  final Map<String, dynamic>? missingSubtitles;
  final int profileId;
  BazarrEpisode({
    required this.sonarrEpisodeId,
    required this.sonarrSeriesId,
    required this.season,
    required this.episode,
    required this.title,
    this.monitored = true,
    this.path,
    this.sceneName,
    this.subtitles = const [],
    this.missingSubtitles,
    required this.profileId,
  });
  factory BazarrEpisode.fromJson(Map<String, dynamic> j) => BazarrEpisode(
        sonarrEpisodeId: ((j['sonarrEpisodeId'] as num?) ?? 0).toInt(),
        sonarrSeriesId: ((j['sonarrSeriesId'] as num?) ?? 0).toInt(),
        season: ((j['season'] as num?) ?? 0).toInt(),
        episode: ((j['episode'] as num?) ?? 0).toInt(),
        title: (j['title'] ?? '').toString(),
        monitored: j['monitored'] == true,
        path: j['path']?.toString(),
        sceneName: j['sceneName']?.toString(),
        subtitles: ((j['subtitles'] as List<dynamic>?) ?? [])
            .map((e) => BazarrSubtitle.fromJson(e as Map<String, dynamic>))
            .toList(),
        missingSubtitles: j['missing_subtitles'] is Map ? Map<String, dynamic>.from(j['missing_subtitles']) : null,
        profileId: ((j['profileId'] as num?) ?? 0).toInt(),
      );
}
