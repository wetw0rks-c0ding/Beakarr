class BazarrSeries {
  final int id;
  final String title;
  final int year;
  final int seasonCount;
  BazarrSeries({required this.id, required this.title, this.year = 0, this.seasonCount = 0});
  factory BazarrSeries.fromJson(Map<String, dynamic> j) => BazarrSeries(
        id: ((j['id'] as num?) ?? 0).toInt(),
        title: (j['title'] ?? '').toString(),
        year: ((j['year'] as num?) ?? 0).toInt(),
        seasonCount: ((j['season_count'] as num?) ?? (j['seasonCount'] as num?) ?? 0).toInt(),
      );
}
