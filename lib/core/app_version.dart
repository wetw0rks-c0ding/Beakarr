/// Canonical app version shown in the UI (Settings → About).
///
/// Keep in sync with the `version:` field in pubspec.yaml on every release.
const String kAppVersion = '0.9.15-alpha';

/// Short git commit baked in at build time via
/// `--dart-define=GIT_HASH=...` (see scripts/build-debug.sh and
/// scripts/release.sh). Reads `dev` for IDE/debug runs without defines,
/// so every installable build is identifiable for rollback.
const String kBuildHash = String.fromEnvironment('GIT_HASH', defaultValue: 'dev');

/// UTC build timestamp baked in at build time via
/// `--dart-define=BUILD_TIME=...`. Empty when not provided.
const String kBuildTime = String.fromEnvironment('BUILD_TIME', defaultValue: '');

/// Version line with build identity, e.g. `0.9.11-alpha (a1b2c3d)`.
String get kAppVersionLabel =>
    kBuildHash == 'dev' ? kAppVersion : '$kAppVersion ($kBuildHash)';
