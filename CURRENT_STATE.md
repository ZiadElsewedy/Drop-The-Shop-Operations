# DROP — Current State

> Product: **DROP — Operations Management System** (Dart package id stays `fbro`).
>
> **Live status snapshot of the project.** Read this after
> [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) to know what's done, what's pending,
> and what needs configuring. This file answers "where are we right now?" —
> architecture/how-it-works lives in PROJECT_CONTEXT.md; history lives in
> [CHANGELOG.md](CHANGELOG.md).
>
> **Keep this current** — update it before finishing any task (see
> [Documentation Maintenance](PROJECT_CONTEXT.md#5-documentation-maintenance)).

**Last updated:** 2026-06-24 (Schedule grid premium redesign — faces + names per shift cell)
**Version:** 1.0.0+1 · **Branch:** `feature/cache-layer` (DROP — monochrome enterprise UX)

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
| Tasks (Phase 3–4, +Stabilization, +Phase 9, +Workflow Upgrade, +Media Upgrade) | ✅ Full operations workflow | Full vertical slice: `TaskCubit` + use cases, functional employee/manager/admin screens, client-side status-transition rules, **live Firestore streams**, admin branch dropdown, multi-assignee, checklist+completion gate. **Workflow Upgrade (2026-06-18):** recurring tasks, activity timeline (`ActivityEntry[]`), Task Details Screen, employee My Tasks redesign. **Media Upgrade (2026-06-20):** **multiple images + videos per submission**, attached to **task events** — `TaskAttachment` entity + `AttachmentType`; `ActivityEntry.attachments[]`; Storage `tasks/{id}/attachments/{id}.<ext>` (no overwrite); `AttachmentPickerField` (gallery/camera + limits), `AttachmentGallery` + fullscreen `AttachmentViewer` (zoom images, `video_player`). Legacy `proofImageUrl` kept in sync for back-compat |
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
  ⚠️ Still need to be **deployed**
  (`firebase deploy --only firestore:rules,storage,functions`).

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
  Flutter CI can't exercise it.

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
| `shift`              | string?    | **Branch Operations (2026-06-21)** — operational shift tag `morning` / `night`, or **null = "any"** (not shift-specific). Drives the Branch Operations shift filter; supersedes the unused legacy `assignedShiftId`. Missing/unknown → null (`ScheduleShift.fromStringOrNull`) |
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
  (layout regressions). `test/widget_test.dart` remains an empty placeholder.
  Cubit/router tests are still a gap (see suggested next steps).
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
