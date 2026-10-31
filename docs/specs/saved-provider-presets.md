# Spec: User-saved OIDC provider presets

Status: DRAFT — for homelab-agent review. No implementation until
review sign-off.

## Problem
The Auth screen hardcodes one preset (ArrStack: issuer
`https://auth.piracyhub.win/application/o/arrstack/`, client
`arrstack`). Anyone running Beakarr against their own Authentik cannot
use presets at all — the feature is hardlocked to our setup.

## Goal
Let the user point the app at THEIR Authentik server, validate a
provider there, and save it as a named, reusable preset.

## Non-goals
- No server-side provider enumeration. `GET /core/applications/`
  needs a privileged API token a normal PKCE login will not have, so
  the app does NOT list providers from the API. Discovery is by slug.
- The `Use ArrStack preset` button stays as-is (one-tap built-in).
- No changes to per-service derivation (`perServiceIssuer` /
  `perServiceClientId`), the OIDC interceptor, or the login flows.
  Presets only write the same two fields the ArrStack button writes.

## User flow (Auth screen, new "Saved presets" section below ArrStack)
1. Two fields: server origin (e.g. `https://auth.example.com`) +
   provider slug (e.g. `arrstack`), plus Validate button.
2. App GETs `{origin}/application/o/{slug}/.well-known/openid-configuration`.
   - Must be HTTP 200 + JSON containing a string `issuer`, else a
     per-field inline error: bad origin URL / unreachable /
     slug 404 / not-OIDC metadata.
   - The document's `issuer` value is canonical (used verbatim, even
     if it differs textually from the constructed URL). Both sides are
     normalized (trim, strip trailing `/`) before display.
3. On success the UI shows the validated issuer host (read-only) and an
   editable client_id prefilled with the slug (convention:
   client_id == slug; user overrides when their setup differs), plus a
   name field and Save.
4. List rows: name + issuer host, active-dot on the row matching the
   current settings, tap = activate, trash = delete. Empty state text
   when none. Cap: 10 presets. Duplicate names denied with a snackbar.
5. Activate: confirm dialog first ("Switching providers wipes login
   sessions — continue?"), then apply via the existing settings update
   path AND explicitly clear the service-token cache (same as the
   ArrStack button). Reselecting the identical active preset is a no-op.
   Deleting the active preset never alters current settings (presets
   are shortcuts, not profiles).

## Storage
- New `SettingsModel.oidcPresets`: `List<OidcPreset>` (`{name, issuer,
  clientId}`), default empty. First list-storage in the app.
- New prefs key `oidc_presets`: JSON array of the above. Load
  (`'[]'` default), save, and `clearAll()` removal in
  `SettingsService`. Included in encrypted backup like other prefs.
- Malformed JSON on load → empty list (fail closed, never crash).

## Activation semantics (binding)
- Activation writes `oidcIssuer`/`oidcClientId` only. All downstream
  behavior (per-service derivation, ArrStack-mode detection,
  lazy exchange, logout) follows unchanged from those two fields.
- Service-token cache is cleared on EVERY activate (even same issuer,
  because a different `clientId` mints different tokens and the
  existing issuer-change wipe would miss it).
- OIDC token pairs are cleared exactly when the existing
  issuer-or-client comparison says the identity changed.

## For homelab reviewers
1. Issuer derivation on your side: our per-service issuer convention is
   `{origin}/application/o/<service>/` with `client_id == <service>`
   (or the shared `arrstack` pair). Does any current or planned
   provider break if a client assumes this shape?
2. The discovery doc's `issuer` is trusted verbatim. Any setup where
   the doc issuer legitimately differs from the request URL in a way
   we should reject rather than accept?
