# SkillForge AI — 10/10 Submission Fix Plan

**Plan date:** 5 August 2026
**Input backlog:** `docs/SUBMISSION_QUALITY_AUDIT.md` (7.5/10 baseline) + 3 user-reported demo bugs
**Status:** PLAN ONLY — no app code has been changed by this document.
**Rule for executors:** read the wave you own, touch only the files listed in that wave, run that wave's verification before handing off.

---

## 1. Goal & Non-Goals

### Goal

Move perceived submission quality from ~7.5/10 to 10/10 by fixing:

1. the three demo-blocking bugs the user hit live (Freelancer AI unavailable, legal pages with no way back, Monetization Center with no way back + off-theme UI),
2. every actionable item in the audit (secrets, repo clutter, silent catches, debug print spam, "coming soon" strings on demo paths),

without changing product behaviour anywhere else.

### Non-Goals — we will NOT rewrite these

| Area | Why we leave it alone |
|---|---|
| `packages/skillforge_sie` internals | Working gesture engine, out of scope, high regression cost |
| `firestore.rules` content or the 150 KB size strategy | Deploy pipeline works via `scripts/deploy-firestore-rules.js`; touching it risks a broken ruleset days before submission. Keep it as a *talking point*, not a change |
| PayFast / demo payment business logic (`skillforge_ai_gateway/src/payfast/**`, `src/demo/**`) | Money paths are verified-working demo paths. Only empty-catch logging inside Flutter services is in scope, never the gateway settlement math |
| `docs/spatial_interaction_engine/**` (19 docs) | Audit flags this as "AI-documentation ceremony", but deleting real docs looks worse than keeping them. Optional single README note only (Wave G) |
| Riverpod/GoRouter architecture, repository layering | Already the strongest part of the project |
| `portfolio_web/` | This is a real deployed artifact referenced by root `netlify.toml`. **Do not delete** (see Wave A explicitly) |
| Any auth/role model in `lib/models/user_model.dart` | Wave B fixes the *gateway* authorization, not the client role model |
| UI redesign outside Monetization Center | Wave D is scoped to one screen using existing theme tokens |

---

## 2. Safety Rules (apply to every wave)

1. **No logic breakage.** Behaviour-preserving edits only. A back button, a log line, a theme token, an ignore rule — none of these may change what data is written or which role can do what (Wave B is the single exception, and there we *widen* an allowlist server-side for users who already hold the capability).
2. **Smallest diff that fixes the symptom.** No opportunistic refactors, no reformatting whole files, no import reordering. If a file needs 4 lines changed, change 4 lines.
3. **Never delete an uncommitted change.** `git status` currently shows ~22 modified files and several new untracked files (courses/commerce work, `skillforge_ai_gateway/**`, `test/course_progress_test.dart`). Wave A uses `git rm --cached` / explicit path deletes only against the exact paths listed. **Never run `git clean`, `git checkout .`, or `git reset --hard`.**
4. **Never `git add .` / `git add -A` until Wave A step 1 is done.** The Firebase Admin private key is currently untracked *and* unignored; a blanket add commits it.
5. **Verify after each wave**, not at the end: `flutter analyze` must be no worse than the pre-wave baseline (capture the baseline count once, before Wave A), plus the wave's own manual demo check.
6. **One wave = one commit** (or one branch). Keeps rollback cheap if a wave misbehaves.
7. **No new dependencies.** Everything here is doable with what's already in `pubspec.yaml`.
8. **Comment discipline.** Do not add narration comments while fixing. A comment is allowed only where it records a real constraint (e.g. why an error is intentionally swallowed).
9. **Gateway restart required** for any `skillforge_ai_gateway/**` change — Node does not hot-reload. Restart before verifying Wave B.

---

## 3. Parallel Waves

| Wave | Title | Scope one-liner | Risk | Blocks / blocked by | Est. |
|---|---|---|---|---|---|
| **A** | Repo hygiene & secrets | Ignore the admin-SDK key, fix the dead gateway ignore rule, `git rm` root scrap | **Low** (no app code) but **highest value** | Independent. Do first because of rule 4 | 25 min |
| **B** | Freelancer / Customer AI unavailable | Gateway role→taskType authorization + honest client error surface | **Medium** (auth path) | Independent of C–G. Needs gateway restart | 60–90 min |
| **C** | Navigation UX — back buttons | Legal pages back arrow, Monetization Center back arrow | **Low** | Shares 1 file with D — see §6 | 30 min |
| **D** | Monetization Center UI polish | Adopt `AdminControlScaffold` + theme tokens on one screen | **Low–Medium** | **Sequential with C** (same file) | 45 min |
| **E** | Empty catch + print/debugPrint cleanup | Add `AppLogger`, replace 25-file print spam, give ~20 silent catches a log line | **Medium** (touches many files) | Independent, but see §6 file-overlap note | 60–75 min |
| **F** | Placeholders / "coming soon" on demo paths | 4 real hits — complete, reword, or hide | **Low** | Independent | 30 min |
| **G** | Docs & light polish | Remove self-graded score, add PayFast/demo honesty line | **Very low** | Independent | 20 min |

