# SkillForge AI EmailJS Setup

SkillForge uses EmailJS as a client-side transactional mailer fallback. It does not use a private EmailJS key in Flutter.

## Setup

1. Create an EmailJS account.
2. Add an email service in the EmailJS dashboard.
3. Create one generic template with these variables:
   - `to_email`
   - `to_name`
   - `subject`
   - `preheader`
   - `headline`
   - `body`
   - `action_text`
   - `action_url`
   - `footer_note`
   - `app_name`
   - `from_name`
   - `reply_to`
4. Copy the Service ID, Template ID, and Public Key.
5. Configure SkillForge either with dart defines:

```powershell
flutter run -d chrome --dart-define=EMAILJS_SERVICE_ID=your_service --dart-define=EMAILJS_TEMPLATE_ID=your_template --dart-define=EMAILJS_PUBLIC_KEY=your_public_key
```

Or use Admin -> Email Settings to save:

- enabled
- serviceId
- publicKey
- templateId
- fromName
- replyTo
- category toggles

## Security Notes

- Do not add a private EmailJS key to Flutter.
- Restrict allowed domains in the EmailJS dashboard.
- Email failures are logged in `emailEvents` and do not block the primary app action.
- Login emails are optional and deduped once per day.

## Test

1. Open Admin -> Email Settings.
2. Enter Service ID, Public Key, and Template ID.
3. Enable the mailer.
4. Click "Send Test Email".
5. Check `emailEvents` for `sent`, `failed`, or `skipped`.
