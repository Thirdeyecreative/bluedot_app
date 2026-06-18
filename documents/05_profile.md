# Profile Feature — Engineering Reference

## 1. Overview

The profile feature lives entirely under:

`c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_app\lib\features\profile\`

Files (all absolute paths):

- `...\profile\pages\profile_page.dart` — main profile screen (header, impact stats, quick actions, badges, recent scans)
- `...\profile\pages\badges_page.dart` — full badge collection ("See all")
- `...\profile\pages\leaderboard_page.dart` — leaderboard with podium + full list
- `...\profile\pages\certificates_page.dart` — certificate list + certificate preview/share/download sheet
- `...\profile\pages\edit_profile_page.dart` — edit name/email/city form
- `...\profile\pages\settings_page.dart` — settings list, PAN management sheet, 80G Tax Vault page
- `...\profile\pages\legal_page.dart` — reusable `LegalPage` widget + concrete `TermsPage`/`PrivacyPage`
- `...\profile\providers\profile_provider.dart` — Riverpod providers (`badgesProvider`, `leaderboardProvider`, `certificatesProvider`)
- `...\profile\data\profile_repository.dart` — `ProfileRepository` (all-demo data source)
- `...\profile\models\badge_model.dart` — `Badge` model
- `...\profile\models\certificate_model.dart` — `VolunteerCertificate` model

Cross-referenced files:

- `c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_app\lib\core\demo\demo_data.dart`
- `c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_app\lib\core\config\api_config.dart`
- `c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_app\lib\features\scanner\widgets\scan_history_detail_sheet.dart`
- `c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_app\lib\features\scanner\providers\scanner_provider.dart`
- `c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_app\lib\features\scanner\data\scanner_repository.dart`
- `c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_app\lib\features\auth\providers\auth_provider.dart`
- `c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_app\lib\features\auth\data\auth_repository.dart`
- `c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_app\lib\core\router\app_router.dart`

A backend `app/api/v1/app/profile.py` route file was searched for under `bluedot_apis` (`Glob **/profile*.py`) and **no matching file exists in the repository** — there is no implemented backend profile route to cross-reference. Only the frontend `ApiConfig.userProfile` constant (`$_app/profile`) defines the intended endpoint; it appears unused by any current profile-feature code path (see section 7).

## 2. Profile data displayed

`_ProfileHeader` and `_ImpactStats` in `profile_page.dart` render fields from the `AppUser` object obtained via `ref.watch(currentUserProvider)` (from `auth_provider.dart`):

- Avatar — a static `Icons.person_rounded` glyph inside a `CircularPercentIndicator` showing `user.levelProgress` (no real image/photo upload; edit-profile page also just shows an initials avatar with a "Photo upload coming soon" snackbar).
- Name — `user.fullName ?? user.phone`
- Level / Level title — `user.levelTitle`, `user.level`
- XP progress — `user.pointsInCurrentLevel` / `user.pointsForNextLevel`
- Impact stats row: `Total XP` (`user.totalPoints`), `Trees Tagged` (`user.treesTagged`), `Donated` (`user.totalDonated`)

**All of this user data is demo/mocked.** `currentUserProvider` is a local `NotifierProvider` whose state is set only by `AuthRepository` (`auth_repository.dart`):

```dart
Future<AppUser> verifyOtp({required String phone, required String otp}) async {
  ...
  final user = DemoData.user;
  await _storage.saveToken(DemoData.demoToken);
  await _storage.saveUserInfo(phone: phone, name: user.fullName);
  return user;
}

