# Scanner / Green Lens — Current State

Scope: `lib/features/scanner/` and `lib/core/widgets/in_app_camera_page.dart` in `bluedot_app`, cross-referenced with backend `bluedot_apis/app/api/v1/app/tags.py`.

## Files

- `pages/green_lens_page.dart` — `GreenLensPage`. On `initState`, schedules `_startCapture()` → `openInAppCamera(context, maxImages: 5, title: 'Scan a Tree')`. On success, calls `_runScan(photos)`, which fetches GPS via `Geolocator.getCurrentPosition`, then calls `ref.read(scanResultProvider.notifier).scan(images:, lat:, lng:)`. Pops the route, then calls `_showResultSheet(result)`. Shows `AiAnalyzingOverlay` while `_analyzing` is true.
- `widgets/ai_analyzing_overlay.dart` — cosmetic full-screen loader cycling phrases ("Scanning leaf structure…", "Matching species database…") over a blurred captured photo while the scan request is in flight.
- `widgets/scan_shared_widgets.dart` — `PillTag`, `Co2Card`, `PlantPlaceholder` (shared small widgets).
- `widgets/scan_result_sheet.dart` — `ScanResultSheet`. Shows points badge, thumbnail, species name, pills, `Co2Card`, status message, and a "Save to My Collection & Geotag" CTA. Has a fallback `_buildNotIdentified` branch with a "Try Again" action. Contains a local `_estimateCo2` lookup table mirroring the backend's CO2 estimation.
- `widgets/scan_history_detail_sheet.dart` — `ScanHistoryDetailSheet` (see below).
- `models/scan_result_model.dart` — `ScanResult` (`status, message, treeId, speciesMatched, isNewSpecies, pointsAwarded, totalPoints, assetUrl, plantnetData, species`, with `isNewTag`/`isNotIdentified` getters); `SpeciesInfo` (`id, scientificName, localName, co2OffsetFactor, growthTimeYears, imageUrls, isPendingReview`); `PlantNetData` (`scientificName, commonName, score, family`); `ScanHistoryItem` (`id, imageUrl, imageUrls, lat, lng, taggedAt, plantnetSummary, plantnetData, species`, with `hasLocation` getter).
- `data/scanner_repository.dart` — `scanTree()` (multipart POST to scan endpoint, 75s timeout), `fetchHistory()` (GET to scan history endpoint), `fetchMapTrees()` (GET map bounding box, `requireAuth: false`).
- `providers/scanner_provider.dart` — Riverpod providers (see below).

## Full scan flow

1. **Capture**: `GreenLensPage._startCapture()` calls `openInAppCamera(...)`, which returns a `List<File>` once the user finishes capturing.
2. **Trigger scan**: `_runScan(photos)` sets `_analyzing = true`, retrieves the device's current GPS position, then calls `ref.read(scanResultProvider.notifier).scan(images:, lat:, lng:)`.
3. **Notifier → repository**: `ScanResultNotifier.scan()` clears prior state, then delegates to `ScannerRepository.scanTree(...)`.
4. **Upload**: `ScannerRepository.scanTree()` does a multipart POST to `ApiConfig.scan` (`{baseUrl}/api/v1/app/tags/scan`) with fields `lat`, `lng` and files under field name `images`, 75-second timeout. Response parsed via `ScanResult.fromJson`.
5. **Backend identification**: `scan_tree()` in `tags.py` calls `identify_plant(primary_bytes, db)` → `_extract_identification()`, checks the Tree Encyclopedia and a 5-meter proximity duplicate check, uploads images via `MediaService.upload_files`, creates/updates rows, and awards points — **50 points for a brand-new tree, 15 points for a verified/duplicate match**.
6. **Result display**: `_showResultSheet(result)` opens `ScanResultSheet` as a modal bottom sheet (not a routed page).
7. **"Save" CTA**: this button in `ScanResultSheet` is effectively cosmetic — it just pops the sheet. Actual persistence already happened server-side during step 5's POST. The `onSaved` callback parameter is optional and isn't even passed at the `GreenLensPage` call site.
8. **History**: scan history is fetched on demand (not auto-refreshed after a scan) via `scanHistoryProvider`, which calls `GET /api/v1/app/tags/history`.

## Exact API calls

### `POST {baseUrl}/api/v1/app/tags/scan` (`ApiConfig.scan`)

Backend (`bluedot_apis/app/api/v1/app/tags.py`):
```python
@router.post("/scan")
async def scan_tree(
    lat: float = Form(...),
    lng: float = Form(...),
    images: List[UploadFile] = File(...),
    db: Session = Depends(get_db),
    current_user: AppUser = Depends(get_current_app_user)
):
```
No Pydantic request model — raw `Form`/`File` params. Response shape varies by branch, all raw dicts:
- **not_identified** branch — plant could not be matched.
- **verified** branch — matched an existing/known species, duplicate-proximity logic applies; awards 15 points.
- **new_tag** branch — brand-new tagged tree; awards 50 points.

Each branch includes a species payload (`_species_payload()` helper) with: `id, scientific_name, local_name, co2_offset_factor, growth_time_years, image_urls, is_pending_review`.

### `GET {baseUrl}/api/v1/app/tags/history` (`ApiConfig.scanHistory`)

Backend:
```python
@router.get("/history")
def get_tag_history(skip: int = 0, limit: int = 20, db: Session = Depends(get_db), current_user: AppUser = Depends(get_current_app_user)):
```
Response envelope: `{"count": ..., "data": [...]}`. Each item: `id, species_id, image_url, image_urls, lat, lng, tagged_at, plantnet_data_summary, plantnet_data, species`.

