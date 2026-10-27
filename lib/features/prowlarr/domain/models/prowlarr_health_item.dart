class ProwlarrHealthItem {
  final int id;
  final String? source;
  final String type;
  final String? message;
  final String? wikiUrl;

  const ProwlarrHealthItem({
    this.id = 0,
    this.source,
    String? type,
    String? status,
    this.message,
    this.wikiUrl,
  }) : type = type ?? status ?? '';

  String get status => type;

  factory ProwlarrHealthItem.fromJson(Map<String, dynamic> json) {
    return ProwlarrHealthItem(
      id: json['id'] ?? 0,
      source: json['source']?.toString(),
      type: json['type']?.toString() ?? json['status']?.toString(),
      message: json['message']?.toString(),
      wikiUrl: json['wikiUrl']?.toString(),
    );
  }

  @override
  String toString() {
    return 'ProwlarrHealthItem(id: $id, source: $source, type: $type, message: $message, wikiUrl: $wikiUrl)';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (source != null) 'source': source,
      'type': type,
      if (message != null) 'message': message,
      if (wikiUrl != null) 'wikiUrl': wikiUrl,
    };
  }
}
