# 13 — Cashfree Payment Gateway & Financial Security Engineering Plan

**Status:** Implementation In Progress  
**Last Updated:** 2026-11-05  
**Primary Standards:** Cashfree PG API `2023-08-01`, ACID Transactions, CAP Theorem (CP Priority), PCI-DSS Compliance (SDK Delegated)  
**Primary Endpoints:** `POST /api/v1/app/donations/initiate`, `POST /api/v1/app/donations/verify`, `POST /api/v1/webhooks/cashfree`, `POST /api/v1/admin/finance/refunds`

---

## 1. Executive Summary & Vision

BlueDot enables transparent, high-impact donations for verified environmental causes (plantation drives, rewilding initiatives, and eco-restoration). 
To accept payments across India seamlessly and securely, BlueDot integrates **Cashfree Payments** via native UPI Intent (Google Pay, PhonePe, Paytm, CRED), NetBanking, Debit/Credit Cards, and Wallets.

This document details the architectural specifications, transaction safety (ACID), distributed consistency rules (CAP Theorem), data security protections, and an active progress checklist.

---

## 2. Architecture & Transaction Flow

The integration follows a strict **Zero-Trust Client-Server-Gateway** architecture. The mobile client never creates or settles charges independently; all monetary authority resides on the backend with Cashfree verification.

```
┌──────────────────┐               ┌──────────────────┐               ┌──────────────────────┐
│  BlueDot App     │               │ FastAPI Backend  │               │ Cashfree PG (Server) │
│  (Flutter SDK)   │               │  (PostgreSQL)    │               │  (API 2023-08-01)    │
└────────┬─────────┘               └────────┬─────────┘               └──────────┬───────────┘
         │                                  │                                    │
         │  1. Initiate Donation            │                                    │
         │  (Amount, Campaign, PAN)         │                                    │
         ├─────────────────────────────────>│                                    │
         │                                  │  2. Create Pending Order           │
         │                                  │     (Idempotent BD_ORD_xxx)        │
         │                                  ├───────────────────────────────────>│
         │                                  │                                    │
         │                                  │  3. Return payment_session_id      │
         │                                  │<───────────────────────────────────┤
         │  4. Return Session & Order ID    │                                    │
         │<─────────────────────────────────┤                                    │
         │                                                                       │
         │  5. Launch Native Cashfree SDK (UPI Intent / Cards)                   │
         ├──────────────────────────────────────────────────────────────────────>│
         │                                                                       │
         │  6. User Completes Payment in UPI / Bank App                          │
         │<──────────────────────────────────────────────────────────────────────┤
         │                                  │                                    │
         │  7. Client Verify Request        │                                    │
         │  (order_id)                      │                                    │
         ├─────────────────────────────────>│                                    │
         │                                  │  8. Server-to-Server Verification  │
         │                                  │     (GET /pg/orders/{order_id})    │
         │                                  ├───────────────────────────────────>│
         │                                  │                                    │
         │                                  │  9. Confirm Status == "PAID"       │
         │                                  │<───────────────────────────────────┤
         │                                  │                                    │
         │                                  │  10. Atomic ACID Settlement        │
         │                                  │      - Mark Completed              │
         │                                  │      - Increment Campaign Total    │
         │                                  │      - Award User XP               │
         │                                  │      - Generate 80G Tax Receipt    │
         │                                  │                                    │
         │  11. Success Modal (+XP & 80G)   │                                    │
         │<─────────────────────────────────┤                                    │
         │                                  │                                    │
         │                                  │  12. [Async Webhook Safety Net]    │
         │                                  │<───────────────────────────────────┤
         │                                  │      (Verify HMAC Signature)       │
```

---

## 3. ACID Guarantees in Financial Transactions

Financial mutations must never result in corrupted tallies, orphaned receipts, or duplicate XP points.

| ACID Property | Problem Prevented | BlueDot Implementation |
| :--- | :--- | :--- |
| **Atomicity** | Crash during receipt generation leaving money recorded without XP or receipt. | Python `with db.begin():` context. If any step fails, all mutations roll back cleanly. |
| **Consistency** | Incompatible data states or negative donations. | Database foreign key constraints (`ForeignKey("campaigns.id")`), Pydantic model validation (`gt=0`), and regex PAN validation (`^[A-Z]{5}[0-9]{4}[A-Z]$`). |
| **Isolation** | Race conditions if Flutter callback and Webhook arrive at the same millisecond. | **Pessimistic Row Locking** via SQLAlchemy `db.query(Donation).with_for_update()`. First process commits; second detects `Completed` and safely no-ops. |
| **Durability** | Data lost during server power outage. | Supabase PostgreSQL Write-Ahead Logging (WAL). Transactions are synchronously committed to disk before returning HTTP 200. |

