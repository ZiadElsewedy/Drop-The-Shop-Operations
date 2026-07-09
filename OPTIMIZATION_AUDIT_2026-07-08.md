# DROP — Engineering Optimization Audit

> **Date:** 2026-07-08 · **Auditor role:** Principal Flutter Architect
> **Scope:** Full codebase (`lib/` 427 files / ~95k LOC, `test/` 97 files / ~10.7k LOC / 738 cases, `functions/`, rules)
> **Mandate:** Find technical debt and produce a phased optimization roadmap for a codebase that must scale to 100k+ users, multiple developers, and a possible backend migration off Firebase. **Audit only — no code changed.**
>
> **Guiding constraint (from project philosophy):** premium *lean* internal ops tool, not enterprise SaaS. Every recommendation below is filtered for measurable benefit. Where the current design is already correct, this report says so explicitly and recommends **no change**.

---

## 0. Executive summary

**This is a well-architected codebase.** The Clean Architecture boundaries are real and enforced, not aspirational. Verified invariants:

- ✅ **Firebase SDK imports appear in `data/` + 5 core files only.** Zero leakage into `presentation/` or `domain/` (grep-verified).
- ✅ **`domain/` is pure Dart** — no Firebase, no Flutter-material coupling in entities.
- ✅ **`presentation/` never imports `data/`** — the dependency arrow points inward everywhere.
- ✅ Every model has `fromMap`/`toMap` + `toEntity`/`fromEntity`; `Timestamp ⇄ DateTime` conversion is quarantined at the model boundary.
- ✅ Snackbars centralized (`AppSnackbar` + `context.showSuccess/showError`) — only 2 raw `ScaffoldMessenger` call-sites remain.
- ✅ 0 `TODO`/`FIXME`/`HACK` markers; 738 test cases; strong coverage on the two hardest domains (task 17 files, schedule 11 files).
- ✅ Server-authoritative security: privileged writes (broadcasts, notifications, swap finalization, account creation) go through Admin-SDK Cloud Functions; branch isolation enforced in rules.

**The codebase does not need re-architecting. It needs scaling hardening and consolidation.** The gap between "works well for a few branches" and "supports 100k users + a team of developers" is concentrated in five places:

| # | Theme | Severity | One-line |
|---|---|---|---|
| 1 | **Unbounded Firestore reads** | 🔴 Critical | Task/case/request/broadcast streams load *entire* collections — no `.limit()`, no cursor pagination (except notifications). This is the single blocker to 100k scale. |
| 2 | **Test coverage holes on critical paths** | 🟠 High | `auth`, `requests`, `cases`, `communications`, `notifications`, `profile`, `statistics` have **0 test files**. |
| 3 | **God objects** | 🟠 High | `task_cubit.dart` (1264 LOC / 23 methods / 3 repos + 7 use cases) and `task_action_sheets.dart` (2452 LOC / 40 classes). |
| 4 | **Duplication clusters** | 🟡 Medium | Date/time formatting re-implemented in ~15 files; 19 raw bottom-sheets with no shared wrapper; reusable UI primitives trapped as private classes. |
| 5 | **Rebuild scoping** | 🟡 Medium | 39 `BlocBuilder` vs 4 `BlocSelector`, `buildWhen` used **0 times** — large screens rebuild wholesale on any state change. |

Nothing here is a rewrite. The roadmap in §14 is 7 incremental phases, front-loaded on the one Critical item.

---

## 1. What is already excellent (do NOT change)

Explicit "leave it alone" list — these are correct and should be defended against well-meaning refactors:

| Area | Verdict |
|---|---|
| **Layer separation** | Textbook. The `data → domain ← presentation` arrows hold under grep. Keep the "hybrid cubit" convention (writes via use cases, reads via repository streams) — it is documented and intentional. |
| **Model ⇄ Entity mapping** | Correct DTO/entity split already exists. `Timestamp` never escapes `data/`. Do **not** add a third "DTO vs model" layer — that would be the over-engineering the philosophy warns against. |
| **freezed entities + union states** | Immutable, exhaustively-matched. Keep. |
| **Enum design** | Each enum owns `.value` + `fromString` with a safe default (`unknown → general`). This is the right pattern for schema-forward compatibility. Keep. |
| **Repository interfaces** | 13 clean abstract contracts in `domain/repositories/`. This is *the* thing that makes a backend swap feasible. Do not collapse them. |
| **Security model** | Server-authoritative, branch-isolated, privilege-frozen self-updates, privacy-split case identity. Genuinely strong. |
| **Startup sequence** | `main.dart` cold-start rendezvous, offline persistence set before first op, home-critical scopes warmed in parallel, everything else lazy. Well-engineered. |
| **`context_extensions.dart`** | `currentUser`/`currentRole`/`isAdmin`/`showSuccess` — exactly the right amount of sugar. Extend this file rather than inventing new patterns. |

---

## 2. Architecture

### 2.1 🟢 Feature boundaries & dependency direction — HEALTHY, no action
Verified clean. `employee`/`manager`/`settings` intentionally have no data layer (they are role shells / compose other features). `operations` has domain+presentation only (a read/derive cockpit over `task` + `schedule`). This is correct, not a smell.

