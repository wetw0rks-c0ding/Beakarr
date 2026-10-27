import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';


/// Pure-Dart PKCE helpers (no openid_client dependency — avoids native code
/// for xcross builds; only needs http + url_launcher which are already in pubspec).
class PkcePair {
  final String codeVerifier;
  final String codeChallenge;
  const PkcePair(this.codeVerifier, this.codeChallenge);
}

PkcePair generatePkce() {
  final rng = Random.secure();
  final v = base64Url.encode(List.generate(32, (_) => rng.nextInt(256))).replaceAll('=', '');
  final hash = sha256.convert(utf8.encode(v)).bytes;
  final c = base64Url.encode(hash).replaceAll('=', '');
  return PkcePair(v, c);
}

// Note: actual sha256 via package:crypto used in interceptor; this file keeps
// generator logic isolated.
