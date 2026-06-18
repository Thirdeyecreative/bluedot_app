# Action Hub & Events — Engineering Reference

## 1. Overview

Files involved (all under `bluedot_app/lib/features/action_hub/`):

- `data/action_repository.dart` — all API calls (events, RSVP, volunteer, check-in/checkout, donate, suggest site)
- `models/event_model.dart` — `PlantationEvent` model, `fromJson`, `copyWith`, derived getters
- `pages/action_hub_page.dart` — main tabbed page: Campaigns tab + Events tab, campaign donation bottom-sheet UI
- `pages/event_checkin_page.dart` — QR-scanner page for event check-in (`mobile_scanner`)
- `pages/event_detail_page.dart` — event detail page: RSVP / Volunteer / Check-in / Check-out / Donate UI
- `pages/suggest_site_page.dart` — "Suggest a Site" form: GPS + in-app camera photos + description
- `providers/action_provider.dart` — Riverpod providers/notifiers for events, RSVP, volunteer, check-in, checkout

Cross-referenced files:

- `bluedot_app/lib/core/demo/demo_data.dart`
- `bluedot_app/lib/core/config/api_config.dart`
- `bluedot_app/lib/core/widgets/in_app_camera_page.dart`
- `bluedot_apis/app/api/v1/app/events.py`
- `bluedot_apis/app/api/v1/app/suggestions.py`

## 2. Events listing

- `eventsProvider` (`providers/action_provider.dart:7-9`) is a `FutureProvider<List<PlantationEvent>>` that calls `ref.watch(actionRepositoryProvider).fetchEvents()`.
- `ActionRepository.fetchEvents()` (`data/action_repository.dart:19-23`): `final data = await _api.get(ApiConfig.appEvents);` — endpoint string `'$_app/events'`.
- UI: `_DrivesTab` in `pages/action_hub_page.dart:96-133` watches `eventsProvider`, renders a `ListView.builder` of `_EventDriveCard` widgets (lines 135-242). Loading state uses `SkeletonCardList` (per the skeleton-loader convention), not a bare spinner.

## 3. Event detail page

- `eventDetailProvider` (`providers/action_provider.dart:11-13`) is a `FutureProvider.family<PlantationEvent, String>` calling `fetchEventById(id)`.
- `ActionRepository.fetchEventById` (`data/action_repository.dart:25-28`) calls `ApiConfig.appEventDetail(id)` → `'$_app/events/$id'`.
- `EventDetailPage` (`pages/event_detail_page.dart:35-204`) shows: title, status tags, capacity row (attendees/volunteers), tree stats (for plantation drives), description, a donation tile (plantation drives only), a "scan QR" check-in button, a check-in status card, and a bottom action bar with RSVP/Volunteer/Check-out controls. Uses `SkeletonDetailPage` while loading (per skeleton convention).

## 4. RSVP flow

- Endpoint: `ApiConfig.appEventRsvp(id)` (`api_config.dart:63`) → `'$_app/events/$id/rsvp'`.
- `ActionRepository.rsvpEvent` (`action_repository.dart:30-33`): `await _api.post(ApiConfig.appEventRsvp(eventId), body: {});` (empty body). Cancel uses `_api.delete(ApiConfig.appEventRsvp(eventId))` (lines 35-37).
- `RsvpNotifier.toggle` (`action_provider.dart:29-43`) flips between `rsvpEvent`/`cancelRsvp` and invalidates `eventDetailProvider(eventId)` to refresh.
- Backend `rsvp_event` (`events.py:180-210`): returns 409 "already registered as a volunteer" if the user is already a volunteer; no-ops if already RSVP'd; 409 if event is full; otherwise creates an `EventParticipant` row and returns `{"message": "RSVP confirmed!", "role": "Attendee"}`.
- UI feedback: `EventDetailPage._handleRsvp` (`event_detail_page.dart:206-219`) calls `AppFeedback.showSuccess(context, isNowRsvped ? 'RSVP confirmed! See you there.' : 'RSVP cancelled.')` on success and `AppFeedback.showError(context, err)` on failure — consistent with the API feedback convention.

## 5. Volunteer flow

