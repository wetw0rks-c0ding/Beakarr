class BazarrSubtitle {
  final String language;
  final String provider;
  final bool hearingImpaired;
  final bool forced;
  final String? path;
  final String? downloadUrl;
  BazarrSubtitle({required this.language, this.provider = '', this.hearingImpaired = false, this.forced = false, this.path, this.downloadUrl});
  factory BazarrSubtitle.fromJson(Map<String, dynamic> j) => BazarrSubtitle(
        language: (j['language'] ?? j['lang'] ?? '').toString(),
        provider: (j['provider'] ?? '').toString(),
        hearingImpaired: (j['hearing_impaired'] ?? j['hearingImpaired'] ?? false) == true,
        forced: (j['forced'] ?? false) == true,
        path: j['path'] == null ? null : j['path'].toString(),
        downloadUrl: j['download_url'] == null ? null : j['download_url'].toString(),
      );
}
