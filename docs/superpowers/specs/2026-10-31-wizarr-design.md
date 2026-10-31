# Wizarr Integration — Design Spec (2026-10-31)

## Intent

Add Wizarr (v3, API-key auth) as a Beakarr service so the admin can
monitor guest onboarding: invitations (codes/links, usage, expiry) and
managed users. Phased: **v1 read-only** (this spec) for fast device
proof, **v2 invite creation** as a gated follow-up. Approved approach:
full sibling mirroring the OMV/NPM loop (approach A).

Non-goals: in-app guest signup flow, invite revocation, user
add/remove, Plex/Jellyfin/Emby management itself.

## Architecture

Mirrors `lib/features/openmediavault/` and `lib/features/npm/` file
for file; no new patterns:

- `lib/features/wizarr/data/wizarr_client.dart` — Dio client, `X-API-Key`
  API key, `User-Agent: Beakarr`, 10/10/15 s timeouts. In-code
  read-only allowlist (same enforcement shape as
  `OpenMediaVaultClient._readOnly`); any non-listed call throws
  `StateError` before hitting the network.
- `lib/features/wizarr/data/wizarr_service.dart` — thin mapping
  (`getInvitations()`, `getUsers()`); tolerant parsing lives in
  models, never here.
- `lib/features/wizarr/data/wizarr_providers.dart` — client, service,
  and `FutureProvider.autoDispose` list providers.
- `lib/features/wizarr/domain/models/` — `wizarr_invitation.dart`
  (code, invite URL, server/type, max uses, used count, expires at,
  created at), `wizarr_user.dart` (username, server/type, email?,
  created/last-active?). All fields nullable; reuse
  `dynamic_map_utils`/`omv_parse`-style helpers.
- `lib/features/wizarr/presentation/wizarr_screen.dart` —
  `SegmentedButton<int>` + conditional child (Overview-style switch,
  NOT TabBarView): **Invitations / Users** tabs. Invite tile: code,
  server pill, uses-left + expiry chips, tap-to-copy link.
- `lib/features/wizarr/presentation/widgets/` — `wizarr_invite_tile.dart`,
  `wizarr_user_tile.dart` (no `Expanded` inside unbounded parents —
  see OMV 0.9.17 lesson: full-width bars only as Column children).
- Plumbing (existing switches only): `ServiceKey.wizarr` (title, icon,
  accent, routeParam), `_wizarrRoutes` under `/services`,
  `SettingsModel.wizarrUrl` + secure-store `wizarrApiKey`, settings
  Test Connection + auto-save, dashboard tile (ONLINE + open-invite
  count, where open = unexpired with remaining uses),
  `FloatingNavBarMetrics` bottom clearance, nav-clearance
  tripwire exemption check.

## Endpoints (v1, verified live 2026-11-01 against owner's Wizarr v3)

Base: `{url}/api`. Auth header: `X-API-Key: <key>`
(`securityDefinitions: apikey in header name X-API-Key`; a live probe
confirmed `Authorization: Bearer` returns `401 Unauthorized`, so Bearer
is NOT used).

- `GET {url}/api/invitations` → `200`, `InvitationList`.
- `GET {url}/api/users` → `200`, `UserList`.
- Test Connection hits `GET /api/invitations` with `X-API-Key` and
  requires `200`.

## Data flow

Settings (URL + key) → `wizarrClientProvider` (throws
`'Wizarr not configured'` when empty) → `wizarrServiceProvider` →
list providers → `AsyncValueWidget` per tab (loading spinner / error
state / `RefreshIndicator` + `ListView`). Dashboard tile and health
check reuse the service provider (summary counts only, never full
bodies). API key lives in secure storage, never in logs (NPM
precedent: no request-body logger on the auth path).

## Error handling

- No creds → `NotConfiguredPlaceholder` (existing widget).
- HTTP 401/403 → error state with server message where present
  (NPM precedent: surface `"Invalid email or password"`, not bare
  codes); no secret persistence on failed test.
- Unparseable rows are skipped item-wise (`whereType`-style), never
  whole-list failures; empty lists render explicit empty states.
- Timeouts: 15 s receive. Release-build layout rule from OMV 0.9.17:
  no flex widgets inside unbounded parents; the regression test
  below pins the previously-crashing shape.

## Testing

- Unit: model tolerance (missing/null/extra keys, `-1`/empty
  sentinels if the API uses them), client allowlist (mutating call
  throws `StateError`), service mapping.
- Widget: screen renders tabs + data with canned providers; a
  live-shaped regression test with fully-populated models (the OMV
  0.9.17 crash passed canned tests and failed live-shaped ones).
- Tab-switch widget test (invitations ↔ users).
- `flutter analyze` clean; full suite green.
- Device proof (Pixel 6, owner's Wizarr v3): Test Connection green +
  auto-save; tile ONLINE with correct count; both tabs vs live data;
  error path with bad key (message surfaced, nothing persisted).
- Review: OCR local pre-pass, exactly one CodeRabbit gate.

## Acceptance criteria (v1)

1. Settings Test Connection green against live Wizarr v3, auto-save,
   tile ONLINE with accurate open-invite count.
2. Invitations + Users tabs render live data; switching works by
   touch; pull-to-refresh works on both.
3. Bad key → server message surfaced, nothing persisted, no secret
   in logs.
4. Suite green, analyze clean, CodeRabbit gate passed, per-release
   notes + `docs/project-log/` entry, tagged alpha + APK + xcross
   IPA (established loop).

## Phase 2 (explicitly out of v1)

`POST` create-invitation behind an explicit confirm dialog, its own
spec delta + review gate + device proof. Revoke/delete deferred
until the owner asks.
