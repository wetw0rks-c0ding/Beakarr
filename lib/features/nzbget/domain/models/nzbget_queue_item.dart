import 'package:seekarr/core/utils/dynamic_map_utils.dart';

/// NZBGet post-processing statuses reported in `listgroups`.
///
/// While one of these is active the group has finished downloading and is
/// being verified / repaired / unpacked.
const Set<String> nzbgetPostProcessingStatuses = {
  'LOADING_PARS',
  'VERIFYING_SOURCES',
  'REPAIRING',
  'VERIFYING_REPAIRED',
  'RENAMING',
  'UNPACKING',
  'MOVING',
  'EXECUTING_SCRIPT',
  'PP_QUEUED',
  'PP_FINISHED',
};

/// A `listgroups` entry: one NBZ in the NZBGet download queue.
///
/// `fromJson` is deliberately tolerant — NZBGet mixes camel-case keys, numeric
/// strings and missing fields between versions, and a shape drift must never
/// blank the whole queue.
class NzbgetQueueItem {
  /// NZBID — the queue-control identifier.
  final int id;
  final String name;
  final String status;
  final String category;
  final int fileSizeMb;
  final int remainingSizeMb;
  final int downloadedSizeMb;

  /// Article health in permille (1000 = 100 %).
  final int health;
  final int activeDownloads;
  final int maxPriority;
  final int remainingFileCount;
  final String postInfoText;
  final int postStageProgress;

  const NzbgetQueueItem({
    this.id = 0,
    this.name = '',
    this.status = '',
    this.category = '',
    this.fileSizeMb = 0,
    this.remainingSizeMb = 0,
    this.downloadedSizeMb = 0,
    this.health = 0,
    this.activeDownloads = 0,
    this.maxPriority = 0,
    this.remainingFileCount = 0,
    this.postInfoText = '',
    this.postStageProgress = 0,
  });

  factory NzbgetQueueItem.fromJson(Map<String, dynamic> json) {
    return NzbgetQueueItem(
      id: intOrNull(json['NZBID']) ?? 0,
      name: stringOrNull(json['NZBName']) ?? '',
      status: (stringOrNull(json['Status']) ?? '').toUpperCase(),
      category: stringOrNull(json['Category']) ?? '',
      fileSizeMb: intOrNull(json['FileSizeMB']) ?? 0,
      remainingSizeMb: intOrNull(json['RemainingSizeMB']) ?? 0,
      downloadedSizeMb: intOrNull(json['DownloadedSizeMB']) ?? 0,
      health: intOrNull(json['Health']) ?? 0,
      activeDownloads: intOrNull(json['ActiveDownloads']) ?? 0,
      maxPriority: intOrNull(json['MaxPriority']) ?? 0,
      remainingFileCount: intOrNull(json['RemainingFileCount']) ?? 0,
      postInfoText: stringOrNull(json['PostInfoText']) ?? '',
      postStageProgress: intOrNull(json['PostStageProgress']) ?? 0,
    );
  }

  /// Download progress in the 0..1 range.
  ///
  /// A zero total size (empty NZB, or a server that omitted the field) is 0 %
  /// rather than a division by zero; a remaining size larger than the total
  /// clamps instead of going negative.
  double get progress {
    if (fileSizeMb <= 0) return 0;
    return (1 - remainingSizeMb / fileSizeMb).clamp(0.0, 1.0);
  }

  bool get isPaused => status == 'PAUSED';

  bool get isPostProcessing => nzbgetPostProcessingStatuses.contains(status);

  /// Health as a percentage (permille → percent).
  double get healthPercent => health / 10;

  String get healthFormatted {
    final value = healthPercent;
    return '${value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1)}%';
  }

  String get fileSizeFormatted => _formatMb(fileSizeMb);

  String get remainingSizeFormatted => _formatMb(remainingSizeMb);

  String get progressFormatted => '${(progress * 100).toStringAsFixed(1)}%';
}

String _formatMb(int mb) {
  if (mb <= 0) return '—';
  if (mb >= 1024 * 1024) return '${(mb / (1024 * 1024)).toStringAsFixed(2)} TB';
  if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(2)} GB';
  return '$mb MB';
}
