# DROP — Project Context

> **Source of truth for the DROP codebase** (product name **DROP — Operations
> Management System**; the Dart package identifier stays `fbro` for build
> stability — only the brand is DROP). Read this first, before opening any
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
ships an **admin-provisioned** authentication system (2026-06-26 redesign): **no
public registration** — only an admin creates accounts (via the secure
`createUserAccount` Cloud Function), and every new account is forced through a
**first-login flow** (change the admin-issued temp password → complete profile →
home). The auth surface is **Splash · Login · Forgot Password · Force Password
Change · Profile Completion** (registration / OTP / Google / email-verification /
pending-approval were all removed). Plus a role system with role-based navigation
+ route guards (Phase 1), a production-ready user profile module, account
settings, a
**full operations task workflow** (Phase 3–4 + Stabilization + Phase 9 + Workflow
Upgrade): managers/admins create + assign tasks (with optional checklist,
recurrence, and branch picker); employees execute them (start → complete with
checklist + notes + proof image → submit); managers/admins review (approve / reject),
with approval auto-spawning the next recurring instance; every status transition
is recorded in an embedded **activity timeline**; full-screen **Task Details**
accessible by all roles; an **admin management module** (Phase 5): branch CRUD,
manager / employee management, **admin-only account provisioning** (Create
Account → the `createUserAccount` Cloud Function) + reset, and branch
assignment; **operational dashboards + a Firebase Cloud Messaging foundation**
(Phase 6): live role-scoped statistics (admin / manager / employee) and device-token
registration for push; and a **weekly schedule + shift-swap system** (Phase 7):
managers build their branch's weekly roster (Day → Morning / Night → Employees),
employees view their week / today's team / manager and request shift swaps
(coworker approves → manager approves → schedule updates automatically), and
admins override any branch. All dressed in the **DROP THE SHOP** design system —
a **strictly monochrome** black / white / grey dark UI (the white `AppColors.primary`
is the only accent; no chromatic brand color), with a **bottom navigation bar** as
the role chrome.

> **DROP THE SHOP operations system** — focused on daily store operations
> (branches · shifts · tasks · employee activity · approvals). It is **not** a
> social app, ERP, or analytics engine.

> There is **no marketing / Welcome page** and **no registration** — FBRO is an
> internal, admin-provisioned tool, so the unauthenticated landing screen is
> **Login** only (accounts are created by an admin).

> ⚠️ Some legacy social fields (follower / post counters) linger in the profile
> schema from an earlier iteration. They are **unused** and slated for removal —
> do not build on them.

### Tech stack

| Concern            | Choice                                                        |
| ------------------ | ------------------------------------------------------------ |
| State management   | `flutter_bloc` (Cubits only, no Blocs)                       |
| Navigation         | `go_router` (declarative, auth-aware redirects)             |
| Backend            | Firebase: Auth, Cloud Firestore, Storage, Google Sign-In    |
| Push / server      | Firebase Cloud Messaging (`firebase_messaging`) + **Cloud Functions** (Node.js, `functions/`) called via `cloud_functions` — the Communications Center send engine |
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
│   ├── enums/                # user_role · approval_status · task_* · recurrence_frequency · notification_type · schedule_day · schedule_shift · swap_status · broadcast_audience · broadcast_category · broadcast_recurrence
│   ├── extensions/           # context_extensions (currentUser/currentRole) · firestore_extensions (Map.date — Timestamp→DateTime)
│   ├── services/             # notification_service.dart (FCM foundation, Phase 6)
│   ├── errors/               # exceptions.dart (data layer) / failures.dart (domain)
│   ├── routes/               # app_router.dart (role dispatch + guards), route_names.dart
│   ├── theme/                # app_colors / typography / spacing / radius / app_theme
│   └── widgets/              # app_snackbar, app_dialog (showConfirmDialog), app_card, app_empty_state, status_badge (+`.task` = the task-status chip; `taskStatusColor` = the single status→colour source), drop_logo, skeleton, list_skeleton, role_scaffold (bottom-nav chrome), app_bottom_nav (AppBottomNav + AppNavItem), user_avatar (+AvatarStack), app_motion (EntranceFade), animated_count (AnimatedCount — the single reusable animated counter: count-up on appear, tween on change; used by dashboard metrics/hero + review counts), live_list_item (LiveListItem — keyed realtime-list item: enters once + optional new-arrival highlight, preserves scroll, no AnimatedList/diff), app_search_field, glass_container (GlassContainer — the shared premium surface, now with an optional semantic `glow`), dashboard_metric_card (DashboardMetricCard), action_card (ActionCard), admin_section_header (AdminSectionHeader), timeline_tile (TimelineTile) · **Premium component system (Slice 2):** app_glass_card (AppGlassCard — premium card mapping task status → subtle glow; thin wrapper over GlassContainer), metric_pill (MetricPill — compact `[icon] value · label`), premium_button (PremiumButton — canonical compact inline action button, distinct from the 56px form AppButton), branch_avatar (BranchAvatar — branch logo · else initials · else store glyph, §8) · **Brand primitives (§9a):** drop_wordmark (DropWordmark — typographic DROP logotype, complements the PNG DropLogo), drop_empty_state (DropEmptyState — brand-led empty state), drop_loading_state (DropLoadingState — pulsing-logo loader) · **§9b rollout helpers:** drop_auth_mark (DropAuthMark — auth lockup: DropLogo + "DROP Operations System" tagline; on login/register), brand_watermark (BrandWatermark — clipped ≤0.05-opacity corner wordmark for hero cards; on Admin Home hero). Rolled out: DropEmptyState → task/notification/branch empties; DropLoadingState → schedule full-page loaders
└── features/
    ├── auth/                 # Admin-provisioned: email sign-in, forgot/force password change, profile completion, role (no signup/OTP/Google/approval)
    ├── profile/              # View + edit profile, image uploads, username checks
    ├── task/                 # Task feature — data/domain + use cases + TaskCubit + functional role screens (Phase 3–4); realtime streams + templates (Stabilization); Phase 9 — multi-assignee + checklist + redesigned cards; Workflow Upgrade — RecurrenceConfig + ActivityEntry + TaskDetailsScreen + MyTasksScreen redesign; presentation/activity_format.dart (shared timeline label/colour/time helpers); Premium task UX slice (2026-06-25) — admin/manager reference images (`TaskEntity.referenceAttachments`, reused `AttachmentPickerField`) + a redesigned, **de-flashed** signal-driven `TaskCard` (flat `TaskSurface` primitive — no glow/gradient/pulse; status pill · High-only priority · branch/due/refs chips · thin checklist bar)
    ├── branch/               # Branch feature — data/domain + BranchCubit + branch management (Phase 5)
    ├── admin/                # Admin module — user-admin data/domain + AdminUsersCubit + dashboard/managers/employees/approvals (Phase 5). Admin redesign (2026-06-19): command-center Home (greeting · hero · metric grid · quick actions · pending preview · activity feed · manage), EmployeeCard + employee_metrics (computeEmployeeMetrics — per-employee perf from the task stream)
    ├── statistics/           # Statistics feature — entity/model/repo/datasource + StatisticsCubit; powers all 3 dashboards (Phase 6, +Phase 7 schedule figures)
    ├── schedule/             # Weekly schedule + shift swaps (Phase 7) — full slice + ScheduleCubit & ShiftSwapCubit; weekly_schedules + shift_swaps
    ├── operations/           # Branch Operations cockpit (task-centric → operations-centric redesign, 2026-06-21). domain: `ShiftFilter` · `EmployeeWorkload` · `BranchSummary` · `computeBranchWorkload` (joins the branch task stream × getUsersByBranch × today's weekly_schedule, overload-first). presentation: `BranchOperationsCubit` (read/derive — repo-direct; writes still via TaskCubit) + `BranchOperationsState`; pages `BranchOperationsScreen` (the cockpit: summary header · shift toggle · workload cards · FAB), `ManagerOperationsScreen` (manager's own branch), `EmployeeDetailScreen` (drill — tasks by status); widget `WorkloadCard`
    ├── communications/       # Communications Center (Phase 1 slice + Phase 2 engine + Phase 3 UI + **Premium Upgrade Phase 2 Commit 1**, 2026-06-22) — Broadcast slice: data/domain (`BroadcastEntity`/`BroadcastModel`/`BroadcastRepository(+Impl)`/`BroadcastRemoteDataSource`) + `SendBroadcast` use case + `BroadcastCubit` (+ `branches()`/`branchUsers()` pickers + lifecycle `setArchived`/`setDeleted`/`repeatNow`) + `domain/broadcast_permissions.dart`. Send via the callable `sendBroadcast` Cloud Function (now a reusable `dispatchBroadcast()`); audiences allBranches/branch/**user (DM)**. **Premium Upgrade Commit 1:** broadcast schema gains `priority`/`channel`/`openedCount`/`archivedAt`/`deletedAt` (new `broadcast_priority`/`broadcast_channel` enums); the feed is **history** (Active/Archived/Deleted + per-item actions) with delivery-analytics detail; archive/soft-delete are **field-restricted client writes**. UI: `communications_screen` (history feed) · `compose_broadcast_screen` (role-gated, `prefill` for Duplicate) · `broadcast_detail_screen` (analytics + actions) + `widgets/broadcast_card.dart` + `communications_format.dart`; route `/communications` (admin + manager). **Premium Upgrade Commit 2:** **templates** — `broadcastTemplates` slice (`BroadcastTemplateEntity`/`Model`/`Repository(+Impl)`/`RemoteDataSource`) + repo-direct `BroadcastTemplateCubit`, pure `domain/template_renderer.dart` (`{{placeholders}}`), library `broadcast_templates_screen` (+ `widgets/template_card.dart`) at `/communications/templates`, and a premium composer (priority/channel selectors · char counters · live preview · use/save template). **Commit 3 (audiences):** `BroadcastAudience.custom` (multi-recipient, `__custom__` marker + `targetUserIds`) + a `roleFilter`, threaded as send-time intents through `SendBroadcast`/repo/datasource/`send` → the callable (no entity change); composer multi-select People picker + Select-all + role filter; `dispatchBroadcast` resolves custom/role, `broadcasts` read rule adds `uid in targetUserIds`. **Commit 4 (scheduler):** `broadcastSchedules` slice (`BroadcastScheduleEntity` — plain immutable / `Model` / repo / datasource + freezed `BroadcastScheduleState` + repo-direct `BroadcastScheduleCubit`), pure `recurrence_rule.dart` + `broadcast_recurrence` enum; `broadcast_schedules_screen` at `/communications/schedules` + composer Schedule sheet; functions `runBroadcastSchedules` (onSchedule poller — the chosen architecture) + `broadcastHousekeeping` (retention). **Commit 5 (reminders):** `NotificationType` + `taskReminder`/`taskOverdue`; pure `reminder_rules.dart` (in `features/task/domain`); functions `runTaskReminders` (onSchedule, anti-spam ledger `taskReminders/{taskId}` + quiet hours) + `reminderConfig`. **Commit 6 (analytics) — REMOVED 2026-06-23 (Decision A):** the analytics pipeline was vanity (open/read rate, monthly rollups, charts drove no admin decision) and was deleted — `onNotificationRead`/`onBroadcastOpened` functions, `bumpAnalytics`, `analytics/{YYYY-MM}` rollups, `broadcastOpens`, `openedCount`, `BroadcastCubit.trackOpen`, the `comms_analytics` slice, and `communications_analytics_screen`. **Kept:** minimal delivery diagnostics on `broadcast_detail_screen` (recipients · delivered · failed). _The Premium Upgrade's history/templates/audiences/scheduler/reminders remain; analytics was rolled back as over-engineering per the lean philosophy._ **§5 Notification operational inbox (2026-06-25):** the Notification Center was rebuilt from the lean feed into an **operations workflow inbox** (reversing the 2026-06-24 lean simplification, owner-directed). Pure `notification_format.dart` now owns: **`NotificationPriority`** (critical/high/normal/low · `notificationPriority`), **`NotificationCategory`** filter pills (All/Tasks/Reviews/Broadcast · `categoryOf`), and **`groupByTime`** (Today/Yesterday/Earlier, priority-first within each). The screen adds swipe (right=mark-read · left=archive, delete in the **Archived view**), bulk **Mark-all-read** + **Clear-archived** (`NotificationCubit.clearArchived`), verified deep-links, and subtle motion/haptics; `NotificationTile` gives a critical notification a stronger unread dot. **Kept single `readAt` (= isRead); `isSeen` not added** (lean — too invasive for a small inbox). **Schedule/System categories omitted** — no producer (trimmed types). The earlier lean note follows for history: **Lean simplification (2026-06-24, slices 1–4):** Notification Center → an All/Unread action-inbox with exact-task deep-link (`/task/:taskId`); broadcast **soft-delete + Deleted view removed** (a broadcast is active|archived only) and nav collapsed to **feed + FAB + "···" overflow** (Scheduled/Templates/Archived); **categories merged 4→3** (dropped Alert); **Priority + Delivery-channel selectors and the `BroadcastPriority`/`BroadcastChannel` enums removed** — delivery is **derived from the category** (announcement = inbox-only · reminder/emergency = push+inbox · emergency = high), the single dial across broadcasts / templates / schedules / the Cloud Function. So the live broadcast schema is now just `category` + targeting + lifecycle (`archivedAt`) + delivery counts.
    ├── manager/              # ManagerShell + ManagerHomeScreen (live branch dashboard, Phase 6)
    ├── employee/             # EmployeeShell + EmployeeHomeScreen (live command center: progress-ring hero + actionable task list; redesign v2)
    └── settings/             # Settings + change password (presentation only)
