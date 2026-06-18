# Eco Garden Map — Current State

> Documented by reading the live source on 2026-06-18. The map feature was recently and heavily modified; everything below was re-verified against the current code (not carried over from any earlier description).

## Files read

- `lib/features/map/pages/eco_garden_page.dart` — the page/UI (only file under `lib/features/map/`; there is no separate `providers/`, `models/`, or `repositories/` subfolder for the map feature — those live in the `scanner` feature and are reused)
- `lib/features/scanner/providers/scanner_provider.dart` — `mapTreesProvider`, Bangalore constants
- `lib/features/scanner/data/scanner_repository.dart` — `fetchMapTrees`
- `lib/features/scanner/models/scan_result_model.dart` — `ScanHistoryItem`, species payload shape
- `lib/features/scanner/widgets/scan_history_detail_sheet.dart` — the detail sheet opened from the map
- `lib/core/config/api_config.dart` — `mapData` endpoint constant
- `lib/core/router/app_router.dart` — route registration
- Backend: `bluedot_apis/app/api/v1/app/tags.py` — `GET /map` handler

## Data source — confirmed all-community trees, not just current user's

`ScannerRepository.fetchMapTrees()` (`scanner_repository.dart` lines 44-66) calls:

```dart
await _api.get(ApiConfig.mapData, requireAuth: false, query: {
  'min_lat': minLat.toString(),
  'min_lng': minLng.toString(),
  'max_lat': maxLat.toString(),
  'max_lng': maxLng.toString(),
});
```

`ApiConfig.mapData` = `$_app/tags/map` → `GET /api/v1/app/tags/map`.

On the backend, `tags.py` `get_tags_map` (lines 285-328) takes optional `min_lat, min_lng, max_lat, max_lng` query params, and when all four are present filters with a PostGIS bbox-overlap (`&&`) against a constructed `POLYGON(...)` — confirming a **bounding-box query**, not lat/lng/radius. Critically, the query is:

```python
query = db.query(TaggedTree).options(selectinload(TaggedTree.species))
```

with **no `user_id` filter at all** — it returns every `TaggedTree` row in the bbox regardless of which user tagged it. This confirms the map fetches **all community-tagged trees**, not just the current user's. The call is also made with `requireAuth: false` on the client side, consistent with this being a public/community endpoint.

### Response shape per tree (from `tags.py` `get_tags_map`)

```json
{
  "count": <int>,
  "data": [
    {
      "id": ...,
      "lat": <float>,
      "lng": <float>,
      "species_id": ...,
      "species": {
        "id": ..., "scientific_name": ..., "local_name": ...,
        "co2_offset_factor": <float|null>, "growth_time_years": ...,
        "image_urls": [...], "is_pending_review": <bool>
      },
      "plantnet_data": {...},
      "image_url": <string|null>,
      "tagged_at": <timestamp>
    }, ...
  ]
}
```

`is_pending_review` is set as `species.status == TreeSpecies.STATUS_PENDING_REVIEW` (`_species_payload`, line 35).

The Flutter side parses this into `ScanHistoryItem` (`scan_result_model.dart`) via `.fromJson`, then `fetchMapTrees` filters out items lacking coordinates: `.where((item) => item.hasLocation)`.

## Pending-review filtering — confirmed

`mapTreesProvider` (`scanner_provider.dart` lines 34-44):

```dart
final mapTreesProvider = FutureProvider<List<ScanHistoryItem>>((ref) async {
  final trees = await ref.watch(scannerRepositoryProvider).fetchMapTrees(
        minLat: bangaloreCenterLat - _bangaloreBoxDegrees,
        minLng: bangaloreCenterLng - _bangaloreBoxDegrees,
        maxLat: bangaloreCenterLat + _bangaloreBoxDegrees,
        maxLng: bangaloreCenterLng + _bangaloreBoxDegrees,
      );
  // Species still awaiting admin review aren't confirmed yet -- keep them
  // off the public map until approved.
  return trees.where((t) => t.species?.isPendingReview != true).toList();
});
```

Confirmed: trees whose `species.isPendingReview == true` are filtered out **client-side**, after the backend fetch, before the page ever sees them. (Backend `tags.py` itself does not filter on review status — the filter is purely on the Flutter side in this provider.)

## Map centering and bounding box — confirmed Bangalore constants

In `scanner_provider.dart` (lines 28-32):

```dart
// Bangalore bounding box (~30km around the city center) used to scope the
// Eco Garden map to trees tagged in and around Bangalore.
const bangaloreCenterLat = 12.9716;
const bangaloreCenterLng = 77.5946;
const _bangaloreBoxDegrees = 0.3;
```

So the bbox sent to the backend is `[12.9716 ± 0.3, 77.5946 ± 0.3]`, i.e. roughly `12.6716–13.2716` lat by `77.2946–77.8946` lng (comment calls this "~30km around the city center").

In `eco_garden_page.dart` (line 28): `static const _bangaloreCenter = LatLng(bangaloreCenterLat, bangaloreCenterLng);` — reuses the same constants for the map's visual center.

### Location-permission fallback — confirmed

`_loadMyLocation()` (lines 40-53):

```dart
final permission = await Permission.locationWhenInUse.request();
if (!permission.isGranted) return;
final position = await Geolocator.getCurrentPosition(
  locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 5)),
);
if (mounted) setState(() => _myLocation = LatLng(position.latitude, position.longitude));
```

