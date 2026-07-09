# DROP — Production Readiness Audit

> **`core/optimization`** · **Date:** 2026-07-08 · **Scope:** reliability, error handling, lifecycle, memory leaks, offline, disposal, logging, retry, loading/error/empty states, Firebase exceptions, hardening.
> **Mandate:** identify only issues affecting **stability / maintainability / real-world production**. No architecture refactor, no rendering optimization. Report first; implement only **provably safe** fixes, one at a time, analyzer + tests after each.

---

## 0. Headline

**DROP is already well-hardened for production.** Across every audited dimension the codebase shows deliberate, correct patterns — not aspirational ones. The audit found **zero critical or high-severity reliability defects**. The only actionable items are **minor observability gaps** (silent best-effort failures aren't logged). This report documents the healthy invariants explicitly (so they're defended against regressions) and implements the one provably-safe hardening.

> **Verification note:** live runtime verification (running the app) remains blocked on the Phase 0.2 signing/auth issue. Every finding below is from **static inspection**; the one implemented fix is behavior-identical by construction and verified by analyzer + the 597-test suite.

---

## 1. What is already correct (defend — do NOT "fix")

| Area | Evidence | Verdict |
|---|---|---|
| **Controller/subscription disposal** | 58 `dispose()` + 10 cubit `close()`; a per-file scan for un-disposed `AnimationController`/`Timer`/`ScrollController`/`StreamSubscription`/`TabController`/`FocusNode`/`TextEditingController` found **no real leaks** — every flag was either a widget **receiving** a controller as a param (`SegmentedTabBar`, `AppPasswordField`, `CompensationFields`) or a **correct** teardown. | ✅ Healthy |
| **Stream-merge teardown** | `schedule_remote_datasource.watchEmployeeSwaps` builds a `StreamController` whose `onCancel` cancels **both** upstream subscriptions (textbook single-subscription merge; documented inline). | ✅ Healthy |
| **Stream `onError` handling** | **Every** cubit `.listen()` (auth, cases, requests, task, broadcast, notification, branch-ops, shift-swap) passes `onError` → emits an `.error(...)` state, guarded by `if (!_hasSnapshot)` so a **transient** stream error never clobbers already-loaded data. No "stuck on loading" path exists. | ✅ Exemplary |
| **Firebase exception mapping** | Datasources use `on FirebaseException catch (e) → throw ServerException(e.message ?? '…honest message…')` and also catch `TimeoutException` (89 `FirebaseException` handlers). Errors reach the UI as honest, specific messages. | ✅ Exemplary |
| **Loading / error / empty states** | 17 state unions model `.loading` + `.error`; 38 screens/widgets render an error/retry branch; 44 `DropEmptyState`/`AppEmptyState` usages; skeleton + loading widgets in `core/widgets/`. | ✅ Healthy |
| **Retry flows** | Startup `SplashPage.onRetry` re-runs bootstrap; 31 in-app `Retry`/`onRetry` references re-invoke the cubit load. | ✅ Healthy |
| **Offline behavior** | Firestore persistence enabled at boot; `statistics` `count().get()` has an explicit **offline cache fallback** (`Source.cache`); streams serve the local cache automatically. | ✅ Healthy |
| **Observability** | `CrashReporter` installs **4 crash funnels** (FlutterError, PlatformDispatcher, isolate, zone) + persists a report for next-launch export; `AppLog` records a bounded breadcrumb ring **in release too**, attached to crash reports; `CrashContext` tracks last action/route/user. | ✅ Exemplary |
| **Best-effort swallows are intentional** | The 6 `catch (_) {}` sites are all **enrichment** (branch-name lookup, user-directory hydration, seen-dot persistence) — never the primary data load. Failing them degrades a label, not the feature. | ✅ Correct pattern |
| **Log hygiene** | **0** `print()` calls. `debugPrint` only in `AppLog` itself (+1 boot diagnostic). | ✅ Healthy |

---

## 2. Findings (prioritized)

### 🔴 Critical — none
### 🟠 High — none

### 🟡 Medium