---

## 4. Wave Detail

### Wave A — Repo hygiene & secrets

**Risk: Low. Value: highest. Do this first.**

#### A1. Stop the private key leak (CRITICAL)

- **Edit** `.gitignore` — append to the existing secrets block (currently lines 15–23):
  ```gitignore
  **/*firebase-adminsdk*.json
  **/*-adminsdk-*.json
  **/serviceAccount.json
  ```
  Existing `**/serviceAccount*.json` does **not** match `skillforge-ai-4f2da-firebase-adminsdk-fbsvc-411016a137.json` — confirmed by `git check-ignore` exit 1 in the audit.
- **Verify:** `git check-ignore -v "skillforge_ai_gateway/skillforge-ai-4f2da-firebase-adminsdk-fbsvc-411016a137.json"` must print a matching rule and exit 0.
- **Out-of-repo action (owner, not the agent):** rotate the key in Google Cloud Console → IAM → Service Accounts → delete old key, issue new one, update the gateway `.env` path. Ignoring only prevents *future* leaks.
- **Do NOT** delete the key file from disk — the gateway needs it locally for role binding and demo payment finalize (`FIREBASE_SERVICE_ACCOUNT_PATH`). Ignore it, don't remove it.

#### A2. Fix the dead ignore rule (HIGH)

- **Edit** `skillforge_ai_gateway/.gitignore` line 2: delete `skillforge_ai_gateway/`. It can never match from inside that folder, and it is the reason A1's leak went uncaught. Replace with the concrete patterns:
  ```gitignore
  *firebase-adminsdk*.json
  serviceAccount.json
  ```
  Keep the existing `.env`, `*.env`, `node_modules/` lines untouched.

#### A3. Root clutter — exact paths

All of the following are **git-tracked** (verified with `git ls-files`), so removal is `git rm -r --cached <path>` + filesystem delete, not just an ignore rule.

**Delete (tracked scrap):**
```
analyze_log.txt
analyze_output.txt
build_log.txt
dart_files_list.txt
dart_files_utf8.txt
firestore.rules.bak-pre-sizefix
firestore.rules.with-comments.bak
firestore.rules.stripped.tmp
firestore.rules.min.tmp
firestore.rules.partial.tmp
fix_analyze.py
fix_analyze2.py
fix_auth_const.py
fix_imports.py
fix_imports_2.py
fix_syntax.py
refactor_forgot_password.py
refactor_login.py
refactor_scaffold.py
refactor_signup.py
update_auth.py
portfolio_emergency_deploy.zip
portfolio_web_deploy.zip
skillforge_portfolio_pro_single_file.zip
scratch/                              (18 tracked one-off audit scripts)
portfolio_emergency/                  (2 files, superseded by portfolio_web/)
skillforge_portfolio_pro_single_file/ (2 files, superseded by portfolio_web/)
.dart-tool/                           (4 tracked Dart telemetry files — never belongs in git)
```

**Untracked, delete from disk only:**
```
debug-info/
```

**Decide, don't auto-delete:**
- `spikes/sie_camera_hand_cursor/` — ~60 tracked files, a real research spike referenced by the SIE docs. **Recommendation: keep**, and add one line to its `README.md` saying it is an intentional feasibility spike. Deleting it makes the SIE research docs look unsupported.
- `TODO.md`, `PROJECT_COMPLETION.md` — open both first. If they contain stale internal checklists, delete; if they read as intentional project docs, move under `docs/`.

**Never touch:** `portfolio_web/` (live site, wired to root `netlify.toml`), `firestore.rules` (the real one), `.env`, `.env.example`, `firebase.json`, `firestore.indexes.json`, `scripts/`, `functions/`, `packages/`, `test/`.

**Also edit** `.gitignore` to keep this from coming back:
```gitignore
.dart-tool/
debug-info/
*_deploy.zip
analyze_output.txt
build_log.txt
dart_files_*.txt
firestore.rules.*.tmp
firestore.rules.*.bak*
```

**Verification:**
1. `git status` — the ~22 pre-existing modified files must still be listed as modified. If any disappeared, stop and restore.
2. `git ls-files | Measure-Object -Line` — count drops by roughly the number of removed paths.
3. `flutter analyze` — unchanged (nothing in `lib/` was touched).
4. `flutter run -d chrome` still builds. `netlify.toml` still points at an existing directory.

**Additions:** none. **Edits:** `.gitignore`, `skillforge_ai_gateway/.gitignore`. **Deletes:** list above.

---

### Wave B — Freelancer AI (and Customer AI) "unavailable"

**Risk: Medium — this is an authorization path. Read the whole wave before editing.**

#### What the user sees

