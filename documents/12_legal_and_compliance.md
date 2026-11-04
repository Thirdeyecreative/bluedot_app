# 12 — Legal & Privacy Compliance — Engineering Reference

**Status:** 100% Complete & Fully Integrated  
**Last Updated:** 2026-11-04  
**Primary Endpoints:** `GET /api/v1/app/legal/documents/{slug}`, `GET /api/v1/app/legal/consent-status`, `POST /api/v1/app/legal/consent`, `POST /api/v1/app/legal/privacy-request`  

---

## 1. Overview

The Legal & Privacy Compliance system ensures BlueDot adheres to modern privacy and data protection frameworks (such as the Digital Personal Data Protection Act / DPDP and GDPR). It provides dynamic document versioning (Terms of Service, Privacy Policy), affirmative consent tracking, retroactive policy update sheets, and privacy rights self-service (data export and deletion requests).

### Source Files (`lib/features/legal/`)
- `services/legal_service.dart` — Network client and local offline cache for legal documents, consent status checks, affirmative consent dispatch, and privacy request submission.
- `widgets/policy_update_sheet.dart` — Interactive bottom sheet prompted when new legal document versions are published.
- `lib/features/profile/pages/legal_page.dart` — Concrete screens (`TermsPage`, `PrivacyPage`) rendering markdown text with loading and offline caching.
- Backend: `bluedot_apis/app/api/v1/app/legal.py` — REST endpoints for documents, user consent logging, and data privacy requests.
- Backend: `bluedot_apis/app/models/legal.py` — Database models for `LegalDocument`, `UserConsent`, and `PrivacyRequest`.

---

## 2. Core Workflows

### 1. Dynamic Legal Document Loading & Offline Caching
- When a user views `/terms` or `/privacy`, `LegalService.fetchDocument(slug)` is called.
- Issues `GET /api/v1/app/legal/documents/{slug}` (e.g. `terms`, `privacy`).
- If successful, parses title, effective date, version, and Markdown content. The document is cached locally in `SharedPreferences` (`bluedot_legal_doc_{slug}`).
- If the device is offline or the server is unreachable, the client falls back to the cached version or hardcoded default templates, ensuring legal text is always accessible.

### 2. Affirmative Consent on Login
- When a user enters their 6-digit OTP and authenticates for the first time:
  ```dart
  ref.read(legalServiceProvider).recordConsent('terms', '1.0');
  ref.read(legalServiceProvider).recordConsent('privacy', '1.0');
  ```
- The backend records a timestamped `UserConsent` entry with the user's UUID, IP address, and user-agent string.

### 3. Retroactive Policy Update Sheet (`PolicyUpdateSheet`)
- On `HomePage.initState()`, the app calls:
  ```dart
  final status = await ref.read(legalServiceProvider).checkConsentStatus();
  if (status.requiresConsent && mounted) {
    PolicyUpdateSheet.show(context, status.pendingDocuments);
  }
  ```
- Backend checks whether the user has consented to the latest published version of each active legal document.
- If an admin publishes Terms v2.0 or Privacy Policy v2.0, `status.requiresConsent` evaluates to `true`.
- The `PolicyUpdateSheet` appears over the home screen with a summary of changes:
  - Users can read the updated terms directly inside the sheet.
  - Tapping "I Accept" records affirmative consent for all pending documents and dismisses the modal.

### 4. Privacy Rights Self-Service (Data Export & Account Deletion)
- Located in `SettingsPage` under "Data & Privacy".
- Users can request a complete copy of their personal data or request permanent deletion of their account:
- Calls `POST /api/v1/app/legal/privacy-request` with payload:
  ```json
  {
    "request_type": "export_data", // or "delete_account"
    "reason": "User requested archive of personal tags and donations"
  }
  ```
- Automatically logs a verifiable audit trail in the backend database.

---

## 3. API Endpoints

### 1. `GET /api/v1/app/legal/documents/{slug}` (`ApiConfig.legalDocument(slug)`)
- Returns the latest published version of a legal document (e.g. `terms`, `privacy`).
- Public endpoint (no auth required).

### 2. `GET /api/v1/app/legal/consent-status` (`ApiConfig.consentStatus`)
- Requires Supabase JWT.
- Evaluates whether the authenticated user has accepted the latest published versions.
- Returns `{ "requires_consent": bool, "pending_documents": [...] }`.

### 3. `POST /api/v1/app/legal/consent` (`ApiConfig.recordConsent`)
- Requires Supabase JWT.
- Request payload: `{ "document_slug": "terms", "document_version": "1.0" }`.
- Persists user consent with timestamp and client metadata.

### 4. `POST /api/v1/app/legal/privacy-request` (`ApiConfig.privacyRequest`)
- Requires Supabase JWT.
- Request payload: `{ "request_type": "export_data" | "delete_account", "reason": "..." }`.
- Creates a `PrivacyRequest` record for automated or administrative compliance fulfillment.

