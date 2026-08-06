# SkillForge AI Gateway

Secure local/server gateway for SkillForge **Copilot AI**, marketplace/teacher/company AI tasks, and **demo + Stripe (test) + PayFast** payment endpoints.

Flutter must never contain Gemini/OpenAI keys. Provider keys live only in this
gateway environment.

**App status docs:** `../PROJECT_COMPLETION.md`, `../docs/CURRENT_PROJECT_STATUS.md`.

## Install

```bash
cd skillforge_ai_gateway
npm install
```

## Create Local Environment

Copy the template and edit your local `.env` file:

```bash
cp .env.example .env
```

On Windows PowerShell:

```powershell
copy .env.example .env
```

Never commit `.env`.

Windows quick start:

```powershell
cd skillforge_ai_gateway
copy .env.example .env
npm install
npm run check
npm run dev
```

Verify `.env` without printing secrets:

```powershell
node -e "require('dotenv').config(); console.log(process.env.AI_PROVIDER, process.env.OPENAI_MODEL, !!process.env.OPENAI_API_KEY)"
```

## Run Mock Mode

Use this for local development without any AI key:

```env
AI_PROVIDER=mock
PORT=3001
```

```bash
npm run dev
```

## Run OpenAI Mode

```env
AI_PROVIDER=openai
OPENAI_API_KEY=your_server_side_key
OPENAI_MODEL=gpt-4o-mini
OPENAI_PREMIUM_MODEL=gpt-4o-mini
OPENAI_FALLBACK_MODEL=gpt-4o-mini
REQUEST_TIMEOUT_MS=120000
```

```bash
npm run dev
```

OpenAI is the primary production provider. `OPENAI_MODEL` is used for normal
Copilot requests. `OPENAI_PREMIUM_MODEL` is used for heavier tasks such as full
course blueprints and admin/company analysis. If the premium model is not
available, the gateway retries with `OPENAI_MODEL`, then with
`OPENAI_FALLBACK_MODEL`. The provider uses OpenAI's Responses API and never
mixes Chat Completions fields with Responses fields.

Windows OpenAI setup:

```powershell
cd skillforge_ai_gateway
copy .env.example .env
npm install
npm run dev
curl.exe http://localhost:3001/health
```

PowerShell POST smoke test:

```powershell
$body = @{
  requestId = "openai-smoke-test"
  userId = "teacher-1"
  role = "teacher"
  accountType = "teacher"
  taskType = "teacherCourseBlueprint"
  userMessage = "Create a Flutter beginner course with 4 modules and 4 quizzes"
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri http://localhost:3001/api/copilot `
  -ContentType "application/json" `
  -Body $body
```

Security:

- Never put OpenAI keys in Flutter.
- Never commit `.env`.
- Restart the gateway after changing `.env`.

## Run Gemini Mode

```env
AI_PROVIDER=gemini
GEMINI_API_KEY=your_server_side_key
GEMINI_MODEL=gemini-2.0-flash
```

```bash
npm run dev
```

## Health Check

```bash
curl http://localhost:3001/health
```

PowerShell:

```powershell
curl.exe http://localhost:3001/health
```

Expected:

```json
{
  "ok": true,
  "provider": "openai",
  "port": 3001,
  "openaiModel": "gpt-4o-mini",
  "openaiPremiumModel": "gpt-4o-mini",
  "openaiFallbackModel": "gpt-4o-mini",
  "hasOpenAiKey": true,
  "geminiModel": "gemini-2.0-flash",
  "hasGeminiKey": false,
  "devAllowLocalhost": true,
  "envLoaded": true,
  "requestTimeoutMs": 120000,
  "mode": "local-dev"
}
```

## Test Copilot POST

```bash
curl -X POST http://localhost:3001/api/copilot \
  -H "Content-Type: application/json" \
  -d '{"requestId":"local-test","userId":"teacher-1","role":"teacher","accountType":"teacher","taskType":"teacherCourseOutline","userMessage":"Create a Flutter beginner course outline"}'
```

PowerShell:

```powershell
$body = @{
  requestId = "local-test"
  userId = "teacher-1"
  role = "teacher"
  accountType = "teacher"
  taskType = "teacherCourseOutline"
  userMessage = "Create a Flutter beginner course outline"
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri http://localhost:3001/api/copilot `
  -ContentType "application/json" `
  -Body $body
```

Useful task checks:

- `teacherCourseOutline`
- `studentTutorExplain`
- `companyJobPostGenerator`
- `customerRefundReasonDraft`
- `freelancerProposalDraft`
- `adminLawRecommendation`

## Flutter Gateway Config

Flutter talks to the gateway only:

```powershell
flutter run -d chrome --web-port=5000 --dart-define=AI_GATEWAY_BASE_URL=http://localhost:3001
```

