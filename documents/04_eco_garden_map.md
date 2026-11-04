# 04 — Eco Garden Map — Engineering Reference

**Status:** 100% Complete & Fully Integrated  
**Last Updated:** 2026-11-04  
**Primary Endpoint:** `GET /api/v1/app/tags/map`  
**Cross-Reference:** [10_database_schema_trees.md](10_database_schema_trees.md) for PostGIS spatial indexing and bounding-box queries.

---

## 1. Overview

The Eco Garden Map is BlueDot's geospatial visualization feature. It renders an interactive map displaying all community-tagged trees across the region, user location tracking ("Blue Dot"), dynamic tree filtering, and quick-action detail bottom sheets.

### Source Files
- `lib/features/map/pages/eco_garden_page.dart` — Main map page using `flutter_map` (OpenStreetMap tiles).
- `lib/features/scanner/providers/scanner_provider.dart` — `mapTreesProvider` supplying verified map trees.
- `lib/features/scanner/data/scanner_repository.dart` — `fetchMapTrees()` querying the geospatial bounding box.
- `lib/features/scanner/models/scan_result_model.dart` — `ScanHistoryItem` representing geotagged trees.
- `lib/features/scanner/widgets/scan_history_detail_sheet.dart` — Shared tree inspection sheet.

---

## 2. Geospatial Architecture & Data Flow

### 1. Data Source (Community-Wide Trees)
`ScannerRepository.fetchMapTrees()` issues a public `GET /api/v1/app/tags/map` query:
```dart
await _api.get(ApiConfig.mapData, requireAuth: false, query: {
  'min_lat': minLat.toString(),
  'min_lng': minLng.toString(),
  'max_lat': maxLat.toString(),
  'max_lng': maxLng.toString(),
});
```

On the backend (`bluedot_apis/app/api/v1/app/tags.py: get_tags_map`):
- Constructs a PostGIS bounding box polygon from `min_lat`, `min_lng`, `max_lat`, `max_lng`.
- Queries `TaggedTree` records overlapping the bounding box using PostGIS spatial indexing (`&&` operator).
- Eager-loads species information (`selectinload(TaggedTree.species)`).
- **Public/Community Scope:** No `user_id` filter is applied; the map displays all trees tagged by any user across the community.

### 2. Client-Side Pending Review Filter
In `scanner_provider.dart`:
```dart
final mapTreesProvider = FutureProvider<List<ScanHistoryItem>>((ref) async {
  final trees = await ref.watch(scannerRepositoryProvider).fetchMapTrees(
        minLat: bangaloreCenterLat - _bangaloreBoxDegrees,
        minLng: bangaloreCenterLng - _bangaloreBoxDegrees,
        maxLat: bangaloreCenterLat + _bangaloreBoxDegrees,
        maxLng: bangaloreCenterLng + _bangaloreBoxDegrees,
      );
  // Keep pending review tags off the public map until approved
  return trees.where((t) => t.species?.isPendingReview != true).toList();
});
```
Trees whose species are awaiting administrative review (`isPendingReview == true`) are filtered out on the client to ensure only verified trees appear publicly.

---

## 3. UI Features & Controls

### 1. Map Coordinates & Centering
- Default center: Bangalore coordinates (`12.9716, 77.5946`) with a bounding box of `± 0.3°` (~30 km radius).
- On initialization, requests `Permission.locationWhenInUse`.
- If granted, retrieves high-accuracy GPS coordinates via `Geolocator.getCurrentPosition()` and centers the map on the user.
- If permission is denied or times out, safely falls back to the Bangalore center.

### 2. User Live Location Marker ("Blue Dot")
- Rendered as a pulsing, layered marker:
  - Outer ring: 26×26 translucent circle (`AppColors.primaryBlue` with 60 alpha)
  - Inner core: 14×14 solid circle (`AppColors.primaryBlue` with 2px white border)
  - Wrapped in `IgnorePointer` to prevent accidental gesture blocking.

### 3. Tree Pins & Detail Popups
- Each verified tree renders as a green botanical marker icon.
- Tapping a pin highlights it and presents a floating `_TreeInfoCard` at the bottom of the viewport showing:
  - Tree thumbnail image
  - Common and scientific name
  - Tagged date
- Tapping the `_TreeInfoCard` opens the modal `ScanHistoryDetailSheet` with full botanical facts and CO₂ absorption stats.

### 4. Interactive Layer Toggle
- A floating toggle button (`_LayerToggle`, top-right) allows users to hide/show the tree markers layer without re-fetching data.

### 5. Zoom & Manual Refresh Controls
- Floating `+` and `-` buttons clamped between zoom levels `4.0` and `20.0`.
- Manual Refresh button (`Icons.refresh_rounded`) invalidates `mapTreesProvider` and triggers a smooth re-fetch with custom skeleton placeholders.

### 6. Dynamic Bottom Stats Bar
- **Tagged Trees:** Shows total count of community trees visible in the area.
- **Your Trees:** Dynamically calculates `trees.where((t) => t.userId == currentUser.id).length` using `currentUserProvider`. Updates live without page reload.

---

## 4. Navigation

Registered as a top-level route outside the bottom navigation shell:
```dart
GoRoute(path: '/map', builder: (__, _) => const EcoGardenPage())
```
Can be accessed from:
- Profile page (map action icon)
- Home page quick actions
- Direct route navigation (`context.push('/map')`)
