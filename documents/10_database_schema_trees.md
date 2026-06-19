# Database Schema: Tree Tagging, Allocations & Species Encyclopedia

**Status:** All features implemented with real backend APIs  
**Last updated:** 2026-06-19  
**Database:** PostgreSQL with PostGIS (geospatial queries), JSONB columns

---

## Complete Database Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                           DATABASE SCHEMA                           │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────────────┐
│     app_users        │
├──────────────────────┤
│ id (UUID) [PK]       │
│ full_name            │
│ email                │
│ phone                │
│ city                 │
│ total_impact_points  │◄─── Incremented by +50 (new tag) or +15 (verified)
│ tags (JSONB)         │
│ streak_count         │
│ created_at           │
└──────────────────────┘
        │
        │ (1:Many)
        │
        ├────────────────────┬──────────────────────┐
        │                    │                      │
        ▼                    ▼                      ▼
┌──────────────────────┐  ┌──────────────────────┐ ┌──────────────────────┐
│   tagged_trees       │  │ user_tree_           │ │ donations, occasions │
│ (SCANNED TREES)      │  │ allocations          │ │ events, badges, etc. │
├──────────────────────┤  ├──────────────────────┤ └──────────────────────┘
│ id (UUID) [PK]       │  │ id (UUID) [PK]       │
│ user_id [FK]         │  │ user_id [FK] ────────┘
│ species_id [FK] ─────┼──┤ site_id [FK]         │
│ location_coords ◄────┤  │ species_id [FK] ─────┼──┐
│  (POINT geometry)    │  │ quantity (integer)   │  │
│ image_url            │  │ allocated_at         │  │
│ image_urls (JSONB)   │  └──────────────────────┘  │
│ plantnet_data (JSONB)│           │                │
│ tagged_at            │           │ (1:Many)       │
└──────────────────────┘           │                │
        │                          ▼                │
        │                  ┌──────────────────────┐ │
        │ (Many:1)         │ plantation_sites     │ │
        │                  ├──────────────────────┤ │
        └─────────────────▶│ id (UUID) [PK]       │ │
                           │ site_name            │ │
                           │ boundary_polygon     │ │
                           │ trees_planted        │ │
                           └──────────────────────┘ │
                                                    │
┌──────────────────────────────────────────────────┘
│
▼
┌──────────────────────┐
│   tree_species       │
│ (THE ENCYCLOPEDIA)   │
├──────────────────────┤
│ id (UUID) [PK]       │
│ scientific_name      │
│ local_name           │
│ co2_offset_factor    │
│ growth_time_years    │
│ image_urls (JSONB)   │
│ fun_facts (JSONB)    │◄─── {"facts": ["fact1", "fact2", ...]}
│ status               │◄─── published (1), pending review (2), deleted (0)
└──────────────────────┘
        ▲
        │ (Many:1)
        │ via species_id
        │
        ├── Referenced by tagged_trees
        │
        └── Referenced by user_tree_allocations
```

---

## Key Relationships Explained

### 1. User → Tagged Trees (Scanning Feature)
When a user scans a tree using the in-app camera:

```
User scans a tree at a location
    ↓
Creates TaggedTree entry:
  - user_id: which user scanned
  - species_id: what species (links to TreeSpecies encyclopedia)
  - location_coords: where scanned (POINT geometry with lat/lng)
  - plantnet_data: AI confidence, PlantNet response JSON
  - image_url: first image URL from CDN
  - image_urls: array of all uploaded image URLs
  - tagged_at: when scanned (timestamp)
    ↓
User gets +50 impact points (new tag) or +15 (verified same species within 5m)
User's total_impact_points incremented
```

**API Endpoint:** `POST /api/v1/app/tags/scan`
- Request: `lat`, `lng`, `images[]` (multipart form)
- Response: scan result with status, points, species payload, fun facts

**Retrieval:** `GET /api/v1/app/tags/history` (user's scan history)

---

### 2. User → Tree Allocations (Planting Feature)
When a user is allocated trees at a plantation event/site:

```
User participates in plantation event at a site
    ↓