Future<AppUser?> getSavedUser() async {
  final isLoggedIn = await _storage.isLoggedIn();
  if (!isLoggedIn) return null;
  return DemoData.user;
}
```

Both `verifyOtp` and `getSavedUser` return `DemoData.user` verbatim (`lib/core/demo/demo_data.dart:17-26`):

```dart
static const user = AppUser(
  id: 'demo-user',
  phone: demoPhone,
  fullName: 'Avishkar',
  email: 'avishkar@bluedot.demo',
  totalPoints: 1320,
  level: 3,
  totalDonated: 7500,
  treesTagged: 18,
);
```

So **"Total XP", "Trees Tagged" ("Your Trees"-style stat), and "Donated" are all hardcoded demo values** — none of them come from a live API call. There is no repository method anywhere in the profile feature that calls `ApiConfig.userProfile`.

The **only real, backend-backed data on the profile page is the Recent Scans list** (see section 6).

## 3. Quick actions

Confirmed by reading the current `_QuickActions` widget in `profile_page.dart` (lines 191-219): there are exactly **two** pills, Leaderboard and Certificates, side-by-side in a `Row` of two `Expanded` children. No "Eco Garden" or "Badges" pill exists in this row (Badges has its own separate section below; Eco Garden is only reachable via the app-bar map icon, not a quick-action pill).

```dart
class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.leaderboard_rounded,
                label: 'Leaderboard',
                sublabel: 'See your rank',
                color: AppColors.primaryBlue,
                onTap: () => context.push('/profile/leaderboard'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.workspace_premium_rounded,
                label: 'Certificates',
                sublabel: 'Your contributions',
                color: AppColors.terracotta,
                onTap: () => context.push('/profile/certificates'),
              ),
            ),
          ],
        ),
      );
}
```

This confirms the claim: **Leaderboard + Certificates only**, side-by-side. ("Eco Garden" is instead reachable via the `SliverAppBar` action icon `Icons.map_rounded` → `context.push('/map')`; "Badges" has its own dedicated `_BadgesSection` below the quick actions, with a "See all" button → `/profile/badges`.)

## 4. Badges / Certificates — data source

Both sections are **100% demo data**, served through `ProfileRepository` (`profile_repository.dart`):

```dart
class ProfileRepository {
  Future<void> _demoDelay() => Future<void>.delayed(const Duration(milliseconds: 250));

  Future<AppUser> fetchProfile() async {
    await _demoDelay();
    return DemoData.user;
  }

  Future<List<Badge>> fetchBadges() async {
    await _demoDelay();
    return DemoData.badges;
  }

  Future<List<Map<String, dynamic>>> fetchLeaderboard() async {
    await _demoDelay();
    return DemoData.leaderboard;
  }

  Future<List<VolunteerCertificate>> fetchCertificates() async {
    await _demoDelay();
    return DemoData.certificates;
  }
}
```

There is no HTTP call anywhere in this class — every method awaits an artificial 250ms delay and returns a `DemoData.*` constant. None of `ApiConfig.badges` (`$_admin/content/gamification/badges`), `ApiConfig.gamificationRules`, or `ApiConfig.leaderboard` (`$_app/leaderboard`) are referenced anywhere inside `lib/features/profile/`.

Providers in `profile_provider.dart` simply wrap these repository calls:

```dart
final badgesProvider = FutureProvider<List<Badge>>((ref) {
  return ref.watch(profileRepositoryProvider).fetchBadges();
});

final leaderboardProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(profileRepositoryProvider).fetchLeaderboard();
});

final certificatesProvider = FutureProvider<List<VolunteerCertificate>>((ref) {
  return ref.watch(profileRepositoryProvider).fetchCertificates();
});
```

Note: `profile_page.dart` does **not** even use `leaderboardProvider` for its inline display — `leaderboard_page.dart` defines its own larger, separate hardcoded list `_fullLeaderboard` (10 entries) rather than consuming `leaderboardProvider`/`DemoData.leaderboard`. So the leaderboard page's data is independently mocked inline, not sourced from the provider at all.

Badge model (`badge_model.dart`) supports `Badge.fromJson` for future API wiring, but no call site uses it yet — `DemoData.badges` are constructed directly as `Badge(...)` const objects, not parsed JSON.

## 5. Settings / Edit Profile / Legal sections

**Edit Profile** (`edit_profile_page.dart`):
- Fields: Full Name (required, min 2 chars), Email (optional, regex-validated), City (free text), Phone (read-only, disabled, labelled "your login ID and cannot be changed").
- Avatar is initials-only with a camera-icon affordance that just shows a "Photo upload coming soon" snackbar.
- On save, calls `ref.read(currentUserProvider.notifier).update(...)` which only mutates local Riverpod state — no backend PATCH. Comment in code (verbatim, `edit_profile_page.dart:42-43`):
  ```
  // Demo: persist to local state. (Wire to PATCH /app/profile when the
  // app-side profile endpoint lands.)
  ```

**Settings** (`settings_page.dart`) sections/tiles:
- Account: Edit Profile (`/profile/settings/edit`), My Certificates (`/profile/settings/certificates`), PAN Management (opens bottom sheet, local-only "Save PAN Securely" with simulated 1.5s save, no backend call).
- Notifications: Push Notifications toggle, Email Notifications toggle — both backed by local `Notifier<bool>` providers (`_pushEnabledProvider`, `_emailEnabledProvider`) defaulting to `true`, no persistence/API call.
- Tax & Compliance: 80G Tax Vault (`/profile/settings/tax-vault`) — `TaxVaultPage` shows a hardcoded `_donations` list (3 entries) with "Receipt Ready"/"Pending" statuses and simulated download snackbars.
- Legal: Terms & Conditions (`/profile/settings/terms`), Privacy Policy (`/profile/settings/privacy`), and an external "80G Exemption Details" link opened via `url_launcher` to `https://bluedot.org/80g`.
- About: App Version tile shows literal text `'1.0.0 (Demo)'`.
- Danger Zone: Sign Out (calls real `authNotifierProvider.notifier.signOut()`, which clears storage and navigates to `/login`) and Delete Account (confirmation dialog only — the `onPressed` for "Delete" just calls `Navigator.pop(context)`, no actual deletion logic).

