# OpenMediaVault 7 — read-only integration blueprint

Status: design (nothing implemented yet)
Scope: **read-only monitoring** — system info, filesystems, services state, disks + SMART.
Out of scope by contract: reboot, shutdown, standby, service enable/disable, filesystem
mount/umount/create/grow, disk wipe, SMART self-test execution, config writes of any kind.

---

## 1. Options considered

### Option A — feature-layer session client (recommended)

`lib/features/openmediavault/data/openmediavault_client.dart`, modelled on
`QbittorrentClient`: owns its own `Dio`, performs `Session.login` once, caches the
returned `sessionid`, sends it as `X-OPENMEDIAVAULT-SESSIONID` on every request, and
re-logins once on HTTP 401 behind a `skipAuthRetry` guard.

| | |
|---|---|
| Round-trips per screen | 1 login + N reads |
| Concurrency | one session shared by all reads; safe |
| Failure surface | 401 → transparent re-login, mirrors qBittorrent, already-tested pattern |
| Fit with `ServiceAuth`/`ApiClient` | none needed; `ApiClient` is stateless by design (headers + query params only) |
| Cost | one extra class (~200 lines) + ~6 client tests |

### Option B — per-request auth through `ServiceAuth` + `ApiClient`

Add a `SessionAuth implements ServiceAuth` that logs in on every `headers()` call
(impossible: `headers()` is sync) — the only workable variant is "login before each
`ApiClient` call" in the service layer.

| | |
|---|---|
| Round-trips per screen | 2 × N (login + read) |
| Correctness | every login creates/regenerates a PHP session (`session_regenerate_id()`), so sessions accumulate until PHP GC |
| Failure surface | concurrent reads race on `Session.login`; OMV answers `400 "Another user is already authenticated."` when a session is already bound to a different user |
| Fit | `ApiClient` works but adds a stateless abstraction over a stateful protocol; `ServiceAuth` cannot express "cookie set by a previous response" |
| Cost | fewer new classes, but a permanently awkward lifecycle |

**Why A wins, concretely:** OMV's `Session.login` returns
`{authenticated, username, permissions, sessionid}`; the server reads the id from
`$_SERVER['HTTP_X_OPENMEDIAVAULT_SESSIONID']` (`openmediavault/session.inc` §start).
There is no token or API-key mechanism in OMV 7 — the session id *is* the auth
artifact, so it must be cached client-side. `ApiClient`'s API-key/bearer model has
nowhere to put it.

---

## 2. Verified OMV 7 protocol facts

Verified by reading `openmediavault/openmediavault` branch **7.x** source
(`engined/rpc/*.inc`, `var/www/openmediavault/rpc/session.inc`,
`php/openmediavault/session.inc`, `php/openmediavault/system/system.inc`,
`datamodels/rpc.common.json`). Everything below is still on the device-verification
checklist — a fork/plugin can differ.

### Transport

```
POST {baseUrl}/rpc.php
Content-Type: application/json
X-OPENMEDIAVAULT-SESSIONID: <sessionid>      (all calls except login)

{"service":"System","method":"getInformation","params":{}}

200 → {"response": <payload>, "error": null}
4xx/5xx → {"response": null, "error": {"code":…, "message":…, "trace":…}}
```

- Login: `{"service":"Session","method":"login","params":{"username","password"}}` →
  `{"response":{"authenticated":true,"username":"admin","permissions":{...},"sessionid":"…"}}`.
  Bad credentials → **HTTP 400**, `error.message == "Incorrect username or password."`
  (not 401).
- **Gotcha:** when the session is *already* authenticated as the same user, `login`
  returns `sessionid: ""`. Never overwrite a cached id with an empty string.
- The session is bound to the **User-Agent** (`validateUserAgent`, 401 on mismatch).
  IP binding exists but `validateIpAddress()` is commented out in `validate()`.
  ⇒ send one stable `User-Agent` for the client's whole lifetime.
- Expired/invalid session → **HTTP 401** ("Authentication required"/"Session expired").
  Role failures → 403-style permission error; **do not** re-login on 403.
