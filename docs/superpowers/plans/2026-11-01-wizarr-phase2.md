# Wizarr Phase 2 (invite creation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the owner create Wizarr guest invitations from the app via a full form sheet.

**Architecture:** One new gated POST on the existing Dio client, two new list providers (servers, libraries), two small models, one fullscreen form route; last-used defaults in SharedPreferences. No new dependencies.

**Tech Stack:** Flutter, flutter_riverpod, Dio, go_router; SharedPreferences (already a dependency, mockable in tests).

**Spec:** `docs/superpowers/specs/2026-10-31-wizarr-design.md` (Phase 2 section; field names verified against live swagger `InvitationCreateRequest`/`Server`/`Library` on 2026-11-01)

## Global Constraints

- Read-only v1 invariant holds except exactly one mutating key (`Invitation.create` → `POST /api/invitations`); every other non-list call still throws `StateError` before any network I/O.
- API key in secure storage, never in logs; no request-body logger on any Wizarr path.
- Every shell screen keeps the floating-nav-bar bottom inset; `nav_clearance_test` must keep passing.
- TDD: failing test first; `flutter test`, `flutter analyze` clean before each commit.
- No invite revocation, no user add/remove, no server management in this phase.
- `wizard_bundle_id` is never sent (automatic selection).

## Review Focus

- A non-201 response (400 envelope, 401 HTML login page) surfaces as an error state, never a parse crash — pin with a 400-envelope test and an HTML-200 test in the owning task, most likely first.
- Empty server list renders a "no servers" state with creation disabled — pin with an empty-servers widget test.
- Submit with no server selected shows validation and performs zero POSTs — pin with a mock-adapter call-count test (service-level: `createInvitation(serverIds: [])` throws `ArgumentError` before any I/O; widget-level: empty server list renders "no servers" with creation disabled).
- Unlimited toggle on hides/disables the duration field and sends `duration: "unlimited"` — pin with a payload-capture test.
- Success with a relative `/j/<code>` link shows the absolute share URL — pin with a sheet test asserting the full URL text (reuses `absoluteInviteUrl`).

---
### Task 1: Client POST, service create, server/library models + providers

**Files:**
- Modify: `lib/features/wizarr/data/wizarr_client.dart`
- Modify: `lib/features/wizarr/data/wizarr_service.dart`
- Create: `lib/features/wizarr/domain/models/wizarr_server.dart`, `lib/features/wizarr/domain/models/wizarr_library.dart`
- Modify: `lib/features/wizarr/data/wizarr_providers.dart`
- Test: `test/features/wizarr/data/wizarr_client_test.dart`, `test/features/wizarr/data/wizarr_service_test.dart`, `test/features/wizarr/domain/models/wizarr_models_test.dart`

**Interfaces:**
- Consumes: live-verified map (base `{url}/api`, `X-API-Key`, `GET /api/invitations|users`, `POST /api/invitations` with `InvitationCreateRequest` shape)
- Produces: `WizarrClient.post(service, method, [body])`, `WizarrService.createInvitation({...})`, `WizarrServer`, `WizarrLibrary`, `wizarrServersProvider`, `wizarrLibrariesProvider`

- [ ] **Step 1: Write the failing tests**

```dart
// client: exactly one mutating key allowed, everything else blocked
test('Invitation.create posts, Invitation.delete still throws', () async {
  final service = _service({'message': 'ok', 'invitation': {'code': 'n'}});
  final created = await service.createInvitation(serverIds: [1]);
  expect(created.code, 'n');
  expect(
    () => service.client.post('Invitation', 'delete'),
    throwsA(isA<StateError>()),
  );
});
test('400 envelope message surfaces', () async {
  // mock adapter returns 400 {"error": {"message": "pick a server"}}
  // expect createInvitation throws WizarrException with that message
});
test('HTML 200 body throws WizarrException', () async {
  // mock adapter returns 200 text/html "<html>login</html>"
  // expect createInvitation throws isA<WizarrException>()
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/wizarr/data/ 2>&1 | tail -2`
Expected: FAIL (undefined `post`/`createInvitation`/models)

- [ ] **Step 3: Implement in `wizarr_client.dart`: `static const _createOnly = {'Invitation.create'}` with a comment naming it the sole v1 exception; `Future<dynamic> post(String service, String method, [Map<String, dynamic>? body])` that throws `StateError` unless the key is in `_createOnly`, then `_dio.post` to the EXACT path `'/api/invitations'` (a literal constant — never via the fuzzy `_pathForKey`, which is GET-only) with the `X-API-Key` header and the same 10/10/15 s timeouts; extend `_readOnly` with `'Server.getAll'`/`'Library.getAll'` (+ the same alias style as existing entries) and `_pathForKey` with exact `'server' → '/api/servers'`, `'library' → '/api/libraries'`**

- [ ] **Step 4: Implement in `wizarr_service.dart`: `Future<WizarrInvitation> createInvitation({required List<int> serverIds, List<int> libraryIds = const [], int? expiresInDays, required String duration, required bool unlimited, bool allowDownloads = true, bool allowLiveTv = true, bool allowMobileUploads = true})` that throws `ArgumentError` on empty `serverIds` before any network I/O, posting body `{server_ids, expires_in_days, duration, unlimited, library_ids, allow_downloads, allow_live_tv, allow_mobile_uploads}` (never `wizard_bundle_id` — assert its absence in the payload-capture test) and mapping the `201` `invitation` map via `WizarrInvitation.fromJson`; plus `getServers()` (`client.rpc('Server', 'getAll')` → envelope `servers`) and `getLibraries()` (`client.rpc('Library', 'getAll')` → `libraries`)**

