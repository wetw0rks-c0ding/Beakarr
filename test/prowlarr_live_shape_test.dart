import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:seekarr/features/prowlarr/domain/models/prowlarr_search_result.dart';

/// Shape regression test: real Prowlarr field shapes that broke parsing
/// before (int age, nameless category objects, null guid).
void main() {
  test('parses real-world item shapes without throwing', () {
    const raw = '''
[
  {"guid": "magnet:?xt=urn:btih:abc", "indexer": "Nyaa.si", "indexerId": 7,
   "title": "Show S01E01", "protocol": "torrent", "size": 1400000000,
   "age": 2, "seeders": 390, "leechers": 13,
   "categories": [{"id": 5070, "name": "TV/Anime", "subCategories": []},
                  {"id": 127720, "subCategories": []}]},
  {"guid": null, "indexer": "IPTorrents", "indexerId": 3,
   "title": "Movie (2024)", "protocol": "torrent", "size": 8600000000,
   "age": 854, "seeders": null, "leechers": null, "categories": []},
  {"guid": "x", "indexer": null, "indexerId": 1, "title": null,
   "protocol": null, "size": null, "age": null, "categories": null}
]''';
    final decoded = jsonDecode(raw) as List<dynamic>;
    final results = decoded
        .map((e) => ProwlarrSearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(results.length, 3);
    expect(results[0].categories, ['TV/Anime']);
    expect(results[0].age, 2.0);
    expect(results[1].guid, isNull);
    expect(results[2].title, '');
  });
}