### 2.2 🟡 Cross-feature coupling via shared repositories — Medium
- **Location:** `injection.dart:204-350` — `branchRepository`, `scheduleRepository`, `notificationRepository` are constructed early and injected into `TaskCubit`, `CaseListCubit`, `BroadcastCubit`, `BranchOperationsCubit`, `RequestsListCubit`.
- **Why it matters:** `TaskCubit` depends on `scheduleRepository` + `branchRepository` + `notificationRepository`. A feature is not independently movable if its cubit reaches into three other features' repositories. For a multi-developer team this creates merge contention and blast radius.
- **Recommended solution:** This is *acceptable coupling through domain interfaces* (it depends on `ScheduleRepository` the interface, not the impl), so **do not abstract it away**. Instead: (a) document the coupling graph in one place (mostly done in `ARCHITECTURE.md §1.5`), and (b) where `TaskCubit` needs "resolve shift-task recipients," consider a thin `TaskNotificationTargets` domain service so `TaskCubit` depends on one narrow port instead of the whole `ScheduleRepository`. **Low priority** — flag, don't fix yet.
- **Estimated impact:** Reduced blast radius; clearer ownership for parallel work. Not a scaling issue.

### 2.3 🟡 Documentation drift in `ARCHITECTURE.md` — Medium (docs, not code)
- **Location:** `ARCHITECTURE.md §6.2` claims "Collections with no rule block: `requests`, `counters`, `savedAudiences`, `config`." **This is stale** — `firestore.rules:562` (requests), `:580` (request events), `:614` (counters), and `storage.rules:52` (request media) all exist and are correct.
- **Why it matters:** A stale architecture doc that under-reports security coverage will send the next engineer (or auditor) chasing a non-existent hole, or worse, "fixing" already-correct rules.
- **Recommended solution:** Correct §6.2. `savedAudiences` genuinely has no rules and no reads — see §11.3 (dead declaration).
- **Estimated impact:** Prevents wasted investigation; keeps the doc trustworthy as the team grows.

---

## 3. Dependency Injection

### 3.1 🟡 Everything is an eager app-wide singleton — Medium
- **Location:** `lib/core/di/injection.dart` — one 210-line `init()`; every repository, datasource, use case, and cubit is `static late final` and constructed at startup.
- **Why it matters:** At startup the app builds **15 singleton cubits + 13 repositories + 14 datasources** whether or not the signed-in role will ever use them. An employee never opens the admin module, yet `adminUsersCubit`, `broadcastScheduleCubit`, `statisticsRepository`, etc. are all constructed. This is memory allocated up front and a longer cold start. It also means no scoping — a cubit's stream subscriptions live for the whole process.
- **Recommended solution:** **Do not migrate to `get_it`** — the hand-rolled locator is fine and explicit. Two targeted wins instead:
  1. Convert leaf cubits that are only used in one area (admin, communications, statistics) to **lazy getters** (`static AdminUsersCubit get adminUsersCubit => _adminUsersCubit ??= ...`). Repositories/datasources they need can stay eager (cheap).
  2. The two **per-entity cubits** (`createCaseConversationCubit`, `createRequestDetailCubit`) are already correctly on-demand — good pattern; extend it to any future "one per opened X" cubit.
- **Estimated impact:** Lower baseline memory, faster cold start for the common (employee) role. Low risk (construction is pure).

### 3.2 🟢 Service Locator pattern — acceptable, no action
The static locator is simple and testable-enough (cubits receive their deps via constructor; only `injection.dart` touches the statics). Do not introduce a DI framework for a codebase this size — that is unnecessary abstraction.

### 3.3 🟡 One 210-line `init()` — Medium (readability)
- **Location:** `injection.dart:184-395`.
- **Solution:** Split into private feature initializers (`_initTask()`, `_initComms()`, …) called from `init()`. Same singletons, same order, just readable and merge-friendly. No behavior change.
- **Impact:** Faster onboarding for new devs; fewer merge conflicts on the DI file (currently a hotspot every feature touches).

---

## 4. State Management

### 4.1 🟠 `TaskCubit` is a god object — High
- **Location:** `lib/features/task/presentation/cubit/task_cubit.dart` — 1264 LOC, 23 public methods, 3 repositories + 7 use cases.
- **Why it matters:** It owns task CRUD, the full lifecycle (start/submit/approve/rework/reject), checklist toggling, notes, work-data patching, proof upload with progress, **and** task-template + recurring-template management. Template management (`saveTemplate`, `deleteTemplate`, `createRecurringShiftTemplate`, `setRecurringTemplateActive`, `deleteRecurringTemplate`, `getTemplates`) is a separate concern with a separate audience (managers/admins configuring blueprints, not the live work feed). Every template edit sits in the same class as the live task stream subscriptions.
- **Recommended solution:** Extract a `TaskTemplatesCubit` (task templates + recurring templates). It shares the same `TaskRepository` but has its own state and lifecycle. Leave live-task CRUD + lifecycle in `TaskCubit`. Do **not** over-split into per-action cubits — the lifecycle transitions genuinely belong together (they share `_transitionMutate` + notification fan-out).
- **Estimated impact:** ~250 LOC out of `TaskCubit`; template screens stop rebuilding when a task stream ticks; two developers can work templates vs live-tasks without colliding.