There's also a `GET /api/v1/app/tags/map` route (bounding-box query) backing `fetchMapTrees()`, used by the map/Eco Garden feature, not by the scan flow itself.

**Backend auth caveat**: `get_current_app_user` in `tags.py` is explicitly commented as a `"Mock dependency for getting the current app user"` — `"In a real scenario, this would decode a JWT or verify a session."` It currently just queries the first active `AppUser` row in the database. This means all scan/scan-history calls are not actually scoped to the authenticated device user on the backend yet — worth flagging if this doc is read in the context of security/auth review.

## Riverpod providers

- `scannerRepositoryProvider` — `Provider<ScannerRepository>`
- `scanResultProvider` — `NotifierProvider<ScanResultNotifier, ScanResult?>`; exposes `.scan(images:, lat:, lng:)` and `.clear()`
- `scanHistoryProvider` — `FutureProvider<List<ScanHistoryItem>>`
- `mapTreesProvider` — `FutureProvider<List<ScanHistoryItem>>`; uses a fixed bounding box (`_bangaloreBoxDegrees = 0.3`) and filters out items whose species `isPendingReview` is true

No dedicated provider was found for raw camera state, zoom, or upload progress — camera/zoom state lives locally inside `InAppCameraPage`'s `State` (see below), and upload progress isn't tracked beyond the binary "analyzing" boolean in `GreenLensPage`.

## In-app camera widget (`lib/core/widgets/in_app_camera_page.dart`)

Confirmed: pinch-to-zoom and a vertical zoom slider both exist.

- Zoom state: local `double` fields `_minZoom`, `_maxZoom`, `_zoom`, `_baseZoom`.
- Pinch-to-zoom gesture:
  ```dart
  child: GestureDetector(
    onScaleStart: (_) => _baseZoom = _zoom,
    onScaleUpdate: (details) => _setZoom(_baseZoom * details.scale),
  ```
- `_setZoom()` clamps the value between `_minZoom`/`_maxZoom` and calls `controller.setZoomLevel(clamped)`.
- Vertical slider: rendered only if `_maxZoom > _minZoom`, implemented as `_ZoomSlider`, which wraps a standard horizontal `Slider` inside `RotatedBox(quarterTurns: 3, ...)` to present it vertically.

**Shared usage confirmed** — `openInAppCamera()` is called from two distinct flows:
- `lib/features/scanner/pages/green_lens_page.dart`: `openInAppCamera(context, maxImages: 5, title: 'Scan a Tree')`.
- `lib/features/action_hub/pages/suggest_site_page.dart`: `openInAppCamera(context, maxImages: remaining, title: 'Photograph the Site')`.

So the same camera widget (with the same pinch-to-zoom/slider UX) backs both Green Lens tree scanning and the Action Hub's Suggest Site photo capture — single shared implementation, not duplicated per-feature.

## Scan history UI

The scan history list itself lives in the **Profile** feature, not inside `lib/features/scanner/`: `lib/features/profile/pages/profile_page.dart`, widget `_ScansHistory`.

- Header: "Recent Scans".
- Empty state: camera icon + "No scans yet! Use the Green Lens to identify plants."
- List: `ListView.separated`, capped to the first 5 items (`items.take(5)`).
- Each row computes `isPendingReview`, a scientific/common-name fallback chain, a primary label, and a secondary label (date + scientific name), shows a thumbnail plus labels.
- Tapping a row opens `ScanHistoryDetailSheet` via `showModalBottomSheet`.

### `ScanHistoryDetailSheet` (shared component — confirmed)

Location: `lib/features/scanner/widgets/scan_history_detail_sheet.dart`.

Takes a `ScanHistoryItem`. Renders a rounded bottom sheet capped at 90% height, containing:
- `CachedNetworkImage` thumbnail (180×220) with skeleton/placeholder fallback states.
- Scientific name (italic) and common name.
- A `Wrap` of `PillTag`s showing match percentage, family, and an approval-status pill (pending vs. approved).
- A `Co2Card` if the CO2 value is greater than 0.
- A "Tagged on {date}" footer.

**Confirmed shared with the map feature**: used in two places:
1. `lib/features/profile/pages/profile_page.dart` — Recent Scans row tap.
2. `lib/features/map/pages/eco_garden_page.dart` — `_showTreeDetail(item)`, opened from map marker taps.

## Navigation routes

Only one router entry exists for the scanner feature: `lib/core/router/app_router.dart`:
```dart
GoRoute(path: '/scanner', builder: (__, _) => const GreenLensPage()),
```
There are no separate routes for scan history or the result/detail sheets — both `ScanResultSheet` and `ScanHistoryDetailSheet` are presented as modal bottom sheets, not pushed as distinct routes.

## TODO / demo / mock comments found

No "TODO", "FIXME", "mock", "demo", "not yet", or "hardcoded" comments were found anywhere in `lib/features/scanner/` (the Flutter side appears fully wired to the real backend — there is no `DemoData` usage in this feature at all). The one genuine "mock" note found during cross-referencing is on the **backend**: `tags.py`'s `get_current_app_user` dependency, explicitly commented as a mock auth stand-in (see auth caveat above) — this is a backend file, not part of the Flutter scanner feature, but is relevant context for anyone evaluating how "real" the scan flow's auth actually is end-to-end.
