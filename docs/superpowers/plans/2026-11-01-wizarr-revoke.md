# Wizarr Invite Revocation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Revoke a live Wizarr invitation from its tile, behind a confirm dialog.

**Architecture:** Single-purpose `deleteInvitation(id)` on the existing Dio client (no generic DELETE passthrough, so no new allowlist-bypass class), thin service wrapper, trailing tile button + confirm dialog, list invalidation on success.

**Tech Stack:** Flutter, flutter_riverpod, Dio; no new dependencies.

**Spec:** `docs/superpowers/specs/2026-11-01-wizarr-revoke-design.md` — the plan
argues from the spec, so the spec travels with it; executors read both

## Global Constraints

- Read-only v1 invariant holds except the two named mutating keys (`Invitation.create`, `Invitation.delete`); every other non-list call still throws `StateError` before any network I/O.
- API key in secure storage, never in logs; no request-body logger on any Wizarr path.
- Every shell screen keeps the floating-nav-bar bottom inset; `nav_clearance_test` must keep passing.
- TDD: failing test first; `flutter test`, `flutter analyze` clean before each commit.
- No invite creation changes, no user add/remove, no server management in this task.
- Endpoint shapes verified against live swagger: `DELETE /api/invitations/{id}` (id interpolated into the literal path) → `200` `{message}` object or empty body; `401`/`404`/`500` error envelope.

## Review Focus

- A `204`/empty-`200` body parses as success without crash — pin with an empty-body test in the owning task, most likely first.
- A 404 surfaces "Invitation not found" (or the server message), never a generic crash — pin with a 404-envelope test.
- Cancel performs zero DELETEs — pin with a mock-adapter call-count test.
- Revoking an invitation already consumed/expired behaves like any other 200 (row disappears) — no special-casing; pin with a used-invite fixture test.
- The revoke action is hidden when `id` is null — pin with a null-id tile test.

---

### Task 1: Revoke endpoint, service, tile action

**Files:**
- Modify: `lib/features/wizarr/data/wizarr_client.dart`
- Modify: `lib/features/wizarr/data/wizarr_service.dart`
- Modify: `lib/features/wizarr/presentation/widgets/wizarr_invite_tile.dart`
- Modify: `lib/features/wizarr/presentation/wizarr_screen.dart` (pass revoke callback + invalidate)
- Test: `test/features/wizarr/data/wizarr_client_test.dart`, `test/features/wizarr/data/wizarr_service_test.dart`, `test/features/wizarr/presentation/wizarr_screen_test.dart` (or a new `wizarr_revoke_test.dart` if cleaner)

**Interfaces:**
- Consumes: existing `WizarrException`, `_extractError`, `wizarrInvitationsProvider`, `absoluteInviteUrl` (untouched)
- Produces: `WizarrClient.deleteInvitation({required int id}) → Future<void>` (2xx = success, else throws `WizarrException`); `WizarrService.revokeInvitation({required int id}) → Future<bool>` (true on success)

- [ ] **Step 1: Write the failing tests**

```dart
test('deleteInvitation hits literal path with id', () async {
  // mock adapter returns 200 {"message": "deleted"}; call
  // client.deleteInvitation(id: 7); expect captured request method DELETE
  // and path '/api/invitations/7'
});
test('empty 200 body succeeds without parse crash', () async {
  // mock adapter returns 200 with empty body; expect service
  // revokeInvitation(id: 7) completes true
});
test('404 surfaces not-found message', () async {
  // mock adapter returns 404 {"error": {"message": "Invitation not found"}}
  // expect throws WizarrException with that message
});
test('second mutating shape still blocked', () async {
  // expect(() => client.post('Invitation', 'delete'), throwsStateError)
  // expect(adapter.callCount, 0)
});
testWidgets('revoke hidden when id is null', (tester) async {
  // pump tile/screen with invitation lacking id; expect no delete affordance
});
testWidgets('Cancel performs zero DELETEs', (tester) async {
  // open confirm, tap Cancel; expect mock adapter call count 0
});
testWidgets('confirm revokes and row disappears', (tester) async {
  // mock 200; tap revoke, tap confirm; expect row gone
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/wizarr/ 2>&1 | tail -2`
Expected: FAIL (undefined `deleteInvitation`/`revokeInvitation`, no revoke UI)

- [ ] **Step 3: Implement `deleteInvitation` in `wizarr_client.dart`**

Single-purpose method with a checked sibling set (same pattern as
`post()` + `_createOnly`, per-verb sets rather than one renamed bag):
`static const _deleteOnly = {'Invitation.delete'}`; `Future<void>
deleteInvitation({required int id})` verifies membership first (so a
second mutating shape such as `client.delete('Invitation', 'update')`
throws `StateError` before any I/O) and `_dio.delete`s the EXACT
literal path `'/api/invitations/$id'` (never via the fuzzy
`_pathForKey`, which is GET-only) with the `X-API-Key` header and the
same 10/10/15 s timeouts; 2xx (object or empty body) completes
normally, anything else (including any present-or-future 409) throws
`WizarrException` via the existing `_extractError` path — no
per-state special-casing.

- [ ] **Step 4: Implement `revokeInvitation` in `wizarr_service.dart`**

`Future<bool> revokeInvitation({required int id})` → `await client.deleteInvitation(id: id)` then `return true`; exceptions propagate untouched (the screen maps them to UI).

- [ ] **Step 5: Implement the tile action + dialog + wiring**

`WizarrInviteTile` gains an optional `onRevoke` (`VoidCallback?`, hidden when null — existing screen tests construct tiles without it and are unaffected); the screen passes a callback that shows a confirm `AlertDialog` ("Revoke invite CODE? …") implemented as a small local `StatefulWidget` holding the `_submitting` flag (both buttons disabled + spinner while the DELETE is in flight, guarding double-submit), and on confirm calls `revokeInvitation`, invalidates `wizarrInvitationsProvider`, and shows a snackbar; errors surface verbatim (scrubbed) in the dialog with no state change. The screen passes `onRevoke: null` when `invitation.id == null`.

- [ ] **Step 6: Run `flutter test test/features/wizarr/`, full `flutter test`, `flutter analyze`** → green/clean

- [ ] **Step 7: Commit**

```bash
git add lib/features/wizarr test/features/wizarr
git commit -m "feat(wizarr): revoke invitations"
```

### Task 2: Proof, gates, release

- [ ] **Step 1: Device proof (Pixel 6, live bertha)** — revoke the 1-day device-proof invite, verify the row disappears and the tile count drops; Cancel path verified (zero requests)
- [ ] **Step 2: OCR local pre-pass** (`ocr review --commit <hash> --concurrency 1 --max-git-procs 1`); disposition every finding with verified reasons
- [ ] **Step 3: Exactly one CodeRabbit gate**; apply or decline-with-reason
- [ ] **Step 4: Write the release project-log entry** and commit
- [ ] **Step 5: Release** — version bump, tag, APK + xcross IPA, GitHub release (established loop)