---

## 4. CAP Theorem Application: Consistency over Availability (CP)

In distributed financial architectures, **Consistency (C)** and **Partition Tolerance (P)** strictly override pure Availability (A).

* **Idempotency Guarantee**: Every Cashfree payment order has a deterministic `order_id` prefixed with `BD_ORD_{uuid}`. If network retries occur, Cashfree detects the identical order ID and prevents double deduction.
* **Single Source of Truth**: Cashfree's ledger is the sole authority on cash transfer. BlueDot's PostgreSQL is the sole authority on tax receipts and in-app gamification. The state synchronizes deterministically.
* **Graceful Degradation**: If Cashfree APIs experience partial outages, donation buttons gracefully show informative retry banners rather than recording speculative offline balances.

---

## 5. Security & Data Protection Checks

To guarantee bank-grade security and protect user personally identifiable information (PII):

### 1. Zero-Trust API Key Isolation
* **`CASHFREE_SECRET_KEY`** is stored exclusively in `bluedot_apis/.env` and loaded via Pydantic `BaseSettings`.
* **Never exposed to Flutter**: The mobile client only receives a short-lived `payment_session_id` (expires in 30 minutes).

### 2. Cryptographic Webhook Authentication (HMAC-SHA256)
* Cashfree sends HTTP headers `x-webhook-signature` and `x-webhook-timestamp`.
* The backend recalculates:
  $$\text{Signature} = \text{HMAC-SHA256}(\text{timestamp} + \text{raw\_body}, \text{secret\_key})$$
* Any request with an invalid or expired timestamp (>5 minutes drift) is immediately rejected with HTTP `401 Unauthorized`.

### 3. Server-Side Double Verification
* The mobile client is **untrusted**. The app cannot pass `{ "status": "PAID" }`.
* When the client says checkout is complete, the backend queries Cashfree directly via HTTPS: `GET https://sandbox.cashfree.com/pg/orders/{order_id}`.
* Only when Cashfree confirms `order_status == "PAID"` does the backend commit changes.

### 4. PII & Financial Data Security
* **PAN Storage & Privacy**: PAN numbers are validated and stored for 80G tax generation only. PANs are never rendered in public feeds or leaderboards.
* **Zero Card Storage (PCI-DSS Compliance)**: BlueDot never touches or stores raw credit/debit card numbers or CVVs. All card inputs are rendered securely within Cashfree's PCI-DSS compliant SDK.
* **Network Encryption**: All communication is enforced over TLS 1.3 / HTTPS.

---

## 6. Refund Lifecycle & Recovery

Refunds are supported for accidental donations or cancellation requests:
1. **Source Route**: Money is refunded back to the originating payment instrument (UPI account, debit card, credit card) automatically without manual bank account queries.
2. **Administrative Approval**: Triggered from `bluedot_admin_panel` via `POST /api/v1/admin/finance/refunds`.
3. **Ledger Adjustment**:
   * Creates a record in the `refunds` table with `refund_reference`.
   * Updates `Donation.payment_status = "Refunded"`.
   * Subtracts the amount from `Campaign.current_amount_raised`.
   * Rolls back corresponding user XP points to maintain leaderboard fairness.

---

## 7. Implementation Tracking Checklist

### 🟢 Completed & Verified
- [x] **Complete Payment State Lifecycle Handling (Success, Pending, Under Review, Failed, Cancelled, Refunded)**:
  - [x] Backend `/verify` endpoint maps all Cashfree gateway order statuses (`PAID`, `ACTIVE`/`PENDING`, `FLAGGED`, `FAILED`/`EXPIRED`, `REFUNDED`) into clear, non-panicking JSON responses.
  - [x] Asynchronous Webhook listener handles `PAYMENT_SUCCESS_WEBHOOK`, `PAYMENT_FAILED_WEBHOOK`, `PAYMENT_USER_DROPPED_WEBHOOK`, and `REFUND_SUCCESS_WEBHOOK`.
  - [x] Flutter client interactive Pending dialog (`AppFeedback.showPaymentPending`) with a live "Check Status Now" button that verifies bank confirmation on demand.
  - [x] Dedicated Payment Failed & Cancelled dialog (`AppFeedback.showPaymentFailed`) with transparent money-safety assurance (24–48 hr auto-refund).
  - [x] 80G Tax Vault (`settings_page.dart`) updated with dynamic color-coded state badges and an inline "Verify Bank Settlement" action button for unresolved pending orders.