"AI Gateway Unavailable" / "SkillForge AI is not reachable" on the Freelancer AI assistant. That copy is produced by `_unavailable(...)` in `lib/features/copilot/services/ai_gateway_client.dart:259`, which is *also* what a **403** falls into (`ai_gateway_client.dart:158–172`). So a role-authorization denial is currently mislabelled as "gateway unreachable" — the user cannot tell the two apart. That mislabelling is itself a bug to fix.

#### Ranked root-cause candidates (evidence-backed, verify in this order)

1. **Role binding vs. freelancer capability mismatch — most likely.**
   - `skillforge_ai_gateway/src/security/auth.js:213–304` (`bindRoleFromAuth`) overwrites the client-supplied role with `users/{uid}.primaryRole` whenever `REQUIRE_AUTH=true`.
   - In this app a freelancer is frequently an **unlocked** account, not a `primaryRole == 'freelancer'` account: `lib/models/user_model.dart:318` → `hasFreelancerAccess => freelancerUnlocked || _hasNormalizedRole('freelancer')`, and `lib/features/student/providers/student_freelancer_bridge_provider.dart:230` sets `freelancerUnlocked: true`.
   - So the gateway binds `role = 'student'`, then `authorizeTask` (`auth.js:161–173`) checks `allowByRole['student']`, which contains **no** `freelancer*` taskType → 403 "You do not have access to this AI feature with your current role."
2. **`accountType === 'customer'` hard override.** `auth.js:164`: `effectiveRole = accountType === 'customer' ? 'customer' : role`. Any freelancer whose `users/{uid}.accountType` is `customer` gets the customer allowlist and loses every `freelancer*` task — even with `primaryRole: 'freelancer'`.
3. **Missing Admin SDK credentials → guest fallback.** If `FIREBASE_SERVICE_ACCOUNT_PATH` / `FIREBASE_SERVICE_ACCOUNT_JSON` is unset, the Firestore lookup throws, `auth.js:273–278` logs `[AI Auth] Unable to resolve role from Firestore`, and `auth.js:299` returns `role: 'guest'` unless `DEV_ALLOW_LOCALHOST` or `DEV_ALLOW_ROLE_FALLBACK` is `true` (`.env.example` ships both effectively off). Guest only has `generalAppHelp/explainFeature/rewriteText/summarizeText` → **every** role AI dies, Customer AI included. **This is the check that tells you whether Customer AI is also broken.**
4. **Client role is cosmetic.** `lib/features/marketplace_ai/services/marketplace_ai_service.dart:32–33` hardcodes `role: 'freelancer', accountType: 'professional'`, and `marketplace_ai_assistant_screen.dart:36–37 / 54–55` pass those per entry point. With `REQUIRE_AUTH=true` the gateway discards them. **Conclusion: no client-only change can fix this.** Do not "fix" it by weakening `REQUIRE_AUTH`.
5. **Not the cause, but distinguish them:** quota block renders as "AI Credits Required" (`ai_gateway_client.dart:229`), and release+localhost renders `CopilotAiConfig.releaseLocalhostWarning` (`ai_gateway_client.dart:81`). Different titles — if the user sees those, it is a different problem.

#### Diagnosis steps (do these before editing)

1. Restart the gateway and read the startup summary + console. Look for `[AI Auth] Unable to resolve role from Firestore` (→ cause 3) or `[AI Auth] Using verified-token client role fallback` (→ credentials missing but dev fallback on).
2. Reproduce as a Freelancer user, then as a Customer user, and record the exact HTTP status and message. 401 → token; **403 → authorization (causes 1/2)**; connection error → genuinely unreachable.
3. In Firestore, read the demo freelancer's `users/{uid}`: note `primaryRole`, `accountType`, `roles[]`, `freelancerUnlocked`. This single document decides between causes 1 and 2.

#### Fix (server-side, capability-based — keeps security intact)

- **Edit** `skillforge_ai_gateway/src/security/auth.js`:
  - In `bindRoleFromAuth`, additionally read the capability flags already present on `users/{uid}` (`freelancerUnlocked`, `roles[]`, `accountType`) and return them as a `capabilities` set alongside `role`.
  - In `authorizeTask`, **union** allowlists instead of replacing: base role set **+** `freelancer` set when the verified user holds freelancer capability **+** `customer` set when `accountType === 'customer'`. Never take the union from anything client-supplied — only from the Firestore/claims-verified document.
  - This is a widening of access for users who *already* hold the capability in the database, which is why it is safe: the client still cannot assert a role it does not have.