**Legal pages** (`legal_page.dart`): a reusable `LegalPage` widget rendering a header card + numbered `LegalSection` list. `TermsPage` and `PrivacyPage` are concrete instances with fully hardcoded section text (8 sections each), `lastUpdated: '12 June 2026'`. All content is static copy, not fetched from any API/CMS.

## 6. Recent Scans section

Confirmed: yes, it opens `ScanHistoryDetailSheet`, defined at:

`c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_app\lib\features\scanner\widgets\scan_history_detail_sheet.dart`

Invocation in `profile_page.dart` (`_ScansHistory._build` itemBuilder, lines ~409-418):

```dart
onTap: () => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => ScanHistoryDetailSheet(item: item),
),
```

The list itself is driven by `scanHistoryProvider` (`scanner_provider.dart:24-26`):

```dart
final scanHistoryProvider = FutureProvider<List<ScanHistoryItem>>((ref) {
  return ref.watch(scannerRepositoryProvider).fetchHistory();
});
```

`fetchHistory()` in `scanner_repository.dart:36-37` performs a real HTTP call:

```dart
Future<List<ScanHistoryItem>> fetchHistory() async {
  final json = await _api.get(ApiConfig.scanHistory);
```

where `ApiConfig.scanHistory` = `$_app/tags/history`. **This is the one genuinely backend-backed section of the Profile page** (assuming the backend route exists and is reachable; not verified here since no backend route file was found for it either — see section 7).

## 7. API endpoints — verbatim constants and backend cross-reference

From `api_config.dart`:

| Constant | Path | Used by profile feature? |
|---|---|---|
| `ApiConfig.userProfile` | `$_app/profile` | **No** — not referenced anywhere under `lib/features/profile/` |
| `ApiConfig.leaderboard` | `$_app/leaderboard` | **No** — not referenced; leaderboard page uses inline hardcoded list, `ProfileRepository.fetchLeaderboard()` returns `DemoData.leaderboard` instead |
| `ApiConfig.badges` | `$_admin/content/gamification/badges` | **No** — not referenced; `ProfileRepository.fetchBadges()` returns `DemoData.badges` |
| `ApiConfig.gamificationRules` | `$_admin/content/gamification/rules` | **No** — not referenced anywhere in profile feature |
| `ApiConfig.suggestions` | `$_app/suggestions` | **No** — not referenced in profile feature (belongs to the directory/suggestions feature) |
| `ApiConfig.scanHistory` | `$_app/tags/history` | **Yes** — via `scanner_repository.dart`, consumed by Profile's Recent Scans section |

Backend cross-reference: `c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_apis\app\api\v1\app\profile.py` does **not exist**. A repo-wide glob for `**/profile*.py` under `bluedot_apis` returned no results, so there is currently no backend route implementation to confirm `/app/profile`, `/app/leaderboard`, or the gamification endpoints actually exist server-side. This could not be verified.

## 8. Riverpod providers used

- `currentUserProvider` (`NotifierProvider<CurrentUserNotifier, AppUser?>`) — `lib/features/auth/providers/auth_provider.dart`
- `authStateProvider` (`FutureProvider<bool>`) — `lib/features/auth/providers/auth_provider.dart`
- `authNotifierProvider` (`NotifierProvider<AuthNotifier, AsyncValue<void>>`) — `lib/features/auth/providers/auth_provider.dart`
- `badgesProvider` (`FutureProvider<List<Badge>>`) — `lib/features/profile/providers/profile_provider.dart`
- `leaderboardProvider` (`FutureProvider<List<Map<String, dynamic>>>`) — `lib/features/profile/providers/profile_provider.dart` (defined but **not consumed** by `leaderboard_page.dart`, which uses its own local hardcoded list)
- `certificatesProvider` (`FutureProvider<List<VolunteerCertificate>>`) — `lib/features/profile/providers/profile_provider.dart`
- `profileRepositoryProvider` (`Provider<ProfileRepository>`) — `lib/features/profile/data/profile_repository.dart`
- `scanHistoryProvider` (`FutureProvider<List<ScanHistoryItem>>`) — `lib/features/scanner/providers/scanner_provider.dart`
- Local-only settings toggles: `_pushEnabledProvider`, `_emailEnabledProvider` (`NotifierProvider<_BoolNotifier, bool>`) — private to `lib/features/profile/pages/settings_page.dart`

