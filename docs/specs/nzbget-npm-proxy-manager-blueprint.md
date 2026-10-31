# Blueprint — NZBGet (MONITOR + CONTROL) and Nginx Proxy Manager (READ-ONLY v1)

Status: design only. No code changed by this document.
Repo: `seekarr` (Beakarr), Flutter + Riverpod, go_router.

## 0. Decisions up front

| | decision |
|---|---|
| **NZBGet transport** | **Stateless per-request HTTP Basic.** New `BasicAuth implements ServiceAuth` + existing `ApiClient`. A thin `NzbgetClient` owns the JSON-RPC envelope; `NzbgetService` owns endpoints/models. **No** session client, **no** cookie jar. |
| **NZBGet settings** | Username + password (both required). Same form variant as Navidrome. |
| **NZBGet health** | `POST /jsonrpc` → `version` (reachability + auth), then `status` (proves queue-control scope). |
| **NZBGet dashboard** | version = `version()` → "v24.3"; count = `listgroups(0).length` → `downloads`. |
| **NPM transport** | **Standalone `NpmClient` with in-memory token cache + 401 re-login**, QbittorrentClient-shaped (`Dio? dio` injection). **Not** `ApiClient` + `ServiceAuth`. |
| **NPM settings** | Reuse the credential form's username slot for the **email identity**, rename field to `npmIdentity`, label it "Email". No new form variant type — a third `credentialKind` value instead. |
| **NPM health** | `POST /api/tokens` then `GET /api/nginx/proxy-hosts` (auth + reachability in one). |
| **NPM dashboard** | version = none (`REST` label); count = proxy hosts. |
| **Cert "expiring soon"** | **30 days = warning, 7 days = critical**, `expired` when negative. Matches the certbot/NPM renewal window (NPM renews inside 30 days, so "inside 30 days" means renewal is failing). |
| **NPM token expiry** | Trust `expires` from the token response; verify with a 60 s safety margin; if absent, decode the JWT `exp` claim; else 30 min. On 401, re-login **once** (guard flag), and de-dupe concurrent logins. |
| **Search** | Both `isSearchable == false` (not media sources — Prowlarr owns indexer search). |
| **Onboarding** | Both appear (list is `ServiceKey.values`), so they must be handled or they crash / post qBittorrent login to them. Solved by `credentialKind` + explicit `_verifyService` branches. |

---

## 1. Why those transports (the code reasons)

### NZBGet: Basic, not a session

`lib/core/api/api_client.dart` merges `auth.headers()` into `BaseOptions.headers`
**once, in the constructor**, and merges only `auth.queryParams()` per request.
That is ideal for a credential that never rotates — and NZBGet's Basic header
never rotates (it comes straight from `ControlUsername`/`ControlPassword`).
NZBGet has *no* login call, no cookie, no token: the docs state "The RPC server
uses HTTP basic authentication" on `POST /jsonrpc`. There is nothing to cache, so
a `QbittorrentClient`-style session machine would be pure dead state plus a
cookie jar dependency.

Reusing `ApiClient` also gives, for free:
* `FakeApiClient` tests (`test/test_helpers/fake_api_client.dart`) — the whole
  test suite pattern;
* the existing `LogInterceptor` **header** redaction, so `Authorization` never
  hits logs while the JSON-RPC body (method + params, no secrets) stays visible.

### NPM: standalone client, not `ApiClient` + `ServiceAuth`

Three concrete blockers, in order of severity:

1. **`ApiClient` would log the admin password.** `requestBody: true` and the
   redactor (`lib/core/api/api_client.dart:40-60`) masks only
   `x-api-key|authorization|cookie` **headers**, not bodies. The token exchange
   body is `{"identity": "<email>", "secret": "<password>"}`. Shipping that
   through `ApiClient` prints the NPM admin credential to the console.
2. **`ServiceAuth` cannot express a rotating token.** Headers are baked at
   construction, so every refreshed JWT would force a new `ApiClient` per call —
   i.e. re-implementing the client anyway, with worse lifecycle control.
3. **401 retry is a client concern here.** `ApiClient` has no retry hook for
   non-OIDC services; `QbittorrentClient` already demonstrates the clean shape
   (`onError` interceptor + `skipAuthRetry` extra + `_authInFlight` de-dupe,
   `lib/features/qbittorrent/data/qbittorrent_client.dart:34-110`). Copy that
   shape rather than invent a second one.

Cost of the choice: NPM service tests use `Dio` + a fake `HttpClientAdapter`
(the pattern already proven in `test/features/qbittorrent/data/qbittorrent_client_test.dart`),
not `FakeApiClient`. Acceptable — the token machine *is* the thing under test.

---

## 2. Shared plumbing (do this first, in its own PR)

Adding two `ServiceKey` values is not additive in this codebase: several
`switch` statements are exhaustive and several lookups are `map[key]!`. This is
the exact break list found by inspection.

### 2.1 `lib/features/settings/domain/service_key.dart`

```dart
enum ServiceKey { seerr, radarr, sonarr, lidarr, qbittorrent, prowlarr,
                  bazarr, navidrome, soulsync, nzbget, npm }
```

New enum + getter, so the four credential services stop being if-chains:

