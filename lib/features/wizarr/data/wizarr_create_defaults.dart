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
  final map = <String, dynamic>{
    'server_ids': List<int>.from(serverIds),
    'serverIds': List<int>.from(serverIds),
    'library_ids': List<int>.from(libraryIds),
    'libraryIds': List<int>.from(libraryIds),
    'expires_in_days': expiresInDays,
    'expiresInDays': expiresInDays,
    'unlimited': unlimited,
    'duration_days': durationDays,
    'durationDays': durationDays,
    'allow_downloads': allowDownloads,
    'allowDownloads': allowDownloads,
    'allow_live_tv': allowLiveTv,
    'allowLiveTv': allowLiveTv,
    'allow_mobile_uploads': allowMobileUploads,
    'allowMobileUploads': allowMobileUploads,
  };
  return jsonEncode(map);
}

/// Looks up the first present (non-null OR explicitly present) value among
/// [keys] in [map], returning null if none of the keys exist.
dynamic _lookup(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    if (map.containsKey(key)) {
      return map[key];
    }
  }
  return _missing;
}

const Object _missing = Object();

List<int> _asIntList(dynamic value) {
  if (value == null) return const <int>[];
  if (value is List) {
    final out = <int>[];
    for (final element in value) {
      if (element is int) {
        out.add(element);
      } else if (element is num) {
        out.add(element.toInt());
      } else {
        // Wrong element type -> whole field falls back to default (empty).
        return const <int>[];
      }
    }
    return out;
  }
  // Wrong type -> default.
  return const <int>[];
}

int _asInt(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  return fallback;
}

bool _asBool(dynamic value, bool fallback) {
  if (value is bool) return value;
  return fallback;
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

  // serverIds
  List<int> serverIds = const <int>[];
  List<int> libraryIds = const <int>[];
  int? expiresInDays = 7;
  bool unlimited = false;
  int durationDays = 30;
  bool allowDownloads = true;
  bool allowLiveTv = true;
  bool allowMobileUploads = true;

  if (map != null) {
    final serverVal = _lookup(map, const [
      'serverIds',
      'server_ids',
      'servers',
    ]);
    if (serverVal != _missing) {
      serverIds = _asIntList(serverVal);
    }

    final libraryVal = _lookup(map, const [
      'libraryIds',
      'library_ids',
      'libraries',
    ]);
    if (libraryVal != _missing) {
      libraryIds = _asIntList(libraryVal);
    }

    final expiryVal = _lookup(map, const [
      'expiresInDays',
      'expires_in_days',
      'expiresIn',
      'expiryDays',
    ]);
    if (expiryVal != _missing) {
      if (expiryVal == null) {
        expiresInDays = null;
      } else if (expiryVal is int || expiryVal is num) {
        expiresInDays = _asInt(expiryVal, 7);
      } else if (expiryVal is String) {
        final parsed = int.tryParse(expiryVal);
        expiresInDays = parsed; // wrong string -> null? fallback? 
        // Per spec, wrong type falls back to default 7. A non-numeric string
        // is a wrong type, so use default.
        if (parsed == null) expiresInDays = 7;
      } else {
        expiresInDays = 7;
      }
    }

    final unlimitedVal = _lookup(map, const ['unlimited']);
    if (unlimitedVal != _missing) {
      unlimited = _asBool(unlimitedVal, false);
      // If wrong type, _asBool returns fallback false, which matches default.
    }

    final durationVal = _lookup(map, const [
      'durationDays',
      'duration_days',
      'duration',
    ]);
    if (durationVal != _missing) {
      if (durationVal is String) {
        // "unlimited" is not a day count; fall back to default.
        final parsed = int.tryParse(durationVal);
        durationDays = parsed ?? 30;
      } else {
        durationDays = _asInt(durationVal, 30);
      }
    }

    final downloadsVal = _lookup(map, const ['allowDownloads', 'allow_downloads']);
    if (downloadsVal != _missing) {
      allowDownloads = _asBool(downloadsVal, true);
    }

    final liveTvVal = _lookup(map, const ['allowLiveTv', 'allow_live_tv']);
    if (liveTvVal != _missing) {
      allowLiveTv = _asBool(liveTvVal, true);
    }

    final mobileVal = _lookup(map, const [
      'allowMobileUploads',
      'allow_mobile_uploads',
    ]);
    if (mobileVal != _missing) {
      allowMobileUploads = _asBool(mobileVal, true);
    }
  }

  // If a field was present but wrong type, _asBool returns fallback already.
  // But for unlimited wrong type, _asBool returns false (default) - good.
  // However if unlimited present wrong type, we called _asBool -> false. Good.

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
