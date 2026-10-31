class NavidromeAlbum {
  final String id;
  final String name;
  final String? artist;
  final String? artistId;
  final int? year;
  final int? songCount;
  final String? coverArt;
  final String? genre;

  const NavidromeAlbum({
    required this.id,
    required this.name,
    this.artist,
    this.artistId,
    this.year,
    this.songCount,
    this.coverArt,
    this.genre,
  });

  factory NavidromeAlbum.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return NavidromeAlbum(
      id: data['id']?.toString() ?? '',
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'Unknown Album',
      artist: (data['artist'] as String?)?.trim(),
      artistId: data['artistId']?.toString(),
      year: (data['year'] as num?)?.toInt(),
      songCount: (data['songCount'] as num?)?.toInt(),
      coverArt: data['coverArt']?.toString(),
      genre: (data['genre'] as String?)?.trim(),
    );
  }
}