- Endpoint: `ApiConfig.appEventVolunteer(id)` (`api_config.dart:64`) → `'$_app/events/$id/volunteer'`.
- `ActionRepository.volunteerForEvent` / `cancelVolunteer` (`action_repository.dart:39-46`).
- Distinct from RSVP via separate Riverpod state: `VolunteerNotifier.toggle` (`action_provider.dart:59-76`) calls `ref.read(rsvpStateProvider.notifier).seed(false)` when volunteering, clearing RSVP state client-side — i.e. RSVP and Volunteer are tracked as two separate boolean providers (`rsvpStateProvider` vs `volunteerStateProvider`) and are mutually exclusive.
- Backend enforces the same exclusivity server-side: `volunteer_for_event` (`events.py:230-259`) runs `db.query(EventParticipant).filter_by(event_id=event.id, user_id=current_user.id).delete()` before inserting an `EventVolunteer` row.
- UI: separate buttons in `_ActionBar` (`event_detail_page.dart:372-400`) — outlined "RSVP" button vs. filled forest-green "Join as Volunteer" button. Once registered, `_RegisteredBadge(isVolunteer: isVolunteered)` (lines 404-436) shows "Registered as Volunteer" or "RSVP'd as Attendee". Feedback messages ("You're registered as a Volunteer!" / "Volunteer registration cancelled.") via `AppFeedback` (`_handleVolunteer`, lines 221-234).

## 6. Check-in / Check-out flow

**Mechanism found: QR-code scanning for check-in; plain manual button tap (no verification) for check-out. Not geofencing/GPS-based.** No `geolocator`, `Position`, or distance calculation appears anywhere in this flow.

### Check-in (QR-based)

`event_checkin_page.dart` imports `package:mobile_scanner/mobile_scanner.dart` and uses a `MobileScannerController` + `MobileScanner` widget. The QR payload is parsed and validated in `_onDetect`:

```dart
Future<void> _onDetect(BarcodeCapture capture) async {
  if (_processing) return;
  final raw = capture.barcodes.firstOrNull?.rawValue;
  if (raw == null) return;

  // Expected: bluedot://event/{event_id}/checkin?token={token}
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.scheme != 'bluedot' || uri.host != 'event') return;

  final token = uri.queryParameters['token'];
  if (token == null || token.isEmpty) return;

  setState(() => _processing = true);
  await _scanner.stop();

  try {
    await ref.read(checkInProvider.notifier).checkIn(widget.eventId, token);
    ...
```

(`event_checkin_page.dart:53-99`)

Endpoint constants: `ApiConfig.appEventCheckin` (`api_config.dart:65`) → `'$_app/events/checkin'`; `ApiConfig.appEventCheckout` (`api_config.dart:66`) → `'$_app/events/checkout'`.

```dart
Future<Map<String, dynamic>> checkInEvent(String eventId, String token) async {
  final data = await _api.post(ApiConfig.appEventCheckin, body: {
    'event_id': eventId,
    'token': token,
  });
  return (data as Map<String, dynamic>?) ?? {};
}
```

(`action_repository.dart:48-54`)

Backend `check_in` (`events.py:283-331`) validates `Event.qr_token == payload.token` server-side (line 293) — the QR code encodes a per-event secret token matched against the `events.qr_token` column. No lat/lng check anywhere. Awards `CHECKIN_XP = 10` (line 22).

### Check-out (manual, unverified)

```dart
Future<Map<String, dynamic>> checkOutEvent(String eventId) async {
  final data = await _api.post(ApiConfig.appEventCheckout, body: {'event_id': eventId});
  return (data as Map<String, dynamic>?) ?? {};
}
```

(`action_repository.dart:56-59`)

This is triggered purely by tapping `_CheckOutButton` (`event_detail_page.dart:438-456`) → `_handleCheckOut` (lines 236-259) → `checkOutProvider.notifier.checkOut(eventId)`. No token, QR, or location is sent or validated. Backend `check_out` (`events.py:334-379`) simply stamps `checked_out_at = now()` on whichever record (`EventVolunteer`/`EventParticipant`) already has `checked_in_at` set — purely time-based bookkeeping, no location/QR check at all.

UI feedback via `AppFeedback.showSuccess` / `AppFeedback.showThankYou` / `AppFeedback.showError` (e.g. `event_checkin_page.dart:78-92`, `event_detail_page.dart:248-253`).

## 7. "Suggest a Site" flow

Route: tapping the entry point in `action_hub_page.dart:48` does `context.push('/action-hub/suggest-site')`, resolved by go_router to `SuggestSitePage`.

Confirmed use of the shared in-app camera widget. Call site:

