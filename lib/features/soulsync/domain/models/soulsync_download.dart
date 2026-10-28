class SoulSyncDownload {
  final String id;
  final String title;
  final double progress;
  final String? client;
  final String? speed;
  final String? eta;
  final bool complete;

  const SoulSyncDownload({
    required this.id,
    required this.title,
    this.progress = 0,
    this.client,
    this.speed,
    this.eta,
    this.complete = false,
  });

  factory SoulSyncDownload.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    final rawProgress = data['progress'] ?? data['percent'] ?? 0;
    double progress = 0;
    if (rawProgress is num) {
      progress = rawProgress.toDouble();
    } else {
      progress = double.tryParse(rawProgress.toString()) ?? 0;
    }
    if (progress > 1) progress = progress / 100.0;
    return SoulSyncDownload(
      id: (data['id'] ?? '').toString(),
      title: (data['track_name'] ?? data['title'] ?? data['name'] ?? '').toString(),
      progress: progress,
      client: data['client']?.toString() ?? data['source']?.toString(),
      speed: data['speed']?.toString(),
      eta: data['eta']?.toString(),
      complete: data['complete'] == true || data['status']?.toString().toLowerCase() == 'complete',
    );
  }
}