If permission is denied, the method simply `return`s early — `_myLocation` stays `null`. The `FlutterMap`'s `initialCenter` is `_myLocation ?? _bangaloreCenter` (line 98), so denial/failure of any kind (permission denied, or an exception caught by the surrounding `try/catch`, e.g. timeout) **confirmed to fall back to the Bangalore center**. A full-screen `CircularProgressIndicator` (`AppColors.primaryBlue`) is shown until `_locationResolved` becomes true (set in the `finally` block), so the map only renders once location resolution (success or failure) has completed.

## User's live location marker — confirmed

Rendered only `if (_myLocation != null)` (lines 161-188): a 26×26 `Marker` containing a translucent outer circle (`AppColors.primaryBlue.withAlpha(60)`) and a solid 14×14 inner circle (`AppColors.primaryBlue`, white 2px border) — a standard "blue dot" you-are-here style, wrapped in `IgnorePointer` (not tappable).

## Zoom — confirmed

`MapOptions` (lines 97-103):

```dart
initialZoom: 11.5,
minZoom: 4,
maxZoom: 20,
```

No explicit `interactionOptions` are set, so `flutter_map`'s default interaction flags apply, which include pinch-to-zoom (drag/pinch gestures are enabled by default unless overridden) — confirmed pinch gesture is not disabled anywhere in this file.

Explicit +/- buttons exist (`_MapButton` with `Icons.add_rounded` / `Icons.remove_rounded`, lines 240-253), wired to `_zoomBy(1)` / `_zoomBy(-1)`:

```dart
void _zoomBy(double delta) {
  final camera = _mapController.camera;
  final nextZoom = (camera.zoom + delta).clamp(4.0, 20.0);
  _mapController.move(camera.center, nextZoom);
}
```

Confirmed the button-driven zoom is clamped to the same `4.0`–`20.0` range as `minZoom`/`maxZoom`.

## Tapping a tree pin — confirmed

Tapping a marker sets `_selectedMarkerIndex` (line 126), which renders a `_TreeInfoCard` (an info pill/popup, positioned bottom:150, lines 268-278) showing the tree's image (or a fallback icon), display name (`species.localName` → `species.scientificName` → `plantnetData.commonName` → `plantnetData.scientificName` → `'Unidentified plant'`), and tagged date.

Tapping that card (`onTap: () => _showTreeDetail(...)`, line 276) calls `_showTreeDetail`, which opens:

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => ScanHistoryDetailSheet(item: item),
);
```

Confirmed `ScanHistoryDetailSheet` lives at `lib/features/scanner/widgets/scan_history_detail_sheet.dart` and is a shared widget (also used from the Profile page's Recent Scans list, per its doc comment). It displays: the tree's image (`CachedNetworkImage` with skeleton placeholder and `PlantPlaceholder` error fallback), scientific name (italic) and common name, a "% Match" pill (from `plantnetData.score`) if present, a family pill if present, an **Approval status pill** — `'Pending review'` (amber, hourglass icon) if `species.isPendingReview == true`, else `'Approved'` (green, check icon) — a CO2 offset card (`Co2Card`) if `co2OffsetFactor > 0`, and the formatted tagged date.

## Bottom stats bar — confirmed

`_StatsBar` (lines 339-371), fed `treeCount: trees.length` where `trees` is the (already pending-review-filtered) list from `mapTreesProvider`:

- **"Tagged Trees"** — shows `'$treeCount'`, a **real count** derived from the API data (length of the filtered community-trees list).
- **"Your Trees"** — hardcoded to `'0'`. Confirmed by an explicit TODO directly above it (lines 360-362):

```dart
// TODO: wire to the user's own tagged-tree count once that flow
// exists (the map currently only fetches community trees, not
// per-user ones) -- placeholder at 0 until then.
const Expanded(
  child: Center(
    child: _StatItem(icon: Icons.park_rounded, value: '0', label: 'Your Trees', color: AppColors.primaryYellow),
  ),
),
```

## Riverpod providers used

- `mapTreesProvider` (`FutureProvider<List<ScanHistoryItem>>`, defined in `scanner_provider.dart`) — fetches + filters the map's tree list. Watched in `eco_garden_page.dart` via `ref.watch(mapTreesProvider)`.
- `scannerRepositoryProvider` (`Provider<ScannerRepository>`) — the underlying repository used by `mapTreesProvider`.

No map-specific provider file exists; the map page reuses scanner-feature providers/models entirely.

## Navigation route

Registered in `app_router.dart`: `GoRoute(path: '/map', builder: (__, _) => const EcoGardenPage())` (top-level route, not nested under a shell). The page itself navigates back via `context.pop()`.

## Other gaps / TODOs found

A repo-wide search of the map feature folder and the scanner provider/repository/detail-sheet files for "TODO", "demo", "mock", "not yet" found exactly one hit:

- The "Your Trees" hardcoded-0 TODO described above (`eco_garden_page.dart` line 360). No other TODO/demo/mock markers were found in `lib/features/map/`, `scanner/providers/`, or `scan_history_detail_sheet.dart`.

## Layer toggle (incidental finding)

There is also a "Tagged Trees" layer toggle (`_LayerToggle`, top-right, `_showTrees` bool) that lets the user hide/show the tree `MarkerLayer` entirely — unrelated to the bottom stats bar's "Tagged Trees" label, which always shows the count regardless of toggle state.
