# BlueDot Flutter Mobile Client 📱

This repository contains the Flutter mobile application codebase for the BlueDot Foundation environmental movement. It features **The Green Lens** (AI-powered botanical identifier), the **Eco Garden Map** (geospatial markers), **Boarding Pass Event Tickets**, **Botanical Encyclopedia**, and the **80G Tax Vault**.

---

## 📖 Feature & Technical Documentation

The mobile client maintains a comprehensive documentation suite inside the **[`documents/`](documents/)** directory:

| Document | Feature Scope |
|---|---|
| [00_overview.md](documents/00_overview.md) | **Master Index & Architecture Overview** |
| [01_auth.md](documents/01_auth.md) | **Supabase OTP Authentication, MSG91 DLT Hook & Complete Profile Flow** |
| [02_home.md](documents/02_home.md) | **Home Feed Dashboard, Promo Banners & Educational Blogs** |
| [03_scanner_green_lens.md](documents/03_scanner_green_lens.md) | **The Green Lens: Vertex AI Plant ID & 5m PostGIS Proximity Deduplication** |
| [04_eco_garden_map.md](documents/04_eco_garden_map.md) | **Eco Garden Map, GPS Live "Blue Dot" & Bangalore Bounding-Box Viewport** |
| [05_profile.md](documents/05_profile.md) | **User Account, Impact Stats, Settings, Notification Toggles & 80G Tax Vault** |
| [06_leaderboard.md](documents/06_leaderboard.md) | **Leaderboard: Redis Caching, PostgreSQL RANK() & Infinite Scroll Pagination** |
| [07_action_hub_events.md](documents/07_action_hub_events.md) | **Action Hub: Drives, RSVPs, Volunteering, QR Check-ins & Crowdsourced Sites** |
| [08_directory.md](documents/08_directory.md) | **Botanical Directory: Multi-Field Search & Species Encyclopedia** |
| [09_navigation.md](documents/09_navigation.md) | **Navigation: StatefulShellRoute, Custom CurvedNavBar & GoRouter Guards** |
| [10_database_schema_trees.md](documents/10_database_schema_trees.md) | **Database Schema: PostGIS Spatial Queries, Allocations & Species Relations** |
| [11_app_architecture_and_directory.md](documents/11_app_architecture_and_directory.md) | **Architecture Blueprint: Modular Feature-First Structure & Networking** |
| [12_legal_and_compliance.md](documents/12_legal_and_compliance.md) | **Legal & DPDP Compliance: Document Caching, Affirmative Consent & Privacy** |

> [!TIP]
> For backend API specifications and database triggers, also check the backend **[Documentation Hub](../bluedot_apis/Documentation/README.md)**.

---

## 🚀 Quick Start (Local Setup)

1. Ensure Flutter 3.x and Dart are installed on your machine (`flutter doctor`).
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

*To connect a physical device over local Wi-Fi, `ApiConfig` automatically routes to the developer machine LAN IP (`192.168.1.49`). Environment can also be configured at build time via `--dart-define=ENV=local|staging|production`.*
