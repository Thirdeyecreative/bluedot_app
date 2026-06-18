# Navigation / App Shell — Current State

## 1. App Shell Structure

Defined in `lib/features/navigation/main_navigation.dart` (only file in this feature folder).

- **`MainNavigationShell`** (`StatelessWidget`) — wraps the routed `child` in a `Scaffold(extendBody: true, bottomNavigationBar: _BlueDotNavBar(...))`. It is plugged into the router via a plain `ShellRoute` (not `StatefulShellRoute`):

```dart
ShellRoute(
  builder: (context, state, child) => MainNavigationShell(child: child),
  routes: [ /* /home, /action-hub, /directory, /profile and their nested routes */ ],
)
```

- **Tab selection is path-derived, not state-stored.** There is no dedicated Riverpod provider holding a "selected tab index." Instead:

```dart
static const _tabs = ['/home', '/action-hub', '/directory', '/profile'];
```

`_currentIndex(context)` matches `GoRouterState.of(context).matchedLocation` against `_tabs` using `startsWith`, and that index drives which nav item renders as "selected."

- **`_BlueDotNavBar`** — a fully custom bottom nav widget (not Flutter's built-in `BottomNavigationBar` or `NavigationBar`). Items are defined as a typed record list:

```dart
static const _items = [
  (icon: Icons.home_rounded, label: 'Home', route: '/home'),
  (icon: Icons.hub_rounded, label: 'Action Hub', route: '/action-hub'),
  (icon: Icons.local_florist_rounded, label: 'Directory', route: '/directory'),
  (icon: Icons.person_rounded, label: 'Profile', route: '/profile'),
];
```

Tapping an item calls `context.go(_items[i].route)`. The selected tab renders as an elevated circular icon button (raised ~14px above the bar) with its label underneath; unselected tabs render as a plain dimmed icon. The bar itself is styled with `AppColors.forestGreen`, 32px corner radius, floating "pill" shape with a shadow.

## 2. Bottom Nav Tabs → Pages

| Tab Label | Icon | Route Path | Page Rendered |
|---|---|---|---|
| Home | `Icons.home_rounded` | `/home` | `HomePage` |
| Action Hub | `Icons.hub_rounded` | `/action-hub` | `ActionHubPage` |
| Directory | `Icons.local_florist_rounded` | `/directory` | `DirectoryPage` |
| Profile | `Icons.person_rounded` | `/profile` | `ProfilePage` |

## 3. Riverpod Providers Involved in Navigation

None found. Tab highlighting is computed purely from `GoRouterState.of(context).matchedLocation` inside `MainNavigationShell`/`_BlueDotNavBar` — no `NotifierProvider`/`StateProvider` tracks the active tab. The only Riverpod provider touching the router is `authStateProvider` (consumed by `routerProvider` for the redirect guard — see `01_auth.md`).

`routerProvider` itself is a `Provider<GoRouter>` defined in `lib/core/router/app_router.dart`, and it `watch`es `authStateProvider` so the router rebuilds/re-evaluates redirects when auth state changes.

## 4. Full Route Table

Source: `lib/core/router/app_router.dart`. `initialLocation: '/splash'`.

### Outside the shell (full-screen routes)

| Path | Page | Params |
|---|---|---|
| `/splash` | `SplashPage` | — |
| `/login` | `LoginPage` | — |
| `/otp` | `OtpPage` | `phone` passed via `extra` (not a path/query param) |
| `/scanner` | `GreenLensPage` | — |
| `/map` | `EcoGardenPage` | — |
| `/notifications` | `NotificationsPage` | — |

### Inside the shell (`ShellRoute` → `MainNavigationShell`)

| Path | Page | Params |
|---|---|---|
| `/home` | `HomePage` | — |
| `/home/blog/:slug` | `BlogDetailPage` | `slug` = `state.pathParameters['slug']!` |
| `/action-hub` | `ActionHubPage` | — |
| `/action-hub/event/:id` | `EventDetailPage` | `eventId` = `state.pathParameters['id']!` |
| `/action-hub/event/:id/checkin` | `EventCheckinPage` | `eventId` from parent `:id` |
| `/action-hub/suggest-site` | `SuggestSitePage` | — |
| `/directory` | `DirectoryPage` | — |
| `/directory/species/:id` | `SpeciesDetailPage` | `speciesId` = `state.pathParameters['id']!` |
| `/profile` | `ProfilePage` | — |
| `/profile/badges` | `BadgesPage` | — |
| `/profile/leaderboard` | `LeaderboardPage` | — |
| `/profile/edit` | `EditProfilePage` | — |
| `/profile/certificates` | `CertificatesPage` | — |
| `/profile/settings` | `SettingsPage` | — |
| `/profile/settings/tax-vault` | `TaxVaultPage` | — |
| `/profile/settings/edit` | `EditProfilePage` | — |
| `/profile/settings/terms` | `TermsPage` | — |
| `/profile/settings/privacy` | `PrivacyPage` | — |
| `/profile/settings/certificates` | `CertificatesPage` | — |

Note: `TaxVaultPage`, `TermsPage`, and `PrivacyPage` are referenced as route destinations but their source imports weren't directly visible in `app_router.dart`'s import list during this review — they are likely defined in or re-exported from a `legal_page.dart` or within `settings_page.dart`. Worth confirming file locations if writing per-page docs.

## 5. Auth Guards / Redirects

Implemented in `routerProvider`, watching `authStateProvider` (see `01_auth.md` for provider details). Exact redirect function:

```dart
redirect: (context, state) {
  final isLoggedIn = authState.value ?? false;
  final isSplash = state.matchedLocation == '/splash';
  final isAuth = state.matchedLocation.startsWith('/login') ||
      state.matchedLocation.startsWith('/otp');

  if (isSplash) return null;
  if (!isLoggedIn && !isAuth) return '/login';
  if (isLoggedIn && isAuth) return '/home';
  return null;
},
```

Behavior:
- `/splash` is always allowed through (no redirect) — it performs its own one-time auth check and navigates manually.
- Any other route, if not logged in and not already on an auth route (`/login*` or `/otp*`), redirects to `/login`.
- If logged in and on an auth route, redirects to `/home`.
- Otherwise no redirect (route proceeds as requested).

This means all shell routes (`/home`, `/action-hub`, `/directory`, `/profile` and their nested routes) and the full-screen utility routes (`/scanner`, `/map`, `/notifications`) are implicitly gated behind `isLoggedIn` — an unauthenticated user landing on any of them gets bounced to `/login`.

## 6. TODOs / Gaps

- A grep for `TODO|mock|demo|not yet|fixme` (case-insensitive) across `lib/features/navigation/` and `lib/core/router/` returned **no matches** — no flagged work-in-progress comments in either area.
- Gap (not flagged in code, but notable): there is no Riverpod-level navigation state — if any other part of the app needs to know the "current tab" outside of widget tree access to `GoRouterState`, it would need to be derived ad hoc; there's no shared provider for it today.
- `ShellRoute` is used rather than `StatefulShellRoute.indexedStack`, meaning each tab's page is rebuilt from scratch on navigation rather than preserving independent navigation stacks/scroll position per tab (no `StatefulShellBranch` state preservation).
