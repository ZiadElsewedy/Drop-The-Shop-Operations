# FBRO — Current State

> **Live status snapshot of the project.** Read this after
> [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) to know what's done, what's pending,
> and what needs configuring. This file answers "where are we right now?" —
> architecture/how-it-works lives in PROJECT_CONTEXT.md; history lives in
> [CHANGELOG.md](CHANGELOG.md).
>
> **Keep this current** — update it before finishing any task (see
> [Documentation Maintenance](PROJECT_CONTEXT.md#5-documentation-maintenance)).

**Last updated:** 2026-06-17
**Version:** 1.0.0+1 · **Branch:** `redesign` (DROP THE SHOP indigo redesign)

> **DROP THE SHOP UI redesign (2026-06-17):** restructured the role chrome into a
> **bottom navigation bar** (Home · Tasks · Schedule · Profile) and redesigned the
> signature auth screens (splash brand lockup, the breathing-clock Pending Approval,
> login/register copy) — **keeping the strictly-monochrome black / white / grey
> palette** (owner confirmed B&W/grey stays; no indigo). Added the
> `app_bottom_nav.dart` widget + rebuilt `RoleScaffold`, plus token *names*
> (`onPrimary`, `primarySurface`, flat `primaryGlow`) consumed by the new chrome —
> `AppColors.primary` stays white. **Also fixed a pre-existing Tasks-screen crash**
> ("BoxConstraints forces an infinite height" in `TaskCard`'s priority rail → now a
> `Stack`/`PositionedDirectional`; regression test added). **No logic / routing /
> data / rule changes** (`git diff` = theme/widget/screen/doc only). The
> `assets/drop_logo.png` wordmark is preserved. `flutter analyze` clean; **11 tests
> pass**. See [CHANGELOG.md](CHANGELOG.md).

> **Stability & UX Audit (2026-06-17):** hardened `UserModel`/`ProfileModel`
> `fromMap` against malformed docs (no more crash on a partial `users/{uid}`),
> simplified the role chrome to an overflow menu + **confirmed sign-out** (the
> overflow menu was later replaced by the **bottom-nav chrome** in the indigo
> redesign — Profile tab now carries Settings + Sign out), and
> standardized all auth/settings snackbars on `AppSnackbar`. Role separation,
> list states, and button flows audited clean.
>
> **De-duplication pass (2026-06-17):** extracted three shared utilities with no
> behaviour change — `context.currentUser`/`currentRole`
> ([context_extensions.dart](lib/core/extensions/context_extensions.dart), 13
> sites), `showConfirmDialog` ([app_dialog.dart](lib/core/widgets/app_dialog.dart),
> 3 dialogs), and `map.date()` for Firestore Timestamps
> ([firestore_extensions.dart](lib/core/extensions/firestore_extensions.dart), 21
> sites) — and removed dead code (`RolePlaceholder`) + 14 unused imports.
>
> **Shared component system (2026-06-17):** added `AppPasswordField` (login /
> register / change-password — 5 sites), `AppDropdownField<T>` (branch picker),
> `AppEmptyState` (`TaskEmptyState` now delegates), `AppCard` (surface·radius
> 24·press·hover — ready for adoption), and **`StatusBadge`** (`task_card`
> migrated; `.task`/`.approval`/`.swap`/`.active` factories); enhanced
> `AppTextField` (`readOnly`/`onTap`/`suffixIcon`, radius 20) and `context`
> (`isAdmin`/`isManager`/`isEmployee`, `showSuccess`/`showError`). **Next per the
> owner: a full Task Flow audit** (assignment · branch selection · admin task
> screen · employee task visibility). See [CHANGELOG.md](CHANGELOG.md).

---

## Status at a glance

| Module           | Status        | Notes                                                          |
| ---------------- | ------------- | ------------------------------------------------------------- |
| Authentication   | ✅ Complete    | Email, phone OTP, Google, verify, forgot/change pw, delete; landing = **Login** (social Welcome page removed) |
| Account approval | ✅ Complete*   | New sign-ups seeded `pending` + inactive → **Pending Approval** screen; gate in router (`hasAppAccess`). *In-app approval UI (manager/admin) still pending — approve out of band (console) until Phase 5 |
| Roles & routing  | ✅ Complete    | `UserRole` enum, role dispatch + guards; **admin ⊇ manager** hierarchy + branch-scoped access model (admin global · manager own-branch · employee self) |
| Shifts (Phase 2) | ❌ Removed (Phase 10) | The unused `shift` foundation (data/domain + placeholder screens + `shifts/{shiftId}` rules + `/admin\|manager/shifts`·`/my-shift` routes + DI) was **deleted** as dead code. The **Weekly Schedule** (Phase 7) is the production roster |
| Weekly Schedule (Phase 7) | ✅ Complete | `schedule` feature: `WeeklyScheduleEntity` + `ScheduleCubit` + manager editor / admin override / employee my-week view. Roster `day → morning/night → employees`; `weekly_schedules/{id}` rules. Reuses Role/Branch systems |
| Shift Swap (Phase 7) | ✅ Complete | `ShiftSwapEntity` + `ShiftSwapCubit`: employee requests → coworker approves → manager approves → schedule auto-updates; `shift_swaps/{id}` rules. Statuses pending/employeeApproved/managerApproved/rejected |
| Tasks (Phase 3–4, +Stabilization, +Phase 9) | ✅ Workflow + realtime + multi-assignee | Full vertical slice: `TaskCubit` + use cases, functional employee/manager/admin screens (create·assign·start·complete+notes/proof·submit·review approve/reject), client-side status-transition rules, audit fields, proof upload, **live Firestore streams**, admin **branch dropdown**. **Phase 9:** **multiple assignees** (`assigneeIds[]`, replaces single `assignedEmployeeId` — kept as a mirror), optional **checklist** generated from a template + completion gate, **redesigned task cards** (avatars · name/role · checklist progress · glass cards), employee directory resolution |
| Task / Checklist Templates (Stabilization, +Phase 9) | ✅ Complete | Reusable blueprints ("Open Shop", "Close Shop"). **Phase 9:** templates are now **checklists** — `TaskTemplateEntity.checklistItems` (`ChecklistItemTemplate`: id/title/isRequired) with a checklist editor; creating a task generates its `checklist`. `task_templates/{id}` rules (admin global/any · manager own-branch). New Task → Blank vs. From a template + Manage Templates sheet |
| Branches (Phase 5, +Phase 9) | ✅ Complete   | `BranchEntity`/`Model`/`Repository`/`RemoteDataSource` + `BranchCubit`; admin CRUD + activate/deactivate + soft delete; `branches/{id}` rules. **Phase 9:** premium cards (manager + employee count + status) + search |
| Admin module (Phase 5, +Phase 9 UX) | ✅ Complete | Branch / manager / employee management + **admin-only** pending-user approval + branch assignment. `AdminUsersCubit`, `UserAdminRepository` over `users/{uid}`. **Phase 9:** Admin Home restructured to **4 KPIs** + module nav; new **Analytics** page (`/admin/analytics`); avatar-led user cards; search + active/inactive/branch filters |
| Dashboards / Statistics (Phase 6, +Phase 7) | ✅ Complete | `statistics` feature (`StatisticsCubit`) drives **live** admin / manager / employee dashboards. **Phase 7:** shift/coverage figures read the weekly schedule. **Phase 9:** the full metric wall moved to the Analytics page; the Admin Home shows only 4 headline KPIs |
| Notifications (Phase 6, +Phase 7) | 🟡 Foundation | FCM client foundation: permission + device-token persistence + foreground snackbars. `NotificationType` extended with Phase 7 swap/schedule events. **Sending** the events needs a server trigger (out of scope) |
| Profile          | ✅ Complete    | View/edit, avatar+cover upload, username checks                |
| Settings         | ✅ Complete    | Settings page + change password + delete account              |
| Role shells      | ✅ Live        | All three role dashboards show live operational stats (Phase 6); Admin shell hosts the full admin module (Phase 5) |
| Design system    | ✅ Complete    | **Strictly monochrome** black / white / grey dark UI (`AppColors.primary` = white, the only accent; `onPrimary`/`primarySurface`/flat `primaryGlow`), **dark-mode only**; branded **DROP** (`DropLogo` wordmark, preserved). Role chrome is a **bottom navigation bar** (`AppBottomNav` + rebuilt `RoleScaffold`: Home · Tasks · Schedule · Profile). Signature screens: splash brand lockup, breathing-clock Pending Approval. **Phase 9:** premium glass cards, reusable `UserAvatar`/`AvatarStack`, `EntranceFade` motion, `AppSearchField` |
| Security rules   | ✅ In repo     | `firestore.rules` + `storage.rules` — committed, need deploy   |
| Social fields    | ⛔ Legacy      | Counter/presence fields linger in schema but are unused — **FBRO is not a social app** |

Legend: ✅ done · 🟡 partial · ⛔ not started

---

## Working tree

- **Branch:** `feature/roles-and-foundation`.
- **Phase 1 (Roles & Foundation) implemented** — `UserRole` enum, extended
  user model, role seeding, role-based routing + guards, three role shells, and
  Firestore/Storage security rules. `flutter analyze` is clean.
- **Auth-flow rework** — removed the social **Welcome** page (landing is now
  **Login**); added the **account-approval gate**: new sign-ups are seeded
  `pending` + inactive and confined to a new **Pending Approval** screen
  (`/pending-approval`) until an admin approves them (`hasAppAccess` gate in the
  router; approval became **admin-only** in Phase 6). New `ApprovalStatus` enum +
  `approvalStatus` user field + `AuthCubit.refreshUser` (polled by the pending
  screen).
- **Phase 2 — Shift foundation** — *(deleted in Phase 10 as dead code; the weekly
  schedule superseded it.)* Was a data+domain `shift` feature with placeholder
  screens, never wired into a working UI.
- **Phase 3 — Task foundation** — new `task` feature: data + domain
  (`TaskEntity`/`TaskModel`/`TaskRepository(+Impl)`/`TaskRemoteDataSource(+Impl)`),
  `TaskType`/`TaskStatus`/`TaskPriority` enums, `tasks/{taskId}` Firestore rules,
  three role routes/screens, repo wired in DI.
- **Phase 4 — Task workflow (activated)** — `TaskCubit` + `TaskState` + 10 use
  cases; the three screens are now **functional**: employee My Tasks
  (start → complete with notes + optional proof image → submit for review,
  restart if rejected); manager Branch Tasks / admin Task Management (create,
  edit, assign employee from a branch picker, delete, review → approve/reject
  with notes). Added review **audit fields** (`approvedBy`/`approvedAt`/
  `rejectedBy`/`rejectedAt`/`reviewNotes`), **proof image upload** to Storage,
  **client-side status-transition validation** (`TaskCubit._canTransition`), and
  `AuthRepository.getUsersByBranch` (assignee picker). `TaskCubit` is provided
  app-wide in `main.dart`. No notifications / analytics (out of scope).
- **Phase 5 — Admin module** — new `branch` feature (full vertical slice +
  `BranchCubit`: CRUD, activate/deactivate, soft delete) and `admin` module
  (`UserAdminRepository` over `users/{uid}`, `AdminUsersCubit`): management
  screens for **branches, managers, employees, and pending approvals**
  (`/admin/branches|managers|employees|approvals`). Admin can approve/reject
  users, (de)activate, change role/branch, assign managers to branches, and move
  employees between branches. `branches/{branchId}` Firestore rules added.
  **Managers are promoted from existing approved users** (no client-side Auth
  account creation — no Cloud Functions). admin/branch cubits call repositories
  directly (no use-case layer).
- **Phase 6 — Dashboards & notifications** — new `statistics` feature
  (`StatisticsEntity`/`Model`/`Repository(+Impl)`/`RemoteDataSource` +
  `StatisticsCubit`) computes **role-scoped operational counts** (branch-scoped
  single-field queries + client-side aggregation). The admin / manager / employee
  home dashboards now render **live stats** via a shared `StatGrid`. Added the
  **FCM foundation** (`core/services/notification_service.dart` +
  `core/enums/notification_type.dart`): permission, device-token persistence on
  `users/{uid}.fcmToken`, foreground snackbars, wired in `main.dart`. **Approval
  made admin-only** — the manager user-write path was removed from
  `firestore.rules`. Replaced the Phase 5 `AdminStatsCubit` with `StatisticsCubit`.
- **Phase 7 — Weekly Schedule & Shift Swap** — new `schedule` feature (full
  vertical slice; repo-direct cubits like branch/admin). `WeeklyScheduleEntity`
  (nested `day → morning/night → [uid]` roster) + `ShiftSwapEntity`,
  `ScheduleRepository(+Impl)`/`ScheduleRemoteDataSource`, `ScheduleCubit` +
  `ShiftSwapCubit`. Managers build/edit their branch's weekly schedule (assign /
  remove employees, navigate weeks); admins pick any branch and override; employees
  see **My Week** (today's shift + team + manager) and request **shift swaps**
  (coworker approves → manager approves → schedule updates automatically). Routes
  `/admin/schedule`, `/manager/schedule`, `/my-schedule` (role chrome calendar
  icon → weekly Schedule). New collections `weekly_schedules` / `shift_swaps` with
  branch-scoped Firestore rules. `ScheduleDay` / `ScheduleShift` / `SwapStatus`
  enums + `ScheduleWeek` (deterministic doc id `<branchId>_<yyyy-MM-dd>`).
  **Dashboards integrated** — shift/coverage stats now come from the weekly
  schedule. `NotificationType` extended (swap + schedule events). `flutter analyze`
  clean.
- **Stabilization & Workflow Integration (branch `stabilization-and-optimization`)**
  — production-usability pass. Fixed a **broken build** (`pubspec.yaml` had
  `name:Drop` → restored `name: fbro`). Fixed **admin task assignment**: the task
  form's free-text branch field is replaced by a **Firestore-backed branch
  dropdown** (`TaskCubit.branches()` → `BranchRepository`), so a task's
  `branchId` always matches employees' `branchId` and the Assign picker is
  populated. **Task lists are now realtime** (`TaskRepository.watch*` streams
  drive `TaskCubit`) — an assigned task / status change shows immediately. Added
  **Task Templates** (new `task_templates` collection + `TaskTemplateEntity`/
  `Model`, repo/cubit CRUD, New-Task-from-template + Manage Templates UI). Fixed
  the **profile image freeze** (upload timeouts + smaller picked images +
  `cacheWidth` decode caps). Removed the now-dead one-shot task use cases. `flutter
  analyze` clean (2 pre-existing infos).
- **Phase 9 — Task UX, Admin UX & Design Overhaul (branch `claude/upbeat-knuth-7ch3wu`)**
  — premium-operations redesign, reusing the existing architecture. **Checklist
  templates:** `ChecklistItem` / `ChecklistItemTemplate` entities;
  `TaskTemplateEntity.checklistItems` + `TaskEntity.checklist`; create-from-template
  generates the checklist; **completion gate** (`requiredChecklistComplete`) +
  per-item toggling + manager-review progress. **Multi-assignee:** `assigneeIds[]`
  replaces single `assignedEmployeeId` (kept as a synced primary mirror for
  rules/stats/back-compat); assign one/many/whole-team; `assigneeIds arrayContains`
  query + rules. **Redesigned** task cards (avatars · name/role · checklist
  progress · glass), admin Home (4 KPIs + nav + **Analytics** page), branch cards
  (manager + employee count), and avatar-led admin user cards with search/filters.
  **Avatar bug fixed** via reusable `UserAvatar`/`AvatarStack` (initials fallback,
  no broken icons). New shared widgets `app_motion.dart` (`EntranceFade`),
  `app_search_field.dart`, `user_avatar.dart`. Schedule polished (coverage,
  shift badges, avatar chips — no logic change). `flutter analyze` clean (2
  pre-existing infos); 7 new unit tests pass.
- **Phase 10 — Production Hardening & QA (branch `claude/upbeat-knuth-7ch3wu`)**
  — verification + stabilization + UI modernization (no new business modules; no
  architecture change). **Cleanup:** deleted the dead Phase 2 `shift` feature
  (folder + 3 routes + DI + `shiftsForRole` + `shiftsCollection` + `shifts/{id}`
  rules), verified by `flutter analyze`. **Dashboards modernized** into a
  command-center layout: Manager Home now leads with a "Needs attention" hero row
  (waiting reviews · active tasks, tappable to the task screen) then grouped
  Team/Shifts and Tasks sections; Employee Home leads with a premium glass
  "Today's shift" card then a focused "Your tasks" grid. **Loading states:**
  list screens (tasks · admin users · branches) now use a `ListSkeleton`
  shimmer instead of a bare spinner. New shared widgets `dashboard_section.dart`
  (`SectionHeader`, `HeroStatCard`) and `list_skeleton.dart`. **Audited** (by code
  + tooling): auth/approval/role guards, task & schedule workflows, analytics
  math, realtime/offline, error handling, and the **profile-upload** path (timeouts
  + progress + error recovery — no freeze). `flutter analyze` clean (2 pre-existing
  infos); 7 unit tests pass; `build_runner` consistent (0 stale outputs).
- **Action needed:** deploy `firestore.rules` / `storage.rules` and
  enable Firebase Storage; bootstrap the first admin (set
  `role/approvalStatus/isActive` in the console) before production.

---

## Routes (all implemented)

| Name                | Path                         | Page                    | Access        |
| ------------------- | ---------------------------- | ----------------------- | ------------- |
| splash              | `/splash`                    | `SplashPage`            | public        |
| home                | `/`                          | `EmployeeShell`         | **employee**  |
| adminDashboard      | `/admin`                     | `AdminShell`            | **admin**     |
| managerHome         | `/manager`                   | `ManagerShell`          | **manager**   |
| adminShifts         | `/admin/shifts`              | `ShiftManagementScreen` | **admin**     |
| managerShifts       | `/manager/shifts`            | `BranchShiftScreen`     | **manager** (+admin) |
| myShift             | `/my-shift`                  | `MyShiftScreen`         | any approved auth (self) |
| adminTasks          | `/admin/tasks`               | `TaskManagementScreen`  | **admin**     |
| managerTasks        | `/manager/tasks`             | `BranchTasksScreen`     | **manager** (+admin) |
| myTasks             | `/my-tasks`                  | `MyTasksScreen`         | any approved auth (self) |
| _(removed Phase 10)_ | ~~`/admin\|manager/shifts`, `/my-shift`~~ | — | Phase 2 shift screens deleted (dead code) |
| adminSchedule       | `/admin/schedule`            | `ScheduleManagementScreen` | **admin**  |
| managerSchedule     | `/manager/schedule`          | `BranchScheduleScreen`  | **manager** (+admin) |
| mySchedule          | `/my-schedule`               | `MyScheduleScreen`      | any approved auth (self) |
| adminBranches       | `/admin/branches`            | `BranchManagementScreen`| **admin**     |
| adminManagers       | `/admin/managers`            | `ManagerManagementScreen`| **admin**    |
| adminEmployees      | `/admin/employees`           | `EmployeeManagementScreen`| **admin**   |
| adminAnalytics      | `/admin/analytics`           | `AdminAnalyticsScreen`  | **admin**     |
| adminApprovals      | `/admin/approvals`           | `PendingApprovalsScreen`| **admin**     |
| login               | `/login`                     | `LoginPage`             | unauth (landing) |
| register            | `/register`                  | `RegisterPage`          | unauth        |
| phone               | `/phone`                     | `PhoneOtpPage`          | unauth        |
| forgotPassword      | `/forgot-password`           | `ForgotPasswordPage`    | unauth        |
| emailVerification   | `/email-verification`        | `EmailVerificationPage` | awaiting verif|
| pendingApproval     | `/pending-approval`          | `PendingApprovalPage`   | auth, not approved |
| profile             | `/profile`                   | `ProfilePage`           | any auth      |
| editProfile         | `/profile/edit`              | `EditProfilePage`       | any auth      |
| settings            | `/settings`                  | `SettingsPage`          | any auth      |
| changePassword      | `/settings/change-password`  | `ChangePasswordPage`    | any auth      |

Defined in [route_names.dart](lib/core/routes/route_names.dart) /
[app_router.dart](lib/core/routes/app_router.dart). Navigation is auth-guarded,
**approval-gated**, **and role-guarded**: an authenticated-but-unapproved user
(`!user.hasAppAccess`) is held on `/pending-approval`; once approved each user is
dispatched to their role shell (`RouteNames.homeForRole`), and attempts to enter
another role's area (incl. manual URL hacking) are bounced back to their own
home. `/profile` & `/settings` are shared across all roles. The unauthenticated
landing is **Login** (the social Welcome page was removed).

---

## Backend / Firebase status

- **Firebase Auth** — configured & working: Email/Password, Phone, Google.
- **Cloud Firestore** — in use. **Offline persistence enabled** (stabilization):
  `Settings(persistenceEnabled: true, cacheSizeBytes: CACHE_SIZE_UNLIMITED)` set
  in `main.dart` — cached reads, writes queued + synced on reconnect, no crashes
  when the connection drops. The Pending Approval screen uses a **real-time**
  `users/{uid}` listener (`AuthCubit.watchCurrentUser`) instead of polling.
- **Firebase Storage** — code uploads to `users/{uid}/avatar.jpg` &
  `cover.jpg`. ⚠️ **Storage must be enabled** in the Firebase console for
  uploads to work in production.
- **Security rules** — ✅ **In the repo:** [`firestore.rules`](firestore.rules)
  and [`storage.rules`](storage.rules), wired into [`firebase.json`](firebase.json).
  Firestore rules encode the role/branch + **approval** access model: **self
  registration** is allowed only as a `pending`, **inactive** employee;
  **admin** reads/writes any user (approve/reject, promotions, branch moves,
  (de)activation) — **account approval is admin-only (Phase 6)**; **any branch
  member** (manager **or** employee) **reads** users in their **own branch** —
  managers see their team, employees see the coworkers on their shift + their
  manager for the weekly schedule (stabilization fix; `selfBranch() != '' &&
  branchId == selfBranch()`) but only an **admin** writes user docs; **employee**
  edits only their own doc and may **not** change
  the privileged fields (`role`, `branchId`, `isActive`, `assignedShift`,
  `approvalStatus`) — non-privileged fields (profile, `fcmToken`) are allowed. **`shifts/{shiftId}` (Phase 2)** is the
  first branch-scoped collection wired to `canReachBranch()`: admin = all
  branches, manager = own branch, employee = their own assigned shift
  (read-only). **`tasks/{taskId}` (Phase 3–4)** follows the same model with a
  **limited employee self-update** — the assignee may advance status / add notes /
  proof, but not reassign, move branch, set approved/rejected, or forge the
  review-attribution fields (`approvedBy`/`rejectedBy`). **Storage** (`storage.rules`)
  now also allows task proof images at `tasks/{taskId}/proof.jpg` (any signed-in
  user read/write; the meaningful gate is the Firestore `proofImageUrl` write).
  **`branches/{branchId}` (Phase 5)** is admin-write / any-signed-in-read with
  hard delete denied (soft delete only); admin user-administration uses the
  existing `users` admin-update rule. **`weekly_schedules/{id}` (Phase 7)** is
  branch-scoped: admin/own-branch manager write, and **any employee of the
  branch** reads (their schedule + today's team) via `branchId == selfBranch()`.
  **`shift_swaps/{id}` (Phase 7)**: read/act = the two involved employees + the
  branch manager/admin; create requires the requester to be self and the swap to
  be in their own branch (the exact status flow is validated client-side in
  `ShiftSwapCubit`). **`task_templates/{id}` (Stabilization)**: read = any
  admin/manager; create = admin (global/any) or own-branch manager;
  update/delete = admin or the owning-branch manager (employees don't read
  templates). Reusable `isAdmin()` / `isManager()` / `canReachBranch()`
  helpers remain for future collections. ⚠️ Still need to be **deployed**
  (`firebase deploy --only firestore:rules,storage`).

### Firestore schema — `users/{uid}`

Shared by the auth (`UserModel`) and profile (`ProfileModel`) layers.

| Field                                                   | Type      | Notes                          |
| ------------------------------------------------------ | --------- | ------------------------------ |
| `uid`, `email`, `authProvider`                         | string    | core identity                  |
| `role`                                                 | string    | **Phase 1** — `admin` (global) / `manager` (one branch) / `employee` (own data); seeded `employee` once, role-guarded |
| `branchId`                                             | string?   | **Phase 1** — owning branch. **admin:** null/ignored (global); **manager:** their one branch; **employee:** their branch. Assigned by an admin. |
| `assignedShift`                                        | string?   | **Phase 1/2** — references the assigned `shifts/{shiftId}`; null until a manager assigns one |
| `isActive`                                             | bool      | **Phase 1** — activation/soft-disable. **New sign-ups seeded `false`** (pending approval); set `true` on approval |
| `approvalStatus`                                       | string    | **Approval** — `pending` / `approved` / `rejected`. New sign-ups seeded `pending`; missing → treated as `approved` (legacy). **Flipped by admin only (Phase 6)** |
| `fcmToken`, `fcmTokenUpdatedAt`                        | string? / Timestamp? | **Phase 6** — device push token (self-written, best-effort) |
| `displayName`, `photoUrl`                              | string    | **legacy** auth keys, kept in sync |
| `fullName`, `username`, `profileImage`, `coverImage`   | string    | profile identity               |
| `phoneNumber`, `bio`, `gender`, `country`, `city`, `website` | string?  | personal                       |
| `birthDate`, `createdAt`, `updatedAt`, `lastSeen`      | Timestamp | dates                          |
| `isEmailVerified`, `isVerified`, `isOnline`            | bool      | status/presence                |
| `isProfilePublic`, `allowMessages`, `allowNotifications` | bool    | privacy (default true)         |
| `accountStatus`                                        | string    | default `active`               |
| `followersCount`, `followingCount`, `postsCount`, `likesCount` | int | **legacy/unused** — FBRO is not a social app |

> **Privileged-field seeding:** `role`/`branchId`/`isActive`/`assignedShift`/
> `approvalStatus` are seeded **once** on first document creation (a new account
> is seeded as a `pending`, **inactive** employee) and are deliberately excluded
> from `UserModel.toMap()`, so a routine re-login (which merges) can never reset
> an admin-assigned role/branch or re-pend an approved account.

### Firestore schema — `branches/{branchId}` (Phase 5)

| Field        | Type       | Notes                                              |
| ------------ | ---------- | -------------------------------------------------- |
| `id`         | string     | mirrors the doc id                                 |
| `name`       | string     | branch name                                        |
| `location`   | string?    | optional area / address                            |
| `isActive`   | bool       | activate / deactivate                              |
| `deletedAt`  | Timestamp? | soft-delete marker (null = live; excluded from list)|
| `createdAt`, `updatedAt` | Timestamp | server timestamps                      |

> Admin-only writes; any signed-in user may read (branch names show in pickers).
> Managers/employees belong to a branch via `users/{uid}.branchId` (single source
> of truth for assignment).

### Firestore schema — `shifts/{shiftId}` (Phase 2 — REMOVED in Phase 10)

The `shifts` collection, its rules, and the whole `shift` feature were deleted in
Phase 10 (dead code, never consumed). The **weekly schedule**
(`weekly_schedules`) is the production roster. `users/{uid}.assignedShift` and
`tasks.assignedShiftId` remain as nullable strings (unused).

### Firestore schema — `tasks/{taskId}` (Phase 3, +Phase 9 multi-assignee)

| Field                | Type       | Notes                                                  |
| -------------------- | ---------- | ----------------------------------------------------- |
| `id`                 | string     | mirrors the doc id (set on create)                    |
| `title`              | string     | task title                                            |
| `description`        | string?    | details                                               |
| `type`               | string     | `daily` / `special`                                   |
| `status`             | string     | `pending`→`started`→`completed`→`waitingReview`→`approved`/`rejected` |
| `priority`           | string     | `low` / `normal` / `high`                             |
| `branchId`           | string?    | owning branch (admin: any · manager: own branch)      |
| `assigneeIds`        | string[]   | **Phase 9** — employees assigned to the task (multi-assignee). Empty = unassigned |
| `assignedEmployeeId` | string?    | **legacy mirror** of the primary assignee (`assigneeIds.first`), kept in sync for back-compat rules/stats; read falls back to it when `assigneeIds` is absent |
| `checklist`          | array<map> | **Phase 9** — `{id, title, isRequired, completed, completedAt}` items generated from the template; the task can't complete until all required items are `completed` |
| `createdBy`          | string?    | uid of the manager/admin who created it               |
| `assignedShiftId`    | string?    | optional link to `shifts/{shiftId}`                   |
| `deadline`           | Timestamp? | due date/time                                         |
| `notes`              | string?    | employee's free-text notes                            |
| `proofImageUrl`      | string?    | proof image download URL (uploaded on completion)     |
| `approvedBy`, `approvedAt`   | string? / Timestamp? | reviewer uid + time on approve (Phase 4 audit) |
| `rejectedBy`, `rejectedAt`   | string? / Timestamp? | reviewer uid + time on reject (Phase 4 audit) |
| `reviewNotes`        | string?    | reviewer's note on approve/reject (Phase 4)           |
| `createdAt`, `updatedAt` | Timestamp | server timestamps written by the datasource       |

> Workflow: manager/admin creates + assigns → employee `started`→`completed`→
> `waitingReview` → manager/admin `approved`/`rejected`. Branch/role access +
> the limited employee self-update are enforced by `firestore.rules`
> (`tasks/{taskId}`). The employee cannot reassign, change branch, or set the
> terminal approved/rejected status.

### Firestore schema — `task_templates/{id}` (Stabilization)

Reusable task blueprints. A template carries only task *content* — never an
assignment or status (those are set when a task is created from it).

| Field         | Type       | Notes                                                       |
| ------------- | ---------- | ---------------------------------------------------------- |
| `id`          | string     | mirrors the doc id (set on create)                         |
| `title`       | string     | template title (e.g. `Open Shop`)                          |
| `description` | string?    | optional details                                           |
| `type`        | string     | `daily` / `special`                                        |
| `priority`    | string     | `low` / `normal` / `high`                                  |
| `checklistItems` | array<map> | **Phase 9** — reusable checklist: `{id, title, isRequired}` per step (e.g. Unlock entrance · Turn on lights). Generated into a task's `checklist` on create |
| `branchId`    | string?    | owning branch; `''`/null = **global** (admin-made, all branches) |
| `createdBy`   | string?    | uid of the manager/admin who created it                    |
| `createdAt`, `updatedAt` | Timestamp | server timestamps                              |

> Branch/role access is enforced by `firestore.rules` (`task_templates/{id}`):
> read = any admin/manager; create = admin (global/any) or own-branch manager;
> update/delete = admin or the owning-branch manager. Employees don't read
> templates. Branch filtering (global + own branch) is applied client-side in
> `TaskCubit.templates` (the collection is tiny).

### Firestore schema — `weekly_schedules/{id}` (Phase 7)

One document per (branch, week). Deterministic id `<branchId>_<yyyy-MM-dd>` (the
week's Sunday), so a week is addressed directly without a query.

| Field         | Type       | Notes                                                       |
| ------------- | ---------- | ---------------------------------------------------------- |
| `id`          | string     | mirrors the doc id                                         |
| `branchId`    | string     | owning branch                                              |
| `weekStart`   | Timestamp  | Sunday 00:00 that starts the week                          |
| `assignments` | map        | `{ <day>: { <shift>: [uid, …] } }` — `day` = `sunday`…`saturday`, `shift` = `morning`/`night` |
| `createdBy`   | string?    | uid of the manager/admin who created it                    |
| `createdAt`, `updatedAt` | Timestamp | server timestamps; assign/remove use nested `arrayUnion`/`arrayRemove` |

> The roster is intentionally a nested map so an employee can appear on any mix
> of morning/night slots across the week. Branch/role access is enforced by
> `firestore.rules` (`weekly_schedules/{id}`): admin all · own-branch manager
> write · branch employees read.

### Firestore schema — `shift_swaps/{id}` (Phase 7)

| Field          | Type       | Notes                                                       |
| -------------- | ---------- | ---------------------------------------------------------- |
| `id`           | string     | mirrors the doc id (set on create)                         |
| `branchId`     | string     | branch the swap belongs to (= requester's branch)          |
| `weekStart`    | Timestamp  | week of the slot (addresses the schedule doc on approval)  |
| `day`          | string     | `sunday`…`saturday`                                        |
| `shift`        | string     | `morning` / `night`                                        |
| `requesterId`  | string     | employee giving up the slot                                |
| `requesterName`| string?    | denormalized for display                                   |
| `targetId`     | string     | coworker asked to take the slot                            |
| `targetName`   | string?    | denormalized for display                                   |
| `status`       | string     | `pending`→`employeeApproved`→`managerApproved` / `rejected`|
| `note`         | string?    | optional note from the requester                           |
| `createdAt`, `updatedAt` | Timestamp | server timestamps                              |

> Workflow: requester creates (`pending`) → target coworker approves
> (`employeeApproved`) → branch manager approves (`managerApproved`), which
> **removes the requester and adds the target** on that schedule slot. Any party
> may reject. Status order is validated client-side (`ShiftSwapCubit`); WHO may
> write is enforced by `firestore.rules` (`shift_swaps/{id}`).

### Storage schema

| Path                       | Content                            |
| -------------------------- | ---------------------------------- |
| `users/{uid}/avatar.jpg`   | profile image (overwrite-in-place) |
| `users/{uid}/cover.jpg`    | cover image (overwrite-in-place)   |
| `tasks/{taskId}/proof.jpg` | task proof image (overwrite-in-place, Phase 4) |

---

## Known gaps & follow-ups

- ⚠️ **Enable Firebase Storage** and **deploy** the committed
  `firestore.rules` / `storage.rules` before production.
- **Approval & user administration are now in-app (Phase 5)** — admins approve/
  reject users, (de)activate, change role/branch, assign managers to branches and
  move employees between branches from the admin module. The **first admin** must
  still be bootstrapped in the Firebase console (set `role: admin`,
  `approvalStatus: approved`, `isActive: true`), since every sign-up — including
  the founder's — is seeded `pending`/inactive.
- **Managers are promoted, not created** — there is no admin "create account"
  flow: client-side Firebase Auth account creation would sign the admin out, and
  there are no Cloud Functions (no Node.js). "Add Manager" promotes an existing
  approved employee to `role: manager`; new staff self-register, then an admin
  approves them (optionally directly as a manager).
- **Approval is admin-only (Phase 6)** — managers no longer approve or write user
  accounts (rules + UI); they manage branch operations (shifts/tasks) only.
- **Push notifications need a sender** — the FCM **client** foundation is in
  place (permission, `users/{uid}.fcmToken`, foreground snackbars), but actually
  **emitting** the events (task assigned, waiting review, new registration, …)
  requires a server trigger. With no Node.js/Cloud Functions in scope, a sender
  (Cloud Function or external) is the remaining piece. FCM also needs native
  setup: **APNs key + Push capability (iOS)**; Android works via `google-services`.
  `NotificationType` documents the event contract for whatever sends them.
- **Manager / Employee home dashboards** (`ManagerHomeScreen` /
  `EmployeeHomeScreen`) are still functional placeholders — their shifts/tasks
  live behind the Shifts/Tasks icons in the role chrome. The **Admin** shell is
  the full admin module (Phase 5).
- ~~Orphaned Phase 2 shift placeholders~~ **REMOVED (Phase 10).** The entire
  `shift` feature (`features/shift/`, the 3 placeholder screens + routes,
  `RouteNames.shiftsForRole`, `AppDependencies.shiftRepository`,
  `AppConstants.shiftsCollection`, and the `shifts/{shiftId}` rules) was deleted
  as verified dead code. The shift-visibility requirement is fully met by the
  Weekly Schedule (employee My Week · manager branch schedule · admin all branches).
- **Real-time: tasks (push) + everything else (reload-after-mutation).**
  **Tasks are now fully streamed** (`TaskRepository.watch*` → `TaskCubit`): an
  assigned task or status change appears on every open client immediately
  (cross-client push), backed by the offline cache. Pending-approval is also
  stream-driven. **Schedule / branch / admin / swap** lists still use
  **reload-after-mutation** (instant for the acting user) + pull-to-refresh;
  another user's open list reflects a change on next refresh. Converting those to
  streams too is a deliberate follow-up (out of this pass's scope). **(Phase 8)**
  approving a swap auto-refreshes the manager Schedule tab via a `BlocListener`.
- **Integration-audit findings.** (1) **Managers do not approve users** —
  approval is admin-only (Phase 6 design); any "manager approves employee"
  expectation is intentionally unsupported. (2) **Rejected users** land on the
  generic "Pending Approval" screen — access is correctly blocked, but the copy
  doesn't distinguish *rejected* from *pending*. (3) ~~Admin task creation uses a
  free-text branch field~~ **FIXED (Stabilization)** — admin now selects from a
  Firestore-backed branch dropdown, so a task's `branchId` always matches a real
  branch and the Assign picker is populated.
- **Shift-swap status flow is validated client-side** (`ShiftSwapCubit`), like the
  task transitions — `firestore.rules` enforce *who* may write a swap, not the
  exact order. Hardening the transition matrix server-side is a follow-up.
- **Task workflow is live** (Phase 4) but a few deliberate simplifications remain:
  - **Status transitions are validated client-side** (`TaskCubit._canTransition`),
    not in `firestore.rules` — the rules enforce *who* can write, not the exact
    flow order. Hardening the transition matrix server-side is a follow-up.
  - ~~Assignee uid → name isn't resolved on the card~~ **DONE (Phase 9)** — the
    `TaskCubit` resolves a per-branch user **directory** so cards show real
    avatars · names · roles (multi-assignee shown as an avatar stack + count).
  - `assignTask` writes the task side only — **`users/{uid}.assignedShift` is not
    auto-synced**, and there's no status automation. Storage proof write is
    loosely gated (see security rules).
  - **Notifications and analytics are intentionally out of scope.**
- **Account deletion** removes the Firebase Auth account but **not** the
  `users/{uid}` Firestore document — that cleanup belongs in a Cloud Function
  (`auth.user().onDelete`); see note in
  [auth_cubit.dart](lib/features/auth/presentation/cubit/auth_cubit.dart).
- **Light theme** exists in `AppTheme.light` but is **not wired up** — app is
  hardcoded to dark mode in [main.dart](lib/main.dart).
- **Legacy social fields** (`followersCount`/`followingCount`/`postsCount`/
  `likesCount` on `ProfileEntity`) are unused and should be removed in a future
  cleanup — FBRO is a role-based operations app, not a social network.

---

## Testing

- Only `test/widget_test.dart` exists and is an **empty placeholder**
  (`void main() {}`). No automated test coverage yet.
- **Manual QA:** [`QA_CHECKLIST.md`](QA_CHECKLIST.md) — an executable, on-device
  checklist covering the Employee / Manager / Admin workflows, real-time, offline,
  and UI/branding, with the deploy/Storage preconditions a tester must do first.

---

## Suggested next steps

1. Commit Phase 1 on `feature/roles-and-foundation`; open a PR into `main`.
2. Deploy `firestore.rules` / `storage.rules` and enable Storage.
3. Bootstrap the first admin (in the Firebase console set
   `role: admin`, `approvalStatus: approved`, `isActive: true`); then verify the
   register → Pending Approval → approve → role dispatch flow end to end.
4. Verify Phase 5 end to end: create a branch, approve a pending user as
   employee/manager, assign branches, and confirm the dashboard counts.
5. **Shift UI:** add a `ShiftCubit` + use cases on top of `ShiftRepository`
   (mirroring the now-built task feature), then the admin/manager shift
   management + assignment UI and the employee my-shift view; sync
   `users/{uid}.assignedShift` on assignment. Seed the two V1 shifts.
6. **Task workflow hardening:** enforce status transitions in `firestore.rules`,
   resolve assignee uid → name on cards, link tasks to shifts in the UI.
7. **Notifications sender:** add the server trigger that emits the
   `NotificationType` events to device tokens (Cloud Function or external) +
   native FCM setup (APNs key + Push capability on iOS).
8. **Stats optimization (if data grows):** move the dashboard counts to Firestore
   `count()` aggregate queries (with the needed composite indexes).
9. Add a Cloud Function to clean up the user document on account deletion.
10. Add widget/cubit tests, starting with `AuthCubit`, the approval gate, the
    `TaskCubit` transition rules, and the router redirect.