### 4.2 🟡 No shared loading/error state handling — Medium
- **Location:** 7 cubits (`admin_users`, `branch`, `broadcast_schedule`, `broadcast_template`, `schedule`, `shift_swap`, `task`) each hand-roll a `_mutate`/`_guard` wrapper (try → set loading → call → set success/error).
- **Why it matters:** The same try/catch/emit choreography is written 7 times. When you change error-surfacing policy (e.g. add telemetry on failure), you edit 7 files.
- **Recommended solution:** A small `mixin CubitOps` (or `Future<T?> guard(...)` helper) in `core/` that centralizes the try/emit-error pattern. **Keep it tiny** — one method, no inheritance hierarchy, no `BaseCubit<TState>` generic gymnastics (that would fight freezed unions). This is the measured version; if it can't be expressed in ~30 lines, don't do it.
- **Estimated impact:** One place to change failure policy; ~15 lines saved per cubit. Low risk.

### 4.3 🟡 Rebuild scoping under-uses selectors — Medium
- **Location:** codebase-wide — `BlocBuilder` ×39, `BlocSelector` ×4, `context.select` ×5, `buildWhen` ×**0**.
- **Why it matters:** Big screens (`employee_home_screen.dart` 1941 LOC, `my_schedule_screen.dart` 1722 LOC, `admin_dashboard_screen.dart` 1196 LOC) wrap large trees in a single `BlocBuilder` over a freezed union. Any field change in that state rebuilds the whole subtree. With unbounded lists (§6) each Firestore snapshot re-emits the *entire* list, triggering a full rebuild of the screen.
- **Recommended solution:** On the 3–4 heaviest screens, add `buildWhen` on the top `BlocBuilder` and use `BlocSelector`/`context.select` for leaf widgets that only need one field (e.g. a header count). Do **not** blanket-convert all 39 — most are small and correct. Target only the screens >800 LOC.
- **Estimated impact:** Measurably fewer widget rebuilds on the highest-traffic screens; smoother scroll under live updates. Pairs naturally with Phase 4 + the pagination work.

### 4.4 🟢 Stream subscription hygiene — HEALTHY, no action
Cubits holding Firestore subscriptions cancel on `close()`/re-subscribe (verified list in `ARCHITECTURE.md §1.9`; `TaskCubit._subs` + `close()` at `task_cubit.dart:1258`). The live-countdown `Timer` gotcha (tests must unmount) is already documented in memory. Good.

---

## 5. Widgets & UI reuse

### 5.1 🟢 Shared component library exists and is used — mostly HEALTHY
`core/widgets/` has 40 components (cards, empty states, skeletons, dialogs, snackbars, glass surfaces, status badges, metric pills). This is a real design system, not a stub. Good.

### 5.2 🟡 Reusable primitives trapped inside feature files — Medium
- **Location:** `task_action_sheets.dart` defines **public** `SheetHandle`, `SheetTitle`, `ShiftChipPicker`, `ShiftRepeatPicker`, `WeekdayChipPicker`, and private `_Segmented<T>`, `_MiniChip`, `_PickerTile`, `_SectionLabel`, `_FieldCaption` — all generic, none task-specific.
- **Why it matters:** A grab-bag sheet toolkit lives in one feature. The next developer building a sheet in `requests` or `schedule` either re-implements a segmented control / chip picker (new duplication) or reaches into a `task` file (bad coupling). The `['Jan','Feb',…]` month arrays (§7.1) proliferate for exactly this reason.
- **Recommended solution:** Promote the genuinely generic ones (`SheetHandle`, `SheetTitle`, `_Segmented`→`AppSegmented`, `_MiniChip`→`AppChip`, `_PickerTile`) to `core/widgets/`. Leave the domain-specific ones (`ShiftChipPicker`, `WeekdayChipPicker`) in the feature. **Move, don't redesign** — the memory rulings on premium UI mean pixels must not change.
- **Estimated impact:** Stops the next round of sheet-duplication before it starts; ~6 primitives become team-wide.

### 5.3 🟠 `task_action_sheets.dart` — 2452 LOC / 40 classes in one file — High (maintainability)
- **Why it matters:** Create/edit form, branch picker, assignee picker, assign sheet, review sheet, checklist builder, and every sub-primitive live in one file. It is the largest widget file in the app. Any change forces a merge-conflict-prone edit to a 2452-line file; new devs can't find anything.
- **Recommended solution:** Split by sheet along the class boundaries already present: `task_form_sheet.dart`, `assign_sheet.dart`, `review_sheet.dart`, `assignee_picker_sheet.dart`, `branch_picker_sheet.dart`, plus the promoted primitives (§5.2). Pure file reorg, no logic change.
- **Estimated impact:** 5 files ~400–600 LOC each; navigable, review-able, mergeable.

### 5.4 🟡 No shared bottom-sheet wrapper — Medium
- **Location:** 19 raw `showModalBottomSheet` call-sites, each re-specifying `isScrollControlled`, shape, `useSafeArea`, drag handle, background.
- **Recommended solution:** One `showAppSheet(context, builder, {title})` helper in `core/widgets/` that bakes in the house defaults (matches how `AppSnackbar` centralized snackbars). Adopt incrementally.
- **Estimated impact:** Consistent sheet chrome; one place to tune sheet behavior; deletes repeated boilerplate.

