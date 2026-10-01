# 11 — App Architecture & Directory Structure

## 1. Overview

The BlueDot Flutter app follows a strictly modular **feature-first architecture** with Riverpod for state management and GoRouter for declarative routing.

The `lib/` directory is split into two primary domains:
- `core/`: Application-wide utilities, configuration, theme, networking, and shared widgets.
- `features/`: Isolated, self-contained business domains (Auth, Home, Scanner, Profile, etc.).

---

## 2. Global Directory Tree (`lib/`)

```text
lib/
├── main.dart                       // Entry point (WidgetsBinding, Supabase, MediaKit init)
├── core/                           // Shared application infrastructure
│   ├── config/                     // Environment and API endpoints (api_config.dart)
│   ├── constants/                  // Assets, colors, typography (app_colors.dart)
│   ├── demo/                       // Hardcoded mock data (demo_data.dart)
│   ├── router/                     // GoRouter configuration (app_router.dart)
│   ├── services/                   // Core networking (api_client.dart) & storage
│   ├── theme/                      // Flutter ThemeData definitions (app_theme.dart)
│   └── widgets/                    // Shared UI (media_carousel.dart, buttons, skeletons)
└── features/                       // Feature modules
    ├── action_hub/                 // Events, Drives, Campaigns, and Check-ins
    ├── auth/                       // Login, OTP verification, and Profile setup
    ├── directory/                  // Botanical Encyclopedia and species search
    ├── home/                       // Dashboard, Stats, Blogs, Promo Banners
    ├── map/                        // Eco-Garden map and location clustering
    ├── navigation/                 // Global bottom navigation scaffold (main_navigation.dart)
    ├── profile/                    // User settings, Leaderboard, Badges, Certificates, Tax Vault
    └── scanner/                    // Green Lens (AI camera, real-time ML, scan results)
```

---

## 3. Feature-First Structure

Each folder inside `features/` follows a uniform internal structure to maintain separation of concerns:

- `models/`: Immutable Dart data classes (often with `fromJson`).
- `data/`: Repositories handling HTTP requests (via `ApiClient`) or mock data access.
- `providers/`: Riverpod providers (`FutureProvider`, `NotifierProvider`) bridging UI and repositories.
- `pages/`: Full-screen Flutter `Widget`s that map to GoRouter routes.
- `widgets/`: Feature-specific UI components (e.g., `promo_banner_carousel.dart` in `home/`).

---

## 4. Key Architectural Patterns

### State Management (Riverpod)
The app uses modern Riverpod (`flutter_riverpod`). State is largely driven by `FutureProvider`s for asynchronous data fetching and `NotifierProvider`s for complex mutable state (e.g., `authNotifierProvider`).
UI widgets use `ConsumerWidget` or `ConsumerStatefulWidget` and rely on `.when()` blocks to handle `data`, `loading`, and `error` states efficiently.

### Routing (GoRouter)
Defined in `core/router/app_router.dart`. The app uses nested routing via `ShellRoute` for the main bottom navigation bar (`MainNavigation`), allowing tabs to persist state while sub-pages (e.g., `/profile/settings`) are pushed on top.

### Video & Media
Video playback is centralized through `media_kit` (using the native `libmpv` C++ engine to avoid Android SurfaceTexture slanting bugs). This logic is fully encapsulated within `core/widgets/media_carousel.dart` and `home/widgets/promo_banner_carousel.dart`.

### "Fail-Soft" UI
The app uses sophisticated "Skeleton" loaders (`core/widgets/skeletons.dart`) rather than simple spinners. Fallback mechanisms (e.g., placeholder images for missing avatars) are implemented across all media widgets to ensure robust error handling.
