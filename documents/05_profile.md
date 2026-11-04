# 05 — Profile & User Account — Engineering Reference

**Status:** 100% Complete & Fully Integrated  
**Last Updated:** 2026-11-04  
**Primary Endpoints:** `GET /api/v1/app/profile`, `PUT /api/v1/app/profile`, `POST /api/v1/app/profile/avatar`, `GET /api/v1/app/profile/certificates`, `GET /api/v1/app/tags/history`  

---

## 1. Overview

The Profile module manages user identity, gamification levels, impact statistics, volunteer certifications, achievements (badges), personal scan history, and account settings (including PAN management, 80G Tax Vault, and runtime server configurations).

### Source Files (`lib/features/profile/`)
- `pages/profile_page.dart` — Main profile dashboard: Avatar, user level, XP progress bar, impact statistics row, quick action cards, badges showcase, and recent scans.
- `pages/badges_page.dart` — Complete badge showcase with unlocked/locked states and requirements.
- `pages/leaderboard_page.dart` — Real-time paginated global leaderboard with podium rankings.
- `pages/certificates_page.dart` — Volunteer achievement certificates list and download viewer.
- `pages/edit_profile_page.dart` — Full name, email, and city editing form.
- `pages/settings_page.dart` — Account settings, notification preferences (push & email), PAN management, 80G Tax Vault, privacy data export, and developer server settings.
- `pages/legal_page.dart` — In-app terms and privacy viewer (`TermsPage`, `PrivacyPage`).
- `providers/profile_provider.dart` — Providers for badges, certificates, and profile operations.
- `data/profile_repository.dart` — Network repository calling `ApiClient` for profile resources.
- `models/badge_model.dart` — Model representing unlockable impact badges.
- `models/certificate_model.dart` — Model for official volunteer certificates.

---

## 2. Profile Data & Live Backend Integration

All user data displayed across the profile header and impact stats is **100% REAL**, sourced from PostgreSQL through `currentUserProvider` (`auth_provider.dart`):

| Metric | Source Field | Description |
|---|---|---|
| **Avatar** | `user.avatarUrl` | Hosted on CDN. Tapping the avatar launches `image_picker` and uploads via `POST /api/v1/app/profile/avatar`. |
| **Full Name** | `user.fullName` | Displayed prominently. Fallback to phone number if empty. |
| **Level / Title** | `user.levelTitle` | Gamification level (Seedling, Sapling, Ranger, Guardian) based on impact points. |
| **Level XP Progress** | `user.pointsInCurrentLevel` | Visualized with `CircularPercentIndicator` around avatar. |
| **Total XP** | `user.totalPoints` | Incremented by tree scans (+50/+15), donations (100 + ₹10/XP), event check-ins (+10), and site approvals (+20). |
| **Trees Tagged** | `user.treesTagged` | Live count of trees tagged by the user. |
| **Total Donated** | `user.totalDonated` | Total INR amount contributed across campaigns and plantation drives. |

---

## 3. Quick Actions & Sub-Pages

### 1. Leaderboard (`/profile/leaderboard`)
- Tapping the "Leaderboard" quick action opens `LeaderboardPage`.
- Powered by `leaderboardProvider` (`AsyncNotifierProvider`) with infinite scroll pagination.
- See [06_leaderboard.md](06_leaderboard.md) for complete details.

### 2. Certificates (`/profile/certificates`)
- Tapping "Certificates" opens `CertificatesPage`.
- Powered by `certificatesProvider` calling `GET /api/v1/app/profile/certificates`.
- Displays official volunteer certificates for completed plantation drives with hours volunteered, trees planted, and verification ID.
- Fully integrated vector PDF generation and native download & share via `CertificatePdfService` (`Printing.layoutPdf` and `Printing.sharePdf`). Users can save directly to device storage or share to WhatsApp, LinkedIn, or Instagram.

### 3. Badges Showcase (`/profile/badges`)
- The profile screen displays the top 4 unlocked badges.
- "See All" opens `BadgesPage` with tier-based categories (Tree Discovery, Community Hero, Generous Giver, Consistent Green).

### 4. Recent Scans
- Directly embedded in `ProfilePage` via `_ScansHistory` widget.
- Powered by `scanHistoryProvider` calling `GET /api/v1/app/tags/history`.
- Displays the user's latest 5 tagged trees. Tapping any item opens `ScanHistoryDetailSheet`.

---

## 4. Settings Page Features (`/profile/settings`)

`SettingsPage` provides deep administrative and user preference controls:

### 1. Push Notifications Toggle
- Bridges OS-level permissions (`permission_handler`) with the backend user `preferences` JSONB column.
- Implements `WidgetsBindingObserver` to auto-detect permission changes when returning from the Android/iOS OS Settings screen.
- Syncs state changes to `PUT /api/v1/app/profile` without disturbing global authentication state.

### 2. Email Notifications Toggle
- Manages user preference for newsletter and drive updates.
- Optimistically updates UI toggle and rolls back if the backend sync fails.

### 3. PAN Card Management & 80G Tax Vault
- Bottom sheet for updating or registering a 10-character PAN number (`[A-Z]{5}[0-9]{4}[A-Z]`).
- Directly opens the **80G Tax Vault** (`TaxVaultPage` at `/profile/settings/tax-vault`), backed by `GET /api/v1/app/donations`.
- Displays all historical donations with 80G receipt numbers, generation status, and one-click PDF receipt downloads for Indian Income Tax deductions.

### 4. Developer / Server Settings Modal
- Accessible via the "Server Settings" tile in developer/debug builds.
- Allows live switching between backend environments:
  - **Local Backend:** Auto-resolves to developer machine LAN IP (`192.168.1.49:8000`) or emulator localhost.
  - **Staging Cloud Run:** `https://bluedot-backend-staging-426166329141.asia-south1.run.app`
  - **Production Cloud Run:** `https://bluedot-backend-426166329141.asia-south1.run.app`
  - **Custom Base URL:** Allows entering an arbitrary URL and saves to `SharedPreferences`.
- Includes an active **Server Health Check** button that pings `/health` and reports round-trip latency in milliseconds.

### 5. Legal & Privacy Compliance
- Navigation to `/terms` and `/privacy`.
- Direct Privacy Request modal for requesting data export or initiating account deletion under DPDP/GDPR laws (backed by `POST /api/v1/app/legal/privacy-request`).

### 6. Sign Out & Account Deletion
- **Sign Out:** Clears local Supabase session, resets Riverpod providers, and redirects to `/login`.
- **Delete Account:** Issues `DELETE /api/v1/app/profile`, cleans up Supabase user, and purges local storage.