### 5.5 🟢 `AppDialog` exists but is unused — Low (verify intent)
- **Location:** `core/widgets/app_dialog.dart` exists; grep finds **0 usages**; 3 files use raw `showDialog`.
- **Action:** Either adopt `AppDialog` in those 3 sites or delete it as dead code (§11). Decide, don't leave a zombie.

---

## 6. Performance & Firestore efficiency — 🔴 the Critical section

### 6.1 🔴 Unbounded collection reads — no pagination — CRITICAL
- **Location:**
  - `task_remote_datasource.dart:100` — `_tasks.orderBy(createdAt, descending:true).get()` → **reads the entire `tasks` collection** (global admin overview).
  - `task_remote_datasource.dart:135/138/144` — `watchAllTasks`, `watchTasksByBranch`, `watchEmployeeTasks` → `.snapshots()` with `orderBy` but **no `.limit()`**.
  - Same pattern in cases, requests, broadcasts, schedules, shift_swaps, task_templates (`:369` `orderBy('title').get()`).
  - Only `notifications` (`:77` `.limit()` + `startAfter` cursor) and `profile` username-check (`:188` `.limit(1)`) are bounded. Verified: `startAfter` appears **only** in the notifications feature.
- **Why it matters (this is the 100k-user blocker):**
  - **Cost:** Firestore bills per document read. An admin opening the task overview reads *every task ever created*. At scale that is thousands of reads per screen open, per user, repeated on every snapshot re-emit.
  - **Memory:** The whole collection is deserialized into `List<TaskModel>` → `List<TaskEntity>` and held in the cubit. `task_feed.dart` then sorts/groups the full list **client-side** (`:233/:287/:294/:299`). O(n) work on the main isolate on every update.
  - **Latency & jank:** First paint waits for the full collection; every live update re-runs the full client-side sort/group and rebuilds the (un-scoped, §4.3) screen.
  - **Offline cache:** `cacheSizeBytes: UNLIMITED` means the device also accumulates the entire history locally.
- **Recommended solution:**
  1. Add `.limit(N)` (e.g. 30–50) + `startAfterDocument` cursor pagination to every list stream — replicate the pattern already proven in `notification_remote_datasource.dart`. Repository interface gains an optional `cursor`/`limit`; cubits append pages on scroll.
  2. Push sort/filter into the **query** (`orderBy` + `where`) instead of client-side where possible; keep client-side only for the genuinely composite feed grouping (and even that operates on a bounded page).
  3. For the admin global overview, favor server-side aggregation (the statistics feature already uses `count()` aggregation — good precedent) for counts, and paginate the actual rows.
  4. Reconsider `CACHE_SIZE_UNLIMITED` → a bounded cache once lists are paginated.
- **Estimated impact:** **Order-of-magnitude fewer Firestore reads and lower bill; bounded memory; faster first paint; no main-thread sort of unbounded lists.** This is the highest-ROI change in the entire audit and the one true prerequisite for 100k users.
- **Risk:** Medium — touches datasource + repo interface + cubit + list widgets per feature. Do it feature-by-feature (tasks first). Guard against regressions with the existing task tests.

### 6.2 🟡 Client-side sort/group of full lists — Medium (subsumed by 6.1)
- **Location:** `task_feed.dart` sorts/groups; `task_ordering.dart:10 sortTasksNewestFirst`. These are **pure functions** (good, testable) but run on unbounded input.
- **Solution:** Once §6.1 bounds the input, these become cheap. Keep the pure functions — do not move logic into widgets.

### 6.3 🟢 `const` discipline & hardcoded colors — HEALTHY
Only 22 `Color(0x…)` literals in all of `features/` (monochrome tokens are centralized in `core/theme/`). `const` is used liberally. No action.

### 6.4 🟢 Whole-doc task writes (`set(merge:true)`) — acceptable, documented
Last-write-wins at field granularity; the one truly concurrent path (swap finalization) is a server transaction. This is a deliberate, documented trade-off (`ARCHITECTURE.md §9`). No change — but note that under heavy multi-editor load the activity-log array-in-doc pattern could grow large; see §8.2.

---

## 7. Utilities & duplication

### 7.1 🟡 Date/time formatting re-implemented ~15× — Medium
- **Location:** `['Jan','Feb',…]` month arrays + bespoke `_fmt`/`_relative`/`timeAgo` helpers in **~15 files**: `task_card.dart:274`, `task_feed_row.dart:244`, `task_feed_expansion.dart:191`, `activity_format.dart:63`, `attachment_format.dart:55`, `task_details_screen.dart:1412`, `task_action_sheets.dart:2015`, `admin_dashboard_screen.dart:843`, `case_message_list.dart:323`, `request_format.dart:41`, `profile_page.dart:147`, `user_inspector_panel.dart:266`, `day_details_sheet.dart:520`, `shift_details_sheet.dart:398`, `employee_home_screen.dart:276`, plus more.
- **Why it matters:** Same logic, 15 copies, inconsistent output (some show "5 Jul", some "Jul 5", some relative). A formatting-policy change is a 15-file edit. This is the clearest, safest consolidation win in the codebase.
- **Recommended solution:** One `DateFormatX` extension on `DateTime` (or `core/utils/date_format.dart`) with `shortDate`, `timeOfDay`, `relative`, `dayLabel`. `intl`'s `DateFormat` is already a dependency (used in exactly 1 file today) — you can standardize on it or keep the lightweight manual formatter, but **in one place**.
- **Estimated impact:** ~15 files simplified; consistent dates app-wide; one-line policy changes. Very low risk (pure functions, cover with a unit test).

