# 09 — Navigation & App Shell — Engineering Reference

**Status:** 100% Complete & Fully Integrated  
**Last Updated:** 2026-11-04  
**Router:** `GoRouter` with `StatefulShellRoute.indexedStack`  
**Shell UI:** Custom `CurvedNavBar` with Animated Hump & Floating Icon Bubble  

---

## 1. App Shell Architecture

The BlueDot application uses declarative routing powered by `go_router` and `StatefulShellRoute.indexedStack`. This architecture preserves the state and scroll position of each tab independently while switching.

### Source Files
- `lib/core/router/app_router.dart` — Router definitions, state listeners, and auth redirect guards.
- `lib/features/navigation/main_navigation.dart` — `MainNavigationShell` and bottom bar wrapper with Android `PopScope`.
- `lib/features/navigation/curved_nav_bar.dart` — High-polish animated curved navigation bar with bezier hump, floating bubble, and avatar rendering.

---

## 2. Bottom Navigation Structure

The bottom navigation bar features 4 primary branches corresponding to the core app pillars:

| Branch | Tab Label | Icon | Route Path | Root Page |
|---|---|---|---|---|
| `0` | **Home** | `Icons.home_rounded` | `/home` | `HomePage` |
| `1` | **Action Hub** | `Icons.explore_rounded` | `/action-hub` | `ActionHubPage` |
| `2` | **Directory** | `Icons.park_rounded` | `/directory` | `DirectoryPage` |
| `3` | **Profile** | `Icons.person_rounded` | `/profile` | `ProfilePage` |

### Custom `CurvedNavBar` UI:
- **Curved Canvas:** Draws a smooth bezier dip and hump that moves along with tab transitions.
- **Floating Active Bubble:** An elevated circular pill floats above the active tab with the highlighted icon.
- **Profile Avatar Integration:** If the user has a profile picture (`user.avatarUrl`), the Profile tab renders the circular avatar image with network caching.
- **Android Back-Button Handling (`PopScope`):**
  - When the user presses the physical back button on Android while on tabs 1, 2, or 3, the app switches back to Tab 0 (`/home`) instead of exiting.
  - Pressing back on Tab 0 exits the app as expected.

---

## 3. Complete Application Route Table

### Outside the Shell (Full-Screen / Modal Routes)

| Path | Destination Widget | Parameters / Notes |
|---|---|---|
| `/splash` | `SplashPage` | App launch, animation, session verification |
| `/no-internet` | `NoInternetPage` | Dedicated screen when device loses internet connectivity |
| `/login` | `LoginPage` | Phone number entry & OTP dispatch |
| `/otp` | `OtpPage` | 6-digit OTP verification; takes query param `phone` |
| `/complete-profile` | `CompleteProfilePage` | Profile setup required for new accounts (`fullName == null`) |
| `/terms` | `TermsPage` | Public Terms of Service viewer |
| `/privacy` | `PrivacyPage` | Public Privacy Policy viewer |
| `/scanner` | `GreenLensPage` | AI camera plant scanner |
| `/map` | `EcoGardenPage` | Full-screen interactive Eco Garden map |
| `/notifications` | `NotificationsPage` | Notifications center |

### Inside the Shell (`StatefulShellRoute.indexedStack`)

#### Branch 0: Home
- `/home` — `HomePage`
- `/home/blogs` — `AllBlogsPage`
- `/home/blog/:slug` — `BlogDetailPage` (path parameter: `:slug`)

#### Branch 1: Action Hub
- `/action-hub` — `ActionHubPage` (supports query param `?tab=0` or `?tab=1`)
- `/action-hub/campaign/:id` — `CampaignDetailPage`
- `/action-hub/event/:id` — `EventDetailPage`
- `/action-hub/event/:id/checkin` — `EventCheckinPage` (QR scanner)
- `/action-hub/suggest-site` — `SuggestSitePage` (GPS + photo crowdsourcing)

#### Branch 2: Directory
- `/directory` — `DirectoryPage` (botanical encyclopedia)
- `/directory/species/:id` — `SpeciesDetailPage`

#### Branch 3: Profile
- `/profile` — `ProfilePage`
- `/profile/badges` — `BadgesPage`
- `/profile/leaderboard` — `LeaderboardPage`
- `/profile/certificates` — `CertificatesPage`
- `/profile/edit` — `EditProfilePage`
- `/profile/settings` — `SettingsPage`
  - `/profile/settings/tax-vault` — `TaxVaultPage` (80G donation tax receipts)
  - `/profile/settings/edit` — `EditProfilePage`
  - `/profile/settings/terms` — `TermsPage`
  - `/profile/settings/privacy` — `PrivacyPage`
  - `/profile/settings/certificates` — `CertificatesPage`

---

## 4. Navigation Guards & Redirect Logic

The redirect guard in `routerProvider` strictly enforces security and profile completeness:

```dart
redirect: (context, state) {
  final currentUser = ref.read(currentUserProvider);
  final isLoggedIn = currentUser != null;
  
  final isSplash = state.matchedLocation == '/splash';
  final isAuth = state.matchedLocation.startsWith('/login') ||
      state.matchedLocation.startsWith('/otp');
  final isLegal = state.matchedLocation == '/terms' ||
      state.matchedLocation == '/privacy';
  final isCompleteProfile = state.matchedLocation == '/complete-profile';
  final isNoInternet = state.matchedLocation == '/no-internet';

  // Always allow unauthenticated access to splash, legal, and offline screens
  if (isSplash || isNoInternet || isLegal) return null;

  // Unauthenticated users are forced to /login
  if (!isLoggedIn) {
    return isAuth ? null : '/login';
  }
  
  // Logged-in users missing a name are forced to complete their profile
  final needsProfileCompletion = currentUser.fullName == null;
  if (needsProfileCompletion) {
    return isCompleteProfile ? null : '/complete-profile';
  }
  
  // Authenticated users with complete profiles cannot visit login, otp, or complete-profile
  if (isAuth || isCompleteProfile) return '/home';
  
  return null;
}
```

### Reactive Refresh Triggers:
- `ref.listen(authStateProvider, ...)` triggers `router.refresh()` when auth changes (e.g., login or logout).
- `ref.listen(currentUserProvider, ...)` triggers `router.refresh()` when profile fields change (e.g., completing name or updating PAN).
