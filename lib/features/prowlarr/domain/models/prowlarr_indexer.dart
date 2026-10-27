class ProwlarrIndexer {
  final int id;
  final String name;
  final String implementationName;
  final String protocol;
  final bool enable;
  final bool supportsRss;
  final bool supportsSearch;
  final String? message;

  const ProwlarrIndexer({
    required this.id,
    required this.name,
    required this.implementationName,
    required this.protocol,
    required this.enable,
    required this.supportsRss,
    required this.supportsSearch,
    this.message,
  });

  factory ProwlarrIndexer.fromJson(Map<String, dynamic> json) {
    return ProwlarrIndexer(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      implementationName: json['implementationName'] ?? '',
      protocol: json['protocol'] ?? '',
      enable: json['enable'] ?? false,
      supportsRss: json['supportsRss'] ?? false,
      supportsSearch: json['supportsSearch'] ?? false,
      message: json['message'],
    );
  }

  @override
  String toString() {
    return 'ProwlarrIndexer(id: $id, name: $name, implementationName: $implementationName, protocol: $protocol, enable: $enable, supportsRss: $supportsRss, supportsSearch: $supportsSearch, message: $message)';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'implementationName': implementationName,
      'protocol': protocol,
      'enable': enable,
      'supportsRss': supportsRss,
      'supportsSearch': supportsSearch,
      if (message != null) 'message': message,
    };
  }
}
