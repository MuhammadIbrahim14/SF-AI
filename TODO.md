# TODO — SkillForge AI

**Updated:** 25 July 2026  
Status docs: [`docs/CURRENT_PROJECT_STATUS.md`](docs/CURRENT_PROJECT_STATUS.md) · [`PROJECT_COMPLETION.md`](PROJECT_COMPLETION.md)

Core Vision product modules are **implemented**. Items below are optional polish / ops — not “missing LMS/marketplace.”

---

## Completed (historical — keep for traceability)

### Onboarding navigation (earlier sprint)
- [x] Router redirect guard audit
- [x] Role selection Step 1/2 UI
- [x] Explicit navigation after role + onboarding submit
- [x] Role dashboards reachable without reload hacks

### Product modules delivered
- [x] LMS: courses, MCQ, grand tests, projects, certificates, skill scores
- [x] Teacher AI course builder / AI tools
- [x] Freelancer marketplace + customer commerce + resolution
- [x] Marketplace AI Phases A–D (Apply-to-form)
- [x] Student Freelancer Bridge Phases 0–5
- [x] Company hiring + AI job post + employment lock
- [x] Career Intelligence
- [x] Copilot + `skillforge_ai_gateway`
- [x] Payments demo + PayFast integration code
- [x] SIE core + role hosts
- [x] MCQ questionId uniqueness (AI import)

---

## Optional remaining

### Quality / ops
- [ ] Expand automated E2E coverage beyond current `test/` suite
- [ ] Production push notifications (if product requires)
- [ ] Live PayFast merchant credentials + IPN QA checklist per env
- [ ] Physical-device / emulator matrix for Android + SIE camera flows
- [ ] Periodic Firestore rules audit after schema additions

### Product polish (only if scoped)
- [ ] Real-time chat / messaging product
- [ ] Deeper analytics dashboards
- [ ] README merge-conflict cleanup verification after doc refresh (root README)

### Housekeeping
- [ ] Keep status docs in sync when adding a new `lib/features/*` module
- [ ] Never commit `skillforge_ai_gateway/.env` or service-account JSON
