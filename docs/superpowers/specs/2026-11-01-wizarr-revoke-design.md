# Wizarr Invite Revocation — Design Spec (2026-11-01)

## Intent

Close the guest lifecycle loop opened in phase 2: revoke a live
invitation from the app. Small, bounded addition to existing Wizarr
code — no new screens, no new dependencies.

Non-goals: user delete/disable/enable (separate decision + spec),
server management (no API exists), undo (no un-revoke endpoint).

## Endpoints (verified against live swagger 2026-11-01)

- `DELETE /api/invitations/{invitation_id}` → `200` on success;
  `401` unauthenticated, `404` unknown id, `500` server error.
  The `200` body is `{message: string}` per swagger, but the client
  must also tolerate an empty body (no parse crash either way).
- Path param is the integer `id` (the model already carries it;
  tiles keyed by `code` must resolve the id first — every live
  invitation has one).

## Architecture

- Client: allowlist gains exactly one mutating key
  (`Invitation.delete` → `DELETE /api/invitations/{id}`, id
  interpolated into the literal path, never a query param). Same
  `StateError`-before-I/O enforcement; same `X-API-Key` header and
  10/10/15 s timeouts; `_extractError` reuse for message/code.
- Service: `WizarrService.revokeInvitation({required int id})`
  → true on 200; throws `WizarrException` otherwise (404 surfaces
  as "Invitation not found", not a crash). Invitations without an
  id cannot be revoked — the UI hides the action for them.
- UI: trailing revoke icon-button on `WizarrInviteTile` opening a
  confirm dialog ("Revoke invite CODE? Guests with the link will no
  longer be able to join.") with Cancel/Revoke. On success:
  invalidate `wizarrInvitationsProvider` (row disappears),
  snackbar confirmation. Errors surface verbatim (scrubbed) in the
  dialog; no state change on failure.

## Data flow

Tile (id) → confirm dialog → service → client DELETE → 200 →
invalidate list provider → snackbar. No snapshot, prefs, or
dashboard changes (tile count derives from the refreshed list).

## Error handling

- 401 → existing "Unauthorized" path; 404 → "Invitation not
  found"; HTML/non-JSON → existing `WizarrException` conversion;
  transport failure → clean message (never raw `e.toString()`).
- Double-tap / double-submit guarded by a submitting flag (the
  created invite can't be un-created; a retry after success would
  404 — acceptable, surfaced).

## Testing

- Client: delete key allowed; a second mutating shape still throws
  `StateError`; 404 maps to message + status; empty-`200` and
  `{message}`-`200` bodies both succeed without parse errors.
- Service: 200 → true; 404 → throws with "not found".
- Widget: revoke button hidden when id is null; confirm dialog
  Cancel performs zero DELETEs (mock adapter call count);
  confirm Revoke → row disappears (provider invalidated).
- `flutter analyze` clean; full suite green.

## Device proof + gates

- Pixel 6 vs live bertha: revoke the device-proof 1-day invite
  (self-cleaning anyway), verify the row disappears and the tile
  count drops; Cancel path verified (zero requests).
- OCR pre-pass + exactly one CodeRabbit gate, project log entry,
  next alpha (tag + APK + xcross IPA).
