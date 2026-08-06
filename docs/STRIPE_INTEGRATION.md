# Stripe Integration — Test / Sandbox Only (PKR)

SkillForge accepts card payments through **Stripe Hosted Checkout in TEST mode**
as an addon beside the existing **Demo gateway** (`/api/demo/*`) and the PayFast
routes. Demo checkout keeps working exactly as before; Stripe is a second
selectable method.

Everything below is sandbox. There is **no Live Stripe account** in this project.

- Server keys: `sk_test_…` only. The gateway **refuses to boot** if `sk_live_` /
  `pk_live_` is configured.
- Client keys: `pk_test_…` only. Never ship a secret key in Flutter.
- Test cards only (`4242 4242 4242 4242`, any future expiry, any CVC).
- Every Stripe payment is labelled **Stripe Test (sandbox)** in the UI.
- Webhook events with `livemode: true` are rejected.

## Money model

| Item | Value |
|------|-------|
| Currency | `PKR` (`STRIPE_CURRENCY=pkr`) |
| Decimals | **Zero-decimal.** PKR 1500 is sent to Stripe as `unit_amount: 1500`, never `150000` |
| Rounding | PKR amounts are rounded to whole rupees *before* the intent is written, so Firestore and Stripe always agree |
| Platform fee | Unchanged, from `skillforge_ai_gateway/src/payfast/fees.js` — courses 20% (or `settings/marketplace.platformCommissionPercent`), service orders 10%, plans / credit packs / wallet top-ups 100% platform |
| Entitlements | Written only by the shared `finalizePaidIntent()` in `src/payfast/finalize.js` (same code path as Demo), so enrollments, wallets, escrow, `commissionLedger` and `course_purchases.platformFee` behave identically |

If the Stripe account rejects PKR, enable PKR in Stripe settings or use an
account that supports it. Do **not** silently switch the code to USD.

## Gateway files

| File | Role |
|------|------|
| `src/stripe/config.js` | Env access, test-key guard (`assertTestOnlyKeys`), public flags |
| `src/stripe/money.js` | Zero-decimal conversion (PKR = whole rupees) |
| `src/stripe/client.js` | Lazy Stripe SDK client, refuses live keys |
| `src/stripe/pricing.js` | Resolves the amount **from Firestore** per payment type |
| `src/stripe/intents.js` | `paymentIntents` + pending `payments` docs, provider tagging, fail/refund marking |
| `src/stripe/connect.js` | Phase 4 Connect Express onboarding, status, destination resolution |
| `src/stripe/handlers.js` | Checkout / Connect / config / return-page handlers |
| `src/stripe/webhook.js` | Signature verification, event de-duplication, `finalizePaidIntent()` |
| `src/tools/stripeSmokeTest.js` | Offline checks (`npm run stripe:smoke`) |

## Environment variables

Add to `skillforge_ai_gateway/.env` (template lives in `.env.example`):

```env
STRIPE_ENABLED=true
STRIPE_MODE=test
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_CURRENCY=pkr
STRIPE_GATEWAY_BASE_URL=http://localhost:3001
STRIPE_APP_RETURN_URL=skillforge://payment/return
STRIPE_MERCHANT_NAME=SkillForge AI
STRIPE_SESSION_EXPIRY_MINUTES=60
STRIPE_WALLET_TOPUP_MIN=100
STRIPE_WALLET_TOPUP_MAX=500000
STRIPE_CONNECT_ENABLED=true
STRIPE_CONNECT_COUNTRY=PK
```

Optional:

| Variable | Purpose |
|----------|---------|
| `STRIPE_SUCCESS_URL` / `STRIPE_CANCEL_URL` | Override the redirect targets. `{intentId}` and `{status}` are substituted; success URLs may also use Stripe's `{CHECKOUT_SESSION_ID}` |
| `STRIPE_ZERO_DECIMAL_CURRENCIES` | Extra zero-decimal currencies (comma separated) |
| `STRIPE_API_VERSION` | Pin a Stripe API version |

`STRIPE_WEBHOOK_SECRET` accepts **several comma-separated secrets**, so the
Stripe CLI secret and the deployed endpoint secret can both be active.