```dart
Future<void> _capturePhotos() async {
  final remaining = _maxPhotos - _photos.length;
  if (remaining <= 0) return;
  final shots = await openInAppCamera(
    context,
    maxImages: remaining,
    title: 'Photograph the Site',
  );
  if (shots.isNotEmpty) {
    setState(() => _photos.addAll(shots.take(remaining)));
  }
}
```

(`suggest_site_page.dart:57-68`)

`openInAppCamera` (`core/widgets/in_app_camera_page.dart:23-35`) pushes the camera page and returns `Future<List<File>>`; the camera page itself returns captured files via `Navigator.of(context).pop(List<File>.from(_captured))` (`in_app_camera_page.dart:139`) — it returns `File` objects (image file paths), not raw bytes.

GPS is captured here (not in check-in/checkout) via `geolocator`:
`Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)))` (`suggest_site_page.dart:42-55`).

Submission endpoint: `ApiConfig.suggestions` (`api_config.dart:58`) → `'$_app/suggestions'`.

```dart
Future<Map<String, dynamic>> suggestSite({
  required String description,
  required double lat,
  required double lng,
  List<File> images = const [],
}) async {
  final response = await _api.multipartPost(
    ApiConfig.suggestions,
    fields: {
      'description': description,
      'lat': lat.toString(),
      'lng': lng.toString(),
    },
    files: images,
    fileField: 'images',
  );
  return (response as Map<String, dynamic>?) ?? <String, dynamic>{};
}
```

(`action_repository.dart:74-91`)

Backend `suggestions.py`: `create_suggestion` (lines 38-156) has anti-abuse guards — `DUPLICATE_RADIUS_METERS = 100`, `MAX_PENDING_PER_USER = 5`, `SUBMIT_XP = 5`, `APPROVAL_XP = 20`, with the comment: *"Anti-abuse guards: XP for the contribution is awarded on admin approval, not on submission, so junk submissions can't farm points."* Dedupe uses PostGIS `ST_DWithin` against pending/approved suggestions and existing `PlantationSite` boundaries (lines 74-95), returning 409 on collision — surfaced client-side as a friendly "Already on Our Radar" message (`suggest_site_page.dart:105-115`).

## 8. Donations

Present in action_hub, in two distinct places — one real, one mock.

**Event-based donation (real, wired to backend):**
- Endpoint: `ApiConfig.appEventDonate(id)` (`api_config.dart:67`) → `'$_app/events/$id/donate'`.
```dart
Future<Map<String, dynamic>> donateForEvent(
  String eventId,
  int amount, {
  String? pan,
}) async {
  final body = <String, dynamic>{'amount': amount};
  if (pan != null && pan.isNotEmpty) body['pan'] = pan;
  final data = await _api.post(ApiConfig.appEventDonate(eventId), body: body);
  return (data as Map<String, dynamic>?) ?? {};
}
```
(`action_repository.dart:61-70`)
- UI: `_DonationTile` in `event_detail_page.dart:575-653`, shown only `if (e.isPlantationDrive)`; `_donate()` (lines 587-606) calls `repo.donateForEvent` then `AppFeedback.showThankYou`.
- Backend `donate_for_event` (`events.py:382-419`): 400 if event isn't a plantation drive, 400 if amount ≤ 0, creates a `Donation` row with `payment_method="app_inline"`, `payment_status="Paid"` immediately — no real payment gateway integration.

**Campaign donation sheet (UI-only, NOT wired to any API):**
- `_CampaignFundingCard` / `_DonationSheet` in `action_hub_page.dart:297-544`. Its "Proceed to Pay" button (lines 517-528) only does `Navigator.pop(context)` plus a local `ScaffoldMessenger.showSnackBar(content: Text('Donation of ₹$_selected initiated!'))`. No repository/API call, and it bypasses the `AppFeedback` convention entirely (uses raw `ScaffoldMessenger` instead). This should be treated as a non-functional/mock flow despite having no explicit TODO comment.

There's also an unused, separate `ApiConfig.donations` getter (`api_config.dart:47` → `'$_app/donations'`) that is not referenced anywhere in action_hub.

## 9. Riverpod providers

All defined in `bluedot_app/lib/features/action_hub/providers/action_provider.dart` unless noted:

| Provider | Type | Location | Manages |
|---|---|---|---|
| `actionRepositoryProvider` | `Provider<ActionRepository>` | `data/action_repository.dart:8-10` | Repository singleton |
| `eventsProvider` | `FutureProvider<List<PlantationEvent>>` | `action_provider.dart:7-9` | Event list fetch |
| `eventDetailProvider` | `FutureProvider.family<PlantationEvent, String>` | `action_provider.dart:11-13` | Single event fetch by id |
| `rsvpStateProvider` | `NotifierProvider<RsvpNotifier, AsyncValue<bool>>` | `action_provider.dart:18-44` | RSVP toggle state |
| `volunteerStateProvider` | `NotifierProvider<VolunteerNotifier, AsyncValue<bool>>` | `action_provider.dart:48-76` | Volunteer toggle state |
| `checkInProvider` | `NotifierProvider<CheckInNotifier, AsyncValue<CheckInResult?>>` | `action_provider.dart:87-110` | Check-in result/state |
| `checkOutProvider` | `NotifierProvider<CheckOutNotifier, AsyncValue<CheckOutResult?>>` | `action_provider.dart:121-142` | Check-out result/state |

Note: `action_hub_page.dart` also consumes a `campaignsProvider` defined outside action_hub (in `features/home/providers/home_provider.dart`), used to populate the Campaigns tab.

## 10. Navigation routes (go_router)

Defined in `bluedot_app/lib/core/router/app_router.dart:70-89`:

```dart
GoRoute(
  path: '/action-hub',
  builder: (__, _) => const ActionHubPage(),
  routes: [
    GoRoute(
      path: 'event/:id',
      builder: (_, state) => EventDetailPage(eventId: state.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'checkin',
          builder: (_, state) => EventCheckinPage(eventId: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: 'suggest-site',
      builder: (__, _) => const SuggestSitePage(),
    ),
  ],
),
```

Resolved paths: `/action-hub`, `/action-hub/event/:id`, `/action-hub/event/:id/checkin`, `/action-hub/suggest-site`. None of the routes specify a `name:` parameter — only `path:`.

## 11. TODO / demo / mock / DemoData audit

A case-insensitive search for `TODO|FIXME|mock|demo|placeholder|hardcoded|simulate|DemoData` across all action_hub files found **no TODO/FIXME/mock/demo/hardcoded/simulate comments** and **no `DemoData.*` references** anywhere in action_hub source. The only matches were unrelated Flutter parameter names (the `placeholder:` callback of `CachedNetworkImage`'s loading widget):

- `pages/action_hub_page.dart:164` — `placeholder: (_, _) => Container(height: 160, color: AppColors.borderLight),`
- `pages/action_hub_page.dart:325` — same pattern for the campaign card
- `pages/event_detail_page.dart:75` — same pattern for the event header

`core/demo/demo_data.dart` does import `PlantationEvent` from `action_hub/models/event_model.dart` and defines `DemoData.events` (lines 128-163, two hardcoded sample events: `event-eco-park`, `event-lake-buffer`), but this is **not referenced from any action_hub file** — it appears to be consumed elsewhere (e.g. notifications demo data). action_hub itself exclusively goes through `ActionRepository` to the real API.

**The one effectively-mock flow with no comment markers:** the Campaign donation sheet (`_DonationSheet` in `action_hub_page.dart:433-544`) never calls the repository/API — its "Proceed to Pay" action only pops the sheet and shows a local SnackBar (`'Donation of ₹$_selected initiated!'`). This is functionally a stub/non-functional UI flow, unlike the fully-wired event-based `_DonationTile` donation flow.

### Summary: real-backend vs. mock/demo, by flow

| Flow | Status |
|---|---|
| Events listing/detail | Real backend (`GET $_app/events`, `GET $_app/events/{id}`) |
| RSVP | Real backend (`POST`/`DELETE $_app/events/{id}/rsvp`) |
| Volunteer | Real backend (`POST`/`DELETE $_app/events/{id}/volunteer`) |
| Check-in | Real backend, QR-token verified server-side (`POST $_app/events/checkin`) |
| Check-out | Real backend but unverified/manual (`POST $_app/events/checkout`) — no location or token check |
| Suggest a Site | Real backend, multipart upload with GPS + photos (`POST $_app/suggestions`) |
| Event donation | Real backend (`POST $_app/events/{id}/donate`), but payment is recorded as "Paid" with no actual gateway |
| Campaign donation sheet | **Mock/UI-only** — no API call, local SnackBar only |
