# 01 — Auth, OTP & Splash Flow — Current State

**Status:** 100% Complete & Fully Integrated  
**Last Updated:** 2026-11-04  
**Integrations:** Native Supabase Auth + Passiton MSG91 DLT SMS + FastAPI Profile Backend  

---

## 1. User-Facing Flow

### 1. Splash (`/splash`)
- File: `lib/features/auth/pages/splash_page.dart`
- Shows smooth BlueDot branding animation.
- Awaits `authStateProvider.future` to load the backend user profile.
- Navigation logic is handled by `GoRouter` redirect guards: sends authenticated users to `/home` (or `/complete-profile` if name is missing) and unauthenticated users to `/login`.

### 2. Login (`/login`)
- File: `lib/features/auth/pages/login_page.dart`
- User enters a 10-digit Indian phone number (`+91` prefix is auto-attached).
- Form validation guarantees exactly 10 digits before dispatch.
- Includes a strict debounce guard (`_isSending`) to prevent double-sends.
- Linked legal text: Clickable spans navigate to `/terms` and `/privacy` via `TapGestureRecognizer`.
- Calls `ref.read(authNotifierProvider.notifier).sendOtp(phone)`.
- On success: navigates via query parameter:
  ```dart
  context.push(Uri(path: '/otp', queryParameters: {'phone': phone}).toString());
  ```

### 3. OTP SMS Delivery (Passiton DLT Template via MSG91)
- Supabase Auth triggers the registered Send SMS Hook (`supabase/functions/send-sms-hook/index.ts`).
- Hook dispatches OTP via MSG91 (`https://api.msg91.com/api/sendhttp.php`) using the registered Passiton DLT template:
  `" {OTP} is your verification code PASSITON. Please do not share it with anyone. INDIBIZ"`
- Parameters: Sender ID: `PASSIT`, Route: `4` (Transactional), with approved `DLT_TE_ID`.
- **Reviewer / Demo Bypass:** Test phone number `+919999999999` with OTP `558712` is hardcoded to succeed instantly without SMS dispatch for Apple/Google App Store reviewers and offline testing.

### 4. OTP Screen (`/otp`)
- File: `lib/features/auth/pages/otp_page.dart`
- 6 individual digit input boxes with automatic focus jumping.
- Multi-digit paste support: Pasting a 6-digit OTP from SMS autofill or clipboard automatically fills all 6 boxes and triggers verification.
- Auto-verifies upon entering the 6th digit; includes `_isVerifying` debounce guard to prevent double-submission.
- 30-second cooldown timer before the "Resend OTP" button becomes active.
- Verification flow:
  1. Calls `ref.read(authNotifierProvider.notifier).verifyOtp(phone: phone, otp: otp)`.
  2. Supabase Auth validates OTP and returns a valid session with JWT.
  3. `AuthRepository.fetchCurrentUser()` immediately calls `GET /api/v1/app/profile` with the JWT in `Authorization: Bearer <token>`.
  4. Backend retrieves or auto-creates the user record in PostgreSQL.
  5. Upon first successful login, the app automatically records affirmative consent for active legal terms (`terms` v1.0, `privacy` v1.0) via `legalServiceProvider.recordConsent()`.
  6. Calls `ref.invalidate(authStateProvider)` so GoRouter re-evaluates the redirect.
  7. GoRouter automatically routes to `/complete-profile` (if `fullName == null` or empty) or `/home` (if profile is already complete).

### 5. Complete Profile (`/complete-profile`)
- File: `lib/features/auth/pages/complete_profile_page.dart`
- Mandatory screen for newly registered "ghost" users whose `fullName == null` or empty.
- Collects Full Name, Email, and PAN Number (auto-uppercased).
- Form validation ensures full name is non-empty and PAN matches standard format `[A-Z]{5}[0-9]{4}[A-Z]`.
- Calls `ref.read(authNotifierProvider.notifier).updateProfile(...)`, which issues a `PUT /api/v1/app/profile`.
- On success, `currentUserProvider` is updated; GoRouter detects `fullName != null` and automatically transitions to `/home`.

---

## 2. API Endpoints

### App User Profile Endpoints
Configured in `lib/core/config/api_config.dart` (`ApiConfig.userProfile`):

| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/v1/app/profile` | Fetches current user profile from PostgreSQL. Auto-creates user if first login. | Yes (Supabase JWT) |
| `PUT` | `/api/v1/app/profile` | Updates `full_name`, `email`, `pan_number`, `city`, and `preferences`. | Yes (Supabase JWT) |
| `POST` | `/api/v1/app/profile/avatar` | Multipart upload for profile photo (stored in Bunny CDN). | Yes (Supabase JWT) |
| `DELETE` | `/api/v1/app/profile` | Soft-deletes user profile and revokes session. | Yes (Supabase JWT) |

### Backend Implementation Reference
- `bluedot_apis/app/api/v1/app/profile.py`:
  - Uses `get_current_user` dependency from `app.api.dependencies` to decode Supabase JWT and retrieve `AppUser`.
  - When a user logs in for the first time, auto-creates an `AppUser` row with `full_name=""` and defaults points to 0.
- `bluedot_apis/app/services/sms_service.py`:
  - `send_otp_via_sms91()` provides an asynchronous MSG91 client with Passiton DLT template parameters.

---

## 3. Riverpod Architecture

Files:
- `lib/features/auth/providers/auth_provider.dart`
- `lib/features/auth/data/auth_repository.dart`
- `lib/features/auth/models/user_model.dart`
- `lib/features/auth/services/supabase_auth_service.dart`

### Key Providers:
- **`authStateProvider`** (`FutureProvider<bool>`):
  - Runs during app initialization.
  - Verifies whether Supabase has an active session and fetches the backend `AppUser`.
  - If a session exists but the backend profile fails to load (e.g. 401 or deleted user), it safely signs out to avoid corrupt half-logged-in states.
- **`currentUserProvider`** (`NotifierProvider<CurrentUserNotifier, AppUser?>`):
  - Holds the in-memory `AppUser` state.
  - Exposes `.set(AppUser?)` and `.update(AppUser Function(AppUser?))` for reactive UI updates across all features.
- **`authNotifierProvider`** (`NotifierProvider<AuthNotifier, AsyncValue<void>>`):
  - Manages asynchronous states (loading, error, success) for `sendOtp`, `verifyOtp`, and `updateProfile`.

---

## 4. Navigation & Route Gating

From `lib/core/router/app_router.dart`:
- `isLoggedIn` is defined strictly as `currentUser != null`. A Supabase session alone is insufficient; the backend profile must be loaded.
- If `currentUser != null` but `currentUser.fullName == null`, `needsProfileCompletion` is `true`. The router intercepts navigation and redirects to `/complete-profile`.
- If `isLoggedIn` and the profile is complete, the user cannot access `/login`, `/otp`, or `/complete-profile` and is sent directly to `/home`.
- `ref.listen(authStateProvider)` and `ref.listen(currentUserProvider)` invoke `router.refresh()` to immediately react to authentication transitions.
