class BazarrWantedEntry {
  final String title;
  final int? radarrId;
  final String? sceneName;
  final Map<String, dynamic>? missingSubtitles;
  final List<String> tags;
  String get type => 'movie'; // minimal; screen expects .type
  BazarrWantedEntry({
    required this.title,
    this.radarrId,
    this.sceneName,
    this.missingSubtitles,
    this.tags = const [],
  });
  factory BazarrWantedEntry.fromJson(Map<String, dynamic> j) => BazarrWantedEntry(
        title: (j['title'] ?? '').toString(),
        radarrId: ((j['radarrId'] as num?) ?? (j['id'] as num?))?.toInt(),
        sceneName: j['sceneName']?.toString(),
        missingSubtitles: j['missing_subtitles'] is Map ? Map<String, dynamic>.from(j['missing_subtitles']) : null,
        tags: ((j['tags'] as List<dynamic>?) ?? []).map((e) => e.toString()).toList(),
      );
}
