# Beakarr

A Flutter app for managing your self-hosted media stack from anywhere.
One client for **Seerr**, **Radarr**, **Sonarr**, **Lidarr**, **Prowlarr**,
**Bazarr**, **Navidrome**, **SoulSync** and **qBittorrent** on Android and iOS —
with **Authentik single sign-on** across the *arr fleet, so one login covers
every service instead of an API key per box.

![Flutter](https://img.shields.io/badge/Flutter-3.38.7-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-%5E3.10.0-0175C2?logo=dart)
![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20iOS-informational)
![License](https://img.shields.io/badge/license-MIT-green)
![Latest release](https://img.shields.io/github/v/release/wetw0rks-c0ding/Beakarr?include_prereleases)

## Table of Contents

- [Screenshots](#screenshots)
- [Features](#features)
- [Getting Started](#getting-started)
  - [Prerequisites (for building from source)](#prerequisites-for-building-from-source)
  - [Installation](#installation)
- [Configuration](#configuration)
- [Platform-specific Install](#platform-specific-install)
- [Architecture](#architecture)
- [Contributing](#contributing)
- [About this project](#about-this-project)
- [Support](#support)
- [License](#license)

---

## Screenshots

### Services
<p align="center">
  <img src="screenshots/services.png" width="300" alt="Services screen" />
  <img src="screenshots/services_dark.png" width="300" alt="Services dark screen" />
  <img src="screenshots/services_list.png" width="300" alt="Services list screen" />
  <img src="screenshots/seerr.png" width="300" alt="Seerr screen" />
  <img src="screenshots/sonarr.png" width="300" alt="Sonarr screen" />
  <img src="screenshots/sonarr_dark.png" width="300" alt="Sonarr dark screen" />
  <img src="screenshots/qbit.png" width="300" alt="qbittorrent screen" />
</p>

### Media Details
<p align="center">
  <img src="screenshots/seerr_media_detail.png" width="300" alt="Seerr details screen" />
  <img src="screenshots/radarr_media_detail.png" width="300" alt="radarr details screen 2" />
</p>

### Activity Management
<p align="center">
  <img src="screenshots/activity.png" width="300" alt="Activity screen" />
  <img src="screenshots/history.png" width="300" alt="History screen" />
</p>

### Search, Import & Settings
<p align="center">
  <img src="screenshots/search.png" width="300" alt="search screen" />
  <img src="screenshots/search_dark.png" width="300" alt="search dark screen" />
  <img src="screenshots/manual_import.png" width="300" alt="manual import screen" />
  <img src="screenshots/manual_import_dark.png" width="300" alt="manual import dark screen" />
  <img src="screenshots/settings.png" width="300" alt="settings screen" />
</p>

---

## Features

- **Discover** — Browse trending movies and TV shows via Seerr
  - Three horizontal carousels: Trending / Movies / TV, with a unified search across both
  - Rich detail page: TMDB + external ratings, region-aware watch providers and content ratings, cast, collections, keywords, and playable trailers
  - TV detail surfaces season/episode lists; both movies and TV show studios, networks, directors, writers, and release info
  - Actions: add to your *arr library, send a Seerr request, run an interactive search, or manage existing media (delete from Radarr/Sonarr, clear data)
- **Movies** — Your Radarr library in your pocket
  - Browse the full library with status badges (file, monitoring, queued), pull-to-refresh, and search
  - Detail page with ratings, file info, quality profile, and genres
  - Actions: auto and interactive search, toggle monitored, change quality profile, manual import, delete (with optional file removal and import exclusion)
- **TV Series** — Manage your Sonarr series library
  - Everything Movies does, plus a season list with episodes and per-season / per-episode search
  - Status badges show `episodeFileCount / episodeCount` at a glance
- **Music** — Manage your Lidarr music library
  - Everything Movies does, plus a per-artist album list
  - Circular artist posters and album/file counts in status badges
- **Torrents** — Manage qBittorrent torrents from anywhere
  - Status filter chips (all / downloading / seeding / completed / paused / queued), category / tag / tracker pills, and a free-text search field, all in the filter row
  - Sort by name, size, progress, ETA, download/upload speed, added date, or state (with reverse toggle)
  - Detail screen with **Info / Files / Trackers / Actions** tabs and 3s live polling
  - Mutate: pause, resume, force-start, force-recheck, reannounce, set per-torrent speed limits, edit category and tags, delete (with optional file removal)
  - Polished with the shared design-token system (`AppSpacing`, `AppRadius`, `AppAnimation`)
- **Search** — Cross-service search with always-visible search bars
- **Activity** — Comprehensive task monitoring
  - Queue, History, and Blocklist with sticky segmented navigation and full pagination
  - Wanted: Missing and Cutoff Unmet with status text and pagination
  - Queue status normalization based on structured fields
  - Sonarr wanted items organized by Series → Season → Episode with per-episode search
- **Customization** — Light, Dark, or System theme; configurable navigation bar services
- **Multiplatform** — Tested on Android and iOS (sideloaded iOS via TrollStore)
- **Prowlarr** — Indexer management plus release search with a grab sheet
- **Bazarr** — Subtitle management for series and movies
- **Navidrome** — Music streaming via Subsonic API
- **SoulSync** — Requests, discovery and downloads with Authentik cookie SSO
- **Single sign-on** — One Authentik login covers Sonarr, Radarr and
  Prowlarr (short-lived service tokens minted per host, refreshed and
  cached automatically), with cookie sessions for SoulSync. The
  Auth/SSO settings screen shows a live per-service status dot:
  green = connected, orange = connecting/error, red = no connection.
  API keys keep working side-by-side and remain the fallback everywhere
- **Backup & restore** — Password-encrypted backup of the whole config
  (URLs, keys, issuer) to a portable file; restore after reinstalls,
  device swaps, or the app rename migration

---

## Getting Started

> **Just want to use the app?** Skip ahead to [Platform-specific Install](#platform-specific-install) — download the right file for your platform from [Releases](https://github.com/wetw0rks-c0ding/Beakarr/releases) and install it. No prerequisites.

### Prerequisites (for building from source)

- Flutter SDK compatible with Dart `^3.10.0` (CI uses Flutter 3.38.7)
- For **iOS**: Xcode (latest stable) for macOS builds; Linux cross-compiles IPAs with `xcross`
- For **Android**: Android Studio + Android SDK (compileSdk 36)
- At least one running self-hosted service: Seerr, Radarr, Sonarr, Lidarr, Prowlarr, or qBittorrent

### Installation

```bash
git clone https://github.com/wetw0rks-c0ding/Beakarr.git
cd seekarr
flutter pub get
flutter run
```

---

## Configuration

Beakarr ships with no default credentials. After launching the app, open **Settings** and configure each service you want to use:

- **Seerr** — Base URL + API key
- **Radarr** — Base URL + API key
- **Sonarr** — Base URL + API key
- **Lidarr** — Base URL + API key
- **Prowlarr** — Base URL + API key
- **Bazarr** — Base URL + API key
- **Navidrome** — Base URL + Username + Password (Subsonic auth)
- **SoulSync** — Base URL + API key, or Authentik cookie SSO
- **qBittorrent** — Base URL + Username + Password (uses qB's WebUI v2 form login; no API key)
- Region preferences (where applicable)

API keys are stored securely on the device using `flutter_secure_storage` and are never transmitted outside your local network.

### Authentik SSO (optional, recommended)

Point **Settings → Authentication** at your Authentik issuer (or tap
**Use ArrStack preset**) and log in once: Sonarr, Radarr and Prowlarr
then authenticate with short-lived per-host service tokens instead of
static keys, and SoulSync uses a cookie session. The SSO dots show each
service's live state. API keys stay as fallback — leave them in, take
them out, or mix per service.

---

## Platform-specific Install

| Platform | Status | Distribution |
| --- | --- | --- |
| Android | ✅ Supported | `.apk` from [Releases](https://github.com/wetw0rks-c0ding/Beakarr/releases) |
| iOS | ✅ Supported (sideload) | Unsigned `.ipa` from [Releases](https://github.com/wetw0rks-c0ding/Beakarr/releases) |
| macOS | ✅ Supported | `.dmg` from [Releases](https://github.com/wetw0rks-c0ding/Beakarr/releases) |
| Web / Linux / Windows | ⚠️ Scaffolding only | Build from source, not officially tested |

### Android

Download the `.apk` file from the [Releases](https://github.com/wetw0rks-c0ding/Beakarr/releases) page and install it on your device (you may need to allow installs from unknown sources).

### macOS

Download the `.dmg` file from the [Releases](https://github.com/wetw0rks-c0ding/Beakarr/releases) page, drag Seekarr to `/Applications`, and launch it. On first run, right-click the app and choose **Open** to bypass Gatekeeper.

### iOS

Download the unsigned `.ipa` from the [Releases](https://github.com/wetw0rks-c0ding/Beakarr/releases) page and sideload it with one of the standard tools:

- **[AltStore](https://altstore.io/)** — refreshes over Wi-Fi on the same machine
- **[Sideloadly](https://sideloadly.io/)** — desktop tool, no account needed on macOS
- **[Sideload](https://sideload.app/)** — web-based, runs in your browser

The `.ipa` is **not signed by Apple**, so it has to be installed through one of the tools above (they apply an ad-hoc signature on install). The signature expires and the app needs to be re-installed periodically:

- **Free Apple ID** — 7 days
- **Paid Apple Developer account** — 1 year

<details>
<summary>Build from source</summary>

If you'd rather build the iOS app yourself, clone the repo and run:

```bash
flutter build ios --no-codesign
```

Then open the resulting `.app` in Xcode and run it on your device or simulator.

</details>

### Web, Linux, Windows

Project scaffolding for these platforms exists, but they are **not officially tested or supported**.  
Contributions to improve support on these platforms are welcome.

---

## Architecture

Beakarr follows a **feature-first layered architecture**:

```
lib/
├── core/           # Shared infrastructure: theme, routing, API client, reusable widgets
└── features/
    ├── <feature>/
    │   ├── data/         # Services and API calls
    │   ├── domain/       # Models
    │   └── presentation/ # Screens, providers, widgets
    ├── activity/
    ├── discover/
    ├── movies/
    ├── music/
    ├── qbittorrent/
    ├── search/
    ├── series/
    └── settings/
```

**Key technical choices:**

| Concern            | Library                                |
| ------------------ | -------------------------------------- |
| UI framework       | Flutter 3.x + Material 3               |
| State management   | Riverpod 3                             |
| Navigation         | go_router 17                           |
| HTTP               | Dio (+ cookie manager for qBittorrent) |
| Image caching      | cached_network_image                   |
| SVG                | flutter_svg                            |
| Dynamic color      | dynamic_color                          |
| Secure storage     | flutter_secure_storage                 |
| Settings storage   | shared_preferences                     |
| Pagination         | infinite_scroll_pagination             |
| URL launching      | url_launcher                           |
| In-app purchase    | in_app_purchase                        |
| File picking       | file_picker                            |

**Goals:** readability, modularity, and reusable UI components built on a consistent design token system (`AppSpacing`, `AppRadius`, `AppAnimation`).

---

## Contributing

Contributions are very welcome.

If you want to work on a change, please **open an issue first** to discuss scope and direction before implementation. I review PRs and issues in my spare time and will get to them as soon as I can.

For setup notes, conventions, and pull request expectations, see [CONTRIBUTING.md](CONTRIBUTING.md).

---

## About this project

Beakarr was born from a personal need: flawlessly managing a self-hosted *arr stack from a phone, from anywhere. It is built with a focus on getting the details right — polished interactions, honest error and empty states, and a test suite that keeps them that way — rather than on shipping fast.

Beakarr started as a fork of [Seekarr by matthw-labs](https://github.com/matthw-labs/seekarr) and has since become its own product: single sign-on across the fleet, Prowlarr/Bazarr/Navidrome/SoulSync support, encrypted config backup, and its own brand. Upstream remains credited under the MIT license; none of its infrastructure is used.

Beakarr is written primarily with AI coding agents under human direction — every feature is specified, device-tested, and reviewed before release. See `docs/project-log/` for the per-release record.

---

## Support

If you find Beakarr useful, star the repo and open issues for bugs you hit on device — device-tested reports with steps to reproduce get fixed first.

---

## License

This project is licensed under the **[MIT License](LICENSE)**.
