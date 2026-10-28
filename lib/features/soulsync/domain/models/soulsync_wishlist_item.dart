class SoulSyncWishlistItem {
  final String id;
  final String title;
  final String status;
  final String? reason;

  const SoulSyncWishlistItem({
    required this.id,
    required this.title,
    this.status = '',
    this.reason,
  });

  factory SoulSyncWishlistItem.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return SoulSyncWishlistItem(
      id: (data['id'] ?? '').toString(),
      title: (data['title'] ?? data['name'] ?? '').toString(),
      status: (data['status'] ?? data['state'] ?? '').toString(),
      reason: data['reason']?.toString(),
    );
  }
}
