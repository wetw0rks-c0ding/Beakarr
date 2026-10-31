class OidcPreset {
  final String name;
  final String issuer;
  final String clientId;

  const OidcPreset({
    required this.name,
    required this.issuer,
    required this.clientId,
  });

  static OidcPreset? tryFromJson(Map<String, dynamic> json) {
    try {
      final n = json['name'] as String?;
      final i = json['issuer'] as String?;
      final c = json['clientId'] as String?;
      if (n == null || i == null || c == null) return null;
      final name = n.trim();
      final issuer = i.trim();
      final clientId = c.trim();
      if (name.isEmpty || issuer.isEmpty || clientId.isEmpty) return null;
      return OidcPreset(name: name, issuer: issuer, clientId: clientId);
    } catch (_) {
      return null;
    }
  }

  factory OidcPreset.fromJson(Map<String, dynamic> json) {
    final result = tryFromJson(json);
    if (result == null) throw const FormatException('Invalid OidcPreset JSON');
    return result;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'issuer': issuer,
        'clientId': clientId,
      };
}