- **Edit** `skillforge_ai_gateway/src/server.js` (small): include the bound `role`, `accountType`, and `source` in the 403 payload so the Flutter UI can say *why*. Do not change the 401/500 shapes.
- **Edit** `lib/features/copilot/services/ai_gateway_client.dart`: split the 403 branch out of `_unavailable` into a `_blocked`-style response titled e.g. "AI access not allowed for this role" carrying the gateway message. Keep timeouts and connection failures on the existing "unreachable" copy. Behaviour-preserving for the success path.
- **Optional, only if diagnosis points to cause 3:** document in `skillforge_ai_gateway/README.md` that `FIREBASE_SERVICE_ACCOUNT_PATH` is mandatory when `REQUIRE_AUTH=true`, and that the gateway must be restarted after setting it. **Do not** set `REQUIRE_AUTH=false` or `DEV_ALLOW_ROLE_FALLBACK=true` for the demo — that is a security downgrade a judge can spot.

**Files likely touched:** `skillforge_ai_gateway/src/security/auth.js`, `skillforge_ai_gateway/src/server.js`, `lib/features/copilot/services/ai_gateway_client.dart`, `skillforge_ai_gateway/README.md`.

**Do NOT touch:** `src/providers/*.js` (OpenAI/Gemini calls), `src/prompts/systemPrompts.js`, `src/schemas/responseSchema.js`, `src/payfast/**`, `src/demo/**`, `lib/features/marketplace_ai/services/marketplace_ai_sanitize.dart`, `lib/features/ai_usage/**` quota logic, `CopilotAiConfig` feature flags (all six role flags are already `true`).

**Verification:**
1. Freelancer account → AI assistant → each of the 10 `freelancer*` taskTypes returns a draft, not "unavailable".
2. Customer account → the 10 `customer*` taskTypes still work (regression check — Customer AI must not break while fixing Freelancer AI).
3. Teacher, Student, Company, Admin AI each still work — the union must not have narrowed anything.
4. **Negative test:** a Student-only account (no `freelancerUnlocked`) requesting `freelancerProposalDraft` must still get 403. If it succeeds, the union is too wide — revert and scope it.
5. `flutter analyze` clean; gateway restarted; no new console errors.

**Additions:** none required. **Edits:** 3–4 files above. **Deletes:** none.

---

### Wave C — Navigation UX (back buttons)

**Risk: Low.**

#### C1. Legal / consent pages have no back arrow

**Root cause (verified):** two things stack up.
- `lib/features/legal/presentation/return_refund_policy_screen.dart:49–66` defines the shared `LegalDocumentScreen`, whose `SliverAppBar` sets no `leading` — so it relies on `automaticallyImplyLeading`.
- `lib/features/home/presentation/home_screen.dart:739–758` and `:899–915` navigate with `context.goNamed(...)`, which **replaces** the stack. Nothing to imply a back button from, so none renders. Users get stuck on Privacy Policy / Terms / Account Deletion / Return & Refund / Shipping & Service.

**Fix:** add an explicit leading button in the shared `LegalDocumentScreen` only:
```dart
leading: IconButton(
  icon: const Icon(Icons.arrow_back_rounded),
  tooltip: 'Back',
  onPressed: () => context.canPop() ? context.pop() : context.go(RoutePaths.home),
),
```
Because all five legal screens (`privacy_policy_screen.dart`, `terms_of_service_screen.dart`, `account_deletion_policy_screen.dart`, `return_refund_policy_screen.dart`, and the shipping/service policy screen) render through this one widget, **one edit fixes all five**.

**Optionally also** change the home-screen footer links from `goNamed` to `pushNamed` (`home_screen.dart` lines listed above) so the system/browser back gesture works too. `context.pushNamed(RouteNames.downloads)` at line 423 is already the pattern. Low risk, but it *is* a navigation-semantics change — if you do it, re-test the logged-out home → legal → back loop on web and Android.

**Do NOT touch:** `lib/features/legal/providers/legal_provider.dart`, `lib/features/legal/domain/models/legal_policy.dart`, the fallback policy text in each screen, `lib/features/admin/presentation/admin_legal_editor_screen.dart`, or the legal route definitions in `app_router.dart:512–528` (they are correct; `app_router.dart:222–225` already treats these as public routes).

#### C2. Monetization Center has no back arrow

**Root cause (verified):** `lib/features/admin/presentation/monetization_center.dart:19–48` builds its own bare `Scaffold` + `AppBar`, unlike every other admin screen which uses `AdminControlScaffold` (`lib/features/admin/presentation/widgets/admin_control_scaffold.dart`). That scaffold already renders a working back button plus fallback at `admin_control_scaffold.dart:90–100` and `:586–593`. Since the admin menu navigates with `context.go`, `AppBar` has nothing to imply, and the bare `AppBar` supplies no `leading`.

**Fix:** two options — pick based on Wave D.
- **Minimal (if D is deferred):** add an explicit `leading: IconButton(... onPressed: () => context.canPop() ? context.pop() : context.go(RoutePaths.adminDashboard))` to the existing `AppBar`.
- **Preferred (do it as the first step of D):** wrap the screen in `AdminControlScaffold`, which supplies the back button, admin nav, and the correct theme in one move. Do not ship both.

