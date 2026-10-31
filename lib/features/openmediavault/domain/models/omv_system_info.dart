import 'omv_parse.dart';

class OmvSystemInfo {
  final String? hostname;
  final String? version;
  final String? kernel;
  final double? uptime;
  final Map<String, dynamic>? loadAverage;
  final String? cpuModelName;
  final int? cpuCores;
  final int? cpuUtilization;
  final double? cpuMhz;
  final String? memTotal;
  final String? memFree;
  final String? memUsed;
  final String? memAvailable;
  final double? memUtilization;
  final bool? configDirty;
  final List<dynamic>? dirtyModules;
  final bool? rebootRequired;
  final int? availablePkgUpdates;
  final int? ts;

  const OmvSystemInfo({
    this.hostname,
    this.version,
    this.kernel,
    this.uptime,
    this.loadAverage,
    this.cpuModelName,
    this.cpuCores,
    this.cpuUtilization,
    this.cpuMhz,
    this.memTotal,
    this.memFree,
    this.memUsed,
    this.memAvailable,
    this.memUtilization,
    this.configDirty,
    this.dirtyModules,
    this.rebootRequired,
    this.availablePkgUpdates,
    this.ts,
  });

  factory OmvSystemInfo.fromJson(Map<String, dynamic> json) {
    return OmvSystemInfo(
      hostname: asString(json['hostname']),
      version: asString(json['version']),
      kernel: asString(json['kernel']),
      uptime: asDouble(json['uptime']),
      loadAverage: asMap(json['loadAverage']),
      cpuModelName: asString(json['cpuModelName']),
      cpuCores: asInt(json['cpuCores']),
      cpuUtilization: asInt(json['cpuUtilization']),
      cpuMhz: asDouble(json['cpuMhz']),
      memTotal: asString(json['memTotal']),
      memFree: asString(json['memFree']),
      memUsed: asString(json['memUsed']),
      memAvailable: asString(json['memAvailable']),
      memUtilization: asDouble(json['memUtilization']),
      configDirty: json['configDirty'] == null ? null : asBool(json['configDirty']),
      dirtyModules: asList(json['dirtyModules']),
      rebootRequired:
          json['rebootRequired'] == null ? null : asBool(json['rebootRequired']),
      availablePkgUpdates: asInt(json['availablePkgUpdates']),
      ts: asInt(json['ts']),
    );
  }

  String get displayVersion {
    final (v, name) = stripVersionName(version);
    if (v.isEmpty) return '';
    if (name.isEmpty) return 'v$v';
    return 'v$v ($name)';
  }

  String get uptimeLabel => formatUptime(uptime);

  /// Ratio 0..1 of memory used, or null when total is missing/zero/"-1".
  double? get memoryUsedRatio {
    final total = bytesFromString(memTotal);
    if (total == null || total <= 0) return null;
    final used = bytesFromString(memUsed);
    if (used == null) {
      // Fall back to memUtilization if it looks like 0..1.
      if (memUtilization != null) {
        if (memUtilization! <= 1.0) return memUtilization!.clamp(0.0, 1.0);
        if (memUtilization! <= 100.0) {
          return (memUtilization! / 100.0).clamp(0.0, 1.0);
        }
      }
      return null;
    }
    return (used / total).clamp(0.0, 1.0);
  }

  String get loadLabel {
    final la = loadAverage;
    if (la == null) return '';
    final a = la['1min'] ?? la['1Min'] ?? la['1'];
    final b = la['5min'] ?? la['5Min'] ?? la['5'];
    final c = la['15min'] ?? la['15Min'] ?? la['15'];
    return '${_fmt(a)} / ${_fmt(b)} / ${_fmt(c)}';
  }

  static String _fmt(dynamic v) {
    final d = asDouble(v);
    if (d == null) return '—';
    return d.toStringAsFixed(2);
  }
}