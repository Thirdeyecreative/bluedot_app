# 06 — Leaderboard Feature — Engineering Reference

**Status:** 100% Complete & Fully Integrated  
**Last Updated:** 2026-11-04  
**Primary Endpoint:** `GET /api/v1/app/leaderboard`  
**Backend Architecture:** PostgreSQL `RANK()` Window Function + Redis In-Memory Caching  

---

## 1. Overview

The Leaderboard provides real-time community engagement by ranking users globally based on their accumulated impact points. It highlights top environmental champions on an animated podium and enables infinite-scroll exploration through thousands of community members.

### Source Files
- `lib/features/profile/pages/leaderboard_page.dart` — Complete UI implementation: Top-3 podium, paginated list view, sticky user rank banner, and skeleton loading states.
- `lib/features/profile/providers/leaderboard_provider.dart` — Riverpod `AsyncNotifierProvider` managing pagination state, data fetching, deduplication, and caching.
- `lib/features/auth/providers/auth_provider.dart` — Supplies current user identity via `currentUserProvider`.
- Backend: `bluedot_apis/app/api/v1/app/leaderboard.py` — High-performance cached ranking API.

---

## 2. Backend Implementation (`leaderboard.py`)

### 1. High Performance & Scalability Guarantees
- **No N+1 Queries:** Total tree counts are computed via a single `LEFT JOIN` and `GROUP BY` across `app_users` and `tagged_trees`.
- **PostgreSQL Window Function:** Rank is calculated server-side using PostgreSQL's `RANK() OVER (ORDER BY total_impact_points DESC)` inside a subquery. Even a user ranked #50,000 gets their exact rank instantly without loading the entire table into Python memory.
- **Redis Caching:** Leaderboard pages are cached in Redis with a configurable TTL (`TTL_LEADERBOARD = 60s`).
- **Privacy & Security:** User UUIDs are never exposed in the response payload. The backend flags the requesting user with an `is_current_user: true` boolean, preventing user enumeration while allowing instant client-side highlighting.

### 2. Gamification Levels
Level titles are computed deterministically from total impact points:
- **Guardian:** ≥ 2,000 XP
- **Ranger:** 1,000 – 1,999 XP
- **Sapling:** 500 – 999 XP
- **Seedling:** 0 – 499 XP

---

## 3. API Specification

### `GET /api/v1/app/leaderboard` (`ApiConfig.leaderboard`)
- **Headers:** `Authorization: Bearer <token>` (Optional; required for `is_current_user` flag)
- **Query Parameters:**
  - `limit` (int, default: 30): Page size
  - `offset` (int, default: 0): Page offset

#### Response Structure:
```json
[
  {
    "rank": 1,
    "name": "Aarav Mehta",
    "city": "Mumbai",
    "points": 4280,
    "trees": 63,
    "level": "Guardian",
    "is_current_user": false
  },
  {
    "rank": 2,
    "name": "Nisha Rao",
    "city": "Pune",
    "points": 3860,
    "trees": 55,
    "level": "Ranger",
    "is_current_user": false
  },
  {
    "rank": 3,
    "name": "Avishkar",
    "city": "Bangalore",
    "points": 2450,
    "trees": 24,
    "level": "Guardian",
    "is_current_user": true
  }
]
```

---

## 4. Frontend Architecture (`leaderboard_provider.dart`)

### `LeaderboardNotifier` (`AsyncNotifierProvider`)
Manages continuous pagination with smooth user experience:
- Default page size: `_pageSize = 30`.
- Initial build fetches items `0` to `30`.
- Scroll trigger: `_onScroll` listens to `ScrollController` and calls `loadMore()` when the user scrolls within 400px of the bottom:
  ```dart
  if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
    ref.read(leaderboardProvider.notifier).loadMore();
  }
  ```
- **Deduplication:** When appending subsequent pages, entries are deduplicated by `rank` and re-sorted to prevent UI flickering.
- `isFetchingMoreLeaderboardProvider` indicates background loading without resetting the active list view.

---

## 5. UI Components (`leaderboard_page.dart`)

1. **Header:** Dark forest green app bar with back navigation and centered "Leaderboard" title.
2. **Top-3 Podium (`_Podium`):**
   - Renders 1st, 2nd, and 3rd rank users as elevated podium blocks.
   - 1st Place is centered and tallest with a golden crown icon.
   - Shows user avatar initial, name, level pill, and impact points (`$points XP`).
3. **Ranked List (`_LeaderList`):**
   - Displays ranks 4 and below in a card list.
   - Displays rank number, user name, tree count with eco leaf icon, level title, and points.
   - Current user's card is highlighted with a subtle accent background and a "(You)" indicator.
4. **Sticky Bottom Banner (`_CurrentUserBanner`):**
   - Fixed to the bottom of the viewport.
   - Shows the logged-in user's rank, avatar, and total XP.
   - Calculates the dynamic overtake gap: `"Earn N more XP to overtake <User Above>!"`
