# FBRO — Project Context

> **Source of truth for the FBRO codebase.** Read this first, before opening any
> source file. It documents the architecture, dependency chains, where to make
> changes, and the conventions every contributor (human or AI) must follow.
>
> **Documentation set (treat as production source code, keep in sync):**
> - **[PROJECT_CONTEXT.md](PROJECT_CONTEXT.md)** (this file) — architecture, dependency maps, conventions.
> - **[CURRENT_STATE.md](CURRENT_STATE.md)** — live project status: what's done, pending, and what needs configuring.
> - **[CHANGELOG.md](CHANGELOG.md)** — chronological history of completed work.
>
> Keep all three current — see [Documentation Maintenance](#documentation-maintenance).

---

## 1. Overview

**FBRO** is a Flutter app built on Firebase for **role-based branch / shift
operations** (admin · manager · employee) — it is **not a social network**. It
currently ships a complete authentication system with an **account-approval
gate** (new sign-ups start *pending* and can't use the app until a
manager/admin approves them), a role system with role-based navigation + route
guards (Phase 1), a production-ready user profile module, account settings, a
**shift** foundation (Phase 2), and a **task management workflow** (Phase 3–4):
managers/admins create + assign tasks, employees execute them (start → complete
→ submit, with notes + proof image), and managers/admins review (approve /
reject). All dressed in a custom monochrome (black & white) design system.

> There is **no marketing / Welcome page** — FBRO is an internal tool, so the
> unauthenticated landing screen is **Login** (with Register one tap away).

> ⚠️ Some legacy social fields (follower / post counters) linger in the profile
> schema from an earlier iteration. They are **unused** and slated for removal —
> do not build on them.

### Tech stack

| Concern            | Choice                                                        |
| ------------------ | ------------------------------------------------------------ |
| State management   | `flutter_bloc` (Cubits only, no Blocs)                       |
| Navigation         | `go_router` (declarative, auth-aware redirects)             |
| Backend            | Firebase: Auth, Cloud Firestore, Storage, Google Sign-In    |
| Immutable models   | `freezed` + `freezed_annotation` (entities & states)        |
| Media              | `image_picker`                                              |
| Secure storage     | `flutter_secure_storage`                                    |
| Codegen            | `build_runner`, `freezed`, `json_serializable`             |
| Dart SDK           | `^3.12.1`                                                   |

### Architecture

The project follows **Clean Architecture** sliced by **feature**. Each feature
has three layers:

```
feature/
├── data/            # Firebase-facing implementation
│   ├── datasources/ # Talk to FirebaseAuth / Firestore / Storage; throw *Exception
│   ├── models/      # Serialization (toMap/fromMap, toEntity/fromEntity)
│   └── repositories/# Implement domain contracts; convert Exception → Failure
├── domain/          # Pure Dart, no Flutter/Firebase imports
│   ├── entities/    # freezed immutable business objects
│   ├── repositories/# Abstract contracts
│   └── usecases/    # One class per action, callable via .call()
└── presentation/    # UI
    ├── cubit/       # Cubit + freezed state
    ├── pages/       # Full screens (routed)
    ├── widgets/     # Feature-local widgets
    └── animations/  # Feature-local transitions
```

The dependency rule points **inward**: `presentation → domain ← data`. The
`domain` layer depends on nothing; `data` and `presentation` depend on `domain`.

### Directory map (`lib/`)

```
lib/
├── main.dart                 # Bootstraps Firebase, DI, router, MaterialApp.router
├── firebase_options.dart     # FlutterFire generated config
├── core/
│   ├── constants/            # app_constants.dart (appName, collection names)
│   ├── di/                   # injection.dart — AppDependencies service locator
│   ├── enums/                # user_role · approval_status · task_type · task_status · task_priority
│   ├── errors/               # exceptions.dart (data layer) / failures.dart (domain)
│   ├── routes/               # app_router.dart (role dispatch + guards), route_names.dart
│   ├── theme/                # app_colors / typography / spacing / radius / app_theme
│   └── widgets/              # app_snackbar, fbro_logo, skeleton, role_scaffold, role_placeholder
└── features/
    ├── auth/                 # Sign-in/up, phone OTP, Google, email verify, password, role, approval
    ├── profile/              # View + edit profile, image uploads, username checks
    ├── shift/                # Shift data/domain (entity·model·repository·datasource) + role shift screens (Phase 2)
    ├── task/                 # Task feature — data/domain + use cases + TaskCubit + functional role screens (Phase 3–4)
    ├── admin/                # AdminShell + AdminDashboardScreen (presentation only)
    ├── manager/              # ManagerShell + ManagerHomeScreen (presentation only)
    ├── employee/             # EmployeeShell + EmployeeHomeScreen (presentation only)
    └── settings/             # Settings + change password (presentation only)
```

> The role shells (`admin`/`manager`/`employee`) and `settings` are
> presentation-only — they reuse `auth`/`profile` cubits rather than owning
> their own data/domain layers. Each user is dispatched to exactly one role
> shell after login.
>
> The `task` feature (Phase 3–4) is the first fully-vertical operations feature:
> data + domain + **use cases + `TaskCubit`** + functional role screens (employee
> My Tasks, manager Branch Tasks, admin Task Management). The `shift` feature
> (Phase 2) still owns only data + domain (`ShiftEntity`/…/`ShiftRepository`) with
> **placeholder screens** — no `ShiftCubit` yet. Both repositories are wired in DI
> (`AppDependencies.shiftRepository` / `taskRepository`); `taskCubit` is also
> provided app-wide via `main.dart`.

---

## 2. File Dependency Map

The composition root is `main.dart` → `AppDependencies.init()`
([core/di/injection.dart](lib/core/di/injection.dart)), which wires every
datasource, repository, use case, and cubit by hand (no DI package). The two
app-wide cubits (`AuthCubit`, `ProfileCubit`) are provided at the root via
`MultiBlocProvider` in [main.dart](lib/main.dart).

### Authentication chain

```
LoginPage / RegisterPage / PhoneOtpPage                  (presentation/pages)
EmailVerificationPage / PendingApprovalPage
        ↓  context.read<AuthCubit>()
AuthCubit                                                (presentation/cubit)
        ↓  calls one use case per action
SignInWithEmail · RegisterWithEmail · SignInWithGoogle
VerifyPhoneNumber · SignInWithOtp · ForgotPassword
SendEmailVerification · CheckEmailVerified · ChangePassword
DeleteAccount · SaveUser · GetUser · SignOut             (domain/usecases)
        ↓  every use case wraps one AuthRepository method
AuthRepository (abstract)                                (domain/repositories)
        ↓
AuthRepositoryImpl                                       (data/repositories)
        ↓                          ↓
AuthRemoteDataSource          UserRemoteDataSource        (data/datasources)
  (FirebaseAuth, Google)        (Firestore users/{uid})
        ↓                          ↓
   FirebaseAuth               Cloud Firestore
```

- `AuthRepositoryImpl` holds **two** datasources: `AuthRemoteDataSource`
  (Firebase Auth + Google) and `UserRemoteDataSource` (the `users/{uid}`
  Firestore document). It maps `UserModel ⇄ UserEntity` at the boundary.
- Datasources throw `AuthException`; the repository catches and rethrows as
  `AuthFailure`; the cubit catches `AuthFailure` and emits `AuthState.error`.

### Routing & session chain

```
AuthCubit.stream
        ↓
_AuthStateNotifier (ChangeNotifier)   ← refreshListenable
        ↓
GoRouter.redirect                     ← auth guard + APPROVAL gate + ROLE guard
        ↓
splash → login/register/... → pending-approval → role shell  (/ employee · /admin · /manager)
```

`createRouter(AuthCubit)` ([core/routes/app_router.dart](lib/core/routes/app_router.dart))
re-evaluates its `redirect` whenever `AuthCubit` emits, routing unauthenticated
users to the auth flow (landing = **Login**), `awaitingEmailVerification` users
to the verification page, and authenticated users onward. Before role dispatch,
the redirect applies the **approval gate**: an authenticated user whose account
is not approved/active (`user.hasAppAccess == false`) is confined to the
**Pending Approval** screen (`/pending-approval`) — sign-out is the only way off
it. Approved users go to **their role shell** (`RouteNames.homeForRole(user.role)`
→ `/` employee, `/admin`, `/manager`). The redirect also **role-guards** every
navigation: admin areas are admin-only, manager areas admit manager + admin
(**admin ⊇ manager**), the employee home (`/`) is employee-only; anyone entering
an area that isn't theirs is bounced to their own home. `/profile` & `/settings`
are shared across roles. `SplashPage` calls `AuthCubit.restoreSession()` once on
cold start and dispatches by approval + role. Because Firebase sign-ins don't
know the role/approval, `AuthCubit` re-reads the Firestore user after
email/Google/OTP sign-in (and on `refreshUser()`, which the Pending Approval
screen polls) so the emitted `authenticated` state carries the authoritative
role/branch/approval.

### Profile chain

```
ProfilePage / EditProfilePage         (presentation/pages)
        ↓  context.read<ProfileCubit>()
ProfileCubit                          (presentation/cubit)
        ↓
GetProfile · UpdateProfile · UploadProfileImage
UploadCoverImage · CheckUsername      (domain/usecases)
        ↓
ProfileRepository (abstract)          (domain/repositories)
        ↓
ProfileRepositoryImpl                 (data/repositories)
        ↓                          ↓
ProfileRemoteDataSource         AuthRemoteDataSource (re-used)
  (Firestore + Storage)           (keeps Auth displayName/photoURL in sync)
        ↓                          ↓
Firestore users/{uid}          FirebaseAuth
+ Storage users/{uid}/avatar.jpg, cover.jpg
```

- `ProfileRepositoryImpl` also depends on `AuthRemoteDataSource` to mirror
  `fullName`/`profileImage` into the Firebase Auth profile (best-effort, never
  fatal) so Home/session stay current without re-login.
- The Firestore document at `users/{uid}` is **shared** between `auth`
  (`UserModel`) and `profile` (`ProfileModel`). `ProfileModel` is back-compat:
  it falls back to the legacy `displayName`/`photoUrl` keys, and `editMap`
  keeps those legacy keys in sync on write.

### Shift chain (Phase 2 — foundation only)

```
ShiftManagementScreen / BranchShiftScreen / MyShiftScreen   (presentation/pages)
  (functional placeholders — NO ShiftCubit/use cases yet)
                              ⋮  (next phase wires a ShiftCubit + use cases here)
ShiftRepository (abstract)                                   (domain/repositories)
        ↓   AppDependencies.shiftRepository  (composed in injection.dart)
ShiftRepositoryImpl                                          (data/repositories)
        ↓
ShiftRemoteDataSource                                        (data/datasources)
        ↓
Cloud Firestore  shifts/{shiftId}
```

- The shift **data + domain** layers are complete (`ShiftEntity`, `ShiftModel`,
  `ShiftRepository(+Impl)`, `ShiftRemoteDataSource(+Impl)`) and exposed via
  `AppDependencies.shiftRepository`. Datasources throw `ServerException`; the
  repository converts to `ServerFailure` and maps `ShiftModel → ShiftEntity`.
- **No presentation logic yet** — the three role screens are placeholders. The
  branch/role access model is enforced server-side in `firestore.rules`
  (`shifts/{shiftId}`): admin = all branches, manager = own branch, employee =
  their own assigned shift (read-only). The user's `assignedShift` (Phase 1)
  references the assigned `shiftId`; the shift's `employeeId` references back.

### Task chain (Phase 3–4 — full vertical slice)

```
MyTasksScreen (employee)                ManagerTasksView          (presentation/pages + widgets)
+ _CompleteSheet (notes+proof)          ← BranchTasksScreen (manager) / TaskManagementScreen (admin)
+ TaskCard / task_action_sheets (create·assign·review)
        ↓  context.read<TaskCubit>()      (provided app-wide in main.dart)
TaskCubit  + TaskState                                        (presentation/cubit)
        ↓  one use case per action
GetAllTasks · GetTasksByBranch · GetEmployeeTasks · CreateTask
UpdateTask · DeleteTask · AssignTask · ChangeTaskStatus
ReviewTask · UploadTaskProof            (domain/usecases)
GetUsersByBranch (auth use case — assignee picker)
        ↓
TaskRepository (abstract)                                    (domain/repositories)
        ↓   AppDependencies.taskRepository  (composed in injection.dart)
TaskRepositoryImpl                                           (data/repositories)
        ↓
TaskRemoteDataSource                                         (data/datasources)
        ↓                          ↓
Cloud Firestore  tasks/{taskId}    Firebase Storage  tasks/{taskId}/proof.jpg
```

- Full vertical slice: `TaskCubit` (app-wide, provided in `main.dart`) injects
  **one use case per action**; each wraps a `TaskRepository` method. Datasource
  throws `ServerException`; repo → `ServerFailure`; maps `TaskModel → TaskEntity`.
- **Core workflow:** a manager/admin creates + assigns a task (assignee picked
  from branch employees via the auth `GetUsersByBranch`); the employee drives it
  `pending → started → completed (+notes/proof) → waitingReview`; a manager/admin
  reviews → `approved` | `rejected` (writing the audit fields). `TaskType`
  (daily/special), `TaskStatus` and `TaskPriority` are enums in `core/enums`.
- **Status transitions are validated in `TaskCubit._canTransition`** (invalid
  moves are blocked client-side and surfaced as an error snackbar); WHO may write
  is enforced in `firestore.rules` (`tasks/{taskId}`): admin all branches,
  manager own branch, employee own assigned tasks with **limited writes** (may
  advance status / add notes / proof but may not reassign, change branch, or
  approve/reject). Proof images upload to Storage `tasks/{taskId}/proof.jpg`.
- The `TaskCubit` loads the list **by role** (admin: all · manager: own branch ·
  employee: own) and keeps it visible during mutations (`loaded(tasks, busy)`),
  re-emitting the previous list on error so the UI never flickers/loses data.

### Shared (core) dependencies

Every layer may import `core/errors` (failures/exceptions). Presentation
imports `core/theme`, `core/widgets`, `core/routes`. Data imports
`core/errors` and `core/constants`. `domain` imports only `core/errors`.

---

## 3. Modification Map

> **"When changing X, edit these files."** Use this to act without scanning.

| You want to change…                       | Edit here                                                                 |
| ----------------------------------------- | ------------------------------------------------------------------------ |
| **Auth screens / UI**                     | `lib/features/auth/presentation/pages/` + `.../widgets/`                  |
| **Auth logic / flow / state**             | `lib/features/auth/presentation/cubit/auth_cubit.dart` + `auth_state.dart` |
| **A new auth action**                     | add `domain/usecases/`, a method on `AuthRepository(+Impl)`, a datasource method, wire in `auth_cubit.dart` **and** `core/di/injection.dart` |
| **Firebase Auth / Google calls**          | `lib/features/auth/data/datasources/auth_remote_datasource.dart`         |
| **User Firestore document (auth side)**   | `lib/features/auth/data/datasources/user_remote_datasource.dart` + `data/models/user_model.dart` |
| **Profile screens / UI**                  | `lib/features/profile/presentation/pages/` + `.../widgets/`              |
| **Profile logic / state**                 | `lib/features/profile/presentation/cubit/profile_cubit.dart` + `profile_state.dart` |
| **Profile reads/writes / image uploads**  | `lib/features/profile/data/datasources/profile_remote_datasource.dart`   |
| **Profile schema / serialization**        | `lib/features/profile/domain/entities/profile_entity.dart` + `data/models/profile_model.dart` (then run codegen) |
| **Auth ⇄ Profile sync (name/avatar)**     | `lib/features/profile/data/repositories/profile_repository_impl.dart`    |
| **Shift schema / serialization**          | `lib/features/shift/domain/entities/shift_entity.dart` + `data/models/shift_model.dart` (then run codegen) |
| **Shift reads/writes (Firestore)**        | `lib/features/shift/data/datasources/shift_remote_datasource.dart`       |
| **Shift repository contract / impl**      | `lib/features/shift/domain/repositories/shift_repository.dart` + `data/repositories/shift_repository_impl.dart` (wired in `core/di/injection.dart`) |
| **Shift screens (admin/manager/employee)**| `lib/features/shift/presentation/pages/` (`shift_management_screen` · `branch_shift_screen` · `my_shift_screen`) |
| **Shift routes / role entry point**       | `lib/core/routes/route_names.dart` (`adminShifts`/`managerShifts`/`myShift` + `shiftsForRole`) + `app_router.dart` + `role_scaffold.dart` (Shifts icon) |
| **Task type/status/priority values**      | `lib/core/enums/task_type.dart` · `task_status.dart` · `task_priority.dart` |
| **Task schema / serialization (incl. audit fields)** | `lib/features/task/domain/entities/task_entity.dart` + `data/models/task_model.dart` (then run codegen) |
| **Task reads/writes / review / proof upload** | `lib/features/task/data/datasources/task_remote_datasource.dart` (Firestore + Storage `tasks/{id}/proof.jpg`) |
| **Task repository contract / impl**       | `lib/features/task/domain/repositories/task_repository.dart` + `data/repositories/task_repository_impl.dart` (wired in `core/di/injection.dart`) |
| **Task workflow logic / status transitions / state** | `lib/features/task/presentation/cubit/task_cubit.dart` (`_canTransition`) + `task_state.dart` |
| **A new task action**                     | add `domain/usecases/`, a `TaskRepository(+Impl)` method, a datasource method, wire in `task_cubit.dart` **and** `core/di/injection.dart` |
| **Task screens (admin/manager/employee)** | `lib/features/task/presentation/pages/` (`my_tasks_screen` employee · `branch_tasks_screen`/`task_management_screen` → shared `widgets/manager_tasks_view.dart`) |
| **Task UI actions (create/assign/review/complete) + card** | `lib/features/task/presentation/widgets/` (`task_action_sheets.dart`, `task_card.dart`, `task_empty_state.dart`) |
| **Assignee picker (branch employees)**    | `AuthRepository.getUsersByBranch` + `auth/domain/usecases/get_users_by_branch.dart` → `TaskCubit.branchEmployees` |
| **Task routes / role entry point**        | `lib/core/routes/route_names.dart` (`adminTasks`/`managerTasks`/`myTasks` + `tasksForRole`) + `app_router.dart` + `role_scaffold.dart` (Tasks icon) |
| **A role's home/dashboard screen**        | `lib/features/{employee,manager,admin}/presentation/pages/`              |
| **Shared role chrome / placeholder**      | `lib/core/widgets/role_scaffold.dart` · `role_placeholder.dart`         |
| **Roles enum / role values**              | `lib/core/enums/user_role.dart`                                         |
| **Approval status enum / values**         | `lib/core/enums/approval_status.dart` (pending/approved/rejected)        |
| **Role + approval on the user model / seeding** | `lib/features/auth/data/models/user_model.dart` + `data/datasources/user_remote_datasource.dart` (seed-once block: pending + inactive employee) |
| **Approval gate (pending → dashboard)**   | `lib/core/routes/app_router.dart` (redirect `hasAppAccess` check) + `UserEntity.hasAppAccess`/`isApproved` + `pending_approval_page.dart` + `AuthCubit.refreshUser` |
| **Role-based redirect / route guards**    | `lib/core/routes/app_router.dart` (redirect + `_isAdminArea`/`_isManagerArea`) + `RouteNames.homeForRole` |
| **Settings / change password UI**         | `lib/features/settings/presentation/pages/`                              |
| **Routes / navigation guards**            | `lib/core/routes/app_router.dart` + `route_names.dart`                    |
| **Firestore / Storage security rules**    | `firestore.rules` · `storage.rules` (registered in `firebase.json`)     |
| **Dependency injection / wiring**         | `lib/core/di/injection.dart`                                             |
| **Colors / typography / spacing / radius**| `lib/core/theme/app_colors.dart` · `app_typography.dart` · `app_spacing.dart` · `app_radius.dart` |
| **Global ThemeData (inputs, buttons…)**   | `lib/core/theme/app_theme.dart`                                          |
| **Cross-feature widgets (snackbar, logo, skeleton)** | `lib/core/widgets/`                                            |
| **Error / failure types**                 | `lib/core/errors/exceptions.dart` (data) · `failures.dart` (domain)      |
| **Constants (collection names, app name)**| `lib/core/constants/app_constants.dart`                                  |
| **App bootstrap / providers**             | `lib/main.dart`                                                          |
| **Firebase platform config**              | `lib/firebase_options.dart`, `firebase.json`, platform folders           |

---

## 4. Project Conventions

Patterns below are established across the codebase and **must be reused**.

### Folder & file conventions
- Feature-first: `features/<feature>/{data,domain,presentation}`.
- Three layers per feature; never let `domain` import Flutter or Firebase.
- Presentation-only features (`home`, `settings`) reuse other features' cubits.
- File names are `snake_case.dart`; one primary class per file.
- Generated files are `*.freezed.dart` / `*.g.dart` and live beside their source.

### Naming conventions
- Classes `PascalCase`; members/vars `camelCase`; constants `camelCase`.
- Datasources: `XRemoteDataSource` (abstract) + `XRemoteDataSourceImpl`.
- Repositories: `XRepository` (abstract) + `XRepositoryImpl`.
- Use cases: a **verb phrase** class (`SignInWithEmail`, `UploadCoverImage`).
- Cubits: `XCubit`; states: `XState`; pages: `XPage`; entities: `XEntity`.
- Private dependency fields are underscore-prefixed (`_repository`).

### Use case conventions
- One class = one action. Stateless, holds only its repository.
- `const` constructor taking the repository positionally.
- Exposes a single `call(...)` method (invoked as `useCase(...)`), delegating
  straight to the repository. Use named params when there's more than one.
  See [sign_in_with_email.dart](lib/features/auth/domain/usecases/sign_in_with_email.dart).

### Repository conventions
- Abstract contract in `domain/repositories`; impl in `data/repositories`.
- Impl depends on datasource(s) only — never on Firebase directly.
- Wrap every datasource call in `try/catch`, converting `*Exception` →
  `*Failure` (`AuthException` → `AuthFailure`).
- Convert `Model → Entity` (`model.toEntity()`) before returning; the rest of
  the app sees entities only.

### Datasource conventions
- Abstract + `Impl`; the `Impl` receives the Firebase SDK instance via
  constructor (injected in `injection.dart`).
- Catch `FirebaseException` and throw a domain-agnostic `*Exception` with a
  user-readable message.
- Firestore collection: `users/{uid}`. Storage paths: fixed
  `users/{uid}/avatar.jpg` and `users/{uid}/cover.jpg` (overwrite-in-place).

### Cubit conventions
- Extend `Cubit<XState>`; inject use cases (and the repository when stream
  access / non-action calls are needed) via a named-param constructor.
- Start in `XState.initial()`.
- Guard against concurrent/double submits with a `_busy` getter that inspects
  the current state (`if (_busy) return;`) — see `AuthCubit`.
- Emit a **loading** state, `await` the use case, then emit success or error.
- Carry an action discriminator on loading (`AuthState.loading(AuthAction.x)`)
  so the UI spins **only** the button that triggered the request.
- Catch `AuthFailure` → emit `XState.error(e.message)`; catch-all → emit a
  generic friendly message.
- For optimistic flows, keep the last-known entity visible across transient
  states (e.g. `ProfileState.saving(profile)`), and on error re-emit
  `loaded(previous)` so the UI never flickers or loses data.
- Cancel stream subscriptions in `close()`.

### State conventions
- States are `freezed` unions (`@freezed class XState with _$XState`).
- One factory per distinct UI state; success/transient states carry their data.
- Read state in the UI/router with `maybeWhen` / `mapOrNull` / `maybeMap`.
- After editing a state or entity, **run codegen** (see below).

### Entity / model conventions
- Entities are `freezed`, in `domain/entities`, with `@Default(...)` for
  non-null optionals. Add computed getters via a private `const X._()`
  constructor (see `ProfileEntity.displayName`).
- Models live in `data/models` and own all (de)serialization:
  `fromMap`/`toMap`, `fromEntity`/`toEntity`, `fromFirebaseUser`.
- Models bridge Firestore types (`Timestamp ⇄ DateTime`) and tolerate missing
  keys with defaults. Keep legacy keys in sync on write when schemas overlap.

### Widget conventions
- Cross-feature reusable widgets → `core/widgets`. Feature-local →
  `features/<f>/presentation/widgets`.
- Buttons use `AppButton` (variants: `primary` / `secondary` / `ghost`) with a
  built-in `isLoading` spinner — don't hand-roll buttons.
- User feedback uses `AppSnackbar.success/error`, never raw `ScaffoldMessenger`.
- Loading placeholders use `Skeleton`.
- Pull spacing/radius from `AppSpacing` / `AppRadius`; never hardcode.

### Theme conventions
- The app is **dark-mode only** today (`themeMode: ThemeMode.dark`); a `light`
  theme exists in `AppTheme` but is not wired up.
- **Strictly monochrome**: `AppColors.primary` is white; the only chromatic
  colors are the semantic `success` / `error` / `warning`, used for status only.
- Never use raw `Color(...)` or `TextStyle(...)` in features — reference
  `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`.
- Global component styling (inputs, buttons, app bar) lives in `AppTheme`; tune
  it there rather than per-widget.

### Roles & access model
- The access role is the `UserRole` enum (`core/enums/user_role.dart`), stored
  as a string in `users/{uid}.role`. Parse stored strings with
  `UserRole.fromString`, which **defaults unknown/missing to `employee`** so a
  bad document can never escalate privileges. Use the `isAdmin`/`isManager`/
  `isEmployee`/`isGlobal` getters rather than re-comparing enum values.
- **Access model (single source of truth, mirrored in `firestore.rules`):**
  - **admin** — *global*. Not restricted by `branchId`; can do everything a
    manager can, across every branch (**admin ⊇ manager**).
  - **manager** — belongs to exactly one branch; limited to data where
    `resource.branchId == manager.branchId`.
  - **employee** — limited to their own assigned data and profile.
- **Account approval (activation gate).** A new sign-up is **not** usable: it is
  seeded as a `pending` + `isActive: false` employee with no branch and is
  confined to the **Pending Approval** screen. A manager/admin approves it
  (`approvalStatus → approved`, `isActive → true`, assigns role + branch); only
  then does it reach a role shell. Gate logic = `UserEntity.hasAppAccess`
  (`isApproved && isActive`), checked in the router redirect **before** role
  dispatch. `ApprovalStatus.fromString` defaults missing → `approved` so legacy
  docs aren't locked out; **new** accounts are explicitly seeded `pending`.
  Managers approve employees of their **own branch** (and may claim pending
  newcomers into it); admins approve anyone — mirrored in `firestore.rules`. The
  **first admin** must be bootstrapped out of band (Firebase console).
- **Privileged fields** (`role`, `branchId`, `isActive`, `assignedShift`,
  `approvalStatus`) are seeded **once** in the `saveUser` first-creation block
  and are kept **out of `UserModel.toMap()`**, because `saveUser` merges on every
  login — including them would reset an admin's role / re-pend an approved
  account on the next sign-in. Self cannot change these (enforced by
  `firestore.rules`); an admin (or own-branch manager, for approval) may.
- **Enforcement** lives in `firestore.rules`: reusable `isAdmin()`/`isManager()`/
  `selfBranch()`/`canReachBranch(branch)` helpers read the requester's own user
  doc. **`shifts/{shiftId}` (Phase 2)** and **`tasks/{taskId}` (Phase 3)** are
  the branch-scoped collections wired to `canReachBranch()` (admin all · manager
  own-branch · employee own assigned data). Shifts are employee read-only; tasks
  additionally allow the **assigned employee a limited self-update** (advance
  status / add notes / proof, but not reassign, move branch, or approve/reject).
  Copy these as the pattern for future collections (branches); a commented
  template remains at the bottom of the rules file.
- Routes are role-guarded in the GoRouter `redirect`: admin areas are
  admin-only, manager areas admit **manager + admin** (the hierarchy), the
  employee home (`/`) is employee-only. Add a new role area as a path prefix
  with an `_isXArea` helper + a guard line, and extend `RouteNames.homeForRole`.
  Never gate role access in the UI only.
- New role-facing screens are presentation-only features
  (`features/<role>/presentation/pages/`) wrapped in a `RoleScaffold`; reuse
  `RolePlaceholder` for not-yet-built screens.

### Codegen
After editing any `freezed` file (`*_entity.dart`, `*_state.dart`):

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 5. Documentation Maintenance

**The three docs are part of the codebase and must never fall behind the code.**
Treat `PROJECT_CONTEXT.md`, `CURRENT_STATE.md`, and `CHANGELOG.md` as production
source, not notes. **Before finishing ANY task**, verify each is synchronized
and update any that is outdated — automatically, in the same task.

### Verification (run before marking a task complete)

1. **PROJECT_CONTEXT.md** matches the current architecture.
2. **CHANGELOG.md** contains the latest completed work.
3. **CURRENT_STATE.md** reflects the current project status.
4. If any document is outdated → update it. **Never leave docs behind the code.**

### Self-check — confirm each is documented

- [ ] Architecture documentation is correct.
- [ ] New **files** added to the [directory map](#directory-map-lib) and chains.
- [ ] New **routes** documented (here, `route_names.dart`, and `CURRENT_STATE.md`).
- [ ] New **cubits / states** documented in [File Dependency Map](#2-file-dependency-map).
- [ ] New **repositories** documented.
- [ ] New **use cases** documented.
- [ ] New **models / entities** documented (incl. Firestore/Storage schema in `CURRENT_STATE.md`).
- [ ] **Dependency injection** changes documented (`injection.dart` chain).
- [ ] **Firebase / Storage / Firestore schema** changes documented in `CURRENT_STATE.md`.
- [ ] [Architecture diagrams](#architecture) / [dependency maps](#2-file-dependency-map) updated if layers/flow/wiring changed.
- [ ] New/changed **conventions** noted in [Project Conventions](#4-project-conventions).
- [ ] **CHANGELOG.md** entry appended (added / removed / fixed / refactored).
- [ ] **CURRENT_STATE.md** updated (status, working tree, gaps, next steps).

### Documentation integrity

If the code and the docs disagree: **verify the code, then update the docs.**
Never ignore the mismatch — the documentation must always represent the latest
state of the project. The goal: a future task can be completed with **minimal
codebase scanning**.

---

## 6. AI Workflow

Future AI sessions should:

1. **Read all three docs first**, in order, and treat them as the source of
   truth: [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) →
   [CURRENT_STATE.md](CURRENT_STATE.md) → [CHANGELOG.md](CHANGELOG.md).
2. Use the [Modification Map](#3-modification-map) to find the exact files to
   touch — do **not** re-scan the whole project.
3. Read only the files related to the requested task.
4. Avoid re-analyzing the entire codebase unless absolutely necessary; trust the
   dependency chains here.
5. When adding a feature, follow it through **all** layers in order:
   datasource → repository (contract + impl) → use case → cubit/state → page,
   then wire it in [`injection.dart`](lib/core/di/injection.dart) and (if
   routed) [`app_router.dart`](lib/core/routes/app_router.dart) +
   `route_names.dart`.
6. Run codegen after touching any `freezed` file.
7. **Before finishing**, run the
   [Documentation Maintenance](#5-documentation-maintenance) verification +
   self-check and update all three docs as needed. Never leave docs behind the
   code.
