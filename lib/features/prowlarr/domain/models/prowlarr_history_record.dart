class ProwlarrHistoryRecord {
  final int id;
  final int indexerId;
  final String? date;
  final String? downloadId;
  final bool successful;
  final String eventType;
  final Map<String, dynamic>? data;

  const ProwlarrHistoryRecord({
    this.id = 0,
    this.indexerId = 0,
    this.date,
    this.downloadId,
    this.successful = false,
    this.eventType = 'unknown',
    this.data,
  });

  factory ProwlarrHistoryRecord.fromJson(Map<String, dynamic> json) {
    return ProwlarrHistoryRecord(
      id: json['id'] ?? 0,
      indexerId: json['indexerId'] ?? 0,
      date: json['date']?.toString(),
      downloadId: json['downloadId']?.toString(),
      successful: json['successful'] ?? false,
      eventType: json['eventType']?.toString() ?? 'unknown',
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
    );
  }

  @override
  String toString() {
    return 'ProwlarrHistoryRecord(id: $id, indexerId: $indexerId, date: $date, downloadId: $downloadId, successful: $successful, eventType: $eventType, data: $data)';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'indexerId': indexerId,
      if (date != null) 'date': date,
      if (downloadId != null) 'downloadId': downloadId,
      'successful': successful,
      'eventType': eventType,
      if (data != null) 'data': data,
    };
  }
}

// Aliases for common naming variants.
typedef ProwlarrHistory = ProwlarrHistoryRecord;
typedef ProwlarrHistoryItem = ProwlarrHistoryRecord;
typedef ProwlarrHistoryResource = ProwlarrHistoryRecord;