```dart
enum ServiceCredentialKind { apiKey, usernamePassword, emailPassword }

ServiceCredentialKind get credentialKind => switch (this) {
  ServiceKey.qbittorrent ||
  ServiceKey.navidrome ||
  ServiceKey.nzbget => ServiceCredentialKind.usernamePassword,
  ServiceKey.npm => ServiceCredentialKind.emailPassword,
  _ => ServiceCredentialKind.apiKey,
};

bool get usesApiKey => credentialKind == ServiceCredentialKind.apiKey; // keep name
bool get isSearchable => this != ServiceKey.qbittorrent &&
                         this != ServiceKey.navidrome &&
                         this != ServiceKey.nzbget &&
                         this != ServiceKey.npm;
String get usernameLabel => switch (credentialKind) {
  ServiceCredentialKind.emailPassword => 'Email',
  _ => 'Username',
};
bool get requiresUsername => credentialKind != ServiceCredentialKind.apiKey &&
                             this != ServiceKey.qbittorrent; // qB allows anonymous
bool get requiresPassword => credentialKind != ServiceCredentialKind.apiKey &&
                             this != ServiceKey.qbittorrent;
```

Values to add (every extension switch is exhaustive → compile errors until done):

| member | nzbget | npm |
|---|---|---|
| `title` | `NZBGet` | `Nginx PM` (not the full name — the dashboard app-bar `Text` has no ellipsis, `service_dashboard_screen.dart:137`) |
| `icon` | `Icons.cloud_download_rounded` | `Icons.router_rounded` |
| `accent` | `AppColors.nzbget` | `AppColors.npm` |
| `apiVersion` | `JSON-RPC` | `REST` |
| `itemLabel` | `downloads` | `proxy hosts` (both plural-safe for `countLabel`'s trailing-`s` strip) |
| `routeParam` | `name` group | `name` group |
| `supportsManualImport` | false (already `||`-based) | false |
| `isSearchable` | false | false |

`lib/core/theme.dart`: add `AppColors.nzbget = Color(0xFF26A69A)` and
`AppColors.npm = Color(0xFFF1583A)` (deliberately away from `navidrome`
green and `prowlarr` red; revisit when brand art lands).

### 2.2 `lib/features/settings/domain/settings_model.dart`

Fields: `nzbgetUrl`, `nzbgetUsername`, `nzbgetPassword`, `npmUrl`,
`npmIdentity`, `npmPassword`. Add to `copyWith`, plus
`copyWithNzbget({url, username, password})` and
`copyWithNpm({url, identity, password})`.

`_serviceSettingsAccess` — **`_serviceAccessFor` does `map[service]!`, so a
missing entry is a runtime crash**, not a compile error:

```dart
ServiceKey.nzbget: _ServiceSettingsAccess(
  url: (s) => s.nzbgetUrl,
  apiKey: (s) => s.nzbgetPassword,
  update: (s, {url, apiKey}) => s.copyWith(nzbgetUrl: url, nzbgetPassword: apiKey)),
ServiceKey.npm: _ServiceSettingsAccess(
  url: (s) => s.npmUrl,
  apiKey: (s) => s.npmPassword,
  update: (s, {url, apiKey}) => s.copyWith(npmUrl: url, npmPassword: apiKey)),
```

(`apiKey` → password is the existing qBittorrent/Navidrome trick that keeps
generic `copyWithService` — used by onboarding and the settings delete button —
working.)

`usernameFor` / `passwordFor`: `nzbget` → `nzbgetUsername` / `nzbgetPassword`;
`npm` → `npmIdentity` / `npmPassword`.

`isServiceConfigured` (insert before the generic fallback at the bottom):
```dart
if (service == ServiceKey.nzbget) {
  return nzbgetUrl.isNotEmpty && nzbgetUsername.isNotEmpty && nzbgetPassword.isNotEmpty;
}
if (service == ServiceKey.npm) {
  return npmUrl.isNotEmpty && npmIdentity.isNotEmpty && npmPassword.isNotEmpty;
}
```

New helper, replaces three hand-rolled clear blocks (and fixes a live bug: the
settings list's delete on Navidrome currently clears only URL+password, leaving
`navidrome_username` behind — `settings_services_screen.dart:41-51`):

```dart
SettingsModel clearedService(ServiceKey service) => switch (service) {
  ServiceKey.qbittorrent => copyWithQbittorrent(url: '', username: '', password: ''),
  ServiceKey.navidrome  => copyWithNavidrome(url: '', username: '', password: ''),
  ServiceKey.nzbget     => copyWithNzbget(url: '', username: '', password: ''),
  ServiceKey.npm        => copyWithNpm(url: '', identity: '', password: ''),
  _ => copyWithService(service, url: '', apiKey: ''),
};
```

### 2.3 `lib/features/settings/data/settings_service.dart`

`_serviceStorageKeys[service]!` is also a runtime crash for a missing key. Add:

| key | storage |
|---|---|
| `nzbget_url` | prefs |
| `nzbget_username` | prefs (`username:` slot) |
| `secure_nzbget_password` | secure (`secureApiKey:`) |
| `npm_url` | prefs |
| `npm_identity` | prefs (`username:` slot) |
| `secure_npm_password` | secure |

`legacyApiKey: ''` for both.

Then:
* `loadSettings()` — read `nzbget_username` / `npm_identity` from prefs and the
  two secure passwords, exactly like the qBittorrent/Navidrome block.
* `saveSettings()` — write/remove the two usernames like `qbUsername`.
* `_loadServiceSettings()` — replace the hardcoded
  `service != qbittorrent && service != navidrome` with `service.usesApiKey`
  (same semantics today, correct for the new services, no future edit needed).
* `_saveServiceApiKeys()` — the qBittorrent special-case can stay; the generic
  line already writes `apiKeyFor(service)` which maps to the password key.
* `clearAll()` iterates the map → automatic. `SettingsBackupService` reads all
  prefs/secure keys → automatic.

### 2.4 `lib/features/settings/data/service_connection_provider.dart`

* `_healthEndpoint` (exhaustive switch): add
  `ServiceKey.nzbget → '/jsonrpc'`, `ServiceKey.npm → '/api/nginx/proxy-hosts'`.
  These are only for exhaustiveness — both services get **early branches** in
  both `_checkService` and `testServiceConnection` because their health call is a
  POST/handshake, exactly like the existing qBittorrent/Navidrome branches.
* `_scrub`: add `npmIdentity` (PII), `nzbgetUsername`, both passwords, both
  URLs to the redaction list.
* Detail strings for `testServiceConnection`:
  * NZBGet RPC error → `'RPC ${code}: ${message}'` (scrubbed to 140 chars).
  * NZBGet HTTP 401 → `'HTTP 401'` (existing `_httpStatusCode` path).
  * NPM `requires_2fa` → `'This account has 2FA enabled — API token auth is not supported'`.
  * NPM otherwise → `'HTTP <code>'`.

### 2.5 `lib/features/services/presentation/services_provider.dart`

Four exhaustive switches/switch-expressions to extend:
`_statusEndpointFor`, `_loadItemCount`, `_loadServiceQueueItems`
(explicit key list → new cases return `const <dynamic>[]`),
`_queueTypeLabel` (`nzbget → 'NZBGet'`, `npm → 'Proxy'`).
Plus `_loadVersion` early branches (both new services).

### 2.6 Routes

* `lib/core/utils/service_routes.dart`: `static const nzbget = '$services/nzbget';`
  `static const npm = '$services/npm';` (list/detail stays in-screen; no
  sub-route in v1).
* `lib/core/router.dart`: `_nzbgetRoutes({path})` /
  `_npmRoutes({path})` shaped like `_qbittorrentRoutes` /
  `_navidromeRoutes` (wrap in `ServiceDashboardScreen`), registered in the
  `/services` children list. NZBGet passes a `trailingAction` (actions bar);
  NPM passes none (read-only).

### 2.7 Settings UI + onboarding (the `usesApiKey` consumers)

* `settings_services_screen.dart`: delete now calls `settings.clearedService(service)`.
* `service_settings_screen.dart`:
  - `bool get isCredentialService => widget.service.credentialKind != ServiceCredentialKind.apiKey;`
  - `_buildUsernameField` / `_buildPasswordField` take labels from
    `service.usernameLabel` / `'Password'`, validators from
    `service.requiresUsername` / `requiresPassword`, `keyboardType:
    TextInputType.emailAddress` for `emailPassword`, and a helper hint under the
    email field: "The email you sign in to Nginx Proxy Manager with".
  - `_updateServiceSettings` gains `isNzBget` / `isNpm` branches calling
    `copyWithNzbget` / `copyWithNpm`.
* `onboarding_screen.dart`:
  - `_serviceColors` map → add both (line 745 does `_serviceColors[k]!` → null crash).
  - `_healthEndpoint` (exhaustive) → add both cases.
  - `_verifyService`: the `!usesApiKey` block currently **falls through to
    `QbittorrentClient`** — NZBGet/NPM would receive a qBittorrent login. Add
    explicit `if (service == ServiceKey.nzbget) …` and
    `if (service == ServiceKey.npm) …` before the qBittorrent fallback.
  - `_isServiceReady`: replace the Navidrome special case with
    `service.requiresUsername`/`requiresPassword`.
  - The card's credential labels/validation → `usernameLabel` + the two
    `requires*` getters; drop the `serviceKey == qbittorrent || navidrome`
    condition.
  - `_saveAndContinue` save/clear: use `clearedService` / the new copyWith
    helpers.

---

## 3. Service A — NZBGet

Scope: queue, history, pause/resume, add-by-URL, delete.

### Options

**A1 — Stateless per-request Basic + `ApiClient` + `NzbgetClient` (RECOMMENDED).**
*Pro:* credential is static, no server-side session exists; reuses `ApiClient`,
`FakeApiClient`, header redaction, DI factory, and the 5 s timeout idiom in
`_checkService`; one JSON-RPC transport class is trivially unit-testable.
*Con:* `ApiClient` sets no timeouts and does not normalise the base URL, so the
client must add `.timeout(...)` per call and normalise once at construction.

**A2 — Session-style client with cookie jar (QbittorrentClient clone).**
*Pro:* identical file shape to qBittorrent, so `_checkService` branches read the
same. *Con:* invents state NZBGet does not have (no login endpoint, no cookie);
drags in `cookie_jar` + `dio_cookie_manager` for nothing; two places to reason
about auth (per-request header vs. cached "authenticated" bool) — plus a bogus
"authenticate" step whose only observable effect is a second HTTP round-trip.

### Wire contract

`POST {baseUrl}/jsonrpc`, `Authorization: Basic base64(user:pass)`,
`Content-Type: application/json`, body
`{"version":"1.1","id":<n>,"method":"<m>","params":[...]}`.
Response `{"version":"1.1","result":<r>,"error":<null|{code,message}>}`.
NZBGet docs: positional params only, **all params are mandatory** — never omit a
trailing param to "default" it.

| use | method | params |
|---|---|---|
| health / version | `version` | `[]` |
| pause state, rates | `status` | `[]` |
| queue | `listgroups` | `[0]` |
| history | `history` | `[false]` |
| pause queue | `pausedownload` | `[]` |
| resume queue | `resumedownload` | `[]` |
| pause item | `editqueue` | `["GroupPause", "", [id]]` |
| resume item | `editqueue` | `["GroupResume", "", [id]]` |
| delete item (→ history) | `editqueue` | `["GroupDelete", "", [id]]` |
| delete history item | `editqueue` | `["HistoryFinalDelete", "", [id]]` |
| add by URL | `append` | `["", url, category, 0, false, false, "", 0, "SCORE", false, []]` |

Two version notes to encode as *friendly errors*, not branches:
* `editqueue` is `(Command, Param, IDs)` since v18; pre-v18 sends `(Command, Offset, Param, IDs)`. On `-32602` return "NZBGet < 18 is not supported".
* `append` gained `AutoCategory` in v17 and `PPParameters` in v16. If the server
  answers `-32602`, retry once without the last param, then once more without the
  last two; if it still fails, surface the RPC message verbatim.

Error mapping (in `NzbgetClient`): HTTP 401 → `NzbgetAuthException('HTTP 401')`;
`error != null` → `NzbgetRpcException(code, message)`; `editqueue`/`pausedownload`
returning `false` → `StateError('NZBGet rejected <command>')`; Dio
`connectionError`/`timeout` propagate (the UI layer already reports them).

Models (tolerant `fromJson`, repo style — see `dynamic_map_utils.dart`):

* `NzbgetQueueItem`: `id` (NZBID), `name` (NZBName), `status`, `category`,
  `fileSizeMb`, `remainingSizeMb`, `downloadedSizeMb`, `health` (permille),
  `activeDownloads`, `maxPriority`, `remainingFileCount`,
  `postInfoText`, `postStageProgress`.
  Derived: `progress = fileSizeMb == 0 ? 0 : 1 - remainingSizeMb/fileSizeMb`,
  `isPaused => status == 'PAUSED'`, `isPostProcessing => status` in the
  `LOADING_PARS…PP_FINISHED` set.
* `NzbgetHistoryItem`: `id`, `name`, `status`, `kind`, `category`,
  `fileSizeMb`, `historyTime` (unix → `DateTime`), `deleteStatus`, `health`,
  `parStatus`, `unpackStatus`, `scriptStatus`, `url`.
  Derived: `succeeded => status.startsWith('SUCCESS')`,
  `deleted => status.startsWith('DELETED')`,
  `failed => status.startsWith('FAILURE') || status.startsWith('WARNING')`.
* `NzbgetStatus`: `remainingSizeMb`, `downloadedSizeMb`, `downloadRateBps`
  (from `DownloadRateLo/Hi`; fall back to deprecated `DownloadRate` on
  `DownloadRateLo == null`), `downloadPaused`, `postPaused`, `serverStandBy`,
  `postJobCount`, `urlCount`, `serverTime`, `freeDiskSpaceMb`.
  Helper `int _u64(int? lo, int? hi) => (hi ?? 0) * 0x100000000 + (lo ?? 0);`

### File-by-file

| file | action | contents |
|---|---|---|
| `lib/core/api/service_auth.dart` | edit | `class BasicAuth implements ServiceAuth { headers() => {'Authorization': 'Basic ${base64Encode(utf8.encode('$username:$password'))}'}; queryParams() => {}; }` (`dart:convert` already imported for `utf8`). |
| `lib/core/utils/url_utils.dart` | edit | `static String normalizeBaseUrl(String)` (trim, prepend `http://` if schemeless, strip trailing `/`). Extracted from `QbittorrentClient._normalizeBaseUrl`; qBittorrent left untouched in this PR. |
| `lib/features/nzbget/data/nzbget_client.dart` | new | JSON-RPC transport: ctor `({required String url, required String username, required String password, ApiClient? apiClient})`; builds `ApiClient(baseUrl: normalize(url), auth: BasicAuth(user, pass))`; `Future<dynamic> call(String method, [List<dynamic> params = const []])` (monotonic `id`, 10 s timeout, envelope unwrap, error mapping); `Future<String> getVersion()`; `void close()`. No endpoint knowledge. |
| `lib/features/nzbget/data/nzbget_service.dart` | new | `nzbgetServiceProvider` (throws `Exception('NZBGet not configured')` when URL/user/pass empty — mirrors `navidromeServiceProvider`); `getStatus`, `getQueue`, `getHistory({bool includeHidden = false})`, `pauseQueue`, `resumeQueue`, `pauseItems(List<int>)`, `resumeItems`, `deleteQueueItems`, `deleteHistoryItems`, `addUrl(String url, {String category = '', int priority = 0, bool paused = false, bool addToTop = true})`. Mapping + `fromJson` live in the models. |
| `lib/features/nzbget/domain/models/nzbget_queue_item.dart` | new | as above. |
| `lib/features/nzbget/domain/models/nzbget_history_item.dart` | new | as above. |
| `lib/features/nzbget/domain/models/nzbget_status.dart` | new | as above. |
| `lib/features/nzbget/presentation/nzbget_provider.dart` | new | `nzbgetStatusProvider`, `nzbgetQueueProvider`, `nzbgetHistoryProvider` (all `FutureProvider.autoDispose`), `nzbgetSelectionProvider` (`StateProvider.autoDispose<Set<int>>`), `nzbgetTabProvider` (`StateProvider<int>`), `nzbgetHistoryFilterProvider`, `nzbgetPollingEnabledProvider` + `nzbgetPollingProvider` (`Timer.periodic(5 s)` invalidating status/queue only — **not** history). |
| `lib/features/nzbget/presentation/nzbget_actions.dart` | new | `runNzbgetAction(...)` copied from `runTorrentAction` (`qbittorrent_actions.dart`) with `NzbgetService` + snackbar + `invalidate` list. |
| `lib/features/nzbget/presentation/nzbget_screen.dart` | new | `showAppBar`/`topPadding` params like `QbittorrentScreen`; `WidgetsBindingObserver` pausing polling when backgrounded; `_StatusBar` (remaining MB, rate, paused badge, post-queue count), segmented Queue/History control, list, `NzbgetSelectionBar`. |
| `lib/features/nzbget/presentation/widgets/nzbget_status_bar.dart` | new | status strip. |
| `lib/features/nzbget/presentation/widgets/nzbget_queue_tile.dart` | new | name, category chip, status pill, MB remaining/total, progress bar, health %, per-item pause/resume + delete via long-press/selection. |
| `lib/features/nzbget/presentation/widgets/nzbget_history_tile.dart` | new | name, status pill (`SUCCESS/*` green, `WARNING/*` amber, `FAILURE/*` red, `DELETED/*` muted), size, relative time, delete. |
| `lib/features/nzbget/presentation/widgets/nzbget_actions_bar.dart` | new | trailing action for `ServiceDashboardScreen`: add-URL button + overflow (`Pause all`, `Resume all`, `Refresh`). Mirrors `QbittorrentActionsBar`. |
| `lib/features/nzbget/presentation/widgets/nzbget_selection_bar.dart` | new | multi-select: pause/resume/delete, `Set<int>` of NZBIDs. |
| `lib/features/nzbget/presentation/widgets/add_nzb_url_sheet.dart` | new | URL field (validated `http/https`), category text field, priority dropdown (`-100 Very low … 900 Force`), "Add paused" switch; calls `addUrl` then invalidates queue+status. |
| *(shared edits)* | edit | §2.1–2.7. |

Settings form: **reuses `isCredentialService`** (now `credentialKind != apiKey`);
`requiresUsername`/`requiresPassword` are both `true` for NZBGet, so the fields
are required — no optional-credentials carve-out like qBittorrent.

Health check (`_checkService` / `testServiceConnection` early branch):

```dart
final client = NzbgetClient(
  url: settings.nzbgetUrl,
  username: settings.nzbgetUsername,
  password: settings.nzbgetPassword,
);
try {
  await client.getVersion().timeout(const Duration(seconds: 5));      // reachability + auth
  await client.call('status').timeout(const Duration(seconds: 5));    // proof of queue scope
  return ServiceConnectionStatus.connected;
} on NzbgetRpcException catch (e) {                                   // auth ok, scope missing
  return (ok: false, detail: 'RPC ${e.code}: ${e.message}');
} catch (_) {
  return ServiceConnectionStatus.disconnected;
} finally { client.close(); }
```

Dashboard mapping (`services_provider.dart`):
`_loadVersion` → `NzbgetClient.getVersion()` (5 s) ⇒ `versionLabel` "v24.3".
`_loadItemCount` → `nzbgetServiceProvider.getQueue().length` ⇒ "3 downloads".

---

## 4. Service B — Nginx Proxy Manager (read-only v1)

Scope: proxy hosts + certificate expiry. Enable/disable and renew are
**explicitly deferred** (they are `PUT /api/nginx/proxy-hosts/{id}` and
`POST /api/nginx/certificates/{id}/renew` — mutating endpoints; deferring keeps
this PR's blast radius to reads and avoids needing a "are you sure" UX).

### Options

**B1 — Standalone `NpmClient` with in-memory token cache (RECOMMENDED).**
*Pro:* matches the credential→token handshake (an async login cannot be
expressed in a synchronous `ServiceAuth`); lets us keep the password out of
`ApiClient`'s body logger; one place for expiry + 401 re-login + login de-dupe;
`Dio` injection gives the same fake-adapter testability qBittorrent already
uses. *Con:* NPM service tests can't use `FakeApiClient`; slightly more code
than a `BearerAuth` one-liner.

**B2 — `ApiClient` + `ServiceAuth` (`NpmTokenAuth implements ServiceAuth`).**
*Pro:* reuses `FakeApiClient`, `serviceStatusClientFactoryProvider`, and the
existing 5 s timeout idiom in `_checkService`; fewest new concepts. *Con:* three
real problems — (a) the token exchange body (`secret`) would pass through the
`LogInterceptor` body logger unredacted; (b) `ServiceAuth.headers()` is read once
at `ApiClient` construction, so each token refresh needs a **new** `ApiClient`
and a mutable holder to keep the reference, which is a client with extra steps;
(c) 401-retry must be hand-rolled per call site instead of one interceptor.

### Wire contract (verified against NPM's OpenAPI schema)

| use | request |
|---|---|
| login | `POST /api/tokens` body `{"identity": "<email>", "secret": "<password>"}` → `{"token": "<jwt>", "expires": "2025-02-04T20:40:46.340Z"}` **or** `{"requires_2fa": true, "challenge_token": "…"}` |
| hosts | `GET /api/nginx/proxy-hosts?expand=certificate` (bearer) |
| certs | `GET /api/nginx/certificates` (bearer) |

Host fields used: `id`, `domain_names[]`, `forward_scheme`, `forward_host`,
`forward_port`, `enabled`, `ssl_forced`, `certificate_id`, `http2_support`,
`allow_websocket_upgrade`, `meta.nginx_online`, `meta.nginx_err`.
Cert fields used: `id`, `provider`, `nice_name`, `domain_names[]`, `expires_on`,
`created_on`, `modified_on`.

`expand=certificate` is deliberate: it lets the Hosts tab render "SSL: expires in
12 d (warn)" per host without a second round trip, and cross-links the
Certificates tab by `certificate_id`.

**2FA accounts:** `requires_2fa` is a hard stop in v1 — surface
"This account has 2FA enabled — API token auth is not supported" and log a
follow-up to add `POST /api/tokens/2fa`. Do not attempt a token without the code.

### Token lifecycle

```
_token, _expires (DateTime?), _loginInFlight (Future<void>?)

ensureAuthenticated():
  if (_token != null && _expires != null && now < _expires - 60s) return
  _loginInFlight ??= _login(); await _loginInFlight
login():  POST /api/tokens → token + expires;  401 → NpmAuthException('HTTP 401')
          requires_2fa → NpmTwoFactorRequiredException
          expires absent → _jwtExpiry(token) (base64url payload 'exp') ?? now + 30 min
onError interceptor: 401 && !extra['skipAuthRetry'] && hasCredentials
          → force re-login (clear _token first), mark skipAuthRetry, retry once
          → second 401 propagates as-is (never loops)
```

`_jwtExpiry` decodes the payload segment only (no signature verification —
we are not the issuer). Concurrent requests share `_loginInFlight`; this copies
`QbittorrentClient.authenticate()`'s de-dupe shape.

### "Cert expiring soon"

Pure function in `lib/features/npm/domain/cert_expiry.dart`, unit-testable
without Flutter:

```dart
enum CertExpiryStatus { ok, expiringSoon, critical, expired, unknown }

CertExpiryStatus certExpiryStatus(DateTime? expiresOn, {DateTime? now}) {
  if (expiresOn == null) return CertExpiryStatus.unknown;
  final d = expiresOn.toUtc().difference((now ?? DateTime.now()).toUtc());
  if (d.isNegative) return CertExpiryStatus.expired;
  if (d.inDays < 7) return CertExpiryStatus.critical;
  if (d.inDays < 30) return CertExpiryStatus.expiringSoon;
  return CertExpiryStatus.ok;
}
```

Threshold rationale: NPM's renewal runs daily and Let's Encrypt renews inside
30 days, so 30 d is the "renewal is failing" signal; 7 d is "act now". UI copy:
`ok` "expires in 74 d", `expiringSoon` "expires in 12 d", `critical` "expires in
3 d", `expired` "expired 2 d ago", `unknown` "no expiry data".
`expires_on` is ISO-8601 with `Z` → parse with `DateTime.parse` (returns UTC when
the string has `Z`), then compare in UTC.

### File-by-file

| file | action | contents |
|---|---|---|
| `lib/features/npm/data/npm_client.dart` | new | ctor `({required String url, required String identity, required String password, Dio? dio})` → `Dio(BaseOptions(baseUrl: UrlUtils.normalizeBaseUrl(url), connectTimeout: 10 s, receiveTimeout: 15 s, sendTimeout: 10 s, headers: {'Accept': 'application/json'}))`; `hasCredentials`; `ensureAuthenticated()`; `login()`; `get(path, {query})` (awaits auth, bearer header, 401 retry interceptor added in ctor); `close()`. No `LogInterceptor`. |
| `lib/features/npm/data/npm_service.dart` | new | `npmServiceProvider` (throws `Exception('Nginx Proxy Manager not configured')`); `ping()` → `ensureAuthenticated()`; `getProxyHosts()`; `getCertificates()`; `getCertificate(int id)` (local lookup, no call); tolerant list parsing (`data is List ? … : const []`). |
| `lib/features/npm/domain/models/npm_proxy_host.dart` | new | fields above; `primaryDomain => domain_names.isEmpty ? '—' : domain_names.first`; `isLive => meta['nginx_online'] != false`; `toSummary()` for the `expand=certificate` sub-object (`expires_on`). |
| `lib/features/npm/domain/models/npm_certificate.dart` | new | fields above; `expiryStatus` delegated to `certExpiryStatus`. |
| `lib/features/npm/domain/cert_expiry.dart` | new | pure thresholds + label formatter (`certExpiryLabel`). |
| `lib/features/npm/presentation/npm_provider.dart` | new | `npmHostsProvider`, `npmCertificatesProvider` (autoDispose), `npmHostQueryProvider` (`StateProvider<String>`), `npmTabProvider`. No polling (read-only, manual pull-to-refresh). |
| `lib/features/npm/presentation/npm_screen.dart` | new | `showAppBar`/`topPadding`; summary bar; Hosts/Certificates segmented control; `RefreshIndicator`; per-tab empty/error states. |
| `lib/features/npm/presentation/widgets/npm_summary_bar.dart` | new | "N hosts · M enabled · K certs · X expiring" + worst-cert chip (uses `AppColors.warning`/`error`). |
| `lib/features/npm/presentation/widgets/npm_host_tile.dart` | new | domains, `scheme://forward_host:forward_port`, enabled/disabled pill, SSL chip from linked cert, `nginx_online == false` warning line. Read-only (no toggle). |
| `lib/features/npm/presentation/widgets/npm_cert_tile.dart` | new | nice_name, provider, domain list, expiry chip + relative label. |
| *(shared edits)* | edit | §2.1–2.7. |

Settings form: `credentialKind == emailPassword` → first field label **"Email"**,
`keyboardType: TextInputType.emailAddress`, `autocorrect: false`, required;
second field "Password", required. Storage lands in `npm_identity` (prefs) +
`secure_npm_password`. Rationale for reusing the username slot rather than a new
form variant: the credential form is already a two-field shape
(`_buildUsernameField`/`_buildPasswordField`); only the *label, keyboard and
validator* differ, and `usernameFor(service)` keeps the generic path (onboarding,
delete, backup) working. A separate `identity` widget variant would duplicate the
same two `TextFormField`s for no gain.

Dashboard mapping: `_loadVersion` → `client.ensureAuthenticated()` (5 s) → return
`null` (no version endpoint; `versionLabel` falls back to "REST API").
`_loadItemCount` → `getProxyHosts().length` ⇒ "3 proxy hosts".
Keep `ServiceSummary` untouched in v1; a cert-expiry badge would need a new
optional field — defer, the NPM screen carries it.

---

## 5. Test plan

New/extended, all under `test/`:

**Shared**
* `test/core/api/service_auth_test.dart` *(new)* — `BasicAuth` header is
  `Basic ` + base64 of `user:pass`; `queryParams()` empty; empty password still
  encodes (no crash).
* `test/features/settings/domain/settings_model_test.dart` — `credentialKind`
  mapping, `usesApiKey` false for the four credential services, `isSearchable`
  false for the four, `isServiceConfigured` for nzbget/npm (each missing field →
  false), `urlFor`/`apiKeyFor` round-trip, `clearedService` for all 11 values
  (guards the Navidrome username bug).
* `test/features/settings/data/settings_service_test.dart` — round-trip
  `nzbget_url`/`nzbget_username`/`secure_nzbget_password` and
  `npm_url`/`npm_identity`/`secure_npm_password`; empty password deletes the
  secure key; `clearAll` removes all six.
* `test/features/settings/data/service_connection_provider_test.dart` — local
  `HttpServer` cases (existing style): NZBGet 200+`{result:"24.3"}` → connected;
  NZBGet 401 → disconnected / `HTTP 401`; NZBGet 200 + `error` object → detail
  starts `RPC`; NPM token 200 + hosts 200 → connected; NPM token 401 → `HTTP 401`;
  NPM `requires_2fa` → detail mentions 2FA.
* `test/core/router_test.dart` + `test/core/utils/service_routes_test.dart` —
  `/services/nzbget` and `/services/npm` build; constants correct.

**NZBGet**
* `test/features/nzbget/data/nzbget_client_test.dart` — uses `FakeApiClient`
  injected as the `ApiClient`: path is `/jsonrpc`, body has
  `version/method/params`, `result` unwrapped, `error` → `NzbgetRpcException`
  with code+message, HTTP 401 (`DioException` with 401) → `NzbgetAuthException`,
  `getVersion()` returns the string, `close()` closes.
* `test/features/nzbget/data/nzbget_service_test.dart` — queue/history/status
  mapping from canned payloads; `addUrl` sends the exact 11-element param list
  (`''`, url, category, priority, addToTop, paused, `''`, 0, `'SCORE'`, false,
  `[]`); `deleteQueueItems` → `['GroupDelete','',[id]]`; `deleteHistoryItems` →
  `['HistoryFinalDelete','',[id]]`; `pauseQueue`/`resumeQueue` methods;
  `addUrl` RPC `-32602` triggers the arity fallback exactly once; provider throws
  when unconfigured.
* `test/features/nzbget/domain/models/*_test.dart` — `fromJson` with missing
  fields, string-vs-int tolerance, 64-bit `Lo/Hi` recomposition, progress maths
  (0-size → 0, remaining>total clamps), status predicates per status string
  (`SUCCESS/ALL`, `WARNING/SCRIPT`, `FAILURE/PAR`, `DELETED/MANUAL`,
  `DOWNLOADING`, `PP_FINISHED`).
* `test/features/nzbget/presentation/nzbget_provider_test.dart` — queue provider
  passes through service errors; selection set add/clear; polling provider
  registers/cancels a timer (fake async) and is disabled when the toggle is off.

**NPM**
* `test/features/npm/data/npm_client_test.dart` — `_MockAdapter` style from
  `qbittorrent_client_test.dart`: login posts `{identity, secret}` to
  `/api/tokens`; bearer applied to subsequent GETs; 401 → re-login → retry once
  → success (assert 3 requests); double 401 → throws and stops (assert no loop);
  cached token is not re-fetched while unexpired; token with `expires` in the past
  → re-login before the next call; `requires_2fa` → `NpmTwoFactorRequiredException`;
  `expires` absent + JWT `exp` → uses the claim.
* `test/features/npm/data/npm_service_test.dart` — host/cert list parsing,
  `expand=certificate` present in query, unexpected (non-list) body → empty list,
  provider guard when identity/password/url missing.
* `test/features/npm/domain/cert_expiry_test.dart` — boundaries at 30/7/0 days
  and negative, `null` → unknown, UTC comparison with a non-UTC `now`.
* `test/features/npm/presentation/npm_provider_test.dart` — query filter is
  case-insensitive across all `domain_names`; worst-cert selection drives the
  summary chip.

**Regression watch** — `test/features/services/presentation/services_provider_test.dart`
adds nzbget/npm summary cases, and `test/features/services/presentation/services_screen_test.dart`
+ `service_dashboard_screen_test.dart` must still pass with 11 enum values (the
picker and status grid iterate `ServiceKey.values`; `services_status_overview.dart:30`
counts `values.length`).

---

## 6. Device verification checklists

### NZBGet (real instance, both a Control user and an Add-only user)

1. Settings → NZBGet: URL + username + password, Save. Indicator turns
   "Connected"; reopen the screen and confirm the password field is repopulated
   from secure storage.
2. Test Connection with a **wrong password** → "HTTP 401"; with an **Add-only**
   user → detail starts `RPC`, not a green check (that is the point of calling
   `status`).
3. Dashboard card: host shown, version "v24.x", count matches the NZBGet web
   UI queue length. Pause the queue in NZBGet, pull-to-refresh → card still
   online, app bar status shows Paused.
4. Queue tab: item name/category/size/health/progress match the web UI; the
   in-progress item shows `postInfoText`/stage % while post-processing.
5. Pause all → NZBGet web UI queue shows paused; resume all → downloading
   resumes. Verify the polling interval looks like ~5 s and stops when the app
   is backgrounded (no requests in NZBGet's connection log while backgrounded).
6. Single item pause/resume via selection bar matches the web UI state after
   refresh; multi-select of 3 items pauses exactly those 3.
7. Add by URL with a real NZB URL → item appears at the top of the queue with the
   chosen category and priority; "Add paused" lands it as PAUSED.
8. Delete a queue item → confirm dialog → it leaves the queue and appears in
   History (not "final delete"). Delete a history item → it disappears from
   History.
9. HTTPS with a self-signed cert behaves the same as the other services (same
   trust policy), and a URL with a sub-path (`/nzbget`) still resolves
   `/nzbget/jsonrpc` (base URL normalisation).
10. Airplane mode → dashboard card goes Offline within one refresh; no crash,
    no endless spinner; the Test button reports a transport error, not "HTTP".

### NPM (real instance, one account without 2FA and one with)

1. Settings → Nginx PM: URL + **email** + password; the field is labelled
   "Email", uses the email keyboard and refuses an empty/whitespace value.
2. Test Connection: correct credentials → Connected; wrong password →
   `HTTP 401`; **2FA-enabled account** → clear "2FA is not supported" message
   (not a spin-forever).
3. Dashboard card: host, "REST API" label, host count equals
   `/api/nginx/proxy-hosts` length in the NPM UI.
4. Hosts tab: domains, forward target, enabled/disabled, websocket/HTTP2 flags,
   SSL chip — each row compared against the NPM UI row.
5. Certificates tab: every cert present with provider and relative expiry
   ("expires in N d") that matches the NPM UI; a cert already inside 30 days
   shows amber, inside 7 days red, and an expired cert shows "expired N d ago".
   Timezone: the device in a non-UTC zone still shows the same day count.
6. Host↔cert cross-link: a host with `certificate_id` points at the same cert's
   expiry chip (thanks to `expand=certificate`).
7. Token expiry: leave the app open > token lifetime (or set the NPM token
   lifetime low), trigger a refresh → the request silently re-logs in and
   returns data (one 401 then 200 in the NPM access log, no error toast).
8. Kill the NPM admin password (change it in NPM) → next refresh shows an auth
   error once, not a retry storm; the Settings screen still opens so the user can
   fix credentials.
9. Read-only guarantee: no `PUT`/`POST`/`DELETE` from this feature appears in the
   NPM logs except `POST /api/tokens`.
10. 11 services configured at once: Services dashboard grid scrolls, the service
    picker lists all 11, and the app bar title does not overflow on a 360 dp
    screen (drives the short "Nginx PM" title).

---

## 7. Sequencing

1. **PR 1 — plumbing only** (§2): `credentialKind`, storage keys, model, health
   switch cases, dashboard switches, routes, settings/onboarding branch cleanup,
   `clearedService`. Tests: the shared block above. No new screens; existing
   suite must stay green (this is where the exhaustive-switch breakage gets paid
   once).
2. **PR 2 — NZBGet** (§3): client, service, models, providers, screens, tests,
   dashboard + health branches.
3. **PR 3 — NPM** (§4): client (token machine), service, models, cert expiry,
   providers, screens, tests, dashboard + health branches.

Deferred, deliberately: NPM enable/disable + cert renew, NZBGet speed limit /
config editing / RSS, and any `ServiceSummary` schema change for cert badges.
