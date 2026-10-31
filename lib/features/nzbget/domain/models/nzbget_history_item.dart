import 'package:seekarr/core/utils/dynamic_map_utils.dart';

/// A `history` entry: one finished NZB (succeeded, failed or deleted).
///
/// `fromJson` tolerates missing keys and numeric-string fields; predicates are
/// prefix-based because NZBGet appends the reason to the status
/// (`SUCCESS/ALL`, `WARNING/SCRIPT`, `FAILURE/PAR`, `DELETED/MANUAL`).
class NzbgetHistoryItem {
  /// NZBID — the identifier `editqueue` expects.
  final int id;
  final String name;
  final String status;

  /// `NZB` or `URL`.
  final String kind;
  final String category;
  final int fileSizeMb;

  /// Unix epoch (seconds) as reported by the server.
  ///
  /// [fromJson] falls back to the epoch for missing/zero timestamps rather
  /// than throwing; use [hasHistoryTime] to distinguish that case.
  final DateTime historyTime;
  final int deleteStatus;

  /// Article health in permille (1000 = 100 %).
  final int health;
  final String parStatus;
  final String unpackStatus;
  final String scriptStatus;

  /// Source URL for history entries added by URL (may be empty).
  final String url;

  const NzbgetHistoryItem({
    this.id = 0,
    this.name = '',
    this.status = '',
    this.kind = '',
    this.category = '',
    this.fileSizeMb = 0,
    required this.historyTime,
    this.deleteStatus = 0,
    this.health = 0,
    this.parStatus = '',
    this.unpackStatus = '',
    this.scriptStatus = '',
    this.url = '',
  });

  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  bool get hasHistoryTime => historyTime.millisecondsSinceEpoch > 0;

  /// Relative age of the entry, e.g. `3 d ago`; empty when unknown.
  String get historyTimeFormatted {
    if (!hasHistoryTime) return '';
    final delta = DateTime.now().difference(historyTime);
    final minutes = delta.inMinutes;
    if (minutes < 1) return 'just now';
    if (minutes < 60) return '$minutes min ago';
    final hours = delta.inHours;
    if (hours < 24) return '$hours h ago';
    final days = delta.inDays;
    if (days < 30) return '$days d ago';
    final months = days ~/ 30;
    if (months < 12) return '$months mo ago';
    return '${days ~/ 365} y ago';
  }

  /// Status label without the reason suffix (`SUCCESS/ALL` → `SUCCESS`).
  String get statusLabel {
    final slash = status.indexOf('/');
    return slash < 0 ? status : status.substring(0, slash);
  }

  factory NzbgetHistoryItem.fromJson(Map<String, dynamic> json) {
    final seconds = intOrNull(json['HistoryTime']) ?? 0;
    return NzbgetHistoryItem(
      id: intOrNull(json['NZBID']) ?? 0,
      name: stringOrNull(json['NZBName']) ?? '',
      status: (stringOrNull(json['Status']) ?? '').toUpperCase(),
      kind: stringOrNull(json['Kind']) ?? '',
      category: stringOrNull(json['Category']) ?? '',
      fileSizeMb: intOrNull(json['FileSizeMB']) ?? 0,
      historyTime: seconds > 0
          ? DateTime.fromMillisecondsSinceEpoch(seconds * 1000)
          : _epoch,
      deleteStatus: intOrNull(json['DeleteStatus']) ?? 0,
      health: intOrNull(json['Health']) ?? 0,
      parStatus: stringOrNull(json['ParStatus']) ?? '',
      unpackStatus: stringOrNull(json['UnpackStatus']) ?? '',
      scriptStatus: stringOrNull(json['ScriptStatus']) ?? '',
      url: stringOrNull(json['URL']) ?? '',
    );
  }

  bool get succeeded => status.startsWith('SUCCESS');

  bool get deleted => status.startsWith('DELETED');

  bool get failed =>
      status.startsWith('FAILURE') || status.startsWith('WARNING');

  /// True when the row belongs to [filter] — a status prefix such as
  /// `SUCCESS`, `WARNING`, `FAILURE` or `DELETED`, or `null`/empty for "all".
  bool matchesFilter(String? filter) {
    if (filter == null || filter.isEmpty) return true;
    return status.startsWith(filter);
  }

  double get healthPercent => health / 10;

  String get fileSizeFormatted {
    if (fileSizeMb <= 0) return '—';
    if (fileSizeMb >= 1024 * 1024) {
      return '${(fileSizeMb / (1024 * 1024)).toStringAsFixed(2)} TB';
    }
    if (fileSizeMb >= 1024) {
      return '${(fileSizeMb / 1024).toStringAsFixed(2)} GB';
    }
    return '$fileSizeMb MB';
  }
}
