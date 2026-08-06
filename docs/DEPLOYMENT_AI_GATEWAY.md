# SkillForge AI Gateway Deployment

SkillForge Flutter apps must call a hosted HTTPS AI gateway in release builds.
Never put OpenAI, Gemini, or other provider keys in Flutter.

## Architecture

```text
Flutter Web / Android APK / Windows EXE
  -> HTTPS SkillForge AI Gateway
  -> OpenAI API
```

The gateway owns all provider keys through server environment variables.

## Temporary Demo With Cloudflare Tunnel

Use this only for demos from your development machine.

```powershell
cd skillforge_ai_gateway
copy .env.example .env
npm install
npm run dev
```

In another terminal:

```powershell
cloudflared tunnel --url http://localhost:3001
```

Use the generated `https://...trycloudflare.com` URL as
`AI_GATEWAY_BASE_URL`.

## Render Free Web Service

Create a new Render Web Service:

- Root directory: `skillforge_ai_gateway`
- Build command: `npm install`
- Start command: `npm start`
- Health check path: `/health`

Required environment variables:

```env
NODE_ENV=production
AI_PROVIDER=openai
OPENAI_API_KEY=your_server_side_key
OPENAI_MODEL=gpt-4o-mini
OPENAI_PREMIUM_MODEL=gpt-4o-mini
OPENAI_FALLBACK_MODEL=gpt-4o-mini
ALLOWED_ORIGINS=https://skillforge-ai.web.app,https://skillforge-ai.firebaseapp.com
DEV_ALLOW_LOCALHOST=false
REQUEST_TIMEOUT_MS=120000
MAX_PROMPT_CHARS=8000
```

Do not add real keys to `.env.example`, Flutter, Git, or screenshots.

## Health Check

```powershell
curl.exe https://YOUR_GATEWAY_URL/health
```

Expected key points:

- `ok: true`
- `provider: "openai"`
- `hasOpenAiKey: true`
- no API key value is printed

## POST Smoke Test

```powershell
$body = @{
  requestId = "deploy-smoke-test"
  userId = "teacher-1"
  role = "teacher"
  accountType = "professional"
  taskType = "teacherLessonBuilder"
  userMessage = "Create a short lesson about HTML forms. Return JSON only."
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri https://YOUR_GATEWAY_URL/api/copilot `
  -ContentType "application/json" `
  -Body $body
```

## Flutter Build Commands

Web:

```powershell
flutter build web --release --dart-define=AI_GATEWAY_BASE_URL=https://YOUR_GATEWAY_URL --dart-define=AI_PROVIDER=openai
```

Android APK:

```powershell
flutter build apk --release --dart-define=AI_GATEWAY_BASE_URL=https://YOUR_GATEWAY_URL --dart-define=AI_PROVIDER=openai
```

Windows EXE:

```powershell
flutter build windows --release --dart-define=AI_GATEWAY_BASE_URL=https://YOUR_GATEWAY_URL --dart-define=AI_PROVIDER=openai
```

Local development:

```powershell
flutter run -d chrome --web-port=5000 --dart-define=AI_GATEWAY_BASE_URL=http://localhost:3001
```

## Android

The Android app needs `android.permission.INTERNET`.

APK release builds must not use `localhost` as the gateway URL. On an Android
device, `localhost` means the phone itself, not your development computer.

## Windows

Windows EXE builds need internet access through the user's firewall/network and
a public HTTPS gateway URL. Do not store provider keys in Windows build files.

## Troubleshooting

Template Fallback appears:

- Check `/health`.
- Confirm `AI_PROVIDER=openai`.
- Confirm `hasOpenAiKey=true`.
- Confirm the Flutter build used `--dart-define=AI_GATEWAY_BASE_URL=...`.
- Check AI Usage quota/admin settings if the response says credits are blocked.

Gateway unreachable:

- Verify the gateway URL is HTTPS and publicly reachable.
- Render free services can cold start; wait and retry.
- Confirm the service start command is `npm start`.

Localhost in APK/EXE/Web release:

- Rebuild with `--dart-define=AI_GATEWAY_BASE_URL=https://YOUR_GATEWAY_URL`.
- The app warns in release mode if the gateway is still localhost.

OpenAI auth issue:

- Check server-side `OPENAI_API_KEY`.
- Check OpenAI billing/project/model access.
- Never move the key into Flutter.

CORS issue:

- Add your Flutter web origin to `ALLOWED_ORIGINS`.
- Keep `DEV_ALLOW_LOCALHOST=true` only for local development.
- Android APK and Windows EXE usually send no browser `Origin` header.

Render cold start:

- The first request after inactivity can be slow.
- Use `/health` before demos.

## Security Rules

- Never put OpenAI keys in Flutter.
- Never commit `.env`.
- Use the gateway only.
- The gateway does not write Firestore.
- Teacher AI drafts still require manual review/apply/save.
