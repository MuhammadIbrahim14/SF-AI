# SIE 1.0.0 — Rollback Checklist

**Execute immediately if SIE causes incidents, security concern, or unacceptable performance.**

---

## Immediate (< 5 minutes)

1. **Activate PRF kill switch** (preferred — no redeploy):
   - Call `prf.activateKillSwitch()` via admin tooling or emergency config overlay
   - Verify `sieEnabled == false` in rollout snapshot

2. **Or halt canary:**
   - `prf.haltCanary()` — disables rollout for current segment

3. **Or manual rollback:**
   - `prf.rollback(reason: '<incident-id>')` — records reason, disables SIE

## Verify

- [ ] Sensitive routes still deny gesture (billing, secrets, deletion)
- [ ] Traditional mouse/touch/keyboard fully functional
- [ ] Camera pipeline stopped on protected routes
- [ ] No user-facing error loops on route change

## If Kill Switch Insufficient

4. Deploy host build with `PrfConfig(flags: enableSie: false)` default
5. Or remove SIE route listener wrappers (last resort — requires hotfix release)

## Post-Rollback

- [ ] Capture SIDF export / logs (no raw video)
- [ ] File incident report with route, segment, platform
- [ ] Root-cause analysis before re-enabling
- [ ] Security review if IDS bypass suspected

---

## Recovery

Re-enable only after:
- Fix verified in staging
- PRF canary restarted at p0 or p10
- QA sign-off on affected modules