- [x] **Database Schema**: `Campaign`, `Donation`, `Receipt80G`, and `Refund` SQLAlchemy models (`models/financial.py`).
- [x] **80G Tax Vault Backend**: Historical donation retrieval with PAN status and receipt links (`GET /api/v1/app/donations`).
- [x] **Admin Finance Endpoints & Cashfree Refund Integration**:
  - [x] Admin audit logging and refund tracking (`api/v1/admin/finance.py`).
  - [x] Automated bank refund execution through `cashfree_service.initiate_refund(...)`.
  - [x] Ledger rollback (deducting campaign raised funds and reversing user XP upon refund approval).
- [x] **User-Facing Legal Refund Policy**: Official Cancellation & Refund Policy added to App Terms & Legal (`legal_page.dart`) satisfying Indian PG & RBI compliance.
- [x] **Flutter UI Flow**: Interactive `DonationSheet` with amount selectors (₹500, ₹800, ₹1500, Custom), PAN validation, and XP preview (`action_hub_page.dart`).
- [x] **Background Data Synchronization**: Real-time multi-provider reload (`Future.wait`) running behind the "Thank You! 🌿" modal so campaign funds, progress bars, and user XP update instantly.
- [x] **Cashfree Account Activation**: Payment Gateway and Secure ID activated on Cashfree Merchant Dashboard.
- [x] **Cashfree Backend Configuration**: Added `CASHFREE_APP_ID`, `CASHFREE_SECRET_KEY`, `CASHFREE_ENV`, and `cashfree_base_url` to `bluedot_apis/app/core/config.py` and `.env`.
- [x] **Live Sandbox Authentication**: Tested and verified live sandbox communication (`create_order` & `get_order_status` return HTTP 200 with active session).
- [x] **Backend `CashfreeService`**: Async client built in `bluedot_apis/app/services/cashfree_service.py` supporting order creation, direct status verification, refunds, and HMAC SHA-256 webhook validation.
- [x] **Payment API Endpoints**:
  - [x] `POST /api/v1/app/donations/initiate`: Creates pending donation and fetches Cashfree `payment_session_id`.
  - [x] `POST /api/v1/app/donations/verify`: Double-verifies bank settlement with Cashfree using row-level locking (`with_for_update`) and commits XP + 80G receipt idempotently.
  - [x] `POST /api/v1/app/donations/webhook`: Public asynchronous webhook endpoint with HMAC signature checking.
- [x] **Flutter Cashfree SDK**:
  - [x] `flutter_cashfree_pg_sdk` installed in `bluedot_app/pubspec.yaml`.
  - [x] `AndroidManifest.xml` updated with package queries for Google Pay, PhonePe, Paytm, BHIM, Airtel, and `upi://` URI schemes.
  - [x] `CashfreePaymentService` created in `lib/core/services/cashfree_payment_service.dart` with BlueDot green styling and desktop/simulator mock fallback.
  - [x] `ActionRepository` updated with `initiateDonation` and `verifyDonation`.
  - [x] `DonationSheet` in `action_hub_page.dart` and `_DonationTile` in `event_detail_page.dart` connected to the full Cashfree initiation, checkout, and verification pipeline.

---

### 🟡 In Progress / Next Up
- [ ] **End-to-End Test Run**: Perform a test donation via the Flutter mobile app to see the native checkout and celebrate with the Thank You modal!

---

### 🔴 Testing & Go-Live Verification
- [ ] Verify test transaction using Cashfree Test UPI simulator.
- [ ] Verify atomic rollback if database error occurs.
- [ ] Confirm receipt generated in 80G Tax Vault after payment.
- [ ] Switch `CASHFREE_ENV=PROD` with live production credentials.

---

### 🔴 Testing & Go-Live Verification
- [ ] Verify test transaction using Cashfree Test UPI simulator.
- [ ] Verify atomic transaction rollback if database error occurs.
- [ ] Confirm receipt generated in 80G Tax Vault after payment.
- [ ] Switch `CASHFREE_ENV=PROD` with live production credentials.

