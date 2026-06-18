# 08 — Directory (Botanical/Tree Species Encyclopedia)

## 1. Overview

Files involved (all under `c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_app\lib\features\directory\`):

- `models\species_model.dart` — `TreeSpecies` data model + `fromJson`
- `data\directory_repository.dart` — `DirectoryRepository`, `directoryRepositoryProvider`
- `providers\directory_provider.dart` — `searchQueryProvider`, `speciesListProvider`, `speciesDetailProvider`
- `pages\directory_page.dart` — grid/list UI with search bar
- `pages\species_detail_page.dart` — detail page UI

Cross-referenced:
- `c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_app\lib\core\demo\demo_data.dart` (lines 242+, `DemoData.species`)
- `c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_app\lib\core\config\api_config.dart` (line 72, `trees` constant)
- `c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_apis\app\api\v1\admin\operations.py` (lines 445–461, `GET /trees` route)
- `c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_app\lib\core\router\app_router.dart` (lines 90–99)
- `c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_app\lib\features\navigation\main_navigation.dart` (lines 10, 38)

## 2. Tree species directory/encyclopedia UI

`directory_page.dart` (`DirectoryPage`) renders a `CustomScrollView` with:
- A `SliverAppBar` titled "Botanical Directory" with an embedded search `TextField` in its `bottom` slot.
- A `SliverGrid` using `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, childAspectRatio: 0.78)` — extent-based so tablets get more columns (comment at line 78–79).
- Each grid cell is a `_SpeciesCard` showing:
  - Thumbnail image (`CachedNetworkImage` from `species.thumbnailUrl`, fallback `_PlaceholderImage` with an eco icon)
  - `localName` (bold, 1 line, ellipsis)
  - `scientificName` (italic, smaller, grey)
  - CO₂ offset badge: `'${species.co2OffsetFactor.toStringAsFixed(1)} kg CO₂/yr'` with a cloud icon

Loading state uses `SkeletonGrid(count: 8, childAspectRatio: 0.78)` from `core/widgets/skeletons.dart` (consistent with the skeleton-loaders convention). Empty state shows a "No species found" message.

## 3. Search/filter capability

**Client-side filter on an already-loaded full list** — not server-side query params.

- `searchQueryProvider` (a `NotifierProvider<SearchQueryNotifier, String>`) holds the typed query string, updated directly from the `TextField.onChanged` callback in `directory_page.dart` line 44.
- `speciesListProvider` watches `searchQueryProvider` and calls `DirectoryRepository.fetchSpecies(search: query)`.
- Inside `fetchSpecies` (`directory_repository.dart` lines 12–24), filtering is done in Dart with `.where(...)` over `DemoData.species` (in-memory `List<TreeSpecies>` constant), matching on `localName`, `scientificName`, or `family` (case-insensitive `contains`). There is no HTTP call or query parameter sent anywhere — the "search" is purely a local list filter with an artificial network-like delay (`_demoDelay()`, 250ms, line 10).

## 4. Detail view

`species_detail_page.dart` (`SpeciesDetailPage`), reached via `speciesDetailProvider(speciesId)`:
- `SliverAppBar` (expandedHeight 300) with a `FlexibleSpaceBar` background image (or `_DefaultPlant` gradient fallback with eco icon).
- Local name (headline) + scientific name (italic).
- Stats row (`_SpeciesStat` widgets): CO₂/year, Growth Time (years), and Family (if present).
- "Native to {nativeRegion}" line, if present.
- "About" section showing `description`, if present.
- A "Lifetime Impact" callout computing `co2OffsetFactor * growthTimeYears` inline in the widget (not from the model/backend): `'A single ${s.localName} tree absorbs ~${(s.co2OffsetFactor * s.growthTimeYears).toStringAsFixed(0)} kg of CO₂ over ${s.growthTimeYears} years.'`
- Loading state uses `SkeletonDetailPage(heroHeight: 280)`.

## 5. Exact API endpoint(s) called

**None.** The directory feature makes **no HTTP/API calls at all.**

- `directory_repository.dart` does not import `api_config.dart`, `ApiClient`, `dio`, `http`, or any networking package. Its only imports are `flutter_riverpod`, `../../../core/demo/demo_data.dart`, and `../models/species_model.dart`.
- `fetchSpecies()` and `fetchSpeciesById()` both call `await _demoDelay()` (a `Future.delayed`) and then read directly from `DemoData.species`.
- `api_config.dart` line 72 defines a candidate constant:
  ```
  static String get trees => '$_admin/operations/trees';
  ```
  i.e. `$_admin/operations/trees` where `_admin = '$baseUrl$_v1/admin'` (line 39). **This constant is never referenced anywhere in the directory feature** (confirmed via grep across `lib/features/directory/` — zero hits for `ApiConfig.trees` or `api_config`). It appears to be defined for future use but is currently dead code as far as this feature is concerned.

## 6. Backend route cross-check

Backend file: `c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_apis\app\api\v1\admin\operations.py`

A real, implemented route exists matching the dead Flutter constant:

```python
@router.get("/trees", response_model=List[TreeSpeciesResponse])   # line 447
def list_tree_species(
    db: Session = Depends(get_db),
    admin=Depends(PermissionChecker("operations_read"))
):
    # 0 = soft-deleted (excluded), 1 = published, 2 = pending review (e.g.
    # auto-created from an unrecognized scan). Both 1 and 2 are shown so
    # admins can review drafts alongside the live encyclopedia.
    return (
        db.query(TreeSpecies)
        .filter(TreeSpecies.status.in_([TreeSpecies.STATUS_PUBLISHED, TreeSpecies.STATUS_PENDING_REVIEW]))
        .order_by(TreeSpecies.status.desc(), TreeSpecies.local_name)
        .all()
    )
