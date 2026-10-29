import 'package:dio/dio.dart';

import 'package:seekarr/core/app_version.dart';

/// A single asset attached to a GitHub release.
class GitHubAsset {
  final String name;
  final String browserDownloadUrl;
  final int size;

  const GitHubAsset({
    required this.name,
    required this.browserDownloadUrl,
    this.size = 0,
  });

  factory GitHubAsset.fromJson(Map<String, dynamic> json) {
    return GitHubAsset(
      name: (json['name'] as String?) ?? '',
      browserDownloadUrl: (json['browser_download_url'] as String?) ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A GitHub release from the seekarr fork.
class GitHubRelease {
  final String tagName;
  final String name;
  final bool draft;
  final bool prerelease;
  final List<GitHubAsset> assets;

  const GitHubRelease({
    required this.tagName,
    this.name = '',
    this.draft = false,
    this.prerelease = false,
    this.assets = const [],
  });

  String get version => stripLeadingV(tagName);

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    final assetsJson = (json['assets'] as List<dynamic>?) ?? const [];
    return GitHubRelease(
      tagName: (json['tag_name'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      draft: (json['draft'] as bool?) ?? false,
      prerelease: (json['prerelease'] as bool?) ?? false,
      assets: assetsJson
          .whereType<Map<String, dynamic>>()
          .map(GitHubAsset.fromJson)
          .toList(),
    );
  }
}

/// Strips a leading 'v'/'V' from a version tag.
String stripLeadingV(String value) {
  final trimmed = value.trim();
  if (trimmed.toLowerCase().startsWith('v') && trimmed.length > 1) {
    return trimmed.substring(1);
  }
  return trimmed;
}

class _ParsedVersion {
  final List<int> core;
  final String pre;
  const _ParsedVersion(this.core, this.pre);
}

_ParsedVersion _parseVersion(String value) {
  var s = value.trim();
  // Drop build metadata.
  final plus = s.indexOf('+');
  if (plus >= 0) s = s.substring(0, plus);
  String pre = '';
  final dash = s.indexOf('-');
  if (dash >= 0) {
    pre = s.substring(dash + 1);
    s = s.substring(0, dash);
  }
  final core = s
      .split('.')
      .map((part) => int.tryParse(part.trim()) ?? 0)
      .toList();
  if (core.isEmpty) core.add(0);
  return _ParsedVersion(core, pre);
}

/// Compares two version strings. Returns negative if [a] < [b], zero if equal,
/// positive if [a] > [b]. Dotted numeric core is compared first; a version
/// without a pre-release suffix is greater than one with the same core. Among
/// pre-releases the suffix is compared lexicographically.
int compareVersions(String a, String b) {
  final pa = _parseVersion(stripLeadingV(a));
  final pb = _parseVersion(stripLeadingV(b));
  final maxLen = pa.core.length > pb.core.length
      ? pa.core.length
      : pb.core.length;
  for (var i = 0; i < maxLen; i++) {
    final ai = i < pa.core.length ? pa.core[i] : 0;
    final bi = i < pb.core.length ? pb.core[i] : 0;
    if (ai != bi) return ai.compareTo(bi);
  }
  final aPre = pa.pre;
  final bPre = pb.pre;
  if (aPre.isEmpty && bPre.isEmpty) return 0;
  if (aPre.isEmpty) return 1;
  if (bPre.isEmpty) return -1;
  return aPre.compareTo(bPre);
}

/// Picks the highest non-draft release. Returns null if none.
GitHubRelease? pickLatestRelease(Iterable<GitHubRelease> releases) {
  GitHubRelease? best;
  for (final r in releases) {
    if (r.draft) continue;
    if (best == null || compareVersions(r.version, best.version) > 0) {
      best = r;
    }
  }
  return best;
}

/// Finds the first asset whose name contains [needle].
GitHubAsset? pickAsset(GitHubRelease release, String needle) {
  for (final a in release.assets) {
    if (a.name.contains(needle)) return a;
  }
  return null;
}

/// Service that talks to the GitHub releases API.
class AppUpdater {
  static const releasesUrl =
      'https://api.github.com/repos/wetw0rks-c0ding/seekarr/releases';

  final Dio _dio;

  AppUpdater({Dio? dio}) : _dio = dio ?? Dio();

  Future<List<GitHubRelease>> fetchReleases() async {
    final response = await _dio.get<dynamic>(
      releasesUrl,
      options: Options(headers: const {'Accept': 'application/vnd.github+json'}),
    );
    final data = response.data;
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(GitHubRelease.fromJson)
        .toList();
  }

  /// Returns the latest release if it is newer than [kAppVersion], else null.
  Future<GitHubRelease?> checkForUpdate() async {
    final releases = await fetchReleases();
    final latest = pickLatestRelease(releases);
    if (latest == null) return null;
    if (compareVersions(latest.version, kAppVersion) <= 0) return null;
    return latest;
  }

  Future<void> downloadAsset(
    GitHubAsset asset,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    await _dio.download(
      asset.browserDownloadUrl,
      savePath,
      onReceiveProgress: onProgress,
    );
  }
}