**Verification:** from every entry point (admin menu tile, Super Admin menu, deep link / page refresh on web) the back control returns to the correct dashboard and never dead-ends. Test as Admin **and** as Super Admin — the fallback target differs by role (`admin_control_scaffold.dart:94–98`).

**Additions:** none. **Edits:** `return_refund_policy_screen.dart` (shared widget), `monetization_center.dart`, optionally `home_screen.dart`. **Deletes:** none.

---

### Wave D — Monetization Center UI polish (theme tokens only)

**Risk: Low–Medium (single screen, ~1,200 lines). Sequential after C2.**

**Current state:** `monetization_center.dart` is the odd one out in the admin suite — bare `Scaffold`, transparent `AppBar`, a 5-tab `TabBar`, and hardcoded `AppColors.primary` alpha washes at lines 32–35, 53, 95, 149, 152, 187–194, 208, 223, 310, 799–801, 1007, 1053–1055, 1082–1084, 1181–1191. Cards use `Theme.of(context).cardColor` while the rest of the admin suite uses `AdminPanelCard`.

**Changes (presentation only — zero provider/logic edits):**
1. Wrap in `AdminControlScaffold(title: 'Monetization Center', subtitle: <short description>, currentPath: RoutePaths.adminMonetization, body: ...)`. Remove the inner `Scaffold`/`AppBar`; keep `DefaultTabController` and move the `TabBar` to the top of the body. This delivers C2's back button, the admin top nav, and the maintenance banner for free.
2. Replace ad-hoc card containers with the existing `AdminPanelCard` from `admin_control_scaffold.dart:1285`.
3. Replace hardcoded `AppColors.primary.withValues(...)` surfaces/borders with `colorScheme.surfaceContainerLow`, `colorScheme.outlineVariant`, `colorScheme.primary`, and `AppTheme.radiusXl` / `AppTheme.lightShadowSm` / `AppTheme.darkShadowSm` — the exact tokens `AdminPanelCard` already uses. Keep `AppColors.success` / `AppColors.warning` for plan-active status (semantic, correct) and `AdminStatusChip` where a status chip fits.
4. `_MetricCard` (line 1167) → align padding/radius/border with `AdminPanelCard`.
5. `_MarketplaceTab` (line 994) and the white-on-gradient text at lines 1016–1024 → verify contrast in **both** light and dark themes; `Colors.white` on a gradient breaks in light mode.
6. Empty states in `_TransactionsTab` (lines 1063, 1092) → match the empty-state styling used by `admin_commerce_orders_screen.dart` / `admin_finance_center_screen.dart`.

**Do NOT touch:** `lib/features/admin/providers/admin_monetization_providers.dart`, `lib/features/payment/providers/payment_providers.dart`, `lib/features/payment/models/payment_models.dart`, the plan/credit-pack create & edit dialogs' **logic** (`_PlanCreateDialog`, `_PlanEditDialog`, `_CreditPackCreateDialog`, `_CreditPackEditDialog` — restyle only, never their validation or write calls), and `marketplace_admin_widgets.dart`. Do not change the tab count, tab order, or tab labels — the copilot route catalog and admin nav reference this screen.

**Verification:** all 5 tabs render in light **and** dark theme; create/edit plan and create/edit credit pack still save (write path untouched); Marketplace tab actions unchanged; no overflow at 360 px, 700 px, 1100 px, 1440 px widths; `flutter analyze` clean; screen visually matches `admin_finance_center_screen.dart` / `admin_commerce_orders_screen.dart`.

**Additions:** none. **Edits:** `monetization_center.dart` only. **Deletes:** none.

---

### Wave E — Empty catch + print/debugPrint cleanup

**Risk: Medium — widest file spread. Mechanical, but do it in the two sub-passes below, not as one sweep.**

#### E1. Add a debug-gated logger (the one addition in this plan)

- **Add** `lib/core/utils/app_logger.dart` — a tiny `kDebugMode`-gated wrapper (`AppLogger.debug/warn/error`) using `dart:developer log`. No dependency, no init, no singletons.
- **Optionally edit** `analysis_options.yaml` to enable `avoid_print` under `linter.rules` **after** E2 lands, so the analyzer keeps the repo clean instead of failing the build mid-cleanup.

#### E2. Replace `print` / `debugPrint` — 25 files, verified counts

Highest-value first (these are the ones a judge sees in a web console):