```

- Mounted under the admin router, so full path is presumably `/api/v1/admin/operations/trees`, gated by `PermissionChecker("operations_read")` — i.e. this is an **admin-only** endpoint, not a general app/public endpoint. It takes no query params (no search/filter param in the signature) and returns `List[TreeSpeciesResponse]`.
- There are also `POST /trees`, `PATCH /trees/{tree_id}`, `DELETE /trees/{tree_id}` (lines 463, 492, 548) for admin CRUD.
- Because this route requires admin auth (`operations_read` permission) and lives under `/admin/`, it is not a like-for-like replacement for a public-facing "browse species" screen without either a public mirror endpoint or relaxed permissions — this app screen would need a different (non-admin) endpoint, or this admin endpoint reused with appropriate auth, to go live.
- No filter/search query parameter exists server-side for this route, so even if wired up, today's client-side `search` substring matching logic could not be pushed server-side without backend changes.

## 7. Riverpod providers

All in `c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_app\lib\features\directory\`:

| Provider | Type | File |
|---|---|---|
| `directoryRepositoryProvider` | `Provider<DirectoryRepository>` | `data\directory_repository.dart:5` |
| `searchQueryProvider` | `NotifierProvider<SearchQueryNotifier, String>` | `providers\directory_provider.dart:5` |
| `speciesListProvider` | `FutureProvider<List<TreeSpecies>>` | `providers\directory_provider.dart:13` |
| `speciesDetailProvider` | `FutureProvider.family<TreeSpecies, String>` | `providers\directory_provider.dart:18` |

## 8. Navigation routes (go_router)

Defined in `c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_app\lib\core\router\app_router.dart` (lines 90–99):

```dart
GoRoute(
  path: '/directory',
  builder: (__, _) => const DirectoryPage(),
  routes: [
    GoRoute(
      path: 'species/:id',
      builder: (_, state) => SpeciesDetailPage(speciesId: state.pathParameters['id']!),
    ),
  ],
),
```

- List page: `/directory`
- Detail page: `/directory/species/:id` (navigated via `context.push('/directory/species/${species.id}')` in `directory_page.dart:115`)
- Bottom-nav tab entry in `main_navigation.dart`: `_tabs = ['/home', '/action-hub', '/directory', '/profile']` (line 10) with icon `Icons.local_florist_rounded`, label `'Directory'` (line 38).

## 9. TODO/demo/mock comments verbatim

- `directory_repository.dart:10` — `Future<void> _demoDelay() => Future<void>.delayed(const Duration(milliseconds: 250));` (named "demo delay", simulating network latency with no real network call)
- No explicit `// TODO` comments were found in the directory feature files. The "demo" naming (`_demoDelay`, `DemoData.species`, `import '../../../core/demo/demo_data.dart'`) is itself the marker that this is mock data, not a TODO annotation.
- Related context comment in `demo_data.dart` (not directory-specific, but in the same demo file) around the Green Lens flow: *"this demo flow uses local sample results so the team can evaluate navigation, camera UX, points, badges, and the result sheet before backend integration... Once APIs are connected, the same flow can submit image, GPS, and species metadata to the BlueDot backend."* (`demo_data.dart` line ~102) — confirms the project's general pattern of demo-first, backend-later for tree/species-adjacent features.

## 10. Verdict: Real backend or DemoData?

**DemoData — entirely mock, no backend integration.**

Deciding evidence:

```dart
// directory_repository.dart
import '../../../core/demo/demo_data.dart';
...
Future<List<TreeSpecies>> fetchSpecies({String? search}) async {
    await _demoDelay();
    final query = search?.trim().toLowerCase() ?? '';
    if (query.isEmpty) return DemoData.species;
    return DemoData.species
        .where(...)
        .toList();
}

Future<TreeSpecies> fetchSpeciesById(String id) async {
    await _demoDelay();
    return DemoData.species.firstWhere(
      (species) => species.id == id,
      orElse: () => DemoData.species.first,
    );
}
```

`DirectoryRepository` never imports `api_config.dart` or any HTTP client; all data comes from the hardcoded `static const species = [...]` list in `demo_data.dart` (6 entries: Neem, Peepal, Jamun, Arjun, Banyan, Amaltas, with Unsplash stock photo URLs). The `ApiConfig.trees` constant (`$_admin/operations/trees`) exists in config but is unused by this feature — it is dead code with respect to the directory screen. A real, matching backend route (`GET /trees` in `operations.py`) does exist and is implemented server-side, but it is admin-gated (`PermissionChecker("operations_read")`) and not wired to this app-facing screen at all.
