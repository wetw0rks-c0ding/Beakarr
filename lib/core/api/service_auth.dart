import 'dart:convert' show utf8;
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Abstract interface for service authentication.
/// Each implementation knows how to attach headers and query params to requests.
abstract interface class ServiceAuth {
  /// Returns headers to be merged with every request.
  Map<String, String> headers();

  /// Returns query parameters to be merged with every request (can be empty).
  Map<String, dynamic> queryParams();
}

/// API Key authentication via [X-Api-Key] header.
class ApiKeyHeaderAuth implements ServiceAuth {
  final String apiKey;

  const ApiKeyHeaderAuth(this.apiKey);

  @override
  Map<String, String> headers() => {'X-Api-Key': apiKey};

  @override
  Map<String, dynamic> queryParams() => {};
}

/// Bearer token authentication via [Authorization: Bearer <token>] header.
class BearerAuth implements ServiceAuth {
  final String token;

  const BearerAuth(this.token);

  @override
  Map<String, String> headers() => {'Authorization': 'Bearer $token'};

  @override
  Map<String, dynamic> queryParams() => {};
}

/// SoulSync authentication: Bearer token plus optional profile scoping
/// header, plus an opaque proxy/app session cookie value (see
/// findSoulSyncSessionCookie: one or more `name=value` pairs).
class SoulSyncAuth implements ServiceAuth {
  final String token;
  final String? profileId;
  final String? proxyCookie;

  const SoulSyncAuth(
    this.token, {
    this.profileId,
    this.proxyCookie,
  });

  @override
  Map<String, String> headers() {
    final h = <String, String>{};
    if (token.trim().isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    if (profileId != null && profileId!.trim().isNotEmpty) {
      h['X-Profile-Id'] = profileId!.trim();
    }
    if (proxyCookie != null && proxyCookie!.trim().isNotEmpty) {
      // Sent verbatim (may carry proxy session and/or app profile
      // session pairs); servers ignore unknown cookies.
      h['Cookie'] = proxyCookie!.trim();
    }
    return h;
  }

  @override
  Map<String, dynamic> queryParams() => {};
}

/// Subsonic-style authentication via query params.
/// Generates a fresh random salt per request and computes MD5(password + salt).
/// Per Subsonic spec: t = md5(password + s) where s is the same value sent as parameter s.
class SubsonicAuth implements ServiceAuth {
  final String username;
  final String password;
  final String clientName;

  const SubsonicAuth(
    this.username,
    this.password, {
    this.clientName = 'Seekarr',
  });

  @override
  Map<String, String> headers() => {};

  @override
  Map<String, dynamic> queryParams() {
    // Generate a random salt per request (32 hex chars from 16 bytes)
    final rng = Random();
    final saltBytes = List.generate(16, (_) => rng.nextInt(256));
    final salt = saltBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');

    // Subsonic: t = md5(password + s), sending the same s as parameter s
    final passwordSalt = utf8.encode(password + salt);
    final tokenHash = md5.convert(passwordSalt).toString();

    return {
      'u': username,
      't': tokenHash,
      's': salt,
      'v': '1.16.1',
      'f': 'json',
      'c': clientName,
    };
  }
}
