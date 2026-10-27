class BazarrProvider {
  final String name;
  final String status;
  final String retry;
  BazarrProvider({required this.name, required this.status, required this.retry});
  factory BazarrProvider.fromJson(Map<String, dynamic> j) => BazarrProvider(
        name: (j['name'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        retry: (j['retry'] ?? '').toString(),
      );
}
