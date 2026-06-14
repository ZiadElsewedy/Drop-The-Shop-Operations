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
| Authentication   | ✅ Complete    | Email, phone OTP, Google, verify, forgot/change pw, delete     |
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
- **Action needed:** commit Phase 1; deploy `firestore.rules` / `storage.rules`
  and enable Firebase Storage before production.

---

## Routes (all implemented)

| Name                | Path                         | Page                    | Access        |
| ------------------- | ---------------------------- | ----------------------- | ------------- |
| splash              | `/splash`                    | `SplashPage`            | public        |
| welcome             | `/welcome`                   | `WelcomePage`           | unauth        |
| home                | `/`                          | `EmployeeShell`         | **employee**  |
| adminDashboard      | `/admin`                     | `AdminShell`            | **admin**     |
| managerHome         | `/manager`                   | `ManagerShell`          | **manager**   |
| login               | `/login`                     | `LoginPage`             | unauth        |
| register            | `/register`                  | `RegisterPage`          | unauth        |
| phone               | `/phone`                     | `PhoneOtpPage`          | unauth        |
| forgotPassword      | `/forgot-password`           | `ForgotPasswordPage`    | unauth        |
| emailVerification   | `/email-verification`        | `EmailVerificationPage` | awaiting verif|
| profile             | `/profile`                   | `ProfilePage`           | any auth      |
| editProfile         | `/profile/edit`              | `EditProfilePage`       | any auth      |
| settings            | `/settings`                  | `SettingsPage`          | any auth      |
| changePassword      | `/settings/change-password`  | `ChangePasswordPage`    | any auth      |

Defined in [route_names.dart](lib/core/routes/route_names.dart) /
[app_router.dart](lib/core/routes/app_router.dart). Navigation is auth-guarded
**and role-guarded**: after login each user is dispatched to their role shell
(`RouteNames.homeForRole`), and attempts to enter another role's area (incl.
manual URL hacking) are bounced back to their own home. `/profile` & `/settings`
are shared across all roles.

---

## Backend / Firebase status

- **Firebase Auth** — configured & working: Email/Password, Phone, Google.
- **Cloud Firestore** — in use (`users/{uid}`).
- **Firebase Storage** — code uploads to `users/{uid}/avatar.jpg` &
  `cover.jpg`. ⚠️ **Storage must be enabled** in the Firebase console for
  uploads to work in production.
- **Security rules** — ✅ **In the repo:** [`firestore.rules`](firestore.rules)
  and [`storage.rules`](storage.rules), wired into [`firebase.json`](firebase.json).
  Firestore rules encode the role/branch **access model**: **admin** reads/writes
  any user (promotions, branch moves, (de)activation); **manager** reads users in
  their **own branch**; **employee** reads/edits only their own doc and may **not**
  change the privileged role fields (`role`, `branchId`, `isActive`,
  `assignedShift`). Reusable `isAdmin()` / `isManager()` / `canReachBranch()`
  helpers + a commented template are ready for the Phase 2+ branch-scoped
  collections. ⚠️ Still need to be **deployed** (`firebase deploy --only
  firestore:rules,storage`).

### Firestore schema — `users/{uid}`

Shared by the auth (`UserModel`) and profile (`ProfileModel`) layers.

| Field                                                   | Type      | Notes                          |
| ------------------------------------------------------ | --------- | ------------------------------ |
| `uid`, `email`, `authProvider`                         | string    | core identity                  |
| `role`                                                 | string    | **Phase 1** — `admin` (global) / `manager` (one branch) / `employee` (own data); seeded `employee` once, role-guarded |
| `branchId`                                             | string?   | **Phase 1** — owning branch. **admin:** null/ignored (global); **manager:** their one branch; **employee:** their branch. Assigned by an admin. |
| `assignedShift`                                        | string?   | **Phase 1** — shift; null until assigned (Phase 2) |
| `isActive`                                             | bool      | **Phase 1** — soft-disable (default `true`) |
| `displayName`, `photoUrl`                              | string    | **legacy** auth keys, kept in sync |
| `fullName`, `username`, `profileImage`, `coverImage`   | string    | profile identity               |
| `phoneNumber`, `bio`, `gender`, `country`, `city`, `website` | string?  | personal                       |
| `birthDate`, `createdAt`, `updatedAt`, `lastSeen`      | Timestamp | dates                          |
| `isEmailVerified`, `isVerified`, `isOnline`            | bool      | status/presence                |
| `isProfilePublic`, `allowMessages`, `allowNotifications` | bool    | privacy (default true)         |
| `accountStatus`                                        | string    | default `active`               |
| `followersCount`, `followingCount`, `postsCount`, `likesCount` | int | **legacy/unused** — FBRO is not a social app |

> **Role-field seeding:** `role`/`branchId`/`isActive`/`assignedShift` are
> seeded **once** on first document creation and are deliberately excluded from
> `UserModel.toMap()`, so a routine re-login (which merges) can never reset an
> admin-assigned role/branch.

### Storage schema

| Path                      | Content                            |
| ------------------------- | ---------------------------------- |
| `users/{uid}/avatar.jpg`  | profile image (overwrite-in-place) |
| `users/{uid}/cover.jpg`   | cover image (overwrite-in-place)   |

---

## Known gaps & follow-ups

- ⚠️ **Enable Firebase Storage** and **deploy** the committed
  `firestore.rules` / `storage.rules` before production.
- **Role promotion** is not yet in-app — an admin promotes a user by editing
  `users/{uid}.role` in the Firebase console / Admin SDK (the client rules
  forbid self-elevation). An in-app admin console arrives in Phase 5.
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
3. Seed a test admin/manager (set `role` in the Firebase console) and verify
   role-based dispatch + guards end to end.
4. **Phase 2** — Shifts (uses `assignedShift` / `branchId`).
5. Add a Cloud Function to clean up the user document on account deletion.
6. Add widget/cubit tests, starting with `AuthCubit` and the router redirect.
