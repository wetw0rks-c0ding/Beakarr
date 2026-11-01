import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seekarr/features/wizarr/data/wizarr_create_defaults.dart';

void main() {
  group('wizarr create defaults', () {
    test('round-trip preserves snapshot', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await saveCreateDefaults(
        prefs,
        serverIds: const [1, 2],
        libraryIds: const [3, 4],
        expiresInDays: 14,
        unlimited: true,
        durationDays: 45,
        allowDownloads: false,
        allowLiveTv: true,
        allowMobileUploads: false,
      );

      final loaded = loadCreateDefaults(prefs);
      expect(loaded.serverIds, [1, 2]);
      expect(loaded.libraryIds, [3, 4]);
      expect(loaded.expiresInDays, 14);
      expect(loaded.unlimited, isTrue);
      expect(loaded.durationDays, 45);
      expect(loaded.allowDownloads, isFalse);
      expect(loaded.allowLiveTv, isTrue);
      expect(loaded.allowMobileUploads, isFalse);
    });

    test('missing snapshot decodes to documented defaults', () {
      final decoded = decodeCreateDefaults(null);
      expect(decoded.serverIds, isEmpty);
      expect(decoded.libraryIds, isEmpty);
      expect(decoded.expiresInDays, 7);
      expect(decoded.unlimited, isFalse);
      expect(decoded.durationDays, 30);
      expect(decoded.allowDownloads, isTrue);
      expect(decoded.allowLiveTv, isTrue);
      expect(decoded.allowMobileUploads, isTrue);
    });

    test('encode/decode round trip equality', () {
      const snap = (
        serverIds: [5],
        libraryIds: [9],
        expiresInDays: null,
        unlimited: false,
        durationDays: 30,
        allowDownloads: true,
        allowLiveTv: false,
        allowMobileUploads: true,
      );
      final encoded = encodeCreateDefaults(
        serverIds: snap.serverIds,
        libraryIds: snap.libraryIds,
        expiresInDays: snap.expiresInDays,
        unlimited: snap.unlimited,
        durationDays: snap.durationDays,
        allowDownloads: snap.allowDownloads,
        allowLiveTv: snap.allowLiveTv,
        allowMobileUploads: snap.allowMobileUploads,
      );
      final decoded = decodeCreateDefaults(encoded);
      expect(decoded.serverIds, snap.serverIds);
      expect(decoded.libraryIds, snap.libraryIds);
      expect(decoded.expiresInDays, snap.expiresInDays);
      expect(decoded.unlimited, snap.unlimited);
      expect(decoded.durationDays, snap.durationDays);
      expect(decoded.allowDownloads, snap.allowDownloads);
      expect(decoded.allowLiveTv, snap.allowLiveTv);
      expect(decoded.allowMobileUploads, snap.allowMobileUploads);
    });

    test('tolerant decode falls back per field', () {
      final raw = jsonEncode({
        'server_ids': 'nope',
        'library_ids': 42,
        'expires_in_days': 'bad',
        'unlimited': 'yes',
        'duration_days': null,
        'allow_downloads': 1,
        'allow_live_tv': null,
        'allow_mobile_uploads': 'false',
      });
      final decoded = decodeCreateDefaults(raw);
      expect(decoded.serverIds, isEmpty);
      expect(decoded.libraryIds, isEmpty);
      expect(decoded.expiresInDays, 7);
      expect(decoded.unlimited, isFalse);
      expect(decoded.durationDays, 30);
      expect(decoded.allowDownloads, isTrue);
      expect(decoded.allowLiveTv, isTrue);
      expect(decoded.allowMobileUploads, isTrue);
    });

    test('decode handles null expiresInDays (Never)', () {
      final raw = jsonEncode({'expires_in_days': null});
      final decoded = decodeCreateDefaults(raw);
      expect(decoded.expiresInDays, isNull);
    });

    test('decode handles invalid json', () {
      final decoded = decodeCreateDefaults('{not json');
      expect(decoded.serverIds, isEmpty);
      expect(decoded.expiresInDays, 7);
    });
  });
}
