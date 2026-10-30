#!/usr/bin/env bash
# Debug device build with build identity baked in.
#
# Every build lands in dist/debug/ as
#   seekarr-debug-<pubspec-version>+<short-hash>-<UTC-timestamp>.apk
# so any install on the Pixel is traceable (Settings → Version shows
# `0.9.x-alpha (abc1234)`) and rollback = reinstall an older file.
# Keeps the 10 newest, prunes the rest. dist/ is gitignored.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: *//;s/+.*//')
HASH="$(git rev-parse --short HEAD)"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
OUT_DIR="dist/debug"
OUT_APK="seekarr-debug-${VERSION}+${HASH}-${STAMP}.apk"

mkdir -p "$OUT_DIR"
flutter build apk --debug --split-per-abi \
  --dart-define="GIT_HASH=${HASH}" \
  --dart-define="BUILD_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  | tail -1
cp build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk "$OUT_DIR/$OUT_APK"

# Prune to newest 10.
ls -t "$OUT_DIR"/seekarr-debug-*.apk 2>/dev/null | tail -n +11 | xargs -r rm --

if [ "${1:-}" = "--install" ]; then
  adb -s 1B181FDF60043F install -r "$OUT_DIR/$OUT_APK" | tail -1
fi

echo "BUILD: $OUT_DIR/$OUT_APK"
echo "--- rollback menu (newest first) ---"
ls -t "$OUT_DIR"/seekarr-debug-*.apk
