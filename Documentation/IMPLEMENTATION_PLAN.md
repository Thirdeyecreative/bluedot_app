# BlueDot Full-Stack Integration & Gamification Plan

This plan details the full-stack architecture and implementation path to connect the **BlueDot** Native Flutter mobile client with the **FastAPI** backend, database, and admin infrastructure. 

BlueDot is built to be the *"Apple of Environmental Action"*—incorporating magical visual assets, a dark/cream tactile layout, geospatial telemetry, and offline-to-online (O2O) verification.

---

## Approved Design Decisions & Regulatory Compliance

> [!NOTE]
> **Frictionless Onboarding & Delayed PAN**: The onboarding flow is confirmed to be 100% frictionless (Name, City, Phone only). The PAN card is exclusively prompted via a secure bottom sheet just before checkout to unlock their 80G tax benefit, preventing signup drop-off.
>
> **Razorpay Custom UI Integration**: Confirmed to use the Razorpay Custom UI overlay to keep the payment experience native and premium. The overlay will inject Studio IKIGAI brand colors: Primary Blue (`#3C4FAF`) buttons and Off-White (`#F3ECD9`) base backgrounds.
>
> **Ghost User Verification**: Confirmed that phone verification via OTP triggers the automated, transaction-gated merging of historical offline donations (Name, Phone matching) with newly registered user profiles, retroactively awarding XP and badge completions.
>
> **PostGIS ST_DWithin Proximity Limits**: Confirmed the 5-meter proximity limit to distinguish new tree tagging (+50 XP) from verifying existing trees (+15 XP), preventing point-farming.
>
> **Eco Garden Map Polygons**: Confirmed the use of CartoDB Positron tiles mapped with transparent Forest Green (`#566D5B` at 14% opacity) site polygons and glowing yellow markers.

---

## Proposed Changes

We group the components by technical layer: Database (PostGIS), Backend API (FastAPI), Mobile App (Flutter), and Admin Panel (React).

---

### 🗄️ 1. Geospatial Database (Supabase + PostGIS)

#### [MODIFY] [tracking.py](file:///c:/Users/avish/OneDrive/Desktop/Third%20Eye/BlueDot/bluedot_apis/app/models/tracking.py)
Ensure that spatial indexing (`GIST`) is explicitly configured on the `location_coords` column.

#### [NEW] [2026_06_12_postgis_polygons.sql](file:///c:/Users/avish/OneDrive/Desktop/Third%20Eye/BlueDot/bluedot_apis/migrations/2026_06_12_postgis_polygons.sql)
Add support for plantation site polygon boundaries rather than single coordinates.
- Creates `plantation_sites` table with a `boundary_polygon` geometry column (type `POLYGON`, SRID `4326`).
- Adds database triggers to count and cache `trees_planted` inside a polygon automatically whenever a `tagged_tree` location falls within a site boundary.

---

### 🐍 2. Backend API Services (FastAPI)

#### [NEW] [ghost_user_service.py](file:///c:/Users/avish/OneDrive/Desktop/Third%20Eye/BlueDot/bluedot_apis/app/services/ghost_user_service.py)
Implements matching logic when a new user registers:
- Scans `donations` and `tagged_trees` tables for any pre-existing records matched by `phone` (created by the Admin Panel offline CSV uploads).
- Links those transactions and tags to the newly created `AppUser.id`.
- Re-calculates `total_impact_points` (XP) and marks qualifying badges as unlocked.

#### [NEW] [receipt_pdf_service.py](file:///c:/Users/avish/OneDrive/Desktop/Third%20Eye/BlueDot/bluedot_apis/app/services/receipt_pdf_service.py)
- Implements automated, ACID-compliant PDF generation for Section 80G tax deductions.
- Integrates with Bunny.net storage to upload and secure files, returning sign-restricted public CDN URLs.

