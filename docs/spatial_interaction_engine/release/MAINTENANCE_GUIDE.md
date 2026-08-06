# SIE 1.0.0 — Maintenance Guide

---

## Versioning

- **Documentation set:** frozen at 1.0 — changes require 1.1 process + ADR
- **Package:** SemVer — patch for fixes, minor for backward-compatible catalog additions, major for breaking contracts

## Adding a New Route Policy

1. Add entry to module catalog (`Sie*RouteCatalog`)
2. Register in `SieSkillForgeRouteCatalog.defaults`
3. Map host `RouteNames` in `*_sie_route_mapper.dart`
4. Add IDS level per doc 03 — default sensitive routes to **disabled L3**
5. Extend integration test matrix
6. No engine changes unless measured hotspot

## Dependency Updates

- `camera`, MediaPipe bindings: test vision provider + camera engine suites
- `flutter_riverpod`: verify ADR-008 compliance (no HF streams in host)

## Long-Term Support (1.0.x)

- Security policy fixes: patch release
- New module routes: minor release
- Engine algorithm changes: require measurement evidence + validation report

## Technical Debt

- Device-lab automation for FPS/gesture accuracy (P0)
- Large-dataset UI perf harnesses (P1)
- Consolidate debug chips across modules (P2)
