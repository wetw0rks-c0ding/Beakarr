class BazarrProvider {
  final String name;
  final bool enabled;
  BazarrProvider({required this.name, this.enabled = true});
  factory BazarrProvider.fromJson(Map<String, dynamic> j) => BazarrProvider(
        name: (j['name'] ?? j['provider'] ?? '').toString(),
        enabled: (j['enabled'] ?? j['enable'] ?? true) == true,
      );
}
