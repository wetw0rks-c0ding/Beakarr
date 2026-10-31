import 'omv_parse.dart';

class OmvFilesystem {
  final String? devicefile;
  final String? mountpoint;
  final String? type;
  final String? label;
  final String? uuid;
  final int? sizeBytes;
  final int? usedBytes;
  final int? availableBytes;
  final int? percentage;
  final bool mounted;
  final String? description;
  final String? comment;
  final bool isReadonly;

  const OmvFilesystem({
    this.devicefile,
    this.mountpoint,
    this.type,
    this.label,
    this.uuid,
    this.sizeBytes,
    this.usedBytes,
    this.availableBytes,
    this.percentage,
    this.mounted = false,
    this.description,
    this.comment,
    this.isReadonly = false,
  });

  factory OmvFilesystem.fromJson(Map<String, dynamic> json) {
    final pct = asInt(json['percentage']);
    return OmvFilesystem(
      devicefile: asString(json['devicefile']),
      mountpoint: asString(json['mountpoint']),
      type: asString(json['type']),
      label: asString(json['label']),
      uuid: asString(json['uuid']),
      sizeBytes: bytesFromString(json['size']),
      usedBytes: bytesFromString(json['used']),
      availableBytes: bytesFromString(json['available']),
      percentage: (pct != null && pct >= 0) ? pct : null,
      mounted: asBool(json['mounted']),
      description: asString(json['description']),
      comment: asString(json['comment']),
      isReadonly: asBool(json['_readonly']),
    );
  }

  double? get usageRatio {
    if (percentage == null) return null;
    return (percentage! / 100.0).clamp(0.0, 1.0);
  }
}