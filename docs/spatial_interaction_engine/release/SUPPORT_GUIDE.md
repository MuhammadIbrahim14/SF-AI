# SIE 1.0.0 — Support Guide

---

## User-Facing

**SIE is optional.** Users can always use mouse, touch, or keyboard.

### Common issues

| Symptom | Likely cause | Resolution |
|---------|--------------|------------|
| Camera not working | Permission denied / no device | Grant permission; use traditional input |
| Cursor jumps | Poor lighting / tracking loss | Improve lighting; reduce motion; use mouse |
| Gesture does nothing | Route is L3/L4 traditional-only | Expected — use click/tap |
| SIE not available | PRF disabled for user segment | Wait for rollout or use traditional input |

### Accessibility

- Enable **Reduced Motion**, **Large Cursor**, or **Dwell Mode** in app accessibility settings (CPMF profiles)
- Screen readers: traditional navigation always supported (ADR-019)

---

## Administrator

- Emergency disable: PRF kill switch (see [OPERATIONS_RUNBOOK.md](OPERATIONS_RUNBOOK.md))
- Billing / admin / secrets routes never accept gesture confirmation

---

## Developer Support

1. Reproduce with SIDF debug overlay (debug builds only)
2. Check `route_activation` log: `routeId`, `sieEnabled`, `decision`
3. Run `flutter test test/*_sie_integration_test.dart`
4. Reference module validation reports 08–12

---

## Escalation

- Security bypass suspicion → immediate kill switch + security team
- Data/privacy concern → verify no raw frame persistence; review camera lifecycle
