# FBRO — Current State

> **Live status snapshot of the project.** Read this after
> [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) to know what's done, what's pending,
> and what needs configuring. This file answers "where are we right now?" —
> architecture/how-it-works lives in PROJECT_CONTEXT.md; history lives in
> [CHANGELOG.md](CHANGELOG.md).
>
> **Keep this current** — update it before finishing any task (see
> [Documentation Maintenance](PROJECT_CONTEXT.md#5-documentation-maintenance)).

**Last updated:** 2026-06-14
**Version:** 1.0.0+1 · **Branch:** `feature/roles-and-foundation`

---

## Status at a glance

| Module           | Status        | Notes                                                          |
| ---------------- | ------------- | ------------------------------------------------------------- |
| Authentication   | ✅ Complete    | Email, phone OTP, Google, verify, forgot/change pw, delete; landing = **Login** (social Welcome page removed) |
| Account approval | ✅ Complete*   | New sign-ups seeded `pending` + inactive → **Pending Approval** screen; gate in router (`hasAppAccess`). *In-app approval UI (manager/admin) still pending — approve out of band (console) until Phase 5 |
| Roles & routing  | ✅ Complete    | `UserRole` enum, role dispatch + guards; **admin ⊇ manager** hierarchy + branch-scoped access model (admin global · manager own-branch · employee self) |
| Shifts (Phase 2) | 🟡 Foundation | `ShiftEntity`/`ShiftModel`/`ShiftRepository`/`ShiftRemoteDataSource` + `shifts/{shiftId}` rules + 3 role placeholder screens. **No `ShiftCubit`/use cases or real UI yet** — data layer ready, wired in DI |
| Tasks (Phase 3–4) | ✅ Workflow   | Full vertical slice: `TaskCubit` + 10 use cases, functional employee/manager/admin screens (create·assign·start·complete+notes/proof·submit·review approve/reject), client-side status-transition rules, audit fields, proof upload to Storage |
| Branches (Phase 5) | ✅ Complete   | `BranchEntity`/`Model`/`Repository`/`RemoteDataSource` + `BranchCubit`; admin CRUD + activate/deactivate + soft delete; `branches/{id}` rules |
| Admin module (Phase 5) | ✅ Complete | Admin dashboard (reports overview) + branch / manager / employee management + in-app pending-user approval + branch assignment. `AdminUsersCubit` + `AdminStatsCubit`, `UserAdminRepository` over `users/{uid}` |
| Profile          | ✅ Complete    | View/edit, avatar+cover upload, username checks                |
| Settings         | ✅ Complete    | Settings page + change password + delete account              |
| Role shells      | 🟡 Partial    | **Admin** shell is now the full admin module (Phase 5); Employee / Manager home dashboards are still functional placeholders |
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
  (`/pending-approval`) until a manager/admin approves them (`hasAppAccess`
  gate in the router). New `ApprovalStatus` enum + `approvalStatus` user field +
  `AuthCubit.refreshUser` (polled by the pending screen). `firestore.rules`
  updated for pending self-registration + manager/admin approval.
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
  (`UserAdminRepository` over `users/{uid}`, `AdminUsersCubit` + `AdminStatsCubit`):
  admin dashboard with a **reports overview** (branches/managers/employees/
  pending/active+completed tasks) and management screens for **branches,
  managers, employees, and pending approvals** (`/admin/branches|managers|
  employees|approvals`). Admin can approve/reject users, (de)activate, change
  role/branch, assign managers to branches, and move employees between branches.
  `branches/{branchId}` Firestore rules added. **Managers are promoted from
  existing approved users** (no client-side Auth account creation — no Cloud
  Functions). admin/branch cubits call repositories directly (no use-case layer).
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
- **Cloud Firestore** — in use (`users/{uid}`).
- **Firebase Storage** — code uploads to `users/{uid}/avatar.jpg` &
  `cover.jpg`. ⚠️ **Storage must be enabled** in the Firebase console for
  uploads to work in production.
- **Security rules** — ✅ **In the repo:** [`firestore.rules`](firestore.rules)
  and [`storage.rules`](storage.rules), wired into [`firebase.json`](firebase.json).
  Firestore rules encode the role/branch + **approval** access model: **self
  registration** is allowed only as a `pending`, **inactive** employee;
  **admin** reads/writes any user (approve/reject, promotions, branch moves,
  (de)activation); **manager** reads users in their **own branch** + any pending
  newcomer and may approve/manage employees into their own branch (never elevate
  role or assign another branch); **employee** reads/edits only their own doc and
  may **not** change the privileged fields (`role`, `branchId`, `isActive`,
  `assignedShift`, `approvalStatus`). **`shifts/{shiftId}` (Phase 2)** is the
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
  existing `users` admin-update rule. Reusable `isAdmin()` / `isManager()` /
  `canReachBranch()` helpers remain for future collections. ⚠️ Still need to be
  **deployed** (`firebase deploy --only firestore:rules,storage`).

### Firestore schema — `users/{uid}`

Shared by the auth (`UserModel`) and profile (`ProfileModel`) layers.

| Field                                                   | Type      | Notes                          |
| ------------------------------------------------------ | --------- | ------------------------------ |
| `uid`, `email`, `authProvider`                         | string    | core identity                  |
| `role`                                                 | string    | **Phase 1** — `admin` (global) / `manager` (one branch) / `employee` (own data); seeded `employee` once, role-guarded |
| `branchId`                                             | string?   | **Phase 1** — owning branch. **admin:** null/ignored (global); **manager:** their one branch; **employee:** their branch. Assigned by an admin. |
| `assignedShift`                                        | string?   | **Phase 1/2** — references the assigned `shifts/{shiftId}`; null until a manager assigns one |
| `isActive`                                             | bool      | **Phase 1** — activation/soft-disable. **New sign-ups seeded `false`** (pending approval); set `true` on approval |
| `approvalStatus`                                       | string    | **Approval** — `pending` / `approved` / `rejected`. New sign-ups seeded `pending`; missing → treated as `approved` (legacy). Flipped by admin/own-branch manager |
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
- **In-app manager-side approval has no dedicated screen yet** — the rules allow
  own-branch managers to approve their pending newcomers, but the approval UI
  lives in the admin module. A manager-facing approval screen is a follow-up.
- **Manager / Employee home dashboards** (`ManagerHomeScreen` /
  `EmployeeHomeScreen`) are still functional placeholders — their shifts/tasks
  live behind the Shifts/Tasks icons in the role chrome. The **Admin** shell is
  the full admin module (Phase 5).
- **Shift UI is a placeholder** — the `shift` data/domain layer + Firestore rules
  are done and DI-wired (`AppDependencies.shiftRepository`), but there is **no
  `ShiftCubit`/use cases** and the three shift screens don't read/write yet. The
  real CRUD/assignment UI (admin) + branch scheduling (manager) + my-shift view
  (employee) is the next phase. The `assignEmployee` foundation updates the shift
  side only; syncing `users/{uid}.assignedShift` lands with the assignment UI.
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
  (`void main() {}`). No real test coverage yet.

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
7. Add a Cloud Function to clean up the user document on account deletion.
8. Add widget/cubit tests, starting with `AuthCubit`, the approval gate, the
   `TaskCubit` transition rules, and the router redirect.
