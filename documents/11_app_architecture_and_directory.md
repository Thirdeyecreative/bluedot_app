# 11 — App Architecture & Directory Structure

**Status:** 100% Up to Date  
**Last Updated:** 2026-11-04  
**Framework:** Flutter (Dart) + Riverpod 2.x + GoRouter 14.x  

---

## 1. Overview

The BlueDot Flutter application follows a strictly modular **feature-first architecture**. Each domain is isolated into its own cohesive module under `lib/features/`, while shared concerns (networking, theme, configuration, and app-wide UI components) reside in `lib/core/`.

---

## 2. Global Directory Tree (`lib/`)

```text
lib/
├── main.dart                       // Entry point: Firebase, Supabase, MediaKit, app shell
├── core/                           // Shared application infrastructure
│   ├── config/                     // Environment config, health checks, endpoints (api_config.dart)
│   ├── constants/                  // Colors (app_colors.dart), assets, typography
│   ├── demo/                       // Fallback visual mocks (demo_data.dart)
│   ├── router/                     // GoRouter configuration, redirect guards (app_router.dart)
│   ├── services/                   // API client, storage, connectivity, app update checks
│   ├── theme/                      // Custom ThemeData & color schemes (app_theme.dart)
│   └── widgets/                    // Shared UI (media_carousel.dart, in_app_camera_page.dart,
│                                   //  no_internet_page.dart, app_update_sheet.dart, skeletons.dart)
└── features/                       // Feature modules
    ├── action_hub/                 // Drives, Campaigns, RSVPs, Volunteering, QR Check-ins, Site Suggestions
    ├── auth/                       // Native Supabase OTP, Profile Completion, User model & Notifiers
    ├── directory/                  // Botanical Encyclopedia, multi-field search, species details
    ├── home/                       // Dashboard, Compact App Bar, Promo Banners, Feed Aggregation, Blogs
    ├── legal/                      // Legal document versioning, affirmative consent tracking, Policy sheets
    ├── map/                        // Eco-Garden map (flutter_map), Bangalore bbox, GPS Blue Dot
    ├── navigation/                 // Curved bottom navigation shell (curved_nav_bar.dart, main_navigation.dart)
    ├── profile/                    // User account, Leaderboard, Badges, Certificates, 80G Tax Vault, Settings
    └── scanner/                    // Green Lens: Multi-photo capture, Vertex AI plant ID, PostGIS 5m dedupe
```

---

## 3. Modular Feature Structure

Every folder inside `features/` adheres to a strict separation of concerns:

- `models/`: Immutable Dart data classes with explicit `.fromJson()` / `.toJson()` serialization.
- `data/`: Repositories responsible for executing network calls via `ApiClient` and mapping responses.
- `providers/`: Riverpod providers (`FutureProvider`, `NotifierProvider`, `AsyncNotifierProvider`) bridging business logic with reactive UI.
- `pages/`: Full-screen widgets bound to GoRouter routes.
- `widgets/`: Local UI components specific to that feature (e.g., `promo_banner_carousel.dart` in `home/`, `scan_result_sheet.dart` in `scanner/`).

---

## 4. Architectural Patterns & Core Infrastructure

### 1. State Management (Riverpod 2.x)
- **Declarative & Reactive:** Eliminates mutable global state. Providers automatically dispose of resources when unneeded.
- **AsyncValue Pattern:** UI widgets handle `.when(data:, loading:, error:)` cleanly without raw `setState` cascades.
- **Optimistic UI:** Preference toggles (e.g. email notification toggles) update the UI immediately and roll back only upon server failure.

### 2. Navigation & Routing (GoRouter)
- `StatefulShellRoute` hosts the primary tabs (`/home`, `/action-hub`, `/directory`, `/profile`). The branch container animates the individual navigators while preserving their scroll positions and form state.
- **Smart Redirect Guard:** Intercepts route transitions:
  - Unauthenticated users $\to$ `/login`
  - Authenticated "ghost" users without names $\to$ `/complete-profile`
  - Fully authenticated users $\to$ `/home` (preventing access back to auth routes)
  - Public exemptions for `/splash`, `/terms`, `/privacy`, and `/no-internet`.

### 3. Build-Time Environment Selection (`ApiConfig`)
- Set `--dart-define=ENV=local|staging|production` when building the app. Release builds default to production and other builds default to local.
- For local development, desktop/web builds use `127.0.0.1`. Android uses `127.0.0.1` through `adb reverse tcp:8000 tcp:8000` and iOS uses the configured Wi-Fi host. Override the host with `--dart-define=API_HOST=...`, or the entire endpoint with `--dart-define=BASE_URL=...`.
- The connectivity service can fall back to the configured endpoint's `/health` route.

### 4. Resilient HTTP Client (`ApiClient`)
- Centralized `ApiClient` wraps `package:http`.
- **Automatic Auth Injection:** Reads the active Supabase JWT session and attaches `Authorization: Bearer <token>`.
- **Intelligent Error Handling:** Parses FastAPI error envelopes (`{"detail": ...}`) and maps HTTP status codes (401, 403, 404, 409, 429, 500) into human-friendly messages.
- **Multipart Uploads:** Supports binary and multi-image uploads with automatic MIME-type resolution for mobile cameras.

### 5. Media & High-Performance Video (`media_kit`)
- Videos in campaigns and banners are powered by `media_kit` (using the native `libmpv` C++ backend), avoiding Android `SurfaceTexture` slanting glitches.

### 6. Fail-Soft UI & Skeleton Loading
- Eliminates jarring circular progress spinners in favor of layout-accurate skeleton placeholders (`core/widgets/skeletons.dart`).
- When network connections hitch or timeout, the app displays user-friendly retry banners or seamlessly routes to `NoInternetPage`.