- [ ] **Step 5: Implement `WizarrServer` (`id`, `name`, `serverType`, all nullable, tolerant `fromJson`) and `WizarrLibrary` (`id`, `name`, `serverId`, `serverName`, `enabled`) in `domain/models/`**

- [ ] **Step 6: Implement in `wizarr_providers.dart`: `wizarrServersProvider` and `wizarrLibrariesProvider` as `FutureProvider.autoDispose` lists via the service (same shape as the existing two providers)**

- [ ] **Step 7: Run `flutter test test/features/wizarr/`, `flutter analyze` on touched files** → green/clean

- [ ] **Step 8: Commit**

```bash
git add lib/features/wizarr test/features/wizarr
git commit -m "feat(wizarr): gated create endpoint, servers/libraries"
```

### Task 2: Last-used defaults persistence

**Files:**
- Create: `lib/features/wizarr/data/wizarr_create_defaults.dart`
- Test: `test/features/wizarr/data/wizarr_create_defaults_test.dart`

**Interfaces:**
- Consumes: nothing new
- Produces: `encodeCreateDefaults({...}) → String`, `decodeCreateDefaults(String?) → ({List<int> serverIds, List<int> libraryIds, int? expiresInDays, bool unlimited, int durationDays, bool allowDownloads, bool allowLiveTv, bool allowMobileUploads})`, `loadCreateDefaults(SharedPreferences)`, `saveCreateDefaults(SharedPreferences, {...})` under key `wiz_last_invite`

- [ ] **Step 1: Write the failing tests**

```dart
test('round-trip preserves snapshot', () {
  // save a snapshot with SharedPreferences.setMockInitialValues({}), load it back, expect equality
});
test('missing snapshot decodes to documented defaults', () {
  // decodeCreateDefaults(null) == (all servers implied by empty selection? no:
  // serverIds: [], libraryIds: [], expiresInDays: 7, unlimited: false,
  // durationDays: 30, all permissions true)
});
```

- [ ] **Step 2: Run to verify they fail**
- [ ] **Step 3: Implement pure encode/decode + prefs load/save (JSON object, tolerant decode: wrong types fall back per-field to defaults)**
- [ ] **Step 4: Run tests + analyze** → green/clean
- [ ] **Step 5: Commit** (`feat(wizarr): last-used create defaults`)

### Task 3: Create form sheet + wiring

**Files:**
- Create: `lib/features/wizarr/presentation/wizarr_create_sheet.dart`
- Modify: `lib/features/wizarr/presentation/wizarr_screen.dart` (header row with "New invite" action atop the Invitations tab; invalidate `wizarrInvitationsProvider` on success)
- Test: `test/features/wizarr/presentation/wizarr_create_sheet_test.dart`

**Interfaces:**
- Consumes: Task 1 providers/service, Task 2 defaults
- Produces: pushed fullscreen route showing the share link on success

- [ ] **Step 1: Write the failing widget tests**

```dart
// empty servers state: providers return [], expect "no servers" text and disabled create
// validation: tap Create with no server selected, expect error text + mock adapter call count 0
// unlimited on: duration field disabled, captured POST body has duration "unlimited"
// expiry Never: captured POST body has expires_in_days null (not 0)
// success: mock 201 with relative url "/j/abc", expect full "https://<host>/j/abc" text + copy affordance
```

- [ ] **Step 2: Run to verify they fail**
- [ ] **Step 3: Implement the sheet** — `MaterialPageRoute(fullscreenDialog: true)` pushed from the Invitations tab header action; server `FilterChip`s (multi), library chips filtered by selected `serverId`s (empty selection = all libraries), expiry `SegmentedButton<int?>` (Never=null, 1, 7, 30), unlimited `Switch` disabling the duration days field, three permission switches, defaults from Task 2 snapshot (fallback: all servers, no library restriction, 7-day expiry, unlimited off, 30 days, all on); at submit an empty server selection expands to all loaded server IDs (the service `ArgumentError` is the backstop, never the path); confirm block ("Create invite for N servers, expires in X?") + Create button; on success persist the snapshot, show the absolute link (via `absoluteInviteUrl`) with copy, then close and invalidate the invitations provider; server errors surface verbatim (scrubbed)
- [ ] **Step 4: Run `flutter test test/features/wizarr/`, full `flutter test`, `flutter analyze`** → green/clean
- [ ] **Step 5: Commit** (`feat(wizarr): invite creation sheet`)

### Task 4: Proof, gates, release

- [ ] **Step 1: Device proof (Pixel 6, live bertha)** — create a real invite with 1-day expiry (self-cleaning; no revoke endpoint in v1), verify the row appears with a working absolute link, tap-to-copy works
- [ ] **Step 2: OCR local pre-pass** (`ocr review --commit <hash> --concurrency 1 --max-git-procs 1` per commit, sequential); disposition every finding with verified reasons
- [ ] **Step 3: Exactly one CodeRabbit gate**; apply or decline-with-reason
- [ ] **Step 4: Write the release project-log entry** and commit
- [ ] **Step 5: Release** — version bump, tag, APK + xcross IPA, GitHub release (established loop)
