/// One recommendation row from SoulSync discovery.
///
/// Shapes vary per section (pool tracks, similar artists, recent releases,
/// bubble entries) — every field falls back defensively. Field names from
/// the SoulSync REST API docs: pool `tracks[]`, similar `artists[]`, recent
/// `releases[]`, bubbles `snapshots.<type>.data.bubbles[]`.
class SoulSyncDiscoverItem {
  final String id;
  final String title;
  final String subtitle;
  final String? coverUrl;
  final int? durationMs;

  const SoulSyncDiscoverItem({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.coverUrl,
    this.durationMs,
  });

  factory SoulSyncDiscoverItem.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    final artist = (data['artist_name'] ??
            data['similar_artist_name'] ??
            data['artist'])
        ?.toString() ??
        '';
    final extra =
        (data['genre'] ?? data['type'] ?? data['kind'])?.toString() ?? '';
    final subtitle = [
      if (artist.trim().isNotEmpty) artist.trim(),
      if (extra.trim().isNotEmpty) extra.trim(),
    ].join(' · ');
    final title = (data['track_name'] ??
            data['name'] ??
            data['album_name'] ??
            data['title'] ??
            data['label'] ??
            '')
        .toString();
    int? durationMs;
    final rawDuration = data['duration_ms'];
    if (rawDuration is num) {
      durationMs = rawDuration.toInt();
    } else if (rawDuration is String) {
      durationMs = int.tryParse(rawDuration);
    }
    final cover = (data['album_cover_url'] ?? data['thumb_url'] ?? data['image_url'])?.toString();
    return SoulSyncDiscoverItem(
      id: (data['id'] ?? '').toString(),
      title: title,
      subtitle: subtitle,
      coverUrl: (cover != null && cover.isNotEmpty) ? cover : null,
      durationMs: durationMs,
    );
  }

  /// `m:ss` duration or null when unknown.
  String? get formattedDuration {
    final ms = durationMs;
    if (ms == null || ms <= 0) return null;
    final totalSeconds = ms ~/ 1000;
    return '${totalSeconds ~/ 60}:${(totalSeconds % 60).toString().padLeft(2, '0')}';
  }

  /// A bubble entry (`{name, value, genre}` or `{query, count}`) labelled
  /// with its snapshot type.
  factory SoulSyncDiscoverItem.fromBubble(
    Map<String, dynamic> json,
    String snapshotType,
  ) {
    final data = Map<String, dynamic>.from(json);
    final value = data['value'] ?? data['count'];
    return SoulSyncDiscoverItem(
      id: '$snapshotType:${data['name'] ?? data['query'] ?? ''}',
      title: ((data['name'] ?? data['query'] ?? '')).toString(),
      subtitle: [
        snapshotType,
        if (data['genre'] != null) (data['genre']).toString(),
        if (value != null) '$value',
      ].join(' · '),
    );
  }
}
