# Push / email channel hook (future)

In-app notifications are written client-side to Firestore `user_notifications`.
Push (FCM) and email are **not** implemented yet. Use the same documents as the
source of truth when those channels ship.

## Trigger shape

```text
onCreate: user_notifications/{notificationId}
```

Suggested Cloud Function flow:

1. Read the created notification (`userId`, `title`, `body`, `category`, `event`, …).
2. Load `users/{userId}.notificationPrefs`:
   - `push` (bool) — if `true`, send FCM to that user’s device tokens.
   - `email` (bool) — if `true`, enqueue an email (optional; same payload).
   - `categories.{category}` — already enforced at write time by
     `NotificationService`; re-check only if prefs can change mid-flight.
3. Skip delivery when the matching channel toggle is off.
4. Do **not** delete or rewrite the in-app notification; inbox remains primary.

## Prefs document shape

```json
{
  "notificationPrefs": {
    "push": true,
    "email": true,
    "categories": {
      "batch": true,
      "learning": true,
      "hiring": true,
      "commerce": true,
      "support": true,
      "admin": true,
      "marketing": true
    }
  }
}
```

Persisted from the Flutter Notification Hub (`notification_settings_screen.dart`).

## Notes

- Device token registration / FCM send / SMTP are out of scope for the current
  unified inbox drop.
- Category skips happen in `NotificationService._isCategoryAllowed` before create;
  channel toggles (`push` / `email`) apply only in this Cloud Function layer.
