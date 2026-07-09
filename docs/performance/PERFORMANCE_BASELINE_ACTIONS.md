# DROP — Performance Baseline: Prioritized Actions

> **Phase:** 0.1 — Performance Baseline · **Date:** 2026-07-08 · **Branch:** `core/optimization`
> **Source of findings:** [`PERFORMANCE_BASELINE.md`](PERFORMANCE_BASELINE.md)
> **Status of this document:** **Backlog only.** Phase 0.1 is measurement. **Nothing here is implemented in this phase.** Each item is a candidate for a later, separately-scoped optimization phase.

---

## How to use this list

- Every finding from the baseline is assigned exactly one priority: **Critical · High · Medium · Low**.
- Priority = *performance/scaling impact × user-visibility × risk-if-ignored* — **not** effort.
- Each row carries: the finding ID (traceable to the baseline), evidence anchor, and the **first measurement to take before touching code** (so the fix is provable).
- **Guardrails** (§5) list changes that would look like optimizations but are explicitly **out of scope** — they protect intentional/UI-frozen design per project rulings.

> ⚠️ Order within a priority tier is by ROI, but **do not batch** these. Each is independently shippable and must be re-measured against this baseline.

---

## 🔴 CRITICAL — blocks scale; do first, in isolation

### C1 · Unbounded Firestore reads/streams — add `.limit()` + cursor pagination
- **Finding:** F1 · **Severity:** 🔴 Critical
- **What:** No `.limit()` and **zero `startAfter` cursors** anywhere except notifications (`.limit` only) and a profile uniqueness `.limit(1)`. Task/case/request/broadcast/schedule/template list streams read the **entire collection** and re-emit the full set on every change.
- **Evidence:** `task_remote_datasource.dart:100` (`getAllTasks` reads all), `:134-158` (`watch*` `.snapshots()` no limit), `:369` (templates); baseline §4.3.
- **Why it's #1:** Firestore bills per doc read; an admin opening the task overview reads every task ever created, on every re-emit. Also drives resident memory (§3.3), main-thread sort (F2), and TTI (S1). This is the single 100k-user blocker.
- **Measure first:** Firebase console Usage → reads per admin task-overview open (before). `flutter run --trace-startup` for TTI (before).
- **Scope when done:** datasource → repo interface → cubit → list widget, **feature-by-feature, tasks first**; lean on the 17 existing task tests. Replicate the notifications `.limit` pattern and **add the missing `startAfterDocument` cursor**.

---

## 🟠 HIGH — material impact at current + near-term scale

### H1 · TTI gated on `Future.wait` of home-critical reads
- **Finding:** S1 · **Evidence:** `main.dart:176-181`
- **What:** Routed first frame waits on `statistics.load` + `task.load` (unbounded) + `branch.loadIfNeeded`. First task emission scales with collection size.
- **Depends on C1** (bounding the task stream shrinks the awaited emission). Consider rendering the home shell before the stream resolves.
- **Measure first:** median TTI over 5 `--trace-startup` runs; add temp `AppLog.time('boot','home-warmup')` around step 6.

### H2 · Eager (non-virtualized) list rendering on high-traffic screens
- **Finding:** SC1 · **Evidence:** baseline §2.3
- **What:** Feeds/lists use `SingleChildScrollView` / plain `ListView(children:[…])` (only 10 `.builder` app-wide). Full result set → widgets on every emit. Compounds with C1.
- **Targets:** `task_feed_section`, `notifications_screen`, `my_tasks_screen`, `cases_screen`, `requests_screen`, `employee_home_screen`.
- **Measure first:** DevTools "Track Widget Rebuilds" + frame chart on scroll (before).

### H3 · Wholesale rebuilds — `buildWhen`=0, `BlocSelector`=2
- **Finding:** SC2 / A3 · **Evidence:** baseline §2.2
- **What:** 1000+ LOC screens wrap large trees in one `BlocBuilder` over a freezed union; any field change rebuilds the whole subtree.
- **Targets (only the heavy ones):** `employee_home_screen` (3 `BlocBuilder`/0 selector), `my_schedule_screen`, `manager_schedule_view`, `task_details_screen`. `admin_dashboard_screen` already models the fix (2 `BlocSelector`).
- **Measure first:** rebuild counts under a live task-stream tick (before). **Do NOT** blanket-convert all 41 `BlocBuilder`.

### H4 · Client-side sort/group + full re-emit on unbounded input
- **Finding:** F2 / F3 · **Evidence:** `task_feed.dart`, `statistics_remote_datasource.dart:169`
- **What:** Full-list sort/group/count on the main isolate on every emit. Largely **subsumed by C1** — bounded pages make these cheap. Keep the pure functions.

### H5 · `CACHE_SIZE_UNLIMITED` + unbounded resident lists
- **Finding:** R1 · **Evidence:** `main.dart:155`
- **What:** On-device cache grows without bound; cubit-held lists scale with collection.
- **Sequence:** revisit cache bound **after** C1 (pagination) lands, not before.

