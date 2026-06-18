# Leaderboard — Current State

> Documented by reading the live source on 2026-06-18.

## Files read

- `lib/features/profile/pages/leaderboard_page.dart` — the page/UI
- `lib/features/profile/providers/profile_provider.dart` — `leaderboardProvider`
- `lib/features/profile/data/profile_repository.dart` — `fetchLeaderboard`
- `lib/core/config/api_config.dart` — `leaderboard` endpoint constant
- `lib/core/router/app_router.dart` — route registration
- Backend: searched `bluedot_apis/app/api/v1/app/` (`tags.py`, `config.py`, `events.py`, `suggestions.py`, `__init__.py`) and the whole `bluedot_apis/app` tree for any file or string matching "leaderboard" (case-insensitive)

## UI — single global ranking, no city tabs (confirmed)

`LeaderboardPage` (`leaderboard_page.dart`) builds a single screen with no `TabBar`/`TabController`/`TabBarView` anywhere in the file. The structure is:

1. Blue header with back button and centered "Leaderboard" title.
2. `_Podium` — top-3 ranking shown as 1st/2nd/3rd podium blocks (1st centered/tallest, 2nd left, 3rd right), each with avatar-initial, name, and `'$points XP'`.
3. `_LeaderList` — scrollable `ListView.builder` of `_LeaderRow` for ranks 4+ (entries `.skip(3)`).
4. `_CurrentUserBanner` — a sticky bottom banner showing the current user's rank, points, and "Earn N more XP to overtake `<name above>`" if applicable.

No remnants of a removed city-tab widget (no commented-out `TabBar`, no `_CityTab` class, no `cityFilter` state variable) were found — the city-tab UI is confirmed fully gone from the current file. However, each leaderboard entry's data model still **carries a `'city'` field** (e.g. `'city': 'Mumbai'`) which is simply unused/undisplayed anywhere in the current widget tree — a data-shape leftover, not a UI leftover.

### Fields shown per entry

From `_fullLeaderboard` entries (e.g. `{'rank': 1, 'name': 'Aarav Mehta', 'city': 'Mumbai', 'points': 4280, 'trees': 63, 'level': 'Guardian'}`) and the row/podium widgets that render them:

- `rank` (`#$rank`)
- `name` (avatar initial circle + full name, "(You)" suffix if current user)
- `points` (rendered as `'$points XP'`)
- `trees` (tree count, shown in `_LeaderRow` with an eco icon, e.g. `'$trees trees'`) — **not shown** in the podium slots, only in the scrollable list rows
- `level` (e.g. `'Sapling'`, `'Ranger'`, `'Guardian'`, `'Seedling'`) — shown under the name in `_LeaderRow`
- `city` — present in the data but **not rendered** anywhere in the current UI

## Data source — fully hardcoded demo data, NOT backend-driven (confirmed, important finding)

`LeaderboardPage` does **not** use `leaderboardProvider` or `ProfileRepository.fetchLeaderboard()` at all. Instead it defines and consumes a local hardcoded constant directly in the page file (`leaderboard_page.dart` lines 8-20):

```dart
const _fullLeaderboard = [
  {'rank': 1, 'name': 'Aarav Mehta', 'city': 'Mumbai', 'points': 4280, 'trees': 63, 'level': 'Guardian'},
  {'rank': 2, 'name': 'Nisha Rao', 'city': 'Pune', 'points': 3860, 'trees': 55, 'level': 'Ranger'},
  {'rank': 3, 'name': 'Avishkar', 'city': 'Mumbai', 'points': 1320, 'trees': 18, 'level': 'Sapling'},
  ... (10 entries total)
];
```

The only dynamic piece is the current user's identity (`ref.watch(currentUserProvider)`, from `auth_provider.dart`), used to find/highlight "you" within this static list by matching `name`. If the current user's name isn't found in the static list, a synthetic fallback entry is created with `rank: 99` using `currentUser?.totalPoints`, `currentUser?.treesTagged`, `currentUser?.levelTitle`.

There is a separate, **unused** path: `leaderboardProvider` (`profile_provider.dart` lines 10-12) → `ProfileRepository.fetchLeaderboard()` (`profile_repository.dart` lines 24-27), which itself just does `await _demoDelay(); return DemoData.leaderboard;` — i.e. even this "repository" layer returns local demo data (`DemoData.leaderboard`), not a real API call. `LeaderboardPage` doesn't reference this provider at all, so it's dead code as far as this screen is concerned.

## API endpoint — defined in config but confirmed unused, and confirmed absent on backend

`ApiConfig.leaderboard` = `$_app/leaderboard` → would resolve to `GET /api/v1/app/leaderboard` (`api_config.dart` line 49).

A search of the backend (`bluedot_apis/app/api/v1/app/` — containing `tags.py`, `config.py`, `events.py`, `suggestions.py`, `__init__.py` — and the entire `bluedot_apis/app` source tree) for any file or route matching "leaderboard" (case-insensitive) found **no matches at all**. There is no `leaderboard.py` file and no `/leaderboard` route registered anywhere in the backend. The `ApiConfig.leaderboard` constant therefore currently points to an endpoint that does not exist on the backend, and — separately — is not called by any code in the leaderboard feature anyway (the page uses local static data, not this constant).

## Riverpod providers used

- By `LeaderboardPage` itself: only `currentUserProvider` (from `lib/features/auth/providers/auth_provider.dart`), used to identify "you" within the static list.
- Defined but **not used** by this page: `leaderboardProvider` (`FutureProvider<List<Map<String, dynamic>>>`, `profile_provider.dart`), which wraps `ProfileRepository.fetchLeaderboard()` (itself demo data, not a real API call).

## Navigation route

Registered in `app_router.dart`, nested under `/profile`: `GoRoute(path: 'leaderboard', builder: (__, _) => const LeaderboardPage())` — i.e. reached at `/profile/leaderboard`, consistent with being launched from a Profile quick action. The page itself navigates back via `Navigator.pop(context)` (not `context.pop()`/go_router, note the inconsistency with the map page which uses `context.pop()`).

## Demo-data status — confirmed

Entirely demo/static: both the active code path (`_fullLeaderboard` constant in the page) and the dormant/unused code path (`leaderboardProvider` → `ProfileRepository.fetchLeaderboard()` → `DemoData.leaderboard`) are non-backend, hardcoded data. There is no live API integration for the leaderboard feature currently wired into the UI.

## TODO comments found

None found in `leaderboard_page.dart`, `profile_provider.dart`, or `profile_repository.dart` — no explicit TODO markers exist flagging the demo-data state; it is only discoverable by reading the actual data flow as documented above.
