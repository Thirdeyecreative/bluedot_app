# Auth, OTP & Splash Flow — Current State

## 1. User-Facing Flow

1. **Splash** (`/splash`, `SplashPage` in `lib/features/auth/pages/splash_page.dart`)
   - On `initState`, shows logo + "Climate Action, Gamified." tagline with fade/scale animation.
   - Waits 2200ms for branding animation.
   - Reads `await ref.read(authStateProvider.future)` to resolve `isLoggedIn`.
   - Navigates: `context.go(isLoggedIn ? '/home' : '/login')`.

2. **Login** (`/login`, `LoginPage` in `lib/features/auth/pages/login_page.dart`)
   - User enters a 10-digit phone number; app prefixes it with `'+91'`.
   - Calls `ref.read(authNotifierProvider.notifier).sendOtp(phone)`.
   - On success: `context.push('/otp', extra: phone)` (phone passed via `extra`, not a path param).
   - On error: shows a `SnackBar` with `authState.error.toString()`.

3. **OTP** (`/otp`, `OtpPage(phone)` in `lib/features/auth/pages/otp_page.dart`)
   - 6-box OTP entry; auto-verifies once all 6 digits are filled.
   - Calls `ref.read(authNotifierProvider.notifier).verifyOtp(phone: phone, otp: otp)`.
   - On success: `ref.invalidate(authStateProvider)` then `context.go('/home')`.
   - Has a "Resend OTP" action that re-calls `sendOtp`.

## 2. API Endpoints — Configured vs. Actually Called

`lib/core/config/api_config.dart` defines (base = `{baseUrl}/api/v1/app`):

```dart
static String get sendOtp => '$_app/auth/send-otp';   // {baseUrl}/api/v1/app/auth/send-otp
static String get verifyOtp => '$_app/auth/login';     // {baseUrl}/api/v1/app/auth/login
static String get userProfile => '$_app/profile';      // {baseUrl}/api/v1/app/profile
```

`baseUrl` is selected via `String.fromEnvironment('ENV', defaultValue: 'staging')`:
- local: `http://10.0.2.2:8000`
- staging: `https://bluedot-backend-staging-426166329141.asia-south1.run.app`
- production: `https://bluedot-backend-426166329141.asia-south1.run.app`

**However, none of these endpoints are actually called.** `AuthRepository` (`lib/features/auth/data/auth_repository.dart`) does not use `ApiClient` or `ApiConfig` at all for auth:
- `sendOtp(String phone)` — just `await Future.delayed(300ms)`. No HTTP request.
- `verifyOtp({phone, otp})` — `await Future.delayed(300ms)`, then compares `otp` to `DemoData.demoOtp` (`'123456'`). On mismatch throws `Exception('Invalid demo OTP. Use 123456.')`. On success returns `DemoData.user` and persists `DemoData.demoToken` via secure storage.
- `getSavedUser()` — checks `_storage.isLoggedIn()`; if true, returns the static `DemoData.user` (not a freshly fetched profile from `/profile`).
- `signOut()` — calls `_storage.clearAll()`.

### Backend cross-reference (confirms no backend exists for this flow)

