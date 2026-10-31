class BazarrProvider {
  final String name;
  final String status;
  final String retry;
  final bool? _enabled;
  bool get enabled => _enabled == true;
  BazarrProvider({required this.name, required this.status, required this.retry, bool? enabled}) : _enabled = enabled;
  factory BazarrProvider.fromJson(Map<String, dynamic> j) => BazarrProvider(
        name: (j['name'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        retry: (j['retry'] ?? '').toString(),
        enabled: j['enabled'] == true,
      );
}
