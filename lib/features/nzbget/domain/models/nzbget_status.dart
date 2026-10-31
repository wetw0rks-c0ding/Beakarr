import 'package:seekarr/core/utils/dynamic_map_utils.dart';

/// Server-wide state from the JSON-RPC `status` method.
///
/// Rates and sizes above 32 bits arrive split into `*Lo` / `*Hi` halves;
/// [fromJson] recomposes them and falls back to the deprecated single-value
/// `DownloadRate` on pre-split server builds.
class NzbgetStatus {
  final int remainingSizeMb;
  final int downloadedSizeMb;

  /// Bytes per second.
  final int downloadRateBps;
  final bool downloadPaused;
  final bool postPaused;
  final bool serverStandBy;
  final int postJobCount;
  final int urlCount;

  /// Unix epoch (seconds) as reported by the server.
  final int serverTime;
  final int freeDiskSpaceMb;

  const NzbgetStatus({
    this.remainingSizeMb = 0,
    this.downloadedSizeMb = 0,
    this.downloadRateBps = 0,
    this.downloadPaused = false,
    this.postPaused = false,
    this.serverStandBy = false,
    this.postJobCount = 0,
    this.urlCount = 0,
    this.serverTime = 0,
    this.freeDiskSpaceMb = 0,
  });

  factory NzbgetStatus.fromJson(Map<String, dynamic> json) {
    final rateLo = intOrNull(json['DownloadRateLo']);
    final downloadRate = rateLo == null
        ? intOrNull(json['DownloadRate']) ?? 0
        : _u64(rateLo, intOrNull(json['DownloadRateHi']));
    return NzbgetStatus(
      remainingSizeMb: intOrNull(json['RemainingSizeMB']) ?? 0,
      downloadedSizeMb: intOrNull(json['DownloadedSizeMB']) ?? 0,
      downloadRateBps: downloadRate,
      downloadPaused: _bool(json['DownloadPaused']),
      postPaused: _bool(json['PostPaused']),
      serverStandBy: _bool(json['ServerStandBy']),
      postJobCount: intOrNull(json['PostJobCount']) ?? 0,
      urlCount: intOrNull(json['UrlCount']) ?? 0,
      serverTime: intOrNull(json['ServerTime']) ?? 0,
      freeDiskSpaceMb: intOrNull(json['FreeDiskSpaceMB']) ?? 0,
    );
  }

  static int _u64(int? lo, int? hi) => (hi ?? 0) * 0x100000000 + (lo ?? 0);

  static bool _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1';
  }

  bool get isPaused => downloadPaused;

  String get downloadRateFormatted => formatStatusSpeed(downloadRateBps);

  String get remainingSizeFormatted => formatStatusMb(remainingSizeMb);

  String get freeDiskSpaceFormatted => formatStatusMb(freeDiskSpaceMb);
}

/// `1.4 MB/s` style rendering for the status bar. Zero renders as `0 B/s`.
String formatStatusSpeed(int bytesPerSecond) {
  if (bytesPerSecond <= 0) return '0 B/s';
  const units = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
  var index = 0;
  var value = bytesPerSecond.toDouble();
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }
  return '${value.toStringAsFixed(1)} ${units[index]}';
}

/// NZBGet reports sizes in whole MB; promote to GB/TB for readability.
String formatStatusMb(int mb) {
  if (mb <= 0) return '0 MB';
  if (mb >= 1024 * 1024) return '${(mb / (1024 * 1024)).toStringAsFixed(2)} TB';
  if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(2)} GB';
  return '$mb MB';
}
