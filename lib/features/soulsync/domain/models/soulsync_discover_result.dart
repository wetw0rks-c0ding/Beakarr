class SoulSyncDiscoverResult {
  final String id;
  final String title;

  const SoulSyncDiscoverResult({required this.id, required this.title});

  factory SoulSyncDiscoverResult.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return SoulSyncDiscoverResult(
      id: (data['id'] ?? '').toString(),
      title: (data['title'] ?? data['name'] ?? '').toString(),
    );
  }
}
