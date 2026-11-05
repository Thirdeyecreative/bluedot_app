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
- [x] **Database Schema**: `Campaign`, `Donation`, `Receipt80G`, and `Refund` SQLAlchemy models (`models/financial.py`).
- [x] **80G Tax Vault Backend**: Historical donation retrieval with PAN status and receipt links (`GET /api/v1/app/donations`).
- [x] **Admin Finance Endpoints**: Admin audit logging and manual refund request handling (`api/v1/admin/finance.py`).
- [x] **Flutter UI Flow**: Interactive `DonationSheet` with amount selectors (₹500, ₹800, ₹1500, Custom), PAN validation, and XP preview (`action_hub_page.dart`).
- [x] **Cashfree Account Activation**: Payment Gateway and Secure ID activated on Cashfree Merchant Dashboard.

---

### 🟡 In Progress / Next Up
- [ ] **Cashfree Credentials Configuration**: Add `CASHFREE_APP_ID`, `CASHFREE_SECRET_KEY`, and `CASHFREE_ENV` to `bluedot_apis/.env` and `app/core/config.py`.
- [ ] **Backend `CashfreeService`**: Build async client in `bluedot_apis/app/services/cashfree_service.py` to create orders, verify payments, and compute HMAC signatures.
- [ ] **API Endpoints**:
  - [ ] `POST /api/v1/app/donations/initiate`: Create pending donation and request Cashfree session ID.
  - [ ] `POST /api/v1/app/donations/verify`: Verify payment with Cashfree and atomically settle XP + 80G.
  - [ ] `POST /api/v1/webhooks/cashfree`: Asynchronous webhook handler for server-to-server notifications.
- [ ] **Flutter SDK Integration**:
  - [ ] Add `flutter_cashfree_pg_sdk` to `bluedot_app/pubspec.yaml`.
  - [ ] Update `AndroidManifest.xml` with UPI Intent package visibility queries (`tez`, `phonepe`, `paytmmp`).
  - [ ] Connect `ActionRepository` and `DonationSheet` to trigger native Cashfree payment checkout.

---

### 🔴 Testing & Go-Live Verification
- [ ] End-to-end sandbox test using Cashfree Test UPI and Simulator.
- [ ] Verify atomic rollback by simulating database timeouts during settlement.
- [ ] Verify idempotency by testing repeated verification calls.
- [ ] Verify 80G receipt PDF generation on successful donation.
- [ ] Switch from `TEST` to `PROD` credentials before public release.

