class NavidromeTrack {
  final String id;
  final String title;
  final String? artist;
  final String? album;
  final String? albumId;
  final int? trackNumber;
  final int? discNumber;
  final int durationSeconds;
  final String? coverArt;

  const NavidromeTrack({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.albumId,
    this.trackNumber,
    this.discNumber,
    this.durationSeconds = 0,
    this.coverArt,
  });

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final secs = durationSeconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  factory NavidromeTrack.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return NavidromeTrack(
      id: data['id']?.toString() ?? '',
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? (data['title'] as String).trim()
          : 'Unknown Track',
      artist: (data['artist'] as String?)?.trim(),
      album: (data['album'] as String?)?.trim(),
      albumId: data['albumId']?.toString(),
      trackNumber: (data['track'] as num?)?.toInt(),
      discNumber: (data['discNumber'] as num?)?.toInt(),
      durationSeconds: (data['duration'] as num?)?.toInt() ?? 0,
      coverArt: data['coverArt']?.toString(),
    );
  }
}