```

> `settings` is presentation-only (reuses `auth`/`profile` cubits). Each user is
> dispatched to exactly one role shell after login; **all three role home
> dashboards are now live** (Phase 6) — they read role-scoped counts from the
> shared `StatisticsCubit` (admin: global · manager: own branch · employee: own).
>
> The `task` (Phase 3–4), `branch` + `admin` (Phase 5), `statistics` (Phase 6)
> and `schedule` (Phase 7) features are full vertical slices. The Phase 2 `shift`
> foundation was **removed in Phase 10** (dead code — never consumed; the weekly
> `schedule` is the production roster).
>
> **Cubit→repository convention varies by feature:** `auth`/`profile`/`task`
> cubits go through **use cases** for write actions; `branch`/`admin`/
> `statistics`/`schedule` cubits call their **repositories directly** (no
> use-case layer) — a deliberate scope choice (the `schedule` cubits reuse the
> auth `GetUsersByBranch` use case for the member/assignee list). `TaskCubit` is
> a hybrid: use cases for writes, **`TaskRepository` directly** for realtime list
> streams + template CRUD, and **`BranchRepository`** for the admin branch
> picker. `BroadcastCubit` (Communications Center) is the same hybrid: the
> **`SendBroadcast` use case** for the write, **`BroadcastRepository` directly**
> for the realtime feed stream. All app-wide cubits are provided in `main.dart`
> (`auth`/`profile`/`task`/`branch`/`adminUsers`/`statistics`/`schedule`/`shiftSwap`/`branchOperations`/`broadcast`).

---

## 2. File Dependency Map

The composition root is `main.dart` → `AppDependencies.init()`
([core/di/injection.dart](lib/core/di/injection.dart)), which wires every
datasource, repository, use case, and cubit by hand (no DI package). The two
app-wide cubits (`AuthCubit`, `ProfileCubit`) are provided at the root via
`MultiBlocProvider` in [main.dart](lib/main.dart).

### Authentication chain (ADMIN-PROVISIONED — no public registration, 2026-06-26)

```
SplashPage · LoginPage · ForgotPasswordPage              (presentation/pages)
ForcePasswordChangePage · ProfileCompletionPage
        ↓  context.read<AuthCubit>()
AuthCubit                                                (presentation/cubit)
        ↓  calls one use case per action (+ flag writes via the repo)
SignInWithEmail · ForgotPassword · ChangePassword
GetUser · SignOut                                        (domain/usecases)
        ↓  every use case wraps one AuthRepository method
AuthRepository (abstract)                                (domain/repositories)
        ↓
AuthRepositoryImpl                                       (data/repositories)
        ↓                          ↓
AuthRemoteDataSource          UserRemoteDataSource        (data/datasources)
  (FirebaseAuth: email only)    (Firestore users/{uid})
        ↓                          ↓
   FirebaseAuth               Cloud Firestore
```

- **DROP is admin-provisioned — there is NO public registration, Google
  sign-in, or phone/OTP.** Accounts are created server-side by the
  **`createUserAccount`** Cloud Function (Admin SDK); the client only signs in
  with email/password, resets/changes the password, and writes the two
  first-login flags. `AuthRepository` exposes `signInWithEmail`, `signOut`,
  `getUser`, `getUsersByBranch`, `watchUser`, `sendPasswordResetEmail`,
  `changePassword`, and the self-flag setters `setMustChangePassword` /
  `setProfileCompleted`.
- `AuthRepositoryImpl` holds **two** datasources: `AuthRemoteDataSource`
  (Firebase Auth, email only) and `UserRemoteDataSource` (the `users/{uid}`
  doc — reads/streams + the flag writes). It maps `UserModel ⇄ UserEntity`.
- Datasources throw `AuthException`; the repository catches and rethrows as
  `AuthFailure`; the cubit catches `AuthFailure` and emits `AuthState.error`.
- `AuthState` cases: initial / loading(AuthAction) / authenticated(UserEntity) /
  unauthenticated / passwordResetSent / passwordChanged / error. `AuthAction` =
  {emailSignIn, forgotPassword, changePassword}.

### Routing & session chain (first-login gate)

```
AuthCubit.stream
        ↓
_AuthStateNotifier (ChangeNotifier)   ← refreshListenable
        ↓
GoRouter.redirect                     ← first-login gate + ROLE guard
        ↓
splash → login/forgot → force-password-change → complete-profile → role shell
```

`createRouter(AuthCubit)` ([core/routes/app_router.dart](lib/core/routes/app_router.dart))
re-evaluates its `redirect` whenever `AuthCubit` emits. **First-login gate** (in
order, before role dispatch): `user.mustChangePassword` → **Force Password Change**
(`/force-password-change`); else `!user.isProfileCompleted` → **Profile Completion**
(`/complete-profile`); else the **role shell** (`RouteNames.homeForRole(user.role)`
→ `/` employee, `/admin`, `/manager`). A **deactivated** account never reaches the
router as authenticated — `AuthCubit` signs it out at login (and on a mid-session
deactivate via `watchCurrentUser`) and surfaces "This account has been disabled".
The redirect **only** bounces an *explicitly* `unauthenticated` session to Login
(transient loading/passwordChanged/error states do **not** redirect — so an
in-flight forced change never flickers the user out). It still **role-guards**
every navigation: admin areas admin-only, manager areas admit manager + admin
(**admin ⊇ manager**), the employee home (`/`) employee-only; `/profile` &
`/settings` are shared. `SplashPage` calls `AuthCubit.restoreSession()` on cold
start and dispatches via the same gate (`_destinationFor`); minimum dwell is the
**brand-animation length (1400 ms)**. **Warm-start preload (Perf · Phase C):** the
app-wide `BlocListener<AuthCubit>` in `main.dart` preloads the home-critical cubits
on `authenticated` (gated on `hasAppAccess` = `isActive`). Because a Firebase
sign-in doesn't know the role/flags, `AuthCubit` re-reads the Firestore user after
sign-in (`_withStoredProfile`) so the emitted `authenticated` state carries the
authoritative role/branch + first-login flags. The first-login screens flip their
flag then call `refreshUser()`, so the router advances automatically.

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
- **`ProfileCubit.loadProfile(uid)` is idempotent** — once a uid's profile is in
  memory (loaded **or** updated via `save`, both stamp `_loadedUid`), a screen
  revisit **skips the Firestore re-read and the skeleton flash** (this fixes the
  "returning to Profile triggers a full reload"). An explicit retry passes
  `forceRefresh`. The Profile page has no pull-to-refresh, so edits (which flow
  back through `save`) are the only in-session mutation.

### Shift chain (Phase 2 — REMOVED in Phase 10)

The Phase 2 `shift` foundation (`features/shift/`, `shifts/{shiftId}` collection +
rules, `/admin|manager/shifts` + `/my-shift` routes, `RouteNames.shiftsForRole`,
`AppDependencies.shiftRepository`, `AppConstants.shiftsCollection`) was **deleted
in Phase 10**: it was never consumed (no `ShiftCubit`/use cases, screens
unreachable from the chrome) and the **weekly `schedule` (Phase 7)** is the
production roster. The `users/{uid}.assignedShift` and `tasks.assignedShiftId`
fields remain as nullable strings (harmless, unused).

### Task chain (Phase 3–4 + Stabilization + Phase 9 + Workflow Upgrade — full operations workflow)

```
TaskDetailsScreen  (all roles — full-screen: status, assignees, checklist, timeline, actions)
MyTasksScreen (employee — tabbed/sectioned: Active→5 sections / Done)
ManagerTasksView (manager, flat list) · AdminTaskOverviewScreen (admin, branch
overview + drill-down) — both render the shared ManagerTaskCard
task_card · task_action_sheets (create·assign·review) · task_template_sheets
        ↓  context.read<TaskCubit>()      (provided app-wide in main.dart)
TaskCubit  + TaskState                                        (presentation/cubit)
        ↓  one use case per WRITE action (reads/streams/templates/activity: repo-direct or inline)
CreateTask · UpdateTask · DeleteTask · AssignTask
UploadTaskAttachment  (image/video → TaskAttachment)   (domain/usecases)
GetUsersByBranch (auth use case — assignee picker)
TaskRepository.watch{AllTasks,TasksByBranch,EmployeeTasks}  (realtime lists)
TaskRepository.{get,create,delete}Template                 (task templates)
BranchRepository.getBranches                               (admin branch picker)
TaskCubit._appendActivity  (inline — appends ActivityEntry to task.activityLog)
TaskCubit._spawnNextRecurrence  (inline on approve — creates next recurring task)
        ↓
TaskRepository (abstract)                                    (domain/repositories)
        ↓   AppDependencies.taskRepository  (composed in injection.dart)
TaskRepositoryImpl                                           (data/repositories)
        ↓
TaskRemoteDataSource                                         (data/datasources)
        ↓                              ↓                       ↓