**M1 — Best-effort swallows have zero observability (IMPLEMENTED).**
- **Where:** `task_cubit._loadBranchNames`/`_ensureDirectory` (2), `case_list_cubit._loadBranchNames`/`_ensureDirectory` (2), `requests_list_cubit` branch-name load (1), `case_seen_store._persist` (1) — all `catch (_) {}`.
- **Why it matters:** the swallow is correct (non-fatal), but a **persistent** failure (e.g. a rules change breaks `getBranches`/`getUsersByBranch`, or the app-support dir is unwritable) is **completely invisible** — cards silently lose names / unread dots silently stop persisting, with nothing in logs or crash breadcrumbs to diagnose it. Production incidents that "aren't errors" are the hardest to find.
- **Fix (provably safe):** bind the exception and record it via `AppLog.warning(scope, '…: $e')`. Control flow is unchanged (still caught, still non-fatal); it only adds a breadcrumb (release) + debug line. `AppLog._emit` cannot throw. → **§4 Phase 1.**

**M2 — 35 `developer.log` calls bypass `AppLog` (recommend, not implemented).**
- **Where:** `main.dart`, `notification_service`, `case`/`request` datasources & cubits, `task_cubit`, `branch_operations_cubit` (10 files).
- **Why it matters:** `developer.log` output is **not** captured in `AppLog`'s breadcrumb ring, so those events are absent from crash reports — a real observability gap. `AppLog`'s own doc calls itself "the single entry point for every log line."
- **Why not implemented here:** converting 35 call-sites across 10 files is a broader change than "one provably-safe fix," and each needs a scope/category judgment. Staged as a follow-up consistency pass, not done in this audit.

### 🟢 Low

- **L1 — `usage_tracker._timer` / `case_seen_store` not cancelled on shutdown.** Static services; the debounce timer self-nulls after each flush (at most one pending). Negligible; no fix.
- **L2 — one `debugPrint` in `splash_page` prints in release.** A single boot diagnostic; harmless noise. Optional.
- **L3 — no `.empty` state factory.** Empty is handled at the widget layer (loaded-with-empty-list → `DropEmptyState`), which is fine and consistent. Note only.

---

## 3. Dimension-by-dimension summary

| Dimension | Status | Notes |
|---|---|---|
| Reliability | ✅ | onError everywhere; no uncaught stream paths |
| Error handling | ✅ | Firebase/Timeout → honest `ServerException` |
| Lifecycle management | ✅ | `dispose`/`close` discipline; `mounted`/`isClosed` guards; `use_build_context_synchronously` lint passes |
| Memory leaks | ✅ | none found (all flags param-owned or correct) |
| Offline behavior | ✅ | persistence + `count()` cache fallback |
| Controller disposal | ✅ | verified per-file |
| Logging | 🟡 | M1/M2 observability gaps; otherwise clean (0 `print`) |
| Retry flows | ✅ | startup + 31 in-app |
| Loading/error/empty states | ✅ | modelled + rendered |
| Firebase exceptions | ✅ | mapped + specific |
| Production hardening | ✅ | 4 crash funnels, breadcrumbs, crash context |

---

## 4. Implementation log (provably-safe fixes only)

### Phase 1 — M1: observability for best-effort swallows ✅
- **Change:** `catch (_) {}` → `catch (e) { AppLog.warning('<scope>', '<best-effort X> failed: $e'); }` at the 6 enrichment sites.
- **Safety proof:** identical control flow (caught, non-fatal, no re-throw, no state change); adds only a breadcrumb + debug line; `AppLog.warning` is total (no throw).
- **Verification:** analyzer clean; full suite unchanged (same 3 pre-existing, unrelated failures); no generated files touched.

*(No other change met the "provably safe **and** worth doing" bar — the codebase is otherwise production-ready. M2 and the Lows are documented for a future consistency pass, deliberately not implemented blind.)*

---

*Audited by static inspection on `core/optimization` @ 2026-07-08. Only Phase 1 (swallow observability) was implemented; everything else is either already correct or a documented recommendation.*
