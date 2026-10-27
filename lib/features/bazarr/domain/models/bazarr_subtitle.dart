class BazarrSubtitle {
  final String name;
  final String code2;
  final String code3;
  final String? path;
  final bool forced;
  final bool hi;
  final int? fileSize;
  final int? embeddedTrackId;
  final int? id;
  BazarrSubtitle({
    required this.name,
    required this.code2,
    required this.code3,
    this.path,
    this.forced = false,
    this.hi = false,
    this.fileSize,
    this.embeddedTrackId,
    this.id,
  });
  factory BazarrSubtitle.fromJson(Map<String, dynamic> j) => BazarrSubtitle(
        name: (j['name'] ?? '').toString(),
        code2: (j['code2'] ?? '').toString(),
        code3: (j['code3'] ?? '').toString(),
        path: j['path']?.toString(),
        forced: j['forced'] == true,
        hi: j['hi'] == true,
        fileSize: ((j['file_size'] as num?) ?? (j['fileSize'] as num?))?.toInt(),
        embeddedTrackId: ((j['embedded_track_id'] as num?) ?? (j['embeddedTrackId'] as num?))?.toInt(),
        id: ((j['id'] as num?) ?? 0).toInt(),
      );
}
