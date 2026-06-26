# Changelog

All notable changes to **DROP — Operations Management System** (Dart package id
`fbro`) are recorded here. After every completed feature, append a short summary
of what was **added / removed / fixed / refactored**. See
[PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) for architecture.

The project adheres loosely to [Keep a Changelog](https://keepachangelog.com)
and [Semantic Versioning](https://semver.org).

---

## [Unreleased]

### Fixed + Changed (2026-06-26 — Token-leak audit · realtime swaps · activity timeline V2)

A deeper notification-security audit + the realtime/UX follow-ups. `node --check`
valid; all changed Dart parse-checked. ⚠️ Run `flutter analyze`/`test` on a current
SDK. No deploy needed (the server `claimFcmToken`/`approveSwap` are already in the
deploy set — ensure they're deployed).

- **FCM cross-account leak — root cause found + fixed.** Multi-account device audit
  (A logs in → logout → B logs in): `forgetUser()` ran from the **post**-sign-out
  `unauthenticated` listener, so its `users/{uid}.fcmTokens arrayRemove` executed
  **after** Firebase Auth was cleared → **permission-denied** (rules require
  `isOwner`) and silently swallowed. So the client **never** removed the token on
  logout; the token lingered on account A and the system relied entirely on the
  server `claimFcmToken`. Fix: `AuthCubit.signOut()` now runs a **pre-sign-out
  hook** (`onPreSignOut`, wired in DI to `NotificationService.forgetUser`) that
  drops the token **while still authenticated**, so the write succeeds. Layered
  guarantee: (1) normal logout removes the token client-side; (2) force-kill /
  offline logout is reconciled by **`claimFcmToken`** (re-audited — correct +
  loop-safe) when the next user registers the same token. Token ownership can no
  longer drift across accounts.
- **`ShiftSwapCubit` is now stream-based (realtime).** New Firestore snapshot
  streams `watchEmployeeSwaps` (merges the requester + target queries),
  `watchBranchSwaps`, `watchAllSwaps` (datasource + repo). The cubit **subscribes**
  per scope (mine / branch / all) — idempotent guard, cancel on close — instead of
  fetch + manual refetch; mutations no longer refetch (the stream reflects them).
  So a coworker's **incoming swap appears on their Home instantly**, accept/reject/
  approve propagate in realtime to every open surface, and the **admin Home swap
  count is live** (`_PendingSection` selects the unresolved count from the stream;
  the one-shot `pendingSwaps()` is retired from Home). Better matches DROP as a
  realtime ops platform.
- **Task activity timeline V2.** Redesigned `_EventCard` (Task Details): the **most
  recent event is the CURRENT step** — a larger accent node with a glow ring + a
  "CURRENT" pill + an accent-tinted, shadowed card; older steps recede onto the
  flat surface. The connecting spine is **accent-tinted at the head, fading to the
  neutral border** (clear progression), and notes render in a callout surface.
  Stronger hierarchy + richer depth, still strictly monochrome + status accents.

### Fixed (2026-06-26 — Audit pass: swap surfacing · admin review reactivity · broadcast resilience · UI polish)

Four surgical fixes from a focused audit. `node --check functions/index.js` valid;
changed Dart parse-checked (`dart format`). ⚠️ Run `flutter analyze`/`flutter test`
on a current SDK; the broadcast fix needs `firebase deploy --only functions`.

- **Issue 1 — Swaps surfaced on Home (coworker accept/reject).** Root cause:
  swap requests only existed inside **Schedule → Swaps**, so a coworker never saw
  the request on their home page (the actions worked, but were unreachable). The
  **employee home** ([employee_home_screen.dart](lib/features/employee/presentation/pages/employee_home_screen.dart))
  now loads `ShiftSwapCubit.loadMine` and shows a prominent **Shift swaps** section:
  **incoming** requests get **Accept / Decline** (with a clear "you give ⇄ you get"
  strip), **outgoing** requests show their stage (waiting on coworker → awaiting
  manager) + **Cancel**. Accept → `coworkerApprove` (→ manager queue); the live
  cubit refetch makes the card reflect each transition immediately. A
  `ShiftSwapCubit` error listener surfaces failures. (Admin home already surfaces
  swaps via Pending Actions.)
- **Issue 2 — Admin review queue didn't refresh after a review.** Root cause: the
  Pending Actions / hero **review count came from `StatisticsCubit`**
  (`s.waitingReviews`), which is **TTL-cached (90s) and not invalidated on a
  mutation** — and the `_DynamicSection` `BlocSelector` was keyed only on the
  **overdue** count, so a review (which doesn't change overdue) didn't even
  rebuild. Fix: the selector now derives **both** `overdue` **and** `reviews` from
  the **live task stream** (`_reviewCount`), so finishing a review drops the queue
  + hero instantly. ([admin_dashboard_screen.dart](lib/features/admin/presentation/pages/admin_dashboard_screen.dart))
- **Issue 3 — Broadcast sends could fail after partial success.** Root cause: in
  `dispatchBroadcast` the **FCM push loop was not error-isolated** — a transient
  messaging/API error threw out of the function **after** the broadcast doc + every
  recipient's inbox notification had been written, so the callable returned an
  error and the sender saw "failed" even though delivery to the inbox succeeded.
  Fix: the push is wrapped in try/catch (best-effort, like the inbox writes) and
  keeps the partial `deliveredCount`; added diagnostic logging — a
  **"recipients have no registered device tokens"** info log and a structured
  **push-failed** error log — so a "didn't reach all" report is diagnosable from
  Firebase logs (token persistence vs. send). Audited the rest end-to-end:
  targeting filters (allBranches/branch/user/custom + role + sender self-exclude),
  token persistence (`_rotateToken`), dead-token cleanup, and the `notifications`
  read rule are all correct. ([functions/index.js](functions/index.js))
- **Issue 4 — Premium UI polish.** Shared `TimelineTile` (task activity timeline +
  admin activity feed) gains a **haloed status dot** + a **callout surface** for
  notes (review reasons). The new Home swap cards use `AppGlassCard` + status glow,
  the ⇄ exchange strip, and `PremiumButton` actions — consistent with the swap
  system's premium language.

### Added + Changed (2026-06-26 — Shift Swap hardening: server-authoritative atomic exchange + premium UX)

Hardened the (already employee-to-employee exchange) shift-swap system and gave it
a premium swap experience. The core exchange/coworker→manager flow already existed
(2026-06-25); this pass makes the exchange **atomic + server-validated**, adds
**role-compatibility + rest-hour** policy, and redesigns the swap UI. ⚠️ **Run on a
current SDK** (this session's Flutter is 3.10.4 < `^3.12.1`): `dart run build_runner
build --delete-conflicting-outputs` (the two freezed files were hand-edited),
`flutter analyze`, `flutter test`. ⚠️ **Deploy required:** `firebase deploy --only
functions,firestore:rules` — until then manager-approve fails (callable missing).
`node --check functions/index.js` valid; all changed Dart parse-checked (`dart
format`).

- **Server-authoritative atomic exchange (`approveSwap` Cloud Function).** Manager
  approval no longer runs four sequential, non-atomic client writes (a partial
  failure could corrupt the roster). A new callable
  [`approveSwap`](functions/index.js) re-validates against the **freshest** schedule
  (TOCTOU backstop), then applies the requester ⇄ target trade in a **single
  Firestore transaction** (both move or nothing changes). It enforces: status =
  `employeeApproved`, slot integrity, future shift, double-booking, role
  compatibility, and rest hours. `ScheduleRepositoryImpl.managerApproveSwap` now
  calls it (via `ScheduleRemoteDataSource.approveSwap` → `cloud_functions`, already a
  dep); the client passes the **locally-computed** `scheduleId` (the UTC function
  can't reproduce the local-week-start doc id) which the function re-checks against
  the swap's branch.
- **Branch swap policy + employee position (validation rules).** New plain value
  object **`SwapPolicy`** ([swap_policy.dart](lib/features/schedule/domain/swap_policy.dart))
  on `branches/{id}.swapPolicy` (`restrictToSamePosition` + `minRestHours`; null =
  permissive) and a new **`UserEntity.position`** (`String?`, e.g. "Cashier"). New
  pure **`SwapValidation`** ([swap_validation.dart](lib/features/schedule/domain/swap_validation.dart))
  is the single canonical rule definition (slot integrity · role compatibility ·
  double-booking · rest hours), used client-side at request time and **mirrored in
  the Cloud Function**. A per-week shift **cap was intentionally omitted** — an
  exchange is headcount-neutral per employee, so a weekly cap is invariant under a
  swap (dead validation). Default eligibility stays "same branch, any role"; role
  compatibility is opt-in per branch.
- **Firestore hardening.** `shift_swaps` update now **denies any client write that
  sets `status == 'managerApproved'`** — the validated exchange is owned solely by
  the Admin-SDK function. The `users` self-update rule now also **freezes
  `position`** (admin-only, like role/branch).
- **Premium swap UI.** `swap_view.dart` rebuilt on `AppGlassCard` with a real **⇄
  exchange visual** (both parties + their shifts), a compact **status timeline**
  (Requested → Accepted → Approved; terminal rejected/cancelled), branded
  `DropEmptyState`, and a redesigned **request sheet** (exchange preview · avatar
  coworker picker with role-incompatible coworkers shown disabled · full
  request-time `SwapValidation`). The my-week **Swap** affordance is now a premium
  pill.
- **Admin config UI.** Branch form sheet gains a "Shift-swap rules" section
  (same-role toggle + min-rest stepper, edit-only). Employee management gains a
  **Position** action (`AdminUsersCubit.changePosition` →
  `UserAdminRepository.changeUserPosition`) + a position line in details.
- **DI:** `ScheduleRemoteDataSourceImpl` now takes `FirebaseFunctions.instance`.
- **Docs fixed:** the stale one-way-handover comments on `ShiftSwapEntity` and
  `ScheduleRepository.managerApproveSwap` now describe the exchange model.
- **Tests:** new `swap_policy_test` + `swap_validation_test` (role compat · slot
  integrity · rest hours); `user_model_test` covers `position` round-trip.

### Added (2026-06-25 — Realtime polish: animated counters + smooth Pending Review list)

Acted on a "realtime admin home" request after reconciling it against the code:
**realtime streams, newest-first, rebuild-scoping, and pull-to-refresh already
exist** (`TaskCubit` streams `watchAllTasks` ordered `createdAt desc`; the admin
dashboard rebuilds only scoped sections via `BlocSelector`). The admin home is a
**counters dashboard**, not a live task list — so per the owner's clarified, lean
scope, this adds counter animation + smooths the one real live list
(`pending_review_screen`), and **deliberately omits** the buffer / "X new tasks"
banner / 2–5s batching (unnecessary complexity: the stream is sufficient and
review is a separate route, so there's no list "jumping under" an open review).
Presentation-only; no schema/logic/stream/dependency change. ⚠️ Run `flutter
analyze` / `flutter test` on a current SDK (this session is 3.10.4); parse-checked
with `dart format`.

- **`AnimatedCount`** ([core/widgets/animated_count.dart](lib/core/widgets/animated_count.dart))
  — the single reusable animated counter (count-up on appear, tween on change).
  Replaces the bespoke `TweenAnimationBuilder` in the review summary header and is
  reused by the dashboard metrics, the hero, and the drill counts (one source, no
  per-surface re-rolls).
- **`LiveListItem`** ([core/widgets/live_list_item.dart](lib/core/widgets/live_list_item.dart))
  — a realtime-list item that **enters once** (fade + rise) and never replays on a
  stream emit (caller supplies a stable `ValueKey`, so Flutter reuses the element
  and preserves scroll — no `AnimatedList`/diff bookkeeping); `isNew` adds a brief
  fading accent-border highlight. Intentionally minimal.
- **Admin counters animate** — `DashboardMetricCard` counts up numeric values via
  `AnimatedCount` (backward-compatible: the "—" placeholder stays plain text; this
  also smooths the manager/employee metric grids consistently — one shared widget,
  no fragmentation), and the admin `_Hero` value animates.
- **`pending_review_screen` smoothed** — every level's rows are now keyed
  `LiveListItem`s (`b:`/`e:`/`t:` keys), so a stream emit no longer re-animates the
  list; a genuinely-new submission (an unseen id after the first load, tracked in
  `_knownTaskIds`) **slides in with a brief highlight**; scroll position is held
  (keyed items + `PageStorageKey` per level); counts use `AnimatedCount`. No
  buffer/banner/batch — the existing live stream drives it directly.

### Changed (2026-06-25 — De-flash: premium ≠ flashy on task surfaces)

Owner ruling: premium **but not flashy** (Linear / Notion / Stripe), and **do not
touch the shared `GlassContainer`/`AppGlassCard` yet** (large blast radius). So
this refines the card redesign from the entry below, **scoped to task surfaces
only**, keeping *subtle* depth (border + whisper shadow) — not full-flat. Visual
direction approved via mockup first. Presentation-only; no schema/logic/dependency
change. ⚠️ Run `flutter analyze` / `flutter test` on a current SDK (this session's
is 3.10.4); parse-checked here with `dart format`.

- **`TaskCard` renders its own flat surface** instead of `AppGlassCard`: solid
  `darkSurface` + hairline `darkBorder` + a *whisper* shadow (`black @45%`, blur 3,
  offset 0,1), radius 14. **Removed:** the gradient, the **status glow halo**, and
  the **4-segment animated lifecycle track**. The shared `GlassContainer`/
  `AppGlassCard` are **untouched** (other surfaces unchanged) — global de-flash is
  deferred until this language is validated in use.
- **Priority is High-only** (`_HighPriorityFlag`) — Medium/Low show nothing
  (removed the per-card priority chip noise; dropped the unused `_priorityLabel`).
- **Progress simplified** — a single thin `_ChecklistBar` shown **only when the
  task has a checklist** (the status pill carries state otherwise), replacing the
  always-present segmented track. Most cards now show no progress widget at all.
- **Minimal one-line footer** (`_AssigneeFooter`) — avatar · name · "· by Creator"
  inline (was two lines), smaller avatars; keeps the card compact (no height
  increase, per the owner constraint).
- **`TaskDetailsScreen._StatusHeader` de-flashed** — converted from a stateful,
  **breathing-pulse + glow + gradient** header to a flat stateless surface (solid
  fill + hairline border + whisper shadow). The status pill's one-shot cross-fade
  on a status change is kept (a transition, not a pulse).
- **Meta contrast** lifted off the dim tertiary grey onto the readable secondary.
- **Maintainability (no duplication / fragmentation):** the de-flashed surface is
  defined **once** in a new reusable **`TaskSurface`**
  ([task_surface.dart](lib/features/task/presentation/widgets/task_surface.dart)) —
  the single source of the flat fill + hairline border + whisper shadow, consumed
  by both `TaskCard` and `TaskDetailsScreen._StatusHeader` (no inline decoration
  copies). It is intentionally feature-local and distinct from
  `GlassContainer`/`AppGlassCard` (the calmer language is scoped to tasks until
  validated; `TaskSurface` is the one place to promote if globalised). The card's
  status pill now sources its colour from the canonical `taskStatusColor` (no
  third status→colour map; only its label + icon are card-local).
- `task_card_layout_test` continues to cover the new card (no API change from the
  redesign entry below).

### Added + Changed (2026-06-25 — Premium task UX slice: reference images + card redesign)

Acted on the task-management UX audit (slices #1 + #2). **#1 — Admin/Manager
reference images:** managers/admins can now attach reference photos ("what good
looks like") when creating/editing a task; the employee sees them on the task
details screen **before** starting. **#2 — Premium task card redesign:** the
shared `TaskCard` (manager/admin surfaces) was rebuilt from a label→value spec
sheet into a scannable, signal-driven premium card. Strictly monochrome with the
existing semantic accents; no new dependencies. ⚠️ **Run on a current SDK** (this
session's Flutter is 3.10.4 < `^3.12.1`): `dart run build_runner build
--delete-conflicting-outputs` (the `task_entity.freezed.dart` was hand-edited to
match), `flutter analyze`, `flutter test`. **No deploy needed** — Storage rules
already cover `tasks/{id}/**`; the `tasks` create/update rules already permit the
manager/admin write (no new field whitelist).

- **Schema — `TaskEntity.referenceAttachments`** (`List<TaskAttachment>`, default
  empty; freezed hand-regenerated) + `hasReferences` getter. `TaskModel`
  (de)serializes it via the existing attachment (de)serializers (back-compat:
  absent → empty). Stored in Storage at `tasks/{id}/attachments/{attId}.<ext>`
  (the existing task-media path) — distinct from employee *proof*, which still
  lives on the submission `ActivityEntry` / legacy `proofImageUrl`.
- **Upload flow (`TaskCubit`)** — `createTask` gains `referenceAttachments:
  List<PickedAttachment>` (uploads **after** create, when the task id exists, then
  patches the doc); `editTask` gains `newReferenceAttachments` (uploads + appends
  to the kept refs). New private `_uploadReferences` (parallel upload, reuses
  `UploadTaskAttachment`); a failure rolls back via `_mutate` so the manager can
  retry.
- **Picker (`AttachmentPickerField`)** — reused for both roles instead of forking:
  new `allowVideo` (images-only for references — hides the video menu rows +
  counter), `title`/`hint` overrides, and `existing` + `onRemoveExisting` so
  already-uploaded refs render as removable network thumbnails (`_ExistingTile`)
  beside the newly-picked ones; the count cap now spans both groups.
- **Form (`task_action_sheets`)** — a "Reference images" section after the
  description; edit mode seeds the kept refs and threads new picks to the cubit.
- **Details (`task_details_screen`)** — a new "Reference" section (2-col
  `AttachmentGallery`, tap → fullscreen/zoom) shown before the checklist on any
  task with references.
- **Card redesign (`TaskCard`)** — replaced the `_MetaRow` label→value table with:
  a tinted **status pill** + **priority** signal (only High carries red), a
  **signal-chip strip** (branch · due/overdue · `N refs`), a **universal 4-segment
  lifecycle track** (Assigned → Started → Review → Done — answers "where is this?"
  even with no checklist; checklist % layered in when present), and an **assignee
  footer** ("by Creator"). Inline proof image / notes / review notes were
  **removed** from the card (they live on the details screen) — decluttered. The
  `premium` flag is gone — every `TaskCard` is now the `AppGlassCard` premium
  surface with the status glow; `ManagerTaskCard` passes the resolved `branchName`.
  `onChecklistToggle` (only ever used by a test) removed. Employee `_MinimalCard`
  / `_HomeTaskCard` are separate surfaces, left for a follow-up.
- **Tests** — new `task_model_reference_test` (serialization + entity round-trip +
  `hasReferences`); `task_card_layout_test` updated to the new API.
- **Deferred (called out in the audit, not in this slice):** drag-and-drop upload
  (new dep), on-image annotation, a `Blocked` status, double-tap zoom,
  `cached_network_image`, swipe/haptics, and aligning the employee minimal card.

### Fixed (2026-06-25 — FCM routing audit: exclusive token ownership)

**Critical (privacy):** a device's FCM token could be attached to **multiple**
`users/*.fcmTokens` arrays at once, so a send to the old user reached a device now
used by someone else — **cross-user notification leakage** (incl. direct messages).
`node --check` valid; no client/schema/rules/index change. ⚠️ **Deploy required**
(`firebase deploy --only functions`) to activate.

- **Root cause.** Token ownership was not exclusive. Registration
  (`NotificationService._rotateToken`) only **adds** the token to the signed-in
  user; the **only** cross-user release is the client's best-effort,
  error-swallowed `forgetUser` on logout. If that fails (offline / force-kill /
  the register-then-logout timing window) the token lingers on the old user. The
  client **can't self-heal** — `firestore.rules` let a user write only their own
  doc — so exclusivity can only be enforced server-side. (The legacy single
  `fcmToken` field, still read by the senders, was never cleaned either.)
- **Not the bug:** audience resolution (a direct send uses **only** the target's
  tokens — no branch leakage) and the within-send token dedup are correct. The
  fault is the upstream token→user mapping in Firestore.
- **Fix — `claimFcmToken`** (new `onDocumentUpdated('users/{uid}')` Cloud
  Function): whenever a token is **added** to a user, it's claimed **exclusively**
  — removed from every other user's `fcmTokens` and any matching legacy
  `fcmToken` (admin privileges; loop-safe, since a removal adds no token). A token
  then belongs to **at most one user** — the most recent to register it —
  regardless of whether the client logout cleanup ran. Smallest safe fix: no
  client change, no schema rewrite, no rules/index change.
- **Scenario validation:** ① account-switch on a shared device → now guaranteed
  (B's registration reclaims the token from A); ② multiple devices per user →
  already correct (unchanged); ③ direct send → reaches only the target's
  *currently-owned* devices once exclusivity holds.

### Added + Changed (2026-06-25 — Shift Swap System: exchange model + swap notifications)

Evolved the existing shift-swap workflow into a true **employee-to-employee
exchange** with a full **notification** pipeline — built on the existing
`shift_swaps` slice + `ShiftSwapCubit` (no marketplace / matching / new schedule
architecture). `flutter analyze` clean (0 issues); **192 tests pass** (+9). **No
deploy needed** — reuses the already-live `notifications` create rule + the
`onNotificationCreated` push function; no rules/functions/schema change.

- **Exchange (was a handover).** Approval now **swaps both employees** across the
  two shifts on that day (Ziad Night ⇄ Ahmed Morning), not a one-way handover.
  With only two shifts the target's slot is deterministically the **opposite** of
  the requester's, so no entity field was added — `ScheduleShift.opposite` + a
  4-op `managerApproveSwap` (reusing the existing assign/remove) do it.
- **Opposite-shift coworker picker.** `my_schedule_screen._requestSwap` now offers
  only coworkers working the **opposite shift that same day** (the exchange
  counterpart), which also enforces *requester ≠ target* and *target slot exists*.
- **`cancelled` status** added to `SwapStatus` (the requester's "Cancel" is now a
  distinct `cancelSwap`, not a reject); badge/label/colour + the exhaustive
  switches updated. (The other four statuses keep their existing names —
  semantically the spec's `pendingCoworker/pendingManager/approved/rejected` — to
  avoid a churny enum/rules/doc rename for zero functional gain.)
- **Swap notifications (new producer).** `NotifySwapEvent` (mirrors
  `NotifyTaskEvent`, reuses `NotificationRepository.createMany`) fires on: **request
  → the coworker**, **coworker-accept → the branch manager(s)** (resolved via
  `GetUsersByBranch`), **approve/reject → both employees**. New `NotificationType`s
  `swapRequested/swapAccepted/swapApproved/swapRejected`; these light up the §5
  inbox's **Schedule** category (now a real pill, no longer empty) and a swap
  awaiting approval is **critical** priority (the spec's "pending swap approval"
  example). Deep-link → the role's schedule. `ShiftSwapCubit` gains `NotifySwapEvent`
  + `GetUsersByBranch` (DI updated).
- **Guards** (all enforced): requester ≠ target · same branch · future shift
  (`SwapEligibility`) · target slot must exist (opposite-shift picker) · **no
  simultaneous pending request** (new cubit guard) · approved/resolved swaps are
  terminal.
- **UI** reuses the premium system (`AppGlassCard`/`StatusBadge`/`PremiumButton`),
  strictly monochrome with subtle status glows (pending=amber · approved=emerald ·
  rejected=red · cancelled=grey).

### Deployed + Audited (2026-06-25 — Release Stabilization Slice)

Production-readiness pass after the Premium UX/Logic Refactor (§1–§11). **No new
features.** Deploy executed; automated gate + static audits run; manual QA matrix
prepared. See [RELEASE_QA.md](RELEASE_QA.md) for the full record.

- **Phase 1 — Deploy ✅ (executed to production `bazic-d9ad7`).** The long-standing
  deploy debt is **cleared**: `firestore:rules` + `storage` (both compiled +
  released) and `functions` (all 5 updated). **Cleanup:** deleted two orphaned
  prod functions (`onBroadcastOpened`, `onNotificationRead`) left over from the
  2026-06-23 analytics rollback — the live function set now exactly matches the
  code (no client/server drift). **Critical checks live:** approved-task lock
  (rules, re-audited — no legitimate flow blocked), broadcast sender self-exclusion
  (`sendBroadcast`), branch-media uploads (storage `branches/{id}`).
- **Phase 2 — Regression QA.** Automated gate green (`flutter analyze` clean ·
  **183 tests** · `node --check` valid); a code-level review of the changed paths
  found no regressions. A full **manual QA matrix** (auth / tasks / notifications /
  branch media × admin / manager / employee) is documented in `RELEASE_QA.md` for
  on-device execution (Flutter UI isn't CI-renderable here).
- **Phase 3 — Performance audit (static).** Image caching clean (all refactor
  `Image.network` use `cacheWidth`; the one exception is the intentional full-res
  zoom viewer). Two **pre-existing** minor hot paths noted (not introduced here):
  `notifications_screen` non-builder `ListView` (bounded by pagination) and
  `employee_management_screen` `context.watch<TaskCubit>` — both candidates for a
  later pass.
- **Phase 4 — UX sweep (static).** Dynamic text on new surfaces is protected
  (`Expanded` + `maxLines`/ellipsis). On-device checks still owed: cover-hero
  layout, notification swipe/haptics, small-screen rendering.
- **Non-blocking maintenance note:** the deploy warned `firebase-functions` is an
  older major version — a future `@latest` bump (with breaking-change vetting), not
  required for this release.

### Changed (2026-06-25 — Premium UX/Logic Refactor · §5: notification UX — operational inbox)

Rebuilt the Notification Center from a lean feed into an **operations workflow
inbox** (information architecture → interaction → motion). This **intentionally
reverses** the 2026-06-23 lean simplification (owner-directed), while keeping the
monochrome / subtle / no-loud-badges constraints. Reuses `NotificationTile` +
`AppGlassCard`. `flutter analyze` clean (0 issues); **183 tests pass** (notification
grouping test rewritten for the new model). ⚠️ Swipe/haptic interactions want an
on-device check (not CI-renderable).

- **§5a — Information architecture** (`notification_format.dart`, all pure +
  unit-tested):
  - **Priority model** — `NotificationPriority` (critical / high / normal / low) +
    `notificationPriority(type)`: **critical** = overdue task · emergency
    broadcast; **high** = assigned / rejected / rework / submitted-for-review;
    **normal** = approvals / reminders / routine broadcasts.
  - **Category model** — `NotificationCategory` (All / Tasks / Reviews / Broadcast)
    + `categoryOf(type)`, driving the top **filter pills** (subtle premium chips,
    horizontal).
  - **Time grouping** — `groupByTime` buckets into **Today / Yesterday / Earlier**,
    and **within each section sorts higher-priority first** then newest-first, so
    critical items pin to the top of their day (replaces the flat
    Needs-action/Earlier grouping).
  - **Critical emphasis** — `NotificationTile`'s unread dot takes the type's
    semantic accent + grows slightly for a critical notification (subtle, still
    monochrome elsewhere).
- **§5b — Interaction:**
  - **Swipe** — right → **Mark read** (no dismiss); left → **Archive** (inbox) or
    **Delete** (Archived view). Both keep the tile in the tree (the live stream
    removes it), so the swipe springs back cleanly.
  - **Archived view** — an app-bar toggle (re-added; the data layer always
    supported it) with its own empty state.
  - **Bulk** — **Mark all read** (inbox) + new **Clear archived**
    (`NotificationCubit.clearArchived`, confirm-gated).
  - **Deep-links verified** — every type routes: task / review → the exact task
    (`/task/:taskId`, whose details screen carries the review surface); broadcast →
    its detail (admin/manager). No dead notifications.
- **§5c — Motion** (subtle only): unread-dot **fade** on read (`AnimatedOpacity`),
  swipe **spring** (Dismissible snap-back), filter-pill **transition**
  (`AnimatedContainer`), and **light haptics** (`selectionClick` on filter /
  mark-read, `mediumImpact` on archive / delete).
- **Data model — kept single `readAt` (= isRead); `isSeen` NOT added (documented
  decision).** `readAt` already matches the spec's **isRead** ("destination
  opened/interacted" — it's set on tap, which deep-links). Adding **isSeen**
  ("inbox opened") would mean a notifications-schema field + a mark-all-seen write
  on every inbox open + reworking the unread count around two states — disproportionate
  for a small internal ops inbox (the lean philosophy). Per the spec's escape
  hatch, kept the single-state model.
- **Scope gap (documented):** the spec's **Schedule** + **System** category pills
  and the "pending swap approval" critical example have **no notification
  producer** — those `NotificationType`s were trimmed (2026-06-23) because nothing
  wrote them. Adding permanently-empty pills would be dead UI, so they're omitted;
  re-add a category **with** its producer (a swap/schedule trigger) as a separate
  slice.

### Added (2026-06-25 — Premium UX/Logic Refactor · §8c: branch hero completion)

Closed the parked §8b/§9 dependency chain — the Branch Operations dashboard now
leads with a premium **branch hero**, the schedule header carries the **employee
count**, and the §9b branch-hero **watermark is unblocked**. `flutter analyze`
clean (0 issues); **180 tests pass**. No schema / rules / DI change (reuses the §8
`coverUrl`/`logoUrl` + the §8b `BranchCubit` directory). Strictly monochrome.
⚠️ Hero rendering (cover image / nested 16:9 Stack) wants an on-device check —
Flutter UI isn't renderable in CI here.

- **Branch hero** (`branch_operations_screen._BranchHero`) — a **16:9** premium
  surface at the top of the cockpit: the branch **cover** photo behind a ~70%
  dark gradient scrim (legibility), with `BranchAvatar` + branch name + **employee
  count** + **active-shift summary** (driven by the cockpit's `ShiftFilter`).
  **Fallback:** no `coverUrl` → a premium **monochrome** gradient hero
  (`_MonoHeroBg`). Cover/logo resolve from the app-wide `BranchCubit` directory;
  `Image.network` falls back to the mono surface on error.
- **`BrandWatermark` on the hero** (§9b Wave 3, now unblocked) — a ≤**0.03**-opacity
  `DropWordmark`, the branch-dashboard watermark that previously had no card
  surface.
- **Schedule header employee count** (`manager_schedule_view._branchHeader`) — the
  secondary label is now **"Weekly Schedule · N employees"** (threaded the branch
  `members.length` through `_body → _controls → _branchHeader`); the admin
  all-branches view (no branch picked) keeps the plain "Weekly schedule".
- **§8 + §9 are now complete.** Remaining noted gap: the **Communications Center
  header** watermark — still a bare `AppBar` with no hero card, so it stays
  deferred (adding one would be a header redesign, out of scope for a watermark).

### Added (2026-06-25 — Premium UX/Logic Refactor · §9b: brand rollout)

Wired the §9a brand primitives into the product — **restrained**: heavy brand only
on auth/empty/full-loading, a single subtle hero watermark, and **zero** brand in
cards/tiles/rows (per the design ruling). No new assets (reuses `DropLogo`/
`DropWordmark`); no raw `Image.asset` logo calls. `flutter analyze` clean (0
issues); **180 tests pass** (+3). Strictly monochrome, no indigo.

- **Wave 1 — auth:** new shared **`DropAuthMark`** (`core/widgets` — `DropLogo` +
  the "DROP OPERATIONS SYSTEM" tagline, one lockup so login/register/OTP don't each
  re-declare the logo) now leads **login** + **register** (replaced their bare
  `DropLogo`). The **splash** already embodied the spec (DropLogo + fade + glow +
  "DROP THE SHOP" lockup) so it was left intact; fixed only its stale "indigo glow"
  comment (the bloom is white). OTP left for a later light touch (the subtitle is
  optional and its layout is a focused code-entry screen).
- **Wave 2 — system states:**
  - **Empty states → `DropEmptyState`:** `TaskEmptyState` now delegates to it
    (all 5 task-list empties — its vestigial `icon` param removed + call sites
    updated); the **notifications** inbox empties; and the **branches** empty
    (both "no branches" and "no search results").
  - **Full-page loaders → `DropLoadingState`:** the manager/admin **schedule** view
    and the employee **my-week** view swapped their bare centred
    `CircularProgressIndicator` for the pulsing-logo loader. List skeletons,
    button spinners and small async loaders were **left alone** (per the rule —
    cold-start/auth-restore is the splash; this is for full-page fetches).
- **Wave 3 — selective header branding:** new reusable **`BrandWatermark`**
  (`core/widgets` — a clipped, non-interactive, ≤0.05-opacity `DropWordmark` in the
  card corner; asserts the opacity cap) applied to the **Admin Home hero**. The
  **Communications Center header** (a bare `AppBar`, no hero card) and the **Branch
  dashboard hero** (the card surface is the parked §8b cover-hero) have **no clean
  surface to watermark yet**, so they're deferred rather than force-fit.

### Added (2026-06-25 — Premium UX/Logic Refactor · §9a: brand primitives)

First step of §9 (DROP branding) — the **brand primitives only**, ahead of the
broad rollout. Built on the existing `DropLogo` PNG (no asset duplication).
`flutter analyze` clean (0 issues); **177 tests pass** (+3 `brand_primitives_test`).
Strictly monochrome.

- **`DropWordmark`** ([core/widgets/drop_wordmark.dart](lib/core/widgets/drop_wordmark.dart))
  — the DROP logotype rendered **typographically** (w800, tight tracking), the
  vector-crisp complement to the PNG `DropLogo` for inline/small contexts (headers,
  empty/loading, auth) — no asset load, tints to any colour.
- **`DropEmptyState`** ([core/widgets/drop_empty_state.dart](lib/core/widgets/drop_empty_state.dart))
  — the **brand-led** empty state: a faded `DropLogo` mark instead of a generic
  grey glyph, then title + message + optional action. Same centered, always-
  scrollable layout as `AppEmptyState` (works as a `RefreshIndicator` child);
  `AppEmptyState` stays the routine placeholder, this is for brand-touchpoint
  empties.
- **`DropLoadingState`** ([core/widgets/drop_loading_state.dart](lib/core/widgets/drop_loading_state.dart))
  — a branded full-area loader: the `DropLogo` with a slow opacity-pulse ("brand
  breathing") + optional message, for whole-screen/section waits (list skeletons
  stay for content placeholders).
- **Not rolled out yet** (deliberate, per the plan): these primitives aren't wired
  into screens — that broad branding pass (splash/auth/empties/loading/headers) is
  the next slice, now landing on a stable component + branch foundation.

### Added (2026-06-25 — Premium UX/Logic Refactor · §8b: branch identity rollout)

Surfaced `BranchAvatar` everywhere branch identity materially matters, finishing
§8. `flutter analyze` clean (0 issues); **174 tests pass**. Mechanism: the
**app-wide `BranchCubit` as a branch directory** — new `branchById(id)` +
`loadIfNeeded()`; warm-preloaded in `main.dart` for **every** role (small + cached)
so any surface resolves a `branchId` → its logo with no per-screen fetch.

- **Schedule header** (`manager_schedule_view`) — a new branch-identity header
  (`BranchAvatar` + name + "Weekly schedule") at the top of the controls, for both
  the manager (their fixed branch) and admin (the selected branch, above the
  existing selector).
- **Branch dashboard / operations header** (`branch_operations_screen`) — the
  AppBar title is now `BranchAvatar` + branch name (reactive `BlocBuilder` so the
  logo fills in when the directory loads).
- **Employee profile** (`profile_page`) — a new **Assigned branch** section
  (`AppGlassCard` + `BranchAvatar` + name + location), sourced from the auth
  session's `branchId`; renders nothing for a user with no branch (e.g. a global
  admin).
- **Swap request cards** (`swap_view._BranchLine`) — the branch line's static
  store glyph → a small inline `BranchAvatar`.
- Each surface calls `BranchCubit.loadIfNeeded()` on entry as a belt-and-braces
  fallback to the warm preload. No schema / rules / route change.

### Added (2026-06-25 — Premium UX/Logic Refactor · §8 Branch Media: logo/cover upload + BranchAvatar)

Branch branding support — an admin uploads a branch **logo** + **cover** to
Storage, and a reusable **`BranchAvatar`** renders the branch's identity. **No
chromatic `branchTheme`** — a per-branch colour theme conflicts with the locked
monochrome ruling, so it was intentionally dropped; the prompt's "Branch Media"
intent (logo/cover) is delivered, branding stays greyscale. `flutter analyze`
clean (0 issues); **174 tests pass** (+7 `branch_media_test`); freezed regenerated.
⚠️ **Deploy** `firebase deploy --only storage` (new `branches/{id}` path) — until
then uploads fail with a Storage permission error.

- **Schema** — `BranchEntity`/`BranchModel` gain `logoUrl` + `coverUrl` (freezed
  regenerated, all back-compat / nullable). `BranchModel.toMap` **excludes** the
  media URLs so a normal name/location edit-save never clobbers an uploaded logo;
  media is written only by the dedicated upload path.
- **Storage upload** — `BranchRemoteDataSource.uploadBranchImage(branchId, file,
  {isLogo})` uploads to `branches/{branchId}/{logo|cover}.jpg` (fixed path →
  overwrite + fresh token; 60s timeout, mirroring the profile uploader) and
  persists the URL onto the branch doc. Threaded through `BranchRepository(+Impl)`
  (invalidates the branch cache so the new media surfaces everywhere) and
  **`BranchCubit.uploadBranchImage`** (uploads → reloads → returns the URL).
  `BranchRemoteDataSourceImpl` now takes `FirebaseStorage` (DI updated).
- **`BranchAvatar`** ([core/widgets/branch_avatar.dart](lib/core/widgets/branch_avatar.dart),
  §11) — the branch identity mark: logo if present, else monochrome **initials**
  from the name (store glyph when empty); a rounded square (a branch is a place,
  not a person). Network-error → initials fallback.
- **Upload UI** — the branch form sheet ([branch_form_sheet.dart](lib/features/branch/presentation/widgets/branch_form_sheet.dart))
  gains a **Branch media** section (editing only — a new branch has no id yet, so
  it shows a "save first" hint): a logo row (`BranchAvatar` preview + Add/Change
  `PremiumButton`) and a cover field (banner preview + Add/Change), each with an
  inline spinner during upload.
- **Display** — the branch management card now leads with `BranchAvatar` instead
  of the static store glyph. **Storage rules** add a `branches/{branchId}/{file}`
  path (signed-in read/write; the real gate is the admin-only Firestore branch
  write, mirroring the task-media rule).
- **Deferred (display wiring):** surfacing `BranchAvatar` on the schedule header,
  the operations/branch dashboard, and the employee profile's branch — each needs
  that surface to carry the branch's `logoUrl` (a small follow-up per surface).

### Refactored (2026-06-25 — Premium UX/Logic Refactor · Slice 2b: component rollout cleanup)

Finished the Slice 2 rollout — swept the remaining ad-hoc buttons + glass cards
onto the canonical primitives so `AppGlassCard` / `PremiumButton` are the default.
`flutter analyze` clean (0 issues); **167 tests pass**. Behaviour-preserving.

- **Compact action buttons → `PremiumButton`** (the duplicated `TextButton.icon` +
  `darkSurfaceElevated` + radius-10 + caption pattern, repeated as button classes):
  `swap_view._SwapButton` (swap accept/reject/approve actions),
  `admin_user_card.AdminActionButton`, `branch_management._btn`, and the custom
  hand-rolled `employee_home._ActionButton` (right-aligned; primary → filled). All
  delegate to `PremiumButton` keeping their call-site APIs (zero call-site churn).
- **Glass-gradient cards → `AppGlassCard`** (the exact `GlassContainer` gradient +
  border + depth-shadow, hand-rolled): `branch_management._card` and
  `employee_home._HeroTodayCard`. These were the **only** two remaining glass-card
  duplications — both gone.
- **Audit result (success criteria met):** no remaining duplicated glass-card
  styling (`grep` for the gradient = 0 hits) and no remaining duplicated compact-
  action-button implementations (`grep` for the pill pattern = 0 hits). The
  *justified* remainders left as-is: standard Material `TextButton`/`OutlinedButton`
  one-offs (banner text-actions, a text-link, a single outlined "Assign") — not
  custom duplications; and the only feature-level `BoxShadow`s left are auth
  brand/input-focus surfaces + the animated **status-aura** task header (a
  specialised semantic element, not a glass card).

### Added + Refactored (2026-06-25 — Premium UX/Logic Refactor · Slice 2: premium component system)

§10/§11 of the refactor — a reusable premium component layer, built to **reduce**
duplicated UI (the stated §11 goal) rather than fork parallel widgets, then
validated by migrating three surfaces. Strictly monochrome with **subtle semantic
status glows only** (emerald/amber/red on task status cards; **no indigo** — the
prompt's indigo accent + "active" glow stay rejected per the 2026-06-25 ruling).
No full-screen redesigns. `flutter analyze` clean (0 issues); **167 tests pass**
(+5 `premium_components_test`).

- **`GlassContainer` gains a `glow`** (optional `Color?`) — a soft tinted halo +
  faint border tint, default null (zero behaviour change for the dozens of
  existing call sites). This is the one shared decoration; the components below
  layer semantics on top of it (no duplicate "glass" treatment).
- **`AppGlassCard`** ([core/widgets/app_glass_card.dart](lib/core/widgets/app_glass_card.dart))
  — the canonical premium card. A thin semantic wrapper over `GlassContainer`
  that maps a **task status → subtle glow** (`glowForTaskStatus`: approved =
  emerald · waitingReview = amber · rejected = red; pending/started/completed =
  **no glow**, monochrome — no indigo "active" glow).
- **`MetricPill`** ([core/widgets/metric_pill.dart](lib/core/widgets/metric_pill.dart))
  — a compact glanceable `[icon] value · label` chip (the small sibling of
  `DashboardMetricCard`); monochrome, optional semantic `tone`.
- **`PremiumButton`** ([core/widgets/premium_button.dart](lib/core/widgets/premium_button.dart))
  — the canonical **compact inline** action button (filled/tonal/ghost, press-
  scale, optional destructive `tone`). Fills the niche of the scattered per-card
  buttons; **not** a duplicate of the 56px form `AppButton`.
- **`StatusBadge`** — exposed `taskStatusColor(TaskStatus)` so the status→colour
  map is the single source for both the badge and the card glow.
- **Migrations (3 surfaces, to validate the layer):**
  - **Manager Task card** — `TaskCard` gained an opt-in `premium` flag (default
    off, so the other 5 `TaskCard` surfaces are untouched); `ManagerTaskCard`
    sets it, rendering on `AppGlassCard` with the status glow. `TaskActionButton`
    now delegates to `PremiumButton` (one button impl for card actions).
  - **Admin Home pending card** — `PendingActions` migrated `GlassContainer` →
    `AppGlassCard` and gained a glanceable `MetricPill` summary strip
    (reviews/approvals/swaps/overdue, non-zero, shown when 2+).
  - **Notifications list** — `NotificationTile` rebuilt on `AppGlassCard` (press
    feedback, unread → elevated) and gained the missing **category badge**
    (Task · Review · Reminder · Broadcast) via the reused `StatusBadge`.
- **Deferred (not in this slice):** migrating the remaining ad-hoc card buttons
  (employee-home `_ActionButton`, pending-review `_DrillRow`) to the new layer,
  and the rest of §5/§8/§9.

### Added + Fixed (2026-06-25 — Premium UX/Logic Refactor · Slice 1: correctness fixes)

First slice of the 12-point "Premium UX + Logic Refactor". After reality-checking
the prompt against the code (several items were already done or deliberately
rejected), the owner ruled: **strictly monochrome + subtle status glows only (no
indigo)**, **logic/correctness first**, and **keep the existing `fcmTokens` array**
(the prompt's `fcmDevices` rebuild was rejected as over-engineering — multi-device,
logout-removal, refresh-rotation and dead-token pruning already work). `flutter
analyze` clean (0 issues); **162 tests pass** (+5 `active_window_test`); `node
--check functions/index.js` valid. ⚠️ Deploy debt grows: `firestore:rules` (approved-
task lock) + `functions` (broadcast self-exclude) are undeployed.

- **§1 — Admin Pending Review drill-down.** The admin review CTA used to jump
  straight to the branch-operations overview; it now opens a guided
  **Summary → Branch → Employee → Task** flow. New
  [`pending_review_screen.dart`](lib/features/task/presentation/pages/pending_review_screen.dart)
  (a self-contained 3-level drill reading the app-wide `TaskCubit` all-branches
  stream, filtered to `waitingReview`, grouped by branch then assignee; premium
  monochrome glass summary with an animated count; leaf reuses `ManagerTaskCard` →
  the existing review surface). New route `RouteNames.adminReview` (`/admin/review`,
  admin-guarded). Both Home review CTAs (`PendingActions.onReviews` + the `_Hero`
  review state) rewired to it. No new cubit / schema / data layer.
- **§2 — Employee "Done X/Y" no longer counts forever.** The home progress ring +
  stat strip counted *every* task ever assigned, so historically-approved work
  inflated the denominator permanently. New pure
  [`active_window.dart`](lib/features/task/domain/active_window.dart)
  (`isTaskInActiveWindow` / `activeWindowTasks`): counts outstanding work plus only
  work **approved today**; approved tasks from a previous day fall out of the count
  (effectively archived from "today"). Wired into `employee_home_screen` (counts
  only — the task sections were already in-window). Unit-tested.
- **§4 — A broadcast no longer notifies its own sender.** `dispatchBroadcast`
  (`functions/index.js`) resolved `allBranches`/`branch` recipients as "all active
  users" with no sender exclusion, so an admin/manager got their own announcement
  (inbox + push). The sender is now filtered out of **implicit** audiences
  (everyone / a branch / a role); **explicit** audiences (a direct `user` message
  or a hand-picked `custom` list) are honoured as chosen.
- **§6 — Approved tasks are locked.** An approved task is a reviewed record;
  `editTask` / `deleteTask` / `assignEmployees` only had a client path that bypassed
  the status guard, and the `tasks` update/delete rules had no approved lock.
  - **Cubit** — `editTask`/`deleteTask`/`assignEmployees` now refuse an approved
    task (friendly transient error); new admin-only **`TaskCubit.reopenTask`** moves
    an approved task back to `started` (clearing the approval audit + logging a
    "Reopened for changes" activity entry) so a mistaken approval is recoverable.
  - **Rules** — `tasks` update permits an in-place change on an approved task only
    for an **admin reopen** (status must move out of `approved`); manager/admin
    in-place edits and **deletes** of an approved task are denied (the review
    transition *into* approved is unaffected).
  - **UI** — `ManagerTaskCard` + `TaskDetailsScreen` hide Assign/Edit/Delete on an
    approved task, show a **Reopen** affordance (admin only) + a monochrome locked
    banner/glyph.

### Changed (2026-06-24 — Schedule grid premium redesign: faces + names per shift)

Visual/UX upgrade of the admin + manager weekly schedule grid (the shared
`ManagerScheduleView` → `ScheduleGrid` → `ShiftCell`). Presentation-only — no
schema / rules / route / DI / cubit / freezed change. `flutter analyze` clean
(0 issues); **157 tests pass** (`schedule_grid_test.dart` updated to the new
cell). Strictly monochrome (no chromatic accent introduced); the requested
mockup's purple/gold/blue and its "X of N open" **staffing-quota** model were
deliberately **not** adopted (quotas were a settled product rejection — coverage
stays "has someone / empty").

- **`ShiftCell` now shows _who_, not a number.** A staffed slot renders an
  `AvatarStack` (real faces, initials fallback) + up to two compact names
  (`shortName`: "Ahmed M.") + a "+N more" overflow, on a subtly top-lit elevated
  card. An empty slot is a muted **dashed** placeholder (`_DashedBorderPainter`)
  with a person-add glyph + "No one" (was a bare "—"/"Empty"). Today's column
  keeps the solid white ring; a broken/orphan reference is still flagged with the
  amber warning and never shown as a uid. `ShiftCell` API changed from a `count`
  int to a `List<UserEntity> users`; the grid resolves the cell's valid uids to
  members (`userForUid`) and passes them in.
- **Premium shift rail.** Each shift row's rail gained a rounded icon tile
  (morning = brighter white-wash sun · night = dim moon — brightness, not colour,
  separates them) plus the shift **time range** (`08:30 – 16:30`). Cells widened
  (86→128 w · 78→122 h) so faces + names fit; the grid still scrolls horizontally
  with the pinned rail + day headers.
- **Coverage summary upgraded** (`manager_schedule_view._coverageSummary`): icon
  tile + "N of M shifts covered" + plain-language subtitle + a **% pill** and a
  monochrome **coverage progress bar**. Added a one-line tap/scroll **hint** above
  the grid.
- New helper `shortName(UserEntity)` in `schedule_helpers.dart`.

### Fixed (2026-06-24 — Perf audit regression fixes: offline admin stats + task stream scope)

Two highest-priority regressions from the Phase A–D validation audit. `flutter
analyze` clean (0 issues); **157 tests pass**. No schema / rules / route / DI /
freezed change.

- **L1 — Offline-safe admin statistics
  (`statistics_remote_datasource.dart`).** Phase A moved `adminStats` to
  server-side `count()` aggregation, but aggregation queries are **server-only**
  (no offline cache support), so `count().get()` throws `unavailable` when
  offline → the whole `adminStats` failed → admin dashboard showed a hard error
  instead of cached numbers (regressing the offline-first goal; manager/employee
  stats were unaffected since they use cache-backed `.get()`). Fix: `_aggCount`
  now catches the offline `unavailable` error and falls back to counting the
  **same query's** documents from the local cache
  (`query.get(Source.cache).docs.length`) — last-known values, no network, no
  hard failure. The **online path is unchanged** (still pure aggregation, zero
  doc downloads); the cached fallback only runs offline and reads only the
  already-filtered query. Non-offline errors (e.g. `permission-denied`) are
  rethrown so genuine failures still surface.

- **L3 — Task stream scope guard (`task_cubit.dart`).** Phase A's idempotency
  guard keyed only on `uid`, but `_streamFor` selects a **different** stream per
  role/branch (admin → `watchAllTasks`, manager → `watchTasksByBranch`, employee
  → `watchEmployeeTasks`). A same-uid role or branch change while the app was
  active (e.g. an employee promoted to manager, or moved branches, via
  `watchCurrentUser`'s re-emit) would hit the no-op guard and **keep streaming
  the wrong scope**. Fix: a new `_scopeKey(u) = uid:role:branchId` is now the
  subscription identity — the no-op guard returns early only when the full scope
  matches, and a scope change resubscribes and clears the scope-bound directory /
  branch caches. The revisit no-op optimization is preserved for an identical
  scope; pull-to-refresh (`forceRefresh`) and error-recovery paths are unchanged.

### Changed (2026-06-24 — Performance · Phase D: admin-dashboard + broadcast-feed rebuild scoping)

Two targeted UI-rebuild fixes from the rebuild/render audit (which found the app
otherwise healthy — scoped builders, `context.select`, keyed lists, no
blur/`saveLayer` rendering). **Scope limited to two screens; no broad refactor.**
Behaviour preserved exactly. No schema / rules / route / DI / freezed change. ⚠️
Local toolchain (Dart 3.10.4 < `^3.12.1`) **can't run `analyze`/`test` here** —
verify on a current SDK.

- **P1 — Admin dashboard (`admin_dashboard_screen.dart`).** Removed the two
  top-level `context.watch` (`StatisticsCubit` + `TaskCubit`) that rebuilt the
  **entire** dashboard (≈12 sections / ≈16 cards) on every all-branches task-stream
  emit. The `ListView` scaffold + static sections (Overview / Quick actions /
  Manage headers + grids) now build **once**. Data sections subscribe via two new
  private helpers:
  - `_StatsSection` — `BlocBuilder<StatisticsCubit>`; used by the greeting scope
    line + the metric grid (no task dependency → never rebuilt by the task stream).
  - `_DynamicSection` — `BlocBuilder<StatisticsCubit>` + a
    `BlocSelector<TaskCubit, TaskState, int>` over the **overdue count**; used by
    the hero + Pending Actions header + Pending Actions. A task emit that doesn't
    move the overdue number rebuilds nothing.
  - `_Hero` now takes a pre-computed `overdue` int (its only task input) instead
    of the task list.
  - Every section's `EntranceFade` is **keyed** (`ValueKey('admin-sec-…')`), so the
    entrance plays once and never replays when the conditional "Pending approvals"
    section appears and shifts the trailing sections.
- **P2 — Broadcast feed (`communications_screen.dart`).** Non-lazy `ListView` →
  **`ListView.builder`** (off-screen cards no longer built). Each `BroadcastCard`
  is **keyed by `broadcast.id`** (not index), so a stream reorder/insert reuses
  elements instead of shuffling. The `EntranceFade` now plays **once per broadcast
  id** (tracked in a `_entered` set) — so neither a live-stream emit nor a
  `ListView.builder` scroll-recycle replays it (removes the feed flicker; scales to
  long histories).
- **Estimated rebuild reduction:** admin home goes from a full-tree rebuild on
  *every* task emit to rebuilding only hero + Pending Actions, and only when the
  overdue count changes (often zero rebuilds for emits like the post-load
  directory/branch-name fills). Broadcast feed stops rebuilding/re-animating the
  whole visible list on each stream tick.
- **Behavioural risks (low):** (a) the broadcast entrance now fires as cards scroll
  into view (once each) rather than all at load — the initial viewport cascade is
  unchanged; (b) `_entered` is populated inside `itemBuilder` (a benign build-phase
  `Set.add`, no `setState`); (c) `_DynamicSection`'s selector recomputes
  `_overdueCount` per task emit (O(n), cheap) to detect change. Not touched: P3
  (generic `ListView.builder` migrations elsewhere).

### Changed (2026-06-24 — Performance · Phase C: warm-start preload + splash floor trim)

Improve perceived startup so Home paints with real data instead of skeletons —
with **no preload framework / no new files / no storage deps**, ~6 lines total.
The audit found the real startup bottleneck was **not** Firestore reads but a
hardcoded **2400 ms artificial splash delay**, ~1 s of it dead time after the
1400 ms brand animation. No schema / rules / route / DI / freezed change. ⚠️ Local
toolchain (Dart 3.10.4 < `^3.12.1`) **can't run `analyze`/`test` here** — verify
on a current SDK.

- **Splash floor trimmed** (`splash_page.dart`) — `_initSession`'s
  `Future.delayed(2400ms)` → **1400 ms** (matches the brand animation length),
  removing ~1 s of dead time before navigation. Auth restore (1 read) finishes
  well within it.
- **Warm-start preload** (`main.dart`) — the existing app-wide
  `BlocListener<AuthCubit>` (fires on `authenticated` for **both** cold-start
  restore and fresh login; already loads the FCM token + notifications) now also
  calls `StatisticsCubit.load(u)` + `TaskCubit.load(u)`, **gated on
  `u.hasAppAccess`** so a pending user triggers zero home reads. The fetch
  overlaps the splash + route transition, so Home renders data immediately.
- **Fire-and-forget + concurrent** — not `Future.wait`, not awaited: independent
  reads run in parallel (negligible Firebase load) with **per-cubit error
  isolation** (one failing can't break the others or the splash). Off the paint
  path.
- **No redundant reads** — both preloads are **idempotent** (Phase A:
  `StatisticsCubit` TTL+key guard, `TaskCubit` same-user no-op), so Home's own
  `initState` `load()` calls become no-ops. The listener and the screen can both
  call `load()` with only one actual fetch.
- **Deliberately not preloaded:** templates (lazy — only on compose/create;
  Phase B cache), branches (warmed indirectly by `TaskCubit._loadBranchNames` +
  Phase B cache), schedule / pending-approval / swap queues (screen-specific).
  Preloading them would be wasted reads users may never need.

### Added (2026-06-24 — Performance · Phase B: repository-level branch + template caches)

Lightweight in-memory caching for the two highest-ROI remaining read hotspots,
**inside the existing repositories** — deliberately **no** generic cache
framework, **no** Hive/Isar/SharedPreferences, **no** `CacheService`/
`CacheManager`/`TtlCache` classes. Each cache is the same minimal shape: a
private `_cachedX` + `_xFetchedAt`, a TTL const, an optional `forceRefresh`
param on the read, and a `_invalidateX()` called after every write. No schema /
rules / route / DI / freezed change. ⚠️ Local toolchain (Dart 3.10.4 <
`^3.12.1`) **can't run `analyze`/`test` here** — verify on a current SDK.

- **Branch cache (`BranchRepositoryImpl`).** Caches the active (non-deleted)
  branch list with a **10-minute TTL**. Because the repository is a **single
  shared instance** (DI), this dedupes **all six** branch-read paths at once with
  **no call-site changes**: `BranchCubit`, `TaskCubit._loadBranchNames`,
  `TaskCubit.branches` (admin picker), `AdminUsersCubit.branches`,
  `BroadcastCubit.branches`. `getBranches({includeDeleted, forceRefresh})` —
  `includeDeleted` (admin-rare, unused) is never cached; `forceRefresh` bypasses.
  Invalidated after `createBranch`/`updateBranch`/`setBranchActive`/`deleteBranch`.
- **`BranchCubit.load({forceRefresh})`** threads the flag so the branch-management
  **pull-to-refresh** (`_refresh`) still does a real fetch; `_mutate` re-reads
  after the (already-invalidated) write, so a created/edited/deleted branch shows
  immediately everywhere.
- **Task-template cache (`TaskRepositoryImpl`).** `getTemplates({forceRefresh})`
  caches the (tiny, global) template collection with a **20-minute TTL**,
  invalidated on `createTemplate`/`deleteTemplate`. The New-Task chooser + Manage
  Templates sheet read it 3× per session → now ≤1 Firestore read per window; the
  manage sheet's delete re-read gets the invalidated (fresh) list.
- **Broadcast-template cache (`BroadcastTemplateRepositoryImpl`).** Symmetric —
  **20-minute TTL**, invalidated after **all five** writes (`create`/`update`/
  `setFavorite`/`incrementUsage`/`delete`).
- **No stale-data risk:** both template reads are unconstrained full-collection
  queries (branch scoping is applied client-side in the cubit), so the cached
  value is global rather than a per-user slice — safe to reuse across sessions,
  bounded by the TTL and cleared by every mutation.

### Refactored + Fixed (2026-06-24 — Performance · Phase A: reload/refetch guards + adminStats query)

First slice of the performance work — **surgical** fixes to kill redundant
Firestore reads and screen reloads, deliberately **without** a generic cache
service / Hive / Isar (a dedicated cache layer is to be **reassessed after**
this). Scope was limited to `ProfileCubit`, `StatisticsCubit`, `TaskCubit`, and
the `adminStats` query. No schema / rules / route / DI / freezed change. ⚠️ The
local toolchain (Dart 3.10.4 < the project's `^3.12.1`) **can't run
`analyze`/`test` here** — verify on a current SDK.

- **`ProfileCubit.loadProfile(uid, {forceRefresh})` is idempotent.** It tracks
  `_loadedUid` (stamped on a successful load **and** on `save`) and **returns
  early** when that uid's profile is already in memory — no Firestore re-read, no
  skeleton. It only emits `loading()` when there's nothing to show. **Fixes the
  "returning to Profile triggers a full reload."**
- **`StatisticsCubit.load(user, {forceRefresh})` caches the last result.** Keyed
  by `role:uid:branch` with a 90 s freshness window; a revisit inside the window
  is a **no-op** (skips the expensive aggregate) and never flashes a skeleton over
  existing numbers. Pull-to-refresh passes `forceRefresh`.
- **`TaskCubit.load(user, {forceRefresh})` is idempotent.** When already streaming
  the same user (and not in an error state) it **no longer cancels + re-subscribes
  the snapshot stream** (a fresh server read) or emits `loading()` — so revisiting
  any task screen doesn't reload. Errors still retry on revisit; `refresh()` now
  passes `forceRefresh` to re-subscribe.
- **Dashboards** — `employee_home` / `manager_home` / `admin_dashboard`
  `_load({force})` thread `forceRefresh` so **pull-to-refresh** still does a real
  fetch; the admin dashboard's redundant local "already loaded?" task guard was
  removed (the cubit guards it now).
- **`adminStats` query optimized** — the only unscoped statistics query stopped
  downloading **all** users + **all** tasks + **all** schedules. Now: **server-side
  `count()` aggregation** (`_aggCount`) for `totalEmployees` / `pendingApprovals` /
  total / approved / waitingReview / rejected, plus **bounded single-field reads**
  for the cross-referenced metrics (managers-only for `branchesWithoutManagers`;
  `weekStart >= currentWeek` for `branchesWithSchedule`; `rejectedAt >= today` for
  `rejectedTasksToday`). `activeTasks = total − approved − rejected`. **Identical
  numbers**, all single-field filters (automatic indexes — **no composite index**).
  `managerStats`/`employeeStats` are already branch/user-scoped and unchanged.

### Removed (2026-06-24 — Simplification pass · slice 4b: remove Priority + Delivery, derive delivery from category)

Decision B (part 2) — deleted the manual **Priority** and **Delivery-channel**
selectors. Delivery is now derived from the category (the single dial):
announcement → inbox only · reminder → push + inbox · emergency → push + inbox +
high FCM priority. Two orthogonal manual axes collapse into one. `flutter analyze`
clean (0 issues); **157 tests pass**; `node --check functions/index.js` valid.

- **Enums deleted:** `BroadcastPriority` + `BroadcastChannel`. `BroadcastCategory`
  gains pure `sendsPush` / `isHighPriority` / `deliverySummary` — the single source
  of the delivery rule (the Cloud Function mirrors it).
- **Schema:** dropped `priority` + `channel` from `BroadcastEntity`/`Model`,
  `BroadcastTemplateEntity`/`Model`, and `BroadcastScheduleEntity`/`Model` (freezed
  regenerated) — one fewer concept across all three broadcast shapes.
- **Compose:** removed the Priority + Delivery-channel selectors; a read-only
  `_DeliveryHint` and the preview footer now show `category.deliverySummary`. The
  template editor drops the same two selectors.
- **Detail:** the Priority + Channel rows collapse into one category-derived
  **Delivery** row; the feed card drops the priority line.
- **Cloud Function:** `dispatchBroadcast` derives push/inbox + high priority from
  the category (`categorySendsPush` / `categoryIsHigh`) instead of reading
  priority/channel; every category writes the inbox, announcement is push-suppressed.
- **Also:** removed the stale "cannot run build_runner" comment on the schedule
  entity. Tests updated (lifecycle / template / schedule model tests).

**Guardrail check (no over-coupling found):** per the instruction to stop-and-report
if removing Priority/Delivery exposed a root design problem — it did **not**. The
fields were plain, duplicated value-object attributes; collapsing delivery into the
category *removed* coupling (two manual dials → one derived rule). The only mild
smell — priority/channel/category triplicated across broadcast/template/schedule —
is inherent to "a template/schedule is a prefilled broadcast" and is now smaller
(one field, not three). No compatibility layer was added.

### Changed (2026-06-24 — Simplification pass · slice 4a: Category 4→3, drop Alert)

Decision B (part 1) — merged the broadcast categories from 4 to 3 by removing
**Alert** (it overlapped Reminder/Emergency and delivered identically). Final set:
**Announcement · Reminder · Emergency**. `flutter analyze` clean (0 issues); **160
tests pass**; `node --check functions/index.js` valid.

- `BroadcastCategory` drops `alert` — `isUrgent` is now emergency-only; `fromString`
  maps the retired `'alert'` string → announcement (back-compat). The compose
  category chips iterate `.values`, so they auto-collapse to 3.
- `NotificationType` drops `broadcastAlert`; `fromBroadcastCategory` and the
  function `categoryToType` no longer special-case alert. `notification_tile` and
  `communications_format` drop the alert icon/colour cases.
- Tests updated (`broadcast_category`, `notification_model`/`grouping`,
  `broadcast_card`, `broadcast_model`).
- **Next:** slice 4b — remove the Priority + Delivery selectors (delivery becomes
  category-derived).

### Removed (2026-06-24 — Simplification pass · slice 3b: drop soft-delete + collapse Comms nav)

Removed the broadcast **soft-delete / Deleted view** and collapsed the
Communications Center navigation to one primary surface. `flutter analyze` clean
(0 issues); **160 tests pass**; `node --check functions/index.js` valid.

- **Soft-delete gone** — dropped `deletedAt` + `isDeleted` from `BroadcastEntity`/
  `BroadcastModel` (freezed regenerated); `isActive` is now simply "not archived".
  Removed `setDeleted` from the cubit / repository / datasource, the Deleted view,
  the **Delete / Restore / Duplicate / Schedule-again** card + detail actions, and
  the function housekeeping for soft-deleted broadcasts. The `broadcasts` update
  rule now freezes every field but `archivedAt`. A broadcast is **active or
  archived** — no recycle bin.
- **Nav collapsed** — the Communications home is now just the **feed + New
  Broadcast FAB**; **Scheduled / Templates / Archived** moved into a single "···"
  overflow (the Active/Archived/Deleted segmented bar and the separate app-bar
  icons are gone). Archived is a back-navigable view, not a primary tab.
- **`BroadcastCardAction`** trimmed to `open · repeatNow · archive · unarchive`
  (both the feed card and the detail menu).
- **Tests** — `broadcast_lifecycle_test` updated to an archived-only lifecycle.

### Removed (2026-06-23 — Simplification pass · slice 3: kill the analytics pipeline)

Decision A — analytics were vanity (open rate / read rate / monthly rollups /
charts drove no admin decision). Removed the entire pipeline; kept **minimal
delivery diagnostics (recipients · delivered · failed)** for operational health.
`build_runner` re-run; `flutter analyze` clean (0 issues); **160 tests pass**;
`node --check functions/index.js` valid.

- **Cloud Functions** — deleted `onNotificationRead` and `onBroadcastOpened`
  triggers, the `bumpAnalytics` helper + `analytics/{YYYY-MM}` rollups, and the
  `broadcastOpens` housekeeping. `dispatchBroadcast` no longer writes
  `openedCount`. Five operational functions remain (`sendBroadcast`,
  `onNotificationCreated`, `runBroadcastSchedules`, `broadcastHousekeeping`,
  `runTaskReminders`).
- **Client** — deleted the `comms_analytics` slice (entity / repo / datasource /
  `communications_analytics_screen`) + its DI wiring + the `/communications/analytics`
  route + the Communications app-bar Analytics icon. Removed `BroadcastCubit.trackOpen`
  and the open-tracking chain (datasource/repo). The broadcast detail screen now
  shows **Delivery** diagnostics (recipients · delivered · failed) — the "open
  rate" stat is gone.
- **Schema** — dropped `openedCount` from `BroadcastEntity`/`BroadcastModel`
  (freezed regenerated). `recipientCount`/`deliveredCount`/`failedCount` stay.
- **Rules + constants** — removed the `analytics` and `broadcastOpens` rule
  blocks and the `analyticsCollection`/`broadcastOpensCollection` constants.
- **Tests** — deleted `comms_analytics_test`; trimmed `openedCount` assertions
  from `broadcast_lifecycle_test`.
- **Deferred to next slices:** the Deleted-view/soft-delete removal + nav-overflow
  (Slice 3b) and the Priority/Delivery-selector + Category 4→3 (Slice 4, Decision
  B — cascades through templates + schedules).

### Fixed (2026-06-23 — Simplification pass · slice 2: task notifications open the exact task)

A task notification (assigned · rework · approved · rejected · submitted ·
reminder · overdue) now opens the **exact task**, not the task list. `flutter
analyze` clean (0 issues); **165 tests pass**.

- **New `/task/:taskId` route** (`RouteNames.taskDetailPattern` / `taskDetail(id)`)
  — a top-level route outside the role-area guards (a user only reaches it via a
  task they were notified about; Firestore rules enforce read access).
- **`TaskDetailLoaderScreen`** loads the task by id via
  `TaskRepository.getTask` (already existed) and shows `TaskDetailsScreen`
  (which then stays live from the app-wide `TaskCubit` stream); skeleton while
  loading, a friendly "Task unavailable" state with Retry on miss/error.
- **Both entry points fixed:** the inbox tile `_deepLink` and the FCM push-tap
  handler (`main.dart onMessageTap`) now route `route == 'task_details'` with a
  `taskId` to `/task/:taskId` (falling back to the list / inbox when absent).
- No schema / rules / function change. The notification payload already carries
  `taskId` + `route` (written by `NotifyTaskEvent` and `runTaskReminders`).

### Changed (2026-06-23 — Simplification pass · slice 1: lean Notification Center)

First slice of the product-simplification pass (philosophy: DROP is a lean
premium internal ops tool, not enterprise — fewer screens / controls / decisions).
The Notification Center is now a clean, glanceable **action inbox**. Client-only —
no schema / rules / function change. `flutter analyze` clean (0 issues); **165
tests pass**.

- **Filter reduced to All / Unread.** Removed the Tasks / Broadcasts type filters
  (and the already-removed System) — `NotificationFilter` is now just
  `all` / `unread`.
- **Action-first grouping.** Replaced the 5-bucket date grouping (Pinned · Today ·
  Yesterday · This week · Earlier) with **Needs action** (task assigned · rework ·
  reminder · overdue) above **Earlier** (approvals · submissions · broadcasts),
  each newest-first. New pure `isActionNeeded` + `groupByPriority` in
  `notification_format.dart`.
- **Removed power-user chrome:** search field, per-tile actions menu, pin, and the
  archived-view toggle are gone from the UI. The tile is now display-only;
  interaction is **tap to open** (marks read + deep-links) and **swipe to delete**.
  **Mark all read** stays.
- **Archive kept in architecture, hidden** — `archivedAt`/`pinnedAt` fields and the
  cubit/repo methods remain (archived items stay filtered out of the inbox); only
  the UI surface was removed.
- **Tests** — `notification_grouping_test` rewritten for the lean API
  (All/Unread, `isActionNeeded`, `groupByPriority`).
- **Deferred to next slices:** exact-task deep-link fix (`/task/:taskId`),
  Communications Center slimming (drop Deleted/Analytics, overflow nav), compose
  simplification (remove Priority + Delivery selectors), and the data-layer
  removal of the now-dormant pin field.

### Fixed + Changed (2026-06-23 — Stabilization pass: analyze clean, docs synced, NotificationType trimmed)

A trust-but-verify stabilization checkpoint before resuming feature work — no new
features. Verified on the real toolchain (**Flutter 3.44.2 / Dart 3.12.2**):
`build_runner` runs, **`flutter analyze` is clean (0 issues)**, **164 tests pass**,
`node --check functions/index.js` valid.

- **Corrected a stale doc premise.** Prior entries claimed "the local SDK is too
  old to build, so freezed files were hand-edited." The SDK builds fine. Re-ran
  `dart run build_runner build --delete-conflicting-outputs`: three freezed files
  (`broadcast_template_entity`, `broadcast_schedule_state`, `broadcast_template_state`)
  had **cosmetic-only** drift (formatter line-wrapping; same fields/types/logic) —
  now regenerated and committed. The notification-core freezed files were already
  exact.
- **`flutter analyze` → 0 issues** (was 3): removed an unused `communications_format`
  import in `broadcast_templates_screen.dart`; replaced the deprecated
  `activeColor` with `activeThumbColor` on the `Switch.adaptive` in
  `broadcast_schedules_screen.dart`; replaced `if (x != null) x!` with the
  null-aware element `?x` in `compose_broadcast_screen.dart`.
- **`NotificationType` trimmed 27 → 11.** Removed 16 "reserved" schedule / swap /
  admin types (`shiftChanged`, `managerNote`, `tomorrowShiftReminder`,
  `swapApproved`, `swapRejected`, `taskWaitingReview`, `employeeCompletedTask`,
  `newEmployeePendingApproval`, `shiftWithoutEmployees`, `newSwapRequest`,
  `swapPendingApproval`, `newEmployeeRegistration`, `branchWithoutManager`,
  `manyRejectedTasks`, `branchWithoutActiveEmployees`, `branchWithoutSchedule`)
  that had **no producer** in client or Cloud Functions — pure dead surface. Every
  remaining value has a live trigger (task lifecycle via `NotifyTaskEvent`,
  reminders via `runTaskReminders`, broadcasts via `dispatchBroadcast`). Safe:
  these types were never written to Firestore, and `NotificationModel.fromMap`
  already falls back for an unknown type. Re-add a value only alongside its
  producer.
- **Removed the coupled, now-empty "System" inbox filter.** After the trim every
  type is `task*` or `broadcast*`, so `NotificationFilter.system` (`!task &&
  !broadcast`) could never match — the toolbar is now All / Unread / Tasks /
  Broadcasts. Dropping the only fully-covered case also made `notification_tile`'s
  `_iconFor` switch exhaustive, so its unreachable `default` was removed (future
  type additions are now a compile-time prompt).
- **Tests** — updated `notification_grouping_test` (the system-partition case
  became a task-vs-broadcast case; reminders assert under Tasks).
- **No change** to data schema, rules, indexes, functions, routes, or the
  outstanding **deploy debt** (the 7 Cloud Functions remain undeployed; push is
  inert until `firebase deploy` + iOS APNs).

### Added (2026-06-22 — Communications Center · Phase 2 Commit 6: analytics aggregation + dashboard)

Final commit of the **Premium Upgrade** — communications **analytics** via
**precomputed aggregates** (no live scans). `node --check functions/index.js`
valid. **The 6-commit Communications Center Premium Upgrade is complete.**

- **Aggregation (Cloud Functions)** — a monthly rollup doc **`analytics/{YYYY-MM}`**
  with `totals.{metric}` + `days.{DD}.{metric}` counters, maintained incrementally
  by a shared `bumpAnalytics` helper: `dispatchBroadcast` bumps
  `broadcastsSent`/`recipients`/`delivered`; `onNotificationCreated` bumps
  `notifSent`; a new **`onNotificationRead`** (`onDocumentUpdated`) bumps
  `notifRead` on the first read; a new **`onBroadcastOpened`**
  (`onDocumentCreated` on `broadcastOpens`) bumps `opened` + the broadcast's
  `openedCount`.
- **Open tracking** — the broadcast detail screen records a view once via an
  idempotent `broadcastOpens/{broadcastId}_{uid}` guard doc
  (`BroadcastCubit.trackOpen` → repo/datasource, create-once, best-effort).
- **Analytics slice (read)** — pure `CommsAnalyticsEntity` (`fromMap` + derived
  `failed`/`deliveryRate`/`openRate`/`unread`/`readRate`) +
  `CommsAnalyticsRepository(+Impl)`/`RemoteDataSource` reading the **one** monthly
  doc. Exposed on `AppDependencies.commsAnalyticsRepository`.
- **Dashboard** — `communications_analytics_screen.dart` (`/communications/analytics`,
  reached from the Communications app-bar): broadcast metrics (sent · delivered ·
  failed · open rate), notification metrics (sent · read · unread · read rate), a
  monochrome **daily-volume bar chart**, and **engagement** bars (delivery / open
  / read rate). Read-once (`FutureBuilder`, no cubit). `firestore.rules`
  `analytics` block (admin/manager read · function-only write).
- **Tests** — `comms_analytics_test.dart` (rollup parse · day sort · derived
  rates · divide-by-zero safety). **Deferred:** response-latency charts (not
  modelled — no per-event response timestamps). ⚠️ Deploy `firestore:rules` +
  `functions`.

### Added (2026-06-22 — Communications Center · Phase 2 Commit 5: task reminder engine)

Fifth commit of the **Premium Upgrade** — automated **task reminders** (server-
driven, anti-spam). `node --check functions/index.js` valid.

- **Notification types** — `NotificationType` gains `taskReminder` + `taskOverdue`
  (additive); the inbox tile renders them (alarm / overdue icons + warning/error
  accents).
- **Reminder engine** — pure
  [`reminder_rules.dart`](lib/features/task/domain/reminder_rules.dart)
  (`ReminderRules.dueKind` / `inQuietHours` / `typeFor`): escalates **due24h →
  due1h → overdue**, each kind sent at most once, never backwards; honours
  **quiet hours**, a **maxReminders** cap, and an **enabled** flag.
- **Cloud Function** — `runTaskReminders` (`onSchedule('every 30 minutes')`):
  scans tasks with `deadline <= now+24h` (single-field inequality — no composite
  index), skips terminal (approved/rejected) + deadline-less tasks, reads the
  per-task ledger **`taskReminders/{taskId}`**, and on a due kind writes a
  reminder `notifications/{id}` per assignee (pushed by `onNotificationCreated`)
  + advances the ledger. Config from **`reminderConfig/global`** (enabled · quiet
  hours · maxReminders; defaults applied when absent; quiet hours evaluated in
  UTC). The JS mirrors `ReminderRules` exactly.
- **Rules** — `taskReminders` (function-only writes, admin read) +
  `reminderConfig` (admin write, admin/manager read).
- **Tests** — `reminder_rules_test.dart` (kind selection · forward-only
  escalation · maxReminders · disabled · quiet-hours wrap-midnight · typeFor).
- **Deferred:** a reminder-config **editor UI** (today the config is a Firestore
  doc with safe defaults; editable in the console or a later admin screen);
  review-pending / feedback-pending reminders (the engine is structured to extend
  to them). ⚠️ Deploy `firestore:rules,functions` (Blaze + Cloud Scheduler).

### Added (2026-06-22 — Communications Center · Phase 2 Commit 4: scheduled + recurring broadcasts)

Fourth commit of the **Premium Upgrade** — the **scheduler**. Architecture: a
**single scheduled-Function poller** (one `onSchedule` cron, not per-schedule
Cloud Scheduler jobs) — scales to unlimited schedules cheaply, ~5-min firing
granularity. `node --check functions/index.js` valid.

- **`broadcastSchedules` slice** — `BroadcastScheduleEntity` (a **plain immutable
  value object**, not freezed: 20 fields incl. recurrence — a deliberate choice to
  avoid generated-file drift in a toolchain that can't run build_runner here) +
  `BroadcastScheduleModel` (carries `targetUserIds` for custom schedules),
  `BroadcastScheduleRepository(+Impl)`/`RemoteDataSource(+Impl)` over the new
  **`broadcastSchedules/{id}`** collection, and the repo-direct
  **`BroadcastScheduleCubit`** (load · create · pause/resume (`setEnabled`) ·
  cancel · edit). State is freezed (`BroadcastScheduleState`).
- **Recurrence engine** — `BroadcastRecurrence` enum (oneTime/daily/weekly/
  monthly/custom) + pure
  [`recurrence_rule.dart`](lib/features/communications/domain/recurrence_rule.dart)
  (`nextRun` with month-end clamping + endDate cap; `isActive`).
- **Cloud Functions** — `runBroadcastSchedules` (`onSchedule('every 5 minutes')`):
  queries `nextRunAt <= now` (single-field inequality — no composite index),
  filters `enabled` in JS, fires each due schedule through the shared
  `dispatchBroadcast`, then advances `nextRunAt`/`runCount`/`lastRunAt` (or
  disables a completed one). `broadcastHousekeeping` (`every 24 hours`): retention
  cleanup of old soft-deleted broadcasts (>90d), archived notifications (>60d),
  and broadcast-open guards (>90d). `firestore.rules` `broadcastSchedules` block
  (admin any · creator own; the function advances via Admin SDK).
- **UI** — `broadcast_schedules_screen.dart` (next run · recurrence · run-count ·
  **pause/resume** switch · **cancel**), reached from the Communications app-bar
  clock. The composer gains a **Schedule** action → a sheet (first-send date/time ·
  repeat cadence · custom interval · optional end date) that creates a schedule
  instead of sending. **Schedule Again** in the history opens the composer
  prefilled.
- **Tests** — `recurrence_rule_test.dart` (one-time/daily/weekly/monthly/custom +
  month clamp + endDate stop + isActive), `broadcast_schedule_model_test.dart`
  (round-trip + defaults + custom targetUserIds). ⚠️ Deploy `firestore:rules` +
  `functions` (Blaze; the scheduled functions need Cloud Scheduler enabled).

### Added (2026-06-22 — Communications Center · Phase 2 Commit 3: advanced recipient targeting)

Third commit of the **Premium Upgrade** — multi-recipient + role-filtered
sending, threaded as **send-time intents** (no `BroadcastEntity`/freezed change).
`node --check functions/index.js` valid.

- **`BroadcastAudience.custom`** — a hand-picked multi-recipient send. Stored with
  a `__custom__` branch marker (mirrors the DM `__direct__` marker) + a
  `targetUserIds` array, so it never leaks into a branch/all feed; the chosen
  recipients read it via the array. `custom` is **derived** (a 2+ multi-pick under
  the people picker), not a selectable chip.
- **Send pipeline** — `SendBroadcast`/`BroadcastRepository(+Impl)`/
  `BroadcastRemoteDataSource(+Impl)`/`BroadcastCubit.send` thread `targetUserIds`
  (custom recipients) + `roleFilter` (restrict a branch/all send to managers /
  employees) into the callable payload. `BroadcastPermissions` gains `custom`
  (admin any · manager own-branch members · employee none); `allowedAudiences`
  now explicitly lists the *selectable* audiences (excludes the derived `custom`).
- **Cloud Function** — `dispatchBroadcast` resolves `custom` via `db.getAll`
  (manager picks filtered to their own branch), applies `roleFilter` to branch/all
  fetches (client-side filter — no composite index), and persists `targetUserIds`
  on the doc. `firestore.rules` broadcasts **read** now also allows
  `request.auth.uid in targetUserIds`, and the branch/all read clause requires
  `targetUserIds` empty (so a custom doc never surfaces in a branch feed).
- **Composer** — the "Individual" picker became a **multi-select "People"** picker
  with **Select all / Clear** + a "{n} selected" count; sending one routes as a
  DM (`user`), two-plus as `custom`. Branch + All-branches sends gain a **role
  filter** (Everyone / Managers / Employees). Placeholder context updated for the
  single-select case.
- **Tests** — `broadcast_permissions_test` updated for `custom` + the
  selectable-audience change; `broadcast_lifecycle_test` covers the custom marker
  round-trip. ⚠️ Deploy `firestore:rules,functions`.
- **Deferred:** *saved audiences* (named reusable filters) — a follow-up; today's
  targeting covers individual / role-based / branch-based / multi-select.

### Added (2026-06-22 — Communications Center · Phase 2 Commit 2: broadcast templates + placeholder engine + premium composer)

Second commit of the **Communications Center Premium Upgrade**. Adds a reusable
**template** system with a `{{placeholder}}` rendering engine, a premium
**template library**, and a redesigned **composer**. New vertical slice
(`broadcastTemplates`), repo-direct cubit (mirrors `BranchCubit`), all additive.
⚠️ Freezed files hand-edited (SDK too old here) — run `dart run build_runner build
--delete-conflicting-outputs` + `flutter analyze` + `flutter test`.

- **Templates slice** — `BroadcastTemplateEntity` (freezed: title · message ·
  category · priority · channel · ownerId · branchId(''=global) · isFavorite ·
  usageCount + `isGlobal`/`placeholders` getters) + `BroadcastTemplateModel` over
  the new **`broadcastTemplates/{id}`** collection, `BroadcastTemplateRepository
  (+Impl)`/`RemoteDataSource(+Impl)` (CRUD + favorite + usage increment), and the
  repo-direct **`BroadcastTemplateCubit`** (load/save/update/toggleFavorite/
  delete/markUsed). Wired in `injection.dart` + `main.dart`. Rules mirror
  `task_templates` (admin any/global · own-branch manager · employees none).
- **Placeholder engine** — pure
  [`template_renderer.dart`](lib/features/communications/domain/template_renderer.dart)
  (`TemplateRenderer.extract` / `render` / `hasUnresolved`): `{{employee_name}}`,
  `{{task_name}}`, `{{branch_name}}`, `{{date}}`, `{{sender_name}}` (generic over
  any key). Rendered **client-side before** send so the function gets final text.
- **Template library** — `broadcast_templates_screen.dart`: grid/list toggle,
  search, category filter, **Favorites** + **Recent** sections, a create/edit
  editor sheet (title · category · priority · channel · message with
  quick-insert placeholder chips), favorite/delete with confirmation. New
  `template_card.dart`. Reached from the Communications Center app-bar, and in
  **pick mode** from the composer (selecting pops the template back). Route
  `/communications/templates` (declared before the `:broadcastId` detail route).
- **Premium composer** — `compose_broadcast_screen.dart` gains a **priority**
  selector (low/normal/high/emergency, emergency = a stronger accent notice +
  high-priority push), a **delivery channel** selector (push/inbox/both), live
  **character counters** (title 80 / body 500), a **rich live preview** card, and
  **Use template** (renders placeholders with the current recipient/branch/date
  context) + **Save as template** actions.
- **Tests** — `template_renderer_test.dart` (extract/render/unresolved) and
  `broadcast_template_model_test.dart` (round-trip, global-branch convention,
  defaults, placeholders getter). ⚠️ Deploy `firestore:rules` for the new
  `broadcastTemplates` collection.

### Added (2026-06-22 — Communications Center · Phase 2 Commit 1: schema foundation + Broadcast History + Notification Center management)

First commit of the **Communications Center Premium Upgrade** (Phase 2). Adds the
data backbone, the full broadcast **history lifecycle**, and **Notification
Center** management — all additive + back-compatible. ⚠️ The local Flutter SDK is
too old to build here, so freezed `.freezed.dart` files were **hand-edited** to
match the entity changes; run `dart run build_runner build
--delete-conflicting-outputs` to regenerate, then `flutter analyze` + `flutter
test`. `node --check functions/index.js` valid.

- **New enums** — `BroadcastPriority` (low/normal/high/emergency, `isHighDelivery`)
  and `BroadcastChannel` (push/inbox/both, `sendsPush`/`writesInbox`). Orthogonal
  to `BroadcastCategory` (priority = delivery urgency; category = semantic kind).
- **Broadcast schema (`broadcasts/{id}`)** — `BroadcastEntity`/`BroadcastModel`
  gain `priority`, `channel`, `openedCount`, `archivedAt`, `deletedAt` + derived
  getters (`isActive`/`isArchived`/`isDeleted`/`failedCount`). All default safely
  for legacy docs.
- **Broadcast lifecycle (history)** — `BroadcastRemoteDataSource`/`Repository`/
  `BroadcastCubit` gain `setArchived` / `setDeleted` (**field-restricted client
  writes** — see rules) + `repeatNow(sender, source)`. The feed
  (`CommunicationsScreen`) is now a **history** with an **Active / Archived /
  Deleted** filter and per-item actions (Open · Repeat Now · Duplicate · Schedule
  Again *(disabled until the Scheduler phase)* · Archive/Unarchive · Delete/
  Restore) via an overflow menu, with confirmation dialogs for destructive
  actions. `BroadcastCard` shows priority, failed count, and an archived/deleted
  status chip; `BroadcastDetailScreen` shows the full **delivery analytics**
  (recipients · delivered · failed · open rate) + priority/channel + an actions
  menu. **Duplicate** prefills the composer (`ComposeBroadcastScreen(prefill:)`).
- **`sendBroadcast` Cloud Function** — refactored into a reusable
  **`dispatchBroadcast()`** helper (the Scheduler phase reuses it). Reads
  `priority` (high/emergency → high FCM priority) + `channel` (inbox → no push,
  push → no inbox docs, both → both); persists `priority`/`channel`/`openedCount`
  on the doc.
- **Notification Center management** — `NotificationEntity`/`Model` gain
  `archivedAt`/`pinnedAt`. Datasource/repository/cubit gain `delete`,
  `setArchived`, `setPinned`, and **paginated** reads: the feed is now an
  ordered, **growing-window** stream (`watch(uid, {limit})` +
  `NotificationCubit.loadMore()`/`hasMore`) using the new composite index.
  `NotificationsScreen` adds **search**, **type filter chips**
  (All/Unread/Tasks/Broadcasts/System), an **archived view**, **date grouping**
  (Pinned · Today · Yesterday · This week · Earlier), **swipe** (archive / delete)
  + a per-tile actions menu, and **infinite scroll**. Pure helpers in
  `notification_format.dart` (`NotificationFilter`, `notificationMatchesQuery`,
  `groupNotifications`).
- **Rules + index** — `broadcasts` update now permits an admin / owning-branch
  manager / original sender to change **only** `archivedAt`/`deletedAt` (a
  `diff().affectedKeys().hasOnly(...)` field-freeze; content + delivery stats stay
  function-owned). New `broadcastOpens/{id}` guard rules (Phase 2 analytics). New
  composite index `notifications(recipientUid ASC, createdAt DESC)`. New
  collection-name constants. ⚠️ **Deploy** `firebase deploy --only
  firestore:rules,firestore:indexes,functions`.
- **Tests** — `broadcast_lifecycle_test.dart` (priority/channel enums + new-field
  round-trip + `failedCount`/`isActive`), `notification_grouping_test.dart`
  (filter/search/grouping), and extended `notification_model_test.dart`
  (archive/pin round-trip).

### Fixed (2026-06-21 — Communications Center: "UNAUTHENTICATED" on Send)

Sending a broadcast failed with a raw **UNAUTHENTICATED** snackbar — because the
`sendBroadcast` callable wasn't deployed yet, so the gateway rejected the call
before the function code ran (hence the raw gateway code, not the function's own
"please sign in" message). The function stays **2nd-gen** (`firebase-functions/v2`,
the v6 default): it deploys cleanly and the Firebase CLI grants the public invoker
for callable functions automatically. (A brief detour to 1st-gen was reverted — it
hit a "Cannot set CPU on GCF gen 1" deploy error with firebase-functions v6.)

- **Friendlier client error** — `BroadcastRemoteDataSource` now maps a
  `FirebaseFunctionsException` to a user-facing message (full-sentence
  `HttpsError` messages from the function are surfaced verbatim; raw transport
  codes like `UNAUTHENTICATED`/`INTERNAL` become "Couldn’t reach the broadcast
  service. Please try again in a moment.") and logs the real `code`/`message` via
  `dart:developer`. Also threads the returned `deliveredCount` back to the model.
- ⚠️ The function **must be deployed** for Send to work (rules deny client writes
  by design): `firebase deploy --only functions` — requires the **Blaze** plan.
  If a deployed call still returns UNAUTHENTICATED, grant the invoker:
  `gcloud functions add-invoker-policy-binding sendBroadcast --region=us-central1 --member=allUsers`.

### Added (2026-06-21 — Communications Center · Phase 3: Center UI)

The role-gated UI on the Phase 1 + 2 backend (no backend-architecture change
beyond what the UI needed). Built entirely on the shared DROP design system —
strictly monochrome, colour only for an urgent category. `flutter analyze` clean
(0 issues); **101 tests pass** (+6); `node --check functions/index.js` valid.

- **Entry point + route** — a campaign icon in the `RoleScaffold` header (shown
  only to admin + manager) opens the new **`/communications`** area. The router
  gains `_isCommunicationsArea` and a redirect guard that **bounces employees**;
  three `GoRoute`s (`/communications`, `/communications/compose`,
  `/communications/:broadcastId`) with compose declared before the param route.
- **Feed** ([communications_screen.dart](lib/features/communications/presentation/pages/communications_screen.dart))
  — a live list of [BroadcastCard](lib/features/communications/presentation/widgets/broadcast_card.dart)s
  (title · body preview · sender · audience · time · delivery
  `recipientCount`/`deliveredCount`) from the cubit stream, with a **New
  Broadcast** FAB, pull-to-refresh, skeleton + empty/error states. Admin sees all
  branches; a manager sees their branch + all-branches.
- **Compose** ([compose_broadcast_screen.dart](lib/features/communications/presentation/pages/compose_broadcast_screen.dart))
  — a role-gated form: audience chips from
  `BroadcastPermissions.allowedAudiences` (admin: Everyone / Branch / Individual ·
  manager: Branch (own, fixed) / Individual (in-branch); **unauthorized options
  are hidden**), an admin branch dropdown, a **searchable recipient picker**
  (`AppSearchField` + user tiles), category chips (announcement / alert /
  reminder / emergency), a title field and a **multiline** body, and a sticky
  **Send Broadcast** CTA. Send → `BroadcastCubit.send` (client permission guard +
  loading) → success snackbar *"Broadcast sent to N recipients"* → `pop`; errors
  surface via a `BlocListener`.
- **Detail** ([broadcast_detail_screen.dart](lib/features/communications/presentation/pages/broadcast_detail_screen.dart))
  — full message · sender · category · audience · sent date · recipient +
  delivered counts. Resolves the broadcast from the tapped entity (`extra`) with
  a live-feed fallback by id; graceful "unavailable" state otherwise.
- **`BroadcastCategory` enum** ([broadcast_category.dart](lib/core/enums/broadcast_category.dart))
  — announcement / alert / reminder / emergency (pure Dart; icon + colour mapping
  in `communications_format.dart`, which also formats relative/full time and the
  audience label). Tested in
  [broadcast_category_test.dart](test/broadcast_category_test.dart).
- **`deliveredCount` persisted** — the `sendBroadcast` Cloud Function now writes
  `deliveredCount` back to the doc after the multicast (`broadcastRef.update`), so
  the feed/detail can show "delivered M / N". Added to `BroadcastEntity`/`Model`.
- **Compose pickers on the cubit** — `BroadcastCubit.branches()` /
  `branchUsers(branchId)` (repo-direct via `BranchRepository` + `GetUsersByBranch`,
  mirroring `TaskCubit`; DI updated).
- **Shared-widget reuse** — `AppTextField` gains an optional `maxLines`/`minLines`
  (default 1; ignored when obscured) for the body; everything else reuses
  `GlassContainer`, `AppButton`, `AppDropdownField`, `AppSearchField`,
  `UserAvatar`, `AppEmptyState`, `EntranceFade`, `ListSkeleton`, `AppSnackbar`.
- **Tests** — `broadcast_card_test.dart` (headless render: title/body/sender/
  audience/category/delivery + tap), `broadcast_category_test.dart`, and a
  `deliveredCount` round-trip added to `broadcast_model_test.dart`.

### Added (2026-06-21 — Communications Center · Phase 2: notification send engine)

The **push delivery engine** on top of the Phase 1 slice — recipient resolution,
FCM, a Cloud Function send pipeline, and Flutter receive handling. The Phase 1
architecture (entity / repository / use case / cubit) is **preserved**; the send
path now routes through a callable Cloud Function instead of a direct Firestore
write. `flutter analyze` clean (0 issues); **95 tests pass** (+15);
`node --check functions/index.js` valid. New dependency: `cloud_functions`.

- **Recipient resolution / permissions** — pure
  [`broadcast_permissions.dart`](lib/features/communications/domain/broadcast_permissions.dart)
  (`BroadcastPermissions.canSend` / `allowedAudiences` / `validate`): admin →
  all users / any branch / any individual; manager → their **own** branch / an
  individual **inside** it; employee → none. It is the client guard (UI
  affordance + pre-send validation) and is **re-enforced authoritatively** in the
  Cloud Function + `firestore.rules`. Tested in
  [broadcast_permissions_test.dart](test/broadcast_permissions_test.dart).
- **Individual (direct-message) audience** — new `BroadcastAudience.user`.
  `BroadcastEntity`/`Model` gain `targetUserId`, `category`, and `recipientCount`.
  A DM is persisted with a non-branch `branchId` marker (`'__direct__'`) +
  `targetUserId`, so it never surfaces in a branch/all feed query and is readable
  only by the recipient + an admin (read rule updated; feed queries unchanged).
- **FCM token storage → array** — `NotificationService` now keeps the device
  token in **`users/{uid}.fcmTokens`** (`arrayUnion` on register and on
  `onTokenRefresh`, rotating out the stale token; `arrayRemove` on sign-out), so
  multiple devices per user are supported and dead tokens don't accumulate.
  Registered on login / app-start via the existing `AuthCubit` listener. The
  legacy single `fcmToken` is no longer written but is still **read** by the
  function for back-compat.
- **Backend send engine** — new Node.js [`functions/`](functions/) codebase
  (firebase-admin + firebase-functions v2), registered in `firebase.json`. The
  callable **`sendBroadcast`** ([functions/index.js](functions/index.js)):
  validates the sender's permissions, resolves recipients (all / branch /
  individual), **writes** `broadcasts/{id}` (Admin SDK), gathers recipient
  `fcmTokens`, sends via `messaging.sendEachForMulticast`, prunes
  permanently-invalid tokens, and returns the **delivery summary**
  `{ success, recipientCount, deliveredCount, broadcastId }`.
- **Client send path** — `BroadcastRemoteDataSource.sendBroadcast` now invokes
  the callable (`cloud_functions`, `toCallablePayload()`) instead of writing
  Firestore; `BroadcastCubit.send` gained `audience` / `targetUserId` /
  `targetUserBranchId` / `category`, applies the client permission guard, and
  returns the resolved **recipient count**. `firestore.rules` now **deny all
  client writes** to `broadcasts` (the function is the sole writer).
- **Notification payload** — `notification: { title, body }` + `data: { type,
  category, senderId, broadcastId, title, body }` (all strings).
- **Flutter receive handling** — `NotificationService` routes **foreground**
  (`onMessage` → in-app snackbar), **background** (top-level handler in
  `main.dart`; the OS renders the `notification` block), and **tap**
  (`onMessageOpenedApp` + `getInitialMessage` → `onMessageTap`, wired in
  `main.dart` to navigate home + log the `broadcastId` for the future
  deep-link). The router is now created once so the tap handler can navigate.
- ⚠️ **Deploy** `firebase deploy --only functions,firestore:rules` (the function
  needs the **Blaze** plan; `cd functions && npm install` first). iOS push also
  needs an APNs key + the `remote-notification` background mode (console/native,
  not set in this repo).

### Added (2026-06-21 — Communications Center · Phase 1: Broadcast vertical slice)

First slice of the **Communications Center** — a one-way **broadcast**
foundation. **Backend + cubit only** (no UI / routes yet — the compose + feed
screens are a later phase), built as a full Clean-Architecture vertical slice
reusing the established patterns. `flutter analyze` clean (0 issues); **80 tests
pass** (+6 new).

- **`BroadcastEntity`** (freezed, `communications/domain/entities`) — `id ·
  title · message · senderId · senderName · senderRole (UserRole) · audience
  (BroadcastAudience) · branchId · createdAt`, with an `isBranchScoped` getter.
- **`BroadcastAudience` enum** (`core/enums/broadcast_audience.dart`) —
  `allBranches` / `branch`, with `value` / `label` / `fromString` (unknown →
  `allBranches`, the widest, safest default).
- **`BroadcastModel`** (`communications/data/models`) — Firestore
  (de)serialization (`fromMap`/`fromEntity`/`toMap`/`toEntity`/`copyWithId`). An
  all-branches broadcast is stored with an **empty `branchId` sentinel** (never
  null) so a branch member's `whereIn: [myBranch, '']` query stays provably safe
  under the read rule; `createdAt` is a server timestamp. Round-trip + sentinel +
  back-compat covered by `test/broadcast_model_test.dart` (6 cases).
- **`BroadcastRepository` (+Impl)** + **`BroadcastRemoteDataSource` (+Impl)** over
  the new **`broadcasts/{broadcastId}`** collection
  (`AppConstants.broadcastsCollection`). Datasource throws `ServerException`; repo
  → `ServerFailure`; maps `BroadcastModel → BroadcastEntity`. Reads are
  **index-free**: the admin feed is `orderBy('createdAt', descending: true)`; a
  branch member's feed is `where('branchId', whereIn: [selfBranch, ''])` (their
  branch + all-branches in one query), sorted newest-first client-side (a
  just-sent doc with a pending server timestamp pinned on top).
- **`SendBroadcast` use case** (`communications/domain/usecases`) — wraps
  `BroadcastRepository.sendBroadcast`, the canonical one-action-per-write pattern.
- **`BroadcastCubit` (+ `BroadcastState`)** — a **hybrid** cubit (mirrors
  `TaskCubit`): the `SendBroadcast` use case for the write, the repository
  directly for the realtime feed stream. `load({branchId})` subscribes (admin:
  all · branch member: their branch + all-branches), `send(...)` validates +
  posts (the new broadcast surfaces via the same stream — no refetch). Keeps the
  last good feed visible on a transient error; cancels its subscription in
  `close()`. Provided app-wide in `main.dart`; composed in `injection.dart`
  (`broadcastCubit`).
- **Firestore rules** — new `broadcasts/{id}` block: **read** = admin, OR any
  all-branches broadcast (`branchId == ''`, visible to every signed-in user), OR
  a branch member whose branch matches; **create** = the sender themself (admin
  any branch/all-branches; own-branch manager their branch only, never
  all-branches); **update/delete** = admin or the owning-branch manager
  (employees never write broadcasts). ⚠️ Deploy `firestore.rules`.
- **Next phase:** the Communications Center UI (compose + feed screens + role
  entry point/route) and optional notification fan-out on send.

### Added (2026-06-21 — Assign employees while creating a task)

The New/Edit Task form now has an **"Assign to"** picker, so a manager/admin can
assign one or more of the branch's employees *as they create the task* — no more
"create first, then assign". `flutter analyze` clean; 80 tests pass.

- **`createTask` gains `assigneeIds`** (`TaskCubit`) — seeded onto the new
  `TaskEntity` so the assignment persists in the same create write; edit threads
  `assigneeIds` through `editTask`'s `copyWith`.
- **`_AssigneePicker` + `_EmployeeChip`** in `task_action_sheets.dart` — a compact
  selectable-chip team picker (avatar · name · toggle, with "Whole team" / "Clear
  all") loaded via `TaskCubit.branchEmployees(branchId)`. Manager: branch fixed;
  admin: loads the picked branch and **clears the selection when the branch
  changes**. Seeded from the task's existing assignees when editing. The standalone
  `_AssignSheet` (quick reassign from a card) is unchanged.

### Added / Changed (2026-06-21 — Branch Operations cockpit · steps 2–3: cubit + screens)

Built the cockpit on the step-1 schema + domain. The task-centric task list is
replaced by an **operations-centric** surface (Admin dashboard → Branch
Operations → Employee details → Task details). Strictly monochrome, reusing the
existing component library. **74 tests pass** (+3 widget); operations/task/core
scope `flutter analyze` clean.

- **`BranchOperationsCubit` + `BranchOperationsState`** (`operations/presentation/
  cubit/`) — read/derive only: subscribes `TaskRepository.watchTasksByBranch`,
  one-shot `GetUsersByBranch` + `ScheduleRepository.getSchedule`, and emits
  `computeBranchWorkload(...)`. `setFilter` re-derives from the cached snapshot
  (no refetch). Repo-direct (reuses the auth `GetUsersByBranch` use case like
  `ScheduleCubit`); wired in `injection.dart` + `main.dart`. **Writes stay in
  `TaskCubit`** — both watch the same branch stream, so a create/assign/review
  propagates to the cockpit live.
- **`BranchOperationsScreen`** (the cockpit) — summary header (Active · Overdue ·
  Pending review · Staff active), an instant `[All][Morning][Night]` shift toggle,
  overload-first `WorkloadCard` list, a New-Task FAB (`startNewTaskFlow`, branch
  fixed), and an "All tasks" action. `WorkloadCard` extracted as a reusable widget
  (avatar · role · shift badge · 4-up metric strip · current-task preview · error
  border when `needsAttention`), widget-tested in `test/workload_card_test.dart`.
- **`ManagerOperationsScreen`** — thin wrapper resolving the manager's own branch;
  it is now the `/manager/tasks` page (the Operations tab).
- **`EmployeeDetailScreen`** — the task-centric drill: one employee's tasks grouped
  by status (Rework · In progress · Pending · Submitted · Completed), each a
  `ManagerTaskCard` opening the existing `TaskDetailsScreen`.
- **`BranchTaskListScreen`** (public) — extracted from the admin overview's private
  drill; the full per-branch task list (incl. **unassigned** tasks), reached via the
  cockpit "All tasks".
- **Routing / retirement** — `app_router` repoints `/manager/tasks` to
  `ManagerOperationsScreen`; the admin branch-overview drill (`_openBranch`) now
  opens `BranchOperationsScreen`. The former `BranchTasksScreen` and
  `ManagerTasksView` (flat manager task list) are **deleted** — superseded by the
  cockpit + `BranchTaskListScreen`.

### Added (2026-06-21 — Branch Operations redesign · step 1: shift tag + workload aggregation)

First slice of the task-centric → **operations-centric** redesign (the Branch
Operations cockpit: Admin dashboard → Branch Operations → Employee details → Task
details; tasks live *inside* operations, no standalone Task Management screen).
**Domain + schema only** — no cubit / screen / route yet (steps 2–3). `flutter
analyze` clean (0 issues); **71 tests pass** (+12 new).

- **`tasks.shift`** — new optional operational shift tag on `TaskEntity`
  (nullable `ScheduleShift`; **null = "any"**, not shift-specific), serialized in
  `TaskModel` (`'shift'` ↔ new `ScheduleShift.fromStringOrNull`, which **preserves
  absence** instead of the lossy `fromString` morning-default). Back-compat:
  missing / unknown → null. Supersedes the unused legacy `assignedShiftId`.
  Freezed re-run. Tested in `test/task_model_shift_test.dart`.
- **New `operations` feature (domain)** — pure aggregation behind the future
  cockpit: `ShiftFilter` (all / morning / night, with `matchesTask` /
  `matchesEmployee`), `EmployeeWorkload` (per-card view model: active / overdue /
  submitted / completedToday + current task + today's shift), `BranchSummary` (the
  four header numbers), and `computeBranchWorkload(...)` → `BranchWorkload`, which
  joins the branch task stream × `getUsersByBranch` × today's `weekly_schedule`
  under a shift lens and sorts employees **overload-first**. Deterministic
  (`day` / `now` injectable), mirroring `computeEmployeeMetrics`. Tested in
  `test/branch_workload_test.dart` (12 cases: bucketing, shift scoping, sort
  order, current-task selection, completed-today, no-schedule fallback).
- **Next:** `BranchOperationsCubit` + state (step 2), then the cockpit screen +
  routes `/admin/branch/:branchId` & employee drill-down, and retiring the
  standalone task screens as destinations (step 3).

### Fixed + Added (2026-06-21 — submission loading UX + premium status animations)

`flutter analyze` clean (0 issues); 59 tests pass.

- **Fixed: video submit looked frozen.** Root cause (traced, not guessed): the
  submit pipeline (`completeAndSubmit` → parallel `putFile` → `_updateTask`) is
  fully async / non-blocking, but **no loading state was surfaced** — the submit
  button stayed enabled and the screen rendered nothing for the `busy` flag, so a
  multi-second video upload appeared frozen. (Not a main-isolate block; thumbnail
  generation is display-time, not in the submit path.)
- **Submission state moved to the cubit.** `TaskState.loaded` now carries
  `isSubmitting` + `submissionProgress` (`SubmissionProgress` in
  `presentation/submission_progress.dart`), preserved on every emit (incl. the
  Firestore stream) so the **whole Task Details screen** reacts and progress
  survives rebuilds / disposal. Progress emits are throttled to whole-percent
  changes.
- **Single, state-driven submission overlay** (`submission_loading_overlay.dart`)
  rendered by the screen in a Stack when `isSubmitting`: stages **Preparing media
  → Uploading attachments → Finalizing**, a **real progress bar + percentage +
  transferred/total MB** (aggregated from each upload's Storage `snapshotEvents`).
  `PopScope` blocks back during submit. Only `completeAndSubmit` sets
  `isSubmitting` (approve/reject/start use `busy`) → exactly one overlay ever
  exists (audited across submit / rework / review-approval flows).
- **Reverted server-side video posters.** Persistent poster uploads
  (`TaskAttachment.thumbnailUrl`, submit-time generation) were removed — not
  justified for low video volume. Videos use **local generation + in-memory LRU
  caching** (`VideoThumbnailImage`) at view time. `durationMs` is still captured
  at pick. (No `firestore`/storage change.)
- **Premium status animations** (monochrome-preserving) on the task detail status
  header — a soft status glow with an **amber pulse for In Review** and static
  **green** (Approved) / **red** (Rework) glow + faint tint; the status badge
  **cross-fades + scales** on change; timeline event cards **stagger-fade in**
  (reused `EntranceFade` / `staggerDelay`).

### Changed (2026-06-21 — Submission Details surface: lightweight timeline + deep review sheet)

Split the overloaded task timeline into a scan layer and a deep review layer.
`flutter analyze` clean (0 issues); 54 tests pass (+`submission_resolution_test.dart`).

- **Timeline = summary only.** `_EventCard` now shows status · actor · timestamp ·
  attachment summary ("2 photos · 1 video") · a 2-line truncated note preview —
  no inline media. Submission-related cards (`completed` / `waitingReview`) are
  tappable (chevron affordance).
- **New `SubmissionDetailsSheet`** (`widgets/submission_details_sheet.dart`) — a
  large iOS-style modal bottom sheet (~90% height, no full-screen route) that is
  the full review surface: header (task + "Completed by X · date"), **Employee
  Response** (full note), **Attachments** (2-col gallery), **Manager Feedback**
  (per-cycle decision + note), and a sticky **Approve / Request Rework** bar when
  the submission is pending (read-only otherwise).
- **Submission resolution** — pure `resolveSubmission(task, index)` (in
  `attachment_format.dart`) maps a tapped event to its cycle's content event and
  the decision that followed it; correctly handles rework loops (each cycle →
  its own media + feedback). Tested in `submission_resolution_test.dart`.
- **`AttachmentGallery` gains a grid mode** (`columns`, `showDuration`) reused by
  the sheet — 2-column cells, video tiles show a duration pill. Compact wrap mode
  unchanged for other call sites. Media rendering (`AttachmentGallery` +
  `AttachmentViewer` + `VideoThumbnailImage`) is reused, not duplicated.
- **Video duration** — captured best-effort at pick time (`video_player` reads
  the local file), threaded through the upload chain, stored on
  `TaskAttachment.durationMs`, and rendered as `mm:ss` (`formatVideoDuration`).
  Legacy videos without a stored duration simply omit the pill.

### Fixed (2026-06-21 — task-load regression) + Added (real video thumbnails)

- **Fixed: "Failed to load tasks" for employees & managers.** Root cause: the
  newest-first follow-up added `orderBy('createdAt', descending: true)` to the
  **filtered** task queries — `where('assigneeIds', arrayContains: uid)` (employee)
  and `where('branchId', …)` (manager). A filter + `orderBy` on a different field
  needs a **composite index**, which wasn't deployed, so Firestore threw
  `failed-precondition` on the snapshot stream; `TaskCubit`'s `onError` swallowed
  the exception and showed the generic message. **Fix:** removed server-side
  `orderBy` from those two queries (back to the automatic single-field
  array/equality index) and rely on the existing client-side
  `sortTasksNewestFirst`; the admin query keeps its index-free `orderBy`. Emptied
  `firestore.indexes.json` (no composite index needed) — **the
  `firebase deploy --only firestore:indexes` step is no longer required.**
- **Fixed: swallowed stream errors.** `TaskCubit` now logs the real error + stack
  trace (`dart:developer`) on stream failure, so the exact exception is visible
  instead of only a generic UI message.
- **Added: real video thumbnails.** New `VideoThumbnailImage` (backed by
  `video_thumbnail`) extracts an actual poster frame from each video (network URL
  or local file), shown in the attachment gallery and the submission picker with
  the play overlay on top. Frames are generated at 256px/JPEG-q60 and memoised in
  a bounded LRU cache (≈60 entries) keyed by source; concurrent requests share
  one future; failures drop from the cache (retryable) and fall back to a
  film-glyph tile. New dependency: `video_thumbnail`.

### Added (2026-06-20 — Task submission media upgrade: multiple images & videos)

Replaced the single proof image with multiple images + videos, attached to **task
events** (not the task globally). `flutter analyze` clean (0 issues); 48 tests
pass (+9 new). New dependency: `video_player`.

- **Model** — new `TaskAttachment` entity (`id · url · type · uploadedAt ·
  uploadedBy · uploadedByName`) + `AttachmentType` enum (image/video).
  `ActivityEntry` gains `List<TaskAttachment> attachments`, so each submission /
  rework cycle keeps its own evidence. `TaskModel` (de)serializes attachments
  inside `activityLog`.
- **Storage** — uploads go to `tasks/{taskId}/attachments/{id}.<ext>` with a
  unique id per file (never overwritten); `storage.rules` widened from
  `{file}` to `{allPaths=**}` to cover the nested folder. Content-type inferred
  from extension.
- **Submission** — `TaskCubit.completeAndSubmit` now takes
  `List<PickedAttachment>`, uploads each before the status write (failure aborts
  and keeps the selection), and attaches the result to the submission event.
  First image mirrors to the legacy `proofImageUrl` for back-compat. New use case
  `UploadTaskAttachment` replaces `UploadTaskProof`.
- **Picker** — `AttachmentPickerField`: multi-photo, video, and camera capture
  (photo / record) with validation via `AttachmentLimits` (≤6 photos, ≤3 videos,
  ≤50 MB each). New iOS `NSMicrophoneUsageDescription`.
- **Viewing** — `AttachmentGallery` (image grid + video tiles with play overlay)
  on the timeline event cards, "Submitted work", and the review sheet; tapping
  opens fullscreen `showAttachmentViewer` — swipeable, pinch-zoom images
  (`InteractiveViewer`), inline `video_player`, each captioned "Uploaded by X ·
  20 Jun 2026 • 4:32 PM". Helpers in `attachment_format.dart` resolve per-event
  media with legacy-proof back-compat (no double-render).
- **Uploads parallelized** — `completeAndSubmit` uploads attachments with
  `Future.wait` (order preserved) instead of sequentially, so multiple photos no
  longer queue behind each other.
- **Pre-upload optimization** — photos are resized + recompressed by image_picker
  (`maxWidth 1600`, `quality 70`, in `AttachmentLimits`) before upload, cutting
  upload time + Storage cost. Video transcoding is deferred (bounded by the
  3-min duration cap + size limit rather than a heavy native codec dependency).
- **Separate size limits** — images ≤15 MB, videos ≤200 MB (was a shared 50 MB);
  `AttachmentLimits.maxBytesFor(type)` / `maxMbFor(type)`, enforced per type in
  the picker.
- **Newest-first task lists** — admin query uses Firestore
  `orderBy('createdAt', descending: true)` (index-free); the filtered branch +
  employee queries are ordered by a pure `sortTasksNewestFirst`
  (`domain/task_ordering.dart`) in the repository, which also keeps a just-created
  task (pending server timestamp → locally null) pinned to the top. *(Note: an
  earlier revision added server-side `orderBy` to the filtered queries too; that
  required an undeployed composite index and broke loading — reverted in the
  2026-06-21 fix above.)*
- **Tests** — `task_attachment_test.dart` (model round-trip + format helpers) and
  `task_ordering_test.dart` (newest-first incl. pending-timestamp on top).

⚠️ Deploy `storage.rules` (`firebase deploy --only storage`). Video playback needs
an on-device check.

### Changed (2026-06-20 — Schedule assignment-grid redesign, no staffing quotas)

Re-architected the manager/admin schedule from first principles — from vertical
day cards to a weekly **assignment grid** (an operations-control surface). The
schedule represents **assignments, not staffing quotas** — no required-headcount
or understaffed-vs-target model; the admin assigns by operational judgment.
`flutter analyze` clean (0 issues); 39 tests pass.

- **New mental model** — `ScheduleGrid`: days are columns (Sun→Sat), shifts are
  rows (Morning/Night). Each `ShiftCell` shows **how many employees are assigned**
  — a monochrome density tint (more people = brighter), a muted "Empty" state, a
  white ring on today, and an orphan flag. Horizontally scrollable with a
  **pinned shift rail + day headers** (mobile constraint).
- **No quotas** — removed the `Staffing` domain model, `StaffingHealth`,
  `StaffingBadge`, and all required/target/understaffed/critical concepts. Cells
  and sheets show plain assignment counts; the only surfaced signals are **empty**
  (a neutral fact) and **broken reference** (a data-integrity issue).
- **Cell interaction** — tapping a cell opens `ShiftDetailsSheet`: a neutral
  "N assigned" / "No one assigned yet", assigned employees as premium
  `EmployeeRow`s (avatar · name · role · status dot) with double-booking
  conflicts surfaced, plus assign / remove and broken-slot resolve — updates live.
- **Swaps** — removed the separate "Swap Requests" tab; swaps now surface as a
  floating `SwapAlertCard` inside the grid that opens a queue modal (reusing
  `SwapListView`). Swap cards now show the **submitted time** alongside
  requester · branch · shift · reason.
- **Broken assignments** — `BrokenAssignmentBanner` → resolve sheet with
  **Remove / Reassign** per slot, labelled `Day · Shift` + "Former employee"
  (user-friendly; raw uids / "Unknown member" debug text gone).
- **Screens** — `BranchScheduleScreen` (manager) and `ScheduleManagementScreen`
  (admin) are now a single operations surface (DefaultTabController/TabBar gone);
  the grid self-refreshes when a swap settles.
- **Reusable widgets** (engineering req.) — `ScheduleGrid`, `ShiftCell`,
  `EmployeeRow`, `ShiftDetailsSheet`, `SwapAlertCard`, `BrokenAssignmentBanner`,
  shared `showEmployeePicker` + `SheetHandle`; presentation kept free of
  business-rule assumptions.
- **Tests** — headless `schedule_grid_test.dart` (renders assigned counts,
  excludes/flags orphans, Empty state, no uid leak, cell-tap routing, shift
  filter).

### Changed (2026-06-20 — Premium UI redesign: Branch Schedule, Admin Home, Task timeline)

A visual/product-refinement pass — monochrome, token-driven, no schema/logic change.
`flutter analyze` clean (0 issues); 35 tests pass.

- **Branch Schedule** (`manager_schedule_view.dart`) — denser, premium rebuild. The
  oversized day cards are replaced by a compact **calendar date-rail + two shift
  lanes** layout (`_dateRail` / `_shiftLane`): a fixed date tile (today fills
  white), a hairline divider, then Morning/Night lanes each with an icon, label,
  live count, a round **+** add affordance, and refined avatar chips (full-radius,
  circular remove target). Padding tightened (lg→md) so more of the week fits on
  screen. Broken-reference chips keep their amber treatment.
- **Admin Home** (`admin_dashboard_screen.dart`) — premium tightening. Greeting
  collapsed to a single line ("Good morning, Ziad", `h1`) instead of a stacked
  `h2`+`display`; section gaps reduced (xxl→xl) to cut dead space; the **hero** now
  places the big metric **beside** its title+summary (one block) with the daily
  throughput moved to the eyebrow row — less vertical sprawl, clearer hierarchy.
- **Task timeline** (`task_details_screen.dart`) — the plain `TimelineTile` rows
  are replaced by rich **event cards** strung on a spine: a status badge (icon +
  colour from `activityFormat`, new `activityIcon`), timestamp, **actor with avatar
  + role**, a quoted note block (accent left-border), and an **attachment
  thumbnail** (the submitted proof surfaces on the submission event).

### Fixed (2026-06-20 — Product/UI verification pass: visibility, orphans, admin swap reachability)

A product-engineer verification pass driven by real-UI review — every change here
fixes something that was **wired in code but broken or unreachable in the actual
flow**. `flutter analyze` clean (0 issues); **35 tests pass** (25 + 10 new,
including headless **widget** tests that render the affected UI).

- **Admin "Pending Actions" was invisible.** The whole section was gated behind
  `if (pendingActions > 0)`, so on empty/zero data it silently vanished — looking
  like the feature wasn't there. It's now **always rendered**, with an explicit
  "You're all caught up" state. The panel was also **extracted to a public,
  testable widget** ([pending_actions.dart](lib/features/admin/presentation/widgets/pending_actions.dart))
  and covered by a widget test that actually pumps it
  ([pending_actions_widget_test.dart](test/pending_actions_widget_test.dart)).
- **Branch Schedule "Unknown" employees → explicit broken-reference handling.**
  Root cause: `getUsersByBranch` returns only users whose **current** `branchId`
  matches, so a uid left in a schedule slot after its owner was moved to another
  branch / removed resolves to a silent `"Unknown"`. Now those orphaned
  assignments are **detected** (`isOrphanAssignment`), **surfaced explicitly** (a
  top-of-week warning banner + a distinct warning chip — "Unknown member · <uid>",
  never a fake name), and **resolvable** (tap → confirm → remove the stale entry,
  then reassign a current employee via "Add"). The employee "Working with" list
  already dropped orphans (no fake name leaked there).
- **Admin could not see or approve swap requests at all.** `ScheduleManagementScreen`
  had no swap tab — only the manager screen did. It's now a **two-tab screen**
  (Schedule · Swap Requests) with an **all-branches** queue
  (`ShiftSwapCubit.loadAll()` + `SwapScope.all` + `getAllSwaps`), each card
  labelled with its **branch** (`showBranch`, resolved via `BranchCubit`), plus the
  same auto-refresh-on-approval `BlocListener` the manager screen has. The Pending
  Actions "Swap Requests" row now lands somewhere the admin can actually act.
- **Employee was offered "Swap" on past shifts.** The week rows showed an active
  Swap button on every non-today, non-off day — including days already past this
  week. Past/in-progress slots now show a muted "Past" label instead, keeping the
  offered action in lock-step with `SwapEligibility` (the send-time + cubit + rules
  gates from the previous entry remain as the backstop).

### Added / Changed (2026-06-20 — Shift-swap hardening + Admin Pending Actions)

First slice of the Operations refinement spec — **shift-swap correctness** (spec
§2) and **admin operational visibility** (spec §1). No schema/entity/route change;
no codegen. `flutter analyze` clean (**0 issues**); **25 tests pass** (17 + 8 new).

**§2 — "Future shifts only" swap validation (the spec's critical rule), enforced
in three layers:**
- **Domain (source of truth):** new pure helper
  [`SwapEligibility`](lib/features/schedule/domain/swap_eligibility.dart) —
  `slotStart(weekStart, day, shift)` derives a slot's concrete start instant
  (week's Sunday + day offset + shift start: morning 08:30 / night 16:30, mirroring
  `ScheduleShift.timeRange`) and `isRequestable(...)` is true only when that start
  is **strictly in the future**. Unit-tested
  ([swap_eligibility_test.dart](test/swap_eligibility_test.dart), 8 cases:
  yesterday → invalid, today-already-started → invalid, today-later/tomorrow/next-week
  → valid, exact-start boundary → invalid).
- **Cubit (authoritative client gate):** `ShiftSwapCubit.requestSwap` now rejects a
  past/in-progress slot with a clear error (`SwapEligibility.pastShiftMessage`)
  before any write.
- **UI (immediate feedback):** the Request-Swap sheet (`swap_view.dart`) validates
  on send and shows the same message.
- **Firestore rules (server backstop):** `shift_swaps` **create** now requires
  `swapSlotInFuture(request.resource.data)` — the rule recomputes the slot start
  from `weekStart`/`day`/`shift` (via `swapDayOffset` + `swapShiftMinutes` +
  `duration.value`) and requires it `> request.time`. ⚠️ Needs deploy.

**§1 — Admin Home "Pending Actions" (replaces "Recent activity"):** the low-value
activity feed on `admin_dashboard_screen.dart` is gone; in its place a consolidated,
**actionable** queue right under the hero — Swap Requests · Employee Approvals ·
Tasks Waiting Review · Overdue Tasks. Each non-empty queue is one tappable row
(`_ActionRow`) that jumps straight to where it's resolved; the section header shows
the total ("Pending Actions · N awaiting you"); empty queues are hidden.

**Admin swap visibility plumbing (spec §2 — "Admin must see swap requests"):** new
`ScheduleRepository.getAllSwaps()` (+ datasource + impl) — every branch's swaps —
and `ShiftSwapCubit.pendingSwaps()`, a one-shot fetch of all **open** (non-resolved)
swaps that powers the Pending Actions count without disturbing the cubit's
list state (mirrors `AdminUsersCubit.pendingUsers`).

### Changed (2026-06-19 — Admin command-center redesign + reusable component library)

A premium-operations pass on the **Admin** experience (enterprise / Apple-inspired
dark UI), built on a new shared component library so repeated card patterns stop
being copy-pasted. **Strictly monochrome** — the existing `AppColors` tokens were
kept (owner chose not to shift the palette); colour stays reserved for status.
No schema / route / entity / Firestore-rule changes; no codegen (no freezed
touched). `flutter analyze` clean (**0 issues**); 17 tests pass (12 + 5 new).

**New reusable components (`lib/core/widgets/`):**
- **`GlassContainer`** — the one shared premium surface (elevated→surface
  gradient, hairline border, soft depth shadow, large radius) with built-in
  press-scale + hover feedback and a `highlight`/`accent` mode. `HeroStatCard`
  and `AdminUserCard` were **refactored onto it** (dedup — the gradient/border/
  shadow `BoxDecoration` lived in 4+ places).
- **`DashboardMetricCard`** — icon chip · value · label · optional trend/status
  footnote (built on `GlassContainer`).
- **`ActionCard`** — premium quick-action tile (icon chip + title + optional
  subtitle), replacing boring `ListTile`s.
- **`AdminSectionHeader`** — prominent section header (title + optional subtitle +
  optional trailing action), distinct from the micro-label `SectionHeader`.
- **`TimelineTile`** — generic vertical-timeline row (dot · spine · title ·
  timestamp · actor · note), rendered purely from data. The Task Details activity
  timeline (`_ActivityTimeline`/`_TimelineRow`) was rebuilt on it, and the admin
  recent-activity feed reuses it.
- **`TaskStatusChip`** requirement is satisfied by the existing
  `StatusBadge.task(status)` factory (no duplicate widget created).

**New shared formatting (`lib/features/task/presentation/activity_format.dart`):**
`activityTitle(status)` / `activityColor(status)` / `relativeTime(dt)` — the
status→label/colour + relative-time mapping, previously private to Task Details,
now shared with the admin activity feed.

**Admin Home → command center** (`admin_dashboard_screen.dart`, rebuilt):
time-aware **greeting header** (salutation · date · branch/employee scope) → a
focal **hero card** that surfaces the most urgent insight (pending approvals →
tasks awaiting review → overdue → all-clear) with a metric, summary, today's
throughput progress bar and a CTA → a 2×2 **metrics grid**
(`DashboardMetricCard`: Branches · Employees · Managers · Active tasks, with
trend lines) → **quick actions** (`ActionCard`: Add Branch · Add Manager · Assign
Task · Approve Employee) → a **pending-approvals** preview (read-only, via the new
`AdminUsersCubit.pendingUsers()`) → a **recent-activity feed** (`TimelineTile`,
derived from the live task stream's `activityLog`) → a **Manage** grid (Schedules
· Employees · Analytics · Settings). Reads three live sources: `StatisticsCubit`,
the `TaskCubit` all-branches stream, and pending users. Every module stays
reachable in 1–2 taps.

**Employee Management page** (`employee_management_screen.dart`): the generic
`AdminUserCard` was replaced by a new **`EmployeeCard`** (avatar · name · role ·
branch · active/inactive badge) carrying a **performance metric strip**
(Completed · Pending · Completion rate · Late). Metrics are derived from the live
admin task stream via the new pure helper **`computeEmployeeMetrics`**
(`employee_metrics.dart`) — no new backend query/schema. `EmployeeMetrics` is unit
tested ([employee_metrics_test.dart](test/employee_metrics_test.dart), 5 cases).

**Task timeline (data architecture note):** the spec's recommended event-based
timeline (`TaskEvent`/`TaskEventType`) is **already implemented** as
`TaskEntity.activityLog` (`List<ActivityEntry>{status, actorId, actorName, at,
note}`); the timeline renders dynamically from that list (supports missing /
optional steps and rework loops — no hardcoded sequence). This pass extracted the
reusable `TimelineTile` and shared the formatting, rather than re-modelling.

### Changed (2026-06-19 — Employee schedule premium redesign)

**`my_schedule_screen.dart` fully rebuilt** to a premium, animated schedule view:

- **Staggered entrance animations:** `_MyWeekTab` is now a `StatefulWidget` with a
  900 ms `AnimationController`; each section fades in + slides up with its own
  `Interval`-based `CurvedAnimation` (greeting → today card → week header → week
  rows). Animation replays on every refresh so the user always feels the update.
- **Greeting header:** time-aware salutation ("Good morning/afternoon/evening,
  [FirstName] 👋") + formatted date (e.g. "Friday, 20 Jun").
- **Today hero card:** prominent card with a rounded-square shift icon box, "TODAY"
  pill badge, large shift-name headline, time range line with a `_CountdownRow`
  ("In Xm" pill visible when shift starts within the next 2 hours), two-column
  **Manager / Working with** layout (avatar + name + role label, `_TeamAvatars`
  avatar stack with first-name summary text), and a tappable "View Shift Details"
  divider row that opens `_ShiftDetailsSheet` — a bottom sheet listing the full
  team for that shift.
- **Week rows (all 7 days):** every day of the week is now shown (no more
  skipping off-days). Each row has `_DayChip` (3-letter day + date number; today
  gets white filled square + dark text), a circular shift icon, shift name + time
  range, and a Swap button / "Today" filled pill / "—" for off days.
- **App bar:** notification bell icon added alongside the refresh icon.
- No data-layer changes — uses existing `ScheduleCubit` + `ShiftSwapCubit`.
  `flutter analyze` clean (2 pre-existing infos).

### Fixed (2026-06-19 — Task proof upload + admin task experience)

**Rebrand:** the product is now **DROP — Operations Management System**. All
user-facing names (app label/display name, web manifest + title, `appName`,
README) and in-code product references say **DROP**; the Dart package identifier
stays `fbro` for build stability (documented).

**P1 — Proof photo upload (critical fix).** Employee proof images weren't
reaching reviewers. Root cause was twofold: (a) `completeAndSubmit` caught any
upload error and submitted the task **anyway**, permanently dropping the photo,
while (b) the catch-all message always blamed "internet connection," masking the
real cause (Storage rules not deployed / Storage not enabled). Now proof is
uploaded **before** the status write — a failure aborts the transition (task
stays `started`, photo retained for retry), the cubit returns success so the UI
only leaves on success, the employee can clear/replace the photo, and the
datasource maps Storage error codes to honest, actionable messages (+60s upload
timeout). **Infra still required:** deploy `storage.rules` and ensure Firebase
Storage is enabled, or every upload will keep failing regardless of app code.

**P2 — Admin task experience.** `TaskManagementScreen` is now
`AdminTaskOverviewScreen`: a **branch-based overview** (Active / Pending Review /
Overdue / Completion Rate per branch, sorted so branches needing attention come
first, plus a company summary strip) with a per-branch drill-down to the full
task list. Replaces the flat all-branches list that didn't scale. **Fixed
`setState() callback returned a Future`** — `_load()` was using `setState(() =>`
with an async method, making the lambda return a `Future`; fixed by extracting the
Future first then updating state synchronously in a block body.

**P4 — Architecture cleanup.** Removed dead code: `ChangeTaskStatus` /
`ReviewTask` use-case files, the `updateStatus` / `reviewTask` repository +
datasource chains, and the unused `completeTask` cubit method. Extracted a shared
`ManagerTaskCard` widget and `startNewTaskFlow` helper so the manager view and
admin overview/drill-down render task cards and the New-Task flow from one source
of truth. `flutter analyze` clean (0 issues — **fixed the 2 pre-existing infos**:
`prefer_initializing_formals` in `AuthCubit` and `ProfileCubit` constructor
parameters now use initializing formals (`this._signInWithEmail`,
`this._updateProfile`) instead of the intermediate named-parameter pattern).

### Changed (2026-06-18 — Employee Home Screen Redesign v2)

Full rebuild of `employee_home_screen.dart` into a personal operations command
center. The screen is a single live dashboard driven by the **TaskCubit task
list** (ground truth) for everything task-related, with the `StatisticsCubit`
used only for today's shift. No new files, routes, cubits, models, or schema —
presentation only.

- **Time-aware greeting** — date pill ("WED, 18 JUN") + "Good morning, [First Name]" (display type), animated entrance.
- **Animated "Today" hero card** — a sweeping **circular progress ring** (`_ProgressRing` + `_RingPainter` CustomPaint) showing *finished / total* with a count-up centre, paired with today's shift (Morning/Night/Off + "Next:" line) and a live summary pill ("4 to do · 1 in review" / "All caught up").
- **Count-up stat strip** — 4 chips (To do / Active / In review / Done) computed from the live task list via a `_Counts` helper + `TweenAnimationBuilder`. **Fixes a latent bug:** the old strip read `stats.activeTasks`, which `employeeStats` never populates, so "In progress" was always 0; counts now come from the task list.
- **Actionable task cards** — each card has a footer action so the employee can work **without leaving Home**: pending → **Start task** (primary, calls `TaskCubit.startTask` inline), started → **Continue** (opens Details), rejected → **View feedback**, in-review → muted "Awaiting review". Body tap opens `TaskDetailsScreen` (fade + slide). Cards show title, description, animated checklist progress, and meta chips (relative due — "Due today"/"Overdue"/"Due in 2d", "From [manager]" resolved via the cubit directory, and the rejection note).
- **Sections** — Needs attention (rejected) · Submitted (in review) · Up next (active, sorted started-first then soonest deadline, top 3 + "View N more"), plus an "Open all tasks" row that navigates to the Tasks tab (`RouteNames.tasksForRole`).
- **Polish** — `_Pressable` scale-on-press feedback on every tappable surface; staggered `EntranceFade`; an error `BlocListener` (guarded to Home being the visible route); a last-good-snapshot cache so inline-action transitions never blank the list; combined `_HomeShimmer` loading state; refined empty / all-caught-up states. Stays strictly monochrome (colour only for status).

`flutter analyze` clean (0 errors, 0 warnings; 2 pre-existing infos unchanged).

### Fixed (2026-06-18 — Proof submission error visibility)
- **Upload error now shown on the right screen.** `_CompleteButton._submit()` was fire-and-forget: it launched `completeAndSubmit` and immediately popped the screen. If the Storage upload failed, the warning snackbar fired on `MyTasksScreen` (the previous screen) after the user had already navigated away — easy to miss. `_submit()` is now `async` and `await`s `completeAndSubmit` before calling `pop()`. The upload-failure snackbar now appears while the user is still looking at the task details screen.
- **User-friendly upload error messages.** Upload failure messages no longer reference internal infrastructure ("Enable Firebase Storage and deploy storage.rules"). Both `completeTask` and `completeAndSubmit` now show: `"Photo upload failed — check your internet connection and try again."` The root cause (Storage not enabled) is still documented in `CURRENT_STATE.md` for the operator.

`flutter analyze` clean (0 errors, 0 warnings; 2 pre-existing infos unchanged).

### Fixed (2026-06-18 — Task Workflow Architecture: single-write state machine)

**Root cause of duplicate activity entries, status regressions, and unreliable checklist.**

Every status-transition method (`startTask`, `submitForReview`, `approveTask`, `rejectTask`) was doing two conflicting Firestore writes:

1. **Write 1 (thin)** — `_changeTaskStatus` / `_reviewTask`: sets `status=newStatus` only, via `merge:true`
2. **Write 2 (fat)** — `_appendActivity` → `_updateTask`: writes the **entire** task map from the *original* entity (which still carries `status=oldStatus`), via `merge:true`, reverting Write 1

Because `merge:true` overwrites every specified field, Write 2 always reverted the status back to the pre-transition value. The Firestore real-time stream fired after each write, so the UI would bounce: `pending → started → pending`. This caused:
- Employees seeing "Start Task" again after tapping it → tapping again → **duplicate "Started" activity entries**
- Checklist becoming non-interactive (gated on `status == started`) because status bounced back to `pending`
- Managers seeing the review block re-appear after approving/rejecting

**Fix:** Replaced the two-write pattern with a **single `_updateTask` call** in each method that atomically writes the new `status`, any audit fields (`approvedBy`/`rejectedBy`/`approvedAt`/`rejectedAt`/`reviewNotes`), and the new `ActivityEntry`, all in one Firestore document write. No more race condition.

- `startTask` — single write: `status=started` + activity entry
- `submitForReview` — single write: `status=waitingReview` + activity entry  
- `approveTask` — single write: `status=approved` + audit fields + activity entry + spawn recurrence
- `rejectTask` — single write: `status=rejected` + audit fields + activity entry

Removed `_appendActivity` helper (was the source of the double-write).
Removed `ChangeTaskStatus` and `ReviewTask` use cases from `TaskCubit` (no longer needed; use case files kept as dormant domain objects).
Updated `_canTransition` to include `started → waitingReview` (the path `completeAndSubmit` uses), making the state machine complete.
DI wiring (`injection.dart`) updated to match the removed cubit dependencies.

**Second pass — complete single-write architecture with audit timestamps:**

Added `startedAt` and `submittedAt` fields to `TaskEntity` (freezed) and `TaskModel` (serialization + Firestore Timestamp ↔ DateTime). Completing the per-transition audit timestamp set: every status transition now writes its own named timestamp in the same atomic document update — `startedAt` (`startTask`), `submittedAt` (`submitForReview` and `completeAndSubmit`), `approvedAt` (`approveTask`), `rejectedAt` (`rejectTask`).

**Full audit result — every task action verified clean:**

| Action | Writes | Stale-data risk |
|---|---|---|
| `createTask` | 1 Firestore create | none |
| `editTask` | 1 Firestore update | none |
| `deleteTask` | 1 Firestore delete | none |
| `assignEmployees` | 1 thin merge (no status change) | none |
| `startTask` | 1 atomic update (status + startedAt + activity) | none |
| `completeTask` | 1 atomic update (status + notes/proof + activity) | none |
| `submitForReview` | 1 atomic update (status + submittedAt + activity) | none |
| `completeAndSubmit` | 1 Storage upload + 1 atomic update (status + submittedAt + activity) | none |
| `approveTask` | 1 atomic update (status + approvedAt + audit + activity) | none |
| `rejectTask` | 1 atomic update (status + rejectedAt + audit + activity) | none |
| `toggleChecklistItem` | 1 atomic update (checklist only, no status change) | none |

Freezed codegen re-run (2 outputs written). `flutter analyze` clean (0 errors, 0 warnings; 2 pre-existing infos unchanged).

### Changed (2026-06-18 — App Icon & Name)
- **App icon** updated to new DROP branding image on both Android and iOS (all sizes generated via `flutter_launcher_icons` from `assets/E22CA445-D611-4A31-8EE5-BB661032E09C.png`).
- **App display name** changed from `FBRO` → `DROP` in `AndroidManifest.xml` (android:label) and `Info.plist` (CFBundleDisplayName + CFBundleName). Dart package name (`name: fbro` in pubspec.yaml) unchanged.
- Added `flutter_launcher_icons: ^0.14.3` as a dev dependency.

### Added (2026-06-18 — Inline Checklist Editor in Task Form)
- **Inline checklist editor** in the Create/Edit Task bottom sheet (`_InlineChecklistEditor` + `_ChecklistItemRow`). Managers can now add, remove, and reorder checklist steps directly on any blank task (not just templates). Each step has a **required/optional toggle** (star icon). On create: steps become `ChecklistItem`s on the task; on edit: existing steps preserve their `completed`/`completedAt` state, new steps are appended uncompleted.
- When a task is created from a **template**, its checklist is now **pre-populated and editable** (was read-only preview before) — managers can trim or extend the template checklist before creating.

### Changed (2026-06-18 — Task Form Simplified)
- **Removed the "Type" dropdown** (`TaskType: daily / special`) from the Create/Edit Task form. It was visually redundant with the "Repeats" picker ("Type: daily" looked identical to "Repeats: Daily"). Type is now **auto-inferred**: recurring tasks → `TaskType.daily`; one-off tasks → `TaskType.special`. The field is still stored on the entity for stats/filtering — it just no longer requires manual input.

### Fixed (2026-06-18 — Product Review: Employee UX)
- **Two-step complete → submit UX eliminated.** After an employee tapped "Submit
  Completion" (status → `completed`), they had to re-find the task card and tap
  "Submit for Review" a second time. `TaskCubit.completeAndSubmit` now uploads the
  proof image and advances the task directly to `waitingReview` in a **single
  Firestore write**, recording both `completed` and `waitingReview` activity
  entries with the same timestamp. The bottom-sheet button is renamed **"Complete &
  Submit"**. The separate `completeTask` (→ `completed`) and `submitForReview`
  paths are preserved for backward compat (e.g. tasks already in `completed` state
  still show "Submit for Review").
- **QA Checklist corrected** — R2 (task assignment) was documented as
  "refresh-based"; tasks are in fact realtime Firestore streams (`TaskCubit`).
  Updated E7/E10/E11 scenarios and the real-time note accordingly. Removed the
  obsolete known-limitation about the admin free-text branch field (fixed in
  Stabilization). Added accuracy notes on activity-log analytics limits and
  recurring-task spawn behaviour.

### Added (2026-06-18 — Operations Workflow Upgrade)
- **Recurring tasks** — `RecurrenceFrequency` enum (none/daily/weekly/monthly) + `RecurrenceConfig` entity (`frequency`, `interval`, `weekday`, `hour`, `minute`, `nextOccurrence()`). Manager/admin can set recurrence on any task. On approval, `TaskCubit._spawnNextRecurrence` auto-creates the next instance with the checklist reset and deadline advanced.
- **Activity timeline** — `ActivityEntry` entity embedded in `task.activityLog[]`. Every status transition (create/start/submit/approve/reject) appends an entry with actor, timestamp, and optional note. Shown newest-first on the Task Details page.
- **Task Details Screen** (`task_details_screen.dart`) — full-screen scrollable view: status header with animated pills, assignee block with "Assigned by Name·Role", checklist with live progress bar, submitted work (notes + proof image), activity timeline, and role-appropriate action buttons. Accessible from both manager (`ManagerTasksView`) and employee (`MyTasksScreen`) task cards.
- **Employee task UX redesign** (`my_tasks_screen.dart`) — tabbed layout (Active / Done) with 5 sorted sections: Needs Attention (rejected), In Progress, Today's Tasks, Upcoming, In Review. Animated entrance (fade+slide, staggered per card). Minimal card with status dot, deadline, checklist progress pill, and recurrence badge. Tapping any card opens `TaskDetailsScreen` with slide transition.
- **Recurrence picker** in task form sheet (`_RecurrencePicker`) — animated chip row: None / Daily / Weekly / Monthly. Only shown on new task creation.
- **`RecurrenceConfig`** and **`ActivityEntry`** are freezed entities with full Firestore serialisation in `task_model.dart`.

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

## 2026-06-18 — Task UX overhaul: proof bug, monochrome cards, "Assigned by", username removal

A product-design + architecture pass toward an enterprise (Linear/Notion/Asana)
feel: **black/white/grey, minimal, scannable**. Fixes the proof-photo flow,
redesigns task cards, surfaces **who assigned a task**, and removes the
operationally-useless username. Architecture, routing, role system, and Firebase
integration are unchanged.

### Fixed — review-photo / "User is not authorized" on Complete
- **Root cause:** the error is Firebase **Storage's `unauthorized`** — `storage.rules`
  aren't deployed / Storage isn't enabled. The upload code + rules are correct
  (`tasks/{taskId}/proof.jpg`, any signed-in user). **⚠️ Action required (console):**
  enable Storage + `firebase deploy --only storage,firestore:rules`.
- **Code fix (resilience):** `TaskCubit.completeTask` uploaded the proof *inside*
  the completion action, so a Storage failure **aborted the whole completion** —
  the employee couldn't even mark the task done and lost their notes. The proof is
  now **best-effort**: on upload failure the task still completes (notes kept) and a
  **precise, actionable warning** surfaces ("…Enable Firebase Storage and deploy
  storage.rules, then re-attach it.") instead of a blocking, cryptic error.
- **Manager can now view the submitted work:** the Review sheet
  ([task_action_sheets.dart](lib/features/task/presentation/widgets/task_action_sheets.dart))
  gained a **"Submitted work"** block showing the employee's notes + the proof image
  (it previously showed neither).

### Changed — task cards redesigned (monochrome, scannable)
- Rebuilt [task_card.dart](lib/features/task/presentation/widgets/task_card.dart) as a
  calm, enterprise card: **no priority rail, no coloured chips, no loud status
  badge**. Clear hierarchy — Title · subtle status (greyscale dot + label) ·
  Description · assignee (avatar/name/role) · **meta key-values** (Assigned by · Due ·
  Priority) · greyscale checklist · actions. **Removed all red/yellow** from the card
  body; colour is now reserved strictly for **destructive** actions (Delete) — even
  the amber "Review"/"Restart" accents are now monochrome.
- **"Assigned by" added everywhere relevant** — the card resolves the task's
  `createdBy` → "Name · Role" (e.g. "Ahmed Hassan · Manager"; global creators not in
  the branch directory show "Admin"). Managers/employees now instantly see who
  created a task. **Overdue** is flagged inline (greyscale) on the Due row.

### Changed — username removed (no operational value)
- Audited: username was **never collected at registration**, only **forced in
  profile editing** ("Username is required"), and is a leftover from the app's
  earlier social iteration — it provides no store-operations value (identity is Full
  Name · Email · Role · Branch). Removed the username field + validation + the
  uniqueness check from the edit-profile flow
  ([edit_profile_page.dart](lib/features/profile/presentation/pages/edit_profile_page.dart)).
  The dormant model field + `CheckUsername` use case are left as harmless legacy
  (no longer read/written by any UI) — a full model purge is a safe follow-up.

### Verified
- `flutter analyze` clean (2 pre-existing infos); **12 tests pass**. No
  entity/route/rule schema change; the proof + completion **workflow and permissions
  are intact** — the fix is resilience + UX, not a permission change.

### Still open (next, per the brief)
- **Full-screen employee Tasks experience** (search · filters · My Tasks / Overdue /
  Completed sections) — the redesigned card is the building block.
- **Broad screen simplification** (Home/Admin/Manager altitude pass).
- **Deploy `storage.rules` + enable Storage** so proof photos actually upload.

---

## 2026-06-17 — DROP THE SHOP UI redesign + Tasks crash fix

Restructures the role chrome to match the product mockups and redesigns the
signature auth screens — **while keeping the strictly-monochrome black / white /
grey palette** (the owner confirmed B&W/grey stays the main color; no indigo).
Also fixes a **pre-existing layout crash** on the Tasks screen. **No business
logic, routing model, entity/model, or Firebase-rule changes** — the work is the
shared chrome, the signature screens, and one render fix. The `assets/drop_logo.png`
wordmark is preserved and still rendered by `DropLogo`.

### Fixed (crash — pre-existing, Phase 9)
- **Opening the Tasks screen crashed with "BoxConstraints forces an infinite
  height".** `TaskCard`'s root was a `Row(crossAxisAlignment: stretch)` with a
  fixed-width priority rail; inside a `ListView` (unbounded height) `stretch`
  forces the rail to infinite height → assertion (the `RenderFlex`/`RenderBox.size`
  crash seen in the debugger). The rail is now a `PositionedDirectional` element in
  a `Stack`, so it stretches to the card's real content height instead of forcing
  infinity — identical look, no crash. Locked in with
  [task_card_layout_test.dart](test/task_card_layout_test.dart) (pumps a `TaskCard`
  in a `ListView`). Pre-existing since Phase 9 (surfaced now that the UI was run).

### Fixed (search field — "a field inside a field")
- **`AppSearchField` rendered an ugly nested box** (Branches / Employees /
  Managers). Its inner `TextField` set only `border: InputBorder.none`, so it still
  inherited the global `InputDecorationTheme`'s `filled: true`,
  `enabledBorder`/`focusedBorder` outlines, and 18px padding — drawing a second
  filled, bordered, padded box inside the search surface. Rebuilt to **fully
  neutralise** the input theme (`filled: false`, all border states
  `InputBorder.none`, `isCollapsed: true`, zero content padding) so it's ONE clean
  rounded surface, with a **focus highlight** (border + magnifier brighten) and a
  circular clear button — monochrome. Locked in with
  [app_search_field_test.dart](test/app_search_field_test.dart).

### Changed (chrome — bottom navigation)
- **`RoleScaffold`** rebuilt around a **bottom navigation bar**
  (Home · Tasks · Schedule · Profile) plus a clean header (notification bell +
  tappable avatar → profile). The old app-bar icon row (Tasks / Schedule) and the
  overflow menu (Profile / Settings / Sign out) are gone — Tasks/Schedule are
  bottom-nav tabs and the Profile tab still carries Settings + Sign out (both
  verified reachable). Each tab pushes its existing role-scoped route (launcher
  pattern; a persistent `StatefulShellRoute` is a noted follow-up).
- New shared widget **`app_bottom_nav.dart`** (`AppBottomNav` + `AppNavItem`) — a
  flat dark bar with a top hairline, a white-wash pill behind the active icon, and
  a white active label (monochrome).

### Changed (signature screens)
- **Splash** — DROP brand lockup (logo + `THE SHOP` + "Operations Management
  System"), a subtle neutral glow bloom, and a bottom loading bar + version.
- **Pending Approval** — centered redesign around a **breathing clock** (mono
  white-on-near-black, pulsing halo), a "Pending Approval" headline, the
  under-review copy, and a **"What happens next?"** 3-step card + Log out. Keeps
  the real-time `watchCurrentUser` redirect.
- **Login / Register** — copy aligned to the mockups (`Welcome Back` / `Sign in to
  continue`, `Create Account` / `Join DROP THE SHOP`).

### Changed (design tokens — palette unchanged, names added)
- **`AppColors`** stays **monochrome** (`primary` = white). Added token *names*
  consumed by the new chrome/screens — `onPrimary` (dark text on the white
  accent), `primarySurface` (white ~12% wash for the active nav pill / tiles), and
  a `primaryGlow(...)` helper kept **flat** (returns no shadow, so buttons stay
  flat white). `AppButton` primary uses `primaryGradient` (white→grey ≈ flat) +
  dark `onPrimary` text. FABs use the white accent + dark `onPrimary` label
  (unchanged look).

### Verified
- `flutter analyze` clean (only the 2 pre-existing `prefer_initializing_formals`
  infos); **11 unit tests pass** (10 prior + the new TaskCard layout regression).
  No entity/model/cubit/repository/route/Firebase-rule change (`git diff` confirms
  only theme/widget/screen/doc files).

### Notes / honest limitations
- Flutter UI can't be rendered/clicked in this environment, so visual work was done
  at the **token + shared-chrome** level and verified by `flutter analyze` + tests
  (incl. a real layout-assertion reproduction for the Tasks crash). Per-screen pixel
  polish is a natural follow-up.

---

## 2026-06-17 — StatusBadge, AppCard & context helpers

Second component-system increment. **No behaviour change.**

### Added
- **`StatusBadge`** ([status_badge.dart](lib/core/widgets/status_badge.dart)) — one
  tinted status pill for every Pending / Approved / Rejected / Completed / Active …
  indicator, with typed factories (`StatusBadge.task`, `.approval`, `.swap`,
  `.active`) that hold the colour+label mapping in a single place. **`task_card`'s
  private `_StatusBadge` + `_statusColor` + `_statusLabel` were removed** and
  replaced with `StatusBadge.task(...)` — identical render, real de-dup.
- **`AppCard` hover** ([app_card.dart](lib/core/widgets/app_card.dart)) — the
  reusable surface card now brightens its border on hover (`MouseRegion`, no-op on
  touch) in addition to the press-scale. Ready for the task/employee/branch cards
  to adopt.
- **Context helpers** ([context_extensions.dart](lib/core/extensions/context_extensions.dart))
  — `context.isAdmin` / `isManager` / `isEmployee` (literal role), and
  `context.showSuccess(...)` / `showError(...)` (thin pass-throughs to `AppSnackbar`).

### Verified
- `flutter analyze` clean (2 pre-existing infos); **10 tests pass**.

### Deferred (needs an on-device visual pass — flagged by the user as lower
priority than the Task Flow audit)
- Adopting `AppCard` across the 4 bespoke cards (they currently use a gradient +
  radius 20; `AppCard` is flat + radius 24) and converging the admin info-chips
  onto `StatusBadge`.

---

## 2026-06-17 — Shared form & layout component system

Consolidated the form/layout primitives into reusable, design-system-consistent
widgets so screens stop re-implementing fields by hand. **No behaviour change**
(text/keyboard actions preserved exactly); the only visual deltas are the
explicitly-requested token bumps (input radius → 20).

### Added (reusable widgets)
- **`AppPasswordField`** ([app_password_field.dart](lib/features/auth/presentation/widgets/app_password_field.dart))
  — built on `AppTextField` (built-in show/hide, lock prefix, unified focus/error
  style). Replaced the hand-wired `obscureText` fields on **login, register, and
  all 3 change-password** inputs (5 sites).
- **`AppDropdownField<T>`** ([app_dropdown_field.dart](lib/features/auth/presentation/widgets/app_dropdown_field.dart))
  — a styled dropdown matching `AppTextField` (surface · radius 20 · border · icon)
  with a `placeholder` for loading/empty states. The admin task **branch picker**
  (`_BranchDropdown`) now uses it (its bespoke container + `_placeholder` helper
  removed).
- **`AppEmptyState`** ([app_empty_state.dart](lib/core/widgets/app_empty_state.dart))
  — generic scroll-aware empty placeholder (icon · optional title · message ·
  optional action). `TaskEmptyState` now **delegates** to it (same render, same API).
- **`AppCard`** ([app_card.dart](lib/core/widgets/app_card.dart)) — reusable surface
  shell (dark surface · radius 24 · border · press-scale on tap). Provided as the
  shell for task/employee/branch cards to adopt.

### Changed
- **`AppTextField`** gained `readOnly`, `onTap`, and an `IconData suffixIcon`
  convenience (enables read-only / picker-style fields), and its corner radius now
  uses the `AppRadius.xl` (20) token instead of a hardcoded 16 — per the requested
  input spec. Fully backward-compatible (new params are optional).

### Notes / deferred (need an on-device visual pass)
- The existing **task / employee / manager / branch cards** keep their bespoke
  gradients + radius (20) for now; adopting `AppCard` (radius 24) is a visual change
  best verified on device, so it's left as a follow-up rather than migrated blind.
- The **settings delete-account** dialog keeps its raw Material `TextField`
  (outlined style inside a tight dialog) — not migrated to `AppPasswordField` to
  avoid a layout change that can't be verified here.

### Verified
- `flutter analyze` clean (2 pre-existing infos); **10 tests pass**. Existing
  `AppTextField`/`AppButton`/`AppSearchField`/`Skeleton` already covered the rest
  of the requested components and were reused as-is.

---

## 2026-06-17 — Architecture: de-duplication & shared utilities

A maintainability pass — **no new features, no UI redesign, no behaviour
change, no Firebase/routing changes**. Extracted the highest-reuse duplicated
patterns into shared utilities; every render and result is identical to before.

### Added (shared utilities)
- **`context_extensions.dart`** — `context.currentUser` / `context.currentRole`
  ([core/extensions/context_extensions.dart](lib/core/extensions/context_extensions.dart)).
  Collapses the `context.read<AuthCubit>().state.maybeWhen(authenticated: …,
  orElse: () => null)` boilerplate that was copy-pasted across **13 call sites in
  11 screens** into a single getter (same `read` semantics — no rebuild change).
- **`showConfirmDialog(...)`** ([core/widgets/app_dialog.dart](lib/core/widgets/app_dialog.dart))
  — one canonical confirmation/delete dialog, replacing **3 near-identical
  `AlertDialog` blocks** (sign-out · delete branch · delete task). Returns
  `Future<bool>` (dismiss = false); destructive actions get the red confirm.
- **`firestore_extensions.dart`** — `map.date('field')`
  ([core/extensions/firestore_extensions.dart](lib/core/extensions/firestore_extensions.dart)).
  Centralises the `(map['x'] as Timestamp?)?.toDate()` mapping repeated **21×**
  across 7 models, and removes the duplicated per-file `ts()` helper in
  `ProfileModel`.

### Removed (dead code / cleanup)
- **`role_placeholder.dart`** (`RolePlaceholder`, 78 lines) — never referenced
  anywhere in the app.
- **14 unused imports** — 8 `auth_cubit` imports (now reached via the context
  extension), 3 `cloud_firestore` imports (models that no longer touch
  `Timestamp` directly), plus the verbose inline blocks the helpers replaced.

### Verified
- `flutter analyze` clean (2 pre-existing infos); **10 tests pass**. Behaviour is
  byte-for-byte preserved: the extensions reproduce the exact `read`/`Timestamp`
  semantics, and `showConfirmDialog` renders the established delete-dialog chrome.

### Deferred (documented, not done — would risk a blind UI/behaviour change)
- **App-bar consolidation** (~14 screens share `AppBar(darkBg, elevation:0, h3)`)
  — too much per-screen variation (TabBar bottoms, custom leadings, transparent
  auth bars) to migrate safely without an on-device visual pass.
- **Bottom-sheet chrome** — `showSheet`/`SheetHandle` could move to `core`, but
  other sheets use slightly different radius/shade; unifying changes pixels.
- **Form validators** — messages and trim rules vary per field, so extraction
  would be a partial dedup with behaviour-change risk.

---

## 2026-06-17 — Stability & UX Audit

A focused reliability/usability pass — **no new features, no architecture
change**. Goal: make the app feel reliable, simple, and hard to crash. Audited
crashes, broken flows, role separation, navigation friction, and UI consistency.

### Fixed — crashes
- **A malformed/partial `users/{uid}` document could crash every user-list
  load.** `UserModel.fromMap` cast `uid`/`email` to **non-null** `String`
  ([user_model.dart](lib/features/auth/data/models/user_model.dart)), so a single
  doc missing `email` (e.g. a phone-auth account) or seeded out-of-band threw a
  `TypeError` that took down the whole load — the schedule "team", the task
  **assignee picker**, and the admin user lists. Root cause: these two fields
  used hard casts while **every other model** already uses `as String? ?? ''`.
  Now they degrade to empty strings (the UI's initials/avatar fallback handles
  it). Same hardening applied to `ProfileModel.fromMap` (`uid`).
  Locked in with [user_model_test.dart](test/user_model_test.dart) (3 cases:
  no-email doc, empty doc, well-formed doc).

### Changed — navigation & friction
- **Sign out was a single, unconfirmed app-bar tap.** The role chrome
  ([role_scaffold.dart](lib/core/widgets/role_scaffold.dart)) exposed **five**
  app-bar icons (Tasks · Schedule · Profile · Settings · **Sign out**); a stray
  tap signed the user out instantly, losing in-progress work. Consolidated the
  three occasional actions (Profile / Settings / Sign out) into a single overflow
  (`PopupMenuButton`) menu — decluttering the app bar to **Tasks · Schedule · ⋮**
  — and **Sign out now requires a confirmation dialog**. No routes changed.

### Changed — UI consistency
- **Standardized all ad-hoc snackbars on `AppSnackbar`.** Six raw
  `ScaffoldMessenger…showSnackBar` blocks across the auth/settings screens
  (login, register, phone OTP, email verification, forgot password, change
  password) were replaced with `AppSnackbar.success/error`, giving every screen
  the same icon + radius and the **hide-then-show** behaviour that prevents
  snackbars from stacking on rapid retries.

### Verified (audit — no change required)
- **No crashes** from force-unwraps in UI paths: avatar/initials helpers filter
  empty parts; upload-progress division is guarded (`totalBytes > 0`); checklist
  progress is guarded against an empty list; image-picker results are
  null-checked. Firestore models other than the two above already use null-safe
  casts with defaults.
- **No broken/dead buttons or reachable placeholder screens.**
- **Role separation is correct** — the router enforces admin-only `/admin/*`,
  manager+admin `/manager/*`, employee-only `/`, and self-scoped `/my-*`
  (admin ⊇ manager); manual URL access is bounced to the role home.
- **Loading / empty / error states are already covered** on every list screen
  (skeletons, `TaskEmptyState`, `AppSnackbar` errors, pull-to-refresh).
- `flutter analyze` clean (2 pre-existing infos); **10 tests pass** (7 existing +
  3 new crash-regression tests).

---

## 2026-06-16 — Phase 10: Production Hardening & QA

A verification, stabilization and UI-modernization pass for a production beta —
**no new business modules, no architecture change**. Reuses the existing
navigation, Clean Architecture, repositories and theme.

### Removed (cleanup — verified dead code)
- **The entire Phase 2 `shift` feature.** It was never consumed (no `ShiftCubit`/
  use cases; screens unreachable from the role chrome; `AppDependencies.
  shiftRepository` registered but unused; `RouteNames.shiftsForRole` never
  called). Deleted: `lib/features/shift/`, the `/admin|manager/shifts` + `/my-shift`
  routes (+ imports) in `app_router.dart`, the shift route constants +
  `shiftsForRole` in `route_names.dart`, the shift wiring in `injection.dart`,
  `AppConstants.shiftsCollection`, and the `shifts/{shiftId}` block in
  `firestore.rules`. The weekly **schedule** (Phase 7) is the production roster;
  `users/{uid}.assignedShift` and `tasks.assignedShiftId` remain as harmless
  nullable strings. Verified with `flutter analyze` (clean).

### Changed (UI modernization — same navigation/architecture)
- **Manager dashboard** restructured into a command-center: a "Needs attention"
  hero row (**Waiting reviews** + **Active tasks**, tappable to the task screen,
  accent when non-zero), then grouped **Team & shifts today** and **Tasks**
  sections with `SectionHeader`s.
- **Employee dashboard** leads with a premium glass **Today's shift** card
  (shift icon + next-shift line) then a focused **Your tasks** grid — reduced
  clutter.
- **Loading states**: the task / admin-user / branch list screens now show a
  shimmering `ListSkeleton` on first load instead of a bare spinner.
- New shared widgets: `dashboard_section.dart` (`SectionHeader`, `HeroStatCard`)
  and `list_skeleton.dart` (both reuse the existing theme + `Skeleton`).

### Verified (by code audit + tooling — see honest limitations)
- **Auth / approval / roles**: register → pending (real-time `watchUser`) →
  admin approve (role + branch) → role dispatch; router redirect gates approval
  before role, and `_isAdminArea`/`_isManagerArea` guards (incl. the new
  `/admin/analytics`) bounce cross-role access.
- **Tasks**: create / from-template (checklist generated) / edit / delete /
  assign one·many·whole-team / checklist completion gate / proof upload / review;
  lists are live streams; rules are query-compatible (`assigneeIds arrayContains`).
- **Schedule + swaps**, **analytics math** (admin/manager/employee), **offline**
  (Firestore persistence + reload-after-mutation), and **profile upload**
  (60 s/20 s timeouts + progress + error recovery → never freezes).
- `flutter analyze` clean (2 pre-existing infos only); 7 unit tests pass;
  `build_runner` regenerates with 0 stale outputs.

### Notes / honest limitations
- Flutter UI can't be rendered/clicked in this environment, so UI work was kept
  to safe, deterministic, theme-consistent changes verified by `flutter analyze`
  and logic tests — not an on-device visual pass. `firestore.rules` /
  `storage.rules` were edited but **not deployed** here. No commit was made this
  phase (per the phase's git rules).

---

## 2026-06-16 — Phase 9: Task UX, Admin UX & Design Overhaul

A premium-operations redesign pass: checklist task templates, multi-assignee
tasks, redesigned task/admin/branch cards, reliable avatars, an admin dashboard
restructure, and tasteful motion. **Reuses the existing Clean Architecture** —
no new layers, no duplicate features; the task data layer keeps backward
compatibility (legacy `assignedEmployeeId` mirror) so the Firestore schema isn't
broken.

### Added
- **Checklist templates** (was title + description). New `ChecklistItem` (task
  level: `id/title/isRequired/completed/completedAt`) and `ChecklistItemTemplate`
  (template level: `id/title/isRequired`) freezed entities
  ([checklist_item.dart](lib/features/task/domain/entities/checklist_item.dart)).
  `TaskTemplateEntity.checklistItems` + `TaskEntity.checklist`; creating a task
  from a template **generates its checklist** (`buildTaskChecklist`). The
  template form gained a **checklist editor** (add/remove steps, mark each
  required/optional).
- **Checklist completion rule** — a task cannot be marked completed until every
  **required** checklist item is done (`TaskEntity.requiredChecklistComplete`,
  enforced in `TaskCubit.completeTask`). Employees tick items off on the card
  while a task is in progress (`TaskCubit.toggleChecklistItem`); the manager
  review sheet shows progress ("4 / 5 completed" / "100% complete").
- **Multi-assignee tasks** — `assigneeIds[]` replaces the single
  `assignedEmployeeId` (kept as a mirror for backward compatibility). Assign one,
  several, or the **whole team** (multi-select assign sheet). Employee task query
  + stats now use `assigneeIds arrayContains`.
- **`UserAvatar` + `AvatarStack`** ([user_avatar.dart](lib/core/widgets/user_avatar.dart))
  — the **assignee image bug fix**: a reliable circular avatar that renders
  `users/{uid}.photoUrl` (kept in sync with the profile `profileImage`) and falls
  back to **initials** on any missing/empty URL, network failure, or decode error
  — never a broken-image icon or crash. Decode size is capped; `gaplessPlayback`
  avoids flicker. `AvatarStack` shows overlapping avatars + a "+N" overflow.
- **`EntranceFade` + `staggerDelay`** ([app_motion.dart](lib/core/widgets/app_motion.dart))
  — tasteful, performance-conscious card/list entrance motion (used on task,
  admin, branch and KPI cards).
- **`AppSearchField`** ([app_search_field.dart](lib/core/widgets/app_search_field.dart))
  — shared search box; added to the Managers, Employees, Approvals and Branches
  pages.
- **Admin Analytics page** ([admin_analytics_screen.dart](lib/features/admin/presentation/pages/admin_analytics_screen.dart),
  route `/admin/analytics`) — the full metric wall (grouped Workforce / Tasks /
  Coverage), moved off the Admin Home.

### Changed (UI redesign — no business-logic change unless noted)
- **Task cards** — glass-like gradient cards with a priority rail, status badge,
  **assignee avatars** (name + role for a single assignee; stack + count for
  many; tap → assignee sheet), **checklist progress bar**, priority/category/
  deadline chips, and the existing actions. Employee identity is now visible
  (avatar · name · role) instead of "assigned/unassigned".
- **Admin Home** restructured to **four headline KPIs** (Branches · Employees ·
  Managers · Active tasks) + a clean module nav (Branches · Schedules · Managers
  · Employees · Analytics · Approvals · Settings). The crowded stat wall is gone
  (now on Analytics).
- **Branches page** — premium cards showing **manager + employee count + status**
  (resolved via `AdminUsersCubit.usersWithRole`), search, animated entrance.
- **Managers / Employees / Approvals** — avatar-led `AdminUserCard`s; Employees
  gained **search + active/inactive + branch** filters; Managers/Approvals gained
  search.
- **Schedule** (no logic change) — day **coverage indicator**, **shift badges**,
  **employee chips with avatars**, avatar-led picker, and the employee "My Week"
  team/manager shown with avatars.
- **Firestore rules** (`tasks/{taskId}`) — read/own-task-update now key off
  `assigneeIds` (`request.auth.uid in assigneeIds`, with a legacy
  `assignedEmployeeId` fallback); the assigned employee still can't reassign
  (`assigneeIds` frozen on self-update), move branch, or set the terminal
  approved/rejected status.

### Verified
- `flutter analyze` — clean (only the 2 pre-existing `prefer_initializing_formals`
  infos). `build_runner` regenerated the freezed entities/state. New unit tests
  ([task_checklist_test.dart](test/task_checklist_test.dart), 7 passing) cover the
  checklist completion rule, multi-assignee (de)serialization + legacy fallback,
  and template→task checklist generation. Existing task & schedule workflows are
  unchanged in shape; admin navigation reaches every module.

### Notes / honest limitations
- Tasks created **before** Phase 9 carry only `assignedEmployeeId`; the model
  reads it into `assigneeIds` on load and re-writes the array on the next save,
  so they migrate transparently as they're touched (no bulk migration needed for
  a pre-production dataset). `firestore.rules` were edited but **not deployed** in
  this environment.

---

## 2026-06-16 — Stabilization & Workflow Integration

Production-usability pass making the task workflow reliable end-to-end, plus a
new **Task Templates** feature. **No redesign, no rebuild** — reuses the
existing task architecture, widgets, and theme.

### Fixed
- **Build was broken — `pubspec.yaml` had `name:Drop`** (invalid YAML *and* the
  wrong package name; every import is `package:fbro/…`). Restored to
  `name: fbro` so the project compiles, codegen runs, and `flutter analyze` works.
- **Admin-created tasks could be orphaned / unassignable.** The admin task form
  used a **free-text branch field** — a typo (`cairo`) stored a `branchId` that
  matched no real branch, so the Assign sheet found no employees ("flow looks
  broken"). The admin now **picks an existing branch from a Firestore-backed
  dropdown** (`task_action_sheets._BranchDropdown` → `TaskCubit.branches()` →
  `BranchRepository`), so the task's `branchId` always matches the employees'
  `users/{uid}.branchId`. Managers still use their own fixed branch.
- **Employees didn't see a task right after assignment.** Task lists were
  one-shot reads, so a just-assigned task only appeared on manual refresh. Lists
  are now **realtime** (see below).
- **Profile image change could "freeze" the app.** Storage uploads had **no
  timeout**, so a disabled/misconfigured bucket or a dropped connection hung the
  UI indefinitely. Added a 60s upload + 20s download-URL timeout
  (`ProfileRemoteDataSource`), surfaced as a clean error. Also shrank picked
  images (avatar 800px / cover 1280px, q70) and capped decode size
  (`cacheWidth`) on every avatar/cover/proof image so a large bitmap can't jank
  the UI thread.

### Added
- **Task Templates** — reusable task blueprints ("Open Shop", "Close Shop",
  "Morning/Night Checklist") so recurring daily work isn't retyped each shift.
  Full slice folded into the **existing** task feature (faithful reuse, not a new
  system): `TaskTemplateEntity` (freezed) + `TaskTemplateModel`, template CRUD on
  `TaskRemoteDataSource`/`TaskRepository`(+Impl), and `TaskCubit.templates /
  saveTemplate / deleteTemplate`. New collection `task_templates/{id}` with
  branch-scoped `firestore.rules` (admin: global or any · manager: own branch;
  employees don't read templates). UI: a two-step **New Task** chooser
  (Blank vs. From a template), a template picker that **prefills** the task form,
  and a **Manage Templates** sheet (add/delete) behind a new app-bar action on
  the manager/admin task screen (`task_template_sheets.dart`).

### Changed (realtime)
- **Task lists are now live Firestore streams.** `TaskRepository.watch{AllTasks,
  TasksByBranch,EmployeeTasks}` (added) drive `TaskCubit`, which subscribes by
  role (admin: all · manager: branch · employee: own) instead of one-shot
  fetches. A newly assigned task — or any status change — now appears
  **immediately** with no manual refresh, backed by the offline cache. Mutations
  keep the list visible (busy bar) and the stream reflects the result.
  Pull-to-refresh re-subscribes. Other lists (schedule/branch/admin/swaps) keep
  the instant reload-after-mutation model (per stabilization scope).

### Removed
- The three one-shot task **use cases** (`GetAllTasks`/`GetTasksByBranch`/
  `GetEmployeeTasks`) — superseded by the realtime streams. `TaskCubit` now takes
  the `TaskRepository` directly for streams/templates (+ `BranchRepository` for
  the branch picker), per the documented cubit convention (repository injection
  for stream/non-action access). The Future-based read methods remain on the
  repository contract.

### UI polish (safe, deterministic — visuals unverifiable in this env)
- All task/template/review bottom sheets share rounded chrome with a **drag
  handle** (`SheetHandle`); the assign empty-state copy now explains *why* a
  branch has no employees; the delete-confirm dialog is rounded.

### Verified (by code audit + tooling)
- `flutter analyze` — clean (2 pre-existing infos only). Codegen
  (`build_runner`) regenerates the new freezed template entity. Realtime task
  queries are **rules-compatible** (each role's query is provably safe under
  `tasks/{id}`). DI + routing unchanged in shape; the `branchRepository` is now
  built once and shared by `TaskCubit` and the admin module.

### Honest limitations
- **Flutter mobile UI can't be run/rendered here**, so visual polish was kept to
  safe, deterministic changes; the freeze fix is verified by code/logic, not an
  on-device repro. `firestore.rules` were edited but **not deployed/tested** in
  this environment. Storage still must be **enabled** in the Firebase console for
  uploads to succeed at all (an unrelated precondition).

---

## 2026-06-16 — Phase 8: QA, Hardening & UI Polish

Stabilization + polish pass to make the app feel like a production operations
system. **No new business features, no redesign.** Reuses existing widgets and
architecture; diffs kept focused. Produced [`QA_CHECKLIST.md`](QA_CHECKLIST.md)
(on-device manual QA sheet for the Employee / Manager / Admin workflows + real-time
/ offline / UI checks).

### Added / Improved (UI)
- **Dashboard loading skeletons** — the admin / manager / employee dashboards now
  show a shimmering `StatGridSkeleton` (new, in `statistics/.../stat_grid.dart`,
  reusing the existing `Skeleton` widget) while stats load, instead of a single
  spinner card — no layout jump when data arrives. The employee dashboard also
  skeletons its shift card.
- **Dashboard error state** is now an icon + message row (clearer than bare red
  text); pull-to-refresh still recovers it.

### Changed (real-time)
- **Manager swap approval refreshes the schedule automatically.** On
  `BranchScheduleScreen`, a `BlocListener` on `ShiftSwapCubit` refreshes
  `ScheduleCubit` the moment a swap action settles — so an approved swap (which
  rewrites the roster) shows on the Schedule tab without a manual pull-to-refresh.
  Fires only after a mutation, not on first load.

### Verified (by code audit — see Honest limitations)
- Full Employee / Manager / Admin workflows trace cleanly end-to-end; routing,
  role guards, DI (all 8 cubits + repos/datasources registered & provided),
  Firestore/Storage rules, FCM token foundation, offline persistence, and session
  restore are consistent. `flutter analyze` clean (2 pre-existing infos only).
- Pull-to-refresh confirmed present on **every** list screen already.

### Notes
- UI changes were deliberately limited to **safe, deterministic** improvements
  (skeletons, error rows, an auto-refresh) — broader visual restyling was **not**
  done blind, since Flutter mobile UI can't be visually verified in this
  environment. A prioritized visual-polish spec is in the final report / docs.
- The orphaned Phase 2 `shift` feature remains documented dead code (see prior
  entries) — kept per "remove only if safe, otherwise document."

---

## 2026-06-16 — Integration Audit (workflow verification)

End-to-end verification of the Employee / Manager / Admin business workflows and
the seams between features. One integration bug fixed; no new features.

### Fixed
- **Promoting an employee to manager wiped their branch.**
  `AdminUsersCubit.promoteToManager` called `changeUserBranch(uid, null)`
  unconditionally, so a promoted manager was left **branch-less** — unable to
  manage any schedule/tasks until a second "Assign Branch" step, and silently
  discarding the employee's existing branch. It now **preserves the existing
  branch** unless a new one is explicitly passed (admins can still reassign from
  the manager list). Updated the "Add manager" sheet copy to match.

### Verified (works end-to-end, by code audit)
- **Employee:** register → pending (real-time approval) → login → view schedule
  (team + manager resolve after the stabilization rule fix) → assigned task →
  start → complete (+ notes/proof to Storage) → submit for review.
- **Manager:** create/edit weekly schedule, assign/remove shift employees, create
  + assign tasks, review (approve/reject), and handle shift swaps (coworker →
  manager approval rewrites the schedule). All branch-scoped reads/writes pass the
  rules.
- **Admin:** create branches, manage managers (promote/assign-branch/activate/
  demote), manage employees (change-branch/activate/details), view analytics,
  device-token persistence for push.

### Notes / honest findings (not bugs — by design or out of scope)
- **Managers do not approve users** — approval is **admin-only** (Phase 6 design),
  so the brief's "Manager → Approve employee" is intentionally unsupported.
- **Rejected users** see the generic "Pending Approval" screen (access is correctly
  blocked; the message just doesn't distinguish rejected from pending).
- **Admin task creation** uses a free-text branch field (mistyping orphans the
  task); managers — the primary task creators — use their fixed branch and are
  safe. Pre-existing (Phase 4).
- **Cross-client updates** are not push: another user's open list / the dashboards
  reflect a change on refresh, and within the manager schedule screen approving a
  swap doesn't auto-refresh the schedule tab. Data is consistent after refresh;
  only the approval gate is stream-driven (see the stabilization entry).

---

## 2026-06-16 — Stabilization & Production Hardening

A production-readiness audit pass — verification, integration fixes, real-time
and offline hardening. **No new business features.** Reuses existing systems;
changes kept minimal and focused.

### Fixed
- **Employees could not load their weekly schedule (critical).** The Phase 7
  employee "My Schedule" resolves teammate + manager names via
  `getUsersByBranch`, but the `users` read rule only allowed **managers/admins**
  to read same-branch users — an employee's query was denied, so the whole
  schedule view errored. `firestore.rules` now lets **any branch member** read
  users in their **own** branch (`selfBranch() != '' && branchId == selfBranch()`),
  which is exactly what the schedule's "team working with me" + "current manager"
  needs. Managers/admins are unchanged; cross-branch reads stay blocked.
- **`getUsersByBranch` now fails gracefully** — the datasource wraps Firestore
  errors as `AuthException` (→ `AuthFailure`), so a permission/network error
  surfaces as a clean error state instead of an unhandled exception.

### Added
- **Firestore offline persistence** (`main.dart`) — `Settings(persistenceEnabled:
  true, cacheSizeBytes: CACHE_SIZE_UNLIMITED)`. Cached reads, writes queued and
  synced on reconnect, and no crashes when the connection drops. Reuses Firebase's
  built-in cache (no custom offline engine).
- **Real-time user-doc watch** — `AuthRepository.watchUser` /
  `UserRemoteDataSource.watchUser` (Firestore `snapshots()`) +
  `AuthCubit.watchCurrentUser` / `stopWatchingUser`.

### Changed
- **Pending Approval is now real-time, not polled.** `PendingApprovalPage`
  replaced its 6-second `Timer.periodic(refreshUser)` poll with
  `AuthCubit.watchCurrentUser` (a live `users/{uid}` listener): the instant an
  admin approves the account it redirects to the role shell — no delay, fewer
  reads. The manual "Check Approval Status" button remains as a fallback.

### Notes / honest state
- **Real-time scope:** the approval flow is now stream-driven. Task / schedule /
  branch lists still use **reload-after-mutation** (instant for the acting user)
  + pull-to-refresh; full cross-client streaming for those would convert the
  Future-based repositories to streams — a deliberate non-goal for a stabilization
  pass (it would redesign the data layer).
- **Orphaned Phase 2 shift placeholders remain** (`features/shift/...`,
  `/admin|manager/shifts`, `/my-shift`, `AppDependencies.shiftRepository`,
  `RouteNames.shiftsForRole`): unreachable from the UI and unused since the weekly
  Schedule (Phase 7) superseded them. Left intact this pass (deleting a feature is
  out of a minimal stabilization scope); recommended for removal in a focused
  cleanup. The shift-visibility requirement is met by the Weekly Schedule.

---

## 2026-06-16 — Phase 7: Weekly Schedule & Shift Swap

Replaces the Excel / WhatsApp shift roster with an in-app **weekly schedule**:
managers build their branch's week (Day → Morning / Night → Employees), employees
see their week + today's team + manager, and coworkers trade shifts through a
**swap workflow** (coworker approves → manager approves → schedule updates
automatically). Reuses the existing Clean Architecture, Role/Branch systems, and
the FCM contract; no Node.js, no working systems rewritten.

### Added
- **`schedule` feature** (full vertical slice, repo-direct cubits — like
  branch/admin):
  - **Enums** (`core/enums`): `ScheduleDay` (Sun→Sat, `fromDate`/`today`),
    `ScheduleShift` (`morning`/`night`), `SwapStatus`
    (`pending`/`employeeApproved`/`managerApproved`/`rejected`).
  - **Domain**: `ScheduleWeek` (week-start math + deterministic doc id
    `<branchId>_<yyyy-MM-dd>`), `WeeklyScheduleEntity` (nested
    `day → shift → [uid]` roster + helpers), `ShiftSwapEntity`, and
    `ScheduleRepository`.
  - **Data**: `WeeklyScheduleModel` / `ShiftSwapModel`, `ScheduleRemoteDataSource`
    (`weekly_schedules` + `shift_swaps`; nested `arrayUnion`/`arrayRemove` for
    assign/remove; merge-two-queries for an employee's swaps) and
    `ScheduleRepositoryImpl` (`managerApproveSwap` updates the swap **and** the
    schedule).
  - **Cubits** (provided app-wide): `ScheduleCubit` (loads a (branch, week) view
    + branch members; create/assign/remove; week + branch navigation) and
    `ShiftSwapCubit` (employee `loadMine` / manager `loadBranch`; request /
    coworker-approve / reject / manager-approve).
  - **Screens**: manager `BranchScheduleScreen` (tabs: editor + swap queue),
    admin `ScheduleManagementScreen` (branch picker + editor, override any
    branch), employee `MyScheduleScreen` (tabs: My Week — today's shift, team,
    manager, per-slot "Request swap" — + Swaps). Shared `ManagerScheduleView`,
    `SwapListView` + `showSwapRequestSheet`, `schedule_helpers`.
  - **Routes** `/admin/schedule`, `/manager/schedule`, `/my-schedule`
    (`RouteNames.scheduleForRole`, role-guarded like tasks). The role-chrome
    calendar icon now opens the **weekly Schedule** (was the Phase 2 shift
    placeholder).
  - **DI** `scheduleCubit` / `shiftSwapCubit` wired in `injection.dart` + provided
    in `main.dart`. `AppConstants.weeklySchedulesCollection` / `shiftSwapsCollection`.
- **Firestore rules** for `weekly_schedules/{id}` (branch-scoped: admin/own-branch
  manager write · any employee of the branch reads) and `shift_swaps/{id}`
  (read/act = the two employees + branch manager/admin; create = requester in own
  branch). Exact swap flow validated client-side (`ShiftSwapCubit`).
- **Notification contract** (`NotificationType`): `tomorrowShiftReminder`,
  `swapApproved`, `swapRejected` (employee), `newSwapRequest`,
  `swapPendingApproval` (manager), `branchWithoutSchedule` (admin) — the sender is
  still out of scope (no Cloud Functions).

### Changed
- **Dashboards now read the weekly schedule** (Phase 7), not the Phase 2 `shifts`
  placeholder: employee — **current + upcoming shift**; manager — **scheduled /
  morning / night today**; admin — **schedule coverage** (`branchesWithSchedule`/
  `totalBranches`). New `StatisticsEntity` fields (`branchesWithSchedule`,
  `scheduledToday`, `upcomingShiftName`); `morningShiftEmployees`/
  `nightShiftEmployees`/`currentShiftName` now mean "today, per the weekly
  schedule." `StatisticsRepository.employeeStats` gained a `branchId` arg.

### Notes
- **Swap = single-slot handover**: the requester gives up one (week, day, shift)
  cell; on manager approval they're removed and the target is added. Status-flow
  order is enforced client-side (`ShiftSwapCubit`); the rules enforce *who* writes.
- The Phase 2 `shift` foundation (`shifts/{shiftId}`) is **untouched** — the
  weekly schedule is the production roster and supersedes the placeholder shift
  screens for navigation. No notifications sender, no analytics engine (out of
  scope).

---

## 2026-06-15 — Phase 6: Operations Dashboards & Notifications

Makes the app feel like a DROP THE SHOP operations center: live role-scoped
dashboards and a Firebase Cloud Messaging foundation. Reuses existing
architecture; no analytics engine, no Node.js, no chat/inbox.

### Added
- **`statistics` feature**: `StatisticsEntity` (freezed) / `StatisticsModel` /
  `StatisticsRepository(+Impl)` / `StatisticsRemoteDataSource` + `StatisticsCubit`.
  `load(user)` dispatches by role — `adminStats()` (global) / `managerStats(branchId)`
  / `employeeStats(uid)` — computing operational counts from branch-scoped
  single-field queries + client-side aggregation (no composite indexes).
- **Live dashboards** via a shared `StatGrid`: admin (branches, managers,
  employees, pending approvals, active/completed tasks, waiting reviews, rejected
  today, no-manager branches), manager (own-branch employees, active/waiting/
  completed-today/rejected/daily/special tasks, morning/night shift staff),
  employee (current shift, assigned/pending/waiting-review/completed tasks).
  `AdminDashboardScreen`, `ManagerHomeScreen` and `EmployeeHomeScreen` now show
  real data (the manager/employee placeholders are gone).
- **FCM foundation**: `core/services/notification_service.dart` (permission,
  device-token persistence on `users/{uid}.fcmToken`, foreground → in-app
  snackbar) + `core/enums/notification_type.dart` (the employee/manager/admin
  event contract). Wired in `main.dart` (background handler, init, token
  register/forget on auth changes, `scaffoldMessengerKey`). Added the
  `firebase_messaging` dependency.

### Changed
- **Account approval is now admin-only** — removed the manager user-write path
  (approve/claim) and the manager pending-read from `firestore.rules`. Managers
  read their own-branch team but manage **operations only** (shifts/tasks), not
  accounts. (Workflow: register → pending → **admin** approves → role + branch →
  active.)
- Replaced the Phase 5 `AdminStatsCubit`/`AdminStats` with the unified
  `StatisticsCubit` (admin dashboard migrated; redundant files removed).

### Notes
- Push **sending** is out of scope (needs a server trigger / Cloud Function —
  no Node.js). This phase ships the client foundation only; `NotificationType`
  is the event contract. iOS still needs an APNs key + Push capability.
- `count()` aggregate queries are a documented future optimization if data grows.

---

## 2026-06-15 — Phase 5: Admin Management module

Builds the complete admin module: branch management, manager/employee/pending
user administration, branch assignment, and a reports overview. Reuses the
existing Clean Architecture and Firebase backend; no working code rewritten.

### Added
- **`branch` feature** (full vertical slice): `BranchEntity` (freezed) /
  `BranchModel` / `BranchRepository(+Impl)` / `BranchRemoteDataSource` +
  `BranchCubit`/`BranchState` + `BranchManagementScreen` + `branch_form_sheet`.
  Admin CRUD, activate/deactivate, and **soft delete** (`deletedAt`).
  Collection `branches/{branchId}` + `AppConstants.branchesCollection`.
- **`admin` module**: `UserAdminRemoteDataSource` + `UserAdminRepository(+Impl)`
  over `users/{uid}` (reusing the auth `UserModel`/`UserEntity`); `AdminUsersCubit`
  (loads pending / managers / employees by `AdminUserFilter`; approve, reject,
  (de)activate, change role, change branch, promote-to-manager) and
  `AdminStatsCubit` (+ `AdminStats`) for the reports overview.
- **Admin screens**: reworked `AdminDashboardScreen` (reports overview — branches,
  managers, employees, pending approvals, active + completed tasks — plus
  navigation) and `BranchManagementScreen`, `ManagerManagementScreen`,
  `EmployeeManagementScreen` (branch filter + details), `PendingApprovalsScreen`;
  shared `AdminUserCard` / `admin_user_sheets` (approve, assign branch, promote) /
  `admin_users_list_view`.
- **Routes** `/admin/branches|managers|employees|approvals` (under the existing
  admin-only `_isAdminArea` guard); `branchCubit`/`adminUsersCubit`/
  `adminStatsCubit` wired in DI and provided app-wide in `main.dart`.
- **Firestore rules** for `branches/{branchId}` (admin write · any signed-in
  read · hard delete denied). Admin user-administration uses the existing `users`
  admin-update rule.

### Notes
- **Managers are promoted from existing approved users** — no client-side Firebase
  Auth account creation (it would sign the admin out) and no Cloud Functions
  (no Node.js). New staff self-register → admin approves (optionally as manager).
- The Phase 5 `admin`/`branch` **cubits call repositories directly** (no use-case
  layer), unlike `auth`/`profile`/`task` — a deliberate scope choice.
- The first admin is still bootstrapped manually in the Firebase console.
- No notifications, no analytics (out of scope).

---

## 2026-06-15 — Rebrand to DROP

Replaces the **FBRO** visual identity with **DROP** across the app.

### Added
- `DropLogo` ([drop_logo.dart](lib/core/widgets/drop_logo.dart)) — renders the
  **DROP wordmark artwork** at `assets/drop_logo.png` (the brand's "DROP" + down
  arrow). The PNG is transparent-background with white-filled glyphs; `DropLogo`
  tints it to the theme color (white) via `BlendMode.srcIn` so it stays crisp on
  the near-black UI, sized by `height`.
- `assets/drop_logo.png` registered in `pubspec.yaml` (`flutter: assets:`).
- The logo now appears on the **splash / loading screen**, **Login** and
  **Register** headers, and the **Pending Approval** screen.

### Changed / Removed
- Removed `FbroLogo` (`fbro_logo.dart`) and all its usages.
- App display name → **DROP** (`MaterialApp.title`, `AppConstants.appName`).

### Notes
- This is a **visual** rebrand. The Dart package name (`fbro`, `package:fbro/…`)
  and the iOS bundle id (`com.example.fbro`) are unchanged — renaming those is a
  separate, higher-risk refactor (every import + native config) and is not
  required for the user-facing brand.
- The logo is tinted **white** for the dark-only UI; if a light theme is wired up
  later, the tint should adapt (or ship a dark-on-light variant).

---

## 2026-06-15 — Phase 4: Task Workflow & Review System

Activates the Phase 3 task foundation into the **real operations workflow** —
managers/admins create + assign, employees execute, managers/admins review — with
a `TaskCubit`, functional role screens, proof images, audit fields and
status-transition rules. Reuses the existing architecture; no foundations rewritten.

### Added
- **`TaskCubit` + `TaskState`** ([cubit](lib/features/task/presentation/cubit/task_cubit.dart))
  driving the workflow for all three roles (loads by role; keeps the list visible
  during mutations; surfaces errors as snackbars). Provided app-wide in
  [main.dart](lib/main.dart).
- **10 task use cases** (`GetAllTasks`, `GetTasksByBranch`, `GetEmployeeTasks`,
  `CreateTask`, `UpdateTask`, `DeleteTask`, `AssignTask`, `ChangeTaskStatus`,
  `ReviewTask`, `UploadTaskProof`) + the auth `GetUsersByBranch` (assignee picker).
- **Functional screens** replacing the Phase 3 placeholders:
  - Employee **My Tasks** — start → complete (notes + optional **proof image**
    via `image_picker`) → submit for review; restart a rejected task.
  - Manager **Branch Tasks** / Admin **Task Management** (shared
    `ManagerTasksView`) — create, edit, **assign** (branch-employee picker),
    delete, and **review** (approve/reject + note).
  - Shared `TaskCard`, `task_action_sheets` (create/assign/review), and
    `TaskEmptyState` widgets.
- **Status-transition validation** in `TaskCubit._canTransition`
  (pending→started→completed→waitingReview→approved/rejected, plus rejected→started
  for redo); invalid moves are blocked with an error.
- **Review audit fields** on `TaskEntity`/`TaskModel`: `approvedBy`/`approvedAt`/
  `rejectedBy`/`rejectedAt`/`reviewNotes` (written together by `reviewTask`).
- **Proof image upload** to Firebase Storage `tasks/{taskId}/proof.jpg`
  (`TaskRepository.uploadProof`); `storage.rules` updated.
- `AuthRepository.getUsersByBranch` + `UserRemoteDataSource.getUsersByBranch`
  (branch employees for the assignee picker).

### Changed
- `TaskRepository` gained `reviewTask` + `uploadProof`; `TaskRemoteDataSourceImpl`
  now also takes `FirebaseStorage`.
- `firestore.rules` (`tasks/{taskId}`): the employee self-update now also forbids
  changing the review-attribution fields (`approvedBy`/`rejectedBy`).
- DI: `AppDependencies.taskCubit` added and wired.

### Notes
- Status-flow order is enforced **client-side** (`TaskCubit`); `firestore.rules`
  still enforce *who* may write. Hardening the transition matrix server-side,
  resolving assignee uid → name on cards, and `users.assignedShift` sync are
  follow-ups. **No notifications, no analytics** (out of scope).

---

## 2026-06-15 — Phase 3: Task Management foundation

Adds the **core FBRO workflow** foundation — managers create/assign tasks,
employees execute them, managers review them. Data + domain + rules + placeholder
UI only; **no task Cubit / use cases / workflow UI yet** (minimal & extensible).

### Added
- **Task enums** in `core/enums`: `TaskType` (daily/special), `TaskStatus`
  (pending→started→completed→waitingReview→approved/rejected) and `TaskPriority`
  (low/normal/high), each with safe `fromString` defaults.
- **`task` feature** with full data + domain layers:
  - `TaskEntity` ([task_entity.dart](lib/features/task/domain/entities/task_entity.dart),
    freezed): `id, title, description?, type, status, priority, branchId?,
    assignedEmployeeId?, createdBy?, assignedShiftId?, deadline?, notes?,
    proofImageUrl?, createdAt?, updatedAt?`.
  - `TaskModel` ([task_model.dart](lib/features/task/data/models/task_model.dart))
    — Firestore (de)serialization for `tasks/{taskId}`.
  - `TaskRepository` (+ `TaskRepositoryImpl`) and `TaskRemoteDataSource`
    (+ `Impl`): list (all / by branch / by employee), get, create, update,
    delete, `assignTask` (employee + optional shift) and `updateStatus`
    (workflow transitions). Datasource throws `ServerException` → `ServerFailure`.
- **Firestore rules** for `tasks/{taskId}` — branch model (admin all · manager
  own branch) **plus a limited employee self-update**: the assigned employee may
  advance status / add notes / proof on their own task but may not reassign,
  change branch/creator, or set the terminal approved/rejected status.
- **Three role placeholder screens** (`task_management_screen` [admin],
  `branch_tasks_screen` [manager], `my_tasks_screen` [employee]) at
  `/admin/tasks`, `/manager/tasks`, `/my-tasks`, reachable via a **Tasks icon**
  in the shared `RoleScaffold` (`RouteNames.tasksForRole`).
- `AppConstants.tasksCollection`; `AppDependencies.taskRepository` (DI wiring).

### Notes
- Admin/manager task routes reuse the existing `_isAdminArea` / `_isManagerArea`
  route guards; `/my-tasks` is self-scoped.
- Screens are functional placeholders only. Proof-image **upload to Storage** is
  not wired yet (`proofImageUrl` is a plain field); the workflow UI and
  `users.assignedShift` sync land in the next phase.
- **Notifications and analytics are intentionally not built** (out of scope).

---

## 2026-06-15 — Phase 2: Shift Management foundation

Adds the shift system foundation (data + domain + rules + placeholder UI) that
manager scheduling and, later, task management build on. Minimal and extensible
by design — **no shift Cubit / use cases / CRUD UI yet**.

### Added
- **`shift` feature** with full Clean-Architecture data + domain layers:
  - `ShiftEntity` ([shift_entity.dart](lib/features/shift/domain/entities/shift_entity.dart),
    freezed): `id`, `name`, `startTime`, `endTime`, `branchId?`, `employeeId?`,
    `isActive`, `createdAt?`, `updatedAt?` (V1 = Morning 08:30–16:30 / Night
    16:30–23:00; strings keep it extensible for weekend/custom shifts).
  - `ShiftModel` ([shift_model.dart](lib/features/shift/data/models/shift_model.dart))
    — Firestore (de)serialization for `shifts/{shiftId}`.
  - `ShiftRepository` (+ `ShiftRepositoryImpl`) and `ShiftRemoteDataSource`
    (+ `Impl`): `getAllShifts`, `getShiftsByBranch`, `getShift`,
    `getEmployeeShift`, `createShift`, `updateShift`, `deleteShift`,
    `assignEmployee`. Datasource throws `ServerException`; repo → `ServerFailure`.
- **Firestore rules** for `shifts/{shiftId}` using the existing
  `canReachBranch()` helper — admin: all branches; manager: own branch;
  employee: their own assigned shift (read-only). First branch-scoped collection.
- **Three role placeholder screens** (`shift_management_screen` [admin],
  `branch_shift_screen` [manager], `my_shift_screen` [employee]) at
  `/admin/shifts`, `/manager/shifts`, `/my-shift`, reachable via a **Shifts icon**
  in the shared `RoleScaffold` (`RouteNames.shiftsForRole`).
- `AppConstants.shiftsCollection`; `AppDependencies.shiftRepository` (DI wiring,
  ready for the shift UI to consume next phase).

### Notes
- Reuses the existing `users/{uid}.assignedShift` field (references the assigned
  `shiftId`) — the user model was **not** redesigned.
- Admin/manager shift routes are covered by the existing `_isAdminArea` /
  `_isManagerArea` route guards; `/my-shift` is self-scoped.
- The screens are functional placeholders only; the CRUD/assignment UI and the
  `users.assignedShift` sync on assignment land in the next phase.

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
