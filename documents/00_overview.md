# BlueDot App — Documentation Index

This folder documents the **current, actual state** of the BlueDot Flutter app
(`bluedot_app/`), based on a direct read of the source code as of 2026-06-18.
It is intentionally honest about what is wired to the real backend
(`bluedot_apis`) versus what still runs on local demo/mock data
(`lib/core/demo/demo_data.dart`). Where a doc says "appears to," the underlying
agent could not fully confirm that detail from code alone.

## Feature docs

| File | Feature | Backend status (short) |
|---|---|---|
| [01_auth.md](01_auth.md) | Login / OTP / splash | **Fully mocked.** No real HTTP calls; backend has no matching routes either. |
| [02_home.md](02_home.md) | Home page, banners, blogs, campaigns, scan tagline | Mixed: scan tagline is real (`GET /app/config`); banners/blogs/campaigns are demo-only (no public backend routes exist for them). |
| [03_scanner_green_lens.md](03_scanner_green_lens.md) | Camera, AI plant ID scan, scan history | **Fully real backend.** `POST /app/tags/scan`, `GET /app/tags/history`. |
| [04_eco_garden_map.md](04_eco_garden_map.md) | Eco Garden map | **Mostly real backend** (`GET /app/tags/map`), with one hardcoded stat ("Your Trees" = 0). |
| [05_profile.md](05_profile.md) | Profile, quick actions, badges, certificates, settings | **Mostly mocked.** Only "Recent Scans" is real; everything else is `DemoData` or local-only state. |
| [06_leaderboard.md](06_leaderboard.md) | Leaderboard | **Fully mocked**, and the backend has no `/leaderboard` route at all. |
| [07_action_hub_events.md](07_action_hub_events.md) | Events, suggest site, check-in/out, volunteering | **Mostly real backend.** Donation sheet is UI-only. |
| [08_directory.md](08_directory.md) | Tree species directory | **Fully mocked.** Backend admin trees route exists but is unconnected. |
| [09_navigation.md](09_navigation.md) | Bottom nav / app shell / router | Structural — not data-backed; documents routes and the auth-redirect guard. |
| [10_database_schema_trees.md](10_database_schema_trees.md) | **Database schema: Tree tagging, allocations, species encyclopedia, fun facts** | **Fully real backend.** Complete relationship diagram, data flows, proximity logic, fun facts extraction & storage. |

## Architecture summary

- **State management:** Riverpod (`flutter_riverpod`). Each feature has its own
  providers/repositories; most repositories wrap either real `ApiClient` calls
  or, currently, `DemoData` lookups behind an artificial delay to simulate
  network latency.
- **Navigation:** `go_router`, configured under `lib/core/router/`. A `ShellRoute`
  hosts the bottom-nav tabs (`/home`, `/action-hub`, `/directory`, `/profile`);
  auth-related routes (`/splash`, `/login`, `/otp`) sit outside the shell. The
  router has a redirect guard that sends unauthenticated users to `/login` and
  authenticated users away from auth routes to `/home` (see `09_navigation.md`
  for exact logic and exemptions).
- **API configuration:** `lib/core/config/api_config.dart` selects a base URL
  per build-time `--dart-define=ENV=...` flag (`local` / `staging` /
  `production`, defaulting to `staging`), then exposes endpoint getters under
  two namespaces: `/api/v1/app/*` (end-user app routes) and `/api/v1/admin/*`
  (admin-authored content served publicly, e.g. blogs/banners/trees/badges).
  Several of these getters are **dead config** — defined but never called by
  any current UI, or pointing at backend routes that don't exist yet (see the
  per-feature docs and the table above).
- **HTTP client:** `lib/core/services/api_client.dart` wraps `package:http`
  with: bearer-token injection from `StorageService`, a 30s default timeout
  (overridable, e.g. scan upload uses a longer timeout), multipart upload
  support with image MIME-type correction, and centralized error handling.
  `ApiException` carries a `message` + `statusCode`; `_extractMessage` parses
  FastAPI's `{"detail": ...}` (string or validation-error list) and falls back
  to friendly per-status-code defaults (401 -> "session expired", 404, 429,
  5xx, etc.) so callers never see raw exceptions or socket errors.
- **Demo data:** `lib/core/demo/demo_data.dart` is the single source of truth
  for everything still mocked — auth OTP/user, banners, campaigns, blogs,
  notifications, leaderboard, badges, certificates, and tree species. As the
  backend grows real public routes, repositories should be swapped from
  `DemoData.*` to `ApiClient` calls one at a time; each feature doc flags
  exactly which repository methods need that swap.

## Most important cross-cutting finding

A large fraction of "API endpoints" defined in `api_config.dart` are not
actually called anywhere in the UI yet (campaigns, blogs, banners, trees,
badges, gamificationRules, leaderboard, donations in some flows), and a few
that *are* called point at backend routes that don't exist yet (auth, profile,
leaderboard). Treat `api_config.dart` as a superset of planned + partially
implemented endpoints, not a confirmation that a feature is live. Each
feature doc states explicitly, section by section, whether what's on screen
came from a real HTTP response or from `DemoData`.
