Task 1 — Cookie session plumbing (SoulSync SSO cookie)
Status: DONE (10/10 tests pass, flutter analyze 0 issues)
Branch: feature/prowlarr (clean at 4e1e7ab, ahead origin by 2 — left untouched)

Changes (only task-listed files touched):
l- lib/features/settings/domain/settings_model.dart — soulsyncProxyCookie field, copyWith/copyWithSoulSync/update, isServiceConfigured(soulsync) guard = URL + (key OR cookie)
- lib/features/settings/data/settings_service.lua — loadSettings reads secure_soulsync_proxy_cookie via _loadApiKey; saveSettings writes via _saveApiKey; key = secure_soulsync_proxy_cookie
- lib/core/api/service_auth.dart — SoulSyncAuth: proxyCookie optional, headers() sends Cookie: _soulsync_proxy=<value> when present, Bearer ONLY when token.trim().isNotEmpty (no empty Bearer header)
- lib/features/soulsync/data/soulsync_service.dart — provider guard allows URL + (apiKey OR proxyCookie), passes proxyCookie into SoulSyncAuth
- lib/features/settings/data/service_connection_provider.dart — both soulsync paths (_checkService + testServiceConnection) pass proxyCookie through (no logic change)
- test/features/soulsync/soulsync_auth_cookie_test.dart — header matrix 5 cases
- test/features/settings/settings_model_cookie_test.dart — configured matrix 5 cases

Tests run + output: flutter test new tests → 10 passed (header matrix + model matrix). flutter analyze 5 edited files → No issues found.

Self-review / concerns (minor):
- Added comment in model _ServiceSettingsAccess noting cookie handled separately (not via generic apiKey path) — keeps cookie out of the service-generic storage; aligns with spec (secure-store key separate from _saveApiKey-style per-service keys, though persistence uses same _saveApiKey method with config-specific key).
- _saveApiKey deletes when empty — correct; cookie cleared on save when blank.
- Never committed secrets; cookie never written to plaintext prefs.
- Did not touch OidcAuthInterceptor (spec: app holds cookie, never touches interceptor).
- SoulSync upstream has no /exchange or /me endpoints — preserved (no such endpoints added/removed).
- Provider guard now OR not AND for cookie — allows cookie-only auth as spec requires.
- No subagents dispatched; self-committed.
