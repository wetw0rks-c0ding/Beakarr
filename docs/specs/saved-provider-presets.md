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
   Origin is normalized first (trim, strip trailing `/` — a pasted
   trailing slash otherwise 404s and misdiagnoses as a bad slug; same
   norm convention the app already uses). Slug is trimmed + lowercased
   (Authentik slugs are lowercase; uppercase 404s).
   - Must be HTTP 200 + JSON containing a string `issuer` AND present
     `authorization_endpoint` + `token_endpoint` — checking issuer
     alone lets broken docs through to fail late and cryptically.
     Per-field inline errors: bad origin URL / unreachable /
     slug 404 / not-OIDC metadata / missing endpoints.
   - The document's `issuer` value is canonical (used verbatim, even
     if it differs textually from the constructed URL). Both sides are
     normalized (trim, strip trailing `/`) before display. Live
     verification (Authentik 2026.8.5): issuer is always
     `{origin}/application/o/{slug}/` with trailing slash, and
     endpoints are shared (`.../o/authorize/`, `.../o/token/`) — read
     them from the doc, never constructed.
3. On success the UI shows the validated issuer host (read-only) and an
   editable client_id prefilled with the slug. The prefill is a
   DEFAULT GUESS, not a convention: verified counterexamples on our
   own setup (`pirate-jellyseerr` → `8jzO…`, `pirate-audiobookshelf` →
   `kBBK…`). There is no public endpoint that pre-validates a
   client_id — only a login proves it — so the override field is
   load-bearing, not a corner case. Name field and Save.
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
- No-op reselect needs an equality check on BOTH fields (normalized
  issuer AND clientId) before the update path: `updateSettings` only
  compares issuer, so a same-issuer/different-client reselect would
  otherwise wipe + rewrite unnecessarily. Skip the whole apply when
  both match.
- OIDC token pairs are cleared exactly when the existing
  issuer-or-client comparison says the identity changed.
