class ProwlarrSearchResult {
  final String? guid;
  final String indexer;
  final int indexerId;
  final String title;
  final String protocol;
  final int size;
  final double? age;
  final int? seeders;
  final int? leechers;
  final List<String> categories;

  const ProwlarrSearchResult({
    this.guid,
    required this.indexer,
    required this.indexerId,
    required this.title,
    required this.protocol,
    required this.size,
    this.age,
    this.seeders,
    this.leechers,
    required this.categories,
  });

  factory ProwlarrSearchResult.fromJson(Map<String, dynamic> json) {
    return ProwlarrSearchResult(
      guid: json['guid'],
      indexer: json['indexer'] ?? '',
      indexerId: json['indexerId'] ?? 0,
      title: json['title'] ?? '',
      protocol: json['protocol'] ?? '',
      size: json['size'] ?? 0,
      age: json['age'],
      seeders: json['seeders'],
      leechers: json['leechers'],
      categories: List<String>.from(
        (json['categories'] ?? [])
            .cast<String>()
            .where((s) => s != null && s!.isNotEmpty),
      ),
    );
  }

  @override
  String toString() {
    return 'ProwlarrSearchResult(guid: $guid, indexer: $indexer, indexerId: $indexerId, title: $title, protocol: $protocol, size: $size, age: $age, seeders: $seeders, leechers: $leechers, categories: $categories)';
  }

  Map<String, dynamic> toJson() {
    return {
      if (guid != null) 'guid': guid,
      'indexer': indexer,
      'indexerId': indexerId,
      'title': title,
      'protocol': protocol,
      'size': size,
      if (age != null) 'age': age,
      if (seeders != null) 'seeders': seeders,
      if (leechers != null) 'leechers': leechers,
      if (categories.isNotEmpty) 'categories': categories,
    };
  }
}
