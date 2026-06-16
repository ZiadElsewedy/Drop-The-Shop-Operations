# FBRO — Current State

> **Live status snapshot of the project.** Read this after
> [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) to know what's done, what's pending,
> and what needs configuring. This file answers "where are we right now?" —
> architecture/how-it-works lives in PROJECT_CONTEXT.md; history lives in
> [CHANGELOG.md](CHANGELOG.md).
>
> **Keep this current** — update it before finishing any task (see
> [Documentation Maintenance](PROJECT_CONTEXT.md#5-documentation-maintenance)).

**Last updated:** 2026-06-16
**Version:** 1.0.0+1 · **Branch:** `stabilization-and-optimization`

---

## Status at a glance

| Module           | Status        | Notes                                                          |
| ---------------- | ------------- | ------------------------------------------------------------- |
| Authentication   | ✅ Complete    | Email, phone OTP, Google, verify, forgot/change pw, delete; landing = **Login** (social Welcome page removed) |
| Account approval | ✅ Complete*   | New sign-ups seeded `pending` + inactive → **Pending Approval** screen; gate in router (`hasAppAccess`). *In-app approval UI (manager/admin) still pending — approve out of band (console) until Phase 5 |
| Roles & routing  | ✅ Complete    | `UserRole` enum, role dispatch + guards; **admin ⊇ manager** hierarchy + branch-scoped access model (admin global · manager own-branch · employee self) |
| Shifts (Phase 2) | 🟡 Foundation | `ShiftEntity`/`ShiftModel`/`ShiftRepository`/`ShiftRemoteDataSource` + `shifts/{shiftId}` rules. Data layer only; **superseded by the Weekly Schedule** (Phase 7) for production scheduling — placeholder shift screens no longer linked from the role chrome |
| Weekly Schedule (Phase 7) | ✅ Complete | `schedule` feature: `WeeklyScheduleEntity` + `ScheduleCubit` + manager editor / admin override / employee my-week view. Roster `day → morning/night → employees`; `weekly_schedules/{id}` rules. Reuses Role/Branch systems |
| Shift Swap (Phase 7) | ✅ Complete | `ShiftSwapEntity` + `ShiftSwapCubit`: employee requests → coworker approves → manager approves → schedule auto-updates; `shift_swaps/{id}` rules. Statuses pending/employeeApproved/managerApproved/rejected |
| Tasks (Phase 3–4, +Stabilization) | ✅ Workflow + realtime | Full vertical slice: `TaskCubit` + use cases, functional employee/manager/admin screens (create·assign·start·complete+notes/proof·submit·review approve/reject), client-side status-transition rules, audit fields, proof upload to Storage. **Stabilization:** task lists are now **live Firestore streams** (assigned task appears immediately); admin create uses a **branch dropdown** (no more free-text → no orphaned tasks) |
| Task Templates (Stabilization) | ✅ Complete | Reusable task blueprints ("Open Shop", "Night Checklist", …). `TaskTemplateEntity`/`Model` + template CRUD on the task repo/cubit; `task_templates/{id}` rules (admin global/any · manager own-branch). New Task → Blank vs. From a template (prefills the form) + Manage Templates sheet |
| Branches (Phase 5) | ✅ Complete   | `BranchEntity`/`Model`/`Repository`/`RemoteDataSource` + `BranchCubit`; admin CRUD + activate/deactivate + soft delete; `branches/{id}` rules |
| Admin module (Phase 5) | ✅ Complete | Branch / manager / employee management + **admin-only** pending-user approval + branch assignment. `AdminUsersCubit`, `UserAdminRepository` over `users/{uid}` |
| Dashboards / Statistics (Phase 6, +Phase 7) | ✅ Complete | `statistics` feature (`StatisticsCubit`) drives **live** admin / manager / employee dashboards. **Phase 7:** shift/coverage figures now read the weekly schedule (employee current+upcoming shift · manager scheduled/morning/night today · admin schedule coverage) |
| Notifications (Phase 6, +Phase 7) | 🟡 Foundation | FCM client foundation: permission + device-token persistence + foreground snackbars. `NotificationType` extended with Phase 7 swap/schedule events. **Sending** the events needs a server trigger (out of scope) |
| Profile          | ✅ Complete    | View/edit, avatar+cover upload, username checks                |
| Settings         | ✅ Complete    | Settings page + change password + delete account              |
| Role shells      | ✅ Live        | All three role dashboards show live operational stats (Phase 6); Admin shell hosts the full admin module (Phase 5) |
| Design system    | ✅ Complete    | Monochrome B&W, **dark-mode only**; branded **DROP** (`DropLogo` wordmark, FBRO removed) |
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
- **Phase 2 — Shift foundation** — new `shift` feature with full data + domain
  (`ShiftEntity`/`ShiftModel`/`ShiftRepository(+Impl)`/`ShiftRemoteDataSource(+Impl)`),
  `shifts/{shiftId}` Firestore rules (branch-scoped), three role placeholder
  screens (`/admin/shifts`, `/manager/shifts`, `/my-shift`) reachable via a
  Shifts icon in the role chrome, repo wired in DI. **No `ShiftCubit`/use cases
  or real CRUD UI yet** (intentionally minimal — next phase).
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
- **Action needed:** commit; deploy `firestore.rules` / `storage.rules` and
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
| adminSchedule       | `/admin/schedule`            | `ScheduleManagementScreen` | **admin**  |
| managerSchedule     | `/manager/schedule`          | `BranchScheduleScreen`  | **manager** (+admin) |
| mySchedule          | `/my-schedule`               | `MyScheduleScreen`      | any approved auth (self) |
| adminBranches       | `/admin/branches`            | `BranchManagementScreen`| **admin**     |
| adminManagers       | `/admin/managers`            | `ManagerManagementScreen`| **admin**    |
| adminEmployees      | `/admin/employees`           | `EmployeeManagementScreen`| **admin**   |
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

### Firestore schema — `shifts/{shiftId}` (Phase 2)

| Field        | Type       | Notes                                                       |
| ------------ | ---------- | ---------------------------------------------------------- |
| `id`         | string     | mirrors the doc id (set on create)                         |
| `name`       | string     | `morning` / `night` (free-form for future weekend/custom)  |
| `startTime`  | string     | e.g. `08:30` (morning) / `16:30` (night)                   |
| `endTime`    | string     | e.g. `16:30` (morning) / `23:00` (night)                   |
| `branchId`   | string?    | owning branch (admin: any · manager: own branch)           |
| `employeeId` | string?    | assigned employee uid; null while unassigned               |
| `isActive`   | bool       | soft-disable (default `true`)                              |
| `createdAt`, `updatedAt` | Timestamp | server timestamps written by the datasource     |

> V1 has two shifts — **Morning** (08:30→16:30) and **Night** (16:30→23:00/00:00).
> Times/`name` are strings so weekend & custom shifts add later with no schema
> change. Branch/role access is enforced by `firestore.rules` (`shifts/{shiftId}`).

### Firestore schema — `tasks/{taskId}` (Phase 3)

| Field                | Type       | Notes                                                  |
| -------------------- | ---------- | ----------------------------------------------------- |
| `id`                 | string     | mirrors the doc id (set on create)                    |
| `title`              | string     | task title                                            |
| `description`        | string?    | details                                               |
| `type`               | string     | `daily` / `special`                                   |
| `status`             | string     | `pending`→`started`→`completed`→`waitingReview`→`approved`/`rejected` |
| `priority`           | string     | `low` / `normal` / `high`                             |
| `branchId`           | string?    | owning branch (admin: any · manager: own branch)      |
| `assignedEmployeeId` | string?    | the employee executing the task; null while unassigned |
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
- **Orphaned Phase 2 shift placeholders (recommended cleanup).** The `shift`
  feature is now fully **dead code**: the 3 placeholder screens (`/admin/shifts`,
  `/manager/shifts`, `/my-shift`) are unreachable from the UI (the role-chrome
  calendar icon opens the weekly Schedule), `AppDependencies.shiftRepository` is
  registered but never consumed (stats moved to `weekly_schedules` in Phase 7),
  and `RouteNames.shiftsForRole` is unused. They still contain "arrives in a later
  phase" prototype text and are reachable by manual deep-link. **Left intact in the
  stabilization pass** (deleting a whole feature exceeds a minimal audit's scope);
  recommended for removal in a focused cleanup PR. The shift-visibility requirement
  is fully met by the Weekly Schedule (employee My Week · manager branch schedule ·
  admin all branches).
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
  - **Assignee picker** lists branch employees; resolving an assigned uid → name
    on the card isn't done (the card shows "assigned"/"unassigned").
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