## 9. Navigation routes (go_router)

Defined in `c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_app\lib\core\router\app_router.dart` (lines ~100-120):

```dart
GoRoute(
  path: '/profile',
  builder: (__, _) => const ProfilePage(),
  routes: [
    GoRoute(path: 'badges', builder: (__, _) => const BadgesPage()),
    GoRoute(path: 'leaderboard', builder: (__, _) => const LeaderboardPage()),
    GoRoute(path: 'edit', builder: (__, _) => const EditProfilePage()),
    GoRoute(path: 'certificates', builder: (__, _) => const CertificatesPage()),
    GoRoute(
      path: 'settings',
      builder: (__, _) => const SettingsPage(),
      routes: [
        GoRoute(path: 'tax-vault', builder: (__, _) => const TaxVaultPage()),
        GoRoute(path: 'edit', builder: (__, _) => const EditProfilePage()),
        GoRoute(path: 'terms', builder: (__, _) => const TermsPage()),
        GoRoute(path: 'privacy', builder: (__, _) => const PrivacyPage()),
        GoRoute(path: 'certificates', builder: (__, _) => const CertificatesPage()),
      ],
    ),
  ],
),
```

Resulting full paths: `/profile`, `/profile/badges`, `/profile/leaderboard`, `/profile/edit`, `/profile/certificates`, `/profile/settings`, `/profile/settings/tax-vault`, `/profile/settings/edit`, `/profile/settings/terms`, `/profile/settings/privacy`, `/profile/settings/certificates`. Note `edit` and `certificates` are duplicated both as direct `/profile/...` children and nested under `/profile/settings/...`, pointing to the same widgets (`EditProfilePage`, `CertificatesPage`).

The profile page's app bar also has an icon button to `/profile/edit` (edit icon) and one to `/map` (Eco Garden, `Icons.map_rounded`) — the latter is outside the `/profile` route subtree.

## 10. TODO / demo / mock comments found verbatim

- `lib/features/profile/pages/edit_profile_page.dart:42-43`:
  ```
  // Demo: persist to local state. (Wire to PATCH /app/profile when the
  // app-side profile endpoint lands.)
  ```
- `lib/features/profile/pages/leaderboard_page.dart:8`:
  ```
  // Extended leaderboard for demo purposes
  ```
- `lib/features/profile/pages/settings_page.dart:127` — literal demo marker in UI text: `'1.0.0 (Demo)'`
- `lib/features/auth/data/auth_repository.dart` — no explicit "demo" comment, but logic unconditionally returns `DemoData.user` for both `verifyOtp` and `getSavedUser`.
- `lib/features/profile/data/profile_repository.dart` — no explicit comment, but every method is an artificial `_demoDelay()` + `DemoData.*` return with no real HTTP client usage (contrast with `scanner_repository.dart`, which does call `_api.get(...)`).

## Summary of demo/mock vs real-API status

| Section | Status |
|---|---|
| User identity (name, email, phone, level, XP, trees tagged, donated) | **Demo** — `DemoData.user`, via `AuthRepository` |
| Avatar/photo | **Demo/placeholder** — initials only, "coming soon" upload |
| Badges (profile page + badges page) | **Demo** — `DemoData.badges` via `ProfileRepository.fetchBadges()` |
| Certificates | **Demo** — `DemoData.certificates` via `ProfileRepository.fetchCertificates()` |
| Leaderboard (profile quick action target) | **Demo** — local hardcoded `_fullLeaderboard` in `leaderboard_page.dart`, independent of `leaderboardProvider`/`DemoData.leaderboard` |
| 80G Tax Vault donations | **Demo** — hardcoded `_donations` list in `settings_page.dart` |
| Push/Email notification toggles | **Local-only**, no persistence/API |
| Recent Scans | **Real API** — `GET $_app/tags/history` via `scanner_repository.dart` |
| Edit profile save | **Local-only** — explicit TODO comment to wire `PATCH /app/profile` |