- `rpc.common.getlist` params: `start` (int, **required**), `limit` (int|null,
  **required**), optional `sortfield`, `sortdir` (`asc|ASC|desc|DESC`), `search`.
  Sending `{}` fails validation.

### Services / methods (all require `OMV_ROLE_ADMINISTRATOR` except where noted)

| Service | Method | Params | Payload |
|---|---|---|---|
| `Session` | `login` | `{username, password}` | `{authenticated, username, permissions, sessionid}` |
| `Session` | `logout` | — | — |
| `System` | `getInformation` | none | hostname/time for everyone; **version, cpu\*, mem\*, kernel, uptime, loadAverage, rebootRequired, availablePkgUpdates, configDirty** only for admin |
| `FileSystemMgmt` | `getList` | getlist | `{total, data:[filesystem]}` |
| `FileSystemMgmt` | `enumerateMountedFilesystems` | `{}` / `{type?, includeroot?}` | bare array of mounted filesystems |
| `DiskMgmt` | `getList` | getlist | `{total, data:[disk]}` |
| `Smart` | `getList` | getlist | `{total, data:[smartdevice]}` |
| `Smart` | `getInformation` | `{devicefile}` | SMART info incl. `temperature`, `powercycles`, `poweronhours` |
| `Services` | `getStatus` | none | `{total, data:[{name,title,enabled,running}]}` |

⚠ There is **no `ServiceMgmt` service in OMV 7** — it is `Services` (plural).
⚠ The docs write `DiskMgnt::getList`; the class is `DiskMgmt` (`getName()` returns
`"DiskMgmt"`).

### Field casing/shapes (the ones that bite)

`System.getInformation`:
`hostname` string · `version` string like `"7.4.17 (Sandworm)"` · `kernel` string
`"Linux 6.1.0-18-amd64"` · `uptime` **float seconds** · `loadAverage`
**object** `{1min,5min,15min}` (not an array) · `cpuModelName` string ·
`cpuCores` int · `cpuUtilization` int % · `cpuMhz` number ·
`memTotal/memFree/memUsed/memAvailable` **strings of bytes** ·
`memUtilization` number (0–1 or 0–100 — verify) · `configDirty` bool ·
`dirtyModules` array · `rebootRequired` bool · `availablePkgUpdates` int ·
`ts` int.

`FileSystemMgmt.getList` item: `devicefile`, `canonicaldevicefile`,
`predictabledevicefile`, `parentdevicefile`, `devlinks[]`, `uuid`, `label`, `type`,
`mounted` bool, `mountpoint`, `blocks`, **`size`/`used`/`available` are strings**
(`"-1"` when unknown; `used` is `binary_format()` output), `percentage` **int**
(`-1` unknown), `description`, `comment`, `_used`, `_readonly`, `hasmultipledevices`,
`propposixacl|propquota|propresize|propfstab|propcompress|propautodefrag`.

`DiskMgmt.getList` item: `devicename`, `canonicaldevicefile`, `devicefile`,
`devicelinks[]`, `model`, `vendor`, `serialnumber`, `wwn`, **`size` string of bytes**,
`description` (e.g. `n/a [/dev/sda, 465.76 GiB]`), `israid`, `isroot`, `isreadonly`,
`powermode` (`ACTIVE|STANDBY|SLEEP|UNKNOWN`), `temperature` int or `""`,
`hotpluggable`, optional `hdparm`.

`Smart.getList` item: same identity fields plus `temperature` (int or `""` when in
standby), `overallstatus` ∈ `GOOD | BAD_ATTRIBUTE_IN_THE_PAST | BAD_SECTOR |
BAD_ATTRIBUTE_NOW | BAD_SECTOR_MANY | BAD_STATUS`, `monitor` bool, `uuid`, `_used`.

`Services.getStatus` item: `name`, `title` (localized!), `enabled` bool,
`running` bool. `name` is the module name (e.g. `ssh`, `smb`, `ftp`), **not** a
systemd unit.

---

## 3. Settings / form decisions

