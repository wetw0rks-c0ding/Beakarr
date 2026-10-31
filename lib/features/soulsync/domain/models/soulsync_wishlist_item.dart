class SoulSyncWishlistItem {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String status;
  final String? reason;
  final String? dateAdded;

  const SoulSyncWishlistItem({
    required this.id,
    required this.title,
    this.artist = '',
    this.album = '',
    this.status = '',
    this.reason,
    this.dateAdded,
  });

  factory SoulSyncWishlistItem.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    final artistName = (data['artist_name'] ?? data['artist'] ?? '').toString();
    final albumName = (data['album_name'] ?? data['album'] ?? '').toString();
    final fallback = [
      if (artistName.isNotEmpty) artistName,
      if (albumName.isNotEmpty) albumName,
    ].join(' – ');
    return SoulSyncWishlistItem(
      id: (data['id'] ?? '').toString(),
      title: (data['track_name'] ?? data['title'] ?? data['name'] ?? fallback)
          .toString(),
      artist: artistName,
      album: albumName,
      status: (data['status'] ?? data['state'] ?? '').toString(),
      reason: (data['failure_reason'] ?? data['reason'])?.toString(),
      dateAdded: (data['date_added'] ?? data['dateAdded'])?.toString(),
    );
  }
}