### 7.2 🟢 Validators / permission checks — HEALTHY
`core/utils/validators.dart` centralizes validation; `context_extensions.dart` centralizes `isAdmin/isManager/isEmployee` and role reads. Permission checking is not duplicated. No action.

### 7.3 🟢 Snackbars / navigation — HEALTHY
`AppSnackbar` + `context.showSuccess/showError` (only 2 raw stragglers in `my_schedule_screen.dart` + `manager_schedule_view.dart` — sweep them). `go_router` with centralized `RouteNames`. Good.

---

## 8. Data & Domain layer

### 8.1 🟡 `users/{uid}` mapped by two models — Medium
- **Location:** `UserModel` (auth/role fields) **and** `ProfileModel` (profile fields) both (de)serialize the *same* `users/{uid}` document (`ARCHITECTURE.md §2.2` documents this as intentional; `displayName`/`fullName`, `photoUrl`/`profileImage` are kept mirror-synced).
- **Why it matters:** Two mappers over one document is a split-brain risk — a field added to the user doc can be read by one mapper and silently dropped by the other; the mirror-sync (`displayName ↔ fullName`) is manual and easy to break. For a growing team this is a subtle data-integrity trap.
- **Recommended solution:** Keep the two *entities* (they serve different screens) but consider a single source-of-truth mapper for the shared fields, or document the field ownership explicitly at the top of both model files. **Low-priority** — it works today; the risk is future drift. Do not merge `UserEntity` and `ProfileEntity` (they legitimately differ by audience).
- **Estimated impact:** Prevents a class of "why did my new field disappear" bugs as the team grows.

### 8.2 🟡 Unbounded embedded arrays (`activityLog`, `checklist`, `attachments`) — Medium (latent)
- **Location:** `TaskModel` embeds `activityLog[]`, `checklist[]`, `referenceAttachments[]` in the task doc (`ARCHITECTURE.md §2.4`).
- **Why it matters:** Firestore docs cap at 1 MB. A long-lived, heavily-reworked task with many activity entries + attachments approaches that ceiling, and every whole-doc `set(merge:true)` write re-transmits the growing array. Fine at current scale; a latent cliff at 100k-user volume/longevity.
- **Recommended solution:** No action now — **flag and monitor**. If activity volume grows, migrate `activityLog` to a `tasks/{id}/activity` subcollection (the codebase already does exactly this for `cases/{id}/messages` and `requests/{id}/events` — a proven pattern to copy). Do not pre-migrate; the soft-archive housekeeping caps task lifetime today.
- **Estimated impact:** Avoids a future write-amplification + doc-size cliff. Measured: only act when activity-log length trends up.

### 8.3 🟢 Missing use cases — mostly fine
Writes go through use cases; reads via repository streams (documented hybrid). This is consistent. The only inconsistency: some cubits call `repository.getTemplates()` directly (`task_cubit.dart:978`) rather than a use case — acceptable for reads under the hybrid convention. No action.

### 8.4 🟢 Work-Type polymorphism (Strategy + Registry) — EXEMPLARY, no action
The `WorkTypeDefinition`/`BaseWorkType`/`WorkTypeRegistry` design (add a type = 1 file + 1 line, OCP-compliant) is the best-engineered part of the domain. This is the pattern other features should aspire to. Keep it exactly as is.

---

## 9. Backend readiness (Firebase not permanent)

### 9.1 🟢 The hard part is already done — HEALTHY
Because repository **interfaces** live in `domain/` and Firebase is quarantined in `data/`, swapping to Supabase/Appwrite/PocketBase/NestJS/Go means **reimplementing `data/`, not touching `domain/` or `presentation/`.** This is the correct, and frankly rare, foundation. Explicitly: **no change needed to enable a backend swap at the repository level.**

### 9.2 🟠 Firebase-specific seams that a swap must confront — High (document now, don't abstract yet)
Three couplings are not behind ports and would leak into any migration:
1. **Cloud Function callables by string name** — `sendBroadcast`, `approveSwap`, `sendNotification`, `createUserAccount`, `adminResetPassword`, plus referenced-but-absent `onRequest*` (see §9.3). These are RPCs invoked from datasources. A new backend needs equivalent endpoints. **They are already behind repository methods** (`BroadcastRepository.send`, etc.) — so the *interface* is portable; only the *impl* is Firebase. Good enough. **Action: none beyond documenting the RPC contract.**
2. **`Timestamp ⇄ DateTime`** — correctly confined to models. A new backend swaps the conversion in one layer. Good.
3. **No `LocalDataSource` / `CacheManager` seam** — the *only* cache is Firestore's built-in offline persistence (+ one in-memory TTL for task templates). Migrating off Firebase **loses offline entirely** unless a local cache is introduced. This is the real backend-readiness gap.
- **Recommended solution:** When (if) a migration becomes real, introduce `LocalDataSource` behind the existing repositories and a `RemoteDataSource` interface split (`ApiClient` for a REST/GraphQL backend). **Do not build this now** — it is speculative until a backend decision exists, and building it speculatively is the over-engineering the philosophy forbids. Document it as the migration's first task.
- **Estimated impact:** Clear-eyed migration scope; no wasted abstraction today.

