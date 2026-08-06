# SIE 1.0.0 — Operations Runbook

---

## Architecture (Runtime)

```
Host App
  └─ AdminSieRouteListener (outermost)
       └─ CompanySieRouteListener
            └─ FreelancerSieRouteListener
                 └─ TeacherSieRouteListener
                      └─ StudentSieRouteListener
                           └─ App content
```

Single **SRDCR** (`SieServiceRegistryCompositionRoot`) owns all engines. Host controllers call `activateRoute(routeId)` on navigation.

---

## Normal Operations

### Enable SIE for a segment

1. Update PRF config: segment targeting + canary percentage
2. `prf.promoteCanary()` only after healthy telemetry
3. Monitor `prf.latestSnapshot.sieEnabled` per route activation

### Disable SIE globally

```dart
await prf.activateKillSwitch();
```

### Route policy lookup

```dart
PrfRouteCatalog.allowsSie('admin.billing'); // false
```

---

## Monitoring

| Signal | Source | Action |
|--------|--------|--------|
| `sieEnabled` false on productivity route | Route activation log | Check PRF + IDS policy |
| High inference latency | SIDF stage metrics | Reduce canary %; check device |
| Kill switch active | PRF snapshot | Expected during incident |
| Camera permission denied | Camera engine state | Fall back to traditional input |

---

## Incident Severity

| Level | Example | Response |
|-------|---------|----------|
| SEV-1 | Gesture bypasses payment confirm | Kill switch + security review |
| SEV-2 | SIE crash on route change | Rollback + hotfix |
| SEV-3 | Cursor jitter / poor UX | Reduce rollout %; traditional input OK |

---

## Contacts

- Engineering: SkillForge AI platform team
- On-call: per org runbook
- Security: IDS policy changes require ADR

---

## Related

- [ROLLBACK_CHECKLIST.md](ROLLBACK_CHECKLIST.md)
- [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)
- [MAINTENANCE_GUIDE.md](MAINTENANCE_GUIDE.md)
