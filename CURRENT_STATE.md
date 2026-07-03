# DROP — Current State

> Product: **DROP — Operations Management System** (Dart package id is `drop`).
>
> **Live status snapshot of the project.** Read this after
> [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) to know what's done, what's pending,
> and what needs configuring. This file answers "where are we right now?" —
> architecture/how-it-works lives in PROJECT_CONTEXT.md; history lives in
> [CHANGELOG.md](CHANGELOG.md).
>
> **Keep this current** — update it before finishing any task (see
> [Documentation Maintenance](PROJECT_CONTEXT.md#5-documentation-maintenance)).

**Last updated:** 2026-07-03 (note categories + feed telemetry — Home Dashboard redesign)
**Version:** 1.0.0+1 · **Branch:** `feature/macos-desktop` (DROP — monochrome premium desktop UX)

---

## ✅ Home Dashboard redesign — note categories + feed telemetry (2026-07-03)

- **Smart Queue is opt-in** — default sort reverted to **Due date (grouped)**;
  Smart stays an explicit sort mode (validate before promoting).
- **Note categories** — `NoteCategory` (info / warning / issue) stored as the
  note's activity kind (no schema change); `addNote(category:)`; distinct
  timeline title/colour/icon; note sheet has a category selector.
- **Animated attention counters** — the strip always renders 3 pills (muted at
  zero) so `AnimatedCount` tweens smoothly through any change.
- **Lightweight feed telemetry** — `UsageTracker` (`core/services`): a single
  `usageStats/feed` counters doc (`FieldValue.increment`), debounced ~one
  write/20s, best-effort, test-safe. Tracks `preset_{name}` · `sort_{name}` ·
  `expansion_open` · `quick_approve` · `note_create`. New `usageStats/{doc}`
  rule (signed-in write, admin read).
- `flutter analyze` clean (7 pre-existing infos) · **343 tests pass** (+2).
  ⚠️ **Deploy:** `firebase deploy --only firestore:rules` (telemetry). Read data
  at `usageStats/feed` in the console. Full urgency engine still deferred.

---

## ✅ Home Dashboard redesign — R1 refinements + Smart Queue (2026-07-03)

Owner: three R1 refinements + a lightweight Smart Queue before the full urgency
engine. Presentation-only except one additive cubit method.

- **Attention strip: Blocked → Unassigned** (owner ruling). Now Overdue ·
  Pending review · Unassigned (individual/team tasks with no assignee).
- **Proof-safe approve** — a submission with proof shows a confirm sheet
  (thumbnails + Approve/Cancel) before approving; proofless stays one-tap.
- **Sticky action footer** — actions extracted into `TaskFeedActions`; the
  mobile bottom sheet pins them as a footer.
- **Quick manager notes** — `Note` action → `TaskCubit.addNote` appends a `note`
  activity entry (no status change; new `note` kind in `activity_format`).
- **Smart Queue (P3-lite)** — `FeedSort.smart` (now the **default**): 5-tier
  `smartRank` (overdue+high · review · overdue · today · normal), flat ranked
  list; other sorts restore grouping. Not the full urgency engine yet.
- `flutter analyze` clean (7 pre-existing infos) · **341 tests pass** (+5).
  ⚠️ On-device QA: approve-confirm + note sheets; Smart Queue order. Full urgency
  engine (`task_urgency.dart` + reviewer/executor lens) still deferred.

---

## ✅ Home Dashboard redesign — R1 shipped: inline expandable row + Attention strip (2026-07-03)

Owner priority after P2 (before P3). The feed row now triages in place —
Branch→Employee→Task **and** the tap-into-details step are both gone for routine
actions. Presentation-only.

- **`task_feed_expansion.dart`** — ONE shared triage surface (description ·
  branch/shift/due/assignee · checklist + progress · attachment thumbnails ·
  compact timeline · Approve/Reject/Reassign/Open-full-details). Actions read the
  app-wide `TaskCubit` lazily on tap (no new cubit).
- **Desktop = inline accordion** (`_expandedId`, one open at a time; `AnimatedSize`
  height + fade; scroll preserved). **Mobile = bottom sheet**
  (`DraggableScrollableSheet`). `context.isDesktop` picks the presentation.
- **Attention Needed strip** above the feed — Overdue · Pending review · Blocked
  counts (scope active set, filter-independent); tappable → filters. **"Blocked"
  = `rejected`/rework — owner to confirm** (vs. unassigned).
- `flutter analyze` clean (7 pre-existing infos) · **336 tests pass** (+6). Next:
  **P3 urgency engine → "Smart" sort**. ⚠️ On-device QA: accordion + mobile sheet.

---

## ✅ Home Dashboard redesign — P1 + P2 shipped: global task feed on the homepage (2026-07-03)

Owner re-prioritized: homepage usability + active-task discoverability first,
retention read-bounding last (P4, paused). Presentation-only — **nothing to
deploy**.

- **P1 — badge dedupe (the flagged bug):** `taskBadgeFor` no longer returns
  `Approved`/`Rejected` (the status pill already shows them → the word stacked
  twice). Badge = `REWORK #n` / `NEW` only.
- **P2 — global active-task feed** on the admin + manager homes (reach any task
  in ≤2 taps, no Branch→Employee→Task drill):
  - `task_feed.dart` — pure engine (filters · presets · search · sort ·
    grouping), 23 tests.
  - `task_feed_row.dart` — dense scannable row, 5 tests.
  - `task_feed_section.dart` — composable homepage feed over the app-wide
    `TaskCubit` (no new cubit/query); tap → `TaskDetailsScreen`.
  - Wired into `AdminDashboardScreen` (**replaced + deleted** the redundant
    `_ActivityFeed`) and `ManagerHomeScreen` (`branchLocked`; now loads
    `TaskCubit`).
- **Deferred:** urgency "Smart" sort (P3, next); inline row-expansion triage
  surface (R1). `flutter analyze` clean (7 pre-existing infos) · **330 tests
  pass** (+28). ⚠️ On-device visual QA suggested (feed density on a phone).

---

## ✅ Home Dashboard redesign — proposal + P3 lifecycle shipped (2026-07-03)

Full UX/architecture proposal in
[HOME_DASHBOARD_REDESIGN.md](HOME_DASHBOARD_REDESIGN.md) (global task feed on
the homepage · dense rows + expandable triage surface · KPIs-as-filters ·
urgency ranking engine · monochrome per the locked ruling · retention costed).
Owner reviewed, chose **monochrome** and **P3 (lifecycle) first**.

**P3 shipped — completed tasks stop cluttering active views:**
- `TaskEntity.archivedAt` + `isArchived`; `TaskModel` round-trips it (written in
  `toMap` only so an admin reopen clears it — always null on a live task).
- `TaskRepositoryImpl._newestFirst` filters archived out of **every** active
  list/stream (single clutter gate). `getTask` bypasses it (deep-links resolve);
  statistics read Firestore directly (lifetime counts intact).
  `TaskCubit.reopenTask` clears `archivedAt`.
- **`taskHousekeeping`** Cloud Function (`onSchedule` 24h): archives approved
  tasks > `archiveAfterDays` (default 30) → stamps `archivedAt` + cold-tiers
  `tasks/{id}/` Storage to COLDLINE; **hard-delete opt-in** (`deleteAfterDays`
  null by default = soft-archive-forever). Cursor-paged archive query (no
  composite index, outage-tolerant). Config `config/taskRetention` (defaults).
- **Kept archive in-place** (not a separate collection): stats count approved
  from `tasks`, and the Firestore `isNull` missing-field gotcha would make a
  server-side filter need a migration. *Server-side* read-bounding deferred +
  costed (not needed at current volume).
- `flutter analyze` clean (7 pre-existing infos) · **302 tests pass** (+6
  `task_archive_test.dart`) · `node --check` OK · freezed regenerated.
- ⚠️ **Deploy (owner, surgical):** `firebase deploy --only
  functions:taskHousekeeping`. No rules/indexes/storage-rule change. Rollback =
  `firebase functions:delete taskHousekeeping`. Remaining redesign slices (P1
  quick wins, P2 feed + urgency engine) not yet built.

---

## ✅ Production blockers FIXED + DEPLOYED (2026-07-03)

All six audit blockers closed against production `bazic-d9ad7` (each verified
after deploy; per-blocker commits):

1. **C1a `tasks` composite index — DEPLOYED, READY.** Audit correction: the
   probe proved the equality-only `watchShiftTasks` query ran WITHOUT the
   composite (merge join) — production was never broken; the deploy aligns
   repo config + makes it a direct index scan.
2. **C1b `generateShiftTaskInstances` — DEPLOYED** (surgical, first v7-SDK
   build). Scheduler job ENABLED; forced run executed clean
   (`templates: 0, created: 0` — no recurring templates in prod yet).
   Rollback = `firebase functions:delete generateShiftTaskInstances`.
3. **C2 salary privacy — MIGRATED.** Compensation now lives in
   `users/{uid}/private/compensation` (read: owner+admin ONLY — managers
   excluded; write: admin, owner may touch only `paymentNumber`). The four
   fields are REMOVED from `UserEntity`/`UserModel` (public fetch can never
   carry salary); admin surfaces load it on demand
   (`AdminUsersCubit.compensationFor`); profile `paymentNumber`
   overlays/writes the subdoc. `tool/migrate_compensation.js` ran against
   production: **1/1 user migrated, 0 residue, readback-VERIFIED** (backup
   JSON on disk, gitignored; `--rollback` supported).
4. **M2 notification forgery — CLOSED.** New **`sendNotification` callable**
   (type whitelist: 5 task + 4 swap types · recipients must be admin-reachable
   or same-branch · title/body caps · sanitized payload keys ·
   **server-stamped senderUid**); client datasource now calls it;
   `notifications` `create: if false` deployed. Push trigger unchanged.
5. **M1 swap consent forgery — CLOSED.** `shift_swaps` update rule now
   enforces per-party transitions: TARGET only may set
   `employeeApproved`/`rejected` (from pending); REQUESTER only `cancelled`
   (from pending/employeeApproved); employee writes field-locked to
   `status`+`updatedAt`; `managerApproved` stays function-only (`approveSwap`
   already gates on current status == employeeApproved — verified).
6. **M3 proof tampering — CLOSED.** Storage `tasks/**` is now **create-only**
   (update/delete denied). Every upload already mints a unique Firestore push
   id (verified: no fixed `proof.jpg` path remains in lib/), so evidence is
   immutable from the moment of upload — rework loops add new files.

**Also (owner ruling):** Edit Profile's self-service sections (Contact
details + Salary payment number) and the "Salary sent to" profile row are
**manager/employee-only — hidden for admin** (the admin manages compensation,
never receives it in-app; admin saves never write those fields).

`flutter analyze` clean (7 pre-existing infos) · **296 tests pass** (+3) ·
functions fleet: 11 deployed (2 new). ⚠️ Remaining from the audit (not in
this scope): C1c stale-fleet redeploy (9 functions still on the 2026-06-26
build — diagnostics-only gap), C3 iOS push entitlement (owner, Xcode).

## ✅ Schedule 4.0 — overflow · mobile actions · undo · validation (2026-07-02)

The stabilize-then-finish pass (owner phase plan). **Phase 1 (bugs):** the
mobile blank-My-Week bug was already fixed + guarded (verified,
`my_schedule_tab_test.dart` green); closed the last "schedule disappears on
navigation" path — `ScheduleCubit.load` is now **silent on a same-scope
reload** (revisit/pull-to-refresh keeps the view on screen; unchanged data →
no emission; a real branch/week change still shows the loader;
`schedule_silent_reload_test.dart`), and `_MyWeekTab`'s `orElse` renders the
loader, never a blank. Cubit stream/listener audit clean (all stream cubits
cancel on close; TaskCubit scope-keyed; NotificationService recipient-guarded).

**Phase 2 (Schedule 4.0), all in the manager/admin grid:**

1. **Crowded cells** — ≤4 people: all chips; >4: first 3 + tappable
   **“+N more”** → the shift panel. Hover “+ assign” hides at capacity.
2. **Mobile actions** — long-press a chip → premium action sheet
   (`chip_action_sheet.dart`): **Move** (mini week map; invalid slots show
   their reason), **Switch** (pick (person, slot) → trade preview → confirm),
   **Remove**. Desktop right-click gains “Switch shifts with…” → same flow.
3. **Undo (5s)** — every move/exchange/remove records its exact inverse on
   `ScheduleCubit` (`canUndo`/`undoLast`, single-use, invalidated by newer
   mutations); monochrome UNDO snackbar for the window.
4. **Validation** — pure `domain/move_validation.dart`: double-booking
   **blocked** with the day named; exchange position-compatibility follows
   the branch `SwapPolicy` (same rule as employee swaps); emptying a shift =
   **confirm, not block** (facts, never quotas). All edit paths funnel
   through validated helpers in `manager_schedule_view`.
5. **Approval integrity (audited)** — drag-to-switch cannot bypass approvals:
   employees have no `weekly_schedules` write path (rules), swap final
   approval is function-only. Manager/admin direct edit = sanctioned instant.

`flutter analyze` clean (7 pre-existing infos) · **293 tests pass** (+25:
move_validation 10 · undo 6 · silent-reload 4 · action-sheet/overflow 4 + 1).
macOS debug build + web release build green.
⚠️ On-device QA: long-press sheet on a phone, undo snackbar timing.

**Phases 3–5 deliverables (repo root):**
[PRODUCTION_AUDIT_2026-07-02.md](PRODUCTION_AUDIT_2026-07-02.md) —
🔴 C1 **verified against production** (`bazic-d9ad7`): rules + storage rules
are LIVE and byte-identical; what's missing = the **`tasks` composite index**
(employee shift streams fail `failed-precondition`) + the
**`generateShiftTaskInstances` function** (fleet last deployed 2026-06-26,
now on a stale `firebase-functions` v6) — deploy order: indexes → surgical
function → fleet · C2 salary-read exposure (design property, unaffected by
deploys — subdoc migration planned) · C3 iOS push entitlement;
[BETA_CHECKLIST.md](BETA_CHECKLIST.md) — pre-flight + role walkthroughs +
S1–S10 scenario drills + lean feedback-collection design (unbuilt, ~½ day);
[AUTO_SCHEDULE_DESIGN.md](AUTO_SCHEDULE_DESIGN.md) — Phase 5 architecture
(greedy+repair pure-Dart generator; design only, no code).

---

## ✅ Admin swap requests — one tap from Pending Actions (2026-07-02)

The admin home's "N Swap Requests" row used to push `/admin/schedule`, which
lands on "Pick a branch" — the admin had to select the branch and find the
swap chip manually. It now opens **`showSwapQueueSheet`** directly (the
all-branches actionable queue; `ShiftSwapCubit.loadAll()` is already live on
the dashboard, and approve/reject work in-sheet). Manager/employee paths were
already direct (fixed-branch strip chip / inline Home section). A ⌘K palette
swaps entry was deliberately skipped (palette is route-based; one-off callback
machinery = over-engineering). `flutter analyze` clean · **268 tests pass**.

---

## ✅ macOS app icon + animated brand logo (2026-07-02)

**Dock/Finder icon is now the DROP brand:** Big Sur squircle (dark monochrome
gradient + hairline border + white wordmark), composed from
`assets/drop_logo.png` by a Swift/AppKit script → master at
`assets/icon/app_icon_macos.png` (1024²), all 7 sizes written into
`macos/Runner/Assets.xcassets/AppIcon.appiconset/`; `flutter_launcher_icons`
config gained a `macos:` block pointing at the master (Android/iOS untouched).
**Verified inside the built `DROP.app` bundle** (`AppIcon.icns` extracted and
inspected; macOS debug build green). If the Dock caches the old icon:
`killall Dock`. **Animated logo:** new **`AnimatedDropLogo`**
(`core/widgets/animated_drop_logo.dart`) — a soft diagonal light band sweeps
the ~88%-white wordmark once per ~3.2s (ShaderMask srcATop, rests between
passes, strictly monochrome). Live on the **Splash** lockup (under its
entrance fade/scale) and the **Login desktop brand panel**; chrome marks stay
static. `flutter analyze` clean · **268 tests pass** (+1).

---

## ✅ Schedule 3.1 — drag-to-switch + brand polish (2026-07-02)

Owner extended the Schedule 3.0 drag scope: dropping a dragged person **onto
another person's chip** now trades their slots (drag Ziad onto Richard → they
switch shifts). New **`ScheduleCubit.exchange`** (single busy cycle,
assign-both-first-then-release ordering — a failed write never strands anyone;
self-swap / same-slot = no-op); `AssignmentChip` doubles as a `DragTarget`
(primary ring + ⇄ cue when targeted) that wins the hit test over its host
cell, so chip-drop = switch while empty-cell-drop stays the existing move.
Wired via `onSwapChip` through `ShiftCell` → `ScheduleGrid` →
`manager_schedule_view` (admin + manager). Grid hint names the gesture. Brand:
quiet `DropLogo` signature on the hint row + both schedule empty states now
brand-led `DropEmptyState`. Covered by `test/schedule_exchange_test.dart`
(incl. a real chip-onto-chip drag). `flutter analyze` clean · **267 tests
pass** (+4). ⚠️ On-device QA: real-trackpad chip-onto-chip drop on the Mac.

---

## ✅ DROP logo rollout across the app chrome (2026-07-02)

Owner request: the real logo (`assets/drop_logo.png`) on the homepage and all
important screens. Done via the three shared chrome widgets (no per-screen
edits, strictly monochrome): **`RoleScaffold`** mobile app bar leads with a
`DropLogo` (22px) + title lockup on all three role homes; **`AppSidebar`**'s
desktop brand header now renders the real artwork (30px) instead of the
typographic `DropWordmark` (still used by `BrandWatermark`); and
**`AdaptiveScaffold`** gains `showBrandMark` (default on) — a quiet
non-interactive tertiary `DropLogo` (16px) closing every **mobile** app bar
(desktop is already branded by the persistent sidebar). Covered by
`test/brand_chrome_test.dart`. `flutter analyze` clean · **263 tests pass**
(+4). ⚠️ Visual QA suggested on a phone + the Mac (lockup sizing/spacing).

---

## ✅ Mobile blank "My Week" after Swaps tab — root-caused and fixed (2026-07-02)

Owner report: on mobile, Schedule → My Week rendered initially but went blank
after visiting the Swaps tab and returning (recovered only on manual refresh).
**Not a data/cubit bug** — `TabBarView` disposes the My Week tab on switch and
recreates it on return; its entrance `AnimationController` (starts at 0.0) was
only played from the `BlocConsumer` **listener**, which never fires because the
`ScheduleCubit` is still `loaded` with no new emission → the whole tab rendered
at **opacity 0**. Fixed in `my_schedule_screen.dart`: on mount, an
already-loaded cubit snaps the controller to 1.0 (stagger still plays on real
load/refresh). Also fixed there: `SwapListView` got `currentUid: ''` (user was
cached without `setState`) which hid all swap card actions — the uid is now
read at build time. Reproduced + guarded by `test/my_schedule_tab_test.dart`.
**Pattern rule: never gate an entrance animation solely on a bloc state
transition — sync it with the current state at mount (TabBarView recreates
tabs).** `flutter analyze` clean · **259 tests pass** (+1).

