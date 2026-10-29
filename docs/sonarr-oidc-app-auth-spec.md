# Sonarr Fork — OIDC App-Auth Endpoints (spec for the server-side agent)

## Goal

Add two endpoints to the Sonarr fork so Seekarr (the mobile client) can
authenticate users through Authentik and authorize per-tier without the
app ever resolving groups into tiers.

The app-side pilot (Branch 8 of the Seekarr spec) will not start until
these endpoints exist and return the documented shapes. Everything below
is the contract the app will consume; deviations break the pilot.

## Context (what already exists — reuse, do not rebuild)

- Authentik provider `sonarr` (client_id `sonarr`, aud `sonarr`) — the
  app logs in against Authentik, not against Sonarr.
- `OidcGroupMapping.Resolve(groups)` already maps the Authentik groups
  (`pirates`, `homies`, `family`, `maintenance`, `authentik Admins`)
  to T1..T5 roles (`Admin`, `Manage`, `AddSearch`, `ReadOnly`, null).
- `UpsertOidcUser` already writes the `Role` used by `GET /api/auth/me`.
- `PermissionRequirement` / `[RequiresPermission]` handlers already gate
  on role >= minimum.
- Backchannel logout + `OnTokenValidated` callback auth already wired.
- `IX_Users_OidcSubject` unique index exists (filtered on non-null).

Reuse all of it. Do not re-implement group→role mapping in the new
endpoints.

## Endpoints to add

### `POST /api/auth/oidc/exchange`

Exchange an Authentik access token for a Sonarr-scoped service token.

Request (JSON body):

```json
{ "subject_token": "<authentik access_token>" }
```

Also accept the same token via `Authorization: Bearer <token>` header
(the app sends both — body wins if both present).

Response 200 (JSON):

```json
{
  "token": "<sonarr service jwt>",
  "token_type": "Bearer",
  "expires_in": 300,
  "role": "AddSearch",
  "permissions": ["UI.Read", "UI.Add"]
}
```

- `token`: a JWT Sonarr mints itself, `aud=sonarr`, `iss` = Sonarr's own
  issuer (or the same Authentik issuer if you prefer — but aud must be
  `sonarr`), short TTL (5 minutes recommended, must be ≤ 10).
- `role`: result of `OidcGroupMapping.Resolve(groups)` from the
  Authentik token's `groups` claim. `null`/rejected when no tier maps.
- `permissions`: derived from `role` via the existing permission table
  (what `[RequiresPermission]` already enforces). At minimum
  `UI.Read`, plus `UI.Add`/`UI.Manage`/`UI.Admin` as the role rises.
- `expires_in`: seconds.

Error responses (JSON `{ "message": "..." }` or Sonarr's normal error
shape, app only reads status code + message):

- `400` — missing/empty `subject_token`.
- `401 invalid_token` — Authentik JWT failed validation (bad signature,
  expired, wrong issuer, wrong audience, unknown `kid`, clock skew).
- `403 insufficient_group` — JWT valid but `OidcGroupMapping.Resolve`
  returned null (e.g. no recognized group, or pirates-only).
- `500` only for genuine server errors.

### `GET /api/auth/me`

Return the authenticated user's context. Requires the Sonarr service
token from `/exchange` in `Authorization: Bearer <token>`.

Response 200 (JSON):

```json
{
  "username": "sheila",
  "role": "AddSearch",
  "groups": ["family"],
  "permissions": ["UI.Read", "UI.Add"]
}
```

- `username`: from the Authentik `sub` / `preferred_username` claim,
  persisted via `UpsertOidcUser`.
