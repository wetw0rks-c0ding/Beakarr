class SoulSyncProfile {
  final String id;
  final String name;

  const SoulSyncProfile({required this.id, required this.name});

  factory SoulSyncProfile.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return SoulSyncProfile(
      id: (data['id'] ?? data['profile_id'] ?? '').toString(),
      name: (data['name'] ?? data['title'] ?? '').toString(),
    );
  }
}