---

## ✅ Phase 3 — crash & logging infrastructure (2026-07-02)

Production-grade observability, centralized in two files:

- **[`core/observability/crash_reporter.dart`](lib/core/observability/crash_reporter.dart)**
  — global crash capture via 4 funnels (`FlutterError.onError` ·
  `PlatformDispatcher.onError` · `runZonedGuarded` around the whole bootstrap
  · isolate listener). Structured 🔴 CRASH report: timestamp / screen / route /
  user / role / error / full stacktrace / last action / last-30 breadcrumbs.
  **Persisted to `Application Support/last_crash.log` even in release**;
  next launch shows a banner → Copy report (clipboard) / Dismiss.
  `CrashContext` is fed passively (navigator observers → route; auth listener
  → user/role; `AppLog.call` → last action).
- **`core/utils/app_logger.dart`** — full category set: 🟡 CALL / 🟢 SUCCESS /
  🔵 ROUTE / 🟣 STATE (cubit transitions, via `AppBlocObserver`) / 🟠 WARNING /
  🔴 ERROR; optional `meta` map on every line; breadcrumb ring (always on,
  bounded 30); `time()` prints `⏱ … finished in Nms` and escalates **>1000 ms
  → 🟠 WARNING**. Console output is debug-only; breadcrumbs + crash file are
  release-active with negligible overhead.
- **Instrumented:** Firebase boot · session restore · FCM permission/token ·
  schedule load · per-role statistics load · notifications first-snapshot.
  Navigation (root + shell + redirects) and all cubit lifecycles were already
  auto-logged.
- New direct dependency: `path_provider ^2.1.4`.

`flutter analyze` clean · **258 tests pass** (+7 `observability_test.dart`) ·
macOS debug build green. To sanity-check on the Mac: run, then `⌘K` around the
app and watch the 🔵/🟣/⏱ stream; force a test crash if desired and relaunch to
see the export banner.

---

## ✅ macOS navigation freeze — root-caused and fixed (2026-07-02)

**The freeze** (clicking Tasks/Notifications sometimes locked the UI) was
Phase 2's `AppShell` `AnimatedSwitcher` around the `ShellRoute` child — that
child is go_router's shell **Navigator with a GlobalKey**, and the cross-fade
mounted it twice → duplicate-GlobalKey exception → corrupted element tree →
dead navigation. Desktop-only, cross-destination-only — matched the symptoms
exactly. **Fixed by removing the wrapper** (guard comment left in
`app_shell.dart`); the desktop fade already exists per-page, so no visual
change. **RULE: never wrap the ShellRoute child in anything that can mount it
twice (AnimatedSwitcher / keyed swaps / cross-fades).**

**The "Please ensure an APNS token is available" warning**: `registerToken`
called `getToken()` at sign-in on macOS, which has **no `aps-environment`
entitlement** (APNS token can never arrive). `NotificationService` is now
gated on new `supportsPushNotifications` (Android/iOS only — desktop skips
permission prompt + registration entirely) and checks `getAPNSToken()` before
`getToken()` on Apple platforms (fixes the same too-early race on iOS).

**Global debug logging** (debug builds only): `core/utils/app_logger.dart` —
`AppLog.call` (yellow) / `.success` (green) / `.error` (red) / `.route`
(cyan) / `.time` (async ms timing); `AppBlocObserver` (all cubit lifecycles +
state transitions, wired in `main`); `LoggingNavigatorObserver` on root +
shell navigators (pages now carry real path names); redirect decisions logged.

`flutter analyze` clean · **251 tests pass** · macOS debug build green.
⚠️ Owner: click through Tasks/Notifications on the Mac to confirm; `flutter
run -d macos` now shows the colored nav/cubit/timing logs.

---

## ✅ Phase 2 — premium desktop UX (2026-07-02)

Owner-approved visual overhaul (mock-first; approved scope: move-only
drag & drop · full ⌘K palette · fact-chips, no percentages). **Presentation
layer only — nothing to deploy.**

1. **Schedule 3.0** — people are individual **chips** in the grid cells
   (drag-to-move between slots on desktop via new `ScheduleCubit.move`;
   right-click/long-press menu: move-to-opposite-shift [double-booking-safe]
   · remove). New pure `schedule_insights.dart` + a clickable **insight
   strip** (open shifts · one-person shifts · **double-booked** conflicts —
   red dot on the chip) that highlights matching cells and dims the rest;
   swap queue is now a strip chip (floating footer removed); the coverage
   %-bar card is gone (quota framing — settled rejection).
2. **macOS layer** — `app_context_menu.dart` (app-wide right-click),
   `command_palette.dart` (**⌘K**: go-to + role actions + people, keyboard
   navigable), `hover_lift.dart`, and a 180 ms content cross-fade on sidebar
   navigation (`AppShell`, keyed by destination).
3. **Admin dashboard (desktop)** — executive two-column: main column =
   greeting + ⌘K pill → pulse hero → metrics → **Live activity feed** (from
   task `activityLog`s); 330px right rail = Pending Actions · quick
   actions/manage (2-up) · **Branch pulse** (per-branch open/review from the
   live stream). Rebuild-scoping preserved; mobile unchanged.
4. **Employee management** — desktop Details is a **person inspector**
   slide-over (contact/work/compensation + this-week chips + inline actions);
   **right-click on employee cards** = full action menu; **Create Account**
   desktop = 2×2 section cards (Identity · Access · Work · Compensation).

`flutter analyze` clean (7 pre-existing infos) · **251 tests pass** (+4
`schedule_insights_test.dart`) · macOS debug build green (`DROP.app`).
⚠️ On-device QA suggested: chip drag on a real trackpad, palette focus
behavior, inspector over the sheets.

---

## ✅ UI/UX audit pass (2026-07-02)

Full-app audit against the "premium macOS app" brief — report in
[UI_UX_AUDIT_2026-07-02.md](UI_UX_AUDIT_2026-07-02.md). **Verdict: the branding
sweep, monochrome design system, desktop shell, branded splash, and schedule
insights were already complete** (verified in code, not just docs). The only
`fbro` remnants are the registered Firebase iOS bundle id (`com.example.fbro`)
and the repo folder name — both intentionally untouched (changing the bundle id
detaches the app from Firebase). Two owner rulings were applied over the brief:
**strictly monochrome (no indigo)** and **lean, not enterprise**. Three real
gaps were closed:

1. **Compensation record** (`users/{uid}`): new `salaryAmount` / `salaryType`
   (`monthly`/`weekly`/`daily`) / `paymentMethod`
   (`cash`/`bank`/`wallet`/`instapay`) / `paymentNumber` fields on
   `UserEntity`/`UserModel` (excluded from `toMap`). Admin edits them in
   **Create Account** (Compensation section; post-create `setCompensation`
   write that warns-but-never-blocks the credentials dialog) and the **Edit
   Info** sheet (single busy-cycle via `updateDetails(writeCompensation:
   true)` → new `UserAdminRepository.updateUserCompensation`, all four keys
   written, null clears); the employee **Details** dialog shows Salary / Paid
   via / Payment no. Shared UI in
   `admin/presentation/widgets/compensation_fields.dart`.
2. **Employee self-service profile**: `ProfileEntity` now carries `address` /
   `emergencyContact` / `paymentNumber`; **Edit Profile** exposes validated
   Contact details + Salary payment number sections (previously name/bio/photos
   only — contact data was write-once at onboarding); the **Profile** page
   displays them. `paymentNumber` threaded through the full profile chain
   (editMap → datasource → repo → `UpdateProfile` → `ProfileCubit.save`).
3. **⌘1–⌘9 sidebar navigation** on desktop (`AppShell` `CallbackShortcuts` +
   autofocused `FocusScope`; `AppSidebar` rows hint `⌘n` on hover).

**Permissions model:** the `users` self-update rule freezes
`salaryAmount`/`salaryType`/`paymentMethod` (admin-only); `paymentNumber` is the
one compensation field the employee may write (their own receiving number).

⚠️ **Deploy required:** `firebase deploy --only firestore:rules` — until then an
employee's paymentNumber self-write is still allowed by the old rule (fine) but
the salary-field freeze is not enforced server-side.

`flutter analyze` clean (7 pre-existing infos, 0 new) · **247 tests pass** (+7
`user_compensation_test.dart`) · freezed regenerated · **macOS debug build
green** (`✓ Built build/macos/Build/Products/Debug/DROP.app`).

---

## ✅ macOS photo upload fixed (2026-07-01)

Owner report: photo upload "wasn't working" on the macOS build (profile
photo/cover, task proof/reference images, branch logo/cover — anywhere
`image_picker` is used). Root cause found by reading the actual plugin source:
**`image_picker` on macOS has no Photos-library integration** — it opens the
native `NSOpenPanel` file chooser (via `file_selector_macos`) and hands back a
real file path. The app is **sandboxed**
(`com.apple.security.app-sandbox = true`), and reading that picked file's bytes
back afterward (`File(picked.path)`, done by every upload call site) requires
the **`com.apple.security.files.user-selected.read-only`** entitlement — without
it the panel opens fine, a photo can be selected, but the subsequent read fails
("Operation not permitted") and the upload never leaves the client. This is the
same class of bug as the earlier keychain/network entitlement fixes on this
branch — an undeclared sandbox capability, invisible in the UI until you look at
`DebugProfile.entitlements`/`Release.entitlements`.

- **Fixed:** added `com.apple.security.files.user-selected.read-only` to both
  `macos/Runner/DebugProfile.entitlements` and `Release.entitlements` (kept in
  sync per the standing rule). Read-only is sufficient — the app only reads the
  picked file, never writes back to it.