Release builds must use a deployed HTTPS gateway URL:

```powershell
flutter build web --release --dart-define=AI_GATEWAY_BASE_URL=https://YOUR_GATEWAY_URL --dart-define=AI_PROVIDER=openai
flutter build apk --release --dart-define=AI_GATEWAY_BASE_URL=https://YOUR_GATEWAY_URL --dart-define=AI_PROVIDER=openai
flutter build windows --release --dart-define=AI_GATEWAY_BASE_URL=https://YOUR_GATEWAY_URL --dart-define=AI_PROVIDER=openai
```

Do not add AI API keys to Flutter.

## Flutter Web Local Development

Option A - fixed Flutter port:

```powershell
flutter run -d chrome --web-port=5000
```

Option B - random Flutter ports:

Set this in `skillforge_ai_gateway/.env`:

```env
DEV_ALLOW_LOCALHOST=true
```

Then restart the gateway:

```powershell
npm run dev
```

Health check:

```powershell
curl.exe http://localhost:3001/health
```

Important:

- Do not put API keys in Flutter.
- Do not commit `.env`.
- Restart gateway after changing `.env`.
- `curl` error 7 means the gateway is not running.
- `provider: "mock"` means `.env`/provider selection is wrong or an old process is still running.
- Browser `failed to fetch` usually means CORS, gateway down, or wrong `gatewayBaseUrl`.

For stable Chrome debugging you can run Flutter on a fixed port:

```powershell
flutter run -d chrome --web-port=5000
```

For random Flutter web ports, keep this in gateway `.env`:

```env
DEV_ALLOW_LOCALHOST=true
```

## Environment Variables

- `PORT=3001`
- `HOST=0.0.0.0`
- `NODE_ENV=production`
- `AI_PROVIDER=mock|gemini|openai`
- `OPENAI_API_KEY=...`
- `OPENAI_MODEL=gpt-4o-mini`
- `OPENAI_PREMIUM_MODEL=gpt-4o-mini`
- `OPENAI_FALLBACK_MODEL=gpt-4o-mini`
- `GEMINI_API_KEY=...`
- `GEMINI_MODEL=gemini-2.0-flash`
- `ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5000,http://localhost:8080`
- `DEV_ALLOW_LOCALHOST=true`
- `REQUIRE_AUTH=false`
- `FIREBASE_PROJECT_ID=...` only required when `REQUIRE_AUTH=true`
- `FIREBASE_SERVICE_ACCOUNT_PATH=./skillforge-ai-*-firebase-adminsdk-*.json` required when `REQUIRE_AUTH=true`
- `FIREBASE_SERVICE_ACCOUNT_JSON=...` alternative to the path, raw JSON string
- `MAX_PROMPT_CHARS=8000`
- `REQUEST_TIMEOUT_MS=120000`
- `DEBUG_OPENAI_ERRORS=false`
- `DEBUG_GEMINI_ERRORS=false`

Payment variables live in `.env.example` (demo gateway, Stripe test mode, PayFast).

## Stripe Test Payments

Stripe runs in **test/sandbox mode only**. The gateway refuses to boot when
`sk_live_` or `pk_live_` is configured, and PKR is charged as a zero-decimal
currency (whole rupees).

```env
STRIPE_ENABLED=true
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_CURRENCY=pkr
STRIPE_GATEWAY_BASE_URL=http://localhost:3001
```

Routes:

- `POST /api/stripe/checkout` — hosted Checkout Session (Firebase Bearer token)
- `POST /api/stripe/webhook` — signature-verified events → `finalizePaidIntent()`
- `POST /api/stripe/connect/onboard` — Connect Express onboarding link
- `GET|POST /api/stripe/connect/status` — payout/onboarding status
- `GET /api/stripe/config` — publishable key + flags, no secrets

Forward test webhooks locally:

```powershell
stripe listen --forward-to http://localhost:3001/api/stripe/webhook
```

Offline checks (no charges, no network):

```powershell
npm run stripe:smoke
```

Full setup, API contract, test cards and troubleshooting:
`../docs/STRIPE_INTEGRATION.md`.

## Role Binding And Task Authorization

When `REQUIRE_AUTH=true` the gateway ignores the `role` and `accountType` in the
request body and resolves them from verified sources only, in this order: Firebase
custom claims, then `users/{uid}`, then `admins/{uid}`, then `guest`.

Firestore role binding therefore needs Admin SDK credentials.
`FIREBASE_SERVICE_ACCOUNT_PATH` (or `FIREBASE_SERVICE_ACCOUNT_JSON`) is mandatory
whenever `REQUIRE_AUTH=true`; without it every request binds to `guest` and each
role's AI features return `403`. Node does not hot-reload — restart the gateway
after changing any of these values.

