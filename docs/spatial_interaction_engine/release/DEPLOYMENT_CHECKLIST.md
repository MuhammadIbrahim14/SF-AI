# SIE 1.0.0 — Deployment Checklist

**Use before enabling SIE in any production environment.**

---

## Pre-Deploy

- [ ] `skillforge_sie` **1.0.0** locked in `pubspec.lock`
- [ ] All automated tests pass (`flutter test` package + host SIE suites)
- [ ] PRF config reviewed: `enableSie` default, canary phase, kill switch clear
- [ ] Firebase / remote config overlays reviewed (if used)
- [ ] No debug SIDF overlay in release builds
- [ ] Camera permission strings present (Android manifest, iOS plist, Web)

## Deploy

- [ ] Deploy host app with five SIE route listeners wired (`app.dart`)
- [ ] Verify traditional input works on all routes (smoke test)
- [ ] Enable PRF for **internal developers** segment only
- [ ] Confirm route activation logs show correct `sieEnabled` per module
- [ ] Spot-check L3 deny routes (payments, billing, secrets) — SIE off

## Post-Deploy

- [ ] Monitor error rates and SIDF telemetry (if collected)
- [ ] Confirm kill switch tested in staging
- [ ] Document rollout percentage and segment in ops log
- [ ] Schedule device-lab P0 gates before expanding canary

---

## Sign-Off

| Role | Name | Date |
|------|------|------|
| Engineering | | |
| QA | | |
| Security | | |
| Operations | | |
