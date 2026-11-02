import 'omv_parse.dart';

class OmvServiceStatus {
  final String? name;
  final String? title;
  final bool enabled;
  final bool running;

  const OmvServiceStatus({
    this.name,
    this.title,
    this.enabled = false,
    this.running = false,
  });

  factory OmvServiceStatus.fromJson(Map<String, dynamic> json) {
    return OmvServiceStatus(
      name: asString(json['name']),
      title: asString(json['title']),
      enabled: asBool(json['enabled']),
      running: asBool(json['running']),
    );
  }

  String get stabilityLabel {
    if (!enabled) return 'Disabled';
    return running ? 'Running' : 'Stopped';
  }
}