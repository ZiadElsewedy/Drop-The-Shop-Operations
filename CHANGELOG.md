# Changelog

All notable changes to **FBRO** are recorded here. After every completed
feature, append a short summary of what was **added / removed / fixed /
refactored**. See [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) for architecture.

The project adheres loosely to [Keep a Changelog](https://keepachangelog.com)
and [Semantic Versioning](https://semver.org).

---

## [Unreleased]

### Added
- `PROJECT_CONTEXT.md` — architecture, dependency maps, modification map, and
  conventions as the single source of truth for the codebase.
- `CURRENT_STATE.md` — live project status: module status, working tree, routes,
  Firebase/Firestore/Storage status & schema, known gaps, and next steps.
- `CHANGELOG.md` — this file.
- Documentation protocol: PROJECT_CONTEXT.md, CURRENT_STATE.md, and CHANGELOG.md
  are treated as production source and must be verified/synchronized before any
  task completes (verification rules + self-check in PROJECT_CONTEXT §5). Docs
  are updated automatically — never ask whether to update.
- `.claude/settings.json` — committed `SessionStart` hook that injects the
  documentation protocol into every new session (read all three docs first,
  verify against the codebase, auto-update docs + any stale project memory
  before finishing).

---

## 2026-06-17 — StatusBadge, AppCard & context helpers

Second component-system increment. **No behaviour change.**

### Added
- **`StatusBadge`** ([status_badge.dart](lib/core/widgets/status_badge.dart)) — one
  tinted status pill for every Pending / Approved / Rejected / Completed / Active …
  indicator, with typed factories (`StatusBadge.task`, `.approval`, `.swap`,
  `.active`) that hold the colour+label mapping in a single place. **`task_card`'s
  private `_StatusBadge` + `_statusColor` + `_statusLabel` were removed** and
  replaced with `StatusBadge.task(...)` — identical render, real de-dup.
- **`AppCard` hover** ([app_card.dart](lib/core/widgets/app_card.dart)) — the
  reusable surface card now brightens its border on hover (`MouseRegion`, no-op on
  touch) in addition to the press-scale. Ready for the task/employee/branch cards
  to adopt.
- **Context helpers** ([context_extensions.dart](lib/core/extensions/context_extensions.dart))
  — `context.isAdmin` / `isManager` / `isEmployee` (literal role), and
  `context.showSuccess(...)` / `showError(...)` (thin pass-throughs to `AppSnackbar`).

### Verified
- `flutter analyze` clean (2 pre-existing infos); **10 tests pass**.

### Deferred (needs an on-device visual pass — flagged by the user as lower
priority than the Task Flow audit)
- Adopting `AppCard` across the 4 bespoke cards (they currently use a gradient +
  radius 20; `AppCard` is flat + radius 24) and converging the admin info-chips
  onto `StatusBadge`.

---

## 2026-06-17 — Shared form & layout component system

Consolidated the form/layout primitives into reusable, design-system-consistent
widgets so screens stop re-implementing fields by hand. **No behaviour change**
(text/keyboard actions preserved exactly); the only visual deltas are the
explicitly-requested token bumps (input radius → 20).

### Added (reusable widgets)
- **`AppPasswordField`** ([app_password_field.dart](lib/features/auth/presentation/widgets/app_password_field.dart))
  — built on `AppTextField` (built-in show/hide, lock prefix, unified focus/error
  style). Replaced the hand-wired `obscureText` fields on **login, register, and
  all 3 change-password** inputs (5 sites).
- **`AppDropdownField<T>`** ([app_dropdown_field.dart](lib/features/auth/presentation/widgets/app_dropdown_field.dart))
  — a styled dropdown matching `AppTextField` (surface · radius 20 · border · icon)
  with a `placeholder` for loading/empty states. The admin task **branch picker**
  (`_BranchDropdown`) now uses it (its bespoke container + `_placeholder` helper
  removed).
- **`AppEmptyState`** ([app_empty_state.dart](lib/core/widgets/app_empty_state.dart))
  — generic scroll-aware empty placeholder (icon · optional title · message ·
  optional action). `TaskEmptyState` now **delegates** to it (same render, same API).
- **`AppCard`** ([app_card.dart](lib/core/widgets/app_card.dart)) — reusable surface
  shell (dark surface · radius 24 · border · press-scale on tap). Provided as the
  shell for task/employee/branch cards to adopt.

### Changed
- **`AppTextField`** gained `readOnly`, `onTap`, and an `IconData suffixIcon`
  convenience (enables read-only / picker-style fields), and its corner radius now
  uses the `AppRadius.xl` (20) token instead of a hardcoded 16 — per the requested
  input spec. Fully backward-compatible (new params are optional).

### Notes / deferred (need an on-device visual pass)
- The existing **task / employee / manager / branch cards** keep their bespoke
  gradients + radius (20) for now; adopting `AppCard` (radius 24) is a visual change
  best verified on device, so it's left as a follow-up rather than migrated blind.
- The **settings delete-account** dialog keeps its raw Material `TextField`
  (outlined style inside a tight dialog) — not migrated to `AppPasswordField` to
  avoid a layout change that can't be verified here.

### Verified
- `flutter analyze` clean (2 pre-existing infos); **10 tests pass**. Existing
  `AppTextField`/`AppButton`/`AppSearchField`/`Skeleton` already covered the rest
  of the requested components and were reused as-is.

---

## 2026-06-17 — Architecture: de-duplication & shared utilities

A maintainability pass — **no new features, no UI redesign, no behaviour
change, no Firebase/routing changes**. Extracted the highest-reuse duplicated
patterns into shared utilities; every render and result is identical to before.

### Added (shared utilities)
- **`context_extensions.dart`** — `context.currentUser` / `context.currentRole`
  ([core/extensions/context_extensions.dart](lib/core/extensions/context_extensions.dart)).
  Collapses the `context.read<AuthCubit>().state.maybeWhen(authenticated: …,
  orElse: () => null)` boilerplate that was copy-pasted across **13 call sites in
  11 screens** into a single getter (same `read` semantics — no rebuild change).
- **`showConfirmDialog(...)`** ([core/widgets/app_dialog.dart](lib/core/widgets/app_dialog.dart))
  — one canonical confirmation/delete dialog, replacing **3 near-identical
  `AlertDialog` blocks** (sign-out · delete branch · delete task). Returns
  `Future<bool>` (dismiss = false); destructive actions get the red confirm.
- **`firestore_extensions.dart`** — `map.date('field')`
  ([core/extensions/firestore_extensions.dart](lib/core/extensions/firestore_extensions.dart)).
  Centralises the `(map['x'] as Timestamp?)?.toDate()` mapping repeated **21×**
  across 7 models, and removes the duplicated per-file `ts()` helper in
  `ProfileModel`.

### Removed (dead code / cleanup)
- **`role_placeholder.dart`** (`RolePlaceholder`, 78 lines) — never referenced
  anywhere in the app.
- **14 unused imports** — 8 `auth_cubit` imports (now reached via the context
  extension), 3 `cloud_firestore` imports (models that no longer touch
  `Timestamp` directly), plus the verbose inline blocks the helpers replaced.

### Verified
- `flutter analyze` clean (2 pre-existing infos); **10 tests pass**. Behaviour is
  byte-for-byte preserved: the extensions reproduce the exact `read`/`Timestamp`
  semantics, and `showConfirmDialog` renders the established delete-dialog chrome.

### Deferred (documented, not done — would risk a blind UI/behaviour change)
- **App-bar consolidation** (~14 screens share `AppBar(darkBg, elevation:0, h3)`)
  — too much per-screen variation (TabBar bottoms, custom leadings, transparent
  auth bars) to migrate safely without an on-device visual pass.
- **Bottom-sheet chrome** — `showSheet`/`SheetHandle` could move to `core`, but
  other sheets use slightly different radius/shade; unifying changes pixels.
- **Form validators** — messages and trim rules vary per field, so extraction
  would be a partial dedup with behaviour-change risk.

---

## 2026-06-17 — Stability & UX Audit

A focused reliability/usability pass — **no new features, no architecture
change**. Goal: make the app feel reliable, simple, and hard to crash. Audited
crashes, broken flows, role separation, navigation friction, and UI consistency.

### Fixed — crashes
- **A malformed/partial `users/{uid}` document could crash every user-list
  load.** `UserModel.fromMap` cast `uid`/`email` to **non-null** `String`
  ([user_model.dart](lib/features/auth/data/models/user_model.dart)), so a single
  doc missing `email` (e.g. a phone-auth account) or seeded out-of-band threw a
  `TypeError` that took down the whole load — the schedule "team", the task
  **assignee picker**, and the admin user lists. Root cause: these two fields
  used hard casts while **every other model** already uses `as String? ?? ''`.
  Now they degrade to empty strings (the UI's initials/avatar fallback handles
  it). Same hardening applied to `ProfileModel.fromMap` (`uid`).
  Locked in with [user_model_test.dart](test/user_model_test.dart) (3 cases:
  no-email doc, empty doc, well-formed doc).

### Changed — navigation & friction
- **Sign out was a single, unconfirmed app-bar tap.** The role chrome
  ([role_scaffold.dart](lib/core/widgets/role_scaffold.dart)) exposed **five**
  app-bar icons (Tasks · Schedule · Profile · Settings · **Sign out**); a stray
  tap signed the user out instantly, losing in-progress work. Consolidated the
  three occasional actions (Profile / Settings / Sign out) into a single overflow
  (`PopupMenuButton`) menu — decluttering the app bar to **Tasks · Schedule · ⋮**
  — and **Sign out now requires a confirmation dialog**. No routes changed.

### Changed — UI consistency
- **Standardized all ad-hoc snackbars on `AppSnackbar`.** Six raw
  `ScaffoldMessenger…showSnackBar` blocks across the auth/settings screens
  (login, register, phone OTP, email verification, forgot password, change
  password) were replaced with `AppSnackbar.success/error`, giving every screen
  the same icon + radius and the **hide-then-show** behaviour that prevents
  snackbars from stacking on rapid retries.

### Verified (audit — no change required)
- **No crashes** from force-unwraps in UI paths: avatar/initials helpers filter
  empty parts; upload-progress division is guarded (`totalBytes > 0`); checklist
  progress is guarded against an empty list; image-picker results are
  null-checked. Firestore models other than the two above already use null-safe
  casts with defaults.
- **No broken/dead buttons or reachable placeholder screens.**
- **Role separation is correct** — the router enforces admin-only `/admin/*`,
  manager+admin `/manager/*`, employee-only `/`, and self-scoped `/my-*`
  (admin ⊇ manager); manual URL access is bounced to the role home.
- **Loading / empty / error states are already covered** on every list screen
  (skeletons, `TaskEmptyState`, `AppSnackbar` errors, pull-to-refresh).
- `flutter analyze` clean (2 pre-existing infos); **10 tests pass** (7 existing +
  3 new crash-regression tests).

---

## 2026-06-16 — Phase 10: Production Hardening & QA

A verification, stabilization and UI-modernization pass for a production beta —
**no new business modules, no architecture change**. Reuses the existing
navigation, Clean Architecture, repositories and theme.

### Removed (cleanup — verified dead code)
- **The entire Phase 2 `shift` feature.** It was never consumed (no `ShiftCubit`/
  use cases; screens unreachable from the role chrome; `AppDependencies.
  shiftRepository` registered but unused; `RouteNames.shiftsForRole` never
  called). Deleted: `lib/features/shift/`, the `/admin|manager/shifts` + `/my-shift`
  routes (+ imports) in `app_router.dart`, the shift route constants +
  `shiftsForRole` in `route_names.dart`, the shift wiring in `injection.dart`,
  `AppConstants.shiftsCollection`, and the `shifts/{shiftId}` block in
  `firestore.rules`. The weekly **schedule** (Phase 7) is the production roster;
  `users/{uid}.assignedShift` and `tasks.assignedShiftId` remain as harmless
  nullable strings. Verified with `flutter analyze` (clean).

### Changed (UI modernization — same navigation/architecture)
- **Manager dashboard** restructured into a command-center: a "Needs attention"
  hero row (**Waiting reviews** + **Active tasks**, tappable to the task screen,
  accent when non-zero), then grouped **Team & shifts today** and **Tasks**
  sections with `SectionHeader`s.
- **Employee dashboard** leads with a premium glass **Today's shift** card
  (shift icon + next-shift line) then a focused **Your tasks** grid — reduced
  clutter.
- **Loading states**: the task / admin-user / branch list screens now show a
  shimmering `ListSkeleton` on first load instead of a bare spinner.
- New shared widgets: `dashboard_section.dart` (`SectionHeader`, `HeroStatCard`)
  and `list_skeleton.dart` (both reuse the existing theme + `Skeleton`).

### Verified (by code audit + tooling — see honest limitations)
- **Auth / approval / roles**: register → pending (real-time `watchUser`) →
  admin approve (role + branch) → role dispatch; router redirect gates approval
  before role, and `_isAdminArea`/`_isManagerArea` guards (incl. the new
  `/admin/analytics`) bounce cross-role access.
- **Tasks**: create / from-template (checklist generated) / edit / delete /
  assign one·many·whole-team / checklist completion gate / proof upload / review;
  lists are live streams; rules are query-compatible (`assigneeIds arrayContains`).
- **Schedule + swaps**, **analytics math** (admin/manager/employee), **offline**
  (Firestore persistence + reload-after-mutation), and **profile upload**
  (60 s/20 s timeouts + progress + error recovery → never freezes).
- `flutter analyze` clean (2 pre-existing infos only); 7 unit tests pass;
  `build_runner` regenerates with 0 stale outputs.

### Notes / honest limitations
- Flutter UI can't be rendered/clicked in this environment, so UI work was kept
  to safe, deterministic, theme-consistent changes verified by `flutter analyze`
  and logic tests — not an on-device visual pass. `firestore.rules` /
  `storage.rules` were edited but **not deployed** here. No commit was made this
  phase (per the phase's git rules).

---

## 2026-06-16 — Phase 9: Task UX, Admin UX & Design Overhaul

A premium-operations redesign pass: checklist task templates, multi-assignee
tasks, redesigned task/admin/branch cards, reliable avatars, an admin dashboard
restructure, and tasteful motion. **Reuses the existing Clean Architecture** —
no new layers, no duplicate features; the task data layer keeps backward
compatibility (legacy `assignedEmployeeId` mirror) so the Firestore schema isn't
broken.

### Added
- **Checklist templates** (was title + description). New `ChecklistItem` (task
  level: `id/title/isRequired/completed/completedAt`) and `ChecklistItemTemplate`
  (template level: `id/title/isRequired`) freezed entities
  ([checklist_item.dart](lib/features/task/domain/entities/checklist_item.dart)).
  `TaskTemplateEntity.checklistItems` + `TaskEntity.checklist`; creating a task
  from a template **generates its checklist** (`buildTaskChecklist`). The
  template form gained a **checklist editor** (add/remove steps, mark each
  required/optional).
- **Checklist completion rule** — a task cannot be marked completed until every
  **required** checklist item is done (`TaskEntity.requiredChecklistComplete`,
  enforced in `TaskCubit.completeTask`). Employees tick items off on the card
  while a task is in progress (`TaskCubit.toggleChecklistItem`); the manager
  review sheet shows progress ("4 / 5 completed" / "100% complete").
- **Multi-assignee tasks** — `assigneeIds[]` replaces the single
  `assignedEmployeeId` (kept as a mirror for backward compatibility). Assign one,
  several, or the **whole team** (multi-select assign sheet). Employee task query
  + stats now use `assigneeIds arrayContains`.
- **`UserAvatar` + `AvatarStack`** ([user_avatar.dart](lib/core/widgets/user_avatar.dart))
  — the **assignee image bug fix**: a reliable circular avatar that renders
  `users/{uid}.photoUrl` (kept in sync with the profile `profileImage`) and falls
  back to **initials** on any missing/empty URL, network failure, or decode error
  — never a broken-image icon or crash. Decode size is capped; `gaplessPlayback`
  avoids flicker. `AvatarStack` shows overlapping avatars + a "+N" overflow.
- **`EntranceFade` + `staggerDelay`** ([app_motion.dart](lib/core/widgets/app_motion.dart))
  — tasteful, performance-conscious card/list entrance motion (used on task,
  admin, branch and KPI cards).
- **`AppSearchField`** ([app_search_field.dart](lib/core/widgets/app_search_field.dart))
  — shared search box; added to the Managers, Employees, Approvals and Branches
  pages.
- **Admin Analytics page** ([admin_analytics_screen.dart](lib/features/admin/presentation/pages/admin_analytics_screen.dart),
  route `/admin/analytics`) — the full metric wall (grouped Workforce / Tasks /
  Coverage), moved off the Admin Home.

### Changed (UI redesign — no business-logic change unless noted)
- **Task cards** — glass-like gradient cards with a priority rail, status badge,
  **assignee avatars** (name + role for a single assignee; stack + count for
  many; tap → assignee sheet), **checklist progress bar**, priority/category/
  deadline chips, and the existing actions. Employee identity is now visible
  (avatar · name · role) instead of "assigned/unassigned".
- **Admin Home** restructured to **four headline KPIs** (Branches · Employees ·
  Managers · Active tasks) + a clean module nav (Branches · Schedules · Managers
  · Employees · Analytics · Approvals · Settings). The crowded stat wall is gone
  (now on Analytics).
- **Branches page** — premium cards showing **manager + employee count + status**
  (resolved via `AdminUsersCubit.usersWithRole`), search, animated entrance.
- **Managers / Employees / Approvals** — avatar-led `AdminUserCard`s; Employees
  gained **search + active/inactive + branch** filters; Managers/Approvals gained
  search.
- **Schedule** (no logic change) — day **coverage indicator**, **shift badges**,
  **employee chips with avatars**, avatar-led picker, and the employee "My Week"
  team/manager shown with avatars.
- **Firestore rules** (`tasks/{taskId}`) — read/own-task-update now key off
  `assigneeIds` (`request.auth.uid in assigneeIds`, with a legacy
  `assignedEmployeeId` fallback); the assigned employee still can't reassign
  (`assigneeIds` frozen on self-update), move branch, or set the terminal
  approved/rejected status.

### Verified
- `flutter analyze` — clean (only the 2 pre-existing `prefer_initializing_formals`
  infos). `build_runner` regenerated the freezed entities/state. New unit tests
  ([task_checklist_test.dart](test/task_checklist_test.dart), 7 passing) cover the
  checklist completion rule, multi-assignee (de)serialization + legacy fallback,
  and template→task checklist generation. Existing task & schedule workflows are
  unchanged in shape; admin navigation reaches every module.

### Notes / honest limitations
- Tasks created **before** Phase 9 carry only `assignedEmployeeId`; the model
  reads it into `assigneeIds` on load and re-writes the array on the next save,
  so they migrate transparently as they're touched (no bulk migration needed for
  a pre-production dataset). `firestore.rules` were edited but **not deployed** in
  this environment.

---

## 2026-06-16 — Stabilization & Workflow Integration

Production-usability pass making the task workflow reliable end-to-end, plus a
new **Task Templates** feature. **No redesign, no rebuild** — reuses the
existing task architecture, widgets, and theme.

### Fixed
- **Build was broken — `pubspec.yaml` had `name:Drop`** (invalid YAML *and* the
  wrong package name; every import is `package:fbro/…`). Restored to
  `name: fbro` so the project compiles, codegen runs, and `flutter analyze` works.
- **Admin-created tasks could be orphaned / unassignable.** The admin task form
  used a **free-text branch field** — a typo (`cairo`) stored a `branchId` that
  matched no real branch, so the Assign sheet found no employees ("flow looks
  broken"). The admin now **picks an existing branch from a Firestore-backed
  dropdown** (`task_action_sheets._BranchDropdown` → `TaskCubit.branches()` →
  `BranchRepository`), so the task's `branchId` always matches the employees'
  `users/{uid}.branchId`. Managers still use their own fixed branch.
- **Employees didn't see a task right after assignment.** Task lists were
  one-shot reads, so a just-assigned task only appeared on manual refresh. Lists
  are now **realtime** (see below).
- **Profile image change could "freeze" the app.** Storage uploads had **no
  timeout**, so a disabled/misconfigured bucket or a dropped connection hung the
  UI indefinitely. Added a 60s upload + 20s download-URL timeout
  (`ProfileRemoteDataSource`), surfaced as a clean error. Also shrank picked
  images (avatar 800px / cover 1280px, q70) and capped decode size
  (`cacheWidth`) on every avatar/cover/proof image so a large bitmap can't jank
  the UI thread.

### Added
- **Task Templates** — reusable task blueprints ("Open Shop", "Close Shop",
  "Morning/Night Checklist") so recurring daily work isn't retyped each shift.
  Full slice folded into the **existing** task feature (faithful reuse, not a new
  system): `TaskTemplateEntity` (freezed) + `TaskTemplateModel`, template CRUD on
  `TaskRemoteDataSource`/`TaskRepository`(+Impl), and `TaskCubit.templates /
  saveTemplate / deleteTemplate`. New collection `task_templates/{id}` with
  branch-scoped `firestore.rules` (admin: global or any · manager: own branch;
  employees don't read templates). UI: a two-step **New Task** chooser
  (Blank vs. From a template), a template picker that **prefills** the task form,
  and a **Manage Templates** sheet (add/delete) behind a new app-bar action on
  the manager/admin task screen (`task_template_sheets.dart`).

### Changed (realtime)
- **Task lists are now live Firestore streams.** `TaskRepository.watch{AllTasks,
  TasksByBranch,EmployeeTasks}` (added) drive `TaskCubit`, which subscribes by
  role (admin: all · manager: branch · employee: own) instead of one-shot
  fetches. A newly assigned task — or any status change — now appears
  **immediately** with no manual refresh, backed by the offline cache. Mutations
  keep the list visible (busy bar) and the stream reflects the result.
  Pull-to-refresh re-subscribes. Other lists (schedule/branch/admin/swaps) keep
  the instant reload-after-mutation model (per stabilization scope).

### Removed
- The three one-shot task **use cases** (`GetAllTasks`/`GetTasksByBranch`/
  `GetEmployeeTasks`) — superseded by the realtime streams. `TaskCubit` now takes
  the `TaskRepository` directly for streams/templates (+ `BranchRepository` for
  the branch picker), per the documented cubit convention (repository injection
  for stream/non-action access). The Future-based read methods remain on the
  repository contract.

### UI polish (safe, deterministic — visuals unverifiable in this env)
- All task/template/review bottom sheets share rounded chrome with a **drag
  handle** (`SheetHandle`); the assign empty-state copy now explains *why* a
  branch has no employees; the delete-confirm dialog is rounded.

### Verified (by code audit + tooling)
- `flutter analyze` — clean (2 pre-existing infos only). Codegen
  (`build_runner`) regenerates the new freezed template entity. Realtime task
  queries are **rules-compatible** (each role's query is provably safe under
  `tasks/{id}`). DI + routing unchanged in shape; the `branchRepository` is now
  built once and shared by `TaskCubit` and the admin module.

### Honest limitations
- **Flutter mobile UI can't be run/rendered here**, so visual polish was kept to
  safe, deterministic changes; the freeze fix is verified by code/logic, not an
  on-device repro. `firestore.rules` were edited but **not deployed/tested** in
  this environment. Storage still must be **enabled** in the Firebase console for
  uploads to succeed at all (an unrelated precondition).

---

## 2026-06-16 — Phase 8: QA, Hardening & UI Polish

Stabilization + polish pass to make the app feel like a production operations
system. **No new business features, no redesign.** Reuses existing widgets and
architecture; diffs kept focused. Produced [`QA_CHECKLIST.md`](QA_CHECKLIST.md)
(on-device manual QA sheet for the Employee / Manager / Admin workflows + real-time
/ offline / UI checks).

### Added / Improved (UI)
- **Dashboard loading skeletons** — the admin / manager / employee dashboards now
  show a shimmering `StatGridSkeleton` (new, in `statistics/.../stat_grid.dart`,
  reusing the existing `Skeleton` widget) while stats load, instead of a single
  spinner card — no layout jump when data arrives. The employee dashboard also
  skeletons its shift card.
- **Dashboard error state** is now an icon + message row (clearer than bare red
  text); pull-to-refresh still recovers it.

### Changed (real-time)
- **Manager swap approval refreshes the schedule automatically.** On
  `BranchScheduleScreen`, a `BlocListener` on `ShiftSwapCubit` refreshes
  `ScheduleCubit` the moment a swap action settles — so an approved swap (which
  rewrites the roster) shows on the Schedule tab without a manual pull-to-refresh.
  Fires only after a mutation, not on first load.

### Verified (by code audit — see Honest limitations)
- Full Employee / Manager / Admin workflows trace cleanly end-to-end; routing,
  role guards, DI (all 8 cubits + repos/datasources registered & provided),
  Firestore/Storage rules, FCM token foundation, offline persistence, and session
  restore are consistent. `flutter analyze` clean (2 pre-existing infos only).
- Pull-to-refresh confirmed present on **every** list screen already.

### Notes
- UI changes were deliberately limited to **safe, deterministic** improvements
  (skeletons, error rows, an auto-refresh) — broader visual restyling was **not**
  done blind, since Flutter mobile UI can't be visually verified in this
  environment. A prioritized visual-polish spec is in the final report / docs.
- The orphaned Phase 2 `shift` feature remains documented dead code (see prior
  entries) — kept per "remove only if safe, otherwise document."

---

## 2026-06-16 — Integration Audit (workflow verification)

End-to-end verification of the Employee / Manager / Admin business workflows and
the seams between features. One integration bug fixed; no new features.

### Fixed
- **Promoting an employee to manager wiped their branch.**
  `AdminUsersCubit.promoteToManager` called `changeUserBranch(uid, null)`
  unconditionally, so a promoted manager was left **branch-less** — unable to
  manage any schedule/tasks until a second "Assign Branch" step, and silently
  discarding the employee's existing branch. It now **preserves the existing
  branch** unless a new one is explicitly passed (admins can still reassign from
  the manager list). Updated the "Add manager" sheet copy to match.

### Verified (works end-to-end, by code audit)
- **Employee:** register → pending (real-time approval) → login → view schedule
  (team + manager resolve after the stabilization rule fix) → assigned task →
  start → complete (+ notes/proof to Storage) → submit for review.
- **Manager:** create/edit weekly schedule, assign/remove shift employees, create
  + assign tasks, review (approve/reject), and handle shift swaps (coworker →
  manager approval rewrites the schedule). All branch-scoped reads/writes pass the
  rules.
- **Admin:** create branches, manage managers (promote/assign-branch/activate/
  demote), manage employees (change-branch/activate/details), view analytics,
  device-token persistence for push.

### Notes / honest findings (not bugs — by design or out of scope)
- **Managers do not approve users** — approval is **admin-only** (Phase 6 design),
  so the brief's "Manager → Approve employee" is intentionally unsupported.
- **Rejected users** see the generic "Pending Approval" screen (access is correctly
  blocked; the message just doesn't distinguish rejected from pending).
- **Admin task creation** uses a free-text branch field (mistyping orphans the
  task); managers — the primary task creators — use their fixed branch and are
  safe. Pre-existing (Phase 4).
- **Cross-client updates** are not push: another user's open list / the dashboards
  reflect a change on refresh, and within the manager schedule screen approving a
  swap doesn't auto-refresh the schedule tab. Data is consistent after refresh;
  only the approval gate is stream-driven (see the stabilization entry).

---

## 2026-06-16 — Stabilization & Production Hardening

A production-readiness audit pass — verification, integration fixes, real-time
and offline hardening. **No new business features.** Reuses existing systems;
changes kept minimal and focused.

### Fixed
- **Employees could not load their weekly schedule (critical).** The Phase 7
  employee "My Schedule" resolves teammate + manager names via
  `getUsersByBranch`, but the `users` read rule only allowed **managers/admins**
  to read same-branch users — an employee's query was denied, so the whole
  schedule view errored. `firestore.rules` now lets **any branch member** read
  users in their **own** branch (`selfBranch() != '' && branchId == selfBranch()`),
  which is exactly what the schedule's "team working with me" + "current manager"
  needs. Managers/admins are unchanged; cross-branch reads stay blocked.
- **`getUsersByBranch` now fails gracefully** — the datasource wraps Firestore
  errors as `AuthException` (→ `AuthFailure`), so a permission/network error
  surfaces as a clean error state instead of an unhandled exception.

### Added
- **Firestore offline persistence** (`main.dart`) — `Settings(persistenceEnabled:
  true, cacheSizeBytes: CACHE_SIZE_UNLIMITED)`. Cached reads, writes queued and
  synced on reconnect, and no crashes when the connection drops. Reuses Firebase's
  built-in cache (no custom offline engine).
- **Real-time user-doc watch** — `AuthRepository.watchUser` /
  `UserRemoteDataSource.watchUser` (Firestore `snapshots()`) +
  `AuthCubit.watchCurrentUser` / `stopWatchingUser`.

### Changed
- **Pending Approval is now real-time, not polled.** `PendingApprovalPage`
  replaced its 6-second `Timer.periodic(refreshUser)` poll with
  `AuthCubit.watchCurrentUser` (a live `users/{uid}` listener): the instant an
  admin approves the account it redirects to the role shell — no delay, fewer
  reads. The manual "Check Approval Status" button remains as a fallback.

### Notes / honest state
- **Real-time scope:** the approval flow is now stream-driven. Task / schedule /
  branch lists still use **reload-after-mutation** (instant for the acting user)
  + pull-to-refresh; full cross-client streaming for those would convert the
  Future-based repositories to streams — a deliberate non-goal for a stabilization
  pass (it would redesign the data layer).
- **Orphaned Phase 2 shift placeholders remain** (`features/shift/...`,
  `/admin|manager/shifts`, `/my-shift`, `AppDependencies.shiftRepository`,
  `RouteNames.shiftsForRole`): unreachable from the UI and unused since the weekly
  Schedule (Phase 7) superseded them. Left intact this pass (deleting a feature is
  out of a minimal stabilization scope); recommended for removal in a focused
  cleanup. The shift-visibility requirement is met by the Weekly Schedule.

---

## 2026-06-16 — Phase 7: Weekly Schedule & Shift Swap

Replaces the Excel / WhatsApp shift roster with an in-app **weekly schedule**:
managers build their branch's week (Day → Morning / Night → Employees), employees
see their week + today's team + manager, and coworkers trade shifts through a
**swap workflow** (coworker approves → manager approves → schedule updates
automatically). Reuses the existing Clean Architecture, Role/Branch systems, and
the FCM contract; no Node.js, no working systems rewritten.

### Added
- **`schedule` feature** (full vertical slice, repo-direct cubits — like
  branch/admin):
  - **Enums** (`core/enums`): `ScheduleDay` (Sun→Sat, `fromDate`/`today`),
    `ScheduleShift` (`morning`/`night`), `SwapStatus`
    (`pending`/`employeeApproved`/`managerApproved`/`rejected`).
  - **Domain**: `ScheduleWeek` (week-start math + deterministic doc id
    `<branchId>_<yyyy-MM-dd>`), `WeeklyScheduleEntity` (nested
    `day → shift → [uid]` roster + helpers), `ShiftSwapEntity`, and
    `ScheduleRepository`.
  - **Data**: `WeeklyScheduleModel` / `ShiftSwapModel`, `ScheduleRemoteDataSource`
    (`weekly_schedules` + `shift_swaps`; nested `arrayUnion`/`arrayRemove` for
    assign/remove; merge-two-queries for an employee's swaps) and
    `ScheduleRepositoryImpl` (`managerApproveSwap` updates the swap **and** the
    schedule).
  - **Cubits** (provided app-wide): `ScheduleCubit` (loads a (branch, week) view
    + branch members; create/assign/remove; week + branch navigation) and
    `ShiftSwapCubit` (employee `loadMine` / manager `loadBranch`; request /
    coworker-approve / reject / manager-approve).
  - **Screens**: manager `BranchScheduleScreen` (tabs: editor + swap queue),
    admin `ScheduleManagementScreen` (branch picker + editor, override any
    branch), employee `MyScheduleScreen` (tabs: My Week — today's shift, team,
    manager, per-slot "Request swap" — + Swaps). Shared `ManagerScheduleView`,
    `SwapListView` + `showSwapRequestSheet`, `schedule_helpers`.
  - **Routes** `/admin/schedule`, `/manager/schedule`, `/my-schedule`
    (`RouteNames.scheduleForRole`, role-guarded like tasks). The role-chrome
    calendar icon now opens the **weekly Schedule** (was the Phase 2 shift
    placeholder).
  - **DI** `scheduleCubit` / `shiftSwapCubit` wired in `injection.dart` + provided
    in `main.dart`. `AppConstants.weeklySchedulesCollection` / `shiftSwapsCollection`.
- **Firestore rules** for `weekly_schedules/{id}` (branch-scoped: admin/own-branch
  manager write · any employee of the branch reads) and `shift_swaps/{id}`
  (read/act = the two employees + branch manager/admin; create = requester in own
  branch). Exact swap flow validated client-side (`ShiftSwapCubit`).
- **Notification contract** (`NotificationType`): `tomorrowShiftReminder`,
  `swapApproved`, `swapRejected` (employee), `newSwapRequest`,
  `swapPendingApproval` (manager), `branchWithoutSchedule` (admin) — the sender is
  still out of scope (no Cloud Functions).

### Changed
- **Dashboards now read the weekly schedule** (Phase 7), not the Phase 2 `shifts`
  placeholder: employee — **current + upcoming shift**; manager — **scheduled /
  morning / night today**; admin — **schedule coverage** (`branchesWithSchedule`/
  `totalBranches`). New `StatisticsEntity` fields (`branchesWithSchedule`,
  `scheduledToday`, `upcomingShiftName`); `morningShiftEmployees`/
  `nightShiftEmployees`/`currentShiftName` now mean "today, per the weekly
  schedule." `StatisticsRepository.employeeStats` gained a `branchId` arg.

### Notes
- **Swap = single-slot handover**: the requester gives up one (week, day, shift)
  cell; on manager approval they're removed and the target is added. Status-flow
  order is enforced client-side (`ShiftSwapCubit`); the rules enforce *who* writes.
- The Phase 2 `shift` foundation (`shifts/{shiftId}`) is **untouched** — the
  weekly schedule is the production roster and supersedes the placeholder shift
  screens for navigation. No notifications sender, no analytics engine (out of
  scope).

---

## 2026-06-15 — Phase 6: Operations Dashboards & Notifications

Makes the app feel like a DROP THE SHOP operations center: live role-scoped
dashboards and a Firebase Cloud Messaging foundation. Reuses existing
architecture; no analytics engine, no Node.js, no chat/inbox.

### Added
- **`statistics` feature**: `StatisticsEntity` (freezed) / `StatisticsModel` /
  `StatisticsRepository(+Impl)` / `StatisticsRemoteDataSource` + `StatisticsCubit`.
  `load(user)` dispatches by role — `adminStats()` (global) / `managerStats(branchId)`
  / `employeeStats(uid)` — computing operational counts from branch-scoped
  single-field queries + client-side aggregation (no composite indexes).
- **Live dashboards** via a shared `StatGrid`: admin (branches, managers,
  employees, pending approvals, active/completed tasks, waiting reviews, rejected
  today, no-manager branches), manager (own-branch employees, active/waiting/
  completed-today/rejected/daily/special tasks, morning/night shift staff),
  employee (current shift, assigned/pending/waiting-review/completed tasks).
  `AdminDashboardScreen`, `ManagerHomeScreen` and `EmployeeHomeScreen` now show
  real data (the manager/employee placeholders are gone).
- **FCM foundation**: `core/services/notification_service.dart` (permission,
  device-token persistence on `users/{uid}.fcmToken`, foreground → in-app
  snackbar) + `core/enums/notification_type.dart` (the employee/manager/admin
  event contract). Wired in `main.dart` (background handler, init, token
  register/forget on auth changes, `scaffoldMessengerKey`). Added the
  `firebase_messaging` dependency.

### Changed
- **Account approval is now admin-only** — removed the manager user-write path
  (approve/claim) and the manager pending-read from `firestore.rules`. Managers
  read their own-branch team but manage **operations only** (shifts/tasks), not
  accounts. (Workflow: register → pending → **admin** approves → role + branch →
  active.)
- Replaced the Phase 5 `AdminStatsCubit`/`AdminStats` with the unified
  `StatisticsCubit` (admin dashboard migrated; redundant files removed).

### Notes
- Push **sending** is out of scope (needs a server trigger / Cloud Function —
  no Node.js). This phase ships the client foundation only; `NotificationType`
  is the event contract. iOS still needs an APNs key + Push capability.
- `count()` aggregate queries are a documented future optimization if data grows.

---

## 2026-06-15 — Phase 5: Admin Management module

Builds the complete admin module: branch management, manager/employee/pending
user administration, branch assignment, and a reports overview. Reuses the
existing Clean Architecture and Firebase backend; no working code rewritten.

### Added
- **`branch` feature** (full vertical slice): `BranchEntity` (freezed) /
  `BranchModel` / `BranchRepository(+Impl)` / `BranchRemoteDataSource` +
  `BranchCubit`/`BranchState` + `BranchManagementScreen` + `branch_form_sheet`.
  Admin CRUD, activate/deactivate, and **soft delete** (`deletedAt`).
  Collection `branches/{branchId}` + `AppConstants.branchesCollection`.
- **`admin` module**: `UserAdminRemoteDataSource` + `UserAdminRepository(+Impl)`
  over `users/{uid}` (reusing the auth `UserModel`/`UserEntity`); `AdminUsersCubit`
  (loads pending / managers / employees by `AdminUserFilter`; approve, reject,
  (de)activate, change role, change branch, promote-to-manager) and
  `AdminStatsCubit` (+ `AdminStats`) for the reports overview.
- **Admin screens**: reworked `AdminDashboardScreen` (reports overview — branches,
  managers, employees, pending approvals, active + completed tasks — plus
  navigation) and `BranchManagementScreen`, `ManagerManagementScreen`,
  `EmployeeManagementScreen` (branch filter + details), `PendingApprovalsScreen`;
  shared `AdminUserCard` / `admin_user_sheets` (approve, assign branch, promote) /
  `admin_users_list_view`.
- **Routes** `/admin/branches|managers|employees|approvals` (under the existing
  admin-only `_isAdminArea` guard); `branchCubit`/`adminUsersCubit`/
  `adminStatsCubit` wired in DI and provided app-wide in `main.dart`.
- **Firestore rules** for `branches/{branchId}` (admin write · any signed-in
  read · hard delete denied). Admin user-administration uses the existing `users`
  admin-update rule.

### Notes
- **Managers are promoted from existing approved users** — no client-side Firebase
  Auth account creation (it would sign the admin out) and no Cloud Functions
  (no Node.js). New staff self-register → admin approves (optionally as manager).
- The Phase 5 `admin`/`branch` **cubits call repositories directly** (no use-case
  layer), unlike `auth`/`profile`/`task` — a deliberate scope choice.
- The first admin is still bootstrapped manually in the Firebase console.
- No notifications, no analytics (out of scope).

---

## 2026-06-15 — Rebrand to DROP

Replaces the **FBRO** visual identity with **DROP** across the app.

### Added
- `DropLogo` ([drop_logo.dart](lib/core/widgets/drop_logo.dart)) — renders the
  **DROP wordmark artwork** at `assets/drop_logo.png` (the brand's "DROP" + down
  arrow). The PNG is transparent-background with white-filled glyphs; `DropLogo`
  tints it to the theme color (white) via `BlendMode.srcIn` so it stays crisp on
  the near-black UI, sized by `height`.
- `assets/drop_logo.png` registered in `pubspec.yaml` (`flutter: assets:`).
- The logo now appears on the **splash / loading screen**, **Login** and
  **Register** headers, and the **Pending Approval** screen.

### Changed / Removed
- Removed `FbroLogo` (`fbro_logo.dart`) and all its usages.
- App display name → **DROP** (`MaterialApp.title`, `AppConstants.appName`).

### Notes
- This is a **visual** rebrand. The Dart package name (`fbro`, `package:fbro/…`)
  and the iOS bundle id (`com.example.fbro`) are unchanged — renaming those is a
  separate, higher-risk refactor (every import + native config) and is not
  required for the user-facing brand.
- The logo is tinted **white** for the dark-only UI; if a light theme is wired up
  later, the tint should adapt (or ship a dark-on-light variant).

---

## 2026-06-15 — Phase 4: Task Workflow & Review System

Activates the Phase 3 task foundation into the **real operations workflow** —
managers/admins create + assign, employees execute, managers/admins review — with
a `TaskCubit`, functional role screens, proof images, audit fields and
status-transition rules. Reuses the existing architecture; no foundations rewritten.

### Added
- **`TaskCubit` + `TaskState`** ([cubit](lib/features/task/presentation/cubit/task_cubit.dart))
  driving the workflow for all three roles (loads by role; keeps the list visible
  during mutations; surfaces errors as snackbars). Provided app-wide in
  [main.dart](lib/main.dart).
- **10 task use cases** (`GetAllTasks`, `GetTasksByBranch`, `GetEmployeeTasks`,
  `CreateTask`, `UpdateTask`, `DeleteTask`, `AssignTask`, `ChangeTaskStatus`,
  `ReviewTask`, `UploadTaskProof`) + the auth `GetUsersByBranch` (assignee picker).
- **Functional screens** replacing the Phase 3 placeholders:
  - Employee **My Tasks** — start → complete (notes + optional **proof image**
    via `image_picker`) → submit for review; restart a rejected task.
  - Manager **Branch Tasks** / Admin **Task Management** (shared
    `ManagerTasksView`) — create, edit, **assign** (branch-employee picker),
    delete, and **review** (approve/reject + note).
  - Shared `TaskCard`, `task_action_sheets` (create/assign/review), and
    `TaskEmptyState` widgets.
- **Status-transition validation** in `TaskCubit._canTransition`
  (pending→started→completed→waitingReview→approved/rejected, plus rejected→started
  for redo); invalid moves are blocked with an error.
- **Review audit fields** on `TaskEntity`/`TaskModel`: `approvedBy`/`approvedAt`/
  `rejectedBy`/`rejectedAt`/`reviewNotes` (written together by `reviewTask`).
- **Proof image upload** to Firebase Storage `tasks/{taskId}/proof.jpg`
  (`TaskRepository.uploadProof`); `storage.rules` updated.
- `AuthRepository.getUsersByBranch` + `UserRemoteDataSource.getUsersByBranch`
  (branch employees for the assignee picker).

### Changed
- `TaskRepository` gained `reviewTask` + `uploadProof`; `TaskRemoteDataSourceImpl`
  now also takes `FirebaseStorage`.
- `firestore.rules` (`tasks/{taskId}`): the employee self-update now also forbids
  changing the review-attribution fields (`approvedBy`/`rejectedBy`).
- DI: `AppDependencies.taskCubit` added and wired.

### Notes
- Status-flow order is enforced **client-side** (`TaskCubit`); `firestore.rules`
  still enforce *who* may write. Hardening the transition matrix server-side,
  resolving assignee uid → name on cards, and `users.assignedShift` sync are
  follow-ups. **No notifications, no analytics** (out of scope).

---

## 2026-06-15 — Phase 3: Task Management foundation

Adds the **core FBRO workflow** foundation — managers create/assign tasks,
employees execute them, managers review them. Data + domain + rules + placeholder
UI only; **no task Cubit / use cases / workflow UI yet** (minimal & extensible).

### Added
- **Task enums** in `core/enums`: `TaskType` (daily/special), `TaskStatus`
  (pending→started→completed→waitingReview→approved/rejected) and `TaskPriority`
  (low/normal/high), each with safe `fromString` defaults.
- **`task` feature** with full data + domain layers:
  - `TaskEntity` ([task_entity.dart](lib/features/task/domain/entities/task_entity.dart),
    freezed): `id, title, description?, type, status, priority, branchId?,
    assignedEmployeeId?, createdBy?, assignedShiftId?, deadline?, notes?,
    proofImageUrl?, createdAt?, updatedAt?`.
  - `TaskModel` ([task_model.dart](lib/features/task/data/models/task_model.dart))
    — Firestore (de)serialization for `tasks/{taskId}`.
  - `TaskRepository` (+ `TaskRepositoryImpl`) and `TaskRemoteDataSource`
    (+ `Impl`): list (all / by branch / by employee), get, create, update,
    delete, `assignTask` (employee + optional shift) and `updateStatus`
    (workflow transitions). Datasource throws `ServerException` → `ServerFailure`.
- **Firestore rules** for `tasks/{taskId}` — branch model (admin all · manager
  own branch) **plus a limited employee self-update**: the assigned employee may
  advance status / add notes / proof on their own task but may not reassign,
  change branch/creator, or set the terminal approved/rejected status.
- **Three role placeholder screens** (`task_management_screen` [admin],
  `branch_tasks_screen` [manager], `my_tasks_screen` [employee]) at
  `/admin/tasks`, `/manager/tasks`, `/my-tasks`, reachable via a **Tasks icon**
  in the shared `RoleScaffold` (`RouteNames.tasksForRole`).
- `AppConstants.tasksCollection`; `AppDependencies.taskRepository` (DI wiring).

### Notes
- Admin/manager task routes reuse the existing `_isAdminArea` / `_isManagerArea`
  route guards; `/my-tasks` is self-scoped.
- Screens are functional placeholders only. Proof-image **upload to Storage** is
  not wired yet (`proofImageUrl` is a plain field); the workflow UI and
  `users.assignedShift` sync land in the next phase.
- **Notifications and analytics are intentionally not built** (out of scope).

---

## 2026-06-15 — Phase 2: Shift Management foundation

Adds the shift system foundation (data + domain + rules + placeholder UI) that
manager scheduling and, later, task management build on. Minimal and extensible
by design — **no shift Cubit / use cases / CRUD UI yet**.

### Added
- **`shift` feature** with full Clean-Architecture data + domain layers:
  - `ShiftEntity` ([shift_entity.dart](lib/features/shift/domain/entities/shift_entity.dart),
    freezed): `id`, `name`, `startTime`, `endTime`, `branchId?`, `employeeId?`,
    `isActive`, `createdAt?`, `updatedAt?` (V1 = Morning 08:30–16:30 / Night
    16:30–23:00; strings keep it extensible for weekend/custom shifts).
  - `ShiftModel` ([shift_model.dart](lib/features/shift/data/models/shift_model.dart))
    — Firestore (de)serialization for `shifts/{shiftId}`.
  - `ShiftRepository` (+ `ShiftRepositoryImpl`) and `ShiftRemoteDataSource`
    (+ `Impl`): `getAllShifts`, `getShiftsByBranch`, `getShift`,
    `getEmployeeShift`, `createShift`, `updateShift`, `deleteShift`,
    `assignEmployee`. Datasource throws `ServerException`; repo → `ServerFailure`.
- **Firestore rules** for `shifts/{shiftId}` using the existing
  `canReachBranch()` helper — admin: all branches; manager: own branch;
  employee: their own assigned shift (read-only). First branch-scoped collection.
- **Three role placeholder screens** (`shift_management_screen` [admin],
  `branch_shift_screen` [manager], `my_shift_screen` [employee]) at
  `/admin/shifts`, `/manager/shifts`, `/my-shift`, reachable via a **Shifts icon**
  in the shared `RoleScaffold` (`RouteNames.shiftsForRole`).
- `AppConstants.shiftsCollection`; `AppDependencies.shiftRepository` (DI wiring,
  ready for the shift UI to consume next phase).

### Notes
- Reuses the existing `users/{uid}.assignedShift` field (references the assigned
  `shiftId`) — the user model was **not** redesigned.
- Admin/manager shift routes are covered by the existing `_isAdminArea` /
  `_isManagerArea` route guards; `/my-shift` is self-scoped.
- The screens are functional placeholders only; the CRUD/assignment UI and the
  `users.assignedShift` sync on assignment land in the next phase.

---

## 2026-06-14 — Account approval flow & Welcome removal

Reworks the authentication entry flow for an internal ops tool: no public
marketing page, and new accounts must be approved before they can be used.

### Added
- `ApprovalStatus` enum (`pending` / `approved` / `rejected`) in
  [core/enums/approval_status.dart](lib/core/enums/approval_status.dart) with
  safe string (de)serialization that defaults unknown/missing → `approved` so
  legacy user documents are never locked out.
- `approvalStatus` field on `UserEntity` / `UserModel`, plus
  `UserEntity.isApproved` and `UserEntity.hasAppAccess` (`isApproved &&
  isActive`) computed getters.
- **Pending Approval screen** ([pending_approval_page.dart](lib/features/auth/presentation/pages/pending_approval_page.dart),
  route `/pending-approval`): the holding screen for authenticated-but-unapproved
  accounts. Polls `AuthCubit.refreshUser` so an approval lands the user in their
  role shell without a re-login; offers Sign Out.
- `AuthCubit.refreshUser` — re-reads the Firestore user and re-emits
  `authenticated` so the router re-evaluates access.
- **Approval gate** in the router redirect (checked **before** role dispatch):
  `!user.hasAppAccess` → confined to `/pending-approval`.

### Changed
- **New accounts are seeded `pending` + `isActive: false`** (employee, no branch)
  in the `saveUser` first-creation block; `approvalStatus` joins the
  seeded-once / excluded-from-`toMap()` privileged fields.
- **`firestore.rules`**: self-registration now requires `isActive == false` &&
  `approvalStatus == 'pending'`; employees can't change `approvalStatus`;
  **managers** can approve/manage employees of their **own branch** (and claim
  pending newcomers into it) without elevating role/branch; admins approve
  anyone; managers can read pending newcomers.
- Unauthenticated landing is now **Login** (router redirect + `SplashPage`);
  `LoginPage` shows a back button only when it can pop.

### Removed
- The social-style **Welcome / marketing page** (`welcome_page.dart`) and the
  `/welcome` route — FBRO is an internal tool, not a social network.

### Notes
- No in-app approval UI yet: approval is done out of band (Firebase console),
  like role promotion. The **first admin** must be bootstrapped there
  (`role: admin`, `approvalStatus: approved`, `isActive: true`) since every
  sign-up is seeded pending.

---

## 2026-06-14 — Role architecture refinement

Refines the Phase 1 foundation into a role **hierarchy** + **branch-scoped**
access model, before Phase 2. No model fields changed.

### Changed
- **Access model defined:** **admin** = global (not branch-restricted, can do
  everything a manager can — *admin ⊇ manager*); **manager** = limited to their
  own branch (`resource.branchId == manager.branchId`); **employee** = own data
  only. Documented on `UserRole` and mirrored in `firestore.rules`.
- **Route guard** now respects the hierarchy: admin areas stay admin-only, but
  **manager areas admit admins too**; employee home (`/`) stays employee-only.
- **`firestore.rules` rewritten** around reusable `isAdmin()` / `isManager()` /
  `selfBranch()` / `canReachBranch()` helpers: managers can read users **in
  their own branch**, admins read/write **any** user (promotion, branch move,
  (de)activation), employees keep self-only access with role fields locked.
  Added a commented template for Phase 2+ branch-scoped collections (branches,
  shifts, tasks).

### Added
- `UserRole.isAdmin` / `isManager` / `isEmployee` / `isGlobal` getters.

---

## 2026-06-14 — Phase 1: Roles & Foundation

Establishes the role system every later phase depends on.

### Added
- `UserRole` enum (`admin` / `manager` / `employee`) in
  [core/enums/user_role.dart](lib/core/enums/user_role.dart) with safe
  string (de)serialization that defaults unknown values to `employee`.
- Role foundation fields on `UserEntity` / `UserModel`: `role`, `branchId`,
  `isActive`, `assignedShift`.
- **Role seeding**: new users are seeded `role: employee`, `isActive: true`
  **once** on first `users/{uid}` creation; these fields are excluded from
  `toMap()` so re-login merges never reset an admin-assigned role/branch.
- **Role-based routing**: `RouteNames.homeForRole` + router redirect dispatch
  each user to their role shell after login.
- **Role guards**: per-area guards in `app_router.dart` bounce any user out of
  another role's area (incl. manual URL hacking); `/profile` & `/settings`
  remain shared.
- Three role shells + screens: `AdminShell`/`AdminDashboardScreen`,
  `ManagerShell`/`ManagerHomeScreen`, `EmployeeShell`/`EmployeeHomeScreen`,
  plus shared `RoleScaffold` and `RolePlaceholder` widgets
  (`features/{admin,manager,employee}`, `core/widgets`).
- Security rules committed: [`firestore.rules`](firestore.rules) (owner-only
  access; self-elevation of role fields forbidden) and
  [`storage.rules`](storage.rules), wired into [`firebase.json`](firebase.json).

### Changed
- `AuthCubit` now re-reads the Firestore user after email/Google/OTP sign-in so
  the emitted `authenticated` state carries the authoritative role/branch for
  routing.
- `SplashPage` dispatches authenticated users via `RouteNames.homeForRole`.

### Removed
- `features/home/home_page.dart` (the generic Home screen) — its UI moved into
  `EmployeeHomeScreen`; `/` now renders `EmployeeShell`.

### Notes
- FBRO is a **role-based branch/shift operations app, not a social network**.
  The legacy social counter fields on `ProfileEntity` are unused and slated for
  removal in a future cleanup.
- Rules still need deploying; role promotion is done out of band until the
  Phase 5 admin console.

---

## 2026-06-14 — Redesign & production profile system

### Added
- **Profile module** (`features/profile`): full view + edit, Firestore-backed
  `ProfileEntity` (identity, personal, account, social counters, presence,
  privacy settings), avatar/cover upload to Firebase Storage with live progress,
  and case-insensitive username availability checks.
- `ProfileCubit` with optimistic, flicker-free save flow (keeps last-known
  profile visible across `saving`/`error`).
- Settings module (`features/settings`): settings page + change password; delete
  account flow.
- Design system: monochrome black & white theme with white accent
  (`AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, `AppTheme`).
- FBRO branding (`FbroLogo` wordmark), shared `AppSnackbar` and `Skeleton`
  widgets, custom page transitions (fade/slide).
- Enhanced Google authentication configuration (Info.plist / settings).

### Fixed
- Per-action loading: `AuthState.loading` now carries an `AuthAction` so only
  the triggering button shows a spinner (fixes "every button spins on Google
  sign-in").

### Notes / follow-ups
- Requires Firebase **Storage enabled** and **Firestore security rules** to be
  configured for production.
- Social counters and presence fields are schema-ready but not yet
  backend-driven.

---

## 2026-06-13 — Authentication feature set

### Added
- Email/password sign-in & registration, phone OTP sign-in, Google sign-in.
- Forgot password, email verification (send + poll), change password,
  delete account.
- Session restore on cold start (`AuthCubit.restoreSession`) and auth-aware
  routing via `go_router` redirects (`_AuthStateNotifier`).
- Firestore user document: saved on registration (`users/{uid}`), loaded to
  restore session, surfaced on the Home screen.
- Clean Architecture scaffold: `core/` (di, errors, routes, theme, widgets,
  constants) and `features/auth` across data/domain/presentation layers.
- Auth UI + design system foundations (Phase 2).

### Refactored
- Completed Firebase authentication integration end-to-end (datasources →
  repository → use cases → cubit → pages).

---

## Earlier

- **Phase 1** — initial Flutter project bootstrap and Firebase setup.
