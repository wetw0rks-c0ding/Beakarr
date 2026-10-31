# Spec: NZBGet + Nginx Proxy Manager + OpenMediaVault 7

Status: APPROVED for implementation. No code written yet.

Order (per-service closed loop): **NZBGet → NPM → OMV**.

## Decisions (all approved)

| Service | Scope | Auth design | Detail spec |
|---|---|---|---|
| NZBGet | Monitor + control (qBittorrent parity) | **A1:** stateless `BasicAuth implements ServiceAuth` + `ApiClient` on `POST /jsonrpc` | `docs/specs/nzbget-npm-proxy-manager-blueprint.md` (Service A) |
| Nginx Proxy Manager | Read-only v1 (hosts + cert expiry; enable/disable + renew deferred) | **B1:** standalone `NpmClient`, in-memory token, 401 re-login; email+password login | same file (Service B) |
| OpenMediaVault 7 | Read-only (system, filesystems, disks/SMART, services; no control) | **A:** session client (`X-OPENMEDIAVAULT-SESSIONID`) with in-code read-only RPC allowlist | `docs/specs/openmediavault-readonly.md` |

No OIDC/SPOT for any of the three — credential auth only, no SSO dots.

## Sequencing

1. **PR 1 — plumbing only:** `ServiceKey.credentialKind` (`apiKey`/`usernamePassword`/`emailPassword`), storage keys (`nzbget_*`, `npm_*`, `openmediavault_*`), all exhaustive switch arms, routes, settings/onboarding/delete paths, `SettingsModel.clearedService`. No new screens; suite stays green. Includes the Navidrome username-on-delete fix (approved).
2. **PR 2 — NZBGet.** 3. **PR 3 — NPM.** 4. **PR 4 — OMV.**

## Hard stops / must-verify-live

- NPM 2FA accounts: clear error in v1, `POST /api/tokens/2fa` deferred.
- OMV RPC names verified against OMV 7 source, never against a live box — every method/field in the OMV doc carries a must-verify checkbox for device testing.
- NZBGet `editqueue`/`append` param-arity differs pre-v18/v17/v16 — handled as friendly-error retry, not version branches.

## Test bar (per service)

Unit (models/auth/client) + widget (screens) + regression (settings round-trip, connection provider, dashboard summary) + `flutter analyze` for the exhaustive switches. Full suite green before each PR merges. Device proof on Pixel 6 against the homelab before release, same as every service before it.
