import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seekarr/features/settings/data/settings_service.dart';
import 'package:seekarr/features/settings/data/backup_exceptions.dart';

class SettingsBackupService {
  final SharedPreferences _prefs;
  final SecureSettingsStore _secureStore;

  static const int _supportedVersion = 1;
  static const int _kdfIterations = 200000;
  static final Random _rng = Random.secure();

  SettingsBackupService({
    required SharedPreferences prefs,
    required SecureSettingsStore secureStore,
  }) : _prefs = prefs,
       _secureStore = secureStore;

  Future<String> exportBackup({required String password}) async {
    if (password.isEmpty) throw ArgumentError('Password required');
    final payload = await _buildPayload();
    final payloadBytes = utf8.encode(payload);
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final key = await _deriveKey(password, salt);
    final cipher = AesGcm.with256bits();
    final secretBox = await cipher.encrypt(
      payloadBytes,
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    final ctBytes = Uint8List(
      secretBox.cipherText.length + secretBox.mac.bytes.length,
    );
    ctBytes.setRange(0, secretBox.cipherText.length, secretBox.cipherText);
    ctBytes.setRange(
      secretBox.cipherText.length,
      ctBytes.length,
      secretBox.mac.bytes,
    );
    final envelope = {
      'v': _supportedVersion,
      'kdf': 'pbkdf2-sha256/$_kdfIterations',
      'salt': base64.encode(salt),
      'nonce': base64.encode(nonce),
      'ct': base64.encode(ctBytes),
    };
    return json.encode(envelope);
  }

  Future<({Map<String, Object?> prefs, Map<String, String> secure})>
  importBackup(String envelopeJson, {required String password}) async {
    if (password.isEmpty) throw ArgumentError('Password required');
    final Map<String, dynamic> env;
    try {
      env = json.decode(envelopeJson) as Map<String, dynamic>;
    } catch (_) {
      throw BackupCorruptException();
    }
    final v = env['v'] as int?;
    if (v == null || v > _supportedVersion)
      throw BackupUnsupportedVersionException(v ?? 0);
    if (v < 1) throw BackupUnsupportedVersionException(v);
    final salt = base64.decode(env['salt'] as String);
    final nonce = base64.decode(env['nonce'] as String);
    final ct = base64.decode(env['ct'] as String);
    final tagLength = 16;
    if (ct.length < tagLength) throw BackupCorruptException();
    final cipherText = ct.sublist(0, ct.length - tagLength);
    final macBytes = ct.sublist(ct.length - tagLength);
    final key = await _deriveKey(password, salt);
    final cipher = AesGcm.with256bits();
    try {
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
      final plaintext = await cipher.decrypt(
        secretBox,
        secretKey: SecretKey(key),
      );
      final payload = utf8.decode(plaintext);
      final data = json.decode(payload) as Map<String, dynamic>;
      final prefs = (data['prefs'] as Map<String, dynamic>)
          .map<String, Object?>((k, v) => MapEntry(k, v));
      final secure = (data['secure'] as Map<String, dynamic>)
          .map<String, String>((k, v) => MapEntry(k, v as String));
      return (prefs: prefs, secure: secure);
    } on SecretBoxAuthenticationError {
      throw BackupWrongPasswordException();
    } catch (e) {
      if (e is BackupWrongPasswordException) rethrow;
      throw BackupCorruptException();
    }
  }

  List<int> _randomBytes(int n) => List.generate(n, (_) => _rng.nextInt(256));

  Future<List<int>> _deriveKey(String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _kdfIterations,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    return secretKey.extractBytes();
  }

  Future<String> _buildPayload() async {
    final keys = _prefs.getKeys();
    final prefsMap = <String, Object?>{};
    for (final k in keys) {
      if (k.startsWith('oidc_access_token') ||
          k.startsWith('oidc_refresh_token') ||
          k.startsWith('oidc_token_expiry') ||
          k.startsWith('oidc_pkce_verifier'))
        continue;
      bool? boolV;
      try {
        boolV = _prefs.getBool(k);
      } catch (_) {}
      if (boolV != null)
        prefsMap[k] = boolV;
      else {
        int? intV;
        try {
          intV = _prefs.getInt(k);
        } catch (_) {}
        if (intV != null)
          prefsMap[k] = intV;
        else {
          double? doubleV;
          try {
            doubleV = _prefs.getDouble(k);
          } catch (_) {}
          if (doubleV != null)
            prefsMap[k] = doubleV;
          else {
            String? strV;
            try {
              strV = _prefs.getString(k);
            } catch (_) {}
            if (strV != null) prefsMap[k] = strV;
          }
        }
      }
    }
    final secureAll = await _secureStore.readAll();
    final secureMap = <String, String>{};
    for (final e in secureAll.entries) {
      final k = e.key;
      if (k.startsWith('oidc_access_token_') ||
          k.startsWith('oidc_refresh_token_') ||
          k.startsWith('oidc_token_expiry_') ||
          k.startsWith('oidc_pkce_verifier_'))
        continue;
      secureMap[k] = e.value;
    }
    return json.encode({'prefs': prefsMap, 'secure': secureMap});
  }
}
