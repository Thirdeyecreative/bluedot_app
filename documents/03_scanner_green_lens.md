# 03 — Scanner / Green Lens — Engineering Reference

**Status:** 100% Complete & Fully Integrated  
**Last Updated:** 2026-11-04  
**Primary Endpoints:** `POST /api/v1/app/tags/scan`, `GET /api/v1/app/tags/history`  
**Cross-Reference:** [10_database_schema_trees.md](10_database_schema_trees.md) for database relationships, species encyclopedia deduplication, PostGIS spatial queries, and fun fact extraction.

---

## 1. Overview

The Green Lens scanner is BlueDot's signature AI-powered feature. It allows users to photograph trees and plants, identify their botanical species in real time using Vertex AI / PlantNet, verify geospatial coordinates against existing trees within 5 meters, record them to the global database, and earn gamification XP points.

### Source Files
- `lib/features/scanner/pages/green_lens_page.dart` — Full-screen scanner entry point, camera orchestration, and GPS capture.
- `lib/core/widgets/in_app_camera_page.dart` — High-performance custom camera widget with multi-angle capture guidance, pinch-to-zoom, and vertical slider.
- `lib/features/scanner/widgets/ai_analyzing_overlay.dart` — Animated backdrop while ML identification runs on the server.
- `lib/features/scanner/widgets/scan_result_sheet.dart` — Interactive bottom sheet displaying species match, confidence score, CO₂ absorption card, and points awarded.
- `lib/features/scanner/widgets/scan_history_detail_sheet.dart` — Reusable detail modal for examining past scans (shared with Profile and Eco Garden Map).
- `lib/features/scanner/data/scanner_repository.dart` — Network repository calling `ApiClient.multipartPost`.
- `lib/features/scanner/providers/scanner_provider.dart` — Riverpod providers (`scanResultProvider`, `scanHistoryProvider`, `mapTreesProvider`).
- `lib/features/scanner/models/scan_result_model.dart` — Models for `ScanResult`, `SpeciesInfo`, `PlantNetData`, and `ScanHistoryItem`.

---

## 2. Complete End-to-End Scan Flow

```
1. User taps Scanner FAB / Camera Icon
   ↓
2. GreenLensPage launches InAppCameraPage
   - Yellow animated instruction banner prompts for clear multi-angle photos
   - User captures 1 to 5 photos of leaves, bark, and overall tree structure
   - Supports pinch-to-zoom and vertical zoom slider
   ↓
3. Device captures GPS Coordinates via Geolocator.getCurrentPosition()
   ↓
4. AiAnalyzingOverlay appears with blurred background and dynamic analysis stages
   ↓
5. ScannerRepository sends Multipart POST to /api/v1/app/tags/scan
   - Includes lat, lng, and images[] list
   - Uses extended 75-second network timeout for server-side AI processing
   - Automatically injects Supabase JWT in Authorization header
   ↓
6. Backend Execution (bluedot_apis/app/api/v1/app/tags.py: scan_tree)
   a. get_current_user dependency decodes JWT and identifies AppUser
   b. identify_plant(image_bytes_list, db) runs Vertex AI / PlantNet identification
   c. 5-meter proximity check via PostGIS ST_DWithin:
      - Brand-New Tree: Awards +50 Impact Points
      - Verified Match (existing tree within 5m): Awards +15 Impact Points
   d. Auto-Publish threshold:
      - Confidence score >= 70%: Status set to 1 (Approved / Published)
      - Confidence score < 70%: Status set to 0 (Pending Review)
   e. Uploads images to CDN via MediaService.upload_files
   f. Extracts botanical fun facts and stores them in JSONB fun_facts column
   g. Updates user's total_impact_points and records to tagged_trees ledger
   ↓
7. Client receives ScanResult response and presents ScanResultSheet
   - Displays species local name and scientific name
   - Shows XP earned with celebration badge
   - Shows annual CO₂ absorption rating via Co2Card
   - Shows botanical taxonomy and fun facts
   - Tap "Save to Collection" closes the modal (tag is already committed on the backend)
```

---

## 3. API Specification

### `POST /api/v1/app/tags/scan` (`ApiConfig.scan`)
- **Headers:** `Authorization: Bearer <Supabase_JWT>`
- **Content-Type:** `multipart/form-data`
- **Fields:**
  - `lat` (float, required): Latitude coordinate
  - `lng` (float, required): Longitude coordinate
  - `images` (file list, required): 1 to 5 JPEG/PNG images

#### Response Structure:
```json
{
  "status": "new_tag",
  "message": "Congratulations! You discovered and tagged a new tree.",
  "tree_id": "uuid",
  "species_matched": true,
  "is_new_species": false,
  "points_awarded": 50,
  "total_points": 1370,
  "asset_url": "https://cdn.bluedot.eco/trees/...",
  "plantnet_data": {
    "scientific_name": "Azadirachta indica",
    "common_name": "Neem",
    "score": 0.89,
    "family": "Meliaceae"
  },
  "species": {
    "id": "uuid",
    "scientific_name": "Azadirachta indica",
    "local_name": "Neem",
    "co2_offset_factor": 21.77,
    "growth_time_years": 15,
    "fun_facts": [
      "Known as the 'Village Pharmacy' in Ayurvedic medicine.",
      "A single mature Neem tree absorbs over 20 kg of CO2 annually."
    ],
    "is_pending_review": false
  }
}
```

### `GET /api/v1/app/tags/history` (`ApiConfig.scanHistory`)
- **Headers:** `Authorization: Bearer <Supabase_JWT>`
- **Query Parameters:** `skip` (int, default 0), `limit` (int, default 20)
- **Response:** Paginated list of user's personal tagged trees with image URLs, coordinates, and species payload.

---

## 4. Riverpod Providers

Defined in `lib/features/scanner/providers/scanner_provider.dart`:

- **`scannerRepositoryProvider`** (`Provider<ScannerRepository>`):
  Injects `ApiClient` for network operations.
- **`scanResultProvider`** (`NotifierProvider<ScanResultNotifier, ScanResult?>`):
  Manages state for the current scan session. Exposes `.scan(images:, lat:, lng:)` and `.clear()`.
- **`scanHistoryProvider`** (`FutureProvider<List<ScanHistoryItem>>`):
  Fetches user's past scans. Caches history and displays in Profile page.
- **`mapTreesProvider`** (`FutureProvider<List<ScanHistoryItem>>`):
  Fetches community-tagged trees within the Bangalore bounding box (`_bangaloreBoxDegrees = 0.3`) for the Eco Garden Map.

---

## 5. Shared Components

### 1. `InAppCameraPage` (`lib/core/widgets/in_app_camera_page.dart`)
Reused by:
- Scanner feature (`GreenLensPage`)
- Action Hub feature (`SuggestSitePage`)

Features:
- Pinch-to-zoom gesture detection
- Custom vertical slider overlay
- Multi-photo filmstrip preview with delete controls
- Camera lens flip and flash controls

### 2. `ScanHistoryDetailSheet` (`lib/features/scanner/widgets/scan_history_detail_sheet.dart`)
Reused by:
- Profile page ("Recent Scans" row tap)
- Eco Garden Map page (Map marker pin tap)

Displays:
- Full thumbnail image with placeholder fallbacks
- Scientific name (italicized) and regional local name
- AI confidence match pill tag
- Botanical family pill tag
- Review status badge (`Pending review` vs `Approved`)
- Annual CO₂ absorption card
- Tagged timestamp and geospatial coordinates
