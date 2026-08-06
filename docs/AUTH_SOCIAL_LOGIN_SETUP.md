# SkillForge AI Social Login Setup

This project supports Firebase Authentication social sign-in for:

- Google
- GitHub

No API keys or OAuth client secrets are stored in Flutter code. Configure the providers in Firebase Console and provider dashboards.

## 1. Enable Google Provider

1. Open Firebase Console.
2. Select the SkillForge AI project.
3. Go to Authentication > Sign-in method.
4. Enable Google.
5. Choose the public support email.
6. Save.

## 2. Android SHA-1 / SHA-256

Google sign-in on Android requires app fingerprints.

1. Run:

   ```bash
   cd android
   ./gradlew signingReport
   ```

   On Windows PowerShell:

   ```powershell
   cd android
   .\gradlew signingReport
   ```

2. Copy SHA-1 and SHA-256 for the debug/release variant you test.
3. Firebase Console > Project settings > Android app.
4. Add SHA-1 and SHA-256.
5. Download the updated `google-services.json` if Firebase instructs you to.

## 3. Enable GitHub Provider

1. Firebase Console > Authentication > Sign-in method.
2. Enable GitHub.
3. Firebase shows an OAuth callback URL. Copy it.

## 4. GitHub OAuth App

1. Go to GitHub > Settings > Developer settings > OAuth Apps.
2. Create a new OAuth App.
3. Homepage URL: your SkillForge app URL or local dev URL.
4. Authorization callback URL: paste the Firebase callback URL from the GitHub provider setup.
5. Copy the GitHub Client ID and Client Secret.
6. Paste them into Firebase Console > Authentication > GitHub provider.
7. Save.

Do not put the GitHub Client Secret in Flutter, Firestore, or public docs.

## 5. Web Authorized Domains

For Flutter Web:

1. Firebase Console > Authentication > Settings > Authorized domains.
2. Add your hosting domain.
3. For local testing, ensure `localhost` is allowed.

## 6. Android Test Steps

1. Confirm Google provider is enabled.
2. Confirm SHA-1 and SHA-256 are configured.
3. Run the app on Android.
4. Tap `Continue with Google`.
5. Existing users should route to their dashboard.
6. New users should route into account/role onboarding.

GitHub native OAuth depends on Firebase Auth platform support. If a platform does not support native provider sign-in, use Flutter Web for GitHub OAuth testing.

## 7. Web Test Steps

1. Run Flutter Web.
2. Tap `Continue with Google`.
3. Confirm popup opens and returns to SkillForge.
4. Tap `Continue with GitHub`.
5. Confirm popup opens and returns to SkillForge.
6. Existing users route to their dashboard.
7. New professional users route to role selection/onboarding.
8. New customer-mode users route to customer workspace.

## 8. Windows Caveat

Firebase OAuth provider popup flows are best supported on Web. For Windows desktop builds, provider availability can vary by plugin/platform support. If GitHub or Google native provider sign-in is unavailable on Windows desktop, test social login through Web.

## 9. Free / No-Cost Note

Firebase Authentication social providers are available without Cloud Functions and without Blaze for normal app authentication. Firebase quotas and provider-specific OAuth limits still apply. This implementation does not require Cloud Functions, payment APIs, or secrets in Flutter.