The bound role selects a taskType allowlist, and verified capabilities on the same
user document are unioned onto it:

- `freelancerUnlocked: true` or `freelancer` in `roles[]` adds the freelancer
  taskTypes. This is what lets a student who unlocked freelancer mode through the
  student→freelancer bridge use Freelancer AI while `primaryRole` stays `student`.
- `accountType: 'customer'` adds the customer taskTypes. Customer accounts carry
  no `primaryRole`, so `accountType` also becomes their bound role.

Only `freelancer` and `customer` can be granted this way. Admin and Super Admin
taskTypes are never unioned from `roles[]` — they must come from `primaryRole` or
the `admins` collection. A user without a capability still gets `403`.

Do not "fix" a `403` with `REQUIRE_AUTH=false` or `DEV_ALLOW_ROLE_FALLBACK=true`.
Both are local-debug switches and downgrade production security.

## Render Deployment

Render Web Service settings:

- Root directory: `skillforge_ai_gateway`
- Build command: `npm install`
- Start command: `npm start`
- Health check path: `/health`

Production CORS:

```env
ALLOWED_ORIGINS=https://skillforge-ai.web.app,https://skillforge-ai.firebaseapp.com
DEV_ALLOW_LOCALHOST=false
```

For a full deployment checklist, see `../docs/DEPLOYMENT_AI_GATEWAY.md`.

## Gemini Model Debug

List Gemini models that support `generateContent`:

```powershell
npm run gemini:models
```

This uses `GEMINI_API_KEY` from local `.env` and never prints the key.

## Troubleshooting

- `curl: (7) Failed to connect`: the gateway is not running, crashed, or another process owns port `3001`.
- `/health` shows `provider: "mock"`: `.env` was not loaded, `AI_PROVIDER` is still mock, or an old Node process is still running. Stop the old process and restart `npm run dev`.
- OpenAI `401/403`: key, billing, or project permissions need review.
- OpenAI `429`: rate limit/credit/request size issue. The gateway returns a safe rate-limited response and the app can use Template Fallback.
- OpenAI JSON mode error `Response input messages must contain the word json`: the gateway must include `Return JSON only` in both instructions and input. This project does that in the OpenAI provider.
- OpenAI `400`: usually wrong request format, unsupported parameter, invalid JSON response format, or unavailable model. The gateway uses the Responses API, retries once without JSON mode if JSON mode is rejected, and falls back through `OPENAI_PREMIUM_MODEL` -> `OPENAI_MODEL` -> `OPENAI_FALLBACK_MODEL`.
- OpenAI `408` timeout: keep `REQUEST_TIMEOUT_MS=120000`, use smaller outputs where possible, and start local demos with `gpt-4o-mini`.
- OpenAI model unavailable: start with `OPENAI_MODEL=gpt-4o-mini`, `OPENAI_PREMIUM_MODEL=gpt-4o-mini`, and `OPENAI_FALLBACK_MODEL=gpt-4o-mini`. Upgrade only after confirming model availability for your account.
- Gemini HTTP `400`: usually model/body/config mismatch. The gateway retries once without `responseMimeType` and returns a sanitized unavailable response if Gemini still rejects the request.
- `DEBUG_OPENAI_ERRORS=true` logs only sanitized OpenAI status/body snippets for debugging. It never logs API keys.
- `DEBUG_GEMINI_ERRORS=true` logs only sanitized Gemini status/body snippets for debugging. It never logs API keys.
- Flutter web `failed to fetch`: check `gatewayBaseUrl`, make sure `npm run dev` is running, and use `DEV_ALLOW_LOCALHOST=true` or run Flutter with `--web-port=5000`.
- `403` with `AI access not allowed for this role`: the gateway is reachable and the token is valid, but the bound role/capabilities do not cover the taskType. The response carries `boundRole`, `boundAccountType`, and `roleSource`; check them against `users/{uid}`. `roleSource: fallback-guest` means role binding failed — see Role Binding And Task Authorization above.
- `[AI Auth] Unable to resolve role from Firestore`: Admin SDK credentials are missing or the path is wrong. Fix `FIREBASE_SERVICE_ACCOUNT_PATH` and restart.
- Never paste real API keys into `.env.example`, README, Flutter, or screenshots.

## Safety

- Returns Copilot-compatible structured JSON.
- Does not write Firestore.
- Does not move money.
- Does not approve refunds, payouts, settlements, user bans, deletes, roles, or grades.
- Admin resolution output is recommendation only.
- Users must manually review/apply every draft.
- Never put provider keys in Flutter.
- Never commit `.env`.

## Deployment Note

This gateway can later be deployed to Vercel, Render, Railway, a VM, or another
Node host. It does not require Firebase Cloud Functions or Blaze for local use.
