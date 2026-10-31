import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/core/updater/app_updater.dart';

void main() {
  group('compareVersions', () {
    test('newer', () {
      expect(compareVersions('0.9.4', '0.9.3-alpha'), greaterThan(0));
    });
    test('older', () {
      expect(compareVersions('0.9.2', '0.9.3-alpha'), lessThan(0));
    });
    test('equal', () {
      expect(compareVersions('0.9.3-alpha', '0.9.3-alpha'), 0);
    });
    test('prerelease older than release', () {
      expect(compareVersions('0.9.3-alpha', '0.9.3'), lessThan(0));
    });
    test('prerelease ordering', () {
      expect(compareVersions('0.9.3-alpha', '0.9.3-beta'), lessThan(0));
    });
    test('strips leading v', () {
      expect(compareVersions('v1.0.0', '0.9.3'), greaterThan(0));
    });
  });

  group('pickLatestRelease', () {
    test('skips drafts and picks highest', () {
      final releases = [
        const GitHubRelease(tagName: 'v0.9.1', draft: true),
        const GitHubRelease(tagName: 'v0.9.2'),
        const GitHubRelease(tagName: 'v0.9.4-alpha'),
      ];
      final latest = pickLatestRelease(releases);
      expect(latest, isNotNull);
      expect(latest!.version, '0.9.4-alpha');
    });

    test('includes prereleases over older release', () {
      final releases = [
        const GitHubRelease(tagName: 'v0.9.3'),
        const GitHubRelease(tagName: 'v0.9.4-alpha'),
      ];
      final latest = pickLatestRelease(releases);
      expect(latest!.version, '0.9.4-alpha');
    });

    test('returns null when all drafts', () {
      final releases = [const GitHubRelease(tagName: 'v1.0.0', draft: true)];
      expect(pickLatestRelease(releases), isNull);
    });
  });

  group('pickAsset', () {
    test('matches needle', () {
      final release = GitHubRelease(
        tagName: 'v0.9.4',
        assets: const [
          GitHubAsset(name: 'seekarr-0.9.4-android.apk', browserDownloadUrl: 'u'),
          GitHubAsset(name: 'seekarr-0.9.4-ios.ipa', browserDownloadUrl: 'i'),
        ],
      );
      expect(pickAsset(release, '-android.apk')?.name, 'seekarr-0.9.4-android.apk');
      expect(pickAsset(release, '-ios.ipa')?.name, 'seekarr-0.9.4-ios.ipa');
      expect(pickAsset(release, '-foo'), isNull);
    });
  });
}