- **Also fixed while in there:** `image_picker`'s `ImageSource.camera` has no
  implementation on macOS/Windows/Linux (throws `StateError` unless a
  `cameraDelegate` is registered, which this app doesn't do) — so the "Take a
  photo" / "Record a video" options in the Edit Profile avatar picker and the
  task `AttachmentPickerField` were **dead ends** on desktop (tap → generic
  "Could not open the picker" error). New **`supportsCameraCapture`**
  (`core/utils/platform_capabilities.dart`, `!kIsWeb && (Android || iOS)`) gates
  both call sites so desktop only ever offers the picker path that actually
  works there ("Choose from library" / "Choose photos"). Mobile is unaffected
  (still offers both).
- **Verified:** confirmed via the actual `image_picker_macos`/`file_selector`
  plugin source (not guessed) that `pickImage`/`pickMultiImage` route through
  `NSOpenPanel.openFile` and that the camera source throws. Also confirmed via a
  live emulator-backed run (web build, since this container can't build macOS)
  that the picker-hides-camera UI change renders correctly and that the
  gallery-pick → upload path is otherwise wired correctly end-to-end (the only
  step unverifiable outside a real Mac is the sandbox read itself, which is a
  well-documented Apple requirement, not a guess).

`flutter analyze` clean (7 pre-existing infos, 0 new); **233 tests pass**.
⚠️ Needs a real macOS run to close the loop (this container has no macOS build
target) — but the fix directly addresses the documented Apple Sandbox
requirement for `NSOpenPanel`-sourced files, which is the confirmed mechanism
`image_picker` uses on macOS.

## ✅ Live end-to-end QA pass across all three roles (2026-07-01)

Previous desktop-polish passes below were all **static** (code + `flutter analyze`/`test`
only — no Dart SDK / no running app in those sessions). This pass actually **ran the
app** — built for web, connected to local Firebase Auth/Firestore/Storage emulators
(seeded with an admin/manager/3 employees/2 branches/tasks in every status), and
drove it with a real Chromium browser at a 1440×900 desktop viewport (the macOS
desktop breakpoint), clicking through every sidebar destination for all three roles
plus the auth/onboarding gate screens. This is the first session to **visually
confirm** (not just infer from code) that the desktop redesign work in the sections
below actually renders correctly.

**Verified working, matches the documented design:** Login (desktop split panel),
all three dashboards, Task Management + Branch Operations cockpit + Employee detail
+ Task Details ticket, the weekly Schedule grid (+ assign-shift sheet), Communications
Center (feed + delivery panel), Notifications empty state, Analytics grid, Branches
list + Edit Branch sheet (media/swap-policy sections), Managers list, Create Account
form, New Task sheet, Profile/Settings, and the full first-login gate (Force Password
Change → Profile Completion → Home).

**Two real bugs found and fixed** (the rest of the punch-list below was already
correct):
1. **Employees page ignored the responsive grid.** `EmployeeManagementScreen` had
   its own bespoke `ListView` of `EmployeeCard`s that never went through
   `ResponsiveCardGrid` — unlike the sibling Managers page (`AdminUsersListView`),
   it always rendered a single full-width column, wasting most of a 1440px window.
   Fixed by wrapping it in the same `ResponsiveCardGrid(runSpacing: 0,
   ultrawideColumns: 2)` convention used everywhere else.
2. **Change Password had a duplicated, badly-wrapped title.** The page kept a
   pre-`AdaptiveScaffold`-migration in-body heading (`Text('Change\nPassword',
   style: displayMedium)`) even though `AdaptiveScaffold(title: 'Change Password')`
   already renders that title in both the mobile app bar and the desktop page
   header — so desktop showed "Change Password" twice, with the second copy
   force-wrapped onto two lines by a stale hardcoded `\n`. Removed the redundant
   heading (kept the one-line instructional subtitle).

`flutter analyze` clean (7 pre-existing infos, 0 new) · **233 tests pass** ·
`flutter build web --release` green. QA harness (temp emulator entrypoint, seed
script, Playwright driver) was scratch-only and not committed.

## ✅ macOS desktop hardening (2026-07-01)

Three fixes on the `feature/macos-desktop` branch, all verified on a signed
debug build + the live login screen:

1. **Keychain login crash — SOLVED.** The error is a `FirebaseAuthException`
   (`keychain-error`) from FirebaseAuth's native macOS session persistence — NOT
   `flutter_secure_storage` (declared in pubspec but **unused** in `lib/`). Root
   cause: **`DebugProfile.entitlements` was missing `keychain-access-groups`**
   (Keychain Sharing had only been added to `Release.entitlements`, but
   `flutter run` uses Debug). Fix: added the keychain group to
   `DebugProfile.entitlements` + restored the sandbox to match Release. Signing
   was already set (`DEVELOPMENT_TEAM = 7Q3PY75VGH`). **Verified** the debug
   binary embeds `keychain-access-groups = 7Q3PY75VGH.com.example.fbro`. Temporary
   `auth.keychain` debug logging added around sign-in. **Rule: keep Debug and
   Release entitlements in sync.**
2. **Desktop layout engages** — `MainFlutterWindow.swift` opens the window at
   1440×900 (min 1024×720) so the >=1024pt premium split/sidebar UI renders
   instead of the mobile fallback that appeared at the old ~800×600 default.
3. **Strictly monochrome restored** — the indigo `#5B5FEF` this branch had
   reintroduced is reverted; `AppColors.accent*` tokens now resolve to the
   white-on-black accent (`app_colors.dart`). Active-nav / primary-CTA / link
   emphasis is white or a faint white wash.

> **NOTE for future work:** older sections below still describe an *indigo
> accent* as the desktop direction (the 2026-06-30 migration section). That is
> **superseded by the 2026-07-01 monochrome revert above** — indigo is no
> longer used anywhere.

---

## ⚙️ Desktop UI migration status (2026-06-30)

The app is now desktop-first via a `ShellRoute` (`AppShell`) that renders a
persistent, role-aware `AppSidebar` across **every** authenticated route on
desktop/ultrawide widths; mobile/tablet keep the original app-bar + bottom-nav
chrome. Indigo (`#5B5FEF`) is the single accent, used only for active nav, the
primary CTA, key FABs, and links.

**Premium desktop redesigns (beyond a chrome swap):**
- **Schedule** (`manager_schedule_view` + `schedule_grid`): full-width weekly grid
  (no horizontal scroll on desktop) + dense horizontal toolbar.
- **Task Details** (`task_details_screen`): two-column ticket — record + dedicated
  action panel.
- **Communications** (`communications_screen`): history feed + command panel with
  delivery analytics.

**Migrated to `AdaptiveScaffold`** (no desktop app bar, premium desktop header):
notifications · settings · change-password · profile · edit-profile · analytics ·
schedule-management · branch-schedule · communications-center · admin-task-overview ·
my-tasks (TabBar) · employee-management · create-account · branch-management ·
task-details · plus the three role dashboards (`RoleScaffold`). Login has a bespoke
desktop split.

**✅ Desktop punch-list COMPLETE (2026-07-01).** Every screen that was still on a
raw mobile `AppBar` now uses `AdaptiveScaffold`: Tasks (`branch_task_list_screen`,
`pending_review_screen`, `task_detail_loader_screen`), Operations
(`branch_operations_screen`, `employee_detail_screen`), Schedule
(`my_schedule_screen`), Admin (`admin_users_list_view`), and Communications
(`compose_broadcast_screen`, `broadcast_detail_screen`, `broadcast_templates_screen`,
`broadcast_schedules_screen`). `AdaptiveScaffold` gained **`titleWidget`** (custom
title lockup, e.g. branch/employee avatar+name — scaled up on desktop) and
**`bottomBar`** (pinned bottom action bar, used by the broadcast send bar).
`flutter analyze` clean (no new issues), **227 tests pass**, macOS build green.

The **auth/onboarding pages are now responsive too** via a new reusable
**`AuthScaffold`** — mobile keeps the app bar; desktop centres the content in a
~440px column (matching the Login panel) with a top utility row (back / "Sign
out"). Applied to `forgot_password_page`, `force_password_change_page`,
`profile_completion_page`. So **no authenticated or auth screen renders as
stretched-mobile on desktop anymore.**

**Conversion recipe (for any future screen):** replace
`Scaffold(appBar: AppBar(title: Text(x), actions: […]))` with
`AdaptiveScaffold(title: x, actions: […], body: …)`; full-width data surfaces pass
`constrainContent: false`; custom leading/sub-view toggle → `leading:`; TabBar →
`bottom:`; custom title lockup → `titleWidget:`; pinned bottom action bar →
`bottomBar:`.

> **Branch cover photo on the admin task overview (2026-06-28):** The branch cards in
> `AdminTaskOverviewScreen` now lead with the branch **cover photo** (new `_CoverHeader`:
> 16:7 image + scrim + logo/name/location + attention pill + chevron) **when the branch
> has an uploaded `coverUrl`** — branches without media keep the plain text header.
> Metrics stay below on the dark surface for legibility. `_BranchRow` carries
> `coverUrl`/`logoUrl` from `TaskCubit.branches()`; reuses `BranchAvatar` + the §8b media
> pipeline (extends the branch-identity-in-tasks work). No data layer, no deploy. **227
> tests pass.**
>
> **User-detail input validation (2026-06-28):** New shared **`Validators`**
> (`lib/core/utils/validators.dart`, pure + unicode-aware for Arabic) enforces the
> right *kind* of value on user-detail fields — `phone` (digits + `+ - ( )`, rejects
> letters/`@`), `name` (letters only), `address`, `emergencyContact` (must contain a
> number), `email`; each takes `required` (mandatory onboarding vs. optional admin
> clear-to-empty). `AppTextField` gained an **`inputFormatters`** hook; phone fields use
> `Validators.phoneInput` so letters can't be typed. Applied to **ProfileCompletionPage**
> (first-login required fields), the admin **Edit details** sheet (was un-validated) and
> **Create account**. `validators_test.dart` → **227 tests pass**. Client-only, no deploy.
>
> **Account-switch push fix on a shared device (2026-06-28):** Fixed an L1 client gap
> behind EXCLUSIVE token ownership. On a shared phone the device's FCM token is the
> **same** across accounts; `registerToken` set `_uid` then hit `_rotateToken`'s dedup
> guard (`_currentToken == token && _uid == uid`), so if the prior session's
> `_currentToken` survived in memory (a switch path that bypassed `forgetUser`) the new
> user's `fcmTokens` was **never** written → `claimFcmToken` had nothing to reclaim →
> pushes to the switched-in account failed ("0 registered tokens"). Now `registerToken`
> **clears `_currentToken` on a uid change**, forcing a fresh write the server reclaims
> from the prior owner. Client-only, **no deploy**; `claimFcmToken` unchanged. `flutter
> analyze` clean.
>
> **Delete sent broadcasts (2026-06-27):** Re-added an option to **permanently delete**
> a broadcast from the Communications feed (archive-only since the 2026-06-24 trim).
> Hard delete of `broadcasts/{id}` via `BroadcastRepository.delete` →
> `BroadcastCubit.deleteBroadcast`; a destructive **Delete** item in the card + detail
> overflow menus (confirm-gated). **Firestore rule** `broadcasts` `delete` now allows
> admin / original sender / owning-branch manager (was `if false`). ⚠️ **Deploy
> required:** `firebase deploy --only firestore:rules` (until then delete →
> permission-denied). Per-recipient inbox notifications already delivered are left as-is.
> `flutter analyze` clean; **217 tests pass**.
>
> **iOS template-sheet keyboard fix (2026-06-27):** the Communications template editor
> (`_TemplateEditor`) keyboard could get stuck on iOS — added tap-outside-to-dismiss
> (`FocusScope.unfocus`), drag-to-dismiss (`keyboardDismissBehavior: onDrag`), and an
> explicit ✕ close button. Client-only, no deploy.

> **Branch identity in tasks (2026-06-27):** Tasks now carry their **branch media**
> so they feel cohesive with the rest of the app. **Task Details** leads with a slim
> 16:6 **cover banner** (`_BranchBanner` — branch cover photo + dark scrim +
> `BranchAvatar` logo + name/location) when the branch has a `coverUrl`; **task cards**
> show the branch **logo** in the branch chip (`TaskCard.branchLogoUrl`, resolved by
> `ManagerTaskCard` from the app-wide `BranchCubit` directory). Reuses §8 branch media
> + the Operations branch-hero pattern; no schema/rules/DI change. **Only shows for
> branches with uploaded media** (Admin → Branches → edit → Branch media) — others
> render as before. `flutter analyze` clean; **217 tests pass**. No deploy needed.

> **Admin contact details + notification diagnosis (2026-06-26):** **(1) Admin "Edit
> Info":** admins can record/edit a person's contact info **anytime after creation** —
> new `UserEntity`/`UserModel` `address` + `emergencyContact` (phoneNumber already
> existed), `UserAdminRepository.updateUserDetails` + `AdminUsersCubit.updateDetails`,
> a new `showEditDetailsSheet` (Full name · Phone · Address · Emergency), wired as an
> **Edit Info** action on the Employees **and** Managers lists; the employee Details
> dialog surfaces them. No rule change (admin already writes any `users/{uid}` field;
> the fields are non-privileged). **(2) Notifications — server is HEALTHY**, the fault
> is platform config: **iOS is the blocker**. ✅ **Bundle-id mismatch RESOLVED** —
> the iOS bundle id was changed `com.ziadelsewedy.fbro` → **`com.example.fbro`** in
> `ios/Runner.xcodeproj/project.pbxproj` (all 3 Runner configs), so the app now
> matches the existing `GoogleService-Info.plist` + `firebase_options.dart` + Android
> (one Firebase iOS app, no plist swap). **Still owner to-dos (Xcode/Apple, not
> code):** **no `Runner.entitlements`/`aps-environment`** (iOS can't get a push token
> until the Push capability is added) + **no APNs key uploaded**. **Android is
> configured**; residual misses are the Android-13 runtime permission grant or a
> recipient with no token. `flutter analyze` clean; **217 tests pass** (+5). **No
> deploy needed.**
>
> **📋 iOS push action checklist (owner, in Xcode/Apple — bundle id already done):**
> (a) ~~reconcile bundle id~~ ✅ done (now `com.example.fbro`). (b) Xcode → Runner
> target → Signing & Capabilities → **+ Capability → Push Notifications** (creates
> `Runner.entitlements` + `aps-environment`) and **+ Background Modes → Remote
> notifications**. (c) Apple Developer → Keys → create an **APNs Auth Key (.p8)** →
> Firebase Console → Project Settings → Cloud Messaging → upload it under the iOS app
> (`com.example.fbro`). (d) Test on a **real device** (the iOS Simulator can't receive
> push). After (b), `pod install` + a clean rebuild.

> **Auth & account provisioning redesign — admin-only accounts (2026-06-26):**
> **Core business change: no public registration — only an admin creates
> accounts.** **Removed completely:** signup/registration, phone-OTP, Google
> sign-in, email-verification gating, and the approval/pending-approval flow (+
> their pages, use cases, the `approval_status` enum, and the `google_sign_in`
> dependency). **Auth surface is now Splash · Login · Forgot Password · Force
> Password Change · Profile Completion.** **Data model** (`users/{uid}`):
> `UserEntity`/`UserModel` gained `mustChangePassword` / `isProfileCompleted` /
> `employmentStatus` / `createdBy`; dropped `approvalStatus`; `hasAppAccess` is
> now just `isActive`. **Backend:** two admin-only callables —
> `createUserAccount` (Admin SDK: Auth user + Firestore doc, admin stays signed
> in) and `adminResetPassword`. **Rules:** `users` `create: if false` (server-only
> creation), self-update freezes role/branch/shift/position/employmentStatus/
> createdBy. **Routing:** `unauthenticated → Login`, `mustChangePassword → Force
> Password Change`, `!isProfileCompleted → Profile Completion`, else role home; a
> deactivated account is **blocked at login + signed out**. **UI (premium, strictly
> monochrome — no indigo, per the locked ruling):** Login redesigned (no signup/
> Google/phone); new Force Password Change + Profile Completion (phone/emergency
> contact/birth date/address required, photo optional); Admin → User Management →
> **Create Account** screen + Reset Account. `node --check` valid; all changed Dart
> parse-checked. ⚠️ This env's Flutter is **3.10.4 < `^3.12.1`** — run `build_runner`
> (UserEntity + AuthState freezed hand-edited) + `analyze` + `test` on 3.12.2.
> ⚠️ **Deploy required:** `firebase deploy --only functions,firestore:rules`
> (`createUserAccount` + `adminResetPassword` + the user-create lockdown) — until
> then account creation fails (callables missing) and self-registration isn't
> closed. Sequence the client cutover with the deploy.

> **FCM token ownership — defense-in-depth (2026-06-26):** Three layers ensure a
> push can never reach the wrong account (crashes / interrupted logout /
> multi-account device / token-refresh races). **L1 client pre-sign-out cleanup**
> (`AuthCubit.signOut` awaits `forgetUser` before `_signOut`). **L2 server
> `claimFcmToken`** (authoritative exclusive ownership). **L3 per-recipient
> stamping + client drop-guard:** every push carries `data.recipientUid`
> (broadcast via `messaging.sendEach` per-token; task push per-recipient); the
> client (`NotificationService._isForCurrentUser`) **drops** any foreground/tap
> push whose `recipientUid != _uid` and self-heals (re-register → `claimFcmToken`
> reclaims). Plus dispatch **drift diagnostics** (`tokenDriftCount` + a `warn` when
> one token is on two recipients in a send). **Residual (documented):** a
> backgrounded/terminated app's OS-rendered banner for a drifted token can't be
> suppressed client-side (rare/short-lived; tap is still guarded). `node --check`
> valid; changed Dart parse-checked. ⚠️ **Deploy `functions`**; run `analyze`/`test`
> on 3.12.2.

> **Token-leak audit · realtime swaps · timeline V2 (2026-06-26):** **(1) FCM
> cross-account leak fixed.** Multi-account device audit (A→logout→B same device)
> found `forgetUser()` ran **after** Firebase sign-out, so its `fcmTokens` write was
> **permission-denied** (silently) — the client never removed the token on logout,
> leaving the server `claimFcmToken` as the only guard. Now `AuthCubit.signOut()`
> runs a **pre-sign-out hook** (`onPreSignOut` → `NotificationService.forgetUser`,
> wired in DI) that drops the token **while still authenticated**. Two-layer
> guarantee: client removal on normal logout + `claimFcmToken` (re-audited, correct/
> loop-safe) reclaiming on the next register for force-kill/offline. **No token
> ownership drift.** **(2) `ShiftSwapCubit` is stream-based** — new
> `watchEmployeeSwaps`/`watchBranchSwaps`/`watchAllSwaps` Firestore streams
> (datasource+repo); the cubit subscribes per scope (idempotent, cancel-on-close),
> mutations no longer refetch. Coworker swap requests appear on Home in realtime;
> the **admin Home swap count is live** (`_PendingSection`). **(3) Activity timeline
> V2** — `_EventCard` gives the current (newest) step a larger glowing accent node +
> "CURRENT" pill + tinted card; spine fades accent→border; note callouts. `node
> --check` valid; changed Dart parse-checked. ⚠️ Run `analyze`/`test` on 3.12.2;
> ensure `claimFcmToken` + `approveSwap` are deployed (no new functions this pass).

> **Audit pass (2026-06-26):** Four surgical fixes. **(1) Swaps on Home:** the
> employee home now loads `ShiftSwapCubit.loadMine` + shows a prominent **Shift
> swaps** section (incoming → Accept/Decline with a "you give ⇄ you get" strip;
> outgoing → stage + Cancel), so a coworker sees & acts on a request without digging
> into Schedule. **(2) Admin review reactivity:** the Pending Actions / hero review
> count was sourced from the **TTL-cached `StatisticsCubit`** (stale after a
> review); now derived from the **live task stream** (`_DynamicSection` selects
> `(overdue, reviews)`), so completing a review updates the queue instantly.
> **(3) Broadcast resilience:** `dispatchBroadcast`'s FCM push wasn't error-isolated
> — a transient send error failed the callable **after** the doc + inbox writes;
> now wrapped best-effort with diagnostic logging (no-token info log + push-failed
> error log). End-to-end broadcast audit (targeting, token persistence, dead-token
> cleanup, rules) otherwise clean. **(4) UI polish:** `TimelineTile` haloed dot +
> note callout; premium Home swap cards. `node --check` valid; changed Dart
> parse-checked. ⚠️ Run `flutter analyze`/`test` on 3.12.2; **deploy** `functions`
> for the broadcast fix.

> **Shift Swap hardening (2026-06-26):** The employee-to-employee exchange (built
> 2026-06-25) is now **server-authoritative + atomic** and has a premium swap UX.
> Manager approval moved off the 4-op non-atomic client write onto a new callable
> **`approveSwap`** (functions/index.js) that re-validates against the freshest
> schedule (TOCTOU) and applies the requester ⇄ target trade in **one Firestore
> transaction**. New validation: **role compatibility** (new `UserEntity.position`
> + per-branch **`SwapPolicy`** on `branches/{id}.swapPolicy` = `restrictToSamePosition`
> + `minRestHours`; null = permissive) and **rest hours**, defined once in pure
> **`SwapValidation`** (client request-time) and **mirrored in the function**
> (authority). A weekly shift cap was deliberately omitted (invariant under an
> exchange). Rules hardened: clients can't set `status==managerApproved` (function
> only); self-update freezes `position`. UI: `swap_view` rebuilt (⇄ exchange visual,
> status timeline, `DropEmptyState`, premium request sheet with avatar picker +
> request-time validation); branch form gains a "Shift-swap rules" section; employee
> management gains a **Position** action. New tests: `swap_policy_test`,
> `swap_validation_test` (+`user_model` position). `node --check` valid; changed Dart
> parse-checked (`dart format`). ⚠️ This session's Flutter is **3.10.4 < `^3.12.1`** —
> run `build_runner` (two freezed files hand-edited) + `analyze` + `test` on 3.12.2.
> ⚠️ **Deploy required:** `firebase deploy --only functions,firestore:rules`
> (`approveSwap` + the swap-status/position rule hardening) — until then
> manager-approve fails (callable missing); sequence the client cutover with the deploy.

> **Realtime polish (2026-06-25):** Reconciled a "realtime admin home" ask against
> the code — **realtime streams, newest-first, rebuild-scoping, and pull-to-refresh
> already exist** (`TaskCubit.watchAllTasks`, scoped `BlocSelector`s); the admin
> home is a **counters dashboard**, not a live task list. Per the owner's lean
> scope, added two reusable primitives — **`AnimatedCount`** (single animated
> counter; replaced the bespoke tween in the review header, reused by dashboard
> metrics + hero + drill counts) and **`LiveListItem`** (keyed entrance-once +
> optional new-arrival highlight; preserves scroll, no `AnimatedList`/diff) — then:
> dashboard **metric grid + hero counters count up** (`DashboardMetricCard` numeric
> values via `AnimatedCount`, back-compat for "—"); **`pending_review_screen`** rows
> are keyed `LiveListItem`s so a stream emit never re-animates the list, a
> genuinely-new submission **slides in + briefly highlights** (`_knownTaskIds`),
> scroll is held (`PageStorageKey` per level), counts animate. **Deliberately did
> NOT build** the buffer / "X new tasks arrived" banner / 2–5s batching — the stream
> is sufficient and review is a separate route (no list-jump-during-review problem).
> Presentation-only; no schema/logic/stream/dependency change. ⚠️ This session's
> Flutter is **3.10.4 < `^3.12.1`** — run `flutter analyze`/`flutter test` on a
> current SDK (parse-checked with `dart format`).

> **Premium task UX slice (2026-06-25):** Acted on the task-management UX audit.
> **#1 — Admin/Manager reference images:** new `TaskEntity.referenceAttachments`
> (`List<TaskAttachment>`, freezed hand-regenerated; `TaskModel` (de)serializes
> it; back-compat → empty when absent). Managers/admins attach reference photos in
> the New/Edit Task sheet (the reused `AttachmentPickerField` in images-only mode,
> with removable already-uploaded thumbnails); `TaskCubit.createTask`/`editTask`
> upload them (new `_uploadReferences`) to `tasks/{id}/attachments/{attId}.<ext>`
> (existing path → **no storage-rules change**); the employee sees a "Reference"
> gallery on the details screen **before** starting. **#2 — Premium (de-flashed)
> task card:** the shared `TaskCard` (manager/admin surfaces) was rebuilt from a
> label→value spec sheet into status-pill + **High-only** priority + signal-chip
> strip (branch · due/overdue · `N refs`) + a **single thin checklist bar** (only
> when a checklist exists) + a **minimal one-line** assignee footer; inline
> proof/notes/review removed (now details-only). **De-flash ruling (premium ≠
> flashy, Linear/Notion/Stripe):** the flat surface (solid fill + hairline border +
> *whisper* shadow — **no gradient/glow/pulse**) is defined **once** in a reusable
> **`TaskSurface`** (shared by the card + `TaskDetailsScreen._StatusHeader` — no
> duplicated decoration), **not** `AppGlassCard`; the card pill reuses the canonical
> `taskStatusColor` (no forked colour map); the details header was flattened to
> match (pulse + glow + gradient removed). **Scoped to task surfaces only — the
> shared `GlassContainer`/`AppGlassCard` are deliberately untouched** (`TaskSurface`
> is the one place to promote if we globalise later). Strictly monochrome; **no new
> dependencies**. ⚠️ This session's Flutter is **3.10.4 < `^3.12.1`**, so
> `build_runner`/`analyze`/`test` can't run here — the freezed file was hand-edited;
> **run `dart run build_runner build --delete-conflicting-outputs`, `flutter
> analyze`, `flutter test` on a current SDK (3.12.2)** before merge. New test
> `task_model_reference_test`; `task_card_layout_test` updated. **Deferred** (audit
> backlog): drag-and-drop upload, on-image annotation, `Blocked` status, double-tap
> zoom, `cached_network_image`, swipe/haptics, employee minimal-card alignment.

> **FCM routing audit (2026-06-25) — CRITICAL fix:** Proved the cross-user
> notification-leak bug is real. **Root cause:** non-exclusive token ownership —
> registration only ADDS a device token to the signed-in user; the only cross-user
> release is the client's best-effort `forgetUser` on logout, and clients can't
> write other users' docs (rules), so a token can linger on multiple users → a send
> to the old user hits a device now used by someone else. Audience resolution +
> within-send dedup are CORRECT (not the bug). **Fix:** new server-only Cloud
> Function **`claimFcmToken`** (`onDocumentUpdated('users/{uid}')`) — on a token
> being added, removes it from every other user's `fcmTokens` + legacy `fcmToken`
> (loop-safe), so a token belongs to at most one user. No client/schema/rules/index
> change. `node --check` valid; Flutter side untouched (analyze clean / 192 tests).
> ⚠️ **DEPLOY REQUIRED** to activate: `firebase deploy --only functions` (now 6
> functions). Until deployed, the leak persists in production.

> **Shift Swap System (2026-06-25):** Evolved the existing swap workflow into a true
> employee-to-employee **exchange** (approval swaps **both** employees across the
> two shifts — Ziad Night ⇄ Ahmed Morning — not a one-way handover) with **swap
> notifications**. Built on the existing `shift_swaps`/`ShiftSwapCubit` slice (no
> matching engine / new schedule schema). New: `ScheduleShift.opposite` + 4-op
> `managerApproveSwap`; opposite-shift coworker picker (`_requestSwap`); `cancelled`
> status (+ `cancelSwap`); **`NotifySwapEvent`** producer (request→coworker ·
> accept→branch manager(s) · approve/reject→both) reusing the notification pipeline
> — lights up the §5 inbox's **Schedule** category + a swap awaiting approval is
> **critical**. Guards: requester≠target · same branch · future shift · target-slot
> exists · no duplicate pending · terminal-when-resolved. Kept the existing 4 status
> names (= spec's pendingCoworker/pendingManager/approved/rejected) + added cancelled.
> `flutter analyze` clean; **192 tests pass** (+9). **No deploy needed** (reuses the
> live `notifications` rule + `onNotificationCreated` push). ⚠️ on-device QA of the
> swap flow recommended.

> **Release Stabilization (2026-06-25):** Production-readiness pass after the
> Premium UX/Logic Refactor (§1–§11). **The long-standing deploy debt is CLEARED** —
> deployed `firestore:rules` + `storage` + all 5 `functions` to production
> `bazic-d9ad7`; deleted two orphaned analytics functions so the live set matches
> the code (no client/server drift). Critical checks live: approved-task lock,
> broadcast sender self-exclusion, branch-media uploads. Automated gate green
> (analyze clean · **183 tests** · `node --check` valid). Static perf/UX audits
> clean (two pre-existing minor hot paths noted, not regressions). **Full manual QA
> matrix + audit record in [RELEASE_QA.md](RELEASE_QA.md)** — execute on a device
> across the three roles before sign-off. Maintenance note: `firebase-functions` is
> an older major (future `@latest` bump). **No earlier "⚠️ deploy pending" warnings
> apply anymore — the server side is live.**

> **Premium UX/Logic Refactor · §5 — notification UX (2026-06-25):** Rebuilt the
> Notification Center into an **operations inbox** (intentionally reversing the
> 2026-06-23 lean feed, owner-directed; monochrome/subtle preserved). **5a IA**
> (`notification_format.dart`, pure + tested): **priority** (critical/high/normal/
> low via `notificationPriority`), **category** filter pills (All/Tasks/Reviews/
> Broadcast via `NotificationCategory`/`categoryOf`), **time grouping**
> (`groupByTime` → Today/Yesterday/Earlier, priority-first within each); critical →
> stronger unread dot on the tile. **5b** swipe right=mark-read · left=archive
> (delete in Archived view), re-added **Archived view** toggle, bulk **Mark all
> read** + **Clear archived** (`NotificationCubit.clearArchived`), deep-links
> verified (no dead notifications). **5c** dot fade · swipe spring · pill transition
> · light haptics. **Data:** kept single `readAt` (= isRead); `isSeen` NOT added
> (documented — too invasive for a small inbox). **Documented gap:** Schedule/System
> category pills + "swap approval" critical have **no producer** (trimmed types) —
> omitted to avoid dead pills; re-add with a producer. `flutter analyze` clean;
> **183 tests pass**. ⚠️ swipe/haptics need an on-device check. Reused
> `NotificationTile` + `AppGlassCard`.

> **Premium UX/Logic Refactor · §8c — branch hero completion (2026-06-25):** Closed
> the parked §8b/§9 chain. New **`_BranchHero`** on the Branch Operations cockpit —
> a **16:9** premium surface: branch **cover** photo (≈70% dark scrim) +
> `BranchAvatar` + name + **employee count** + active-shift summary; **monochrome
> fallback** when no `coverUrl`. Carries a ≤**0.03** `BrandWatermark` (the §9b
> branch-dashboard watermark, now **unblocked**). **Schedule header** secondary
> label is now **"Weekly Schedule · N employees"** (threaded `members.length`).
> Reuses §8 `coverUrl`/`logoUrl` + the §8b `BranchCubit` directory — no schema/rules/
> DI change. `flutter analyze` clean; **180 tests pass**. ⚠️ Hero (cover image /
> nested 16:9 Stack) wants an on-device check. **§8 + §9 complete.** Only noted gap:
> the Communications Center header watermark (bare AppBar, no hero card — deferred).
> **Next:** §5 notification UX polish.

> **Premium UX/Logic Refactor · §9b — brand rollout (2026-06-25):** Wired the §9a
> brand primitives into the product, **restrained** (heavy brand only on
> auth/empty/full-loading; one subtle hero watermark; **no** brand in
> cards/tiles/rows). **Wave 1 (auth):** new shared **`DropAuthMark`** (DropLogo +
> "DROP OPERATIONS SYSTEM" tagline) leads login + register; splash left intact
> (already on-brand; fixed stale "indigo" comment); OTP deferred. **Wave 2 (states):**
> empties → **`DropEmptyState`** (`TaskEmptyState` [5 sites, dropped its `icon`],
> notifications, branches+search); full-page loaders → **`DropLoadingState`** (manager
> + employee schedule views) — skeletons/button spinners untouched. **Wave 3
> (headers):** new reusable **`BrandWatermark`** (clipped ≤0.05-opacity wordmark)
> on the Admin Home hero; comms header (bare AppBar) + branch dashboard hero
> (parked §8b cover-hero) deferred — no card surface yet. No new assets; no indigo.
> `flutter analyze` clean; **180 tests pass** (+3). **Parked from §8b:** the
> operations cover-image hero + schedule "• N employees" label.

> **Premium UX/Logic Refactor · §9a — brand primitives (2026-06-25):** First step of
> §9, the **brand primitives only** (ahead of the broad rollout), built on the
> existing `DropLogo` PNG. New `core/widgets`: **`DropWordmark`** (typographic DROP
> logotype — vector-crisp inline complement to the PNG), **`DropEmptyState`**
> (brand-led empty state — faded logo + message, sibling of `AppEmptyState`),
> **`DropLoadingState`** (pulsing-logo full-area loader). `flutter analyze` clean;
> **177 tests pass** (+3 `brand_primitives_test`). **Not wired into screens yet** —
> the broad branding pass (splash/auth/empties/loading/headers) is the next slice.
> (§5 notif UI still deferred.)

> **Premium UX/Logic Refactor · §8b — branch identity rollout (2026-06-25):**
> Finished §8 by surfacing `BranchAvatar` wherever branch identity matters, via the
> **app-wide `BranchCubit` as a directory** (`branchById` + `loadIfNeeded`,
> warm-preloaded for every role in `main.dart`). Wired into: the **schedule header**
> (`manager_schedule_view` — branch logo + name above the controls), the **operations/
> branch dashboard header** (`branch_operations_screen` AppBar title), the **employee
> profile** (new "Assigned branch" `AppGlassCard` section), and **swap request cards**
> (`swap_view._BranchLine`). `flutter analyze` clean; **174 tests pass**. **§8 (media +
> identity) is complete.** **Next:** §9 branding — first the brand primitives
> (`DropWordmark`/`DropEmptyState`/`DropLoadingState`), then a broad rollout. (§5
> notif UI still deferred.)

> **Premium UX/Logic Refactor · §8 Branch Media (2026-06-25):** Admin branch
> branding — `BranchEntity`/`BranchModel` gain **`logoUrl` + `coverUrl`** (freezed
> regenerated; `toMap` excludes them so an edit-save never clobbers an uploaded
> logo). New Storage path `branches/{branchId}/{logo|cover}.jpg` via
> `BranchRemoteDataSource.uploadBranchImage` → `BranchRepository` (cache-invalidating)
> → `BranchCubit.uploadBranchImage`; `BranchRemoteDataSourceImpl` now takes
> `FirebaseStorage` (DI updated). New reusable **`BranchAvatar`** (logo · else
> monochrome initials · else store glyph). Upload UI in the branch form sheet
> (**editing only** — a new branch has no id; shows a "save first" hint): logo row +
> cover field with inline spinners. Branch management card now leads with
> `BranchAvatar`. **No chromatic `branchTheme`** (monochrome ruling). `storage.rules`
> add the `branches/{id}` path. `flutter analyze` clean; **174 tests pass** (+7
> `branch_media_test`). ⚠️ **Deploy** `firebase deploy --only storage`.
> **Deferred display wiring:** `BranchAvatar` on the schedule header / operations
> dashboard / employee-profile branch (each needs that surface to carry `logoUrl`).
> **Next:** §9 branding (now on a stabilised UI), §5 notif UI.

> **Premium UX/Logic Refactor · Slice 2b — component rollout cleanup (2026-06-25):**
> Finished the Slice 2 rollout. Swept every remaining ad-hoc compact action button
> (`swap_view._SwapButton` · `admin_user_card.AdminActionButton` ·
> `branch_management._btn` · `employee_home._ActionButton`) onto **`PremiumButton`**,
> and the only two remaining hand-rolled glass-gradient cards
> (`branch_management._card` · `employee_home._HeroTodayCard`) onto **`AppGlassCard`**.
> Audit confirms **0** remaining glass-card dups and **0** remaining compact-button
> dups; justified remainders (standard Material `TextButton`/`OutlinedButton`
> one-offs, auth focus shadows, the animated status-aura header) left as-is.
> `AppGlassCard`/`PremiumButton` are now the **default premium primitives**.
> `flutter analyze` clean; **167 tests pass**. **Next:** §8 Branch Media (then §9
> branding on the stabilised UI).

> **Premium UX/Logic Refactor · Slice 2 (2026-06-25):** §10/§11 — a reusable
> premium component layer, built to **reduce** duplication (the §11 goal) instead
> of forking parallel widgets. New `core/widgets`: **`AppGlassCard`** (premium
> card; maps task status → a **subtle glow**, emerald/amber/red only — no indigo),
> **`MetricPill`** (compact `[icon] value · label`), **`PremiumButton`** (canonical
> compact inline action button — distinct from the 56px form `AppButton`).
> Enhanced `GlassContainer` with an optional `glow` (one shared decoration) and
> exposed `taskStatusColor` (single status→colour source). Validated by migrating
> **three** surfaces only (no full-screen redesigns): the **Manager Task card**
> (`TaskCard` opt-in `premium` flag → `AppGlassCard` + status glow; `TaskActionButton`
> → `PremiumButton`), the **Admin Home pending card** (`PendingActions` →
> `AppGlassCard` + `MetricPill` summary), and the **Notifications list**
> (`NotificationTile` → `AppGlassCard` + a reused-`StatusBadge` category badge).
> Strictly monochrome + subtle status glows only. `flutter analyze` clean (0
> issues); **167 tests pass** (+5 `premium_components_test`). **Deferred:**
> migrating the remaining ad-hoc card buttons + §5/§8/§9.

> **Premium UX/Logic Refactor · Slice 1 (2026-06-25):** First slice of a 12-point
> refactor prompt, scoped down after a reality-check + owner rulings (**strictly
> monochrome + subtle status glows only, no indigo**; **logic/correctness first**;
> **keep the `fcmTokens` array** — the `fcmDevices` rebuild was rejected as
> over-engineering, since multi-device + logout-removal + refresh-rotation +
> dead-token pruning already work). Shipped four correctness fixes: **§1** admin
> **Pending Review** drill-down (Summary → Branch → Employee → Task; new
> `pending_review_screen.dart` + `/admin/review` route; review CTAs rewired off the
> branch-operations overview); **§2** employee home counts only the **active
> operational window** (new pure `active_window.dart` — approved-today counts,
> older approved drops out, so "Done X/Y" stops growing forever); **§4** a broadcast
> no longer notifies its **own sender** for implicit audiences (everyone/branch/role
> — explicit DM/custom honoured); **§6** **approved tasks are locked** (cubit guards
> + admin-only `reopenTask` + `firestore.rules` backstop + locked UI on card &
> detail). `flutter analyze` clean (0 issues); **162 tests pass** (+5
> `active_window_test`); `node --check functions/index.js` valid. ⚠️ **Deploy**
> `firestore:rules` (approved lock) + `functions` (sender self-exclude).
> **Prompt items already done / rejected:** §3 FCM (array already correct), §7 swap
> workflow (coworker→manager flow already exists), §5 notif UI (badges/swipe were
> deliberately removed in the 2026-06-24 lean pass). **Deferred slices:** §8 branch
> media, §9 DROP brand presence, §10/§11 premium-card/component system.

> **Schedule grid premium redesign (2026-06-24):** Reworked the admin + manager
> weekly schedule grid (shared `ManagerScheduleView` → `ScheduleGrid` →
> `ShiftCell`) from a bare assigned-**count** tile into a glanceable "who's on"
> surface, on the same days-as-columns / shifts-as-rows model. A staffed cell now
> shows an **avatar stack + names** ("Ahmed M." · "+N more") on a top-lit
> elevated card; an empty cell is a **dashed** "No one" placeholder with a
> person-add glyph; today keeps the white ring; orphan refs still flagged (never a
> uid). The **shift rail** gained an icon tile + **time range** (brightness, not
> colour, separates morning/night), and cells widened (86→128w · 78→122h) to fit
> faces. The **coverage card** is now icon tile + "N of M shifts covered" + a
> **% pill** + a monochrome **progress bar**, with a one-line tap/scroll hint
> above the grid. **Strictly monochrome** — the source mockup's purple/gold/blue
> and its "X open"/"X of N" **staffing-quota** framing were intentionally not
> adopted (quotas remain a settled product rejection). Presentation-only: no
> schema / rules / route / DI / cubit / freezed change; new `shortName` helper.
> `flutter analyze` clean (0 issues); **157 tests pass** (`schedule_grid_test`
> updated to the new cell — names/avatars + "No one" empty state).

> **Perf-audit regression fixes (2026-06-24):** A validation/regression audit of
> the Phase A–D work (analyzer clean, 157 tests pass on the current toolchain —
> Flutter 3.44.2 / Dart 3.12.2, so the "Dart 3.10.4 can't analyze" notes below
> are **stale**) found two real regressions, now fixed. **L1 — offline admin
> stats:** Phase A's `adminStats` `count()` aggregation is **server-only** (no
> offline cache), so it threw `unavailable` offline and hard-failed the admin
> dashboard. `_aggCount` now falls back to counting the **same query's** cached
> docs (`Source.cache`) when offline — online path unchanged (pure aggregation,
> zero doc downloads); non-offline errors still rethrow. **L3 — task stream
> scope:** `TaskCubit.load`'s idempotency guard keyed only on `uid`, so a same-uid
> role/branch change kept streaming the wrong scope (admin/manager/employee use
> different streams). The guard + cache-clear now key on the full
> `_scopeKey = uid:role:branchId`; identical-scope revisits still no-op. Remaining
> audit findings (stats not invalidated on mutation, singleton reset on logout,
> startup double-fetch, broadcast entrance-anim skip, missing optimization tests)
> are **deferred** — not addressed here.

> **Performance · Phase D — two targeted UI rebuild fixes (2026-06-24):** A
> rebuild/render audit found the app **already healthy** (scoped BlocBuilders,
> `context.select`, keyed list items, no blur/`saveLayer`-heavy rendering) with
> exactly **two** hotspots — fixed here; no broad refactor. **① Admin dashboard
> (`admin_dashboard_screen`)** — removed the two top-level `context.watch`
> (`StatisticsCubit` + `TaskCubit`) that rebuilt the *entire* screen on every
> all-branches task emit. The ListView scaffold + static sections (Overview /
> Quick actions / Manage headers + grids) now build **once**; data sections
> subscribe via `_StatsSection` (`BlocBuilder<StatisticsCubit>` — greeting,
> metric grid) and `_DynamicSection` (stats + `BlocSelector<TaskCubit, int>` on
> the **overdue count** — hero, Pending Actions). So a task emit rebuilds only
> hero + Pending Actions, and **only when overdue actually changes**. Every
> section's `EntranceFade` is **keyed** (no replay when the conditional "Pending
> approvals" section appears); `_Hero` now takes a pre-computed `overdue` int.
> **② Broadcast feed (`communications_screen`)** — non-lazy `ListView` →
> `ListView.builder`; cards **keyed by `broadcast.id`** (not index); the entrance
> animation plays **once per id** (tracked in `_entered`) so a live-stream emit or
> a scroll-recycle never replays it (removes feed flicker, scales to long
> histories). Behaviour preserved exactly; no schema / rules / DI / freezed
> change. ⚠️ Toolchain unchanged (Dart 3.10.4 < `^3.12.1`) — verify
> `analyze`/`test` on a current SDK. **Performance work (Phases A–D) is
> complete** pending on-device profiling.

> **Performance · Phase C — warm startup (2026-06-24):** Make Home paint with
> real data, not skeletons, with **no preload framework** and ~6 lines total.
> **Audit headline:** the startup bottleneck was **not** reads — it was a
> hardcoded **2400 ms artificial splash delay** (`splash_page._initSession`'s
> `Future.delayed`), ~1 s of which was dead time after the 1400 ms brand
> animation. **① Splash floor trimmed** 2400 → **1400 ms** (matches the
> animation). **② Warm-start preload** — the existing app-wide
> `BlocListener<AuthCubit>` in `main.dart` (fires on `authenticated` for **both**
> cold-start restore **and** fresh login) now also calls `StatisticsCubit.load(u)`
> + `TaskCubit.load(u)`, **gated on `u.hasAppAccess`**, fire-and-forget +
> concurrent (per-cubit error isolation). The fetch overlaps the splash/route
> transition; Phase A **idempotency** means Home's own `initState` loads then
> no-op (no duplicate reads). **Not preloaded:** templates, branches, schedule,
> pending queues (lazy / already-cached / screen-specific — preloading them would
> be wasted reads). No new files / classes / schema / rules / DI / freezed change.
> ⚠️ Toolchain unchanged (Dart 3.10.4 < `^3.12.1`) — verify `analyze`/`test` on a
> current SDK. **Caching/perf work (Phases A–C) is complete** unless profiling
> surfaces a new hotspot.

> **Performance · Phase B — repository-level caches for branches + templates
> (2026-06-24):** Lightweight in-memory caching for the two highest-ROI read
> hotspots, **inside the existing repositories** — no generic cache framework, no
> Hive/Isar/SharedPreferences, no `CacheService`/`CacheManager` classes. Same
> private shape in each: `_cachedX` + `_xFetchedAt` + TTL + `forceRefresh` param +
> `_invalidateX()` on every write. **① Branch cache** — `BranchRepositoryImpl`
> caches the active branch list (**10-min TTL**); because the repo is a **single
> shared instance**, this dedupes **all six** branch reads at once (`BranchCubit`,
> `TaskCubit._loadBranchNames` + admin picker, `AdminUsersCubit`, `BroadcastCubit`)
> with no call-site changes except `BranchCubit.load({forceRefresh})` for the
> branch-mgmt pull-to-refresh. Invalidated on create/update/setActive/delete; the
> `includeDeleted` variant is never cached. **② Template caches** —
> `TaskRepositoryImpl.getTemplates` and `BroadcastTemplateRepositoryImpl.getTemplates`
> cache the (tiny, full-collection) template lists (**20-min TTL**), invalidated on
> every template write (task: create/delete; broadcast: create/update/setFavorite/
> incrementUsage/delete). **Stale-data:** both template reads are unconstrained
> full-collection queries (branch scoping is client-side), so the cached value is
> global — safe to reuse across sessions; the manage-sheet delete re-reads and now
> gets the invalidated (fresh) list. No schema / rules / route / DI / freezed
> change. ⚠️ Toolchain unchanged — Dart 3.10.4 < `^3.12.1` here, so verify
> `analyze`/`test` on a current SDK.

> **Performance · Phase A — caching groundwork without a cache framework
> (2026-06-24):** Surgical fixes to stop redundant Firestore reads + screen
> reloads, deliberately *without* a generic cache service / Hive / Isar (a
> dedicated cache layer is to be **reassessed after** measuring Phase A). **①
> `ProfileCubit.loadProfile` idempotent** — a revisit for a uid already in memory
> skips the re-read + skeleton (fixes the Profile "full reload"); `save` stamps
> the same `_loadedUid`. **② `StatisticsCubit.load`** caches a recent result
> (90 s, keyed role+uid+branch) and won't refetch or flash a skeleton on a
> revisit. **③ `TaskCubit.load` idempotent** — no re-subscribe / skeleton when
> already streaming the same user (errors still retry; `refresh()` forces). The
> three dashboards' pull-to-refresh now pass `forceRefresh`. **④ `adminStats`
> query** — the one unscoped aggregate stopped scanning **all** users/tasks/
> schedules: now **server-side `count()` aggregation** for the pure counts +
> **bounded single-field reads** (managers-only · this-week-onward schedules ·
> today's rejections). Same numbers, all single-field (no composite index).
> ⚠️ **`count()` needs cloud_firestore aggregation** (already on `^5.4.4`); the
> local toolchain (Dart 3.10.4 < `^3.12.1`) **can't run `analyze`/`test` here** —
> verify on a current SDK. No schema / rules / route / DI / freezed change.

> **Stabilization pass (2026-06-23):** Trust-but-verify checkpoint before resuming
> feature work. **Corrects stale doc claims** — the local SDK (**Flutter 3.44.2 /
> Dart 3.12.2**) **builds this project fine**; earlier "SDK too old, freezed
> hand-edited" notes are obsolete (`build_runner` was re-run — 3 freezed files had
> cosmetic-only formatting drift, now regenerated). **`flutter analyze` is clean
> (0 issues)** — fixed 3 real issues (unused import in `broadcast_templates_screen`,
> `activeColor`→`activeThumbColor` deprecation in `broadcast_schedules_screen`,
> `use_null_aware_elements` in `compose_broadcast_screen`). **The suite is now 164
> tests (all pass)** — earlier "117 tests" was stale. **`NotificationType` trimmed
> 27 → 11 values**: removed 16 reserved schedule/swap/admin types that had **no
> producer** (every remaining value has a live trigger); the coupled, now-empty
> **System** inbox filter was removed too (inbox is All / Unread / Tasks /
> Broadcasts). No feature work, no schema change to live data (trimmed types were
> never written). ⚠️ The deploy debt is unchanged — the 7 Cloud Functions remain
> undeployed (see Suggested next steps #5).

> **Communications Center · Phase 2 — Commit 6 (2026-06-22) — FINAL:** Communications
> **analytics** via **precomputed aggregates**. A monthly rollup
> **`analytics/{YYYY-MM}`** (`totals.{metric}` + `days.{DD}.{metric}`) maintained
> by Cloud Functions (`bumpAnalytics` in `dispatchBroadcast`/`onNotificationCreated`
> + new `onNotificationRead` + `onBroadcastOpened` triggers). Open-tracking via an
> idempotent `broadcastOpens/{bId_uid}` guard (`BroadcastCubit.trackOpen` from the
> detail screen). Read slice: pure `CommsAnalyticsEntity` (+ derived rates) +
> `CommsAnalyticsRepository(+Impl)`/datasource (one-doc read), on
> `AppDependencies.commsAnalyticsRepository`. Dashboard
> `communications_analytics_screen` (`/communications/analytics`): broadcast +
> notification metrics · daily-volume bar chart · engagement bars (read-once
> FutureBuilder). Rules: `analytics` (admin/manager read · function-only write).
> **Deferred:** response-latency charts (not modelled). ⚠️ Deploy
> `firestore:rules,functions`. **🎉 The 6-commit Communications Center Premium
> Upgrade (history → templates → audiences → scheduler → reminders → analytics) is
> complete.**

> **Communications Center · Phase 2 — Commit 5 (2026-06-22):** Automated **task
> reminders**. `NotificationType` + `taskReminder`/`taskOverdue`. Pure
> **`ReminderRules`** (`lib/features/task/domain/reminder_rules.dart`): escalates
> due24h → due1h → overdue (each once, forward-only) with quiet hours + a
> maxReminders cap. Cloud Function **`runTaskReminders`** (every 30 min: scan
> `deadline <= now+24h`, skip terminal/deadline-less, read the per-task
> **`taskReminders/{taskId}`** ledger, write a reminder per assignee + advance the
> ledger; pushed by `onNotificationCreated`). Config in **`reminderConfig/global`**
> (defaults when absent; quiet hours in UTC). Rules: `taskReminders` (function-only,
> admin read) + `reminderConfig` (admin write · admin/manager read). **Deferred:**
> a reminder-config editor UI (config is a Firestore doc today). ⚠️ Deploy
> `firestore:rules,functions` (Blaze + Cloud Scheduler). **Pending:** analytics
> dashboard (final commit).

> **Communications Center · Phase 2 — Commit 4 (2026-06-22):** The **scheduler** —
> recurring / one-time broadcasts. Architecture = a **single `onSchedule` poller**
> (`runBroadcastSchedules`, every 5 min: `nextRunAt <= now`, JS-filter enabled,
> fire via `dispatchBroadcast`, advance `nextRunAt`/disable) — scales to unlimited
> schedules with one cron, no composite index. New **`broadcastSchedules`** slice:
> `BroadcastScheduleEntity` (**plain immutable** value object — 20 fields, no
> freezed to avoid generated-file drift), `BroadcastScheduleModel` (with
> `targetUserIds`), repo/datasource, freezed **`BroadcastScheduleState`** +
> repo-direct **`BroadcastScheduleCubit`** (create/pause/resume/cancel). Pure
> **`RecurrenceRule`** + `BroadcastRecurrence` enum. UI: `broadcast_schedules_screen`
> (`/communications/schedules`: next-run · recurrence · run-count · pause/resume ·
> cancel) + a composer **Schedule** sheet (first-send date/time · cadence · custom
> interval · end date) + **Schedule Again** from history. New
> **`broadcastHousekeeping`** (daily retention cleanup). ⚠️ Deploy
> `firestore:rules,functions` (Blaze + Cloud Scheduler). **Pending:** reminders ·
> analytics dashboard.

> **Communications Center · Phase 2 — Commit 3 (2026-06-22):** Advanced recipient
> targeting. New **`BroadcastAudience.custom`** (multi-recipient; `__custom__`
> marker + `targetUserIds` array, never in a branch feed). `targetUserIds` +
> `roleFilter` are threaded as **send-time intents** through `SendBroadcast`/repo/
> datasource/`BroadcastCubit.send` → the callable (no `BroadcastEntity` change).
> The composer's individual picker is now a **multi-select "People"** picker with
> **Select all / Clear** (1 → DM, 2+ → custom); branch/all sends gain a **role
> filter** (Everyone / Managers / Employees). `dispatchBroadcast` resolves custom
> via `getAll` (manager picks filtered to own branch) + applies `roleFilter`;
> `broadcasts` read rule allows `uid in targetUserIds`. `BroadcastPermissions`
> gains custom; `allowedAudiences` lists only selectable chips. **Deferred:** saved
> audiences. ⚠️ Deploy `firestore:rules,functions`. **Pending:** scheduler ·
> reminders · analytics dashboard.

> **Communications Center · Phase 2 — Commit 2 (2026-06-22):** Broadcast
> **templates** + a `{{placeholder}}` engine + a premium **composer**. New
> `broadcastTemplates` slice: `BroadcastTemplateEntity`/`Model`/`Repository(+Impl)`/
> `RemoteDataSource` + repo-direct **`BroadcastTemplateCubit`** over a new
> `broadcastTemplates/{id}` collection (rules mirror `task_templates`); pure
> **`TemplateRenderer`** (`extract`/`render`/`hasUnresolved`). **Template library**
> (`broadcast_templates_screen` + `template_card`): grid/list toggle · search ·
> category filter · favorites · recents · create/edit editor with placeholder
> quick-insert; reached from the Communications app-bar and in **pick mode** from
> the composer. **Composer** now has priority + channel selectors, character
> counters, a rich live preview, and Use-template / Save-as-template. Route
> `/communications/templates`. ⚠️ Freezed hand-edited (run build_runner) + deploy
> `firestore:rules`. **Pending (next commits):** advanced audiences · scheduler ·
> reminders · analytics dashboard.

> **Communications Center · Phase 2 — Commit 1 (2026-06-22):** First of a 6-commit
> **Premium Upgrade** (history → templates → audiences → scheduler → reminders →
> analytics). This commit adds the **data backbone**, the broadcast **history
> lifecycle**, and **Notification Center management**. **① Enums** —
> `BroadcastPriority` (low/normal/high/emergency) + `BroadcastChannel`
> (push/inbox/both), orthogonal to `BroadcastCategory`. **② Broadcast schema** —
> `priority`, `channel`, `openedCount`, `archivedAt`, `deletedAt` on
> `BroadcastEntity`/`Model` (+ `isActive`/`failedCount` getters), all back-compat.
> **③ History UI** — the feed is now Active/Archived/Deleted with per-item actions
> (Open · Repeat Now · Duplicate · Schedule Again *(pending Scheduler)* · Archive ·
> Delete/Restore), confirmation dialogs, a richer card (priority · failed · status)
> and a detail screen with **delivery analytics** (recipients · delivered · failed ·
> open rate). Archive/soft-delete are **field-restricted client writes** (rule
> freezes all but `archivedAt`/`deletedAt`); content + stats stay function-owned.
> **④ `sendBroadcast`** refactored into a reusable **`dispatchBroadcast()`** (priority
> → FCM priority; channel gates push/inbox). **⑤ Notification Center** — `archivedAt`/
> `pinnedAt` on notifications; **delete/archive/pin**, **search**, **type filters**,
> **archived view**, **date grouping** (pinned first), **swipe**, and **infinite
> pagination** (growing-window ordered stream via a new composite index). ⚠️ The
> local Flutter SDK can't build this project, so freezed files were **hand-edited**;
> run `dart run build_runner build --delete-conflicting-outputs` + `flutter analyze`
> + `flutter test` on a current SDK. ⚠️ **Deploy** `firebase deploy --only
> firestore:rules,firestore:indexes,functions` (Blaze).

> **Notification System · Phase 1 (2026-06-22):** Task notifications + a rework
> distinction + broadcast persistence, on a real **in-app notification slice**.
> **① New `notifications` feature** (full vertical slice mirroring
> `communications`): freezed `NotificationEntity` (id · recipientUid · senderUid ·
> `NotificationType` · title · body · createdAt · readAt · payload) +
> hand-written `NotificationModel` over the new **`notifications/{id}`**
> collection, `NotificationRepository(+Impl)`/`NotificationRemoteDataSource`, the
> `NotifyTaskEvent` + `MarkNotificationRead` use cases, and an app-wide
> **`NotificationCubit`** (live feed + unread count + mark-read). New in-app
> **inbox** (`NotificationsScreen` + `NotificationTile`) at `/notifications`
> (every role), entered from the `RoleScaffold` **bell** (now with an unread
> dot). **② Task rework distinction** — `TaskEntity`/`TaskModel` gain
> `revisionNumber` / `requiresRework` / `rejectionReason` (back-compat defaults
> 0/false/null). A new **`TaskCubit.reworkTask`** ("Request Rework": bumps the
> revision, flags rework, → `taskRework`) sits beside a now-distinct terminal
> **`rejectTask`** (→ `taskRejected`); resubmit clears `requiresRework`. **③
> Automatic triggers** — `TaskCubit` fires the 5 task events (assign / rework /
> submit / approve / reject) best-effort after each write (newly-assigned
> employees only on assign). **④ Broadcast persistence** — `sendBroadcast` Cloud
> Function now also writes one `notifications/{id}` per recipient
> (category→`broadcast*` type; **emergency → `payload.priority=high`** + high FCM
> priority), flagged `pushedByFunction:true`. **⑤ Task push** — a new
> **`onNotificationCreated`** Firestore-trigger Cloud Function pushes FCM for
> client-written task notifications (skips broadcast docs to avoid a double
> push). **⑥ UI badges** — `task_badge.dart`: **NEW** (monochrome) · **REWORK
> #n** (amber) · **Rejected** (red) · **Approved** (green) on task cards; a
> distinct red **Reject** button added beside **Request Rework** in all three
> review surfaces. `NotificationType` extended additively. `flutter analyze`
> clean (0 issues); **117 tests pass** (+16: `notification_model` ·
> `task_model_rework` · `task_badge`); `node --check functions/index.js` valid.
> ⚠️ **Deploy required:** `firebase deploy --only functions,firestore:rules`
> (Blaze plan); until then in-app notifications work but **task push** is inert.

> **Communications Center · Phase 3 — Center UI (2026-06-21):** The role-gated
> UI on the Phase 1 + 2 backend (no backend-architecture change beyond what the
> UI required). **Entry point:** a campaign icon in the `RoleScaffold` header
> (admin + manager only) → new **`/communications`** area; the router's
> `_isCommunicationsArea` guard **blocks employees**. **Feed**
> (`CommunicationsScreen`): live broadcast cards (title · body preview · sender ·
> audience · time · delivery `recipientCount`/`deliveredCount`) from the cubit
> stream + a **New Broadcast** FAB; admin sees all, manager their branch +
> all-branches. **Compose** (`ComposeBroadcastScreen`): a role-gated form —
> audience chips from `BroadcastPermissions.allowedAudiences` (admin: Everyone /
> Branch / Individual · manager: Branch (own) / Individual (in-branch);
> unauthorized options **hidden**), an admin branch dropdown, a **searchable
> recipient picker**, category chips (announcement / alert / reminder /
> emergency), title + multiline body, and a sticky **Send Broadcast** CTA →
> `BroadcastCubit.send` → success snackbar *"Broadcast sent to N recipients"* →
> back. **Detail** (`/communications/:broadcastId`): full message · sender ·
> category · audience · sent date · recipient + delivered counts (resolved from
> the tapped entity via `extra`, live-feed fallback). New `BroadcastCategory`
> enum; `deliveredCount` now persisted by the function; `BroadcastCubit` gains
> `branches()`/`branchUsers()` pickers; `AppTextField` gains `maxLines`. Built on
> the shared design system (`GlassContainer`, `AppButton`, `AppDropdownField`,
> `AppSearchField`, `UserAvatar`, `EntranceFade`), strictly monochrome.
> `flutter analyze` clean (0 issues); **101 tests pass** (+6:
> `broadcast_category_test` + `broadcast_card_test` widget render +
> `broadcast_model` deliveredCount). ⚠️ Deploy `functions` for the delivered-count
> write. **Communications Center is now end-to-end** (compose → push → feed →
> detail). The Phase 2 deploy notes still apply (Blaze plan, iOS APNs).

> **Communications Center · Phase 2 — notification send engine (2026-06-21):**
> Built the **push delivery engine** on the Phase 1 slice (architecture
> preserved). **① Recipient resolution / permissions** — pure
> `domain/broadcast_permissions.dart` (`BroadcastPermissions`): admin → all
> users / any branch / any user; manager → own branch / a user inside it;
> employee → none. Client guard + UI affordance, **re-enforced authoritatively**
> server-side. **② FCM token storage** migrated to a **`users/{uid}.fcmTokens`
> array** (multi-device): `NotificationService` `arrayUnion`s on register +
> token-refresh (rotating the stale token) and `arrayRemove`s this device on
> sign-out; registered on login/app-start via the `AuthCubit` listener. **③
> Cloud Function `sendBroadcast`** (`functions/index.js`, callable, Node.js +
> firebase-admin) — the new **backend send engine**: validates sender
> permissions, resolves recipients, **writes** `broadcasts/{id}` (Admin SDK),
> gathers recipient `fcmTokens`, pushes via `sendEachForMulticast`, prunes dead
> tokens, and returns `{ success, recipientCount, deliveredCount, broadcastId }`.
> Clients no longer write the doc — `BroadcastRemoteDataSource.sendBroadcast`
> invokes the callable; `firestore.rules` now **deny all client writes** to
> `broadcasts`. **④ Payload** carries title · body · category · senderId ·
> broadcastId. **⑤ Flutter receive handling** — foreground (snackbar),
> background (OS-rendered), and tap (`onMessageOpenedApp` + `getInitialMessage`
> → navigate + log) in `NotificationService` + `main.dart`. New
> `BroadcastAudience.user` (DM, stored with a `'__direct__'` branchId marker +
> `targetUserId` so it never leaks into a branch/all feed). New dep
> `cloud_functions`; new `functions/` codebase + `firebase.json` functions
> config. `flutter analyze` clean (0 issues); **95 tests pass** (+15:
> `broadcast_permissions_test.dart` + extended `broadcast_model_test.dart`);
> `node --check functions/index.js` valid. ⚠️ **Deploy required:**
> `firebase deploy --only functions,firestore:rules`; the function needs the
> **Blaze** plan; iOS needs APNs + the `remote-notification` background mode
> (console/native — not set here). **Next phase:** the Communications Center UI
> (compose with audience/recipient pickers + feed) and a broadcast detail route
> for deep-linked taps.

> **Communications Center · Phase 1 (2026-06-21):** First slice of the
> Communications Center — a **one-way broadcast** foundation. **Backend +
> cubit only**, no UI/routes yet (a later phase). New `communications` feature
> (full vertical slice): **`BroadcastEntity`** (id · title · message · sender
> id/name/role · `BroadcastAudience` · branchId · createdAt) + **`BroadcastModel`**
> (Firestore (de)serialization; all-branches stored with the **`''` branchId
> sentinel**), **`BroadcastRepository(+Impl)`** + **`BroadcastRemoteDataSource`**
> over the new **`broadcasts/{id}`** collection, the **`SendBroadcast`** use case,
> and a **hybrid `BroadcastCubit`** (mirrors `TaskCubit`: `SendBroadcast` for the
> write, repository directly for the realtime feed stream — `load({branchId})`
> subscribes, `send(...)` posts). New `BroadcastAudience` enum (allBranches /
> branch). Reads are **index-free + rules-safe**: admin feed
> `orderBy('createdAt')`, branch feed `where('branchId', whereIn:[branch,''])`
> (their branch + all-branches in one query, client-sorted newest-first). New
> `broadcasts/{id}` Firestore rules (admin all · own-branch manager sends their
> branch · branch members + everyone read all-branches · employees read-only).
> Wired in DI + `main.dart`. `flutter analyze` clean (0 issues); **80 tests pass**
> (+6 in `broadcast_model_test.dart`). **Next (later phases):** the Communications
> Center UI (compose + feed screens, role entry point/route) and optional
> notification fan-out on send. ⚠️ Deploy `firestore.rules` for the `broadcasts`
> collection before use.

> **Assign-on-create (2026-06-21):** The New/Edit Task form now has an **"Assign
> to"** picker (`_AssigneePicker` + `_EmployeeChip` in `task_action_sheets.dart`) —
> a manager/admin selects branch employees as they create a task (no more "create
> first, then assign"). `TaskCubit.createTask` gained an `assigneeIds` param (also
> threaded through `editTask`); the picker loads `branchEmployees(branchId)`
> (manager: fixed branch; admin: the picked branch, cleared on change). `flutter
> analyze` clean (0 issues); **80 tests pass**.

> **Branch Operations redesign — cockpit shipped (2026-06-21, steps 1–3):** The
> task-centric → **operations-centric** rework. The standalone task list is
> replaced by a **Branch Operations cockpit**: Admin dashboard (branch overview) →
> **Branch Operations** → Employee details → Task details; tasks now live *inside*
> operations (no dedicated Task Management destination). Strictly monochrome,
> reusing the existing component library. **① Schema (`tasks.shift`)** — optional
> shift tag (`ScheduleShift?`; **null = "any"**) on `TaskEntity`/`TaskModel` via the
> null-preserving `ScheduleShift.fromStringOrNull`; back-compat; supersedes the dead
> `assignedShiftId`. **② Domain** — pure `computeBranchWorkload` (`ShiftFilter` ·
> `EmployeeWorkload` · `BranchSummary` → `BranchWorkload`) joins the branch task
> stream × `getUsersByBranch` × today's `weekly_schedule` and sorts employees
> **overload-first**. **③ `BranchOperationsCubit`** (read/derive; repo-direct;
> `setFilter` re-derives without I/O) wired in `injection.dart`/`main.dart`; **writes
> still flow through `TaskCubit`** (same branch stream → live). **④ Screens** —
> `BranchOperationsScreen` (summary header · shift toggle · `WorkloadCard` list ·
> New-Task FAB · "All tasks"), `ManagerOperationsScreen` (manager's own branch, now
> the `/manager/tasks` page), `EmployeeDetailScreen` (tasks by status →
> `TaskDetailsScreen`), and the extracted public `BranchTaskListScreen`. **Retired:**
> `BranchTasksScreen` + `ManagerTasksView` deleted; the admin branch-overview drill
> now opens the cockpit. Freezed re-run. **74 tests pass** (+15: workload,
> task-shift, workload-card widget); the operations/task/core scope analyzes clean.
> *(Note: a separate, in-progress `communications`/broadcast feature is concurrently
> in the tree and currently breaks the whole-project `flutter analyze` — unrelated to
> this work.)*

> **Submission loading UX + status animations (2026-06-21, refined):** Two
> task-detail improvements. **① Video submit "freeze" fixed.** Root cause: the
> submit pipeline is async/non-blocking (uploads + write), but **no loading state
> was rendered** — `_CompleteButton` just `await`ed with the button left enabled
> (not a main-isolate block; thumbnails are display-time, not in the submit path).
> Fix: submission state now **lives on the cubit** — `TaskState.loaded` carries
> `isSubmitting` + `submissionProgress` (preserved on every emit, incl. the
> Firestore stream), so the **whole Task Details screen** reacts and progress
> survives rebuilds/disposal. The screen renders a **single, state-driven,
> interaction-blocking overlay**
> ([submission_loading_overlay.dart](lib/features/task/presentation/widgets/submission_loading_overlay.dart))
> with stages **Preparing media → Uploading attachments → Finalizing**, a **real
> progress bar + percentage + transferred/total MB** (aggregated from each Storage
> upload's `snapshotEvents`; emits throttled to whole-percent changes). `PopScope`
> blocks back during submit. Only `completeAndSubmit` sets `isSubmitting`
> (approve/reject/start use `busy`), so exactly one overlay can ever exist.
> **Thumbnails:** server-side poster upload was **dropped** (storage/complexity
> not justified for low video volume) — videos use **local generation + caching**
> (`VideoThumbnailImage`, in-memory LRU) at view time. `durationMs` is still
> captured at pick. **② Premium status animations** (monochrome-preserving): the
> status header has a soft status glow — **amber pulse for In Review**, static
> **green** (Approved) / **red** (Rework) glow + faint tint; the status badge
> **cross-fades + scales** on change; timeline cards **stagger-fade in** (reused
> `EntranceFade`). `flutter analyze` clean (0 issues); **59 tests pass**.

> **Submission Details surface (2026-06-21):** Split the overloaded timeline into
> a **scan layer** + a **deep review layer**. Timeline event cards are now
> **summaries only** — status · actor · timestamp · attachment summary
> ("2 photos · 1 video") · truncated note preview (2 lines). Tapping a
> **submission-related** card (`completed` / `waitingReview`) opens the new
> **`SubmissionDetailsSheet`** — a large iOS-style modal (~90% height, no
> full-screen route) that is the full review surface: header (task · "Completed
> by Ziad · 21 Jun 2026 • 4:59 AM"), **Employee Response** (full untruncated
> note), **Attachments** (premium 2-column `AttachmentGallery` grid — images
> tap→fullscreen+zoom, video cards with **real thumbnail + duration + play
> overlay**), **Manager Feedback** (the per-cycle approve/reject decision +
> note), and a **sticky Approve / Request Rework** bar for a pending submission
> (read-only otherwise). The cycle is resolved from the activity log by the pure
> [`resolveSubmission`](lib/features/task/presentation/attachment_format.dart)
> (content event + the decision that followed it — handles rework loops). Media
> rendering is reused, not duplicated (`AttachmentGallery` + `AttachmentViewer`).
> **Video duration** is now captured at pick (best-effort via `video_player`),
> stored on `TaskAttachment.durationMs`, and shown as `mm:ss`. `flutter analyze`
> clean (0 issues); **54 tests pass** (+`submission_resolution_test.dart`).

> **Task submission media upgrade (2026-06-20):** Replaced the single proof image
> with **multiple images + videos**, attached to **task events** (not the task
> globally) per the preferred architecture. New `TaskAttachment` entity
> (`id · url · type · uploadedAt · uploadedBy · uploadedByName`) + `AttachmentType`
> enum (image/video); `ActivityEntry` now carries `List<TaskAttachment>
> attachments`, so each submission / rework cycle keeps its own evidence.
> **Storage:** `tasks/{taskId}/attachments/{id}.<ext>` — unique id per upload,
> never overwritten (`storage.rules` widened to `{allPaths=**}`). **Submission
> flow:** the employee picks multiple photos / videos (gallery **or** camera /
> record) with **separate** limits via `AttachmentLimits` (≤6 photos ≤15 MB each ·
> ≤3 videos ≤200 MB each · 3-min cap). Photos are **resized + recompressed before
> upload** (image_picker `maxWidth 1600` / `quality 70`) to cut Storage cost;
> uploads run in **parallel** (`Future.wait`, order preserved) before the status
> write, so a failure aborts the submit and keeps the selection. (True video
> transcoding is deferred — bounded by the duration + size caps instead of adding
> a heavy native codec dep.) **Timeline:** manager/admin see media per
> event via a premium `AttachmentGallery` (image grid + video tiles with play
> overlay) → fullscreen `showAttachmentViewer` (swipeable, **pinch-zoom images**
> via `InteractiveViewer`, **inline `video_player`**), each captioned "Uploaded by
> X · 20 Jun 2026 • 4:32 PM". Legacy `proofImageUrl` is kept in sync (first image)
> and surfaced as a synthesized attachment for old tasks (no double-render). New
> dep **`video_player`**; new use case `UploadTaskAttachment` (replaces
> `UploadTaskProof`). New iOS `NSMicrophoneUsageDescription`. **Newest-first
> task lists:** the admin query uses Firestore `orderBy('createdAt', descending:
> true)` (index-free); the **filtered** branch/employee queries stay filter-only
> and are ordered by the client-side
> [`sortTasksNewestFirst`](lib/features/task/domain/task_ordering.dart) (pending-
> timestamp task pinned on top) — **no composite index required** (see the
> 2026-06-21 fix below). **Real video thumbnails** (`video_thumbnail`):
> `VideoThumbnailImage` extracts a cached poster frame for the gallery + picker,
> play overlay on top, film-glyph fallback. `flutter analyze` clean (0 issues);
> **51 tests pass**. ⚠️ Deploy `storage.rules` (`firebase deploy --only storage`)
> for the attachments path; video playback / thumbnails need an on-device check.

> **Fixes (2026-06-21):** ① **Employee/manager "Failed to load tasks" regression** —
> root cause: the newest-first follow-up added `orderBy('createdAt')` to the
> **filtered** task queries (`where('assigneeIds', arrayContains:…)` /
> `where('branchId', …)`), which requires a **composite index** that wasn't
> deployed → Firestore threw `failed-precondition` on the snapshot stream →
> `TaskCubit`'s `onError` (which **swallowed** the real exception) showed the
> generic message. Fix: dropped server-side `orderBy` from those two queries
> (they now use Firestore's automatic single-field array/equality index, as
> before) and rely on the existing client-side `sortTasksNewestFirst`; admin
> keeps its index-free `orderBy`. `firestore.indexes.json` emptied (no composite
> index needed). `TaskCubit` stream `onError` now logs the real error + stack via
> `dart:developer` so future failures are diagnosable. ② **Real video thumbnails**
> replaced the static dark placeholder (see above).

> **Schedule assignment-grid redesign (2026-06-20):** Re-architected the
> manager/admin schedule from **first principles** — from vertical day cards to a
> weekly **assignment grid**, an *operations-control surface* that answers
> "who's on each shift, what's empty, what's broken, what needs approval" in
> seconds. New mental model: **days = columns (Sun→Sat), shifts = rows
> (Morning/Night)**; each cell is a tappable tile showing **how many employees
> are assigned** — a monochrome **density tint** (more people = brighter), a
> muted **"Empty"** state for unmanned shifts, a white ring on today, and an
> orphan flag. Horizontally scrollable with a **pinned shift rail + day headers**
> for mobile. **No staffing quotas / required-headcount / understaffed-vs-target
> model** — the schedule represents *assignments*, and the admin assigns by
> operational judgment, not fixed capacity. Tapping a cell opens a rich
> **shift-details sheet** (neutral "N assigned" / "No one assigned yet", employees
> as premium rows with double-booking conflicts, assign/remove, resolve). Broken
> references are **excluded from the count and flagged**, never shown as a uid.
> **Swap "Requests" tab removed** — swaps surface as a **floating
> `SwapAlertCard`** that opens a queue modal (reusing `SwapListView`, with
> submitted-time); cards show requester · branch · shift · reason · time.
> **Broken assignments** are user-friendly: a `BrokenAssignmentBanner` → resolve
> sheet with **Remove / Reassign** per slot, labelled `Day · Shift` + "Former
> employee" (no uid, ever). Both host screens (`BranchScheduleScreen` manager,
> `ScheduleManagementScreen` admin) are now a **single surface** (tabs gone). New
> reusable widgets: `ScheduleGrid`, `ShiftCell`, `EmployeeRow`,
> `ShiftDetailsSheet`, `SwapAlertCard`, `BrokenAssignmentBanner`, shared
> `showEmployeePicker` + `SheetHandle`. `flutter analyze` clean (0 issues);
> **39 tests pass** (incl. headless `schedule_grid_test.dart` proving rendered
> assigned-count, empty state, orphan flag, no-uid-leak, cell-tap routing, shift
> filter).

> **Premium UI redesign (2026-06-20):** Visual refinement pass (monochrome,
> token-driven, no schema/logic change). ① **Branch Schedule** rebuilt for
> density/premium — compact **date-rail + shift-lane** day cards (`_dateRail`/
> `_shiftLane`), round **+** add affordance, refined avatar chips, tighter padding.
> ② **Admin Home** tightened — single-line greeting (`h1`), reduced section gaps,
> a denser hero (metric beside title+summary, throughput in the eyebrow). ③ **Task
> timeline** upgraded to rich **event cards** (status badge + `activityIcon`,
> actor avatar + role, quoted note, attachment thumbnail). `flutter analyze` clean;
> 35 tests pass.

> **Product/UI verification pass (2026-06-20):** Driven by real-UI review — fixed
> things that were coded but **broken/unreachable in the actual flow**. ① **Admin
> Pending Actions was invisible** (gated behind `if (count > 0)`); now **always
> rendered** with an "all caught up" state, and **extracted to a public, widget-
> tested** component
> ([pending_actions.dart](lib/features/admin/presentation/widgets/pending_actions.dart)).
> ② **Branch Schedule "Unknown"** is a stale-reference bug (a uid whose owner left
> the branch); now **detected** (`isOrphanAssignment`), **surfaced** (warning
> banner + distinct "Unknown member · <uid>" chip), and **resolvable** (tap →
> confirm → remove, then reassign). ③ **Admin had no UI to see/approve swaps** —
> `ScheduleManagementScreen` is now a **two-tab** screen (Schedule · Swap Requests)
> with an **all-branches** queue (`ShiftSwapCubit.loadAll`/`SwapScope.all`/
> `getAllSwaps`), branch-labelled cards, and auto-refresh on approval. ④ **Employee
> no longer offered "Swap" on past shifts** (muted "Past" label, in lock-step with
> `SwapEligibility`). `flutter analyze` clean; **35 tests pass** (25 + 10 new incl.
> headless widget tests). ⚠️ True on-device click-through still requires a seeded
> admin + live Firebase (see QA note below) — Flutter UI isn't renderable in CI.

> **Shift-swap hardening + Admin Pending Actions (2026-06-20):** First slice of the
> Operations refinement spec. **§2 "future shifts only" swap validation** is now
> enforced in three layers — domain (new pure
> [`SwapEligibility`](lib/features/schedule/domain/swap_eligibility.dart):
> `slotStart` + `isRequestable`), the `ShiftSwapCubit.requestSwap` gate, the
> Request-Swap sheet, and a `firestore.rules` `shift_swaps` create backstop
> (`swapSlotInFuture` recomputes the slot start from `weekStart`/`day`/`shift` and
> requires `> request.time`). A past or in-progress shift can no longer be swapped.
> **§1 Admin Home "Pending Actions"** replaces the low-value "Recent activity" feed:
> a consolidated, actionable queue (Swap Requests · Employee Approvals · Tasks
> Waiting Review · Overdue Tasks), each a tappable row jumping to where it's
> resolved. New `ScheduleRepository.getAllSwaps()` + `ShiftSwapCubit.pendingSwaps()`
> give the admin all-branch swap visibility. No schema/entity/route change; no
> codegen. `flutter analyze` clean (0 issues); **25 tests pass** (17 + 8 new in
> `swap_eligibility_test.dart`). ⚠️ Deploy `firestore.rules` for the server backstop.

> **Admin command-center redesign + component library (2026-06-19):** Premium
> rebuild of the **Admin** experience on a new shared component library — keeping
> the existing **strictly-monochrome** `AppColors` (owner kept the palette).
> **New `core/widgets`:** `GlassContainer` (the one shared premium surface —
> gradient·border·depth·press/hover; `HeroStatCard` + `AdminUserCard` refactored
> onto it), `DashboardMetricCard`, `ActionCard`, `AdminSectionHeader`,
> `TimelineTile` (generic vertical timeline). The `TaskStatusChip` requirement is
> met by the existing `StatusBadge.task`. **Admin Home** (`admin_dashboard_screen.dart`)
> rebuilt into a command center: greeting header → focal **hero** (pending
> approvals → reviews → overdue → all-clear, with metric·summary·progress·CTA) →
> `DashboardMetricCard` overview grid → `ActionCard` quick actions → pending-
> approvals preview (read-only `AdminUsersCubit.pendingUsers()`) → recent-activity
> feed (`TimelineTile` from the live task `activityLog`) → Manage grid. Reads
> `StatisticsCubit` + the `TaskCubit` all-branches stream + pending users.
> **Employees page** now uses a new `EmployeeCard` (identity + active badge +
> Completed/Pending/Rate/Late metric strip) — metrics derived from the task stream
> via the pure `computeEmployeeMetrics` (`admin/presentation/employee_metrics.dart`,
> unit-tested). Task-details timeline + admin feed share `TimelineTile` +
> `activity_format.dart` (`activityTitle`/`activityColor`/`relativeTime`). The
> spec's event-based task timeline is **already** the `activityLog`/`ActivityEntry`
> model (rendered dynamically — missing/optional steps + rework loops supported).
> No schema/route/entity/rule change; no codegen. `flutter analyze` clean (0
> issues); **17 tests pass** (12 + 5 new in `employee_metrics_test.dart`).

> **Admin tasks setState fix (2026-06-19):** `AdminTaskOverviewScreen._load()` was
> calling `setState(() => _branchesFuture = context.read<TaskCubit>().branches())`
> — the `=>` arrow made the lambda return the Future, triggering Flutter's
> `setState() callback returned a Future` error at runtime. Fixed: the Future is
> now captured before `setState`, and the state update uses a block body (`{}`).
> Also resolved the 2 pre-existing `prefer_initializing_formals` linter infos
> (`AuthCubit._signInWithEmail`, `ProfileCubit._updateProfile`). `flutter analyze`
> clean — **0 issues**.

> **Employee schedule premium redesign (2026-06-19):** `my_schedule_screen.dart`
> rebuilt from scratch. `_MyWeekTab` is now a `StatefulWidget` with a single
> `AnimationController` (900 ms) and per-section staggered `FadeTransition` +
> `SlideTransition` (greeting 0–35%, hero card 15–55%, week header 30–60%, week
> rows staggered 40–90%). Greeting section shows time-based salutation ("Good
> morning/afternoon/evening, [FirstName] 👋") + formatted date. **Today hero card**
> redesigned: rounded-square shift icon, "TODAY" pill badge, shift name headline,
> time-range + "In Xm" countdown pill (appears when shift starts within 2 h),
> two-column Manager + Working-with section (avatar + name + role label; named
> avatar stack with first-name summary), "View Shift Details" tappable divider row
> → `_ShiftDetailsSheet` modal with full team list. **Week rows** (all 7 days,
> Sun → Sat): `_DayChip` (3-letter abbrev + date number; today gets white filled
> box + dark text); shift icon circle; shift name + time; Swap / Today pill /
> "—" action. Notification bell added to app bar (cosmetic). `flutter analyze`
> clean (2 pre-existing infos).

> **Employee home redesign v2 (2026-06-18):** `employee_home_screen.dart` rebuilt
> into a live command center — an animated **circular progress ring** hero
> (`_RingPainter` CustomPaint, sweep + count-up) + today's shift, a count-up
> **stat strip**, and an **actionable** task list (Start a pending task inline →
> `TaskCubit.startTask`; Continue / View feedback; body tap → `TaskDetailsScreen`).
> All task counts/sections come from the **live `TaskCubit` stream** (ground
> truth — fixes the old "In progress" chip always reading 0, since `employeeStats`
> never sets `activeTasks`); only the shift comes from `StatisticsCubit`. Staggered
> entrances, `_Pressable` press feedback, last-good-snapshot cache (no flicker on
> inline actions), route-guarded error snackbars, "Open all tasks" → Tasks tab.
> Strictly monochrome; presentation-only (no new files/routes/cubits/schema).
> `flutter analyze` clean (2 pre-existing infos).

> **App branding (2026-06-18):** App icon replaced with DROP branding image on Android + iOS (all sizes auto-generated). App display name changed to **DROP** (AndroidManifest + Info.plist). Dart package name stays `fbro` internally.

> **Task workflow architecture (2026-06-18 — two passes):** Eliminated the double-write race condition and completed the single-write architecture. Every status transition is now one atomic `_updateTask` call that writes `status` + `activityLog` entry + per-transition audit timestamp in a single Firestore document write. **New fields:** `startedAt` (set by `startTask`) and `submittedAt` (set by `submitForReview` and `completeAndSubmit`), joining the existing `approvedAt`/`rejectedAt`. `ChangeTaskStatus` and `ReviewTask` use cases removed from `TaskCubit` (dormant on disk). `_canTransition` updated to include `started → waitingReview`. Freezed codegen re-run. `flutter analyze` clean (2 pre-existing infos only).
>
> **Task system pass (2026-06-19):** (1) **Proof-upload bug fixed** — `completeAndSubmit` now uploads proof **before** the status write, so a failed upload aborts the transition (task stays `started`, photo retained for retry) instead of silently submitting evidence-less work; the datasource maps Storage error codes to honest messages (unauthorized/object-not-found → "rules not deployed / Storage not enabled" instead of blaming the network) and adds a 60s upload timeout. (2) **Admin task experience redesigned** — `TaskManagementScreen` is now `AdminTaskOverviewScreen`: a branch overview (Active / Pending Review / Overdue / Completion Rate per branch, attention-sorted) with per-branch drill-down. (3) **Dead code removed** — `ChangeTaskStatus`/`ReviewTask` use-case files + the `updateStatus`/`reviewTask` repo+datasource chains + the unused `completeTask` cubit method; shared `ManagerTaskCard` + `startNewTaskFlow` de-duplicate manager/admin task UI. **Infra still required:** deploy `storage.rules` + ensure Firebase Storage is enabled, or proof uploads keep failing.

> **Inline checklist editor + form simplification (2026-06-18):** ① The Create/Edit Task form now has a fully **inline editable checklist** section (`_InlineChecklistEditor`). Managers tap "Add step" to add items, tap the star to toggle required/optional, tap × to remove. On create → items become `ChecklistItem`s; on edit → existing items preserve `completed`/`completedAt`, new items start uncompleted. Template-based tasks pre-populate the checklist editably (was read-only before). ② **"Type: daily/special" dropdown removed** from the form — it was visually redundant with "Repeats"; type is now auto-inferred (recurring → daily, one-off → special). `flutter analyze` clean.

> **Operations Workflow Upgrade + Product Review (2026-06-18):** Full enterprise task system on top of the existing architecture. **① Recurring Tasks** — `RecurrenceConfig` entity (frequency/interval/weekday/hour/minute) + `RecurrenceFrequency` enum; on approve `TaskCubit._spawnNextRecurrence` auto-creates the next task with checklist reset and deadline advanced; recurrence picker (chip row) in the task form. **② Activity Timeline** — `ActivityEntry` embedded array (`activityLog`) on every task; every status transition (create/start/submit/approve/reject) appends an entry with actor + timestamp + optional note; shown newest-first in the Task Details page. **③ Task Details Screen** (`task_details_screen.dart`) — full-screen scrollable: animated status/priority/deadline pills, assignee block with "Assigned by Name·Role", checklist with live progress bar, submitted work (notes + proof), activity timeline, role-appropriate action buttons. **④ Employee UX redesign** (`my_tasks_screen.dart`) — tabbed Active/Done, 5 sorted sections, animated entrance cards, slides into Task Details. **⑤ Product-review UX fix:** the two-step "Complete → re-open → Submit for Review" friction eliminated; `TaskCubit.completeAndSubmit` uploads proof + advances straight to `waitingReview` in one write; the "Mark Complete" expansion button is now **"Complete & Submit"**. `flutter analyze` clean. See [CHANGELOG.md](CHANGELOG.md).

> **Task UX overhaul (2026-06-18):** ① **Proof-photo "User is not authorized" fixed**
> — it's Firebase **Storage `unauthorized`** (rules not deployed / Storage not
> enabled); the code is now **resilient** (proof is best-effort — a Storage failure
> no longer blocks completing the task or loses notes; precise warning shown) and the
> **manager Review sheet now shows the submitted notes + proof image**. ⚠️ Still must
> **enable Storage + deploy `storage.rules`** for uploads to actually work. ②
> **Upload-failure error is now shown on the right screen** — `_submit()` in
> `_CompleteButton` is now `async`/`await`-ed so the error snackbar fires while
> `TaskDetailsScreen` is still open (was previously shown on `MyTasksScreen` after
> the pop — easy to miss). Error message is user-friendly (no developer jargon). ②
> **Task cards redesigned** — monochrome, scannable, no priority rail / coloured
> chips / loud badges; colour reserved for **destructive** actions only. ③ **"Assigned
> by Name · Role"** added to cards (resolves `createdBy`). ④ **Username removed** from
> profile editing (no operational value; legacy social field). `flutter analyze`
> clean; 12 tests pass. See [CHANGELOG.md](CHANGELOG.md).

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
| Weekly Schedule (Phase 7, +2026-06-20 grid redesign) | ✅ Complete | `schedule` feature: `WeeklyScheduleEntity` + `ScheduleCubit`. **Manager/admin view is now a weekly assignment grid** (`ScheduleGrid` + `ShiftCell`) — each cell shows **assigned head-count** (monochrome density tint + "Empty" state, **no staffing quota/target**); cell tap → `ShiftDetailsSheet` (assign/remove/resolve, conflicts). Single-surface screens (tabs removed). Employee keeps the My-Week view. Roster `day → morning/night → employees`; `weekly_schedules/{id}` rules |
| Shift Swap (Phase 7, +2026-06-20 hardening & grid) | ✅ Complete | `ShiftSwapEntity` + `ShiftSwapCubit`: employee requests → coworker approves → manager approves → schedule auto-updates; `shift_swaps/{id}` rules. Statuses pending/employeeApproved/managerApproved/rejected. **future-shifts-only** validation (`SwapEligibility`) in domain + cubit + UI + rules; admin all-branch visibility via `getAllSwaps()` / `pendingSwaps()`. **Swap tab removed** — surfaced as a floating `SwapAlertCard` → queue modal (reuses `SwapListView`, now showing submitted-time) inside the schedule grid |
| Tasks (Phase 3–4, +Stabilization, +Phase 9, +Workflow Upgrade, +Media Upgrade, +Shift Assignment) | ✅ Full operations workflow | Full vertical slice: `TaskCubit` + use cases, functional employee/manager/admin screens, client-side status-transition rules, **live Firestore streams**, admin branch dropdown, multi-assignee, checklist+completion gate. **Workflow Upgrade (2026-06-18):** recurring tasks, activity timeline (`ActivityEntry[]`), Task Details Screen, employee My Tasks redesign. **Media Upgrade (2026-06-20):** **multiple images + videos per submission**, attached to **task events** — `TaskAttachment` entity + `AttachmentType`; `ActivityEntry.attachments[]`; Storage `tasks/{id}/attachments/{id}.<ext>` (no overwrite); `AttachmentPickerField` (gallery/camera + limits), `AttachmentGallery` + fullscreen `AttachmentViewer` (zoom images, `video_player`). Legacy `proofImageUrl` kept in sync for back-compat. **Shift Assignment (2026-07-01):** a task can target a **shift** (Morning/Night) instead of named employees — visible only to whoever's rostered on it *today* (`canUserAccessTask`); recurring shift routines use a proper **template → generated daily instance** split (`recurringTaskTemplates` + `generateShiftTaskInstances` Cloud Function), not the per-task `RecurrenceConfig`. ⚠️ Needs `firestore:rules,firestore:indexes,functions` deploy to fully activate (see Known gaps) |
| Task / Checklist Templates (Stabilization, +Phase 9) | ✅ Complete | Reusable blueprints ("Open Shop", "Close Shop"). **Phase 9:** templates are now **checklists** — `TaskTemplateEntity.checklistItems` (`ChecklistItemTemplate`: id/title/isRequired) with a checklist editor; creating a task generates its `checklist`. `task_templates/{id}` rules (admin global/any · manager own-branch). New Task → Blank vs. From a template + Manage Templates sheet |
| Branches (Phase 5, +Phase 9) | ✅ Complete   | `BranchEntity`/`Model`/`Repository`/`RemoteDataSource` + `BranchCubit`; admin CRUD + activate/deactivate + soft delete; `branches/{id}` rules. **Phase 9:** premium cards (manager + employee count + status) + search |
| Admin module (Phase 5, +Phase 9 UX) | ✅ Complete | Branch / manager / employee management + **admin-only** pending-user approval + branch assignment. `AdminUsersCubit`, `UserAdminRepository` over `users/{uid}`. **Phase 9:** Admin Home restructured to **4 KPIs** + module nav; new **Analytics** page (`/admin/analytics`); avatar-led user cards; search + active/inactive/branch filters |
| Dashboards / Statistics (Phase 6, +Phase 7) | ✅ Complete | `statistics` feature (`StatisticsCubit`) drives **live** admin / manager / employee dashboards. **Phase 7:** shift/coverage figures read the weekly schedule. **Phase 9:** the full metric wall moved to the Analytics page; the Admin Home shows only 4 headline KPIs |
| Notifications (Phase 6 + Notification System Phase 1, +Comms Phase 2 Commit 1) | ✅ In-app inbox + management + task push | FCM client (permission + `fcmTokens` array + fg/bg/tap). Real **in-app inbox** — `notifications` slice + `notifications/{id}` + `/notifications` screen (bell + unread dot). **Automatic task triggers** (assign/rework/submit/approve/reject). **Push:** broadcasts via `sendBroadcast`; task events via `onNotificationCreated`. **Comms Phase 2 Commit 1 — Notification Center management:** `archivedAt`/`pinnedAt` fields; **delete · archive · pin**, **search**, **lean action inbox (2026-06-23 simplification)**: **All / Unread** filter only, **Needs action** group (assigned · rework · reminder · overdue) above **Earlier**, **tap to open** (marks read + **deep-links to the exact task** via `/task/:taskId`, or broadcast detail for admin/manager), **swipe to delete**, mark-all-read, **infinite pagination** (ordered growing-window stream via the `recipientUid+createdAt` index). Removed from the UI: search, type filters, pin, archived view, per-tile menu (archive/pin stay dormant in the data layer). Pure helpers in `notification_format.dart` (`isActionNeeded`/`groupByPriority`). **`NotificationType` trimmed (2026-06-23) to the 11 values with a live producer**. **Push is undeployed** — functions exist but inert until `firebase deploy` |
| Communications Center (Phase 1 + 2 engine + 3 UI, +**Premium Upgrade Phase 2 Commits 1–2**) | ✅ End-to-end + history + templates | `communications` slice + callable `sendBroadcast` (now via reusable `dispatchBroadcast()`). Recipient-resolution matrix (`BroadcastPermissions`); audiences allBranches/branch/**user (DM)**; `broadcasts/{id}` content writes function-owned. UI: `/communications` (admin + manager, employees blocked). **Commit 1:** broadcast `priority`/`channel`/`openedCount`/`archivedAt`/`deletedAt`; **history** feed (Active/Archived/Deleted + actions: open · repeat · duplicate · archive · delete/restore); detail **delivery diagnostics** (recipients · delivered · failed); archive/soft-delete = field-restricted client writes. **Commit 2:** **templates** — `broadcastTemplates` slice + `BroadcastTemplateCubit`, pure `TemplateRenderer` (`{{placeholders}}`), library (`/communications/templates`). **Simplification (2026-06-23):** the **analytics pipeline was removed** (Decision A — vanity: open/read rate, monthly rollups, charts) — deleted `onNotificationRead`/`onBroadcastOpened` functions, `analytics`/`broadcastOpens` collections+rules, `openedCount`, `trackOpen`, and `communications_analytics_screen`; **kept minimal delivery diagnostics** (recipients · delivered · failed). **Slice 3b (2026-06-24):** removed broadcast **soft-delete** (`deletedAt`/`isDeleted`/Deleted view/Delete·Restore·Duplicate·Schedule-again actions); a broadcast is now **active or archived** only; the home is **feed + New-Broadcast FAB** with Scheduled/Templates/Archived behind a "···" overflow. **Slice 4a–4b (2026-06-24):** categories merged **4→3** (Announcement/Reminder/Emergency); the **Priority + Delivery-channel selectors and `BroadcastPriority`/`BroadcastChannel` enums were removed** — delivery is **derived from the category** (announcement = inbox-only · reminder/emergency = push+inbox · emergency = high), the single dial across broadcasts + templates + schedules + the Cloud Function. **Communications Center simplification is complete.** Push/Function need deploy (Blaze) + iOS APNs |
| Profile          | ✅ Complete    | View/edit (Full Name · Bio · avatar+cover). **Username removed (2026-06-18)** from editing/validation — no operational value (legacy social field); dormant model field + `CheckUsername` use case remain as harmless legacy |
| Settings         | ✅ Complete    | Settings page + change password + delete account              |
| Role shells      | ✅ Live        | All three role dashboards show live operational stats (Phase 6); Admin shell hosts the full admin module (Phase 5) |
| Design system    | ✅ Complete    | **Strictly monochrome** black / white / grey dark UI (`AppColors.primary` = white, the only accent; `onPrimary`/`primarySurface`/flat `primaryGlow`), **dark-mode only**; branded **DROP** (`DropLogo` wordmark, preserved). Role chrome is a **bottom navigation bar** (`AppBottomNav` + rebuilt `RoleScaffold`: Home · Tasks · Schedule · Profile). Signature screens: splash brand lockup, breathing-clock Pending Approval. **Phase 9:** premium glass cards, reusable `UserAvatar`/`AvatarStack`, `EntranceFade` motion, `AppSearchField`. **Admin redesign (2026-06-19):** shared component library — `GlassContainer` (the one premium surface), `DashboardMetricCard`, `ActionCard`, `AdminSectionHeader`, `TimelineTile` (+`EmployeeCard`, `StatusBadge.task` as the task-status chip) |
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
  restart if rejected); manager Branch Tasks (flat list) / admin Task Management
  (now a **branch overview** with per-branch vitals + drill-down — see the
  2026-06-19 pass above) — both create, edit, assign employee from a branch
  picker, delete, review → approve/reject with notes. Added review **audit fields** (`approvedBy`/`approvedAt`/
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
- **Operations Workflow Upgrade (2026-06-18, branch `redesign`)** — enterprise task system on top of the existing architecture (no logic/routing/data/rules regressions). New entities: `RecurrenceConfig` (freezed, `nextOccurrence()`) and `ActivityEntry` (freezed). New enum `RecurrenceFrequency` (none/daily/weekly/monthly). `TaskModel` updated: `recurrence` and `activityLog` serialised to/from Firestore. `TaskCubit` extended: `createTask` seeds first `ActivityEntry`; `startTask`/`submitForReview`/`approveTask`/`rejectTask` each append an entry; `approveTask` calls `_spawnNextRecurrence` when `frequency != none`. New full-screen `TaskDetailsScreen` (all roles: status pills, assignees, checklist, notes/proof, activity timeline, role-appropriate actions). `MyTasksScreen` rebuilt (tabbed Active/Done, 5 sections, animated entrance, minimal cards → Details). `ManagerTasksView` taps open `TaskDetailsScreen` with slide transition. `_RecurrencePicker` chip row in task form (new tasks only). `flutter analyze` clean (0 errors, 0 warnings; 2 pre-existing infos in auth/profile cubits untouched).
- **Inline checklist editor + form simplification (2026-06-18, branch `redesign`)** — `_InlineChecklistEditor` + `_ChecklistItemRow` added to `task_action_sheets.dart`. Create Task form: "Add step" button builds a live list of steps with required/optional toggle (star) and × remove. Edit Task: seeds from existing `checklist`, preserves `completed`/`completedAt` on merge. Template prefill: checklist pre-populated and editable (was read-only `_ChecklistPreview` before, now removed). "Type: daily/special" dropdown removed from form (replaced by auto-inference from recurrence). `flutter analyze` clean.
- **Communications Center — Phase 1 (2026-06-21, branch `feature/tasks-improvements`)**
  — first slice of the Communications Center: a one-way **broadcast** foundation
  (backend + cubit only, no UI/routes yet). New `communications` feature (full
  vertical slice): `BroadcastEntity`/`BroadcastModel`/`BroadcastRepository(+Impl)`/
  `BroadcastRemoteDataSource`, `SendBroadcast` use case, hybrid `BroadcastCubit`
  (use case for the write, `BroadcastRepository` stream for the realtime feed),
  and the `BroadcastAudience` enum (allBranches/branch). New `broadcasts/{id}`
  collection (`AppConstants.broadcastsCollection`) + Firestore rules; all-branches
  stored with the `''` branchId sentinel so a branch member's
  `where('branchId', whereIn:[branch,''])` feed is one index-free, rules-safe
  query. Wired in `injection.dart` (`broadcastCubit`) + `main.dart` provider.
  `flutter analyze` clean (0 issues); **80 tests pass** (+6 in
  `broadcast_model_test.dart`). No regressions to existing features (additive
  slice only). **Next phase:** the Communications Center UI + role entry point.
- **Communications Center — Phase 2: notification send engine (2026-06-21,
  branch `feature/tasks-improvements`)** — the push delivery engine on the
  Phase 1 slice (architecture preserved, additive). **Recipient resolution** in
  pure `domain/broadcast_permissions.dart` (`BroadcastPermissions` — admin
  all/branch/user · manager own-branch/user-in-branch · employee none).
  **FCM tokens** moved to the `users/{uid}.fcmTokens` **array** in
  `NotificationService` (arrayUnion on register + refresh-rotation, arrayRemove
  on sign-out). **Backend** `functions/` Node.js codebase: the callable
  `sendBroadcast` (firebase-admin) validates perms → resolves recipients →
  writes `broadcasts/{id}` → pushes via `sendEachForMulticast` → prunes dead
  tokens → returns `{success, recipientCount, deliveredCount, broadcastId}`.
  `BroadcastRemoteDataSource` now invokes the callable (via `cloud_functions`);
  `broadcasts` client writes **denied** in `firestore.rules`. New
  `BroadcastAudience.user` (DM, `'__direct__'` marker + `targetUserId`).
  **Receive handling** (fg snackbar · bg OS-rendered · tap → navigate + log) in
  `NotificationService` + `main.dart`. New dep `cloud_functions`;
  `firebase.json` gains a `functions` config. `flutter analyze` clean (0 issues);
  **95 tests pass** (+15); `node --check functions/index.js` valid.
- **Communications Center — Phase 3: Center UI (2026-06-21, branch
  `feature/tasks-improvements`)** — the role-gated UI on the Phase 1 + 2 backend.
  New `/communications` area (admin + manager; `_isCommunicationsArea` blocks
  employees) entered from the `RoleScaffold` campaign icon. Screens:
  `CommunicationsScreen` (feed of `BroadcastCard`s + New Broadcast FAB),
  `ComposeBroadcastScreen` (audience chips from
  `BroadcastPermissions.allowedAudiences`, admin branch dropdown, searchable
  recipient picker, category chips, title + multiline body, sticky Send CTA →
  `BroadcastCubit.send` → "Broadcast sent to N recipients" → pop), and
  `BroadcastDetailScreen` (`/communications/:broadcastId`). New `BroadcastCategory`
  enum + `communications_format.dart`; `deliveredCount` persisted by the function
  (`broadcastRef.update`) and read on the card/detail; `BroadcastCubit` gains
  `branches()`/`branchUsers()` (repo-direct pickers, DI updated); `AppTextField`
  gains a `maxLines` option. Reuses the shared design system; strictly monochrome.
  `flutter analyze` clean (0 issues); **101 tests pass** (+6); `node --check`
  valid. **Communications Center is now end-to-end.**
- **Action needed:** deploy `firestore.rules` / `storage.rules` (now incl. the
  **`broadcasts/{id}`** rules — client writes denied) and **`functions`**
  (`firebase deploy --only functions,firestore:rules`; the Cloud Function
  requires the **Blaze** plan); enable Firebase Storage; for iOS push, add the
  APNs key + the `remote-notification` background mode (console/native, not set
  here); bootstrap the first admin (set `role/approvalStatus/isActive` in the
  console) before production.

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
| adminTasks          | `/admin/tasks`               | `TaskManagementScreen` (branch overview → drills into `BranchOperationsScreen`) | **admin**     |
| managerTasks        | `/manager/tasks`             | `ManagerOperationsScreen` → `BranchOperationsScreen` (own branch) | **manager** (+admin) |
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
| communications      | `/communications`            | `CommunicationsScreen`  | **admin + manager** |
| communicationsCompose | `/communications/compose`  | `ComposeBroadcastScreen`| **admin + manager** |
| communicationsDetail | `/communications/:broadcastId` | `BroadcastDetailScreen` | **admin + manager** |
| notifications       | `/notifications`             | `NotificationsScreen`   | all roles     |
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
  templates). **`broadcasts/{id}` (Communications Center — Phase 1 + Phase 2)**:
  read = admin, OR the individual recipient of a direct message (`targetUserId`),
  OR a branch member of a branch/all-branches broadcast (`branchId == '' ||
  branchId == selfBranch()`); **all client writes are denied** (`create, update,
  delete: if false`) — the `sendBroadcast` Cloud Function (Admin SDK) is the sole
  writer and enforces the send-permission matrix server-side. Reusable `isAdmin()`
  / `isManager()` / `canReachBranch()` helpers remain for future collections.
  **`tasks/{taskId}` (Shift Assignment feature, 2026-07-01):** a new
  `isShiftTaskInMyBranch()` helper (`assignmentType == 'shift' && branchId ==
  selfBranch()`) is ORed into the read/update rules — a branch-scoped trust
  model (any employee in the task's branch, same bounded fields as the existing
  assignee self-update; not per-shift-verified — the UI is the actual gate via
  client-side `canUserAccessTask`). **`recurringTaskTemplates/{id}`** mirrors
  `task_templates/{id}` exactly (read = any admin/manager; create/update/delete
  = admin or the owning-branch manager).
  ⚠️ Still need to be **deployed**
  (`firebase deploy --only firestore:rules,firestore:indexes,storage,functions`)
  — the Shift Assignment feature additionally needs the new `tasks` composite
  index (`branchId`+`assignmentType`+`shift`) deployed before
  `watchShiftTasks` will work (fails `failed-precondition` until then).

- **Cloud Functions (Phase 2)** — ✅ **In the repo:** [`functions/`](functions/)
  (Node.js 22, `firebase-admin` + `firebase-functions` v6; the callable is
  **2nd-gen** `onCall` — the v6 default, which deploys cleanly; the Firebase CLI
  grants the public invoker for callable functions on deploy. A "Send →
  UNAUTHENTICATED" error means the function isn't deployed yet — run
  `firebase deploy --only functions`), registered in
  [`firebase.json`](firebase.json) (`functions.source = functions`). One callable:
  **`sendBroadcast`** — the Communications Center send engine (validate sender
  permissions → resolve recipients → write `broadcasts/{id}` → gather recipient
  `fcmTokens` → `messaging.sendEachForMulticast` → prune dead tokens → return
  `{ success, recipientCount, deliveredCount, broadcastId }`). Called from
  `BroadcastRemoteDataSource` via `cloud_functions` (default region
  `us-central1`, matching the client). ⚠️ **Not deployed/runnable** in this repo
  state: needs `cd functions && npm install`, the **Blaze** billing plan, and
  `firebase deploy --only functions`. Verified by `node --check` (syntax) only —
  Flutter CI can't exercise it. Also includes the scheduled **`runTaskReminders`**,
  **`runBroadcastSchedules`**/**`broadcastHousekeeping`**, **`approveSwap`**
  (callable), and — **Shift Assignment feature (2026-07-01)** —
  **`generateShiftTaskInstances`** (`onSchedule`, every 24h): scans active
  `recurringTaskTemplates`, generates today's due instances at the deterministic
  id `rt_{templateId}_{yyyy-MM-dd}` (UTC; the existence check is the whole
  duplicate-prevention guarantee), and notifies today's rostered employees by
  writing straight to `notifications` (reuses `onNotificationCreated`, no new
  push logic).

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
| `fcmTokens`                                            | string[]  | **Phase 2** — device push tokens (multi-device; self-written via `arrayUnion`/`arrayRemove`, refresh-aware). Read server-side by the `sendBroadcast` function |
| `fcmToken`, `fcmTokenUpdatedAt`                        | string? / Timestamp? | **Phase 6 (legacy single token)** — superseded by `fcmTokens`; still read by the function for back-compat; `fcmTokenUpdatedAt` still stamped on register |
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
| `recurrence`         | map?       | **Workflow Upgrade** — `{frequency, interval, weekday, hour, minute}`. `frequency` = `none`/`daily`/`weekly`/`monthly`. When a task is approved and `frequency != none`, `TaskCubit._spawnNextRecurrence` auto-creates the next instance (checklist reset, deadline advanced) |
| `activityLog`        | array<map> | **Workflow Upgrade** — embedded array of `{status, actorId, actorName, at, note}`. Every status transition appends an entry. Shown newest-first on the Task Details screen |
| `createdBy`          | string?    | uid of the manager/admin who created it               |
| `assignedShiftId`    | string?    | optional link to `shifts/{shiftId}` (legacy, unused)  |
| `shift`              | string?    | **Branch Operations (2026-06-21)** — operational shift tag `morning` / `night`, or **null = "any"** (not shift-specific). Drives the Branch Operations shift filter; supersedes the unused legacy `assignedShiftId`. Missing/unknown → null (`ScheduleShift.fromStringOrNull`). **Shift Assignment feature (2026-07-01):** when `assignmentType == 'shift'` this is also the real assignment target (`canUserAccessTask`), not just a filter tag |
| `assignmentType`     | string     | **Shift Assignment feature (2026-07-01)** — `individual` / `team` / `shift`. `individual`/`team` both read `assigneeIds` (team is a UX-level alias, same mechanism); `shift` leaves `assigneeIds` empty and targets whoever's rostered on `shift` for `instanceDate` instead. Missing → `individual` (zero-migration back-compat) |
| `instanceDate`       | Timestamp? | **Shift Assignment feature** — the calendar day a shift-assigned instance is *for* (distinct from `deadline`, which may carry a specific time). Null for individual/team tasks |
| `sourceTemplateId`   | string?    | **Shift Assignment feature** — links a generated shift-task instance back to the `recurringTaskTemplates/{id}` that created it (`generateShiftTaskInstances` Cloud Function, or `TaskCubit._materializeTodayInstance`). Null for one-off tasks |
| `deadline`           | Timestamp? | due date/time                                         |
| `notes`              | string?    | employee's free-text notes                            |
| `proofImageUrl`      | string?    | proof image download URL (uploaded on completion)     |
| `startedAt`  | Timestamp? | set atomically when `startTask` writes `status=started` |
| `submittedAt` | Timestamp? | set atomically when `submitForReview` / `completeAndSubmit` writes `status=waitingReview` |
| `approvedBy`, `approvedAt`   | string? / Timestamp? | reviewer uid + time on approve (Phase 4 audit) |
| `rejectedBy`, `rejectedAt`   | string? / Timestamp? | reviewer uid + time on reject (Phase 4 audit) |
| `reviewNotes`        | string?    | reviewer's note on approve/reject (Phase 4)           |
| `createdAt`, `updatedAt` | Timestamp | server timestamps written by the datasource       |

> Workflow: manager/admin creates (optionally with recurrence + checklist) + assigns → employee `started`→`completed`→`waitingReview` → manager/admin `approved`/`rejected` (approval auto-spawns next recurrence). Branch/role access + the limited employee self-update are enforced by `firestore.rules` (`tasks/{taskId}`). The employee cannot reassign, change branch, or set the terminal approved/rejected status.

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

### Firestore schema — `recurringTaskTemplates/{id}` (Shift Assignment feature, 2026-07-01)

A **permanent blueprint** for a shift-assigned task that repeats on its own
clock (e.g. "Open Store" every day on the Morning shift) — distinct from
`task_templates/{id}` (a one-shot checklist blueprint a manager instantiates by
hand). Read by the `generateShiftTaskInstances` Cloud Function, which creates
one real `tasks/{id}` document per due date (so per-day completion is
trackable) and links it back here via `TaskEntity.sourceTemplateId`.

| Field         | Type       | Notes                                                       |
| ------------- | ---------- | ------------------------------------------------------------ |
| `id`          | string     | mirrors the doc id (set on create)                          |
| `title`       | string     | e.g. `Open Store`                                           |
| `description` | string?    | optional details                                             |
| `priority`    | string     | `low` / `normal` / `high`                                    |
| `checklistItems` | array<map> | `{id, title, isRequired}` — instantiated into the generated task's `checklist` |
| `branchId`    | string     | owning branch — **always** branch-scoped (no global option)  |
| `shift`       | string     | `morning` / `night` — the target shift                       |
| `repeat`      | string     | `once` / `daily` / `weekly`. `once` is never persisted as a template row client-side (a single shift task is created directly instead); the Cloud Function skips it defensively |
| `weekday`     | number     | 1(Mon)–7(Sun), used when `repeat == 'weekly'` (matches `RecurrenceConfig.weekday`) |
| `active`      | boolean    | whether the generator should still produce instances; a manager pauses via this rather than deleting (history stays intact) |
| `createdBy`   | string?    | uid of the manager/admin who created it                      |
| `createdAt`, `updatedAt` | Timestamp | server timestamps                                  |

> Access enforced by `firestore.rules` (`recurringTaskTemplates/{id}`) — same
> shape as `task_templates`: read = any admin/manager; create = admin or
> own-branch manager; update/delete = admin or the owning-branch manager.
> Generated instances use a **deterministic id** `rt_{templateId}_{yyyy-MM-dd}`
> (UTC) — the existence check against that id is the entire
> duplicate-prevention guarantee, so the daily Cloud Function run and the
> client's own "materialize today's instance on save" can never double-create
> the same day.

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

### Firestore schema — `broadcasts/{broadcastId}` (Communications Center — Phase 1 + 2 + 3)

**Written exclusively by the `sendBroadcast` Cloud Function** (Admin SDK); client
writes are denied by the rules.

| Field           | Type       | Notes                                                          |
| --------------- | ---------- | ------------------------------------------------------------- |
| `id`            | string     | mirrors the doc id                                            |
| `title`         | string     | broadcast headline (push title)                              |
| `message`       | string     | broadcast body (push body)                                   |
| `category`      | string     | notification category — `announcement` / `alert` / `reminder` / `emergency` (Phase 3 `BroadcastCategory`; legacy default `general`); rides in the push `data` |
| `senderId`      | string     | uid of the sender (`request.auth.uid` in the function)       |
| `senderName`    | string     | denormalized sender name for display                         |
| `senderRole`    | string     | `admin` / `manager` (sender's role at send time)             |
| `audience`      | string     | `allBranches` / `branch` / **`user`** (the addressing intent) |
| `branchId`      | string     | `''` = all branches · a branch id = that branch · **`'__direct__'`** = a direct message (Phase 2) |
| `targetUserId`  | string     | **Phase 2** — the recipient uid for an `audience == 'user'` direct message; `''` otherwise |
| `recipientCount`| number     | **Phase 2** — how many users the engine resolved as recipients |
| `deliveredCount`| number     | **Phase 3** — how many devices the push reached (written after the FCM multicast); shown as "delivered M / N" on the feed card + detail |
| `createdAt`     | Timestamp  | server timestamp                                             |

> A one-way announcement / direct message. For the branch/all feed, targeting is
> by `branchId`: a branch id scopes it to that branch; `''` means **all branches**
> (admin-only to send). A **direct message** (`audience == 'user'`) carries
> `targetUserId` + the non-branch `'__direct__'` marker, so it never appears in a
> branch/all feed and is read only by the recipient + an admin. The admin feed
> reads `orderBy('createdAt', descending)`; a branch member reads
> `where('branchId', whereIn: [selfBranch, ''])` (index-free, rules-safe, sorted
> client-side). The **send** (validate · resolve · persist · push · summary) is
> owned by the callable `sendBroadcast` Cloud Function; the permission matrix is
> `BroadcastPermissions` (client) re-enforced server-side.

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
- ⚠️ **Shift Assignment feature (2026-07-01) needs a deploy before it works
  end-to-end** — `firestore.rules` (new `isShiftTaskInMyBranch()` OR-branch +
  `recurringTaskTemplates/{id}` block), `firestore.indexes.json` (new `tasks`
  composite index `branchId`+`assignmentType`+`shift` — `watchShiftTasks` fails
  `failed-precondition` until deployed), and `functions/generateShiftTaskInstances`
  (the daily instance generator) all need `firebase deploy --only
  firestore:rules,firestore:indexes,functions`. Until then: shift-mode task
  creation and the client-side "materialize today's instance" still work
  (they don't depend on the new index/function), but an employee's shift-task
  *stream* won't resolve and daily/weekly recurring instances won't
  auto-generate.
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
- **Employee home dashboard** (`EmployeeHomeScreen`) is a **full live
  command center (redesign v2, 2026-06-18)** — animated progress-ring hero +
  today's shift, count-up stat strip, and an **actionable** task list (start a
  task inline, continue, view feedback) computed from the live `TaskCubit`
  stream; the Tasks tab is the full list. The **Manager** home
  (`ManagerHomeScreen`) leads with a "Needs attention" hero + grouped sections;
  the **Admin** shell is the full admin module (Phase 5).
- ~~Orphaned Phase 2 shift placeholders~~ **REMOVED (Phase 10).** The entire
  `shift` feature (`features/shift/`, the 3 placeholder screens + routes,
  `RouteNames.shiftsForRole`, `AppDependencies.shiftRepository`,
  `AppConstants.shiftsCollection`, and the `shifts/{shiftId}` rules) was deleted
  as verified dead code. The shift-visibility requirement is fully met by the
  Weekly Schedule (employee My Week · manager branch schedule · admin all branches).
- **Real-time scope: tasks + approval are push; everything else is reload-after-mutation.**
  **Tasks are fully streamed** (`TaskRepository.watch*` → `TaskCubit`): an
  assigned task or any status change appears on every open client immediately
  (cross-client push), backed by the offline cache. Pending-approval is also
  stream-driven (`watchCurrentUser`). **Schedule / branch / admin / swap** lists
  still use **reload-after-mutation** (instant for the acting user) +
  pull-to-refresh; another user's open list reflects a change on next refresh.
  **(Phase 8)** approving a swap auto-refreshes the manager Schedule tab via a
  `BlocListener`.
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

- **Unit/widget tests (35 passing):** `test/task_checklist_test.dart` (checklist
  completion rule, multi-assignee (de)serialization + legacy fallback,
  template→task checklist), `test/employee_metrics_test.dart` (per-employee
  performance derivation — completed/pending/rate/late, multi-assignee, deadline
  lateness), `test/swap_eligibility_test.dart` (the future-shifts-only swap rule —
  slot-start derivation + 8 boundary cases),
  `test/pending_actions_widget_test.dart` (renders the Admin Pending Actions panel
  headlessly — rows, tap callbacks, all-clear state),
  `test/schedule_helpers_test.dart` (name resolution + orphan/broken-reference
  detection), `test/user_model_test.dart` (malformed-doc hardening),
  `test/app_search_field_test.dart` and `test/task_card_layout_test.dart`
  (layout regressions), `test/task_access_test.dart` (Shift Assignment feature
  — `canUserAccessTask`: individual/team unaffected, shift+scheduled→true,
  shift+wrong-shift/wrong-day/no-schedule→false). `test/widget_test.dart`
  remains an empty placeholder. Cubit/router tests are still a gap (see
  suggested next steps). **240 tests passing** as of 2026-07-01.
- **Manual QA:** [`QA_CHECKLIST.md`](QA_CHECKLIST.md) — an executable, on-device
  checklist covering the Employee / Manager / Admin workflows, real-time, offline,
  and UI/branding, with the deploy/Storage preconditions a tester must do first.

---

## Suggested next steps

1. **Deploy rules + enable Storage** — `firebase deploy --only firestore:rules,storage` and enable Firebase Storage in the console. Until then proof uploads return `unauthorized`.
2. **Bootstrap first admin** — in the Firebase console set `role: admin`, `approvalStatus: approved`, `isActive: true` on the founder's account; then verify register → Pending Approval → approve → role dispatch end to end.
3. **Firestore rules for `activityLog`/`recurrence`** — the new fields written by `TaskCubit` are covered by the existing employee self-update path. Confirm the limited-employee rule allows writing `activityLog` (array union) without allowing `recurrence` changes. Harden if needed.
4. **Recurring tasks: server-side spawn** — the current `_spawnNextRecurrence` runs client-side on approve. A Cloud Function on `tasks/{taskId}` write (status==approved + frequency!=none) would be more reliable for offline/concurrent approval cases.
5. **Deploy the notification engine** — the 7 Cloud Functions (`sendBroadcast`, `onNotificationCreated`, `runTaskReminders`, `runBroadcastSchedules`, `broadcastHousekeeping`, `onNotificationRead`, `onBroadcastOpened`) are written + tested but **not deployed**; `firebase deploy --only functions,firestore:rules,firestore:indexes` (Blaze plan) + native FCM setup (APNs key + Push/Background-Modes capability on iOS) are required before any push fires. Until then in-app notifications work but push is inert.
6. **Task workflow hardening** — enforce status transitions in `firestore.rules` (who can write each status value), not only client-side in `TaskCubit._canTransition`.
7. **Stats optimization** (if data grows) — move dashboard counts to Firestore `count()` aggregate queries with composite indexes.
8. Add a Cloud Function to clean up `users/{uid}` Firestore document on account deletion.
9. Add cubit/widget tests, starting with `TaskCubit` transition rules, `RecurrenceConfig.nextOccurrence`, `ActivityEntry` serialisation, and the router redirect.
