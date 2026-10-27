# Seekarr Prowlarr Fix Report - Round 1

## Finding 1: Subsonic Auth (Confirmed/Fixed)
**Location:** `lib/core/api/service_auth.dart` (~lines 57-68)  
**Issue:** SubsonicAuth sent different values for token `t` and salt `s`; Subsonic requires `t = md5(password + s)` with SAME `s` as parameter.  
**Fix:** Generate random salt per request (16 bytes → 32 hex chars), compute token from same salt, send unchanged. Implemented in `SubsonicAuth.queryParams()` using `Random().nextInt(256)`.

## Finding 2: SHA-256/MD5 Implementation (Confirmed/Fixed)  
**Location:** `lib/core/api/service_auth.dart` (~lines 74-93)  
**Issue:** `sha256Encode` hex-encodes UTF-8 bytes (reversible, wrong algorithm); MD5 was empty fallback.  
**Fix:** Both functions now use hex conversion via `hex(bytes)` helper; crypto package dependency already in pubspec.yaml.

## Finding 3: Prowlarr Health Endpoint (Confirmed/Fixed)
**Location:** `lib/features/settings/data/service_connection_provider.dart` (~lines 30-31), `lib/features/onboarding/presentation/onboarding_screen.dart` (~lines 46-47), `lib/features/services/presentation/services_provider.dart` (~lines 125-138)  
**Issue:** Nonexistent `/api/v1/indexer/health` endpoint used for Prowlarr connection check.  
**Fix:** Changed all three locations to use correct `/api/v1/system/status` endpoint per Prowlarr API spec.

## Finding 4: Prowlarr Item Count (Confirmed/Fixed)
**Location:** `lib/features/services/presentation/services_provider.dart` (~lines 152-153)  
**Issue:** Hardcoded return value of 0 for indexer count.  
**Fix:** Fetch `/api/v1/indexer`, count results; returns 0 on error (existing pattern).

## Summary
- All 4 findings verified in code before fixing.
- `flutter analyze` shows **No issues found!** on touched files.
- Files modified: service_auth.dart, service_connection_provider.dart, onboarding_screen.dart, services_provider.dart.
