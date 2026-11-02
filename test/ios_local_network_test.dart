import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// iOS 14+ requires NSLocalNetworkUsageDescription before the system will
/// prompt for Local Network access; without the key, LAN addresses (e.g.
/// http://192.168.4.185:81) fail at TCP level and Dio surfaces only a
/// generic connectionError — the "Connection failed" seen on iPhone while
/// Android (no such permission) stayed green. This test pins the key's
/// presence only: the user must still grant access on-device, so a green
/// test is necessary but not sufficient — the iPhone retest is the proof.
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