Firebase Admin credentials (`FIREBASE_PROJECT_ID` plus
`FIREBASE_SERVICE_ACCOUNT_PATH` or `FIREBASE_SERVICE_ACCOUNT_JSON`) are required —
Stripe checkout and the webhook write Firestore through the Admin SDK.

Restart the gateway after any `.env` change; Node does not hot-reload.

## API contract (for the Flutter client)

Base URL = `AI_GATEWAY_BASE_URL` (same gateway as Copilot and Demo checkout).
All authenticated endpoints need a Firebase ID token:
`Authorization: Bearer <idToken>`.

### `GET /api/stripe/config` — capability probe (no auth)

Use it to decide whether to show the Stripe method in the chooser.

```json
{
  "ok": true,
  "enabled": true,
  "configured": true,
  "available": true,
  "mode": "test",
  "label": "Stripe Test (sandbox)",
  "currency": "pkr",
  "publishableKey": "pk_test_...",
  "webhookConfigured": true,
  "connectEnabled": true,
  "merchantDisplayName": "SkillForge AI"
}
```

`/health` also reports `stripeEnabled`, `stripeConfigured`, `stripeAvailable`,
`stripeMode`, `stripeCurrency`, `stripeConnectEnabled`, `stripeWebhookConfigured`.

### `POST /api/stripe/checkout` — create a hosted Checkout Session (auth)

Body fields mirror the existing Demo checkout call. **The server never trusts a
client amount** except for wallet top-up: every other type is priced from
Firestore, so `amount` sent by the client is ignored.

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `type` | string | yes | `course`, `credit_pack` (`creditPack` accepted), `plan`, `commerce_order`, `wallet_topup` |
| `courseId` | string | for `course` | May also be passed as `metadata.courseId` |
| `creditPackId` | string | for `credit_pack` | Priced from `credit_packs/{id}.price` |
| `planId` | string | for `plan` | Priced from `plans/{id}.price` |
| `orderId` | string | for `commerce_order` | Priced from `serviceOrders/{id}.totalAmount`; buyer must be `clientId` |
| `amount` | number | for `wallet_topup` only | Bounded by `STRIPE_WALLET_TOPUP_MIN`/`MAX`; ignored for every other type |
| `role` | string | no | `student`, `teacher`, `customer`, `freelancer` — stored on the intent |
| `metadata` | object | no | Passed through to the intent and Stripe metadata (`walletRole: 'customer'\|'freelancer'` selects the wallet) |
| `customerMobile` | string | no | Stored on the intent |
| `returnUrl` | string | no | Post-checkout redirect. Only honoured when its origin is in `ALLOWED_ORIGINS` (or localhost with `DEV_ALLOW_LOCALHOST=true`); otherwise the gateway return page is used |

Amount sources per type:

| `type` | Amount comes from |
|--------|-------------------|
| `course` | `paid_courses/{courseId}` price minus discount, falling back to `courses/{courseId}.price` |
| `credit_pack` | `credit_packs/{creditPackId}.price` |
| `plan` | `plans/{planId}.price` |
| `commerce_order` | `serviceOrders/{orderId}.totalAmount` |
| `wallet_topup` | Client `amount`, range-checked |

Example request:

```json
{
  "type": "course",
  "courseId": "course_123",
  "role": "student",
  "metadata": { "courseId": "course_123", "courseTitle": "Flutter Basics" }
}
```

`200` response:

```json
{
  "ok": true,
  "provider": "stripe",
  "gateway": "stripe",
  "mode": "test",
  "label": "Stripe Test (sandbox)",
  "environment": "test",
  "isDemo": false,
  "isTestMode": true,
  "checkoutUrl": "https://checkout.stripe.com/c/pay/cs_test_...",
  "checkoutPageUrl": "https://checkout.stripe.com/c/pay/cs_test_...",
  "sessionId": "cs_test_...",
  "intentId": "pi_1770000000000_123456",
  "basketId": "pi_1770000000000_123456",
  "paymentId": "pay_...",
  "transactionId": "txn_...",
  "status": "pending",
  "type": "course",
  "amount": 1500,
  "currency": "PKR",
  "platformFee": 300,
  "sellerNet": 1200,
  "platformFeeRate": 0.2,
  "chargeMode": "destination",
  "publishableKey": "pk_test_...",
  "merchantDisplayName": "SkillForge AI",
  "expiresAt": 1770003600,
  "connect": {
    "connected": true,
    "accountId": "acct_...",
    "sellerRole": "teacher",
    "status": "active",
    "reason": null,
    "message": null
  }
}
```