- `role`: the persisted `User.Role` (same as exchange's role).
- `groups`: the Authentik groups claim (raw, for display only — the app
  never resolves tiers from it).
- `permissions`: derived from `role`.

Error responses:

- `401` — no/invalid/expired service token.
- `404` — token valid but user row missing (shouldn't happen after
  exchange; treat as re-login required).

## Validation rules (must match exactly)

1. **Authentik JWT validation** (on `subject_token`):
   - Issuer == `https://auth.piracyhub.win/application/o/sonarr/`
     (trailing slash matters, per-provider issuer).
   - Audience contains `sonarr` (the Authentik client_id the app logs
     in with for this pilot). Reject if aud does not contain `sonarr`.
   - Signature verified against Authentik's JWKS.
   - JWKS refresh: cache with `RefreshInterval = 24h`, plus refresh on
     unknown `kid` (key rotation).
   - `exp` and `nbf` with ±2 min clock skew tolerance.
   - `sub` is required and non-empty; it becomes the `OidcSubject` for
     `UpsertOidcUser` (your filtered unique index).
2. **Group mapping**: reuse `OidcGroupMapping.Resolve(groups)`. Do not
   parse/normalize groups in the endpoint; the mapping already handles
   casing and list-vs-string normalization.
3. **Upsert**: call `UpsertOidcUser` with the `sub` and resolved `Role`
   so `GET /api/auth/me` reflects it. Reuse the existing DB row if
   present.
4. **Service token minting**: standard JWT, `aud=sonarr`, TTL 5 minutes
   (300s). Include `sub` (the OidcSubject) and `role` claims. Sign with
   Sonarr's own signing key (not Authentik's). Signing key must be at
   least 256 bits (32 bytes, HS256 minimum) — fail closed (500) if shorter.
5. **No secrets in logs**: redact tokens in any diagnostic output, same
   as the app's redacted HTTP logging.

## App-side contract (what the app will do — do not change these shapes)

- App logs in to Authentik once per service pilot (PKCE, `aud=sonarr`,
  `issuer https://auth.piracyhub.win/application/o/sonarr/`,
  `client_id sonarr`), stores the Authentik access + refresh tokens
  in secure storage. `seekarr` app (`aud=seekarr`) stays for Seekarr's
  own desktop PKCE, not for `*arr` exchange.
- On first call to a Sonarr endpoint, app gets `401` (no service token),
  then `POST /api/auth/oidc/exchange { subject_token }` with
  `Authorization: Bearer <authentik_token>`.
- App caches `{ sonarr_token, permissions, role, expires_at }` keyed by
  host. Reuses until expiry - 5 min.
- On any 401 from Sonarr, app refreshes the Authentik token (central
  refresh, Branch 7), then re-exchanges for Sonarr, then retries the
  original request.
- App calls `GET /api/auth/me` immediately after every successful
  exchange and caches the result atomically with the token (Branch 6).
- App never resolves groups → tiers. It reads `permissions` from `/me`
  for UI gating (`usePermissions()` hook) and relies on
  `[RequiresPermission]` as the real gate.
- On `403 insufficient_group`, app shows a friendly message
  ("Your tier can't do this — contact maintenance/owner"), never raw
  groups in prod.
- Fallback: if exchange fails or Authentik is unreachable, app falls
  back to the stored API key (`X-Api-Key`) so nothing breaks. Log the
  fallback for telemetry.

## Non-goals (explicitly out of scope)

- Do not change existing API-key auth. Keys still work exactly as today.
- Do not add per-service login screens or browser flows in Sonarr.
- Do not issue refresh tokens from Sonarr. The Authentik refresh token
  is the only refresh token.
- Do not implement OIDC for other services in this pass — Sonarr is the
  pilot. Prowlarr, then Sonarr's siblings, reuse this exact contract.
- Do not touch the backchannel logout or `OnTokenValidated` flow.
- Rate limit `POST /exchange` (e.g. 10/min per IP) — it's unauthed until validated.

## Acceptance criteria

1. `POST /api/auth/oidc/exchange` with a valid Authentik token returns
   200 with `token`/`token_type`/`expires_in`/`role`/`permissions`.
2. Same endpoint with an expired/wrong-audience/wrong-issuer token
   returns 401 `invalid_token`.
3. Same endpoint with a valid token but no recognized group returns
   403 `insufficient_group`.
4. `GET /api/auth/me` with the issued service token returns the documented
   shape; with a bogus token returns 401.
5. Service token rejected by a sibling service (aud mismatch) — i.e.
   Sonarr's token fails at Radarr once Radarr implements the same
   contract. (Verify structurally: aud=sonarr in the minted JWT.)
6. JWKS cache refreshes on unknown `kid` (test with a rotated key).
7. Existing API-key auth unchanged: `X-Api-Key` requests still work.

## Notes for the implementer

- Prefer reusing the existing `OidcGroupMapping` and `UpsertOidcUser`
  rather than new code paths.
- The service token is a JWT Sonarr signs itself; do not reuse
  Authentik's signing key.
- Keep TTL at 5 min; the app's central refresh + re-exchange handles
  renewal, so longer TTLs buy nothing and widen exposure.
- Log redaction: any diagnostic that prints a token must show `***`.
