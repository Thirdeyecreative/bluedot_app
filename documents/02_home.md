# Home Page — Current State

Scope: `lib/features/home/` in `bluedot_app`, cross-referenced with `lib/core/config/api_config.dart`, `lib/core/demo/demo_data.dart`, `lib/core/router/app_router.dart`, and backend `bluedot_apis/app/api/v1/app/` + `bluedot_apis/app/api/v1/admin/`.

## Files

- `pages/home_page.dart` (~970 lines) — main page: pinned scanner hero with accelerometer-driven tagline animation, vortex scroll effect, campaigns carousel, blogs grid, quick-action pills.
- `pages/blog_detail_page.dart` — reads `blogDetailProvider(slug)`, strips HTML tags from body, uses `SkeletonDetailPage` while loading.
- `pages/notifications_page.dart` — reads `notificationsProvider`, has `markAllRead()`; purely in-memory, no API call.
- `providers/home_provider.dart` — all home Riverpod providers.
- `data/home_repository.dart` — wraps `ApiClient`; only `fetchScanTagline()` hits a real endpoint, everything else returns `DemoData` after a fake 250ms delay (`_demoDelay()`).
- `models/blog_model.dart` — `BlogPost`: `id, slug, title, excerpt, bodyText, mediaUrls, author, publishedAt, linkedCampaignName, views` (parses snake_case keys); `thumbnailUrl` getter.
- `models/campaign_model.dart` — `Campaign`: `id, title, targetAmount, currentAmountRaised, description, mediaUrls, campaignStatus`; `progressPercent` getter clamped 0–1.
- `models/banner_model.dart` — `AppBanner`: `id, title, subtitle, imageUrl, placement`. **Bug**: `fromJson` reads `json['image']`, but the backend field is `image_url` — banners parsed from a real API response would silently lose their image.
- `models/notification_model.dart` — `AppNotificationType` enum (`drive, badge, campaign, certificate, system`); `AppNotification`: `id, type, title, body, timeLabel, read, route`.

## Page sections — real backend vs demo data

| Section | Source | Detail |
|---|---|---|
| Hero camera tagline | **REAL** | `HomeRepository.fetchScanTagline()` calls `GET /api/v1/app/config`, reads `json['scan_tagline']` |
| Banners carousel | **DEMO** | `bannersProvider` exists but is **not even watched** in `home_page.dart` — banner UI isn't rendered. Repository returns `DemoData.banners` (1 item) regardless. |
| Campaigns carousel | **DEMO** | `home_page.dart` watches `campaignsProvider`, but `HomeRepository` returns `DemoData.campaigns` (3 items) instead of calling an API |
| Blogs grid | **DEMO** | `home_page.dart` watches `blogsProvider`, but `HomeRepository` returns `DemoData.blogs` (3 items) instead of calling an API |
| Notifications | **DEMO** | `notificationsProvider` is a `Notifier` seeded directly from `DemoData.notifications`; no repository/API call involved at all |
| Stats | None found | No dedicated stats section was found in the home page code |

Note: `ApiConfig.campaigns`, `ApiConfig.blogs`, and `ApiConfig.banners` constants are all defined but **never called** anywhere in `home_repository.dart`. Also, `blogs`/`banners` constants point at **admin** routes (`/api/v1/admin/blogs`, `/api/v1/admin/content/banners`), which require admin auth — there are no public `/api/v1/app/*` endpoints for banners/blogs/campaigns. This is the structural reason these sections are still demo-backed: the public-facing endpoints they'd need don't exist yet.

## Exact API calls

| Call | Endpoint | Backend confirmation |
|---|---|---|
| `fetchScanTagline()` | `GET {baseUrl}/api/v1/app/config` (`ApiConfig.homeScreenConfig`) | `bluedot_apis/app/api/v1/app/config.py`: `@router.get("")` → mounted at `/app/config`; returns `DEFAULT_HOME_SCREEN_CONFIG` merged with stored settings, no Pydantic model |

