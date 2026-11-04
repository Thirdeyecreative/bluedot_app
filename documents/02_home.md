# 02 — Home Feature — Engineering Reference

**Status:** Fully Wired to Live Backend  
**Last Updated:** 2026-11-04  
**Primary Endpoints:** `GET /api/v1/app/home-feed`, `GET /api/v1/app/blogs`, `GET /api/v1/app/campaigns`  

---

## 1. Overview

The Home screen serves as the core discovery hub for BlueDot. It delivers personalized impact greetings, promotional banners, upcoming plantation drives, active funding campaigns, and ecological educational blogs.

### Source Files (`lib/features/home/`)
- `pages/home_page.dart` — Main dashboard: Compact App Bar with dynamic time-based greeting, Hero Green Lens AI Tree Scanner Card, 4-Pillar Quick Action Hub, Promo Banners Carousel, Upcoming Drives carousel, Active Campaigns carousel, and Blogs grid.
- `pages/all_blogs_page.dart` — Full-page scrollable list of all published blogs with search and category filtering.
- `pages/blog_detail_page.dart` — Detail reading view for articles by slug (`/home/blog/:slug`).
- `pages/notifications_page.dart` — In-app notification center with read/unread tracking.
- `widgets/promo_banner_carousel.dart` — Auto-advancing banner slider with pagination indicators and target links.
- `providers/home_provider.dart` — Riverpod providers (`homeFeedProvider`, `blogsProvider`, `campaignsProvider`, `blogDetailProvider`, `notificationsProvider`).
- `data/home_repository.dart` — Network repository calling `ApiClient`.
- `models/banner_model.dart` — `AppBanner` with priority sorting and asset rendering.
- `models/blog_model.dart` — `BlogPost` parsing author, media, view counters, and reading time.
- `models/campaign_model.dart` — `Campaign` tracking fundraising goals, raised amounts, and progress percentages.

---

## 2. Page Sections & Backend Data Sources

| Section | Source | Detail |
|---|---|---|
| **Compact App Bar** | `currentUserProvider` | Shows user profile avatar (tappable to `/profile`), dynamic time greeting (`Good morning / afternoon / evening, {name}`), and notification bell with unread badge. |
| **Legal Consent Check** | `legalServiceProvider` | On initial mount, verifies `checkConsentStatus()`. If legal documents were updated, opens `PolicyUpdateSheet`. |
| **Green Lens Scanner Card** | **REAL** (`homeFeedProvider.tagline`) | Clean, grounded ecological action card with the official circular lens badge, server-driven tagline (`"Every Scan Plants a Story."`), and a dedicated 1-tap "Scan" trigger (`/scanner`). |
| **4-Pillar Quick Action Hub** | Navigation / Routes | Tactile 1-tap squircle shortcuts: Eco Garden (`/map`), Rankings (`/profile/leaderboard`), Suggest Site (`/action-hub/suggest-site`), Directory (`/directory`). |
| **Promo Banners Carousel** | **REAL** (`homeFeedProvider`) | Banners returned from `GET /api/v1/app/home-feed`. If no banners are present, the section gracefully collapses with zero layout artifacts, transitioning seamlessly into Upcoming Drives. |
| **Upcoming Events** | **REAL** (`homeFeedProvider`) | Displays upcoming plantation events with floating date badge, drive/upcoming status tag, spots left indicator, and duration. Tapping routes to `/action-hub/event/:id`. |
| **Active Campaigns** | **REAL** (`homeFeedProvider`) | Displays crowdfunding campaigns with live funding progress bars, goal pill, and raised amount. Tapping routes to `/action-hub/campaign/:id`. |
| **Stories & Updates (Blogs)** | **REAL** (`blogsProvider` / `homeFeedProvider`) | Displays latest published articles with multi-media count indicator, formatted dates, and authors. "See all" navigates to `/home/blogs` (`AllBlogsPage`), card tap navigates to `/home/blog/:slug`. |
| **Notifications** | Memory / State | `notificationsProvider` maintains read/unread status across the session. |

---

## 3. API Integrations

### 1. `GET /api/v1/app/home-feed` (`ApiConfig.homeFeed`)
Aggregated public feed endpoint. Combines all dashboard data into a single low-latency round-trip.

**Response Structure (`HomeFeedData`):**
```json
{
  "tagline": "Every Scan Plants a Story.",
  "banners": [
    {
      "id": "uuid",
      "title": "Plant for the Future",
      "subtitle": "Join our upcoming Bangalore drive",
      "image_url": "https://...",
      "target_link": "/action-hub/event/...",
      "display_order": 1
    }
  ],
  "campaigns": [
    {
      "id": "uuid",
      "title": "Western Ghats Reforestation",
      "target_amount": 500000.0,
      "current_amount_raised": 320000.0,
      "media_urls": ["https://..."]
    }
  ],
  "events": [
    {
      "id": "uuid",
      "title": "Cubbon Park Green Drive",
      "event_date": "2026-11-15T09:00:00Z",
      "site_name": "Cubbon Park, Bangalore",
      "media_urls": ["https://..."]
    }
  ],
  "blogs": [
    {
      "id": "uuid",
      "slug": "why-urban-forests-matter",
      "title": "Why Urban Forests Matter",
      "excerpt": "Discover how micro-forests cool metropolitan heat islands...",
      "author": "Dr. Ramesh Kumar",
      "media_urls": ["https://..."]
    }
  ]
}
```

### 2. `GET /api/v1/app/blogs` (`ApiConfig.appBlogs`)
- Supports query parameters: `page`, `limit`, and `search`.
- Returns paginated list of published `BlogPost` items for `AllBlogsPage`.

### 3. `GET /api/v1/app/blogs/{slug}` (`ApiConfig.appBlogDetail(slug)`)
- Returns the complete blog post content and media metadata for `BlogDetailPage`.

### 4. `GET /api/v1/app/campaigns` (`ApiConfig.campaigns`)
- Returns active fundraising campaigns.

---

## 4. Riverpod Providers

Defined in `lib/features/home/providers/home_provider.dart`:

- **`homeFeedProvider`** (`FutureProvider<HomeFeedData>`):
  Watches `homeRepositoryProvider.fetchHomeFeed()`. Powers the primary dashboard widgets.
- **`blogsProvider`** (`FutureProvider<List<BlogPost>>`):
  Watches `homeRepositoryProvider.fetchBlogs()`. Powers the blogs section and `AllBlogsPage`.
- **`campaignsProvider`** (`FutureProvider<List<Campaign>>`):
  Watches `homeRepositoryProvider.fetchCampaigns()`.
- **`blogDetailProvider`** (`FutureProvider.family<BlogPost, String>`):
  Loads a specific blog post by slug or ID.
- **`notificationsProvider`** (`NotifierProvider<NotificationsNotifier, List<AppNotification>>`):
  Tracks local notification feed state with `.markAllRead()` and `.markRead(id)`.
- **`unreadCountProvider`** (`Provider<int>`):
  Computed count of unread notifications for the app-bar notification badge.

---

## 5. Navigation Routes

Configured in `lib/core/router/app_router.dart`:
- `/home` — Dashboard root inside `StatefulShellBranch(0)`
- `/home/blogs` — `AllBlogsPage` (list of all articles)
- `/home/blog/:slug` — `BlogDetailPage` (article reader)
- `/notifications` — `NotificationsPage` (standalone full screen)
