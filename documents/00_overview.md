# BlueDot App — Documentation Index

**Current State & Architecture Reference**  
**Last Audited & Updated:** 2026-11-04  
**Codebase:** `bluedot_app/` (Flutter Mobile Client) + `bluedot_apis/` (FastAPI / PostgreSQL / Supabase)  

---

## 1. Feature Documentation Summary

Every feature in the application has been verified against the live source code and real backend API integrations:

| File | Feature | Live Backend Integration Status |
|---|---|---|
| [01_auth.md](01_auth.md) | **Auth, OTP & Splash** | **100% Real Backend.** Supabase Auth OTP + Passiton MSG91 DLT transactional SMS hook + FastAPI `GET/PUT /api/v1/app/profile` profile management. Reviewer bypass test suite (`+919999999999` / `558712`). |
| [02_home.md](02_home.md) | **Home Feed & Dashboard** | **100% Real Backend.** Aggregated `GET /api/v1/app/home-feed` endpoint powering banners, upcoming drives, active campaigns, published blogs, and scan tagline. Dedicated `/home/blogs` list and `/home/blog/:slug` readers. |
| [03_scanner_green_lens.md](03_scanner_green_lens.md) | **Green Lens AI Scanner** | **100% Real Backend.** Multi-photo in-app camera, `POST /api/v1/app/tags/scan` with Vertex AI / PlantNet, 5-meter PostGIS proximity deduplication (+50 new tag / +15 verified match), auto-publish for confidence $\ge 70\%$, and `GET /api/v1/app/tags/history`. |
| [04_eco_garden_map.md](04_eco_garden_map.md) | **Eco Garden Map** | **100% Real Backend.** Bounding-box PostGIS query (`GET /api/v1/app/tags/map`) displaying community-wide trees, dynamic live GPS "Blue Dot", Bangalore center fallback, manual refresh with skeleton loader, and live personal vs. community stats. |
| [05_profile.md](05_profile.md) | **Profile & Settings** | **100% Real Backend.** `GET/PUT /api/v1/app/profile`, avatar upload via CDN, dynamic level titles & XP progress, volunteer certificates (`GET /api/v1/app/profile/certificates`), 80G Tax Vault for donation receipts, push/email notification sync, and runtime environment switching. |
| [06_leaderboard.md](06_leaderboard.md) | **Leaderboard** | **100% Real Backend.** `GET /api/v1/app/leaderboard` with PostgreSQL `RANK()` window function, Redis caching, infinite-scroll pagination (page size: 30), top-3 podium blocks, and sticky current-user rank banner with overtaking gap. |
| [07_action_hub_events.md](07_action_hub_events.md) | **Action Hub, Events & Campaigns** | **100% Real Backend.** `GET /api/v1/app/events`, RSVP (`POST/DELETE /events/:id/rsvp`), Volunteering (`POST/DELETE /events/:id/volunteer`), QR-token check-in (`POST /events/checkin`), manual checkout, site suggestions with GPS (`POST /suggestions`), and campaign donations with 80G receipt generation (`POST /donations`). |
| [08_directory.md](08_directory.md) | **Botanical Directory** | **100% Real Backend.** `GET /api/v1/app/directory` public encyclopedia, multi-field server-side ILIKE search (local name, scientific name, family, native region), unpaginated 500-item search responses, smooth limit-30 pagination for browsing, and species detail reader. |
| [09_navigation.md](09_navigation.md) | **Navigation & App Shell** | **100% Complete.** `StatefulShellRoute.indexedStack` with 4 state-preserved branches, floating `CapsuleNavBar` with expanding pill indicator, haptic feedback, Android back-button `PopScope`, and profile-aware redirect guards. |
| [10_database_schema_trees.md](10_database_schema_trees.md) | **Database Schema (Trees & Operations)** | **100% Real Backend.** Comprehensive entity-relationship diagram, PostGIS spatial geometries (`POINT`, `POLYGON`), PostGIS `ST_DWithin` deduplication, and single-source-of-truth `tree_species` encyclopedia with JSONB fun facts. |
| [11_app_architecture_and_directory.md](11_app_architecture_and_directory.md) | **App Architecture & Directory** | Modular feature-first architecture, Riverpod state management, GoRouter routing, `media_kit` native C++ video engine, and skeleton loaders. |
| [12_legal_and_compliance.md](12_legal_and_compliance.md) | **Legal & Privacy Compliance** | **100% Real Backend.** Dynamic markdown document rendering for Terms and Privacy, affirmative consent recording on login, retroactive `PolicyUpdateSheet` for policy updates, and GDPR/DPDP data export & deletion requests (`POST /api/v1/app/legal/privacy-request`). |
| [13_cashfree_payment_gateway.md](13_cashfree_payment_gateway.md) | **Cashfree Payment Gateway** | **In Progress.** Zero-trust client-server-gateway architecture, Cashfree PG v2023-08-01, ACID atomic transactions, CAP theorem (CP prioritized), HMAC-SHA256 webhooks, UPI Intent SDK checkout, and automated refunds. |

---

## 2. Core Infrastructure & Networking Summary

### State Management (Riverpod 2.x)
- Providers are organized cleanly per feature (`auth_provider.dart`, `home_provider.dart`, `scanner_provider.dart`, `leaderboard_provider.dart`, `action_provider.dart`, `directory_provider.dart`).
- Asynchronous states are managed cleanly via `FutureProvider`, `NotifierProvider`, and `AsyncNotifierProvider` without mutable global state.

### Routing & Navigation (GoRouter 14.x)
- Configured in `lib/core/router/app_router.dart`.
- Root navigator hosts non-shell pages (`/splash`, `/login`, `/otp`, `/complete-profile`, `/terms`, `/privacy`, `/no-internet`, `/scanner`, `/map`, `/notifications`).
- `StatefulShellRoute.indexedStack` hosts persistent bottom-bar branches:
  - Branch 0: `/home` (with `/home/blogs` and `/home/blog/:slug`)
  - Branch 1: `/action-hub` (with `/action-hub/campaign/:id`, `/action-hub/event/:id`, `/action-hub/event/:id/checkin`, `/action-hub/suggest-site`)
  - Branch 2: `/directory` (with `/directory/species/:id`)
  - Branch 3: `/profile` (with `/profile/badges`, `/profile/leaderboard`, `/profile/certificates`, `/profile/settings`)

### API Configuration & Runtime Environment Switching (`ApiConfig`)
- `lib/core/config/api_config.dart` manages endpoint URLs and runtime environment selection.
- Supports compile-time flags (`--dart-define=ENV=production|staging|local`) and in-app runtime overrides.
- Features automatic LAN IP detection (`192.168.1.49`) for seamless testing on physical Android and iOS devices over local Wi-Fi.
- Includes built-in `/health` latency ping diagnostics and persistence via `SharedPreferences`.

### HTTP Client (`ApiClient`)
- Centralized wrapper in `lib/core/services/api_client.dart`.
- Injects Supabase JWT bearer tokens automatically on all authenticated requests.
- Converts FastAPI error payloads (`{"detail": ...}`) into user-friendly localized messages.
- Manages multipart file uploads with image MIME-type correction.
