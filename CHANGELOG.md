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
