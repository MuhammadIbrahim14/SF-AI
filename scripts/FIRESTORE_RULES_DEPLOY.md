# Firestore rules deploy (SkillForge)

## Permanent command

```bash
firebase deploy --only firestore:rules --project skillforge-ai-4f2da
```

Or:

```bash
node scripts/deploy-firestore-rules.js
```

## Root cause of the old 409

`firebase-tools` tries PATCH on release `cloud.firestore`, and on **any** PATCH failure falls back to POST create. When the ruleset is rejected (HTTP **400 INVALID_ARGUMENT**, usually size/complexity), create then returns **409 already exists**. The 409 is a masked error.

## What keeps deploys working

- Keep `firestore.rules` source roughly **≤ ~195KB** after helper flattening (avoid deep nested `get()` duplication in hot helpers like `isAdmin` / `adminProfileHasRole`).
- Do **not** delete the `cloud.firestore` release or wipe production data.
- Prefer `firebase deploy --only firestore:rules --debug` if it fails again — inspect the PATCH status, not only the final 409.

## Config

- `.firebaserc` default project: `skillforge-ai-4f2da`
- `firebase.json` → `firestore.rules`
