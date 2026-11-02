import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seekarr/core/app_version.dart';

/// The in-app updater compares GitHub releases against [kAppVersion];
/// if this constant drifts behind pubspec, installed releases get
/// re-offered as updates forever (seen with 0.9.18 showing as 0.9.16).
void main() {
  test('kAppVersion matches pubspec version (sans build metadata)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'^version:\s*([^\s+]+)', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec has no version: field');
    expect(kAppVersion, match!.group(1));
  });
}
