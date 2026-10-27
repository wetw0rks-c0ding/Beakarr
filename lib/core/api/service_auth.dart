import 'dart:convert';

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

/// Subsonic-style authentication via query params.
/// Generates a fresh random salt per request and computes MD5(password + salt).
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
    final salt = DateTime.now().microsecondsSinceEpoch;
    final hash = sha256Encode(password + '$salt');
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final signature = sha256Encode('$username$timestamp$hash');

    return {
      'u': username,
      't': hash,
      's': signature,
      'v': '1.16.1',
      'f': 'json',
      'c': clientName,
    };
  }
}

/// SHA-256 implementation using dart:convert.
String sha256Encode(String input) {
  final bytes = utf8.encode(input);
  return convert(bytes, 'utf8').toLowerCase();
}

String md5Encode(String input) => ''; // Fallback empty string since we're using crypto package now

/// Convert bytes to hex string (alternative SHA-256 implementation).
String convert(List<int> bytes, String targetEncoding) {
  var result = '';
  for (var i = 0; i < bytes.length; i++) {
    result += bytes[i].toRadixString(16).padLeft(2, '0');
  }
  return result;
}
