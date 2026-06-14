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
| Profile          | ✅ Complete    | View/edit, avatar+cover upload, username checks                |
| Settings         | ✅ Complete    | Settings page + change password + delete account              |
| Role shells      | 🟡 Scaffolded | Employee / Manager / Admin shells + screens (functional placeholders) |
| Design system    | ✅ Complete    | Monochrome B&W, **dark-mode only**                            |
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
  `assignedShift`, `approvalStatus`). Reusable `isAdmin()` / `isManager()` /
  `canReachBranch()` helpers + a commented template are ready for the Phase 2+
  branch-scoped collections. ⚠️ Still need to be **deployed** (`firebase deploy
  --only firestore:rules,storage`).

### Firestore schema — `users/{uid}`

Shared by the auth (`UserModel`) and profile (`ProfileModel`) layers.

| Field                                                   | Type      | Notes                          |
| ------------------------------------------------------ | --------- | ------------------------------ |
| `uid`, `email`, `authProvider`                         | string    | core identity                  |
| `role`                                                 | string    | **Phase 1** — `admin` (global) / `manager` (one branch) / `employee` (own data); seeded `employee` once, role-guarded |
| `branchId`                                             | string?   | **Phase 1** — owning branch. **admin:** null/ignored (global); **manager:** their one branch; **employee:** their branch. Assigned by an admin. |
| `assignedShift`                                        | string?   | **Phase 1** — shift; null until assigned (Phase 2) |
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

### Storage schema

| Path                      | Content                            |
| ------------------------- | ---------------------------------- |
| `users/{uid}/avatar.jpg`  | profile image (overwrite-in-place) |
| `users/{uid}/cover.jpg`   | cover image (overwrite-in-place)   |

---

## Known gaps & follow-ups

- ⚠️ **Enable Firebase Storage** and **deploy** the committed
  `firestore.rules` / `storage.rules` before production.
- **Approval & role promotion are not yet in-app** — a manager/admin approves a
  user (sets `approvalStatus: approved`, `isActive: true`, assigns `branchId` /
  `role`) by editing `users/{uid}` in the Firebase console / Admin SDK (the
  client rules already permit admin + own-branch manager approval, but there is
  **no approval UI yet**). The **first admin** must be bootstrapped this way too,
  since every sign-up — including the founder's — is seeded `pending`/inactive.
  An in-app admin/manager approval console arrives in Phase 5.
- **Role shells** (`AdminShell` / `ManagerShell` / `EmployeeShell`) are
  functional placeholders — real content lands in Phase 3 (manager/employee)
  and Phase 5 (admin).
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
4. **Phase 5 (bring forward?)** — in-app approval console so managers/admins can
   approve pending users from the app instead of the Firebase console.
5. **Phase 2** — Shifts (uses `assignedShift` / `branchId`).
6. Add a Cloud Function to clean up the user document on account deletion.
7. Add widget/cubit tests, starting with `AuthCubit`, the approval gate, and the
   router redirect.