Creates UserTreeAllocation entry:
  - user_id: which user participated
  - site_id: which plantation site
  - species_id: what species they're planting
  - quantity: how many of that species (e.g., 5 Neem trees)
  - allocated_at: when allocated (timestamp)
    ↓
Tied to PlantationSite for geospatial context
```

**Tables involved:**
- `user_tree_allocations`: the allocation record
- `plantation_sites`: the event/site location (boundary_polygon for geospatial queries)
- `tree_species`: the species being planted

---

### 3. TreeSpecies — The Encyclopedia (Single Source of Truth)
The `tree_species` table is a shared, deduplicated encyclopedia of all plant species:

```
Single TreeSpecies record per species:
  - scientific_name: "Azadirachta indica" (unique identifier)
  - local_name: "Neem"
  - co2_offset_factor: 21.77 kg/year (used for impact calculations)
  - growth_time_years: 15 years (maturity estimate)
  - image_urls: [url1, url2, ...] (JSONB array)
  - fun_facts: {"facts": ["Used for 5000+ years...", "Attracts bees..."]} (JSONB)
  - status: published (1) | pending review (2) | deleted (0)

This ONE species record is NEVER DUPLICATED:
  ├─ Referenced by many TaggedTrees
  │   Example: User A scans Neem at Location X
  │           User B scans Neem at Location Y (10km away)
  │           → Both TaggedTree records point to the SAME TreeSpecies
  │
  └─ Referenced by many UserTreeAllocations
      Example: User A allocated 5 Neem at Site 1
              User B allocated 10 Neem at Site 2
              → Both allocation records point to the SAME TreeSpecies
```

**Key column: status**
- `1` (published): Species is live in the Tree Encyclopedia, available for display
- `2` (pending_review): Auto-created from AI scan, awaiting admin review/approval
- `0` (deleted): Species removed (soft delete)

---

## Complete Data Flow: Tree Scanning Example

### Scenario: User Scans Neem at Two Different Locations

```
STEP 1: First Scan at Location X (12.9716, 77.5946)
═════════════════════════════════════════════════════════════════

User action: Opens camera → Takes photo → Submits scan
  
Backend processing:
  1. Vertex AI identifies species: "Azadirachta indica" (Neem)
  2. Extracts fun facts: ["Used for 5000+ years in Ayurveda...", "Natural pesticide...", ...]
  3. Checks if species exists in tree_species table → NOT FOUND
  
Database changes:
  
  TreeSpecies created (NEW):
    ├─ id: species-neem-456
    ├─ scientific_name: "azadirachta indica"
    ├─ local_name: "Neem"
    ├─ co2_offset_factor: 21.77
    ├─ growth_time_years: 15
    ├─ fun_facts: {"facts": ["Used for 5000+ years...", "Natural pesticide..."]}
    └─ status: 2 (pending_review) ← Admin must approve before going live
  
  TaggedTree created (NEW):
    ├─ id: tag-neem-001
    ├─ user_id: user-avish-123
    ├─ species_id: species-neem-456
    ├─ location_coords: SRID=4326;POINT(77.5946 12.9716)
    ├─ image_url: "https://cdn.bluedot.io/scans/neem-001.jpg"
    ├─ image_urls: ["https://cdn.bluedot.io/scans/neem-001.jpg"]
    ├─ plantnet_data: {"results": [...], "is_plant": true, "fun_facts": [...]}
    └─ tagged_at: 2026-06-19T10:30:00Z
  
  AppUser updated:
    ├─ id: user-avish-123
    └─ total_impact_points: 0 → +50 = 50

Response to app:
  {
    "status": "new_tag",
    "message": "New tree tagged successfully! 50 points awarded.",
    "tree_id": "tag-neem-001",
    "is_new_species": true,
    "points_awarded": 50,
    "total_points": 50,
    "species": {
      "id": "species-neem-456",
      "scientific_name": "azadirachta indica",
      "local_name": "Neem",
      "co2_offset_factor": 21.77,
      "fun_facts": ["Used for 5000+ years...", "Natural pesticide..."],
      "is_pending_review": true
    }
  }


STEP 2: Second Scan at Location Y (12.6716, 77.2946) — 10km away
═════════════════════════════════════════════════════════════════