#### [MODIFY] [tags.py](file:///c:/Users/avish/OneDrive/Desktop/Third%20Eye/BlueDot/bluedot_apis/app/api/v1/app/tags.py)
- Integrate the proximity check with 5-meter limits (`ST_DWithin`) to verify whether a plant scan is a new tag (+50 XP) or an existing tag verification (+15 XP).
- Call Pl@ntNet API and query `TreeSpecies` for local-to-scientific name correlation.

---

### 📱 3. Native Mobile Client (Flutter)

#### [MODIFY] [api_config.dart](file:///c:/Users/avish/OneDrive/Desktop/Third%20Eye/BlueDot/bluedot_app/lib/core/config/api_config.dart)
Define all required mobile endpoints, pointing to the FastAPI gateway:
- `/api/v1/auth/send-otp` (Phone input)
- `/api/v1/auth/verify-otp` (OTP verification)
- `/api/v1/app/tags/scan` (The Green Lens camera post)
- `/api/v1/app/tags/history` (User scan history list)
- `/api/v1/app/donations` (Razorpay transactions)
- `/api/v1/app/suggestions` (GPS location suggestion form)

#### [MODIFY] [app_colors.dart](file:///c:/Users/avish/OneDrive/Desktop/Third%20Eye/BlueDot/bluedot_app/lib/core/constants/app_colors.dart)
Maintain alignment with **Studio IKIGAI** palettes:
- `primaryBlue` = `#3c4faf`
- `primaryYellow` = `#e8bb49`
- `offWhiteBase` = `#f3ecd9` (never pure `#ffffff` for screen backgrounds)
- `darkGrey` = `#3d3d3d`
- `forestGreen` = `#566d5b`
- `terracotta` = `#de977b`
- `slateBlue` = `#6f7da2`
- `sageGreen` = `#8ea8a7`

#### [NEW] [boarding_pass_widget.dart](file:///c:/Users/avish/OneDrive/Desktop/Third%20Eye/BlueDot/bluedot_app/lib/features/action_hub/widgets/boarding_pass_widget.dart)
- Renders the digital event pass using an airline boarding card motif.
- Implements custom layouts with a dashed line separator, circular ticket notch cuts, and high-contrast black-on-white QR codes for outdoor readability.

#### [NEW] [eco_garden_map_page.dart](file:///c:/Users/avish/OneDrive/Desktop/Third%20Eye/BlueDot/bluedot_app/lib/features/map/pages/eco_garden_page.dart)
- Full-screen map using `flutter_map` with clean **CartoDB Positron** tiles.
- Renders site polygons dynamically (fetched from `/api/v1/app/sites`) using transparent Forest Green fills (#566D5B at 14% opacity).
- Renders individual user trees as small glowing yellow icons.

---

### 💻 4. Admin Dashboard (React + Tailwind CSS)

#### [MODIFY] [Blogs.jsx](file:///c:/Users/avish/OneDrive/Desktop/Third%20Eye/BlueDot/bluedot_admin_panel/frontend/src/pages/Blogs.jsx)
- Ensure the Mobile Preview container rendering matches the Flutter client styles, applying the precise Studio IKIGAI fonts and color schemas for content staging.

---

## Verification Plan

### Automated Tests
Run backend API tests targeting authentication, PostGIS proximity queries, and transaction rollbacks:
```powershell
cd "c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_apis"
pytest tests/
```

Verify Flutter app compilation and check static code quality:
```powershell
cd "c:\Users\avish\OneDrive\Desktop\Third Eye\BlueDot\bluedot_app"
flutter analyze
flutter test
```

### Manual Verification
1. **Ghost User Linking**: Upload an offline donation with phone number `+91 9999999999` in the Admin Dashboard. Log in on the Mobile App with the same phone. Verify the donation details and tree credits load instantly in the tax vault and profile.
2. **Proximity Tagging**: Simulate scanning a tree at coordinates `(19.0760, 72.8777)`. Re-scan at `(19.0761, 72.8778)` (within 5 meters). Verify that the backend flags the second scan as `status: verified` and rewards 15 XP rather than creating a new node.
3. **Boarding Pass Visibility**: Load the event QR code, trigger high-brightness layout toggles, and verify physical scanning using a standard QR reader.
