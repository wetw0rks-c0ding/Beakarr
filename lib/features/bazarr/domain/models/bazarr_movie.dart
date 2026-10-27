class BazarrMovie {
  final int id;
  final String title;
  final int year;
  final String path;
  BazarrMovie({required this.id, required this.title, this.year = 0, required this.path});
  factory BazarrMovie.fromJson(Map<String, dynamic> j) => BazarrMovie(
        id: ((j['id'] as num?) ?? 0).toInt(),
        title: (j['title'] ?? '').toString(),
        year: ((j['year'] as num?) ?? 0).toInt(),
        path: (j['path'] ?? '').toString(),
      );
}