`checkoutPageUrl` is an alias of `checkoutUrl` so existing checkout code that
already reads `checkoutPageUrl` (Demo/PayFast) needs no new field.

Client flow:

1. `POST /api/stripe/checkout`.
2. Open `checkoutUrl` (`url_launcher`, or a new tab on web).
3. Watch the intent with the existing `watchIntent(intentId)` stream on
   `paymentIntents/{intentId}` and wait for `status: 'paid'` (webhook-driven) or
   `status: 'failed'`. Only those two terminal statuses are used, so no new
   status handling is needed on the client; `failureReason` (`payment_failed`,
   `session_expired`, `amount_mismatch`, `session_create_failed`) and
   `errorMessage` explain a failure.
4. Never confirm success from the browser redirect alone — the webhook is the
   source of truth.

Error responses use `{ "status": "error", "code": "...", "message": "..." }`:

| HTTP | `code` | Meaning |
|------|--------|---------|
| 401 | `unauthenticated` | Missing/invalid Firebase token |
| 400 | `invalid-argument` | Missing id for the type, or unsupported type |
| 400 | `out-of-range` | Wallet top-up outside the allowed range |
| 403 | `permission-denied` | Service order belongs to another buyer |
| 404 | `not-found` | Course / plan / credit pack / order missing |
| 409 | `already-purchased` / `already-paid` | Course already owned, order already paid |
| 400 | `failed-precondition` | Free course, inactive plan/pack, no payable total |
| 503 | `stripe-unavailable` | Stripe disabled or not configured on the gateway |
| 502 | `stripe-error` | Stripe API rejected the session |

### `POST /api/stripe/connect/onboard` — Express onboarding (auth)

Request:

```json
{ "role": "teacher", "returnUrl": "https://your-app/wallet" }
```

- `role`: `teacher` (course sales) or `freelancer` (service orders). Default `teacher`.
- `country`: optional ISO code override (defaults to `STRIPE_CONNECT_COUNTRY`).
- `returnUrl` / `refreshUrl`: optional, only honoured for allowed origins.
- `forceOnboarding: true`: return a fresh onboarding link even when active.

Response:

```json
{
  "ok": true,
  "provider": "stripe",
  "mode": "test",
  "accountId": "acct_...",
  "status": "pending",
  "chargesEnabled": false,
  "payoutsEnabled": false,
  "requirementsDue": ["individual.verification.document"],
  "onboardingUrl": "https://connect.stripe.com/setup/e/...",
  "expiresAt": 1770003600,
  "role": "teacher",
  "message": "Open the onboarding URL to finish Stripe test onboarding."
}
```

When the account is already active the response carries `alreadyActive: true` and
a short-lived Express `dashboardUrl`; `onboardingUrl` is set to that same
dashboard link, so a client that always opens `onboardingUrl` still lands on a
useful page instead of an empty URL.

Open `onboardingUrl` in a browser, then re-check status when the user returns.

### `GET` or `POST /api/stripe/connect/status` — payout status (auth)

`GET /api/stripe/connect/status?refresh=false` uses the cached Firestore values;
the default refreshes from Stripe and writes the result back.

```json
{
  "ok": true,
  "provider": "stripe",
  "mode": "test",
  "connected": true,
  "accountId": "acct_...",
  "status": "active",
  "chargesEnabled": true,
  "payoutsEnabled": true,
  "detailsSubmitted": true,
  "requirementsDue": [],
  "dashboardUrl": "https://connect.stripe.com/express/..."
}
```

`status` is one of `not_started`, `pending`, `restricted`, `active` — suitable for
a status chip. When no account exists yet the response is `connected: false`,
`status: "not_started"`, `accountId: null`.

### `POST /api/stripe/webhook` — Stripe only