### 9.3 🟠 Referenced-but-missing `onRequest*` Cloud Functions — High (correctness/ops)
- **Location:** `injection.dart:296` + `request_remote_datasource.dart` comments reference server-side `onRequest*` functions for request notifications + `refCode`/`seq` sequencing. **No `onRequest*` function exists in `functions/index.js`.** Yet `firestore.rules:614` has a `counters/{id}` block explicitly noted as backing `REQ-000123` sequencing.
- **Why it matters:** Either (a) request notifications + human-readable ref codes are silently not firing in production, or (b) the functions are deployed from an un-versioned source. Both are ops risks: the first is a missing feature, the second is un-reviewable, un-reproducible infrastructure.
- **Recommended solution:** Confirm deployment state (`firebase functions:list`). If missing, implement `onRequestCreated`/`onRequestUpdated` mirroring the `onCase*` functions. If deployed-from-elsewhere, get the source into `functions/`. Do not leave Schrödinger's function.
- **Estimated impact:** Restores/confirms request notifications + ref-code integrity; eliminates un-versioned infra.

### 9.4 🟠 Cloud Functions deploys pending (from memory/state) — High (ops)
Project memory records **undeployed** rules/indexes/functions for **cases** (`onCase*`, `onNotificationCreated`) and the requests soft-delete/reopen `reopened` event. Verify against `firebase deploy` state. A feature that's coded but whose triggers aren't deployed is a silent production gap.

---

## 10. Testing

### 10.1 🟠 Zero coverage on critical features — High
- **Location:** test files per feature — `task` 17, `schedule` 11, `branch` 2, `admin`/`employee`/`operations` 1 each, and **0** for: `auth`, `cases`, `communications`, `notifications`, `profile`, `requests`, `settings`, `statistics`.
- **Why it matters:** `auth` is the security-critical entry path (session restore, first-login funnel, role guards) with **no tests**. `requests` and `cases` carry sensitive operational data and complex state machines with **no tests**. For a multi-developer team, untested features are where regressions land silently.
- **Recommended solution:** Prioritize by risk, not by coverage %: (1) `auth` cubit + router redirect gate, (2) `requests` + `cases` state machines and mappers, (3) mapper round-trip tests (`toMap→fromMap` identity) for every model — these are cheap, pure, and catch schema drift. Aim for the *paths*, not a number.
- **Estimated impact:** Regression safety net exactly where the team will move fastest; mapper tests catch the §8.1 split-brain class of bug.

### 10.2 🟡 Flat `test/` directory — Medium
- **Location:** all 97 test files sit directly in `test/` with no `lib/` mirroring.
- **Why it matters:** At 97 files (and growing) a flat directory makes it hard to find a feature's tests or see coverage gaps at a glance (indeed, spotting the §10.1 gaps required a script).
- **Recommended solution:** Mirror `lib/features/<feature>/` under `test/features/<feature>/`. Pure move.
- **Estimated impact:** Navigable tests; coverage gaps become visible in the tree.

### 10.3 🟢 Testability of logic — HEALTHY
Pure domain functions (`task_feed`, `task_ordering`, `active_window`, work-type definitions, `schedule_week`) are already extracted and unit-testable — and heavily tested. This is the right shape. The barrier to more tests is coverage effort, not architecture.

---

## 11. Code quality & dead code

### 11.1 🟢 Cleanliness — HEALTHY
0 `TODO`/`FIXME`/`HACK`. Consistent naming, consistent file layout per feature. Good.

