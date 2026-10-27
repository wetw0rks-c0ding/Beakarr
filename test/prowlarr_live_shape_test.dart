import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seekarr/features/prowlarr/domain/models/prowlarr_search_result.dart';

/// Live-shape regression test: parses a REAL Prowlarr /api/v1/search
/// response (235 items, captured 2026-10-27) through fromJson.
/// Fixture file is test-local only and is deleted after verification.
void main() {
  test('parses all live search items without throwing', () {
    final raw = File('/tmp/opencode/prowlarr-madmax.json').readAsStringSync();
    final decoded = jsonDecode(raw) as List<dynamic>;
    expect(decoded, isNotEmpty);

    var parsed = 0;
    for (final e in decoded) {
      final r = ProwlarrSearchResult.fromJson(e as Map<String, dynamic>);
      expect(r.title, isNotEmpty);
      parsed++;
    }
    expect(parsed, decoded.length);
  });
}
