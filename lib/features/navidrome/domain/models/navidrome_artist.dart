class NavidromeArtist {
  final String id;
  final String name;
  final int albumCount;
  final String? coverArt;

  const NavidromeArtist({
    required this.id,
    required this.name,
    this.albumCount = 0,
    this.coverArt,
  });

  factory NavidromeArtist.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return NavidromeArtist(
      id: data['id']?.toString() ?? '',
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'Unknown Artist',
      albumCount: (data['albumCount'] as num?)?.toInt() ?? 0,
      coverArt: data['coverArt']?.toString(),
    );
  }
}