### 11.2 🟡 Legacy social fields on `UserModel` — Low
- **Location:** `followersCount`, `followingCount`, `postsCount`, `likesCount`, `isOnline`, `isProfilePublic`, `allowMessages`, etc. (`ARCHITECTURE.md §2.2`) — read "defensively"; the product is not a social network.
- **Solution:** Delete on the next `UserModel` touch (they're never written meaningfully). Low priority; harmless but noise. Aligns with the "default to deletion" philosophy.

### 11.3 🟡 Declared-but-unused collections — Low
- **Location:** `savedAudiencesCollection` declared in `app_constants.dart`, no reads, no rules. `counters` is used (ref codes) — keep. `savedAudiences` looks dead.
- **Solution:** Remove `savedAudiences` constant if truly unused, or implement it. Confirm before deleting.

### 11.4 🟡 Large screen files — Medium
- **Location:** `employee_home_screen.dart` 1941, `my_schedule_screen.dart` 1722, `admin_dashboard_screen.dart` 1196, `compose_broadcast_screen.dart` 1159, `manager_schedule_view.dart` 1131.
- **Why it matters:** Multi-hundred-line `build()` methods are hard to review and rebuild inefficiently (§4.3).
- **Solution:** Extract sub-sections into `const`-able child widgets (which also fixes rebuild scoping). Do this **only** on files >1000 LOC, and preserve the premium UI exactly (memory rulings). Not urgent; pairs with Phase 2/4.

---

## 12. Security

### 12.1 🟢 Rules & isolation — HEALTHY (stronger than the doc claims)
Verified: `requests` (`firestore.rules:562`), request events (`:580`), `counters` (`:614`), request storage (`storage.rules:52`) all have rule blocks. Branch isolation, privilege freeze, function-owned privileged writes, privacy-split case identity — all present and correct. **The `ARCHITECTURE.md §6.2` "no rule block" claim is stale (§2.3), not a real hole.**

### 12.2 🟡 Storage authorization leans on Firestore-write gating — Medium (by design, document it)
- **Location:** `storage.rules` — task/case/request/branch media are `create: signed-in` (any authed user), with the *real* gate being the role-checked Firestore write of the URL onto the doc, plus unguessable 20-char auto-ids.
- **Why it matters:** This is a deliberate, documented pattern (Storage rules can't cheaply read Firestore role), but a new engineer could mistake it for an authz hole, or a future change could break the coupling. It also means a signed-in user *could* write orphan blobs to `tasks/{knownId}/…` if they learn an id.
- **Recommended solution:** No change to the mechanism (it's the pragmatic Firebase idiom), but keep it clearly documented and consider Storage-side path/size/content-type constraints to limit orphan-blob abuse. Low priority.

### 12.3 🟢 No secrets / no custom claims drift — HEALTHY
Authorization reads role/branch from `users/{uid}` (single cached `get()` per request). No hardcoded secrets found in `lib/`.

---

## 13. Consolidated findings table (by severity)

| # | Severity | Area | Finding | Location |
|---|---|---|---|---|
| 1 | 🔴 Critical | Performance | Unbounded Firestore reads; no pagination (except notifications) | `task_remote_datasource.dart:100/135/144`, cases/requests/broadcasts datasources |
| 2 | 🟠 High | Testing | 0 test files on `auth`, `requests`, `cases`, `communications`, `notifications`, `profile`, `statistics` | `test/` |
| 3 | 🟠 High | State | `TaskCubit` god object (1264 LOC, template mgmt mixed in) | `task_cubit.dart` |
| 4 | 🟠 High | Widgets | `task_action_sheets.dart` 2452 LOC / 40 classes in one file | `task_action_sheets.dart` |
| 5 | 🟠 High | Backend/Ops | Referenced-but-missing `onRequest*` functions; pending case/request deploys | `functions/index.js`, `injection.dart:296` |
| 6 | 🟠 High | Backend | No `LocalDataSource`/cache seam → migration loses offline (document, don't build yet) | `data/datasources/*` |
| 7 | 🟡 Medium | Utilities | Date/time formatting duplicated ~15× | ~15 files (§7.1) |
| 8 | 🟡 Medium | State | 39 `BlocBuilder` / 0 `buildWhen` — wholesale rebuilds on big screens | heavy screens |
| 9 | 🟡 Medium | Widgets | Reusable primitives trapped as private in feature files | `task_action_sheets.dart` |
| 10 | 🟡 Medium | Widgets | No shared bottom-sheet wrapper (19 raw call-sites) | app-wide |
| 11 | 🟡 Medium | State | Duplicated `_mutate`/`_guard` across 7 cubits | 7 cubits |
| 12 | 🟡 Medium | DI | Eager singletons; 210-line `init()` | `injection.dart` |
| 13 | 🟡 Medium | Data | `users/{uid}` mapped by two models (split-brain risk) | `user_model.dart` + `profile_model.dart` |
| 14 | 🟡 Medium | Data | Unbounded embedded arrays (latent 1MB-doc cliff) | `TaskModel.activityLog` |
| 15 | 🟡 Medium | Testing | Flat `test/` directory (no `lib/` mirroring) | `test/` |
| 16 | 🟡 Medium | Docs | `ARCHITECTURE.md §6.2` stale (understates rules) | `ARCHITECTURE.md` |
| 17 | 🟡 Medium | Quality | Screens >1000 LOC with large `build()` | 5 screens (§11.4) |
| 18 | 🟢 Low | Quality | Legacy social fields on `UserModel` | `user_model.dart` |
| 19 | 🟢 Low | Quality | `savedAudiences` declared, unused | `app_constants.dart` |
| 20 | 🟢 Low | Widgets | `AppDialog` unused (adopt or delete) | `app_dialog.dart` |

---

## 14. Implementation roadmap

Ordered by ROI and risk. **Phase 1 alone unblocks the 100k-user goal;** everything after is quality/velocity. Each phase is independently shippable.

### Phase 1 — Scaling: pagination & bounded reads  🔴 do first
- **Goals:** Eliminate unbounded collection reads. Add `.limit()` + cursor pagination to every list stream, starting with `tasks`. Push sort/filter into queries; keep pure client-side grouping only on bounded pages. Reconsider `CACHE_SIZE_UNLIMITED`.
- **Files:** `task_remote_datasource.dart`, `task_repository.dart`(interface) + impl, `task_cubit.dart`, task list widgets; then repeat for `cases`, `requests`, `communications`, `schedule`. Reuse the proven `notification_remote_datasource.dart` pattern.
- **Risk:** Medium (touches datasource→repo→cubit→UI per feature; do tasks first, lean on the 17 existing task tests).
- **Effort:** Large (≈1–2 weeks across features; tasks alone ≈2–3 days).
- **Benefits:** Order-of-magnitude fewer reads + lower Firestore bill; bounded memory; faster first paint; no main-thread sort of unbounded lists. **The prerequisite for scale.**

### Phase 2 — Shared widgets & file decomposition  🟡
- **Goals:** Split `task_action_sheets.dart` into per-sheet files; promote generic primitives (`SheetHandle`, `AppSegmented`, `AppChip`, `AppPickerTile`) to `core/widgets/`; add `showAppSheet()` wrapper; adopt or delete `AppDialog`.
- **Files:** `task_action_sheets.dart` → 5 files; `core/widgets/` (+4 promoted); 19 bottom-sheet call-sites (incremental).
- **Risk:** Low (pure reorg; **pixels must not change** per UI rulings — verify with screenshots).
- **Effort:** Medium (2–3 days).
- **Benefits:** Navigable, merge-friendly UI code; stops the next round of sheet/primitive duplication; team-wide sheet chrome.

### Phase 3 — Utilities consolidation  🟡
- **Goals:** One `DateFormatX` / `date_format.dart`; migrate ~15 inline formatters + month arrays to it; sweep the 2 raw `ScaffoldMessenger` stragglers into `AppSnackbar`.
- **Files:** new `core/utils/date_format.dart` + ~15 call-sites; `my_schedule_screen.dart`, `manager_schedule_view.dart`.
- **Risk:** Low (pure functions; cover with one unit test).
- **Effort:** Small (½–1 day).
- **Benefits:** Consistent dates app-wide; one-line formatting-policy changes; deletes 15 copies.

### Phase 4 — Rebuild & render performance  🟡
- **Goals:** Add `buildWhen` + `BlocSelector`/`context.select` on the 4–5 screens >1000 LOC; extract their large `build()` sections into `const` child widgets.
- **Files:** `employee_home_screen.dart`, `my_schedule_screen.dart`, `admin_dashboard_screen.dart`, `compose_broadcast_screen.dart`, `manager_schedule_view.dart`.
- **Risk:** Low–Medium (preserve premium UI exactly; verify visually).
- **Effort:** Medium (2–3 days).
- **Benefits:** Fewer rebuilds under live updates; smoother scroll; smaller, reviewable widgets. Compounds with Phase 1.

### Phase 5 — State-management hygiene  🟡
- **Goals:** Extract `TaskTemplatesCubit` from `TaskCubit`; add a tiny (~30-line) `CubitOps` guard mixin and adopt in the 7 cubits with hand-rolled `_mutate`.
- **Files:** `task_cubit.dart` (+ new `task_templates_cubit.dart`), `injection.dart`, 7 cubits, `core/`.
- **Risk:** Medium (`TaskCubit` split touches DI + template screens; keep behavior identical, lean on task tests).
- **Effort:** Medium (2–3 days).
- **Benefits:** Smaller cubits; one place for failure policy; parallel-work-friendly.

### Phase 6 — Backend-readiness documentation + ops fixes  🟠 (partly urgent)
- **Goals:** (a) Resolve the `onRequest*` mystery — verify deployment, implement mirroring `onCase*` if missing, version the source. (b) Confirm/complete pending case+request deploys (rules/indexes/functions). (c) Write a one-page "backend migration playbook" documenting the RPC contract + the `LocalDataSource`/`ApiClient` seam to introduce **when/if** a swap happens. (d) Fix stale `ARCHITECTURE.md §6.2`.
- **Files:** `functions/index.js`, `firestore.rules`/indexes (verify), `ARCHITECTURE.md`, new `BACKEND_MIGRATION.md`.
- **Risk:** Low–Medium (functions deploy is real infra — test in a staging project).
- **Effort:** Medium (2–3 days incl. the ops verification).
- **Benefits:** Removes un-versioned/undeployed infra risk; a real, cheap migration plan without speculative abstraction today.

### Phase 7 — Testing depth  🟠
- **Goals:** Cover the untested critical paths — `auth` (cubit + router redirect gate) first, then `requests`/`cases` state machines, then `toMap→fromMap` round-trip tests for every model. Mirror `test/` to `lib/features/`.
- **Files:** new `test/features/{auth,requests,cases,notifications,profile,statistics}/…`; reorg existing 97.
- **Risk:** Low (tests only).
- **Effort:** Large (ongoing; front-load auth + mapper round-trips — highest value, lowest effort).
- **Benefits:** Regression safety exactly where the team moves fastest; mapper tests catch schema/split-brain drift (§8.1) cheaply.

---

## 15. What NOT to do (guardrails against over-engineering)

Per the project's "no over-engineering / default to deletion / simple > clever" philosophy, explicitly **do not**:

- ❌ Migrate to `get_it` or an IoC framework — the static locator is fine.
- ❌ Introduce a `BaseCubit<TState>` generic hierarchy — it fights freezed unions; a 30-line mixin is the ceiling.
- ❌ Add a third "DTO vs domain-model" layer — the model⇄entity split already is that layer.
- ❌ Build `LocalDataSource`/`ApiClient`/`CacheManager` speculatively — only when a concrete backend decision exists.
- ❌ Merge `UserEntity`/`ProfileEntity` or redesign the premium sheets — audience-specific and UI-frozen respectively.
- ❌ Blanket-convert all 39 `BlocBuilder`s — only the heavy screens benefit.
- ❌ Pre-migrate `activityLog` to a subcollection — monitor first; act on evidence.

**Bottom line:** the architecture is sound and, in places (work-type polymorphism, layer isolation, security), exemplary. The work ahead is *hardening for scale* (Phase 1) and *consolidating for team velocity* (Phases 2–7), not restructuring. Ship Phase 1 first — it is the only item that stands between this codebase and 100k users.