### H6 · `task_cubit.dart` god object (1264 LOC)
- **Finding:** A1 · **Evidence:** baseline §5.3
- **What:** CRUD + full lifecycle + checklist/notes + proof upload + **template + recurring-template mgmt** in one class (28% of all cubit LOC).
- **Candidate:** extract `TaskTemplatesCubit` (templates only). Leave live-task lifecycle intact (transitions share `_transitionMutate` + notification fan-out). Maintainability/rebuild-isolation win, not a raw perf win.

### H7 · `task_action_sheets.dart` — 2452 LOC / 40 classes
- **Finding:** A2 · **Evidence:** baseline §5.2
- **What:** Largest file in the app; pure file-decomposition candidate (per-sheet files + promote generic primitives). **Pixels must not change** (UI-frozen rulings).

---

## 🟡 MEDIUM — worthwhile; schedule after High tier

### M1 · Lazy-construct leaf singleton cubits
- **Finding:** S2 · **Evidence:** `injection.dart:184-395` — 15 eager cubits at startup.
- **What:** Convert admin/comms/statistics leaf cubits to lazy getters; keep home-critical ones eager. Lowers baseline memory + shortens `init()`. **Do NOT** adopt a DI framework.

### M2 · Persistent image cache
- **Finding:** R2 · **Evidence:** baseline §3.4 — 13 raw `Image.network`, no disk cache.
- **What:** Introduce a caching image widget (or `cached_network_image`) for branch banners/logos + avatars. Measure repeat-download bytes first.

### M3 · `count()` aggregation for branch-level statistics
- **Finding:** F4 · **Evidence:** `statistics_remote_datasource.dart:169-193`.
- **What:** Admin totals already use `count()`; extend to branch counts to stop reading full doc sets.

### M4 · Monitor unbounded embedded `activityLog`
- **Finding:** F5 · **Evidence:** baseline §4.6.
- **What:** **Monitor only** — migrate to a `tasks/{id}/activity` subcollection (proven pattern from cases/requests) **only on evidence** of array growth toward 1 MB. Do not pre-migrate.

### M5 · Consolidate date/time formatting
- **Finding:** A4 · **Evidence:** baseline §5.7 — 20 month-array files, ~24 bespoke formatters, `intl` used in **0** files.
- **What:** One `core/utils/date_format.dart`; migrate the ~24 sites. Maintainability (perf-negligible); cover with one unit test.

### M6 · Shared sheet/dialog wrappers + stray colors
- **Finding:** A5 · **Evidence:** 23 raw `showModalBottomSheet`, 6 raw `showDialog` (`AppDialog` unused), 65 `Color(0x…)` literals.
- **What:** `showAppSheet()` helper; adopt-or-delete `AppDialog`; sweep stray colors into theme tokens.

### M7 · Decompose screens > 1000 LOC
- **Finding:** A6 / SC3 · **Evidence:** 5 screens (§5.2).
- **What:** Extract sub-sections into `const`-able child widgets (also helps H3). Preserve premium UI exactly.

### M8 · Reduce `setState` churn in `compose_broadcast_screen`
- **Finding:** SC4 · **Evidence:** 21 `setState` in one form.
- **What:** Consolidate form state (e.g. one `ValueNotifier`/form model) to cut rebuild breadth. Low urgency.

---

## 🟢 LOW — hygiene; opportunistic

### L1 · Remove dead `savedAudiences` collection
- **Finding:** F6 · `app_constants.dart:30` — declared, no reads, no rules. Delete or implement.

### L2 · Instrument the home-warmup startup segment
- **Finding:** S3 · `main.dart:163` times steps 1 & 5 but not step 6 (the data-dependent one). Add one `AppLog.time` line (trivially removable).

### L3 · Sweep the 3 raw `ScaffoldMessenger` stragglers into `AppSnackbar`.

---

## Priority summary

| Priority | Count | IDs |
|---|---|---|
| 🔴 Critical | 1 | C1 (F1) |
| 🟠 High | 7 | H1–H7 (S1, SC1, SC2/A3, F2/F3, R1, A1, A2) |
| 🟡 Medium | 8 | M1–M8 (S2, R2, F4, F5, A4, A5, A6, SC4) |
| 🟢 Low | 3 | L1–L3 (F6, S3, snackbar sweep) |

**One-line takeaway:** the only *scaling-critical* item is **C1 (pagination / bounded reads)** — it also drives H1, H2, H4, H5. Everything else is quality-of-render and maintainability that should be measured against this baseline before and after.

---

## Cross-reference: prior optimization audit

`OPTIMIZATION_AUDIT_2026-07-08.md` (repo root) reached the same C1 conclusion from an architecture angle. This baseline **corrects two of its factual claims** (verify against source before acting on the older doc):

1. Notifications use `.limit()` **only** — there is **no `startAfter` cursor anywhere** in `lib/` (the audit implies notifications paginate with a cursor).
2. `package:intl` is imported in **0 files**, not "1 file."

Where the two documents agree (unbounded reads, `task_cubit`/`task_action_sheets` size, rebuild scoping, date-format duplication), treat it as high-confidence.

---

*Actions backlog only — Phase 0.1 ships zero code changes. Re-measure every item against `PERFORMANCE_BASELINE.md` before and after any future implementation.*
