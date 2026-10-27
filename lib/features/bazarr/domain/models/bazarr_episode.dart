import 'bazarr_subtitle.dart';
class BazarrEpisode {
  final int seriesId;
  final int season;
  final int episode;
  final String title;
  final List<BazarrSubtitle> subtitles;
  BazarrEpisode({required this.seriesId, required this.season, required this.episode, required this.title, this.subtitles = const []});
  factory BazarrEpisode.fromJson(Map<String, dynamic> j) {
    final rawSubs = j['subtitles'] ?? j['subtitle'] ?? [];
    return BazarrEpisode(
      seriesId: ((j['series_id'] as num?) ?? (j['seriesId'] as num?) ?? 0).toInt(),
      season: ((j['season'] as num?) ?? 0).toInt(),
      episode: ((j['episode'] as num?) ?? 0).toInt(),
      title: (j['name'] ?? j['title'] ?? '').toString(),
      subtitles: (rawSubs is List) ? rawSubs.map((e) => BazarrSubtitle.fromJson((e as Map<String, dynamic>))).toList() : [],
    );
  }
}
