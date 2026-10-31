import 'package:seekarr/core/utils/dynamic_map_utils.dart';

String? asString(dynamic v) => stringOrNull(v);

int? asInt(dynamic v) => intOrNull(v);

double? asDouble(dynamic v) => doubleOrNull(v);

bool asBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase();
  return s == 'true' || s == '1';
}

Map<String, dynamic>? asMap(dynamic v) => mapOrNull(v);

List<dynamic> asList(dynamic v) {
  if (v is List) return v;
  return const [];
}

/// Parses a byte-count string. Returns `null` for `"-1"`, empty, or
/// non-numeric input (OMV uses `"-1"` for "unknown").
int? bytesFromString(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty || s == '-1') return null;
  final parsed = int.tryParse(s);
  if (parsed == null) return null;
  if (parsed < 0) return null;
  return parsed;
}

/// Formats a byte-count string into a human-readable size using binary units.
/// `"-1"` / empty / unparseable → `null`.
String? formatBytesFromString(dynamic v) {
  final bytes = bytesFromString(v);
  if (bytes == null) return null;
  return _formatBytes(bytes);
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB'];
  int i = 0;
  double s = bytes.toDouble();
  while (s >= 1024 && i < units.length - 1) {
    s /= 1024;
    i++;
  }
  return '${s.toStringAsFixed(1)} ${units[i]}';
}

/// Renders a duration in seconds as `Xd Yh Zm` (omitting zero leading parts
/// except when everything is zero, which renders `0m`).
String formatUptime(double? seconds) {
  if (seconds == null || seconds <= 0) return '';
  final total = seconds.floor();
  final days = total ~/ 86400;
  final hours = (total % 86400) ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final parts = <String>[];
  if (days > 0) parts.add('${days}d');
  if (hours > 0 || days > 0) parts.add('${hours}h');
  parts.add('${minutes}m');
  return parts.join(' ');
}

/// Splits `"7.4.17 (Sandworm)"` into `("7.4.17", "Sandworm")`. A missing
/// parenthetical yields an empty name.
(String, String) stripVersionName(String? raw) {
  final text = (raw ?? '').trim();
  final match = RegExp(r'^([^\s(]+)\s*(?:\(([^)]*)\))?\s*$').firstMatch(text);
  if (match == null) return (text, '');
  return (match.group(1) ?? text, (match.group(2) ?? '').trim());
}

/// Whether a SMART overall status string counts as healthy.
bool smartAssessmentIsHealthy(String? status) {
  final s = (status ?? '').trim().toUpperCase();
  return s == 'GOOD';
}