| File | Hits |
|---|---:|
| `lib/providers/app_lock_provider.dart` | 9 |
| `lib/repositories/customer_wallet_repository_impl.dart` | 5 |
| `lib/repositories/resolution_v2_repository.dart` | 5 |
| `lib/features/career_intelligence/services/career_intelligence_service.dart` | 5 |
| `lib/features/copilot/services/ai_gateway_client.dart` | 4 |
| `lib/features/courses/providers/assignment_provider.dart` | 4 |
| `lib/features/student/sie/student_sie_host_controller.dart` | 4 |
| `lib/features/courses/providers/certificate_provider.dart` | 2 |
| `lib/features/courses/providers/grand_test_provider.dart` | 2 |
| `lib/shared/widgets/animated_theme_switcher.dart` | 2 |
| `lib/repositories/invoice_repository_impl.dart` | 2 |
| `lib/services/notification_service.dart` | 2 |
| `lib/features/payment/services/invoice_service.dart` | 2 |
| `lib/features/company/ai_hiring/services/company_ai_hiring_service.dart` | 2 |
| `lib/features/teacher/ai_tools/services/teacher_ai_generation_service.dart` | 2 |
| `lib/features/copilot/services/copilot_data_service.dart` | 2 |
| 1-hit files | `lib/app/router/app_router.dart`, `lib/core/services/firestore_permission_logger.dart`, `lib/features/copilot/providers/copilot_provider.dart`, `lib/features/courses/providers/course_provider.dart`, `lib/features/interview_lab/services/interview_lab_question_engine.dart`, `lib/features/marketplace_ai/services/marketplace_ai_service.dart`, `lib/features/teacher/ai_course_builder/services/teacher_ai_course_builder_service.dart`, `lib/features/company/candidate_intelligence/services/company_candidate_intelligence_service.dart`, `lib/repositories/resolution_settlement_request_repository.dart` |

Rules: delete anything that is pure tracing; convert anything genuinely diagnostic to `AppLogger`; **never log user PII, emails, tokens, wallet balances, or payment identifiers**. Special case: `ai_gateway_client.dart:95–116` logs `[AIGuard]` / `[AIGateway]` lines that are actively useful for Wave B diagnosis — convert them to `AppLogger.debug`, do not delete, and coordinate with whoever owns Wave B (same file).

#### E3. Give ~20 silent catches a voice — verified locations

`catch (_) {}` / `catch (e) {}` with empty bodies, 20 sites across 20 files. Priority order (payments, wallets, hiring first — a swallowed error there shows the user a false success):

```
lib/features/payment/services/demo_payment_finalize_service.dart      (1)
lib/features/courses/data/services/course_purchase_service.dart      (1)
lib/features/company/hiring_lifecycle/services/hiring_lifecycle_service.dart (1)
lib/providers/customer_wallet_provider.dart                          (2)
lib/features/career_intelligence/services/career_intelligence_context_builder.dart (2)
lib/features/courses/providers/grand_test_provider.dart              (1)
lib/features/courses/data/repositories/assignment_repository.dart    (1)
lib/features/courses/data/repositories/grand_test_repository.dart    (1)
lib/features/payment/providers/payment_providers.dart                (1)
lib/features/copilot/services/ai_gateway_client.dart                 (1)
lib/features/interview_lab/services/interview_lab_question_engine.dart (1)
lib/features/interview_lab/services/interview_lab_service.dart       (1)
lib/providers/application_provider.dart                              (1)
lib/providers/interview_provider.dart                                (1)
lib/features/applications/presentation/my_applications_screen.dart   (1)
lib/features/admin/presentation/admin_theme_settings_screen.dart     (1)
lib/features/teacher/sie/teacher_sie_providers.dart                  (1)
lib/features/company/sie/company_sie_providers.dart                  (1)
lib/features/admin/sie/admin_sie_providers.dart                      (1)
lib/features/freelancer/sie/freelancer_sie_providers.dart            (1)
```

**Critical constraint:** add a log line (and, where a user is waiting on the result, a user-facing error) — **do not change control flow**. Several of these swallows are load-bearing: a best-effort notification or an optional analytics write must keep succeeding when it fails. If a catch is *intentionally* silent, leave the flow alone and add the one comment this plan permits, e.g. `// Optional cache warm-up; failure must not block checkout.`

**Do NOT touch:** business logic, retry counts, transaction boundaries, or anything inside `skillforge_ai_gateway/` (its `console.warn`/`console.error` are server logs and are appropriate).

**Verification:** `flutter analyze` clean (and `avoid_print` clean if enabled); `flutter test` — including `test/course_progress_test.dart` — still passes; run the **full purchase → enrollment → certificate** demo path and the **hiring lifecycle** path and confirm no behaviour change; check the browser console is quiet in a release-mode web build.

**Additions:** `lib/core/utils/app_logger.dart`. **Edits:** the ~40 files above (many overlap between E2 and E3 — do E2 and E3 per-file together to avoid two passes over the same file), optionally `analysis_options.yaml`. **Deletes:** none.

---

### Wave F — Placeholders / "coming soon" on demo paths

**Risk: Low.** The audit's "8 hits / 5 files" over-counts: 4 of them are `_CoverPlaceholder`, a legitimate image-upload placeholder widget in `teacher_course_screen.dart:1342–1410`. **Leave that alone.** Four real hits remain:

| File:line | String | Recommended action |
|---|---|---|
| `lib/features/courses/presentation/teacher_lessons_screen.dart:151` | `'Drag and drop to reorder lessons (coming soon)'` | **Highest priority** — teacher demo flow. Either drop the "(coming soon)" parenthetical, or hide the hint if reordering isn't wired |
| `lib/features/profile/presentation/notification_settings_screen.dart:275` | `'Coming soon — tips & announcements not sent yet'` | Reword as an honest state, e.g. "Marketing announcements are disabled for this deployment" |
| `lib/features/release_center/presentation/release_center_screen.dart:121` | `'Downloads coming soon'` | Legitimate empty state when no build is published. Reword to "No public download published yet" |
| `lib/features/release_center/presentation/admin_release_center_config_screen.dart:344` | `'Coming soon'` subtitle for a disabled toggle | Reword to "Public download disabled" so it reads as a config state, not an unfinished feature |

**Do NOT** delete features or hide working entry points to make strings disappear, and do not touch `_CoverPlaceholder`.

**Verification:** grep `lib/` for `coming soon` (case-insensitive) → only intentional, honest strings remain; walk the teacher demo path and the release-center screens; `flutter analyze` clean.

**Additions:** none. **Edits:** 4 files. **Deletes:** none.

---

### Wave G — Docs & light polish

**Risk: Very low. Safe to run any time, including last.**

