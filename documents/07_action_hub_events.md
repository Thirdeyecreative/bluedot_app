# 07 — Action Hub & Events — Engineering Reference

**Status:** 100% Complete & Fully Integrated  
**Last Updated:** 2026-11-04  
**Primary Endpoints:** `GET /api/v1/app/events`, `POST /api/v1/app/events/checkin`, `POST /api/v1/app/events/checkout`, `POST /api/v1/app/suggestions`, `POST /api/v1/app/donations`  

---

## 1. Overview

The Action Hub drives real-world environmental action. It organizes community plantation drives, crowdfunding campaigns, volunteer management, event check-in/out via QR tokens, site suggestions, and campaign/event donations.

### Source Files (`lib/features/action_hub/`)
- `pages/action_hub_page.dart` — Main tabbed interface hosting Campaigns and Events with donation bottom sheets.
- `pages/event_detail_page.dart` — Complete event details: RSVP, Volunteer registration, QR check-in launch, checkout, and donation tile.
- `pages/campaign_detail_page.dart` — Crowdfunding campaign page with live progress, media carousels, and contribution tiers.
- `pages/event_checkin_page.dart` — Camera QR scanner powered by `mobile_scanner`.
- `pages/suggest_site_page.dart` — Form for crowdsourcing barren land with GPS coordinates and multi-photo uploads.
- `data/action_repository.dart` — Network repository calling `ApiClient`.
- `providers/action_provider.dart` — Riverpod providers for events, RSVPs, volunteering, check-in, and checkout.
- `models/event_model.dart` — `PlantationEvent` data model.

---

## 2. Core Flows

### 1. Events Listing & Detail
- `eventsProvider` calls `GET /api/v1/app/events`.
- Displays upcoming plantation drives with date, location, volunteer requirements, and trees target.
- Tapping an event navigates to `/action-hub/event/:id` (`EventDetailPage`).

### 2. RSVP & Volunteering
- **RSVP Flow:**
  - Endpoint: `POST /api/v1/app/events/:id/rsvp` / `DELETE /api/v1/app/events/:id/rsvp`.
  - Confirms attendee participation.
- **Volunteer Flow:**
  - Endpoint: `POST /api/v1/app/events/:id/volunteer` / `DELETE /api/v1/app/events/:id/volunteer`.
  - Registers the user as an official event volunteer.
  - Server deletes any existing attendee RSVP when the user joins as a volunteer to ensure clean role exclusivity.
- Both flows trigger optimistic Riverpod state updates and refresh event capacity counters.

### 3. QR-Based Event Check-In
- When an attendee arrives at the physical event site, they tap "Scan Event QR Code".
- Opens `EventCheckinPage` with `mobile_scanner`.
- Reads a custom URI scheme: `bluedot://event/{event_id}/checkin?token={token}`.
- Calls `POST /api/v1/app/events/checkin` with payload `{ "event_id": eventId, "token": token }`.
- Backend validates the token against the secret `qr_token` stored on the event record.
- Awards **10 Impact Points (CHECKIN_XP)** to the user's account upon verified check-in.

### 4. Event Check-Out
- After the event concludes, users tap "Check Out".
- Calls `POST /api/v1/app/events/checkout` with `{ "event_id": eventId }`.
- Backend records `checked_out_at = now()` and calculates volunteer hours for subsequent certificate generation.

### 5. Suggest a Site (Crowdsourcing)
- Opens `SuggestSitePage` at `/action-hub/suggest-site`.
- Features:
  - GPS acquisition via `Geolocator.getCurrentPosition()`.
  - In-app multi-photo capture using `InAppCameraPage`.
  - User description of the barren land or potential planting area.
- Calls `POST /api/v1/app/suggestions` (`multipart/form-data`).
- **Anti-Abuse Protections (Backend):**
  - PostGIS `ST_DWithin` checks for duplicates within a 100-meter radius (`DUPLICATE_RADIUS_METERS = 100`).
  - Limits users to 5 pending suggestions (`MAX_PENDING_PER_USER = 5`).
  - Awards **5 XP** on submission and **20 XP** upon admin approval.

### 6. Donations (Campaign & Event)
- **Campaign Donations:**
  - User selects a contribution tier (₹500, ₹1000, ₹2500, or custom amount).
  - Calls `ActionRepository.donateForCampaign()` → `POST /api/v1/app/donations`.
  - Increments campaign `current_amount_raised` in real time.
  - Generates an official 80G tax receipt record if PAN is provided or on file.
  - Awards **100 base XP + 1 XP per ₹10 donated**.
- **Event-Specific Donations:**
  - Tapping the donation tile on a plantation drive calls `POST /api/v1/app/events/:id/donate`.
  - Directs funds specifically to sapling purchases for that drive.

---

## 3. API Specification Reference

| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/v1/app/events` | Lists all upcoming events and drives | No |
| `GET` | `/api/v1/app/events/{id}` | Detailed event information | No |
| `POST` | `/api/v1/app/events/{id}/rsvp` | Confirms attendee RSVP | Yes |
| `DELETE` | `/api/v1/app/events/{id}/rsvp` | Cancels attendee RSVP | Yes |
| `POST` | `/api/v1/app/events/{id}/volunteer` | Registers user as volunteer | Yes |
| `DELETE` | `/api/v1/app/events/{id}/volunteer` | Cancels volunteer registration | Yes |
| `POST` | `/api/v1/app/events/checkin` | QR-token check-in verification | Yes |
| `POST` | `/api/v1/app/events/checkout` | Event check-out timestamping | Yes |
| `POST` | `/api/v1/app/events/{id}/donate` | Donates directly to an event | Yes |
| `POST` | `/api/v1/app/suggestions` | Submits site suggestion with photos & GPS | Yes |
| `POST` | `/api/v1/app/donations` | Contributes to campaign with 80G generation | Yes |

---

## 4. Riverpod Providers

Defined in `lib/features/action_hub/providers/action_provider.dart`:

- `actionRepositoryProvider` — Singleton provider for `ActionRepository`.
- `eventsProvider` (`FutureProvider<List<PlantationEvent>>`) — Supplies the events feed.
- `eventDetailProvider` (`FutureProvider.family<PlantationEvent, String>`) — Loads single event by ID.
- `rsvpStateProvider` (`NotifierProvider<RsvpNotifier, AsyncValue<bool>>`) — Tracks RSVP toggle state.
- `volunteerStateProvider` (`NotifierProvider<VolunteerNotifier, AsyncValue<bool>>`) — Tracks volunteer toggle state.
- `checkInProvider` (`NotifierProvider<CheckInNotifier, AsyncValue<CheckInResult?>>`) — Manages check-in verification state.
- `checkOutProvider` (`NotifierProvider<CheckOutNotifier, AsyncValue<CheckOutResult?>>`) — Manages check-out timestamp state.
