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

  const SoulSyncDiscoverItem({
    required this.id,
    required this.title,
    this.subtitle = '',
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
    return SoulSyncDiscoverItem(
      id: (data['id'] ?? '').toString(),
      title: title,
      subtitle: subtitle,
    );
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