Searched `bluedot_apis\app\api\v1\app\` (`__init__.py`, `suggestions.py`, `events.py`, `config.py`, `tags.py`): **there is no `auth.py`, no `/auth/send-otp`, no `/auth/login`, and no `/profile` route implemented anywhere under the app-facing API.**

The only `auth.py` in the backend is `bluedot_apis\app\api\v1\admin\auth.py` — this is the **admin/staff** login, unrelated to the app's phone/OTP flow:
- `POST /login` (rate-limited `5/15minute`) — accepts `LoginRequest` (`email`, `password`), verifies against `AdminUser`, issues JWT, returns `TokenResponse(access_token, username, role, permissions)`.
- `GET /token/validate` — validates bearer token via `get_current_admin`, returns `TokenValidationResponse`.

**Conclusion: the app's phone/OTP auth and profile fetch are entirely frontend-mocked. The `ApiConfig.sendOtp` / `verifyOtp` / `userProfile` constants are defined but dead — no backend route exists to serve them, and the repository doesn't call them anyway.**

## 3. Demo Data Backing the Flow

`lib/core/demo/demo_data.dart` (`DemoData` class) defines:
- `demoPhone = '+919999999999'`
- `demoOtp = '123456'`
- `demoToken = 'demo-auth-token'`
- A static demo `AppUser` (`id: 'demo-user'`, `fullName: 'Avishkar'`, `totalPoints: 1320`, `level: 3`, etc.)
- Also demo banners/campaigns/etc. used elsewhere in the app.

## 4. Riverpod Providers

All defined in `lib/features/auth/providers/auth_provider.dart`:

- **`authStateProvider`** — `FutureProvider<bool>`. Calls `authRepositoryProvider.getSavedUser()`; sets `currentUserProvider` as a side effect; resolves to `true`/`false` for whether a valid session/token exists. Consumed by the router's redirect logic and by `SplashPage`.
- **`currentUserProvider`** — `NotifierProvider<CurrentUserNotifier, AppUser?>`. `CurrentUserNotifier.build() => null`; exposes `set(user)` and `update({fullName, email, city})` for partial profile edits.
- **`authNotifierProvider`** — `NotifierProvider<AuthNotifier, AsyncValue<void>>`. `AuthNotifier` exposes `sendOtp(phone)`, `verifyOtp({phone, otp})` (returns `AppUser?`), and `signOut()` (calls repo `signOut`, clears `currentUserProvider`, invalidates `authStateProvider`).
- **`authRepositoryProvider`** — plain `Provider<AuthRepository>` (in `lib/features/auth/data/auth_repository.dart`), supplies the `AuthRepository` instance used by the above.

## 5. Token / Session Storage

`lib/core/services/storage_service.dart`, backed by `flutter_secure_storage` (`FlutterSecureStorage` with `AndroidOptions()`).

Exact storage keys:
```dart
_tokenKey = 'auth_token'
_phoneKey = 'user_phone'
_nameKey  = 'user_name'
```

Methods: `saveToken(token)`, `getToken()`, `deleteToken()`, `saveUserInfo({phone, name})` (writes phone always, name only if non-null), `getUserPhone()`, `getUserName()`, `isLoggedIn()` (true if token is non-null/non-empty), `clearAll()` (`_storage.deleteAll()`).

No SharedPreferences or Hive usage found for auth/session data — secure storage is the sole mechanism.

## 6. HTTP Client / Error Handling (`lib/core/services/api_client.dart`)

Even though it's unused by the current auth flow, this is the pattern the rest of the app (and any future real auth wiring) relies on:

- `ApiClient` (+ `apiClientProvider`, a `Provider<ApiClient>`), built on `package:http`.
- Methods: `get`, `post`, `delete`, `multipartPost` — each accepts `requireAuth` (default true for most).
- `_headers({requireAuth=true})`: always sets `Content-Type: application/json` and `Accept: application/json`. If `requireAuth`, reads the token via `_storage.getToken()` and adds `Authorization: Bearer $token`. Multipart requests attach the bearer token directly to `request.headers['Authorization']`.
- 30-second timeout (`_timeout = Duration(seconds: 30)`), wrapped via `_guard`:
  - `SocketException` → "No internet connection. Please check your network and try again."
  - `TimeoutException` → "The request timed out. Please try again."
  - `http.ClientException` → "Could not reach the server. Please try again in a moment."
  - `HandshakeException` → "A secure connection could not be established. Please try again."
  - All surfaced as `ApiException(statusCode: 0)` (`isNetworkError` true when `statusCode == 0`).
- `_handle`: 200–299 → decoded JSON body (or null if empty); otherwise throws `ApiException(message: _extractMessage(...), statusCode: res.statusCode)`.
- `_extractMessage` — **confirmed**: extracts FastAPI's `detail` field first: `decoded['detail'] ?? decoded['message'] ?? decoded['error']`; also handles FastAPI's validation-error list shape (`[{"msg": ...}]`) by taking `first['msg']`. Falls back to `_defaultMessage(statusCode)` if the body isn't JSON or has no usable field.
- `_defaultMessage` friendly defaults by status code: 400, 401 ("Your session has expired. Please log in again."), 403, 404, 409, 413, 415, 429, 500/502/503, and a generic fallback ("Something went wrong (error $statusCode). Please try again.").
- `multipartPost` sends image files under a repeated field (default `'images'`) with content-type inferred from extension (png/webp/jpeg, default jpeg) — code comment notes the API rejects the default `application/octet-stream`.
- `ApiException implements Exception` — fields `message`, `statusCode`, getter `isNetworkError`, `toString() => message`.

## 7. Navigation / Router Integration

From `lib/core/router/app_router.dart` (see `09_navigation.md` for the full route table):

- `initialLocation: '/splash'`.
- Redirect logic (exact code):
```dart
redirect: (context, state) {
  final isLoggedIn = authState.value ?? false;
  final isSplash = state.matchedLocation == '/splash';
  final isAuth = state.matchedLocation.startsWith('/login') ||
      state.matchedLocation.startsWith('/otp');

  if (isSplash) return null;
  if (!isLoggedIn && !isAuth) return '/login';
  if (isLoggedIn && isAuth) return '/home';
  return null;
},
```
- This means: unauthenticated users are forced to `/login` for any non-splash, non-auth route; authenticated users hitting `/login` or `/otp` are bounced to `/home`. `/splash` is exempt from the guard so it can run its own one-time check.
- Relevant route paths: `/splash`, `/login`, `/otp` (phone passed via `extra`), `/home` (post-login landing, inside the shell — see `09_navigation.md`).

## 8. Mock/Demo Findings (grep results in `lib/features/auth/`)

```
auth_repository.dart:2:  import '../../../core/demo/demo_data.dart';
auth_repository.dart:21:    if (otp != DemoData.demoOtp) {
auth_repository.dart:22:      throw Exception('Invalid demo OTP. Use 123456.');
auth_repository.dart:25:    final user = DemoData.user;
auth_repository.dart:26:    await _storage.saveToken(DemoData.demoToken);
auth_repository.dart:34:    return DemoData.user;
```

No literal `TODO` or `FIXME` comments were found, but this doesn't mean the flow is finished — the entire repository is demo-data-backed rather than network-backed.

**Explicit summary: Login, OTP verification, and profile retrieval are 100% mock/demo right now.** No HTTP calls are made by `AuthRepository`. The configured backend endpoints (`/auth/send-otp`, `/auth/login`, `/profile`) do not exist on the backend either, so even if the repository were wired up today, these specific routes would 404.
