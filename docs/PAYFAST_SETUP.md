# PayFast Pakistan setup (SkillForge AI)

## Overview

SkillForge charges users through **PayFast Pakistan** hosted checkout (Card, JazzCash, Easypaisa, Raast).

Checkout runs on **`skillforge_ai_gateway`** (same Node server as the AI copilot, port **3001**).  
Flutter calls `POST /api/payfast/checkout` with a Firebase ID token — **no Firebase Cloud Functions / Blaze plan required**.  
Flutter never stores full card numbers.

## 1. Where to get `PAYFAST_MERCHANT_ID` and `PAYFAST_SECURED_KEY`

These are **not** in Flutter and **not** in Firebase Console. They come from **PayFast Pakistan** after you become a merchant:

1. Sign up: [https://getstarted.apps.net.pk/signup](https://getstarted.apps.net.pk/signup) (or start from [gopayfast.com](https://gopayfast.com/)).
2. Complete KYC / merchant approval with PayFast.
3. After approval, PayFast issues two values (also described in [their API docs](https://gopayfast.com/docs/)):
   - **MERCHANT_ID** → put in `PAYFAST_MERCHANT_ID`
   - **SECURED_KEY** (secret key) → put in `PAYFAST_SECURED_KEY`  
     If you lose the key, regenerate it from the merchant dashboard / support and update `.env`.
4. Paste them into **`skillforge_ai_gateway/.env`** (copy from `.env.example`).

Until both are set, checkout returns **503 / failed-precondition**: *PayFast gateway is not configured*.

## 2. Gateway env (required)

```bash
cd skillforge_ai_gateway
cp .env.example .env
# edit .env
```

Minimum for payments:

```env
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccount.json
PAYFAST_ENABLED=false
PAYFAST_MERCHANT_ID=your_merchant_id
PAYFAST_SECURED_KEY=your_secured_key
PAYFAST_MERCHANT_NAME=SkillForge AI
PAYFAST_CURRENCY=PKR
PAYFAST_SANDBOX=false
PAYFAST_GATEWAY_BASE_URL=http://localhost:3001
DEV_ALLOW_LOCALHOST=true
```

- **`PAYFAST_ENABLED=false`**: pauses all checkouts (UI: “Payments temporarily unavailable”). Set `true` only after merchant approval + keys.
- **Service account JSON**: Firebase Console → Project settings → Service accounts → Generate new private key. Needed so the gateway can write `paymentIntents` / finalize enrollments after IPN.
- **`PAYFAST_GATEWAY_BASE_URL`**: public URL of this gateway (no trailing slash). PayFast calls `/api/payfast/ipn` on this host. Localhost only works for local tests; for real IPN use a deployed HTTPS URL (or a tunnel).

```bash
npm install
npm run dev
```

Health check should show `"payfastConfigured": true` at `GET /health`.

## 3. Flutter

Use the same base URL as AI:

```bash
flutter run -d chrome --dart-define=AI_GATEWAY_BASE_URL=http://localhost:3001
```

## 4. PayFast callback URLs

| Purpose | URL |
|---------|-----|
| IPN | `{PAYFAST_GATEWAY_BASE_URL}/api/payfast/ipn` |
| Return (success/fail) | `{PAYFAST_GATEWAY_BASE_URL}/api/payfast/return?...` (set automatically in the checkout form) |
| Hosted redirect page | `{PAYFAST_GATEWAY_BASE_URL}/api/payfast/checkout-page?intentId=…` |

## 5. Platform fees

| Type | Platform fee |
|------|----------------|
| Teacher plan / credit pack / wallet top-up | 100% (SaaS revenue) |
| Paid course | Marketplace `%` from `settings/marketplace` (default 20%) |
| Freelancer commerce order | 10% (existing commerce config) |

Fees are written on `paymentIntents`, `payments`, and `commissionLedger`.

## 6. App screens

- Shared checkout sheet: method picker → PayFast hosted page
- **My Transactions** (`/billing/transactions`) — all roles
- **Admin Super Transactions** (`/admin/super-transactions`) — full ledger

## 7. Go live

1. Set `PAYFAST_ENABLED=true` in `skillforge_ai_gateway/.env`.
2. Keep `PAYFAST_SANDBOX=false` for production endpoints (default).
3. Set `PAYFAST_GATEWAY_BASE_URL` to your **public HTTPS** gateway URL.
4. Restart the gateway after changing `.env`.
5. Run Flutter with payments on:
   `flutter run -d chrome --dart-define=PAYFAST_ENABLED=true --dart-define=AI_GATEWAY_BASE_URL=http://localhost:3001`

## Note on `functions/`

Legacy PayFast Cloud Functions code may still exist under `functions/payfast/`. The **active** path is **`skillforge_ai_gateway`**. Prefer not deploying Functions for payments.