1. **Edit** `docs/CURRENT_PROJECT_STATUS.md` — remove the self-graded `Overall product readiness (estimate) | **~90 / 100**` row. Replace with objective evidence (module count, test count, demo video link) or nothing. Self-grading in front of a judge reads as weak.
2. **Edit** `docs/CURRENT_PROJECT_STATUS.md:145` area — turn the PayFast sandbox note into a clear one-liner near the top of the payments section: demo payments run through the demo gateway / PayFast sandbox, production credentials are an environment swap. Volunteering this beats being caught by it.
3. **Optionally add** `docs/spatial_interaction_engine/README.md` — 3 lines explaining why 19 documents exist (it was a graded deep-dive sub-feature), which softens the "AI-generated documentation ceremony" impression without deleting anything.
4. **Optionally add** a one-line note in `spikes/sie_camera_hand_cursor/README.md` marking it an intentional feasibility spike (pairs with Wave A's keep-decision).
5. **Do not** rewrite the audit document itself, and do not delete any SIE docs.

**Verification:** docs render; no broken relative links; no self-assigned score anywhere in `docs/`.

**Additions:** up to 2 small README files. **Edits:** `docs/CURRENT_PROJECT_STATUS.md`. **Deletes:** the score row only.

---

## 5. Additions vs Edits vs Deletes (whole plan)

### Additions (3 files max)
| Path | Wave | Why |
|---|---|---|
| `lib/core/utils/app_logger.dart` | E | Debug-gated logging so print spam can go without losing diagnostics |
| `docs/spatial_interaction_engine/README.md` | G (optional) | Explains the 19-doc set |
| `spikes/sie_camera_hand_cursor/README.md` note | G (optional) | Marks the spike as intentional |

### Edits
| Path | Wave |
|---|---|
| `.gitignore` | A |
| `skillforge_ai_gateway/.gitignore` | A |
| `skillforge_ai_gateway/src/security/auth.js` | B |
| `skillforge_ai_gateway/src/server.js` | B |
| `skillforge_ai_gateway/README.md` | B |
| `lib/features/copilot/services/ai_gateway_client.dart` | B + E |
| `lib/features/legal/presentation/return_refund_policy_screen.dart` (shared `LegalDocumentScreen`) | C |
| `lib/features/home/presentation/home_screen.dart` (optional `goNamed` → `pushNamed`) | C |
| `lib/features/admin/presentation/monetization_center.dart` | C + D |
| ~40 files in the Wave E tables | E |
| `analysis_options.yaml` (enable `avoid_print`, after E2) | E |
| `lib/features/courses/presentation/teacher_lessons_screen.dart` | F |
| `lib/features/profile/presentation/notification_settings_screen.dart` | F |
| `lib/features/release_center/presentation/release_center_screen.dart` | F |
| `lib/features/release_center/presentation/admin_release_center_config_screen.dart` | F |
| `docs/CURRENT_PROJECT_STATUS.md` | G |

### Deletes
- Wave A root-clutter list (all tracked → `git rm -r --cached` + filesystem delete): 21 loose files + `scratch/`, `portfolio_emergency/`, `skillforge_portfolio_pro_single_file/`, `.dart-tool/`, and untracked `debug-info/`.
- The self-graded score row in `docs/CURRENT_PROJECT_STATUS.md`.
- **No source file is deleted anywhere in this plan.**

---

## 6. Dependency & Parallelism Notes

### Must run first, alone
**Wave A step A1** (the `.gitignore` key pattern). It is 2 lines and it removes the risk that any other wave's commit leaks the Admin SDK key. Nobody commits anything until A1 is in.

### Truly parallel after A1
**A (rest) ‖ B ‖ C ‖ F ‖ G** — four disjoint file sets:
- A: `.gitignore` files + root scrap (no `lib/`)
- B: `skillforge_ai_gateway/src/**` + one Dart client file
- C: legal shared widget + monetization screen (+ optional home screen)
- F: 4 unrelated presentation files
- G: `docs/` only

### Sequential pairs
1. **C2 → D**: both edit `monetization_center.dart`. Either fold C2 into D as its first step (recommended), or land C2's minimal `leading:` first and let D replace it. Never in parallel.
2. **B → E (for `ai_gateway_client.dart`)**: Wave B rewrites the error branches in the same file where Wave E converts the `[AIGuard]`/`[AIGateway]` debugPrints. Land B first, then let E convert that file's logging. If E must start early, have it skip `ai_gateway_client.dart` and pick it up at the end.
3. **E2 → `avoid_print` lint**: enabling the lint before the sweep finishes floods the analyzer.
4. **Everything → G item 2**: the PayFast/demo honesty line should reflect the final shipped state, so write it after B lands.

### File-overlap warning for Wave E
Wave E touches ~40 files, some of which are **already modified** in the current working tree (`lib/providers/customer_wallet_provider.dart`, `lib/features/courses/data/services/course_purchase_service.dart`, `lib/features/courses/data/repositories/assignment_repository.dart`, `lib/features/courses/data/repositories/grand_test_repository.dart`, `lib/features/courses/providers/grand_test_provider.dart`, `lib/features/payment/services/demo_payment_notification_helper.dart`). Whoever runs E must rebase onto / coordinate with that in-flight work rather than reverting it.

### Recommended execution order
```
A1  (secrets — solo, first)
├─ A2+A3 ─┐
├─ B ─────┤  (parallel)
├─ C1 ────┤
├─ F ─────┤
└─ G1/G3 ─┘
      ↓
   C2 → D          (monetization: back button, then polish)
      ↓
   E  (logger + print sweep + catch pass; ai_gateway_client.dart last)
      ↓
   avoid_print lint on  →  G2 (final honesty line)  →  full demo rehearsal
```

---

## 7. Definition of Done for 10/10

### Security & hygiene
- [ ] `git check-ignore -v` on the Firebase Admin SDK JSON exits 0.
- [ ] Old service-account key rotated in Google Cloud Console (owner action, outside the repo).
- [ ] `skillforge_ai_gateway/.gitignore` has no dead `skillforge_ai_gateway/` rule.
- [ ] Repo root shows only real project files — no `*.tmp`, no `*.bak*`, no `fix_*.py` / `refactor_*.py`, no `*_deploy.zip`, no `analyze_*.txt` / `build_log.txt` / `dart_files_*.txt`, no `.dart-tool/`, no `scratch/` or `debug-info/`.
- [ ] `git status` still lists the pre-existing in-flight modifications — nothing was destroyed.

### Bugs the user reported
- [ ] Freelancer AI produces real drafts for all 10 `freelancer*` taskTypes.
- [ ] Customer AI verified working for all 10 `customer*` taskTypes (explicit regression check).
- [ ] Teacher / Student / Company / Admin AI unchanged and working.
- [ ] A role genuinely lacking a capability still gets a clear 403 — the fix widened nothing it shouldn't.
- [ ] A role denial now reads as an access message, not "gateway unreachable".
- [ ] All five legal pages have a working back control; back also works via browser/system gesture.
- [ ] Monetization Center has a back control from every entry point, as Admin and as Super Admin.
- [ ] Monetization Center is visually indistinguishable in style from Finance Center / Commerce Orders, in light and dark theme.

### Code quality
- [ ] `flutter analyze` — zero issues (and `avoid_print` enabled and clean).
- [ ] `flutter test` — all pass, including `test/course_progress_test.dart`.
- [ ] Zero `print(` / raw `debugPrint(` in `lib/` outside the `AppLogger` implementation.
- [ ] Zero empty `catch (_) {}` / `catch (e) {}` in `lib/` — each either logs or carries a one-line reason comment.
- [ ] Still zero `TODO` / `FIXME` / `HACK` in `lib/` (the audit's strongest signal — don't regress it).
- [ ] No "coming soon" string on any demo path; remaining strings read as honest states.
- [ ] No narration comments added by this work.

### Runtime
- [ ] `flutter run -d chrome` and an Android build both work; no regressions on the purchase → enrollment → certificate path or the hiring lifecycle path.
- [ ] Release-mode web build: browser console is quiet.
- [ ] Gateway starts clean with no `[AI Auth] Unable to resolve role from Firestore` warnings.

### Presentation
- [ ] No self-assigned score anywhere in `docs/`.
- [ ] Demo script opens with the one-line PayFast/demo-gateway disclosure.
- [ ] A prepared answer exists for the `firestore.rules` size-ceiling question.
- [ ] Full demo rehearsal completed end-to-end after the last wave, on the same machine and browser that will be used for submission.