User action: Opens camera → Takes photo → Submits scan

Backend processing:
  1. Vertex AI identifies species: "Azadirachta indica" (Neem) again
  2. Extracts same fun facts (cached or re-extracted)
  3. Checks if species exists → FOUND (from Step 1)
  
Database changes:

  TreeSpecies: ❌ NOT CREATED AGAIN (reused!)
    ├─ id: species-neem-456 (SAME as Step 1)
    └─ fun_facts: (UNCHANGED — not duplicated!)
  
  Proximity check: "Any Neem tagged within 5 meters of (12.6716, 77.2946)?"
    └─ Result: NO (previous scan was 10km away)
  
  TaggedTree created (NEW):
    ├─ id: tag-neem-002 (DIFFERENT ID)
    ├─ user_id: user-avish-123 (SAME user)
    ├─ species_id: species-neem-456 (SAME species, NO duplication!)
    ├─ location_coords: SRID=4326;POINT(77.2946 12.6716) (DIFFERENT location)
    ├─ image_url: "https://cdn.bluedot.io/scans/neem-002.jpg" (DIFFERENT image)
    ├─ image_urls: ["https://cdn.bluedot.io/scans/neem-002.jpg"]
    ├─ plantnet_data: {...}
    └─ tagged_at: 2026-06-19T11:30:00Z
  
  AppUser updated:
    ├─ id: user-avish-123
    └─ total_impact_points: 50 → +50 = 100

Response to app:
  {
    "status": "new_tag",
    "message": "New tree tagged successfully! 50 points awarded.",
    "tree_id": "tag-neem-002",
    "is_new_species": false,
    "points_awarded": 50,
    "total_points": 100,
    "species": {
      "id": "species-neem-456",
      "scientific_name": "azadirachta indica",
      "local_name": "Neem",
      "co2_offset_factor": 21.77,
      "fun_facts": ["Used for 5000+ years...", "Natural pesticide..."],  ← Same facts!
      "is_pending_review": true
    }
  }

RESULT:
═══════
  - 1 AppUser entry (avish)
  - 1 TreeSpecies entry (Neem) ← NO DUPLICATION!
  - 2 TaggedTree entries (both Neem, different locations)
  - User has 100 total impact points
  - All users viewing same species see cached fun facts
```

---

## Proximity Logic (Anti-Duplication)

The scanning endpoint prevents duplicate pins for the same species in the same location:

```python
# STEP 3: Has *this same species* already been tagged within 5m of here?
proximity_query = db.query(TaggedTree).filter(
    TaggedTree.species_id == species_record.id,  # ← Same species
    func.ST_DWithin(
        func.Geography(TaggedTree.location_coords),
        func.Geography(func.ST_GeomFromText(point_wkt, 4326)),
        5  # ← Within 5 meters
    )
).first()

if proximity_query:
    # Same species, same spot → Don't create duplicate
    current_user.total_impact_points += 15  # Verification points
    return {"status": "verified", "message": "This tree was already tagged here..."}
