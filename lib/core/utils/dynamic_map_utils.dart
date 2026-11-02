Map<String, dynamic> stringKeyMap(Map<dynamic, dynamic> value) {
  return value.map((key, value) => MapEntry(key.toString(), value));
}

Map<String, dynamic>? mapOrNull(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return stringKeyMap(value);
  return null;
}

String? stringOrNull(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? intOrNull(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? doubleOrNull(dynamic value) {
  if (value is num) return value.toDouble();
  if (value == null) return null;
  return double.tryParse(value.toString());
}

double? queueProgress(
  Map<dynamic, dynamic> item, {
  bool parseStrings = true,
  bool includeSizeLeftAlias = true,
}) {
  final rawSizeLeft =
      item['sizeleft'] ?? (includeSizeLeftAlias ? item['sizeLeft'] : null);
  final size = parseStrings
      ? doubleOrNull(item['size'])
      : (item['size'] as num?)?.toDouble();
  final sizeLeft = parseStrings
      ? doubleOrNull(rawSizeLeft)
      : (rawSizeLeft as num?)?.toDouble();
  if (size == null || size <= 0 || sizeLeft == null) return null;
  return ((size - sizeLeft) / size).clamp(0.0, 1.0).toDouble();
}

bool? boolOrNull(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is String) {
    final lower = value.toLowerCase();
    if (lower == 'true' || lower == '1' || lower == 'yes') return true;
    if (lower == 'false' || lower == '0' || lower == 'no') return false;
  }
  return null;
}