No other home-feature repository methods make a network call — `fetchBanners`, `fetchBlogs`, `fetchCampaigns` (or equivalent) all short-circuit to `DemoData` after `_demoDelay()`.

### Hero tagline verification (confirmed)

- `home_repository.dart`: `static const _defaultScanTagline = 'Every Scan Plants a Story.';`
- `fetchScanTagline()` calls `_api.get(ApiConfig.homeScreenConfig)`, reads `json['scan_tagline']`, and falls back to `_defaultScanTagline` if the call fails.
- `home_provider.dart`: `scanTaglineProvider = FutureProvider<String>(...)` wraps this call.
- `home_page.dart`: `final tagline = ref.watch(scanTaglineProvider).value ?? 'Every Scan Plants a Story.';` — a second, duplicated hardcoded fallback string exists directly in the widget (in addition to the one in the repository), so the literal "Every Scan Plants a Story." appears in two places in the codebase.
- Backend confirms it: `bluedot_apis/app/api/v1/app/config.py`: `DEFAULT_HOME_SCREEN_CONFIG = {"scan_tagline": "Every Scan Plants a Story."}`, served via `@router.get("")` mounted at `/app/config`.

## Riverpod providers (`home_provider.dart` / `home_repository.dart`)

- `homeRepositoryProvider` — `Provider<HomeRepository>`
- `bannersProvider` — `FutureProvider<List<AppBanner>>`
- `blogsProvider` — `FutureProvider<List<BlogPost>>`
- `campaignsProvider` — `FutureProvider<List<Campaign>>`
- `scanTaglineProvider` — `FutureProvider<String>`
- `blogDetailProvider` — `FutureProvider.family<BlogPost, String>` (keyed by slug)
- `notificationsProvider` — `NotifierProvider<NotificationsNotifier, List<AppNotification>>`
- `unreadCountProvider` — `Provider<int>` (derived from `notificationsProvider`)

## Navigation

- Camera/scan CTA on home page routes to `/scanner` → `GreenLensPage` (`app_router.dart`: `GoRoute(path: '/scanner', builder: (__, _) => const GreenLensPage())`).
- Blog detail navigation: nested route `path: 'blog/:slug'` under `/home`, resolving to `/home/blog/:slug` → `BlogDetailPage(slug: state.pathParameters['slug']!)`.
- No campaign detail route exists anywhere in the router — tapping a campaign card (if wired) has nowhere dedicated to go yet.
- No banner detail/tap-through route found either.

## TODO / demo / mock comments found

No "TODO", "FIXME", "not yet", or "hardcoded" comments were found anywhere in `lib/features/home/`. All "demo" matches are direct `DemoData` usages rather than comments flagging future work:

- `home_provider.dart`: `import` of `DemoData`; notifications `Notifier.build()` returns `DemoData.notifications` directly.
- `home_repository.dart`: `import` of `DemoData`; `_demoDelay()` helper (250ms artificial delay); `fetchBanners`/`fetchBlogs`/`fetchCampaigns`-equivalent methods each do `await _demoDelay(); return DemoData.x;`.

## Backend route reference

- `app/api/v1/app/config.py`: `@router.get("")` → `GET /api/v1/app/config`, raw dict response, no request/response Pydantic model.
- `app/api/v1/admin/content.py`: `@router.get("/banners", response_model=BannerListResponse)` plus POST/PATCH/DELETE/PUT-reorder; `BannerResponse` fields: `id, title, subtitle, image_url, placement, is_published, target_link, linked_campaign_id, linked_campaign_name, display_order, views, clicks, status, published_at, created_at, updated_at`.
- `app/api/v1/admin/blogs.py`: `@router.get("", response_model=BlogListResponse)` plus POST/GET-by-id/PATCH/DELETE/PUT-reorder; `BlogResponse` fields: `id, slug, title, body_text, media_urls, is_published, author, excerpt, linked_campaign_id, linked_campaign_name, published_at, created_at, updated_at, status, views, clicks, display_order`.
- Both blogs and banners are stored in a single `AppContent` table, differentiated by a `content_type` column — both are admin-managed content, not yet exposed via a public app-facing endpoint.
