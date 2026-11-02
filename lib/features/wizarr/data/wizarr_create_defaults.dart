import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key under which the last-used invite-creation snapshot
/// is persisted (non-secret JSON).
const String wizLastInviteKey = 'wiz_last_invite';

/// Encodes a create-invite defaults snapshot to a JSON string.
String encodeCreateDefaults({
  required List<int> serverIds,
  required List<int> libraryIds,
  required int? expiresInDays,
  required bool unlimited,
  required int durationDays,
  required bool allowDownloads,
  required bool allowLiveTv,
  required bool allowMobileUploads,
}) {
  return jsonEncode(<String, dynamic>{
    'serverIds': List<int>.from(serverIds),
    'libraryIds': List<int>.from(libraryIds),
    'expiresInDays': expiresInDays,
    'unlimited': unlimited,
    'durationDays': durationDays,
    'allowDownloads': allowDownloads,
    'allowLiveTv': allowLiveTv,
    'allowMobileUploads': allowMobileUploads,
  });
}

/// Decodes a create-invite defaults snapshot. Tolerant: a null/invalid input
/// or wrong-typed field falls back to the documented defaults per field.
({List<int> serverIds, List<int> libraryIds, int? expiresInDays, bool unlimited, int durationDays, bool allowDownloads, bool allowLiveTv, bool allowMobileUploads}) decodeCreateDefaults(
  String? raw,
) {
  Map<String, dynamic>? map;
  if (raw != null) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        map = decoded;
      } else if (decoded is Map) {
        map = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      map = null;
    }
  }

  List<int> serverIds = const <int>[];
  List<int> libraryIds = const <int>[];
  int? expiresInDays = 7;
  bool unlimited = false;
  int durationDays = 30;
  bool allowDownloads = true;
  bool allowLiveTv = true;
  bool allowMobileUploads = true;

  if (map != null) {
    // serverIds
    final serverVal = map['serverIds'];
    if (map.containsKey('serverIds')) {
      serverIds = _asIntList(serverVal);
    }

    final libraryVal = map['libraryIds'];
    if (map.containsKey('libraryIds')) {
      libraryIds = _asIntList(libraryVal);
    }

    if (map.containsKey('expiresInDays')) {
      final v = map['expiresInDays'];
      if (v == null) {
        expiresInDays = null;
      } else if (v is int) {
        expiresInDays = v;
      } else {
        expiresInDays = 7;
      }
    }

    if (map.containsKey('unlimited')) {
      final v = map['unlimited'];
      if (v is bool) {
        unlimited = v;
      } else {
        unlimited = false;
      }
    }

    if (map.containsKey('durationDays')) {
      final v = map['durationDays'];
      if (v is int) {
        durationDays = v;
      } else {
        durationDays = 30;
      }
    }

    if (map.containsKey('allowDownloads')) {
      final v = map['allowDownloads'];
      if (v is bool) {
        allowDownloads = v;
      } else {
        allowDownloads = true;
      }
    }

    if (map.containsKey('allowLiveTv')) {
      final v = map['allowLiveTv'];
      if (v is bool) {
        allowLiveTv = v;
      } else {
        allowLiveTv = true;
      }
    }

    if (map.containsKey('allowMobileUploads')) {
      final v = map['allowMobileUploads'];
      if (v is bool) {
        allowMobileUploads = v;
      } else {
        allowMobileUploads = true;
      }
    }
  }

  return (
    serverIds: List<int>.from(serverIds),
    libraryIds: List<int>.from(libraryIds),
    expiresInDays: expiresInDays,
    unlimited: unlimited,
    durationDays: durationDays,
    allowDownloads: allowDownloads,
    allowLiveTv: allowLiveTv,
    allowMobileUploads: allowMobileUploads,
  );
}

List<int> _asIntList(dynamic value) {
  if (value == null) return const <int>[];
  if (value is List) {
    final out = <int>[];
    for (final element in value) {
      if (element is int) {
        out.add(element);
      } else {
        return const <int>[];
      }
    }
    return out;
  }
  return const <int>[];
}

/// Loads the persisted snapshot, or documented defaults when absent.
({List<int> serverIds, List<int> libraryIds, int? expiresInDays, bool unlimited, int durationDays, bool allowDownloads, bool allowLiveTv, bool allowMobileUploads}) loadCreateDefaults(
  SharedPreferences prefs,
) {
  return decodeCreateDefaults(prefs.getString(wizLastInviteKey));
}

/// Persists a snapshot under [wizLastInviteKey].
Future<void> saveCreateDefaults(
  SharedPreferences prefs, {
  required List<int> serverIds,
  required List<int> libraryIds,
  required int? expiresInDays,
  required bool unlimited,
  required int durationDays,
  required bool allowDownloads,
  required bool allowLiveTv,
  required bool allowMobileUploads,
}) async {
  await prefs.setString(
    wizLastInviteKey,
    encodeCreateDefaults(
      serverIds: serverIds,
      libraryIds: libraryIds,
      expiresInDays: expiresInDays,
      unlimited: unlimited,
      durationDays: durationDays,
      allowDownloads: allowDownloads,
      allowLiveTv: allowLiveTv,
      allowMobileUploads: allowMobileUploads,
    ),
  );
}