No Firebase auth; verified with the Stripe signature over the raw body. Not for
client use.

### Return pages (browser)

`GET /api/stripe/return?status=success|cancel&intentId=…` and
`GET /api/stripe/connect/return` render a small sandbox-labelled page with a
deep link back to the app (`STRIPE_APP_RETURN_URL`).

## Firestore fields written by Stripe payments

`paymentIntents/{intentId}` keeps the same shape as Demo/PayFast intents (so
`watchIntent` and `finalizePaidIntent` are unchanged) plus:

```
gateway: 'stripe'          provider: 'stripe'
isDemo: false              isTestMode: true        environment: 'test'
paymentMethod: 'stripe_card'
stripeSessionId, stripePaymentIntentId, stripeChargeId
stripeChargeMode: 'platform' | 'destination'
stripeConnectAccountId, applicationFeeAmount
checkoutUrl / checkoutPageUrl, stripeSessionExpiresAt
refundStatus, refundedAt, refundedAmount   (on charge.refunded)
failureReason, errorMessage                (on failure)
```

`payments`, `transactions`, `commissionLedger`, `commerceTransactions` and
`course_purchases` rows are tagged with `provider: 'stripe'`, `gateway: 'stripe'`,
`isTestMode: true`, `stripeSessionId` and `stripePaymentIntentId`, so Admin
Finance can attribute revenue per provider. Demo rows keep
`gateway: 'skillforge_demo'` and `isDemo: true`.

Connect state lives on `users/{uid}` (`stripeConnectAccountId`,
`stripeConnectStatus`, `stripeConnectChargesEnabled`,
`stripeConnectPayoutsEnabled`, `stripeConnectDetailsSubmitted`,
`stripeConnectRequirementsDue`) and is mirrored to
`stripeConnectAccounts/{accountId}` for webhook lookups.

Webhook bookkeeping: `stripeWebhookEvents/{eventId}` (de-duplication claim) and
`stripeWebhookFailures/{eventId}` (last processing error).

## Webhook events handled

| Event | Action |
|-------|--------|
| `checkout.session.completed` (`payment_status: paid`) | `finalizePaidIntent()` → entitlements |
| `checkout.session.async_payment_succeeded` | `finalizePaidIntent()` |
| `payment_intent.succeeded` | `finalizePaidIntent()` (fallback path) |
| `checkout.session.expired` | intent `status: 'failed'` with `failureReason: 'session_expired'`, payment `Cancelled` |
| `checkout.session.async_payment_failed` | intent `status: 'failed'` |
| `payment_intent.payment_failed` | intent `status: 'failed'` with Stripe's message |
| `charge.refunded` | intent `refundStatus: 'refunded'`, payment/transaction `Refunded`, commission `reversed` (entitlement removal stays a manual admin action) |
| `account.updated` | refresh cached Connect status |

Idempotency has three layers: the `stripeWebhookEvents` claim, the
`status === 'paid'` short-circuit inside `finalizePaidIntent()`, and deterministic
document ids. A replayed event never double-grants or double-credits. A webhook
that throws is deleted from the claim collection and returns `500` so Stripe
retries it.

Underpayment guard: if the amount Stripe reports is lower than the intent amount,
the gateway marks the intent failed instead of granting entitlements.

## Local setup with the Stripe CLI

1. Install the CLI: <https://docs.stripe.com/stripe-cli> (Windows:
   `scoop install stripe` or download the release zip).
2. Log in to the **test** account:

```powershell
stripe login
```

3. Start the gateway:

```powershell
cd skillforge_ai_gateway
npm install
npm run dev
```

4. Forward test events to the local webhook (keep this terminal open):

```powershell
stripe listen --forward-to http://localhost:3001/api/stripe/webhook
```

5. Copy the printed `whsec_…` into `STRIPE_WEBHOOK_SECRET` and restart the
   gateway.
6. Buy something in the app with card `4242 4242 4242 4242`, any future expiry,
   any CVC, any postal code.
7. Watch the CLI log, the gateway log, the Stripe test Dashboard → Payments, and
   the Firestore `paymentIntents` doc flipping to `paid`.

Replay a stored event without paying again:

```powershell
stripe events resend evt_...
```

`stripe trigger checkout.session.completed` also works, but the synthetic event
has no SkillForge `intentId`, so the gateway logs `intent-not-found` and returns
`200`. That is expected — use a real sandbox checkout to test finalization.

### Deployed webhook

Dashboard → Developers → Webhooks → **Add endpoint** (test mode):

- URL: `https://YOUR_GATEWAY/api/stripe/webhook`
- Events: `checkout.session.completed`,
  `checkout.session.async_payment_succeeded`,
  `checkout.session.async_payment_failed`, `checkout.session.expired`,
  `payment_intent.succeeded`, `payment_intent.payment_failed`,
  `charge.refunded`, `account.updated`
- Copy the endpoint's `whsec_…` into `STRIPE_WEBHOOK_SECRET` (comma-append it to
  keep the CLI secret working) and restart.

## Connect (Phase 4) in test mode

1. Stripe test Dashboard → **Connect** → enable it, platform profile → Express.
2. Teacher/freelancer calls `POST /api/stripe/connect/onboard` and completes the
   hosted onboarding with Stripe's test data (`000 000 0000` phone,
   `test@example.com`, any test SSN/document Stripe offers).
3. `GET /api/stripe/connect/status` should report `status: "active"`.
4. Next course/service-order checkout automatically uses
   `application_fee_amount` (the `fees.js` platform fee) plus
   `transfer_data.destination`, and the response returns
   `chargeMode: "destination"`.

Fallback behaviour: if the seller has not onboarded, charges are disabled, or
Stripe rejects the destination, the session is created **platform-only**
(`chargeMode: "platform"`) and `connect.message` explains that the seller must
finish onboarding to receive payouts. Plans, credit packs and wallet top-ups are
always platform-only.

Firestore bookkeeping is deliberately unchanged in both modes: escrow, wallet and
`commissionLedger` rows still come from `finalizePaidIntent()` and `fees.js`, so
the platform fee shown in Admin Finance always matches the Stripe application
fee. With a destination charge Stripe also moves the seller's net to the
connected test account; the escrow rules themselves were not rewritten.

If your Stripe test account cannot create `PK` Express accounts, set
`STRIPE_CONNECT_COUNTRY` to a supported test country (for example `US`). This is
sandbox onboarding only.

## Verify

```powershell
cd skillforge_ai_gateway
npm run check          # syntax
npm run stripe:smoke   # offline checks: PKR zero-decimal, live-key rejection, fee parity
curl.exe http://localhost:3001/health
curl.exe http://localhost:3001/api/stripe/config
```

Manual checklist:

- Demo checkout still succeeds end to end (`/api/demo/checkout` + `/confirm`).
- Stripe test Dashboard shows a payment for each buyer type: course, credit
  pack, plan, service order, wallet top-up.
- `course_purchases.platformFee` / `finalAmount` match `fees.js`.
- Replaying the same webhook event leaves entitlements unchanged.
- A live key in `.env` stops the gateway from booting.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Gateway exits with `Stripe test-mode guard failed` | A live key or a bad prefix is in `.env`. Test keys only |
| `503 stripe-unavailable` | `STRIPE_ENABLED=false` or `STRIPE_SECRET_KEY` missing/not `sk_test_` |
| Webhook returns `400 invalid signature` | Wrong `STRIPE_WEBHOOK_SECRET`, or a proxy rewrote the body. The gateway needs the raw bytes |
| Webhook returns `503 webhook secret not configured` | `STRIPE_WEBHOOK_SECRET` is empty |
| Intent stays `pending` after paying | The webhook never arrived: check `stripe listen`, the endpoint URL, and that the gateway is reachable |
| `intent-not-found` in the logs | The event came from `stripe trigger` (no `intentId` metadata) or a different Firebase project |
| Amount is 100x too big | Something bypassed `money.js`; PKR must stay zero-decimal |
| `403` / `Connect` errors on onboarding | Connect is not enabled on the Stripe test account, or the country is unsupported — set `STRIPE_CONNECT_COUNTRY` |
| Stripe rejects PKR | Enable PKR for the account or use an account that supports it; do not switch the code to USD |