- `ServiceKey.openmediavault` — new enum case (name `openmediavault` gives route
  param `openmediavault` for free).
- It is a **credential service**, exactly like qBittorrent/Navidrome:
  `isCredentialService => isQbittorrent || isNavidrome || isOpenMediaVault`.
  No API key field, so `usesApiKey => false`.
- `isSearchable => false` (nothing to search; adding it to the global search sources
  would make the search screen query OMV on every keystroke).
- `supportsManualImport => false`.
- `apiVersion => 'RPC'` (fallback label `"RPC API"` when live version is missing).
- `itemLabel => 'disks'` (dashboard shows "4 disks"; "services" would collide with
  Seekarr's own notion of services).
- Accent `AppColors.openmediavault = Color(0xFF0EA5E9)` (sky-500; unused in the palette).

### Storage keys (`SettingsService`)

| Purpose | Key | Store |
|---|---|---|
| Base URL | `openmediavault_url` | SharedPreferences |
| Admin username | `openmediavault_username` | SharedPreferences (same as qbittorrent/navidrome) |
| Admin password | `secure_openmediavault_password` | `SecureSettingsStore` |

`_ServiceStorageKeys` entry:
```dart
ServiceKey.openmediavault: _ServiceStorageKeys(
  url: 'openmediavault_url',
  legacyApiKey: '',
  secureApiKey: 'secure_openmediavault_password',
  username: 'openmediavault_username',
),
```
Because the username/password pair is loaded explicitly (like qBittorrent), add
`openmediavault` to the `service != qbittorrent && service != navidrome` exclusion in
`_loadServiceSettings`, load it in `loadSettings()` next to `qb*`/`nd*`, save the
username in `saveSettings()`, and `continue` past the generic
`_saveServiceApiKeys` path for it (mirroring the qBittorrent branch).
`clearAll()` and the encrypted backup service need no change — they iterate
`_serviceStorageKeys`, prefs keys generically, and `secureStore.readAll()`.

`SettingsModel` gains `openmediavaultUrl`, `openmediavaultUsername`,
`openmediavaultPassword` + `copyWith` args + `copyWithOpenMediaVault({url, username,
password})` + `_ServiceSettingsAccess` entry mapping `apiKey` → password (same shim as
qBittorrent) + `usernameFor`/`passwordFor` branches +
`isServiceConfigured` branch `url.isNotEmpty && username.isNotEmpty && password.isNotEmpty`.

---

## 4. Health check / Test Connection

`_checkService` / `testServiceConnection` branch (before the generic `ApiClient`
path, next to qBittorrent):

1. `OpenMediaVaultClient(...)`; `await client.login().timeout(5s)`.
   - fail with HTTP 400 → detail = scrubbed `error.message`
     (`Incorrect username or password.`); HTTP 401 → `Session rejected`;
     timeout/connection refused → existing `_errorDetail` path.
2. `await client.rpc('System','getInformation', {})` (5s).
3. If `login` reported `permissions.role != 'admin'` → `(ok: false, detail:
   'Signed in, but "user" is not an administrator. Most OMV data requires an admin
   account.')` — OMV gates every read method on `OMV_ROLE_ADMINISTRATOR`, so a
   non-admin "success" would produce four broken tabs.
4. Otherwise `(ok: true, detail: '')`.
5. `client.close(logout: true)` in `finally`.

`_healthEndpoint` switch still needs a `ServiceKey.openmediavault` case to stay
exhaustive — return `'/rpc.php'` (unused, the branch above short-circuits).

Scrubbing: add OMV credentials to `_scrub` (`omvUrl`, `omvUsername`, `omvPassword`).

---

## 5. Dashboard mapping

| Surface | Source | Mapping |
|---|---|---|
| `serviceSummaryProvider` status | login + `System.getInformation` | 200 & authenticated → `online`; any throw → `offline` |
| version | `getInformation.version` | `"7.4.17 (Sandworm)"` → `versionLabel` renders `v7.4.17 (Sandworm)` |
| itemCount | `DiskMgmt.getList` (`start:0, limit:-1`) `total` | `"4 disks"`; failure → `null` → `"Summary unavailable"` |
| host | `service.extractHost(url)` | existing helper |
| `services_status_overview` grid | `ServiceKey.values.where(isServiceConfigured)` | automatic — no edit needed |
| `ServicesOnlineSummary` | `ServiceKey.values` | automatic |
| service picker / dashboard switcher | ServiceKey-driven | automatic |

Add branches in `services_provider.dart`: `_loadVersion` (before the generic
`ApiClient`) and `_loadItemCount` (new `case ServiceKey.openmediavault`).
`_statusEndpointFor` gains a case for exhaustiveness only.

---

## 6. File-by-file blueprint

### New files

**`lib/features/openmediavault/data/openmediavault_client.dart`**
```dart
class OpenMediaVaultException implements Exception {
  final String message; final int? httpStatus; final int? code;
}

class OpenMediaVaultClient {
  OpenMediaVaultClient({required String url, required this.username,
      required this.password, Dio? dio,});

  static const sessionHeader = 'X-OPENMEDIAVAULT-SESSIONID';
  static const _userAgent = 'Seekarr';           // stable => session stays valid
  static const _readOnly = {                     // hard read-only guard
    'Session.login', 'Session.logout',
    'System.getInformation',
    'FileSystemMgmt.getList', 'FileSystemMgmt.enumerateMountedFilesystems',
    'DiskMgmt.getList', 'Smart.getList', 'Smart.getInformation',
    'Services.getStatus',
  };

  String? _sessionId; bool _authenticated = false;
  Future<bool>? _loginInFlight;

  Future<bool> login();                          // POST Session.login, mutex'd
  Future<dynamic> rpc(String service, String method,
      [Map<String,dynamic>? params]);            // asserts _readOnly
  Future<Map<String,dynamic>> _envelope(...);    // unwraps response/error
  Future<void> logout();
  void close({bool logout = false});
}
```
Behaviour:
- `_normalizeBaseUrl` copied from `QbittorrentClient` (prefix `http://`, strip `/`).
- `BaseOptions(connectTimeout: 10s, receiveTimeout: 30s, sendTimeout: 10s,
  headers: {'User-Agent': _userAgent}, contentType: 'application/json')`.
  ￼30 s receive is deliberate: `Smart.getList` shells out to `smartctl` per disk and
  blocks ~10–20 s on a spun-down drive.
- `login()`: dedupe via `_loginInFlight`; posts `{'service':'Session','method':'login',
  'params':{...}}` directly through `_dio` (never through `rpc()`, no recursion);
  `_authenticated = body['response']['authenticated'] == true`; assign
  `_sessionId` **only when the returned id is non-empty**.
- `rpc()`: throw `StateError` when the pair is not in `_readOnly`; `login()` first if
  needed; POST `{'service':service,'method':method,'params':params ?? {}}` with the
  session header; unwrap; on `error != null` throw `OpenMediaVaultException(...)`.
- Interceptor (copied from `QbittorrentClient`): on 401 and `!alreadyRetried` →
  `_sessionId = null; _authenticated = false; await login()` → retry once with
  `extra['skipAuthRetry'] = true`. 403 never retries.
- `close({bool logout = false})` → optional best-effort `Session.logout`, then
  `_dio.close(force: true)`.

**`lib/features/openmediavault/data/openmediavault_service.dart`**
```dart
class OpenMediaVaultService {
  final OpenMediaVaultClient client;
  Future<OmvSystemInfo> getSystemInfo();            // System.getInformation {}
  Future<List<OmvFilesystem>> getFilesystems();     // FileSystemMgmt.getList
  Future<List<OmvDisk>> getDisks();                 // DiskMgmt.getList
  Future<List<OmvSmartDevice>> getSmartDevices();   // Smart.getList
  Future<List<OmvServiceStatus>> getServices();     // Services.getStatus
}
```
`getList` params are always `{'start': 0, 'limit': -1, 'sortfield': null,
'sortdir': 'ASC'}` (see §2 — `start`/`limit` are required; `-1` means "no limit";
verify `-1` on the device, fall back to `null` if rejected).
No generic `rpc` exposure: the UI can only call these five typed reads.

**`lib/features/openmediavault/data/openmediavault_providers.dart`**
```dart
final openMediaVaultClientProvider = Provider<OpenMediaVaultClient>((ref) {
  final s = ref.watch(currentSettingsProvider);
  if (s.openmediavaultUrl.isEmpty || s.openmediavaultUsername.isEmpty ||
      s.openmediavaultPassword.isEmpty) throw Exception('OpenMediaVault not configured');
  return OpenMediaVaultClient(url: s.openmediavaultUrl,
      username: s.openmediavaultUsername, password: s.openmediavaultPassword);
});
final openMediaVaultServiceProvider = Provider<OpenMediaVaultService>(...);
final omvSystemInfoProvider   = FutureProvider.autoDispose<OmvSystemInfo>(...);
final omvFilesystemsProvider  = FutureProvider.autoDispose<List<OmvFilesystem>>(...);
final omvDisksProvider        = FutureProvider.autoDispose<List<OmvDisk>>(...);
final omvSmartDevicesProvider = FutureProvider.autoDispose<List<OmvSmartDevice>>(...);
final omvServicesProvider     = FutureProvider.autoDispose<List<OmvServiceStatus>>(...);
```
The `Provider` is **not** `autoDispose` (same as `qbittorrentServiceProvider`), so the
session survives tab switches; settings changes rebuild it and drop the old client.
Wrap the two slow providers (disks, smart) with `ref.onDispose(() => …)` only if a
client-per-provider refactor happens later — for v1 reuse the single client, as
qBittorrent does.

**`lib/features/openmediavault/domain/models/omv_parse.dart`**
`asString`, `asInt`, `asDouble`, `asBool`, `asMap`, `asList`, `bytesFromString`
(handles `"-1"` → null), `formatBytesFromString` (`"500107862016"` → `"465.8 GiB"`),
`formatUptime(double seconds)` (`"12d 4h 31m"`), `stripVersionName`
(`"7.4.17 (Sandworm)"` → `("7.4.17","Sandworm")`), `smartAssessmentIsHealthy`.
Mirror the style of `lib/features/qbittorrent/domain/models/parse_utils.dart`; do not
import qBittorrent's file (feature isolation).

**`.../domain/models/omv_system_info.dart`** — `OmvSystemInfo.fromJson`; every field
nullable/defensive (non-admin responses omit nearly everything). Derived getters:
`displayVersion`, `uptimeLabel`, `memoryUsedRatio` (null when `memTotal` is `"0"`),
`loadLabel` (`"0.42 / 0.51 / 0.60"`).

**`.../domain/models/omv_filesystem.dart`** — `devicefile`, `mountpoint`, `type`,
`label`, `uuid`, `sizeBytes`, `usedBytes`, `availableBytes` (ints parsed from strings;
null when `-1`), `percentage` (null when `< 0`), `mounted`, `description`, `comment`,
`isRoot` (`_readonly`). `usageRatio => percentage/100` clamped 0..1.

**`.../domain/models/omv_disk.dart`** — `devicename`, `devicefile`, `model`, `vendor`,
`serialnumber`, `sizeBytes`, `temperatureC` (null when `""`), `powerMode`, `isRaid`,
`isRoot`, `hotpluggable`, `description`.

**`.../domain/models/omv_smart_device.dart`** — identity + `overallStatus` (raw),
`isHealthy`, `monitorEnabled`. `fromJson` tolerant of `""`/missing.

**`.../domain/models/omv_service_status.dart`** — `name`, `title`, `enabled`,
`running` + `stabilityLabel` (`Running` / `Stopped` / `Disabled`).

**`lib/features/openmediavault/presentation/openmediavault_screen.dart`**
`OpenMediaVaultScreen({required double topPadding})` — no `AppBar` (the
`ServiceDashboardScreen` overlay provides title + switcher; same approach as
`QbittorrentScreen(showAppBar:false, topPadding: _serviceDashboardTopPadding)`).
`DefaultTabController(length: 4)`; `TabBar` (scrollable) under `topPadding`;
tabs: **Overview · Storage · Disks · Services**, each an `AsyncValueWidget` with
`serviceName: 'OpenMediaVault'`, `RefreshIndicator` invalidating its provider.
Read-only footer on Overview: *"Read-only — Beakarr never changes your OMV
configuration."*

**`.../presentation/widgets/omv_stat_tile.dart`** — label/value/trailing widget
(hostname, version, kernel, uptime, load, CPU, memory).
**`.../presentation/widgets/omv_usage_bar.dart`** — pill + `LinearProgressIndicator`,
color by threshold (≥90 error, ≥75 warning, else accent).
**`.../presentation/widgets/omv_health_pill.dart`** — SMART assessment →
`GOOD`=success, `BAD_SECTOR*`/`BAD_ATTRIBUTE*`=warning, `BAD_STATUS`=error,
`""`/unknown=neutral "No SMART".

### Modified files

| File | Change |
|---|---|
| `lib/features/settings/domain/service_key.dart` | enum case + 6 switch arms (`title` "OpenMediaVault", `icon` `Icons.storage_rounded`, `accent`, `usesApiKey` false, `isSearchable` false, `apiVersion` `'RPC'`, `itemLabel` `'disks'`, `routeParam` grouped with `name`) |
| `lib/core/theme.dart` | `AppColors.openmediavault` |
| `lib/features/settings/domain/settings_model.dart` | 3 fields, defaults, `copyWith`, `_ServiceSettingsAccess` entry, `copyWithOpenMediaVault`, `usernameFor`, `passwordFor`, `isServiceConfigured` |
| `lib/features/settings/data/settings_service.dart` | `_serviceStorageKeys` entry (mandatory — the loop `for (final service in ServiceKey.values) _serviceStorageKeys[service]!` crashes otherwise), `_loadServiceSettings` exclusion, `loadSettings`/`saveSettings` username+password handling, `_saveServiceApiKeys` early `continue` |
| `lib/features/settings/data/service_connection_provider.dart` | `_healthEndpoint` case; login+getInformation branch in `_checkService` and `testServiceConnection`; `_scrub` credentials |
| `lib/features/services/presentation/services_provider.dart` | `_loadVersion` branch (version), `_loadItemCount` case (disk total), `_statusEndpointFor` case |
| `lib/core/utils/service_routes.dart` | `static const openmediavault = '$services/openmediavault';` |
| `lib/core/router.dart` | import screen; `_openMediaVaultRoutes({required String path})`; add to `/services` routes after `_soulsyncRoutes` |
| `lib/features/settings/presentation/service_settings_screen.dart` | `isOpenMediaVault` getter; `isCredentialService` includes it; `_updateServiceSettings` branch calling `copyWithOpenMediaVault`; header copy ("Administrator account required; Seekarr only reads.") |
| `lib/features/settings/presentation/settings_services_screen.dart` | delete button must use `copyWithOpenMediaVault(url:'', username:'', password:'')` — the generic `copyWithService` path writes `apiKey` and would leave the password behind |
| `lib/features/onboarding/presentation/onboarding_screen.dart` | `_verifyService` OMV branch (ephemeral client, login+getInformation); `_isServiceReady` requires URL+username+password; the credential-field branch (`else if (serviceKey == qbittorrent || navidrome)`) gains `|| openmediavault` with labels "Username (admin)" / "Password" |

No change needed: `services_status_overview.dart`, `services_screen.dart`,
`service_dashboard_screen.dart` (all iterate `ServiceKey.values`),
`settings_backup_service.dart` (prefs keys + secure `readAll` are generic),
`search_screen.dart` (`isSearchable` false), activity/import features.

---

## 7. Test plan

All new tests live under `test/features/openmediavault/` and follow the existing
`_MockAdapter implements HttpClientAdapter` pattern from
`test/features/qbittorrent/data/qbittorrent_client_test.dart`.

**`data/openmediavault_client_test.dart`**
1. `login` posts `{service:'Session',method:'login',params:{username,password}}` to
   `/rpc.php`; caches `sessionid`; second `rpc()` sends the header and does **not**
   re-login (assert `callCount`).
2. Empty-string `sessionid` on an already-authenticated response does not clobber the
   cached id.
3. 401 on a read → exactly one re-login + one retry; the retried request carries
   `extra['skipAuthRetry']`.
4. 403 does **not** trigger a re-login.
5. `error != null` envelope → `OpenMediaVaultException` carrying `message`
   (`Incorrect username or password.`) and HTTP 400.
6. `rpc('System','reboot')` / `'FileSystemMgmt','umountByDir'` / `'Smart',
   'executeScheduledTest'` throw `StateError` **before** any HTTP call
   (`callCount == 0`) — the read-only guard.
7. Request header `User-Agent` is identical across login and reads.
8. `params` defaults to `{}` and is passed through verbatim.

**`data/openmediavault_service_test.dart`** (inject a fake `OpenMediaVaultClient` or
a `Dio` mock) — one test per read: exact service+method pair, `start/limit` present on
every `getList`, and JSON → model field mapping against fixture payloads copied from
§2 (including `"size":"-1"`, `"temperature":""`, `loadAverage` as an object,
`memTotal` as a string).

**`domain/models/omv_parse_test.dart`** — `"-1"` → null; `"500107862016"` →
`465.8 GiB`; empty `loadAverage`; `"7.4.17 (Sandworm)"` split; SMART assessment
mapping table.

**`presentation/openmediavault_screen_test.dart`** — pumps the screen with
`ProviderScope(overrides: [...])` returning fixed model lists: 4 tabs present, a
non-mounted filesystem renders "not mounted", `BAD_STATUS` renders an error pill, and
the read-only footer is visible. Assert **no** button whose label matches
reboot/shutdown/enable/disable/self-test exists.

**`test/features/settings/data/settings_service_test.dart`** (extend) — round-trip
`openmediavaultUrl/username/password`; password lands only in secure storage and not
in prefs; `clearAll()` removes all three.

**`test/features/settings/data/service_connection_provider_test.dart`** (extend) —
OMV connection status: configured+200 → `connected`; 400 login → `disconnected` with
the OMV message detail; role `user` → `ok:false` detail mentions administrator;
not configured → `notConfigured`.

**`test/features/services/...services_provider` (extend or new)** — summary maps
version and disk `total`; a thrown read → offline summary.

Regression guard: `flutter analyze` must be clean — every exhaustive `switch` over
`ServiceKey` is compiler-checked, so a missed arm fails the build rather than falling
through at runtime.

---

## 8. Device-verification checklist (live OMV 7)

Nothing below has been exercised against a real OMV instance. Treat each line as a
claim to confirm from the OMV UI's network tab or from
`omv-rpc -u admin "System" "getInformation"` over SSH.

**Protocol**
- [ ] `POST /rpc.php` accepts `{"service","method","params"}` with
      `Content-Type: application/json` (no form encoding).
- [ ] Response envelope is `{"response":…,"error":null}`; error envelope carries
      `error.message` and a matching HTTP status.
- [ ] Bad credentials return **400** with `"Incorrect username or password."`
      (not 401).
- [ ] The session id travels in `X-OPENMEDIAVAULT-SESSIONID` and is honored on a
      subsequent call.
- [ ] Session survives ≥ 5 minutes of idle (no forced mid-screen re-login).
- [ ] A second login on an authenticated session returns `sessionid == ""`.
- [ ] Changing the `User-Agent` string invalidates the session (proves the UA binding).
- [ ] Expired/invalid session yields **401** (the re-login trigger), and a
      non-admin role yields a *different* status (403-class) that must not re-login.

**Service/method names — every one is a claim to verify**
- [ ] `Session.login` · `Session.logout`
- [ ] `System.getInformation` (no params)
- [ ] `FileSystemMgmt.getList` — **and** that `start`/`limit` are both mandatory
- [ ] `FileSystemMgmt.enumerateMountedFilesystems` (optional `type`, `includeroot`)
- [ ] `DiskMgmt.getList` — confirm the spelling is `DiskMgmt`, not `DiskMgnt`
- [ ] `Smart.getList`
- [ ] `Smart.getInformation` (`devicefile` param)
- [ ] `Services.getStatus` — confirm it is **`Services`**, not `ServiceMgmt`
- [ ] That `limit: -1` is accepted; if rejected, switch to `limit: null`
- [ ] That all of the above return a permission error for a non-admin user, while
      `System.getInformation` still returns hostname/time

**Field-level claims**
- [ ] `System.getInformation`: `version` string format (`7.x.y (Name)`), `uptime`
      numeric **seconds** not a string, `loadAverage` **object** with
      `1min/5min/15min`, `mem*` **strings of bytes**, `memUtilization` scale
      (0–1 vs 0–100), `cpuUtilization` unit, `cpuMhz` key present, `rebootRequired`,
      `availablePkgUpdates`, `configDirty`, `dirtyModules`.
- [ ] `FileSystemMgmt.getList`: item keys `devicefile`, `mountpoint`, `type`, `label`,
      `uuid`, `mounted`, `percentage`, `size`, `used`, `available`, `_used`,
      `_readonly`; and that **`used` is human-formatted** while `size`/`available` are
      byte strings (`"-1"` when unknown).
- [ ] Whether `getList` includes unmounted filesystems (expected: yes) versus
      `enumerateMountedFilesystems` (mounted only) — pick the one the UI needs.
- [ ] `DiskMgmt.getList`: `devicename`, `devicefile`, `model`, `vendor`,
      `serialnumber`, `size` (string bytes), `description`, `israid`, `isroot`,
      `isreadonly`, `powermode`, `temperature` (int or `""`), `hotpluggable`, `wwn`.
- [ ] `Smart.getList`: `overallstatus` exact enum strings
      (`GOOD`/`BAD_SECTOR`/`BAD_ATTRIBUTE_NOW`/`BAD_ATTRIBUTE_IN_THE_PAST`/
      `BAD_SECTOR_MANY`/`BAD_STATUS`), `temperature` `""` on standby, `monitor`.
- [ ] `Smart.getInformation`: `temperature`, `powercycles`, `poweronhours` keys.
- [ ] `Services.getStatus`: `{total,data}` wrapper; item keys `name`, `title`,
      `enabled`, `running`; `title` is localized (do not sort by it for identity).
- [ ] Whether `Smart.getList` hangs on a spun-down drive and how long
      (drives the 30 s receive timeout).

**App-level**
- [ ] OMV UI reachable over plain HTTP and over HTTPS with a self-signed cert
      (Dio rejects invalid TLS by default — confirm the failure message is legible,
      and decide whether to ship an "allow self-signed" toggle or document it).
- [ ] Reverse-proxied OMV behind a path prefix (`/omv/rpc.php`) — decide whether to
      support it or require a root-mounted instance.
- [ ] Phone on Wi-Fi + OMV on the LAN; and over Tailscale (latency on
      `Smart.getList`).

---

## 9. Risks

1. **Slow SMART reads.** `Smart.getList` runs `smartctl` per device. Mitigation:
   separate provider/tab, 30 s receive timeout, spinner copy "Querying disks…".
2. **Non-admin login looks successful.** Mitigation: Test Connection treats
   `role != admin` as failure with an explicit message.
3. **Localized `Services.title`.** Use `name` as the identity key; show `title`.
4. **PHP session accumulation.** Each app launch creates one session; OMV GC reaps
   it. `Test Connection` logs out explicitly; the long-lived client does not (logout
   on app kill is unreliable and would risk killing a session mid-refresh).
5. **Self-signed TLS.** Common on OMV. Out of scope for v1 but must be a conscious
   decision, not a surprise bug report.
6. **Field drift between 7.x point releases.** All parsing is tolerant: unknown keys
   ignored, missing keys → null, `""`/`"-1"` → null, so a renamed field degrades one
   tile instead of blanking a screen.
