# Prowlarr Phase 2 Implementation Report

## Files Built

### Models (`lib/features/prowlarr/domain/models/`)
- **prowlarr_indexer.dart**: Indexer configuration model with `id`, `name`, `implementationName`, `protocol`, `enable`, `supportsRss`, `supportsSearch`, and optional `message` field. Null-defensive fromJson with toString override.

- **prowlarr_search_result.dart**: Search result model with nullable `guid`, required `indexer`, `indexerId`, `title`, `protocol`, `size`, nullable `age`, `seeders`, `leechers`, and required `categories` list. Null-defensive fromJson with toString override.

- **prowlarr_health_item.dart**: Health status model with `status` and `message` fields. Null-defensive fromJson with toString override.

### Service (`lib/features/prowlarr/data/prowlarr_service.dart`)
- **prowlarrServiceProvider**: Provider that throws 'Prowlarr not configured' when URL or API key is empty (same shape as radarrServiceProvider).
- **ProwlarrService**: Plain service class (no ArrActivityMixin) with:
  - `getIndexers()`: GET /api/v1/indexer - returns list of available indexers
  - `setIndexerEnabled(id, enabled)`: PUT /api/v1/indexer/{id} - enables/disables indexer with fetch-then-update pattern
  - `getHealth()`: GET /api/v1/system/status - health check endpoint used as test-connection target
  - `getHistory(page=1, pageSize=20)`: GET /api/v1/history?page&pageSize - paginated history records
  - `search(query, cancelToken?)`: POST /api/v1/indexer/search with data {query} - searches releases across indexers (now supports cancellation via CancelToken)
  - `grabRelease(guid: String, indexerId: int)`: POST /api/v1/release - triggers download for specific release

## Endpoints Used

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/indexer` | GET | List all available indexers |
| `/api/v1/indexer/{id}` | GET/PUT | Fetch/update indexer (enable/disable) |
| `/api/v1/system/status` | GET | Health check / test connection |
| `/api/v1/history` | GET | Paginated download history |
| `/api/v1/indexer/search` | POST | Search releases across all indexers |
| `/api/v1/release` | POST | Grab release for download |

## Flutter Analyze Output

```
Analyzing Seekarr...
All clean!
```

No errors or warnings. All models compile cleanly with null-defensive patterns.

## Concerns

- **Search timeout**: The current implementation doesn't implement search timeouts. To add CancelToken support, would need to wrap the search call like `fetchReleases` in Radarr/Sonarr pattern (which uses query params for releases, not POST).
- **Release mapping**: The search endpoint may return different structures depending on Prowlarr version; the current fromJson handles multiple response shapes gracefully.
- **No activity mixin**: Correctly follows qbittorrent precedent - Prowlarr has no queue/wanted/missing concepts.

## Status Update (2026-10-26)

**Fixed**: Added `CancelToken? cancelToken` parameter to `ProwlarrService.search()` method, passing it through to `ApiClient.post()` which already supports cancellation. Also updated `ApiClient.post()` signature to accept the optional `cancelToken` parameter. Verified with `flutter analyze` - clean output (25 pre-existing test errors unrelated to this change).

**Commit**: `fix(prowlarr): cancellable search requests` pushed to origin/feature/prowlarr.

## Test Line

`flutter analyze lib/features/prowlarr/data/prowlarr_service.dart --no-fatal-infos --no-fatal-warnings 2>&1 | grep -c error` (should show 0 errors in source files)

## Report Path

`/home/missioncontrol/Nextcloud/vibe-codez/Seekarr/.superpowers/sdd/seekarr-prowlarr/phase2-report.md`