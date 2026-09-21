# Auth, OTP & Splash Flow — Current State

## 1. User-Facing Flow

1. **Splash** (`/splash`, `SplashPage` in `lib/features/auth/pages/splash_page.dart`)
   - Shows branding animation.
   - Awaits `authStateProvider.future` to load backend profile.
   - Navigates: `context.go(isLoggedIn ? '/home' : '/login')`.

2. **Login** (`/login`, `LoginPage` in `lib/features/auth/pages/login_page.dart`)
   - User enters a 10-digit phone number.
   - Calls `SupabaseAuthService.sendOtp(phone)`.
   - On success: `context.push('/otp', extra: phone)`.
   - Includes debounce guards to prevent double-sends.

3. **OTP** (`/otp`, `OtpPage` in `lib/features/auth/pages/otp_page.dart`)
   - 6-box OTP entry; auto-verifies when filled.
   - Calls `authNotifierProvider.notifier.verifyOtp(phone, otp)`.
   - Supabase verifies the OTP and issues a session token.
   - App calls `GET /api/v1/app/profile` to fetch or auto-create the backend user.
   - `currentUserProvider` is updated.
   - The GoRouter automatically redirects the user to `/complete-profile` (if new ghost user) or `/home` (if returning user).
   - Includes a 30s resend cooldown.

4. **Complete Profile** (`/complete-profile`, `CompleteProfilePage` in `lib/features/auth/pages/complete_profile_page.dart`)
   - Required for users where `fullName == null` (ghost users).
   - Collects Name, Email, and PAN Number.
   - Calls `PUT /api/v1/app/profile`.
   - On success, updates `currentUserProvider` and GoRouter auto-redirects to `/home`.

## 2. API Endpoints

The auth flow natively uses **Supabase Auth** for token generation. The backend only handles user profiles.

`lib/core/config/api_config.dart` configures:
- `userProfile` (`GET / PUT /api/v1/app/profile`)

Backend (`bluedot_apis/app/api/v1/app/profile.py`):
- `GET /api/v1/app/profile`: Uses `get_current_user` dependency to parse the Supabase JWT. Auto-creates a Postgres `AppUser` with `full_name=""` if it's their first login.
- `PUT /api/v1/app/profile`: Updates `full_name`, `email`, and `pan_number`.

## 3. Riverpod Providers & State

Defined in `lib/features/auth/providers/auth_provider.dart`:

- **`authStateProvider`** — `FutureProvider<bool>`. Runs on app startup. Fetches the backend user. If fetch fails but a Supabase session exists, it forces a local sign-out to prevent a corrupted half-logged-in state.
- **`currentUserProvider`** — `NotifierProvider<CurrentUserNotifier, AppUser?>`. Holds the current backend profile.
- **`authNotifierProvider`** — `NotifierProvider<AuthNotifier, AsyncValue<void>>`. Manages async operations (sendOtp, verifyOtp, updateProfile).

## 4. Navigation Gating (GoRouter Redirects)

From `lib/core/router/app_router.dart`:

- `isLoggedIn` is strictly defined as `currentUser != null`. A Supabase session is not enough; the backend profile must have loaded successfully to enter the app.
- If `currentUser != null` but `currentUser.fullName == null`, `needsProfileCompletion` is true. The router intercepts all navigation and forces the user to `/complete-profile`.
- If `isLoggedIn` and the profile is complete, the user is not allowed to visit `/login`, `/otp`, or `/complete-profile` and is routed to `/home`.

## 5. Status
The Mobile OTP Auth flow is **100% complete and fully wired to the backend and Supabase.** Mock data has been entirely removed from the auth pathway.