Cloud Firestore  tasks/{taskId}   task_templates/{id}   Storage tasks/{id}/attachments/{id}.<ext>
```

- Full vertical slice: `TaskCubit` (app-wide, provided in `main.dart`) injects
  **one use case per write action**; each wraps a `TaskRepository` method. It
  additionally takes the **`TaskRepository` directly** (for realtime list
  **streams** + template CRUD) and **`BranchRepository`** (for the admin's New
  Task branch dropdown) — the documented convention for stream/non-action repo
  access. Datasource throws `ServerException`; repo → `ServerFailure`; maps
  `TaskModel → TaskEntity`.
- **Core workflow:** a manager/admin creates + assigns a task (optionally with a checklist + recurrence); the employee drives it via **`TaskCubit.completeAndSubmit`** — a single action that uploads proof + notes and advances the task directly to `waitingReview` (recording both `completed` and `waitingReview` activity entries in one write); a manager/admin reviews → `approved` | `rejected`; approval auto-spawns the next recurrence when `frequency != none`. Every transition appends an `ActivityEntry` to `task.activityLog`. Proof is uploaded **before** the status write inside `completeAndSubmit`, so a failed upload aborts the transition (task stays `started`, photo retained for retry) rather than silently submitting evidence-less work. The standalone `completeTask` use case was removed (dead since the two-step UX was eliminated); `submitForReview` + the `completed → waitingReview` transition remain only so any pre-existing `completed`-state task can still be advanced. `TaskType` (daily/special), `TaskStatus`, `TaskPriority`, and `RecurrenceFrequency` are enums in `core/enums`.
- **Branch is never free text.** A manager's task takes their own `branchId`; an **admin picks an existing branch from a Firestore-backed dropdown** (`TaskCubit.branches()` → `BranchRepository`). This guarantees the task's `branchId` matches the employees' `users/{uid}.branchId`, so the Assign picker is always populated.
- **Realtime lists.** `TaskCubit.load` subscribes to a **live Firestore snapshot stream** by role (admin: `watchAllTasks` · manager: `watchTasksByBranch` · employee: `watchEmployeeTasks`), so a newly assigned task or any status change appears **immediately** (backed by the offline cache). Mutations keep the list visible (`loaded(tasks, busy)`) and the stream reflects the result; on error the previous list is restored. **`load` is idempotent** — calling it again for the same user while already streaming (and not in an error state) is a **no-op**: it does not re-subscribe or flash a skeleton, so revisiting a screen never reloads. Pull-to-refresh / `refresh()` pass `forceRefresh` to re-subscribe. The subscription is cancelled in `close()`.
- **Every status transition is a single atomic `_updateTask` write** that sets the new `status`, its per-transition audit timestamp (`startedAt`/`submittedAt`/`approvedAt`/`rejectedAt`), and appends the `ActivityEntry` in one Firestore document write — there is no two-write pattern. The `_mutating` flag prevents concurrent writes. **Status transitions are validated in `TaskCubit._canTransition`** (invalid moves are blocked client-side); WHO may write is enforced in `firestore.rules` (`tasks/{taskId}`): admin all branches, manager own branch, employee own assigned tasks with **limited writes** (may advance status / add notes / proof but may not reassign, change branch, or approve/reject). Proof images upload to Storage `tasks/{taskId}/proof.jpg`.
- **Checklist templates** (`task_templates/{id}`): reusable **checklists** ("Open Shop", "Close Shop") that **prefill** the task form *and generate the task's checklist*. Same `TaskCubit`/`TaskRepository` (no new cubit/DI). UI: two-step New Task chooser (Blank / From a template) + Manage Templates sheet (`task_template_sheets.dart`) with a **checklist editor**. **Repository-level cache (Perf · Phase B):** `TaskRepositoryImpl.getTemplates({forceRefresh})` caches the (tiny, global) template list in memory (**20-min TTL**), invalidated on `createTemplate`/`deleteTemplate` — so the New-Task sheets (which read it 3× per session) hit Firestore at most once per window. `BroadcastTemplateRepositoryImpl` mirrors this exactly (20-min TTL; invalidated on create/update/setFavorite/incrementUsage/delete).
- **Multi-assignee + checklist (Phase 9).** A task carries `assigneeIds[]` (replacing the single `assignedEmployeeId`, which `TaskModel` keeps as a synced **primary mirror** for backward-compatible rules/stats) and a `checklist` of `ChecklistItem`s. A task **cannot be completed until every required checklist item is done** (`TaskEntity.requiredChecklistComplete`); employees tick items via `TaskCubit.toggleChecklistItem`. `TaskCubit` builds a per-branch **user directory** (`TaskState.loaded.directory`) so cards render real avatars · names · roles.
- **Recurring tasks (Workflow Upgrade).** `TaskEntity` carries an optional `RecurrenceConfig` (frequency/interval/weekday/hour/minute, `nextOccurrence()`). On task creation, the manager/admin picks a recurrence via the `_RecurrencePicker` chip row in the form sheet. When `TaskCubit.approveTask` succeeds and `task.recurrence?.frequency != none`, `_spawnNextRecurrence(source)` creates the next task (same content, checklist reset, deadline = `recurrence.nextOccurrence(now)`). Best-effort — a spawn failure never blocks the approval.
- **Activity timeline (Workflow Upgrade).** Every status-changing `TaskCubit` action appends an `ActivityEntry` (actorId/actorName/status/at/note) to `task.activityLog[]` **inline**, inside the same single atomic `_updateTask` write that sets the new status (the standalone `_appendActivity` helper was removed in the single-write refactor). This is the spec's **event-based** timeline; `TaskDetailsScreen` and the admin recent-activity feed render it dynamically newest-first via the shared `TimelineTile` + `activity_format.dart` (actor, time-ago, optional note) — missing/optional steps and rework loops just work (no hardcoded sequence).
- **Task Details Screen (Workflow Upgrade).** `TaskDetailsScreen(task, directory)` is a full-screen `StatefulWidget` accessible via `Navigator.push` (slide transition) from both `ManagerTasksView` and `MyTasksScreen`. It wraps in `BlocBuilder<TaskCubit>` so the displayed task refreshes from the live stream. Contains: `_StatusHeader` (animated pills), `_AssigneeBlock` ("Assigned by Name·Role"), `_ChecklistBlock` (progress bar + interactive items for employees on started tasks), `_SubmittedBlock` (notes + proof), `_ActivityTimeline`, and `_EmployeeActions` / `_ReviewBlock` by role.
- **Approved-task lock (UX/Logic Refactor §6, 2026-06-25).** An approved task is a **locked, reviewed record**: `TaskCubit.editTask` / `deleteTask` / `assignEmployees` refuse it (the previously-unguarded mutation path), `firestore.rules` (`tasks` update/delete) permit an in-place change on an approved task **only** for an admin **reopen** (status must leave `approved`) and deny deleting it, and `ManagerTaskCard` + `TaskDetailsScreen` hide Assign/Edit/Delete + show a locked banner/glyph. The single escape hatch is admin-only **`TaskCubit.reopenTask`** (approved → `started`, clears the approval audit, logs a "Reopened for changes" `ActivityEntry`). The review transition *into* approved is unaffected (the stored status is then `waitingReview`).
- **Active operational window (UX/Logic Refactor §2, 2026-06-25).** Pure [`active_window.dart`](lib/features/task/domain/active_window.dart) (`isTaskInActiveWindow` / `activeWindowTasks`) — the employee home counts (progress ring + stat strip) used to include *every* task ever assigned, so historically-approved work inflated the denominator forever. The window keeps outstanding work + work **approved today**, dropping older approved tasks; `employee_home_screen` windows the counts only (the task sections already render in-window statuses).
- **Admin Pending Review drill-down (UX/Logic Refactor §1, 2026-06-25).** [`pending_review_screen.dart`](lib/features/task/presentation/pages/pending_review_screen.dart) (route `RouteNames.adminReview` = `/admin/review`, admin-guarded) replaces the admin review CTA's old jump to the operations overview with a guided **Summary → Branch → Employee → Task** drill. A self-contained `StatefulWidget` reading the app-wide `TaskCubit` all-branches stream (filtered to `waitingReview`, grouped by branch via `branchNames` then assignee via `directory`); the leaf reuses `ManagerTaskCard` → the existing review surface. No new cubit / repository / schema. Wired from `AdminDashboardScreen` (`PendingActions.onReviews` + the `_Hero` review state). **Realtime polish (2026-06-25):** the stream was already live (no buffer/banner/batch added — that was reconciled away as unnecessary; review is a separate route, so there's no list-jump-during-review problem); instead every level's rows are keyed **`LiveListItem`**s (`b:`/`e:`/`t:` keys) so a stream emit never re-animates the on-screen list, a genuinely-new submission (an unseen id after first load, tracked in `_knownTaskIds`) **slides in + briefly highlights**, scroll is held (`PageStorageKey` per level), and all counts use **`AnimatedCount`**. The Admin Home counters (`DashboardMetricCard` numeric values + the `_Hero` value) also count up via `AnimatedCount`.
- **Reference images — admin/manager (Premium task UX slice, 2026-06-25).** `TaskEntity` carries **`referenceAttachments`** (`List<TaskAttachment>`, default empty; `hasReferences` getter) — reference photos the manager/admin attaches when creating/editing a task ("what good looks like"), **distinct from employee proof** (which lives on the submission `ActivityEntry` + legacy `proofImageUrl`). `TaskModel` (de)serializes it via the existing `_attachmentsFrom/ToList` (back-compat → empty). Upload reuses the proof pipeline: `TaskCubit.createTask(referenceAttachments:)` uploads **after** create (the Storage path needs the task id) then patches the doc; `editTask(newReferenceAttachments:)` uploads + appends to the kept refs (the form passes the surviving refs in `task.referenceAttachments`, removed ones drop off); both via `_uploadReferences` → `UploadTaskAttachment` → `tasks/{id}/attachments/{attId}.<ext>` (no new Storage rule; the `tasks` create/update rule already permits the manager/admin write). UI: the **shared `AttachmentPickerField`** gained `allowVideo` (images-only), `title`/`hint`, and `existing` + `onRemoveExisting` (already-uploaded refs as removable `_ExistingTile` network thumbs) — one picker for both proof + references. The form (`task_action_sheets`) has a "Reference images" section; `TaskDetailsScreen` shows a "Reference" 2-col `AttachmentGallery` (tap → fullscreen/zoom) before the checklist.
- **Premium (de-flashed) task card (Premium task UX slice + de-flash, 2026-06-25).** The shared **`TaskCard`** (manager/admin surfaces, via `ManagerTaskCard`) was rebuilt from a `_MetaRow` label→value table into a scannable, signal-driven card: a tinted **status pill**, a **High-only priority flag** (`_HighPriorityFlag`; Medium/Low show nothing — noise reduction), a **signal-chip strip** (`_MetaChip`: branch · due/overdue · `N refs`), a **single thin checklist bar** (`_ChecklistBar`) shown **only when the task has a checklist** (otherwise the pill carries state), and a **minimal one-line `_AssigneeFooter`** (avatar · name · "· by Creator" inline). Inline proof/notes/review were **removed** (details-only). **Premium ≠ flashy (de-flash ruling, 2026-06-25):** the card surface is a flat solid `darkSurface` fill + hairline `darkBorder` + a *whisper* depth shadow (no gradient, **no glow halo**, no pulse), defined **once** in the reusable **`TaskSurface`** ([task_surface.dart](lib/features/task/presentation/widgets/task_surface.dart)) — the **single source** of the de-flashed treatment, deliberately **not** `AppGlassCard`, so the de-flash is **scoped to task surfaces only** (the shared `GlassContainer`/`AppGlassCard` primitives are untouched, pending validation of this language before any global change; `TaskSurface` is the one place to promote if we ever globalise). To avoid a third status→colour map, the card pill takes its colour from the canonical **`taskStatusColor`** (the same source as `StatusBadge` + the `AppGlassCard` glow); only its friendlier label + icon are card-local. `ManagerTaskCard` passes the resolved `branchName` (from `TaskCubit.branchNames`); `resolveAssignees` + `TaskActionButton` stay exported (used by `TaskDetailsScreen` / `ManagerTaskCard`). `TaskDetailsScreen._StatusHeader` was de-flashed to match — a flat stateless surface **reusing the same `TaskSurface`** (the breathing in-review **pulse + glow + gradient removed**; the status pill's one-shot cross-fade kept). The employee `_MinimalCard` (`my_tasks_screen`) + `_HomeTaskCard` (`employee_home_screen`) are **separate** surfaces, unchanged (follow-up).

### Admin module chain (Phase 5)

```
AdminShell ▸ AdminDashboardScreen (reports + nav)            (admin/presentation/pages)
  ├─ BranchManagementScreen ────────────┐
  ├─ ManagerManagementScreen            │  (push /admin/* routes)
  ├─ EmployeeManagementScreen           │
  └─ PendingApprovalsScreen             │
        ↓ context.read<…Cubit>()  (all provided app-wide in main.dart)
BranchCubit          AdminUsersCubit          StatisticsCubit (shared, Phase 6)
        ↓                  ↓                         ↓
BranchRepository     UserAdminRepository      StatisticsRepository
        ↓                  ↓                         ↓
BranchRepositoryImpl UserAdminRepositoryImpl  StatisticsRepositoryImpl
        ↓                  ↓                         ↓
BranchRemoteDataSource  UserAdminRemoteDataSource  StatisticsRemoteDataSource
        ↓                  ↓                         ↓
Firestore branches/{id}   Firestore users/{uid}     aggregates users/tasks/shifts/branches
```

- **Branch** is a full vertical slice (`BranchEntity`/`BranchModel`/
  `BranchRepository(+Impl)`/`BranchRemoteDataSource`). "Delete" is a **soft
  delete** (`deletedAt` set; excluded from the default list). Admin-only writes
  per `firestore.rules` (`branches/{branchId}`); any signed-in user may read.
  **Repository-level cache (Perf · Phase B):** `BranchRepositoryImpl` holds the
  active branch list in memory (**10-min TTL**, `getBranches({forceRefresh})`),
  shared across **all** callers since it's a single instance — `BranchCubit`,
  `TaskCubit` (branch names + admin picker), `AdminUsersCubit`, `BroadcastCubit`.
  Every write (`create`/`update`/`setBranchActive`/`deleteBranch`) **invalidates**
  it; pull-to-refresh passes `forceRefresh`. The `includeDeleted` variant is never
  cached. This is **not** a generic cache — just two private fields per repo.
  **Branch Media (§8, 2026-06-25):** `BranchEntity`/`BranchModel` carry `logoUrl` +
  `coverUrl` (`toMap` **excludes** them so a name/location edit-save can't clobber
  an uploaded logo). `BranchRemoteDataSourceImpl` (now holding `FirebaseStorage`)
  → `uploadBranchImage(branchId, file, {isLogo})` uploads to Storage
  `branches/{id}/{logo|cover}.jpg` (overwrite + fresh token, 60s timeout) and writes
  the URL onto the doc; `BranchRepository.uploadBranchImage` invalidates the cache,
  `BranchCubit.uploadBranchImage` reloads + returns the URL. Rendered by the shared
  **`BranchAvatar`** (`core/widgets`); upload UI is the branch form sheet's "Branch
  media" section (edit-only). `storage.rules` add `branches/{branchId}/{file}`
  (signed-in read/write; the real gate is the admin-only Firestore branch write).
  **No chromatic `branchTheme`** — rejected per the monochrome ruling.
  **Branch directory (§8b):** the app-wide `BranchCubit` doubles as a **branch
  directory** — `branchById(id)` + `loadIfNeeded()`, warm-preloaded for every role
  in `main.dart` — so any surface resolves a `branchId` → `BranchAvatar`/name with
  no per-screen fetch. Consumed by the schedule header (`manager_schedule_view`),
  the operations AppBar (`branch_operations_screen`), the employee profile's
  Assigned-branch section (`profile_page`), and swap cards (`swap_view`).
  **Branch hero (§8c):** the Branch Operations cockpit leads with `_BranchHero` —
  a 16:9 surface using the branch **`coverUrl`** (≈70% dark scrim) + `BranchAvatar`
  + name + employee count + the cockpit `ShiftFilter` summary, with a monochrome
  `_MonoHeroBg` fallback and a ≤0.03 `BrandWatermark`. The schedule header also
  shows "Weekly Schedule · N employees" (`members.length`).
- **`admin`** owns user administration over `users/{uid}` via its own
  `UserAdminRemoteDataSource` (reusing the auth `UserModel`/`UserEntity`) — a
  third datasource on `users` alongside `auth` and `profile`. `AdminUsersCubit`
  loads a slice by `AdminUserFilter` (**managers / employees** — the `pending`
  slice was removed) and performs (de)activate, change-branch, change-role,
  change-position, change-employment-status, **edit contact details**,
  **promote-to-manager**, **reset account**, and **create account**. Managers
  never write user docs.
  **Edit contact details (2026-06-26):** `UserAdminRepository.updateUserDetails` /
  `AdminUsersCubit.updateDetails` let an admin record/correct a person's
  **non-privileged** info — `displayName` (mirrored to legacy `fullName`),
  `phoneNumber`, **`address`**, **`emergencyContact`** (the latter two are new
  `UserEntity`/`UserModel` fields) — **anytime after creation** via the
  `showEditDetailsSheet` "Edit Info" action on the Employees + Managers lists. It
  reuses the generic `updateUser` merge write (only non-null fields sent); the
  admin branch of the `users` update rule already allows it (no rule change), and
  these fields are NOT frozen by the self-update rule (so profile onboarding still
  writes them too).
- **Account provisioning (2026-06-26):** an admin **creates accounts** directly
  via **`CreateAccountScreen`** (Admin → User Management → Create Account) →
  `AdminUsersCubit.createAccount` → `UserAdminRemoteDataSource.createAccount` →
  the admin-only **`createUserAccount`** Cloud Function (Admin SDK creates the
  Auth user — the admin stays signed in — then seeds the `users/{uid}` doc with
  role/branch/shift/position + `mustChangePassword:true` + `isProfileCompleted:
  false` + `createdBy`). **`adminResetPassword`** issues a new temp password +
  re-forces a change. The earlier "promote an existing user (no Admin SDK)"
  constraint is obsolete — direct creation is the path now (promote-to-manager
  remains for existing employees).

### Statistics + notifications (Phase 6)

- **`statistics`** is a full vertical slice (`StatisticsEntity`/`StatisticsModel`/
  `StatisticsRepository(+Impl)`/`StatisticsRemoteDataSource`) + `StatisticsCubit`.
  `StatisticsCubit.load(user)` dispatches by role to `adminStats()` (global) /
  `managerStats(branchId)` / `employeeStats(uid)`. **`adminStats()` is the only
  unscoped query, so it uses server-side `count()` aggregation** (employee /
  pending / approved / waitingReview / rejected / total counts — no document
  downloads) plus **bounded single-field reads** (managers-only, this-week-onward
  schedules, today's rejections) instead of scanning all users/tasks/schedules;
  `managerStats`/`employeeStats` are already branch/user-scoped so they keep the
  fetch-once + **count-client-side** pattern. All filters are single-field
  (automatic indexes — **no composite index**). **`StatisticsCubit` caches a
  recent result (90 s) per role+user+branch key** and skips both the refetch and
  the loading flash on a revisit; pull-to-refresh passes `forceRefresh`.
  The `AdminDashboardScreen` / `ManagerHomeScreen` consume it via the shared
  `StatGrid` widget; the **`EmployeeHomeScreen` (redesign v2)** reads
  `StatisticsCubit` only for **today's shift** (`currentShiftName` /
  `upcomingShiftName`) and computes its task breakdown + progress ring from the
  live `TaskCubit` list instead (the ground truth — `employeeStats` does not
  populate `activeTasks`).
  **Rebuild scoping (Perf · Phase D):** `AdminDashboardScreen` does **not**
  `context.watch` cubits at the top of `build()` (that rebuilt the whole screen on
  every all-branches task emit). The ListView scaffold + static sections build
  once; each data section subscribes via a scoped helper — `_StatsSection`
  (`BlocBuilder<StatisticsCubit>`: greeting scope, metric grid) and
  `_DynamicSection` (stats + a `BlocSelector<TaskCubit, ({int overdue, int
  reviews})>` on the **overdue + waiting-review counts**: hero, Pending Actions) —
  so a task emit only rebuilds hero/Pending Actions, and only when one of those
  numbers actually moves. **Both counts are derived from the LIVE task stream**
  (`_overdueCount`/`_reviewCount`), **not** the TTL-cached `StatisticsCubit`
  (which isn't invalidated on a mutation) — so completing a review drops the
  Pending Actions queue + hero instantly (2026-06-26 fix). Every section's
  `EntranceFade` is **keyed** (`ValueKey('admin-sec-…')`) so the entrance plays
  once and never replays when the conditional "Pending approvals" section shifts
  positions. The `_Hero` takes a pre-computed `overdue` int (its only task input).
- **Notifications** (`core/services/notification_service.dart`, FCM): requests
  permission, persists the device token in `users/{uid}.fcmTokens` (an **array**,
  multi-device + refresh-aware, since Phase 2; the legacy single `fcmToken` is
  still read server-side for back-compat), surfaces **foreground** pushes as
  in-app snackbars, and routes **tap** opens (`onMessageTap`) — wired in
  `main.dart` via a `scaffoldMessengerKey` + an `AuthCubit` listener that
  registers/forgets the token on auth changes. `core/enums/notification_type.dart`
  is the event contract — after the **2026-06-23 stabilization pass every value
  has a live producer**: task lifecycle (client `NotifyTaskEvent`), task reminders
  (`runTaskReminders` Cloud Function), and broadcasts (`sendBroadcast` /
  `dispatchBroadcast`). The ~16 unused reserved schedule/swap/admin types were
  **trimmed** (re-add a value only alongside a real producer). A live in-app
  **inbox** exists at `/notifications` (the `notifications` feature slice);
  there is no chat.

### Schedule chain (Phase 7 — full vertical slice)

```
BranchScheduleScreen (manager, tabs)   ScheduleManagementScreen (admin)   MyScheduleScreen (employee, tabs)
  └─ ManagerScheduleView (shared editor) ─┘   + SwapListView / showSwapRequestSheet      (presentation/pages + widgets)
        ↓  context.read<ScheduleCubit>() / context.read<ShiftSwapCubit>()  (both app-wide in main.dart)
ScheduleCubit (+ ScheduleState)        ShiftSwapCubit (+ ShiftSwapState)              (presentation/cubit)
  load/create/assign/remove,             loadMine/loadBranch/loadAll (LIVE streams),
  week + branch navigation               requestSwap·coworkerApprove/reject·managerApprove
        ↓  (repo-direct; ScheduleCubit also uses auth GetUsersByBranch for members)
ScheduleRepository (abstract)                                                          (domain/repositories)
        ↓   AppDependencies.scheduleCubit / shiftSwapCubit  (composed in injection.dart)
ScheduleRepositoryImpl                                                                 (data/repositories)
        ↓                          (managerApproveSwap → approveSwap Cloud Function: atomic exchange)
ScheduleRemoteDataSource  (FirebaseFirestore + FirebaseFunctions)                     (data/datasources)
        ↓                          ↓                              ↓
Cloud Firestore  weekly_schedules/{branchId_yyyy-MM-dd}    shift_swaps/{id}    fn approveSwap (txn)
```

- **Weekly schedule** = one doc per (branch, week) at a deterministic id
  (`ScheduleWeek.docId` = `<branchId>_<yyyy-MM-dd>` of the week's Sunday), so a
  week is read directly without a query. The roster is a nested map
  `assignments.<day>.<shift> = [uid…]`; assign/remove use Firestore nested
  `arrayUnion`/`arrayRemove` (no read-modify-write). `ScheduleDay` (Sun→Sat),
  `ScheduleShift` (morning/night) and `SwapStatus` are enums in `core/enums`.
- **Shift swap** = an employee-to-employee **exchange** (2026-06-25 — was a
  one-way handover). The requester asks a coworker on the **opposite shift, same
  day** to trade (`my_schedule._requestSwap` filters the picker to that day's
  opposite-shift assignees — there are only two shifts, so the target's slot is
  `ScheduleShift.opposite`). Flow `pending → employeeApproved → managerApproved`
  (or `rejected`/**`cancelled`** — the requester's own cancel via `cancelSwap`).
  Status values map to the spec's `pendingCoworker/pendingManager/approved/rejected`
  (kept the existing names). **Manager approval is server-authoritative + atomic
  (2026-06-26).** `managerApproveSwap` no longer does the 4-op non-atomic client
  write; it calls the callable **`approveSwap` Cloud Function**
  (`ScheduleRemoteDataSource.approveSwap` → `cloud_functions`; DI:
  `ScheduleRemoteDataSourceImpl` now takes `FirebaseFunctions`), which re-validates
  against the **freshest** schedule (TOCTOU) and applies the requester ⇄ target
  trade in **one Firestore transaction** (both move or nothing changes). The client
  passes the locally-computed `scheduleId` (the UTC function can't reproduce the
  local-week-start doc id), re-checked server-side against the swap's branch.
  **Validation** is defined once in pure
  [`swap_validation.dart`](lib/features/schedule/domain/swap_validation.dart)
  (`SwapValidation` — slot integrity · role compatibility · double-booking · rest
  hours), used client-side at request time and **mirrored in `approveSwap`** (the
  authority). Rules: **`shift_swaps` denies any client write setting
  `status==managerApproved`** (function-only); **`branches/{id}.swapPolicy`** holds
  the optional [`SwapPolicy`](lib/features/schedule/domain/swap_policy.dart)
  (`restrictToSamePosition` + `minRestHours`; null = permissive — a per-week shift
  cap was omitted as invariant under an exchange); **`users/{uid}.position`** (new
  `UserEntity.position`, admin-set, frozen on self-update) drives role compatibility.
  Default eligibility is "same branch, any role"; role compat is opt-in per branch
  (branch form "Shift-swap rules" section; employee-management **Position** action →
  `AdminUsersCubit.changePosition` → `UserAdminRepository.changeUserPosition`).
  **Swap notifications:** `NotifySwapEvent` (notifications
  use case, reuses `NotificationRepository.createMany`; the live
  `onNotificationCreated` pushes FCM) fires request→coworker · accept→branch
  manager(s) (via `GetUsersByBranch`) · approve/reject→both — populating the §5
  inbox **Schedule** category (`swap*` `NotificationType`s). `ShiftSwapCubit` now
  holds `NotifySwapEvent` + `GetUsersByBranch` (DI). Guards: requester≠target ·
  future shift (`SwapEligibility`) · target-slot-exists · no duplicate pending.
  The flow order is validated in `ShiftSwapCubit`; `firestore.rules` enforce who
  may write. **Realtime (2026-06-26):** `ShiftSwapCubit` is **stream-based** —
  `loadMine`/`loadBranch`/`loadAll` subscribe to live Firestore snapshot streams
  (`ScheduleRepository.watchEmployeeSwaps` — merges the requester+target queries —
  `watchBranchSwaps`/`watchAllSwaps`), scope-guarded + cancel-on-close; mutations
  no longer refetch (the stream reflects them). So an incoming swap appears on the
  coworker's Home instantly and the **admin Home swap count is live**
  (`admin_dashboard_screen._PendingSection` selects the unresolved count). The
  one-shot `getEmployeeSwaps/getBranchSwaps/getAllSwaps` + `pendingSwaps()` remain
  for snapshot callers.
  `BranchScheduleScreen` carries a `BlocListener` that refreshes `ScheduleCubit`
  whenever a swap action settles, so an approved swap updates the Schedule tab
  with no manual refresh (Phase 8). **A swap may only be requested for an upcoming
  shift** (2026-06-20): the pure `domain/swap_eligibility.dart` (`SwapEligibility`)
  is the single source of truth, enforced at the sheet, the `requestSwap` cubit
  gate, and the `shift_swaps` create rule (`swapSlotInFuture`). Admins get
  all-branch swap visibility via `ScheduleRepository.getAllSwaps()` →
  `ShiftSwapCubit.pendingSwaps()` (feeds the Admin Home Pending Actions panel).
- **Dashboards reuse this data:** the `statistics` datasource reads
  `weekly_schedules` for the current week to compute the employee current/upcoming
  shift, the manager scheduled/morning/night-today counts, and the admin schedule
  coverage (`ScheduleWeek` + `ScheduleDay` imported into statistics).

### Branch Operations chain (task→operations redesign)

```
AdminTaskOverviewScreen (admin branch overview)  ManagerOperationsScreen (manager own branch)
        └─────────────── drill / land ───────────────┘
                          ↓ Navigator.push
BranchOperationsScreen  (the cockpit: summary header · shift toggle · WorkloadCard list · FAB)
        ↓ context.read<BranchOperationsCubit>()        ↓ tap employee (Navigator.push)
BranchOperationsCubit + BranchOperationsState   EmployeeDetailScreen (tasks by status)
        ↓ (repo-direct; reuses auth GetUsersByBranch)         ↓ tap task → TaskDetailsScreen
TaskRepository.watchTasksByBranch  ⨯  GetUsersByBranch  ⨯  ScheduleRepository.getSchedule
        ↓                          computeBranchWorkload (pure)
   Cloud Firestore  tasks/{id}        users/{uid}        weekly_schedules/{id}
```

- **Read/derive only.** `BranchOperationsCubit` (app-wide, in `main.dart`)
  subscribes the **live** `watchTasksByBranch` stream + one-shot branch members +
  this week's roster, and emits `computeBranchWorkload(...)` (the pure domain
  aggregation). The shift filter is cubit state applied as a **pure re-derive**
  (no I/O). **All task writes** (create / assign / review) still go through
  `TaskCubit`, which the cockpit also loads — both watch the same branch stream, so
  a write shows on the cockpit immediately. The cockpit's New-Task FAB reuses
  `startNewTaskFlow`; "All tasks" + the employee drill render the shared
  `ManagerTaskCard` → `TaskDetailsScreen`. No new collection, no new go_router
  route (cockpit + drills are `Navigator.push`); the one schema delta is
  `tasks.shift`.

### Communications Center chain (Phase 1 slice + Phase 2 send engine)

```
SEND (write)                                  RECEIVE (feed read)
BroadcastCubit.send(...)                       BroadcastCubit.load({branchId})
  ↓ client guard: BroadcastPermissions          ↓ repository directly (stream)
SendBroadcast use case                         BroadcastRepository.watchBroadcasts
  ↓                                              ↓
BroadcastRepository.sendBroadcast(entity)      BroadcastRemoteDataSource
  ↓                                              ↓
BroadcastRemoteDataSource (FirebaseFunctions)  Cloud Firestore broadcasts/{id}
  ↓ httpsCallable('sendBroadcast')              (admin: orderBy createdAt ·
══════════ Cloud Function (Node.js) ══════════  branch: whereIn[branch,''])
functions/index.js  sendBroadcast (onCall):
  validate sender perms → resolve recipients →
  write broadcasts/{id} → gather users.fcmTokens →
  messaging.sendEachForMulticast → prune dead tokens →
  return { success, recipientCount, deliveredCount, broadcastId }
  ↓ push (notification + data)
Device  ← NotificationService (foreground · background · tap)
```

- **Hybrid cubit** (mirrors `TaskCubit`): `BroadcastCubit` (app-wide, in
  `main.dart`) injects the **`SendBroadcast` use case** for the write and the
  **`BroadcastRepository` directly** for the realtime feed. Datasource throws
  `ServerException` (from `FirebaseFunctionsException`/`FirebaseException`); repo
  → `ServerFailure`; maps `BroadcastModel ⇄ BroadcastEntity`.
- **Send is server-authoritative (Phase 2).** The client never writes the
  broadcast doc — `BroadcastRemoteDataSource.sendBroadcast` invokes the
  **callable `sendBroadcast` Cloud Function** (`functions/index.js`), which
  validates the sender's permissions, resolves recipients, **writes** the
  `broadcasts/{id}` doc (Admin SDK), pushes the FCM notification, prunes dead
  tokens, and returns the **delivery summary** (`{ success, recipientCount }`).
  `firestore.rules` therefore **deny all client writes** to `broadcasts`.
- **Recipient-resolution matrix** (pure `domain/broadcast_permissions.dart`,
  re-enforced in the function): **admin** → all users / any branch / any user;
  **manager** → their own branch / a user inside it; **employee** → none. The
  client guard gates the UI + the send call; the function is the authority.
  **Sender self-exclusion (UX/Logic Refactor §4, 2026-06-25):** `dispatchBroadcast`
  drops the **sender** from an **implicit** audience (`allBranches`/`branch`/role)
  so an author never receives their own announcement; **explicit** audiences (a
  `user` DM or a hand-picked `custom` list) deliver exactly as chosen.
- **Three audiences.** `BroadcastAudience.allBranches` (every user, admin-only),
  `branch` (one branch), and **`user`** (a direct message). The branch/all feed's
  queryable field is `branchId` (`''` = all-branches sentinel); a **DM** uses a
  non-branch `branchId` marker (`'__direct__'`) + `targetUserId`, so it never
  surfaces in a branch/all feed and is read only by the recipient + admin.
- **Index-free, rules-safe reads** (unchanged from Phase 1): admin feed
  `orderBy('createdAt', descending: true)`; branch member feed
  `where('branchId', whereIn: [selfBranch, ''])`, client-sorted newest-first.
- **FCM device + delivery** lives in `core/services/notification_service.dart`:
  permission, the device token kept in `users/{uid}.fcmTokens` (**array**,
  multi-device, `arrayUnion` on register/refresh, `arrayRemove` on sign-out), and
  message routing — **foreground** (`onMessage` → in-app snackbar), **background**
  (top-level handler in `main.dart`; the OS renders the `notification` block),
  and **tap** (`onMessageOpenedApp` + `getInitialMessage` → `onMessageTap`,
  wired in `main.dart` to navigate + log the `broadcastId`). The backend
  (`functions/`) is a Node.js Cloud Functions codebase deployed separately
  (`firebase deploy --only functions`).
- **UI (Phase 3).** A single `/communications` area (admin + manager; employees
  blocked by the router's `_isCommunicationsArea` guard), entered from the
  `RoleScaffold` header's campaign icon (shown only to admin/manager). Screens:
  `CommunicationsScreen` (the feed — `BroadcastCard`s from the cubit stream, a
  "New Broadcast" FAB), `ComposeBroadcastScreen` (role-gated form: audience via
  `BroadcastPermissions.allowedAudiences` → branch dropdown / searchable
  recipient picker / category chips / title / multiline body → `BroadcastCubit.send`
  → success snackbar with the recipient count → `pop`), and `BroadcastDetailScreen`
  (`/communications/:broadcastId`, resolved from the tapped entity via `extra`
  with a live-feed fallback). The compose pickers read `BroadcastCubit.branches()`
  / `branchUsers()` (repo-direct, mirroring `TaskCubit`). Built entirely on the
  shared design system (`GlassContainer`, `AppButton`, `AppTextField` (now with a
  `maxLines` option), `AppDropdownField`, `AppSearchField`, `UserAvatar`,
  `AppEmptyState`, `EntranceFade`) — strictly monochrome, colour only for an
  urgent category. Delivery stats (`recipientCount` / `deliveredCount`) are
  written by the function and shown on the card + detail.

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
| **Task type/status/priority values**      | `lib/core/enums/task_type.dart` · `task_status.dart` · `task_priority.dart` |
| **Task schema / serialization (incl. audit fields)** | `lib/features/task/domain/entities/task_entity.dart` + `data/models/task_model.dart` (then run codegen) |
| **Task shift tag (morning/night/any)** | `task_entity.dart` (`shift` — nullable `ScheduleShift`, **null = "any"**) + `task_model.dart` (`'shift'` ↔ `ScheduleShift.fromStringOrNull`) + `core/enums/schedule_shift.dart` (`fromStringOrNull` — null-preserving parse). Drives the Branch Operations shift filter; supersedes the unused legacy `assignedShiftId`. Tested in `test/task_model_shift_test.dart` |
| **Branch Operations workload (derive)** | `lib/features/operations/domain/branch_workload.dart` (`computeBranchWorkload` → `BranchWorkload`) + `employee_workload.dart` (`EmployeeWorkload`) + `branch_summary.dart` (`BranchSummary`) + `shift_filter.dart` (`ShiftFilter`). Pure/deterministic (`day`/`now` injectable), joins task stream × `getUsersByBranch` × today's `weekly_schedule`, sorts overload-first. Tested in `test/branch_workload_test.dart` |
| **Branch Operations cubit / state** | `lib/features/operations/presentation/cubit/branch_operations_cubit.dart` + `branch_operations_state.dart` — read/derive only; subscribes `TaskRepository.watchTasksByBranch` + one-shot `GetUsersByBranch` + `ScheduleRepository.getSchedule`; `setFilter` re-derives without I/O. Repo-direct; wired in `injection.dart` + `main.dart`. **Writes stay in `TaskCubit`** (both watch the same branch stream, so writes propagate live) |
| **Branch Operations cockpit (screen)** | `lib/features/operations/presentation/pages/branch_operations_screen.dart` (summary header · `_ShiftToggle` · `WorkloadCard` list · New-Task FAB via `startNewTaskFlow` · "All tasks" → `BranchTaskListScreen`) + widget `presentation/widgets/workload_card.dart` (`WorkloadCard`, widget-tested in `test/workload_card_test.dart`). Manager entry: `manager_operations_screen.dart`; admin entry: the branch-overview drill (`admin_task_overview_screen.dart` `_openBranch`) |
| **Employee operations drill (tasks by status)** | `lib/features/operations/presentation/pages/employee_detail_screen.dart` — reads the loaded `TaskCubit` filtered to one employee, groups by status (Rework·In progress·Pending·Submitted·Completed), renders `ManagerTaskCard` (→ `TaskDetailsScreen`) |
| **Full branch task list (incl. unassigned)** | `lib/features/task/presentation/pages/branch_task_list_screen.dart` (`BranchTaskListScreen` — extracted from the old admin drill; reached via the cockpit "All tasks"). The former `BranchTasksScreen` + `ManagerTasksView` (flat manager list) were **deleted** (retired by the cockpit) |
| **Operations routing / nav entry** | Manager: `RouteNames.managerTasks` (`/manager/tasks`) now renders `ManagerOperationsScreen` (was `BranchTasksScreen`) in `app_router.dart`. Admin: `adminTasks` → `AdminTaskOverviewScreen` (branch overview) whose `_openBranch` drill opens `BranchOperationsScreen`. The cockpit + drills are `Navigator.push` (like `TaskDetailsScreen`), not go_router routes |
| **Task reads/writes / media upload** | `lib/features/task/data/datasources/task_remote_datasource.dart` (Firestore + Storage `tasks/{id}/attachments/{id}.<ext>` via `uploadAttachment`) |
| **Task list ordering (newest first)** | Admin query: Firestore `orderBy('createdAt', descending: true)` (index-free). Filtered branch/employee queries stay filter-only (a filter + `orderBy` needs a composite index → broke loading, reverted) and are ordered by `sortTasksNewestFirst` (`domain/task_ordering.dart`, pending-timestamp on top) in the repo. Tested in `test/task_ordering_test.dart` |
| **Video thumbnails** | `presentation/widgets/video_thumbnail_image.dart` (`VideoThumbnailImage` — `video_thumbnail` poster frame, bounded LRU cache, loading + film-glyph fallback). Used by `attachment_gallery.dart` + `attachment_picker.dart`; play overlay drawn by the caller on top |
| **Task media (images + videos)** | Model: `domain/entities/task_attachment.dart` (`TaskAttachment` incl. `durationMs` + `AttachmentLimits`) + `core/enums/attachment_type.dart`; attached to `ActivityEntry.attachments[]`. Pick: `presentation/widgets/attachment_picker.dart` (`AttachmentPickerField`, captures video duration via `video_player`). View: `attachment_gallery.dart` (compact wrap **or** `columns` grid + `showDuration`) + `attachment_viewer.dart` (fullscreen zoom/`video_player`) + `video_thumbnail_image.dart` (cached real frames). Resolve/format: `presentation/attachment_format.dart` (`attachmentsForEvent` / `latestAttachments` / `attachmentSummary` / `formatVideoDuration`, legacy-proof back-compat). Upload: `UploadTaskAttachment`. Tested in `test/task_attachment_test.dart` |
| **Submission review surface** | `presentation/widgets/submission_details_sheet.dart` (`SubmissionDetailsSheet` / `showSubmissionDetailsSheet`) — large modal opened from a tapped submission timeline card; shows employee response + 2-col gallery + manager feedback + sticky Approve/Rework. Cycle resolution: pure `resolveSubmission(task, index)` in `attachment_format.dart` (content + per-cycle decision, rework-loop aware). Tested in `test/submission_resolution_test.dart`. The timeline `_EventCard` (`pages/task_details_screen.dart`) is now a **summary** (status·actor·time·attachment summary·note preview) |
| **Submission loading UX / progress** | Lives on the cubit: `TaskState.loaded` carries `isSubmitting` + `submissionProgress` (`presentation/submission_progress.dart`: Preparing→Uploading→Finalizing, with bytes→%/MB), preserved on every emit incl. the stream. `completeAndSubmit` throttles progress emits (whole-percent); byte progress aggregated from each upload's Storage `snapshotEvents`. The Task Details screen renders one state-driven `submission_loading_overlay.dart` (fullscreen, interaction-blocking, `PopScope` blocks back). Only `completeAndSubmit` sets `isSubmitting`. Video thumbnails are **local** (`video_thumbnail_image.dart`, view-time, LRU cache) — no server posters. Tested: `test/submission_progress_test.dart` |
| **Task status animations** | `pages/task_details_screen.dart`: `_StatusHeader` (stateful — status glow, amber **pulse** for In Review, static green/red glow), `_StatusPill` (`AnimatedSwitcher` cross-fade+scale on status change), timeline cards wrapped in `EntranceFade`. Monochrome base preserved; colour only as soft glow/tint |
| **Task repository contract / impl**       | `lib/features/task/domain/repositories/task_repository.dart` + `data/repositories/task_repository_impl.dart` (wired in `core/di/injection.dart`) |
| **Task workflow logic / status transitions / state** | `lib/features/task/presentation/cubit/task_cubit.dart` (`_canTransition`) + `task_state.dart` |
| **A new task action**                     | add `domain/usecases/`, a `TaskRepository(+Impl)` method, a datasource method, wire in `task_cubit.dart` **and** `core/di/injection.dart` |
| **Task screens (admin/manager/employee)** | `lib/features/task/presentation/pages/` (`my_tasks_screen` employee · `branch_tasks_screen`/`task_management_screen` → shared `widgets/manager_tasks_view.dart`) |
| **Task UI actions (create/assign/review/complete) + card** | `lib/features/task/presentation/widgets/` (`task_action_sheets.dart`, `task_card.dart`, `task_empty_state.dart`) |
| **Multi-assignee (assigneeIds[]) — schema/logic** | `task_entity.dart` (`assigneeIds`, `isAssigned`) + `task_model.dart` (writes `assigneeIds` + primary `assignedEmployeeId` mirror; reads with legacy fallback) → `assign_task.dart` use case → `TaskCubit.assignEmployees` → multi-select `_AssignSheet` in `task_action_sheets.dart`; rules `tasks/{id}` (`assigneeIds arrayContains`); stats `employeeStats` |
| **Assign-on-create (in the task form)** | `task_action_sheets.dart` `_AssigneePicker` + `_EmployeeChip` (compact team chips, "Whole team"/"Clear all", loaded via `TaskCubit.branchEmployees`; admin reloads + clears on branch change) → `_save()` passes `assigneeIds` to `TaskCubit.createTask` (new optional param, seeded onto the `TaskEntity`) / `editTask` (`copyWith`). No separate create-then-assign step needed |
| **Checklist (template + task) schema/logic** | `lib/features/task/domain/entities/checklist_item.dart` (`ChecklistItem` + `ChecklistItemTemplate`) + `task_template_entity.dart` (`checklistItems`, `buildTaskChecklist`) + `task_entity.dart` (`checklist`, `requiredChecklistComplete`/progress getters); serialization in `task_template_model.dart` / `task_model.dart`; completion gate + toggling in `TaskCubit` (`completeAndSubmit`/`toggleChecklistItem`); checklist editor in `task_template_sheets.dart` |
| **Assignee identity on cards (uid → user)** | `TaskCubit` directory (`_ensureDirectory` via `GetUsersByBranch`) → `TaskState.loaded.directory` → `task_card.dart` (`resolveAssignees`, `_AssigneesRow`) |
| **Reliable avatars (image + initials fallback)** | `lib/core/widgets/user_avatar.dart` (`UserAvatar`, `UserAvatar.fromUser`, `AvatarStack`, `avatarInitials`) — used by task cards, admin user cards, schedule chips/pickers |
| **Card / list entrance motion** | `lib/core/widgets/app_motion.dart` (`EntranceFade`, `staggerDelay`) |
| **Search box (admin lists)** | `lib/core/widgets/app_search_field.dart` (`AppSearchField`) |
| **Admin task branch picker (dropdown, not free text)** | `task_action_sheets.dart` (`_BranchDropdown`) ← `TaskCubit.branches()` ← `BranchRepository` (wired into `TaskCubit` in `injection.dart`) |
| **Recurring tasks (schema / logic)**      | `lib/core/enums/recurrence_frequency.dart` (`RecurrenceFrequency` enum) + `lib/features/task/domain/entities/recurrence_config.dart` (freezed, `nextOccurrence()`) + `task_entity.dart` (`recurrence` field) + `task_model.dart` (`_recurrenceFromMap`/`_recurrenceToMap`) + `TaskCubit._spawnNextRecurrence` (auto-spawn on approve) |
| **Recurrence picker UI**                  | `task_action_sheets.dart` → `_RecurrencePicker` chip row (None/Daily/Weekly/Monthly); shown only on new-task creation |
| **Inline checklist editor in task form**  | `task_action_sheets.dart` → `_InlineChecklistEditor` + `_ChecklistItemRow`; state in `_TaskFormSheetState` as parallel lists (`_itemControllers`/`_itemRequired`/`_itemIds`/`_itemOriginals`); shown for both create and edit; edit preserves `completed` state via `_itemOriginals` merge in `_buildChecklist()` |
| **Task "Type" field (no longer in form)** | `TaskType` enum (`core/enums/task_type.dart`) is still stored on the entity but no longer shown in the form UI. Auto-inferred in `_TaskFormSheetState._save()`: recurring → `TaskType.daily`, one-off → `TaskType.special`. Edit preserves existing type unchanged |
| **Activity timeline (schema / logic)**    | `lib/features/task/domain/entities/activity_entry.dart` (freezed: status/actorId/actorName/at/note/**attachments**) + `task_entity.dart` (`activityLog` field) + `task_model.dart` (`_activityLogFromList`/`_activityLogToList`, incl. `_attachmentsFromList`). Entries are appended **inline** in each status-changing `TaskCubit` method (single atomic write). This **is** the spec's event-based task timeline — rendered newest-first as rich `_EventCard`s (status badge, actor, note, **`AttachmentGallery`**) via `activity_format.dart` + `attachment_format.dart` |
| **Task Details Screen (full-screen view)**| `lib/features/task/presentation/pages/task_details_screen.dart` — opened via `Navigator.push(PageRouteBuilder)` from both `ManagerTasksView._card()` and `MyTasksScreen`; wraps in `BlocBuilder<TaskCubit>` for live updates; contains `_StatusHeader`, `_AssigneeBlock`, `_ChecklistBlock`, `_SubmittedBlock`, `_ActivityTimeline` (renders shared `TimelineTile`), `_EmployeeActions` / `_ReviewBlock` |
| **Employee My Tasks (tabbed/sectioned)**  | `lib/features/task/presentation/pages/my_tasks_screen.dart` — `TabController` (Active/Done), 5 sorted sections, animated entrance, `EmployeeTaskCard` minimal card, taps open `TaskDetailsScreen` |
| **Task realtime list streams**            | `TaskRepository.watch{AllTasks,TasksByBranch,EmployeeTasks}` (+impl + `TaskRemoteDataSource`) → `TaskCubit.load` subscribes by role |
| **Task templates (schema / serialization)** | `lib/features/task/domain/entities/task_template_entity.dart` + `data/models/task_template_model.dart` (then run codegen) |
| **Task templates (reads/writes)**         | `task_remote_datasource.dart` + `task_repository(_impl).dart` (`getTemplates`/`createTemplate`/`deleteTemplate`) → `TaskCubit.templates`/`saveTemplate`/`deleteTemplate`; rules `task_templates/{id}` |
| **Task template UI (New Task chooser / picker / manage)** | `lib/features/task/presentation/widgets/task_template_sheets.dart` (reuses `showSheet`/`SheetTitle` from `task_action_sheets.dart`); invoked from `manager_tasks_view.dart` (FAB + Templates app-bar action) |
| **Assignee picker (branch employees)**    | `AuthRepository.getUsersByBranch` + `auth/domain/usecases/get_users_by_branch.dart` → `TaskCubit.branchEmployees` |
| **Task routes / role entry point**        | `lib/core/routes/route_names.dart` (`adminTasks`/`managerTasks`/`myTasks` + `tasksForRole`) + `app_router.dart` + `role_scaffold.dart` (Tasks icon) |
| **Branch schema / data**                  | `lib/features/branch/domain/entities/branch_entity.dart` + `data/models/branch_model.dart` + `data/datasources/branch_remote_datasource.dart` (then run codegen) |
| **Branch logic / repo / UI**              | `lib/features/branch/domain/repositories/branch_repository.dart` (+impl) · `presentation/cubit/branch_cubit.dart` · `presentation/pages/branch_management_screen.dart` · `widgets/branch_form_sheet.dart` |
| **Admin user administration (data)**      | `lib/features/admin/data/datasources/user_admin_remote_datasource.dart` + `domain/repositories/user_admin_repository.dart` (+impl) — operates on `users/{uid}`, reuses auth `UserModel` |
| **Admin user lists / actions (pending·managers·employees)** | `lib/features/admin/presentation/cubit/admin_users_cubit.dart` (`AdminUserFilter`) + `presentation/pages/{manager,employee}_management_screen.dart` · `pending_approvals_screen.dart` · `widgets/admin_user_card.dart` · `admin_user_sheets.dart` · `admin_users_list_view.dart` |
| **Operational stats / dashboard data**    | `lib/features/statistics/` (entity·model·repository·datasource + `StatisticsCubit`) — branch-scoped counts for all 3 dashboards; **schedule figures (Phase 7)** read `weekly_schedules` in the statistics datasource |
| **Weekly schedule schema / serialization**| `lib/features/schedule/domain/entities/weekly_schedule_entity.dart` + `data/models/weekly_schedule_model.dart` (then run codegen); week math in `domain/schedule_week.dart`; day/shift/swap enums in `lib/core/enums/schedule_day.dart` · `schedule_shift.dart` · `swap_status.dart` |
| **Schedule/swap reads/writes (Firestore)**| `lib/features/schedule/data/datasources/schedule_remote_datasource.dart` (`weekly_schedules` + `shift_swaps`) + `data/repositories/schedule_repository_impl.dart` (+ `domain/repositories/schedule_repository.dart`) |
| **Schedule logic / week+branch nav / assign-remove** | `lib/features/schedule/presentation/cubit/schedule_cubit.dart` + `schedule_state.dart` |
| **Shift-swap workflow / status transitions** | `lib/features/schedule/presentation/cubit/shift_swap_cubit.dart` + `shift_swap_state.dart` |
| **Shift-swap "future shifts only" rule**  | `lib/features/schedule/domain/swap_eligibility.dart` (`SwapEligibility.slotStart`/`isRequestable`/`pastShiftMessage`) — enforced in `ShiftSwapCubit.requestSwap` (gate) + `swap_view.dart` (sheet `_send`) + `firestore.rules` (`shift_swaps` create → `swapSlotInFuture`). Tested in `test/swap_eligibility_test.dart` |
| **Shift-swap exchange validation + approval (2026-06-26)** | Rules in pure `lib/features/schedule/domain/swap_validation.dart` (`SwapValidation.check` — slot integrity · role compat · double-booking · rest hours) + `swap_policy.dart` (`SwapPolicy` on `branches/{id}.swapPolicy`; `UserEntity.position`). **Authority** = callable **`approveSwap`** in `functions/index.js` (re-validate + atomic `runTransaction` exchange), reached via `ScheduleRemoteDataSource.approveSwap` (`FirebaseFunctions`) ← `ScheduleRepositoryImpl.managerApproveSwap`. Config UI: `branch_form_sheet.dart` (Swap rules) + `admin_user_sheets.dart` (`showSetPositionSheet` → `AdminUsersCubit.changePosition`). Tested in `test/swap_policy_test.dart` + `test/swap_validation_test.dart`. ⚠️ Deploy `functions,firestore:rules` |
| **Admin all-branch swap visibility**      | `ScheduleRepository.getAllSwaps()` (+ datasource + impl) → `ShiftSwapCubit.pendingSwaps()` (one-shot, non-emitting, for the Admin Home count) **and** `ShiftSwapCubit.loadAll()`/`SwapScope.all` (the list state for the admin swap **queue modal** opened from the floating `SwapAlertCard` inside the schedule grid) |
| **Schedule = assignments, not quotas** | The grid shows **assigned head-count only** — no required/target/understaffed model (removed deliberately; admin assigns by judgment). Cell density + "Empty" come from `validAssignments(...).length` in `shift_cell.dart`; the only signals are *empty* (neutral) and *broken reference* (flagged). |
| **Schedule orphan / broken-reference handling** | `schedule_helpers.dart` (`isOrphanAssignment` / `validAssignments` / `orphanAssignments`) → `broken_assignment_banner.dart` (`brokenSlots` + `BrokenAssignmentBanner` + resolve sheet Remove/Reassign) and `shift_details_sheet.dart` (per-slot orphan row). A slot uid that isn't a current branch member is excluded from coverage and flagged as "Former employee" — **never** shown as a uid or fake "Unknown" name. Tested in `schedule_helpers_test.dart` |
| **Schedule screens (admin/manager/employee)** | `lib/features/schedule/presentation/pages/` (`schedule_management_screen` admin · `branch_schedule_screen` manager — **single operations-grid surface**, swaps via floating alert; `my_schedule_screen` employee — My Week + Swaps; past slots show "Past" not a Swap action) → shared `widgets/manager_schedule_view.dart` (the grid surface) · `swap_view.dart` (`SwapListView`, `showBranch` for the admin queue) |
| **Schedule grid / cell / sheets (reusable widgets)** | `lib/features/schedule/presentation/widgets/`: `schedule_grid.dart` (`ScheduleGrid`) · `shift_cell.dart` (`ShiftCell` — assigned-count density tile, no quota) · `employee_row.dart` (`EmployeeRow`) · `shift_details_sheet.dart` (`showShiftDetailsSheet`) · `swap_alert_card.dart` (`SwapAlertCard` + `showSwapQueueSheet`) · `broken_assignment_banner.dart` · `employee_picker_sheet.dart` (`showEmployeePicker`) · `sheet_chrome.dart` (`SheetHandle`). Tested in `test/schedule_grid_test.dart` |
| **Schedule routes / role entry point**    | `lib/core/routes/route_names.dart` (`adminSchedule`/`managerSchedule`/`mySchedule` + `scheduleForRole`) + `app_router.dart` + `role_scaffold.dart` (calendar icon → Schedule) |
| **Schedule/swap DI wiring**               | `lib/core/di/injection.dart` (`scheduleCubit`/`shiftSwapCubit`) + `main.dart` providers |
| **Broadcast schema / serialization**      | `lib/features/communications/domain/entities/broadcast_entity.dart` (+ `category`/`targetUserId`/`recipientCount`, Phase 2) + `data/models/broadcast_model.dart` (then run codegen) + `lib/core/enums/broadcast_audience.dart` (`BroadcastAudience` — allBranches/branch/**user**; `''` = all-branches sentinel, `'__direct__'` = DM marker) |
| **Broadcast recipient-resolution / permissions** | `lib/features/communications/domain/broadcast_permissions.dart` (`BroadcastPermissions.canSend`/`allowedAudiences`/`validate` — admin: all/branch/user · manager: own-branch/user-in-branch · employee: none) — the client guard; **re-enforced in `functions/index.js`** + `firestore.rules`. Tested in `test/broadcast_permissions_test.dart` |
| **Broadcast SEND engine (Cloud Function)** | `functions/index.js` (callable `sendBroadcast`: validate perms → resolve recipients → write `broadcasts/{id}` → gather `users.fcmTokens` → `messaging.sendEachForMulticast` → prune dead tokens → return `{success, recipientCount, deliveredCount, broadcastId}`) + `functions/package.json` + `firebase.json` (`functions`). Deploy: `firebase deploy --only functions` |
| **Broadcast send (client path)**          | `BroadcastCubit.send(...)` (client guard via `BroadcastPermissions`, returns recipientCount) → `SendBroadcast` use case → `BroadcastRepositoryImpl` → `BroadcastRemoteDataSource.sendBroadcast` (invokes the callable via `FirebaseFunctions`, `toCallablePayload()`) |
| **Broadcast feed (Firestore read)**       | `lib/features/communications/data/datasources/broadcast_remote_datasource.dart` `watchBroadcasts` (`broadcasts/{id}`; admin `orderBy(createdAt)`, branch `where('branchId', whereIn:[branch,''])` client-sorted; DMs excluded via the `'__direct__'` marker) → `BroadcastCubit.load({branchId})` |
| **Broadcast repository / use case / state** | `domain/repositories/broadcast_repository.dart` (+impl) · `domain/usecases/send_broadcast.dart` (`SendBroadcast`) · `presentation/cubit/broadcast_cubit.dart` + `broadcast_state.dart` |
| **Broadcast DI wiring / provider**        | `lib/core/di/injection.dart` (`broadcastCubit`; datasource takes `FirebaseFirestore` + `FirebaseFunctions`) + `main.dart` provider + `AppConstants.broadcastsCollection` + `firestore.rules` (`broadcasts/{id}` — **client writes denied**, function-owned) |
| **FCM device token storage (multi-device)** | `lib/core/services/notification_service.dart` — `registerToken`/`_rotateToken` (`users/{uid}.fcmTokens` `arrayUnion`, refresh-aware), `forgetUser` (`arrayRemove`). Read server-side by `functions/index.js`. Registered via `main.dart` (`AuthCubit` listener). **Token removal runs PRE-sign-out (2026-06-26):** `AuthCubit.signOut()`'s `onPreSignOut` hook (DI → `forgetUser`) drops the token **while still authenticated** — the post-sign-out listener write is permission-denied. Server `claimFcmToken` reconciles force-kill/offline logouts (exclusive ownership; no cross-account leak). **Layered defense (2026-06-26):** every push is stamped `data.recipientUid` (broadcast via `messaging.sendEach` per-token; task push per-recipient); the client (`_isForCurrentUser`) **drops** any foreground/tap push whose `recipientUid != _uid` + self-heals (re-register → `claimFcmToken` reclaims) — so a drifted token can never surface to the wrong user. `dispatchBroadcast` logs `tokenDriftCount` (same token on 2 recipients in a send). Residual: a backgrounded app's OS banner for a drifted token isn't client-suppressible (tap still guarded) |
| **FCM receive handling (fg/bg/tap)**      | `lib/core/services/notification_service.dart` (`onMessage` → `onForeground`; `onMessageOpenedApp` + `getInitialMessage` → `onMessageTap`) + `lib/main.dart` (background top-level handler, foreground snackbar via `_messengerKey`, tap → `_router.go(home)` + log `broadcastId`) |
| **Communications Center UI (feed/compose/detail)** | `lib/features/communications/presentation/pages/` (`communications_screen.dart` feed + FAB · `compose_broadcast_screen.dart` role-gated form · `broadcast_detail_screen.dart`) + `widgets/broadcast_card.dart` + `presentation/communications_format.dart` (time/audience/category formatting). Card render tested in `test/broadcast_card_test.dart` |
| **Communications routes / entry point**   | `route_names.dart` (`communications` `/communications` · `communicationsCompose` `/communications/compose` · `communicationsDetailPattern` `/communications/:broadcastId` + `communicationsDetail(id)`) + `app_router.dart` (3 routes, declared compose-before-detail; `_isCommunicationsArea` guard — admin + manager, employees bounced) + `role_scaffold.dart` (campaign icon, admin/manager only) |
| **Broadcast category (announcement/alert/reminder/emergency)** | `lib/core/enums/broadcast_category.dart` (`BroadcastCategory` — value/label/isUrgent/fromString; pure Dart, icon+colour mapping in `communications_format.dart`). Tested in `test/broadcast_category_test.dart` |
| **Broadcast compose pickers (branch/recipient)** | `BroadcastCubit.branches()` / `branchUsers(branchId)` (repo-direct, `BranchRepository` + `GetUsersByBranch`, mirrors `TaskCubit`) — wired in `injection.dart` |
| **Broadcast delivery stats (recipient/delivered)** | `recipientCount` (write time) + `deliveredCount` (post-multicast `broadcastRef.update`) on `broadcasts/{id}` — set by `functions/index.js`, read via `BroadcastModel`/`BroadcastEntity`, shown on `broadcast_card.dart` + `broadcast_detail_screen.dart` |
| **Multiline text field**                  | `lib/features/auth/presentation/widgets/app_text_field.dart` (`maxLines`/`minLines`, default 1; ignored when `obscureText`) — used by the broadcast body |
| **Dashboard screens (live stats)**        | `admin_dashboard_screen.dart` (**command center, 2026-06-19** — `DashboardMetricCard` grid + hero + activity feed; see "Admin Home (command center)") · `manager/.../manager_home_screen.dart` (shared `statistics/presentation/widgets/stat_grid.dart` — `StatGrid` + `StatGridSkeleton`, + `HeroStatCard`) · `employee/.../employee_home_screen.dart` (**bespoke, redesign v2** — own `_HeroTodayCard`/`_ProgressRing`/`_RingPainter`/`_StatStrip`/`_HomeTaskCard` with inline actions; task counts from the live `TaskCubit` list, shift from `StatisticsCubit`) |
| **Push notifications (FCM)**              | `lib/core/services/notification_service.dart` + `core/enums/notification_type.dart`; wired in `main.dart` (background handler, init, token register on auth, foreground snackbar) |
| **Admin routes**                          | `lib/core/routes/route_names.dart` (`adminBranches`/`adminManagers`/`adminEmployees`/`adminAnalytics`/`adminApprovals`) + `app_router.dart` (under `_isAdminArea`) |
| **Admin Home (command center)**           | `lib/features/admin/presentation/pages/admin_dashboard_screen.dart` — greeting · hero (most-urgent insight) · **Pending Actions** panel (the public `PendingActions` widget: swaps · approvals · reviews · overdue — replaced the recent-activity feed 2026-06-20; **always rendered**, shows an "all caught up" state when empty) · `DashboardMetricCard` grid · `ActionCard` quick actions · pending-approvals preview · Manage grid. Reads `StatisticsCubit` + `TaskCubit` (all-branches stream, for overdue) + `AdminUsersCubit.pendingUsers()` + `ShiftSwapCubit.pendingSwaps()` |
| **Admin Pending Actions panel (widget)**  | `lib/features/admin/presentation/widgets/pending_actions.dart` (`PendingActions` — presentational: counts + callbacks; widget-tested in `test/pending_actions_widget_test.dart`) |
| **Premium card surface (shared)**         | `lib/core/widgets/glass_container.dart` (`GlassContainer` — gradient·border·depth·press/hover; built on by `DashboardMetricCard`/`ActionCard`/`HeroStatCard`/`AdminUserCard`/`EmployeeCard`) |
| **Dashboard metric / quick-action / section-header tiles** | `lib/core/widgets/dashboard_metric_card.dart` · `action_card.dart` · `admin_section_header.dart` |
| **Vertical timeline row (shared)**        | `lib/core/widgets/timeline_tile.dart` (`TimelineTile`) — used by the Task Details activity timeline (the admin recent-activity feed was replaced by Pending Actions 2026-06-20) |
| **Task activity label/colour/time format**| `lib/features/task/presentation/activity_format.dart` (`activityTitle` / `activityColor` / `relativeTime`) |
| **Employee card + performance metrics**   | `lib/features/admin/presentation/widgets/employee_card.dart` (`EmployeeCard`) + `lib/features/admin/presentation/employee_metrics.dart` (`EmployeeMetrics` + `computeEmployeeMetrics` — derived from the task stream; pending preview via `AdminUsersCubit.pendingUsers()`) |
| **Admin Analytics (full metric wall)**    | `lib/features/admin/presentation/pages/admin_analytics_screen.dart` (route `/admin/analytics`; reuses `StatGrid`) |
| **Branches page (premium cards + search)**| `lib/features/branch/presentation/pages/branch_management_screen.dart` (manager + employee counts via `AdminUsersCubit.usersWithRole`) |
| **Admin user cards / search + filters**   | `admin_user_card.dart` (avatar-led, on `GlassContainer`; Managers/Approvals) · `admin_users_list_view.dart` (search) · `employee_management_screen.dart` (search + active/inactive + branch; renders **`EmployeeCard`** with the perf metric strip) |
| **Schedule UI polish (cells/avatars/rows)** | Manager/admin: the grid widgets above (`shift_cell.dart`, `employee_row.dart`) + `schedule_helpers.dart` (`userForUid`/`roleLabel`). Employee: `pages/my_schedule_screen.dart` |
| **Admin/branch DI wiring**                | `lib/core/di/injection.dart` (`branchCubit`/`adminUsersCubit`/`adminStatsCubit`) + `main.dart` providers |
| **A role's home/dashboard screen**        | `lib/features/{employee,manager,admin}/presentation/pages/`              |
| **Shared role chrome (header + bottom nav)** | `lib/core/widgets/role_scaffold.dart` (header bell/avatar + bottom nav) → `lib/core/widgets/app_bottom_nav.dart` (`AppBottomNav` + `AppNavItem`) |
| **Signed-in user/role off a context**     | `lib/core/extensions/context_extensions.dart` (`context.currentUser` / `context.currentRole`) |
| **Confirmation / delete dialogs**         | `lib/core/widgets/app_dialog.dart` (`showConfirmDialog(...)`)            |
| **Form fields (text / password / dropdown)** | `lib/features/auth/presentation/widgets/` — `app_text_field.dart` (`AppTextField`: label·hint·prefix·suffix·readOnly·onTap·built-in show/hide), `app_password_field.dart` (`AppPasswordField`), `app_dropdown_field.dart` (`AppDropdownField<T>` — branch/role/status/priority) |
| **Primary / secondary / ghost buttons**   | `lib/features/auth/presentation/widgets/app_button.dart` (`AppButton` · `AppButton.secondary` · `AppButton.ghost`) |
| **Reusable card shell / empty state**     | `lib/core/widgets/app_card.dart` (`AppCard` — surface·radius 24·press·hover) · `app_empty_state.dart` (`AppEmptyState`; `TaskEmptyState` delegates to it) |
| **Status pills (task/approval/swap/active)** | `lib/core/widgets/status_badge.dart` (`StatusBadge` + `.task`/`.approval`/`.swap`/`.active` factories — colour+label in one place; **`.task` is the canonical task-status chip**) |
| **Role checks / feedback off a context**  | `lib/core/extensions/context_extensions.dart` (`context.isAdmin`/`isManager`/`isEmployee`, `context.showSuccess`/`showError`) |
| **Firestore Timestamp→DateTime mapping**  | `lib/core/extensions/firestore_extensions.dart` (`map.date('field')` in every `*Model.fromMap`) |
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
| **App brand / logo (the DROP wordmark)**  | artwork `assets/drop_logo.png` (registered in `pubspec.yaml`) rendered by `lib/core/widgets/drop_logo.dart` (`DropLogo`, white-tinted via `srcIn`, sized by `height`) — used on splash, login, register, pending-approval; app name in `main.dart` (`title`) + `AppConstants.appName` |
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
- Premium card surfaces use **`GlassContainer`** (the shared gradient/border/
  depth surface with press+hover feedback) — build cards on it (e.g.
  `DashboardMetricCard`, `ActionCard`, `EmployeeCard`) rather than re-declaring
  the gradient `BoxDecoration`. Vertical timelines use the shared `TimelineTile`.
- User feedback uses `AppSnackbar.success/error`, never raw `ScaffoldMessenger`.
- Loading placeholders use `Skeleton`.
- Pull spacing/radius from `AppSpacing` / `AppRadius`; never hardcode.

### Theme conventions
- The app is **dark-mode only** today (`themeMode: ThemeMode.dark`); a `light`
  theme exists in `AppTheme` but is not wired up.
- **Strictly monochrome** (black / white / grey): `AppColors.primary` is white —
  the only accent. It carries every primary action, focus state, active bottom-nav
  tab, and key highlight. Text/icons that sit **on** the white accent use
  `AppColors.onPrimary` (dark). Use `primarySurface` (white ~12% wash) for tinted
  tiles / the active nav pill; `primaryGradient` is a white→grey (≈ flat white)
  accent fill; `primaryGlow(...)` is kept **flat** (no shadow). The only chromatic
  colors are the semantic `success` / `error` / `warning` (status only).
- Never use raw `Color(...)` or `TextStyle(...)` in features — reference
  `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`. A primary fill is the
  white `primary`/`primaryGradient` (dark `onPrimary` text).
- Global component styling (inputs, buttons, app bar) lives in `AppTheme`; tune
  it there rather than per-widget.
- **Role chrome is a bottom navigation bar.** `RoleScaffold` hosts each role
  dashboard under a header (bell + avatar → profile) and an `AppBottomNav`
  (Home · Tasks · Schedule · Profile); tabs push the role-scoped routes
  (`tasksForRole`/`scheduleForRole`/`profile`). Add cross-role nav here.

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
  - **employee** — limited to their own assigned data and profile. **Exception
    (read-only):** any branch member (employee included) may **read** other
    `users` in their own branch — needed so the weekly schedule can show the
    coworkers on a shift and the branch manager (`selfBranch() != '' &&
    branchId == selfBranch()`). Writes to user docs stay admin-only.
- **Account approval (activation gate).** A new sign-up is **not** usable: it is
  seeded as a `pending` + `isActive: false` employee with no branch and is
  confined to the **Pending Approval** screen. A manager/admin approves it
  (`approvalStatus → approved`, `isActive → true`, assigns role + branch); only
  then does it reach a role shell. Gate logic = `UserEntity.hasAppAccess`
  (`isApproved && isActive`), checked in the router redirect **before** role
  dispatch. `ApprovalStatus.fromString` defaults missing → `approved` so legacy
  docs aren't locked out; **new** accounts are explicitly seeded `pending`.
  **Approval is ADMIN-ONLY (Phase 6)** — managers manage branch operations
  (shifts/tasks), not user accounts; only an admin approves/rejects, assigns
  role/branch, and (de)activates (mirrored in `firestore.rules`). The **first
  admin** must be bootstrapped out of band (Firebase console).
- **Privileged fields** (`role`, `branchId`, `isActive`, `assignedShift`,
  `approvalStatus`) are seeded **once** in the `saveUser` first-creation block
  and are kept **out of `UserModel.toMap()`**, because `saveUser` merges on every
  login — including them would reset an admin's role / re-pend an approved
  account on the next sign-in. Self cannot change these (enforced by
  `firestore.rules`); only an **admin** may. (Self may still write
  non-privileged fields like `fcmToken`.)
- **Enforcement** lives in `firestore.rules`: reusable `isAdmin()`/`isManager()`/
  `selfBranch()`/`canReachBranch(branch)` helpers read the requester's own user
  doc. **`tasks/{taskId}` (Phase 3, +Phase 9 multi-assignee)** is the
  branch-scoped collection wired to `canReachBranch()` (admin all · manager
  own-branch · employee own assigned data). Tasks
  allow the **assigned employee a limited self-update** (advance
  status / tick checklist items / add notes / proof, but not reassign, move
  branch, or approve/reject); the assignee check is `request.auth.uid in
  assigneeIds` (Phase 9, legacy `assignedEmployeeId` fallback).
  (The Phase 2 `shifts/{shiftId}` rules were removed in Phase 10 with the shift
  feature.)
  **`task_templates/{id}` (Stabilization)** are manager/admin-readable reusable
  blueprints; create/update/delete are admin (global/any) or own-branch manager —
  employees never read them. **`branches/{branchId}` (Phase 5)** is admin-write /
  any-signed-in-read (a
  branch isn't branch-scoped *data* — it defines the branches), with "delete" as
  a soft delete (admin update). Admin user-administration writes go through the
  existing `users` admin-update rule (`isAdmin()`). **`weekly_schedules/{id}` and
  `shift_swaps/{id}` (Phase 7)** are branch-scoped via `canReachBranch()`: a
  schedule is **admin / own-branch-manager write** and **readable by any employee
  of the branch** (`branchId == selfBranch()`, so they see their roster + today's
  team); a swap is read/written by the two involved employees and the branch
  manager/admin, with **create** restricted to the requester in their own branch
  (the status order is validated client-side in `ShiftSwapCubit`). **Update denies
  any client write setting `status==managerApproved`** (2026-06-26) — the final
  exchange is applied only by the Admin-SDK `approveSwap` function (re-validate +
  atomic transaction); coworker-accept / cancel / reject client writes are
  unaffected. The `users` self-update rule also freezes the admin-set `position`.
  **`broadcasts/{id}` (Communications Center — Phase 1 + Phase 2 engine)**:
  **read** = admin, OR the individual recipient of a direct message
  (`targetUserId`), OR a branch member of a branch/all-branches broadcast
  (`branchId == '' || branchId == selfBranch()`). **All client writes are
  denied** (`create, update, delete: if false`) — the `sendBroadcast` Cloud
  Function (Admin SDK, which bypasses rules) is the sole writer and enforces the
  send-permission matrix server-side. A DM carries the `'__direct__'` branchId
  marker so it never appears in a branch/all feed query.
- Routes are role-guarded in the GoRouter `redirect`: admin areas are
  admin-only, manager areas admit **manager + admin** (the hierarchy), the
  employee home (`/`) is employee-only. Add a new role area as a path prefix
  with an `_isXArea` helper + a guard line, and extend `RouteNames.homeForRole`.
  Never gate role access in the UI only.
- New role-facing screens are presentation-only features
  (`features/<role>/presentation/pages/`) wrapped in a `RoleScaffold`.

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
