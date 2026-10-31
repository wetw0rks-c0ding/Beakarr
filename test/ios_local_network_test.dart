import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// iOS 14+ blocks TCP to LAN addresses (e.g. http://192.168.4.185:81)
/// unless the app declares NSLocalNetworkUsageDescription and the user
/// grants Local Network access. Without the key the system denies the
/// connection outright and Dio surfaces only a generic connectionError —
/// exactly the "Connection failed" seen on iPhone while Android (no such
/// permission) stayed green. Regression test: the key must exist with a
/// non-empty purpose string.
void main() {
  // Two-step check: key presence first (clear failure message naming the
  // missing key), then a non-empty purpose string (what iOS shows).
  test('iOS Info.plist declares Local Network usage', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist.contains('NSLocalNetworkUsageDescription'), isTrue,
        reason: 'missing NSLocalNetworkUsageDescription — '
            'iOS cannot reach LAN services');
    final value = RegExp(
      r'<key>NSLocalNetworkUsageDescription</key>\s*<string>([^<]*)</string>',
    ).firstMatch(plist)?.group(1)?.trim();
    expect(value, isNotNull);
    expect(value, isNotEmpty);
  });
}
