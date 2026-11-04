# 08 — Botanical Directory & Species Encyclopedia — Engineering Reference

**Status:** 100% Complete & Fully Integrated  
**Last Updated:** 2026-11-04  
**Primary Endpoints:** `GET /api/v1/app/directory`, `GET /api/v1/app/directory/{species_id}`  
**Cross-Reference:** [10_database_schema_trees.md](10_database_schema_trees.md) for TreeSpecies table architecture and deduplication.

---

## 1. Overview

The Botanical Directory is BlueDot's digital tree encyclopedia. It allows users to browse approved tree species, perform multi-field searches (local name, scientific name, botanical family, and native region), examine carbon offset metrics, and explore botanical fun facts.

### Source Files (`lib/features/directory/`)
- `pages/directory_page.dart` — Main encyclopedia grid with search header, extent-based responsive layout, and skeleton loaders.
- `pages/species_detail_page.dart` — Detailed species view: Hero photography, annual and lifetime CO₂ absorption math, taxonomy, and historical trivia.
- `providers/directory_provider.dart` — Riverpod providers (`searchQueryProvider`, `speciesListProvider`, `speciesDetailProvider`, `isFetchingMoreProvider`).
- `data/directory_repository.dart` — Network repository connecting to `ApiConfig.directoryData`.
- `models/species_model.dart` — `TreeSpecies` model parsing scientific names, local names, growth periods, and JSONB fun facts.

---

## 2. Live Backend Integration (`directory.py`)

Backend File: `bluedot_apis/app/api/v1/app/directory.py`

### Key Features:
- **Public Directory:** Only serves species with `status == STATUS_PUBLISHED (1)`. Pending review or soft-deleted species are excluded.
- **Multi-Field Server-Side Search:** If a search query is passed, the server performs an `ILIKE` search across:
  - `local_name`
  - `scientific_name`
  - `family`
  - `native_region`
- **Smart Search Unpagination:** When searching, the backend returns all matching records up to 500 items in a single response, avoiding fragmented pagination during active queries.
- **Alphabetical Pagination:** When browsing without search, the encyclopedia paginates with a default page size of 30 items ordered alphabetically by `local_name`.

---

## 3. API Specification

### 1. `GET /api/v1/app/directory` (`ApiConfig.directoryData`)
- **Query Parameters:**
  - `limit` (int, default: 30)
  - `offset` (int, default: 0)
  - `search` (string, optional)

#### Response Structure:
```json
{
  "data": [
    {
      "id": "uuid",
      "scientific_name": "Azadirachta indica",
      "local_name": "Neem",
      "co2_offset_factor": 21.77,
      "growth_time_years": 15,
      "fun_facts": [
        "Revered in Indian culture as a natural pharmacy.",
        "Repels harmful insects while keeping soil nutrient-rich."
      ],
      "image_urls": ["https://cdn.bluedot.eco/trees/neem.jpg"],
      "description": "A fast-growing evergreen tree native to the Indian subcontinent.",
      "family": "Meliaceae",
      "native_region": "Indian Subcontinent"
    }
  ],
  "pagination": {
    "total": 142,
    "limit": 30,
    "offset": 0,
    "is_search": false
  }
}
```

### 2. `GET /api/v1/app/directory/{species_id}`
- Returns full details for a single tree species.

---

## 4. Frontend Architecture & Riverpod State

Defined in `lib/features/directory/providers/directory_provider.dart`:

- **`searchQueryProvider`** (`NotifierProvider<SearchQueryNotifier, String>`):
  Holds the active search text entered in the search bar.
- **`speciesListProvider`** (`AsyncNotifierProvider<SpeciesListNotifier, List<TreeSpecies>>`):
  - Watches `searchQueryProvider`.
  - When the search string is non-empty, calls `fetchSpecies(search: query, limit: 500)` and disables pagination.
  - When browsing, loads page 1 (limit 30) and enables `loadMore()` for infinite scrolling.
- **`isFetchingMoreProvider`** (`NotifierProvider<IsFetchingMoreNotifier, bool>`):
  Indicates when subsequent pages are loading without triggering full-screen loading spinners.
- **`speciesDetailProvider`** (`FutureProvider.family<TreeSpecies, String>`):
  Loads a specific species by its UUID.

---

## 5. UI Components

### 1. `DirectoryPage` (`pages/directory_page.dart`)
- **SliverAppBar:** Features clean title with embedded search `TextField` with clear (`X`) button.
- **Responsive Grid:** Uses `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, childAspectRatio: 0.78)` to automatically scale from 2 columns on phones to 4+ columns on tablets.
- **Species Card (`_SpeciesCard`):**
  - High-resolution cached thumbnail with placeholder.
  - Local name in bold and italicized scientific name.
  - CO₂ offset pill badge: `'${co2OffsetFactor} kg CO₂/yr'`.
- **Skeleton Loader:** Shows `SkeletonGrid(count: 8)` during initial load.

### 2. `SpeciesDetailPage` (`pages/species_detail_page.dart`)
- **Hero Image:** Expandable `SliverAppBar` with high-resolution imagery.
- **Taxonomy Row:** Badges for Family, Growth Period (years), and Annual CO₂ absorption.
- **Lifetime Impact Card:** Dynamically computes `co2OffsetFactor * growthTimeYears` to explain total lifetime absorption.
- **Fun Facts Carousel:** Displays bulleted trivia stored in the species JSONB record.
