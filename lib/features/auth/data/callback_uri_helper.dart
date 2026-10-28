/// Helper to parse and handle app_links deep-link callbacks for OIDC.
class CallbackUriHelper {
  /// Returns true if the URI matches the expected callback scheme and path.
  static bool isCallbackUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'seekarr') return false;
    
    // Check for the callback path pattern - handles various URI formats
    final pathLower = uri.path.toLowerCase();
    
    // Accept: /oauth/callback, oauth/callback, /oauth/callback?..., oauth/callback?...
    if (pathLower == '/oauth/callback' || 
        pathLower == 'oauth/callback' ||
        pathLower.startsWith('/oauth/callback') ||
        pathLower.startsWith('oauth/callback')) {
      return true;
    }
    
    // For edge cases where path might be just callback due to uppercase normalization
    // Check if it contains "callback" as a segment (case-insensitive already done)
    final segments = pathLower.split('/');
    if (segments.length >= 2 && segments[1] == 'callback') {
      return true;
    }
    
    return false;
  }

  /// Extracts the authorization code from a callback URI, if present.
  static String? extractCode(Uri uri) {
    final code = uri.queryParameters['code'];
    return code != null ? code.trim() : null;
  }

  /// Extracts the error description from a callback URI, if present.
  static String? extractError(Uri uri) {
    final error = uri.queryParameters['error'];
    return error != null ? error.trim() : null;
  }
}