```

**Three scenarios:**

| Scenario | Same Species? | Within 5m? | Result | Points |
|----------|---------------|-----------|--------|--------|
| Different species, same spot | NO | YES | New TaggedTree pin | +50 (new_tag) |
| Same species, different spot (>5m) | YES | NO | New TaggedTree pin | +50 (new_tag) |
| Same species, same spot (<5m) | YES | YES | **Verified** (no new pin) | +15 (verified) |

---

## Fun Facts Storage & Retrieval

### Storage (Database)

The `fun_facts` column in `tree_species` stores facts in JSONB format:

```json
{
  "facts": [
    "Used for 5,000+ years in Ayurvedic medicine for various ailments",
    "Natural pesticide properties make it valuable for organic farming",
    "Attracts honeybees, supporting pollinator populations",
    "Can grow up to 15-20 meters tall with a lifespan of 200+ years",
    "In Indian culture, considered sacred and planted near temples"
  ]
}
```

### Extraction (Vertex AI)

When Vertex AI (Gemini) identifies a species, the system prompt instructs it to extract 3–5 interesting, educational facts:

```
"Additionally, extract 3-5 interesting, educational fun facts about the identified species.
Choose facts that are engaging and informative, such as: medicinal uses, unique growth patterns,
wildlife attraction properties, cultural significance, historical uses, or other distinctive characteristics.
Each fact should be a clear, concise statement suitable for a general audience."
```

The response schema includes:

```python
"fun_facts": {
    "type": "ARRAY",
    "items": {"type": "STRING"},
},
```

### Retrieval (API Response)

When the app calls `GET /api/v1/app/tags/history` or receives a `/tags/scan` response, the `_species_payload()` function extracts facts:

```python
def _species_payload(species: Optional[TreeSpecies]) -> Optional[dict]:
    if not species:
        return None
    fun_facts = []
    if species.fun_facts and isinstance(species.fun_facts, dict):
        fun_facts = species.fun_facts.get("facts", [])
    return {
        "id": species.id,
        "scientific_name": species.scientific_name,
        "local_name": species.local_name,
        "co2_offset_factor": float(species.co2_offset_factor),
        "growth_time_years": species.growth_time_years,
        "image_urls": species.image_urls or [],
        "fun_facts": fun_facts,  # ← Array of strings
        "is_pending_review": species.status == TreeSpecies.STATUS_PENDING_REVIEW,
    }
```

### Display (Flutter UI)

The Flutter app receives facts in the `SpeciesInfo.funFacts` field and displays them in the `FunFactsCard` widget:

```dart
class SpeciesInfo {
  final List<String> funFacts;  // e.g., ["Used for 5000+ years...", ...]
}

// In scan_result_sheet.dart:
if (species?.funFacts.isNotEmpty == true)
  FunFactsCard(facts: species!.funFacts)
      .animate()
      .fadeIn(delay: 350.ms)
      .slideY(begin: 0.06, end: 0),
```

The `FunFactsCard` renders facts as a bulleted list with a lightbulb icon in a blue-themed card.

---

## Three Separate Concepts

| Concept | Table | Purpose | Cardinality | Example |
|---------|-------|---------|------------|---------|
| **User Trees Tagged** | `tagged_trees` | Records of individual scans by users; map pins | User (1:Many) | User scans Neem at X, then Mango at Y → 2 pins |
| **User Tree Allocations** | `user_tree_allocations` | Trees user is allocated to plant at events | User (1:Many) | User allocated 5 Neem at Site A, 10 Neem at Site B |
| **Tree Species Directory** | `tree_species` | Encyclopedia of all species metadata; shared, deduplicated | Single record per species | Neem is one entry, referenced by all Neem scans & allocations |

**Key insight:** TreeSpecies is **never duplicated**. It's a single source of truth referenced by all scans, allocations, and fun facts.

---

## API Endpoints Summary

| Endpoint | Method | Purpose | Status |
|----------|--------|---------|--------|
| `/api/v1/app/tags/scan` | POST | Submit plant scan (image + location) | ✅ Real backend |
| `/api/v1/app/tags/history` | GET | Retrieve user's scan history | ✅ Real backend |
| `/api/v1/app/tags/map` | GET | Retrieve tagged trees in bounding box (for map) | ✅ Real backend |

---

## Database Migration

A migration was created to add the `fun_facts` JSONB column:

```
File: alembic/versions/d4e5f6a7b8c9_add_fun_facts_to_tree_species.py
Revision ID: d4e5f6a7b8c9
Revises: c3d4e5f6a7b8

Adds:
  fun_facts JSONB column to tree_species table
  Server default: '{"facts": []}'::jsonb
```

Run with:
```bash
alembic upgrade head
```

---

## Summary

✅ **No TreeSpecies duplication** — single encyclopedia entry per species
✅ **No TaggedTree duplication** — proximity check prevents same-species within-5m pins
✅ **Fun facts extraction** — Vertex AI extracts 3–5 facts, stored in JSONB, shared across all users
✅ **Impact points** — +50 for new tag, +15 for verified (same species, same spot)
✅ **Geospatial indexing** — PostGIS POINT geometry for efficient location queries
✅ **API responses** — Full species payload including fun facts in all scan-related endpoints
