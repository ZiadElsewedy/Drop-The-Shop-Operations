# Changelog

> **Chronological record.** Entries are summarized as they age — an entry earns
> detail while it is still actionable and collapses to a line once it is settled
> history. **Git has the full detail**; this file exists to answer *when* and
> *roughly what*, not to reproduce a diff.
>
> Current status is [CURRENT_STATE.md](CURRENT_STATE.md). Why a decision was made
> is [docs/decisions/](docs/decisions/). How a feature works is
> [docs/design/](docs/design/).

Format: loosely [Keep a Changelog](https://keepachangelog.com). Nothing has been
released — DROP ships from branches and has no version tags.

---

## Unreleased

### 2026-07-18

- **Attendance spec Phase 1 implemented** (critical items — engine + cubit API +
  rules + CF + tests; **no new UI**, wiring awaits design sign-off). (1) **Missed-
  punch recovery**: `checkCorrection` now allows a null record (asserting a start
  time) instead of `recordMissing`; employees file via new
  `AttendanceCubit.requestMissedPunch`; the correction carries a `scheduledStart`/
  `scheduledEnd` window. (2) **Manager direct action**: `AttendanceAdminCubit.addRecord`
  / `resolveDirectly` write an already-`approved` correction (new
  `AttendanceRepository.createResolvedCorrection` + model `toResolvedCreateMap`);
  the resolution is computed through the new single-source `AttendanceResolution.fromRecord`.
  (3) **One server apply path**: `onAttendanceCorrectionWritten` now **upserts** —
  a missing record is materialized (dayKey lifted from the deterministic id) and a
  create-with-`approved` correction applies immediately (skips reviewer notify);
  guarded against concurrent soft-delete. (4) **Validation**: one open correction
  per record (`duplicateOpen`) + a manager `checkManagerEntry` gate (mandatory
  reason, start time, no self-approval). `firestore.rules` gains a reviewer
  approved-create branch. +17 tests (validation, resolution, decide, employee +
  admin cubits); 914 pass / 2 pre-existing splash. **Needs the standing functions +
  rules deploy** to activate server-side.

- **Attendance product spec locked** — [docs/design/ATTENDANCE_SPEC.md](docs/design/ATTENDANCE_SPEC.md).
  Following a full workflow audit, the Attendance module's product behavior was
  frozen: final state machine (adds **Excused**; Absent stays virtual, materialized
  lazily), 20 business rules (early-clock-in window + clamp, missed-punch recovery,
  managers act directly while employees request, one open correction per record,
  auto-close every open session, exception-driven notifications), edge-case rulings,
  and a decision log. Product decisions / technical constraints / future
  enhancements are kept separate. Docs-only; no code changed. The shipped engine
  does not yet implement every locked rule — `clockInLeadMinutes` enforcement,
  missed-punch/manual creation, direct manager resolve, and the Excused outcome are
  the known deltas. [ATTENDANCE.md](docs/design/ATTENDANCE.md) now points to the spec
  as the behavior source of truth.

### 2026-07-17

- **Attendance History ledger + record Details.** The longitudinal history the
  clock screen only hinted at (a 30-row bottom sheet). A summary strip
  (present/late/absent/rate/avg-arrival/worked), a composable filter bar (date
  range · status · shift · reviewer employee search) and a lazy list of per-day
  record cards → an audit-log Details screen (scheduled window · clock in/out +
  GPS · durations · **Timeline** from the server `events` with a record-derived
  fallback · corrections · an expandable **Metadata** block of recorded fields
  only). Two entries share one screen: `/attendance/history` (self, any role) and
  `/attendance/review` (branch ledger, **admin‖manager** via a new
  `_isAttendanceReviewArea` guard — managers' first attendance-oversight surface);
  a record opens `/attendance/record/:id`. **Presentation-only** — reuses the
  existing repository reads (`watchUserHistory`/`watchBranchRange`/`watchEvents`/
  `watchRecordCorrections`) + the pure `AttendanceStats` and a new pure
  `AttendanceHistoryQuery`; no parallel data stack. Summary reflects the date
  window, facets narrow only the list. Entry points: the employee "View history"
  button (→ self); the admin board's new "History" action + "View full record"
  sheet button; and — since managers had no attendance surface at all — a new
  manager sidebar entry (+⌘K) and home-screen tile (→ branch review). **Held
  ADR-009 + ADR-010**: performance score, analytics/heatmaps,
  CSV/PDF export and payroll were declined (the ledger is shaped to feed them
  later), and Metadata shows only recorded fields — no invented
  timezone/appVersion/syncStatus. +22 tests (query · status filter · cubit ·
  widget render). The list uses a plain `ListView` (the pattern every other DROP
  list screen uses).

### 2026-07-16

- **Admin dashboard → calm, state-aware command center** (owner-directed
  refinement of Admin Dashboard V2). The hero eyebrow now carries data freshness
  ("date · Synced 3m ago") and the subtitle is **one** live state sentence off a
  single needs-attention total — calm "All caught up" (grey pulse) vs
  "N tasks need your attention" (amber pulse), so hero and grid never disagree
  (`dashboard_mood.dart` collapsed from a 3-tone model to two states). **Needs
  attention** is now **one grouped box** (owner-approved from a live A/B/C
  preview): a calm "all clear" summary when every queue is empty, otherwise
  triage **rows** most-urgent-first inside a single living border — a fresh signal
  slides in as a row (`LiveListItem`) instead of the whole grid re-appearing, and
  cleared signals collapse to a quiet footer. **Today** counts up its figures
  (`Stat.count`, ~650ms), Delayed
  reads warning (was error) and Approval rate reads success. Desktop centres in a
  ~1260 column with a 360px right rail; **Manage** trims to Tasks / Schedules; the
  **staffing banner** and **branch pulse** were dropped (owner ruling). Strictly
  monochrome, dark-only, existing primitives only (ADR-004).
- **Task create speed-up.** Added and refined Schedule quick deadline presets
  (`Tomorrow`, `2 days`, `Week`) that start at creation time and set the due
  window without opening the date/time pickers; the presets now use a compact
  duration rail with an animated thumb and animated duration line.
- **Create Task sheet visual polish.** Kept DROP's strict monochrome direction,
  then added neutral tonal depth, a composed animated header, softer picker hover
  lift, richer segmented controls, and a staggered final CTA. All new motion
  collapses under reduced-motion settings; task save/data flow is unchanged.

### 2026-07-15

- **Documentation restructured.** The doc set had reached 16,669 lines across 23
  files and was contradicting itself (it claimed indigo `#5B5FEF` was the accent
  months after deletion, and gave three different test counts in one file). Rebuilt
  around single responsibility: PROJECT_CONTEXT (architecture) · CURRENT_STATE
  (today) · CHANGELOG (history) · `docs/design/` (per-feature) · `docs/decisions/`
  (ADRs). ~90% smaller on the read-before-every-task path.
- **Removed: Schedule Health** — the `domain/health/` analyzer, its 5 rules, the
  facade, the below-grid overview surface, and 4 test files (−2,769 lines). The
  insight strip above the grid is now the only staffing signal. Per-employee stats
  keep *days worked*, drop the morning/night split.
  → [ADR-007](docs/decisions/ADR-007-schedule-health-removed.md)
- **Attendance Phase 3 (engine + UI): GPS-verified clock in/out.** `geolocator` +
  pure `attendance_gps.dart` (Haversine + `AttendanceVerification`), `BranchGeofence`
  per branch, separate clock-in/clock-out verifications, server-timestamped times,
  `checkGpsFix` gate. Employee clock screen (`/attendance`), admin schedule ×
  attendance board (`/admin/attendance`), geofence editor. Clock-out records
  verification but is never GPS-blocked.
- **Removed: attendance breaks** — descoped for MVP; `AttendanceBreak` and the
  calculator's netting kept as dormant extension points.
- **Removed: Community Hub / DROP Events** — the feature, 4 tests, 3 enums, all
  routes/nav/DI wiring, and its Firestore + Storage rules. Live data untouched.

### 2026-07-14

- **Attendance Phase 2: corrections + server-authoritative audit.** The audit trail
  (`attendance/{id}/events`) is now derived and written **only** by the Admin SDK —
  clients cannot forge it. `attendance_corrections/` is a first-class
  Pending → Approved/Rejected approval object reusing `RequestStatus`, with
  self-approval forbidden server-side. Functions `onAttendanceWritten`,
  `onAttendanceCorrectionWritten`, `autoCloseAttendance`.
  → [ADR-005](docs/decisions/ADR-005-server-authoritative-writes.md)

### 2026-07-13

- **Automated Task Engine hardening.** Fixed a duplicate-task bug on
  reopen → re-approve via deterministic `rec_{sourceTaskId}` ids
  (`createTaskWithId`). `generateShiftTaskInstances` made atomic, notifying, and
  roster-filtered. ⚠️ The Automation Center it exposes sits behind one unlabeled
  icon and has never been seen by the owner.

### 2026-07-11

- **Task lifecycle hardening.** New `TaskRepository.transitionTask` — a transaction
  that verifies the expected predecessor status, appends the `ActivityEntry` to the
  **server's** log, and bumps an additive `TaskEntity.version`. Fixes the
  concurrent-reviewer race. Rules freeze review fields and require a non-decreasing
  `activityLog`. Declined as over-engineering: `schemaVersion`, `deviceInfo`.
- **Media upload V2.** New `core/media/` seam — `MediaUploadService` is the single
  Storage upload for task/case/request, plus `media_processing.dart` (crop/compress,
  mobile-gated), `mapPooled` (concurrency cap 3), `UploadCanceller`, partial-retry
  cache, and upload analytics.

### 2026-07-10

- **Notifications V2.** New pure resolver `notification_deep_link.dart` —
  `resolveNotificationRoute` is the single seam for both the tile tap and the FCM
  tap (`null` = safe no-op → inbox). Fixed 5 routing bugs. Broadcast deep-links now
  self-resolve when opened cold. ⚠️ iOS push still unconfigured.

### 2026-07-08

- **Requests: settled as approvals, not tickets.** Statuses reduced to
  Pending → Approved/Rejected; create made employee-only (so self-approval is
  structurally impossible — no guard needed); admin gets soft delete + reopen.
  Fixed an infinite-height freeze in the empty state.
  → [ADR-008](docs/decisions/ADR-008-requests-are-approvals.md)
- **Design System V2** — `PageHero` · `AttentionTile` · `StatStrip` · `ActivityCard`;
  the 4-step grey ramp; Admin Dashboard V2 closed and owner-signed-off.
- **Task Scheduling V2** — additive `startsAt`/`dueAt`, derived `TaskSchedulePhase`
  (not a persisted status), roster-aware smart shift defaults, never locked.
- **Work Details design system** — one language, composed per work type.
- Community Hub / DROP Events shipped (removed a week later, 2026-07-15).

### 2026-07-07

- **Work-type framework** — polymorphic tasks via Strategy + Registry: adding a type
  is 1 file + 1 line. Unknown types degrade to `general`. `workType` + `data` are
  additive, no migration.
- **Configurable shift hours** — shift end times became *data, not code*
  (`ShiftHours`, `end > 1440` = overnight), with per-week overrides.
  → [ADR-006](docs/decisions/ADR-006-schedule-shift-plan-snapshots.md)
- **Employee My Week frozen by owner ruling** — premium UI kept; in-language
  improvements only.
- Multi-line day notes + premium employee shift sheet. Fixed a desktop sidebar idle
  freeze and a My Schedule shift-window API mismatch.

### 2026-07-06

- Task Details activity timeline rework — hero current-status head + ledger rows.
- Schedule 5.0 — day-level leave + notes, Final View.
- `LiveStatusBorder` per-state colour palette. **Motion is load-bearing — do not
  change it.**

### 2026-07-05

- Schedule Final View + real PNG export. One-time employee Welcome screen. Branch
  Operations premium KPI drill-downs. Communications feed bulk selection. Mobile
  splash premium pass. Fixed a recurring shift-task save freeze.

### 2026-07-04

- **Case Management System** — Reports reframed as private employee ↔ manager/admin
  conversations, with a rule-enforced confidential reporter split
  (`cases/{id}/reporter/identity`) and a realtime `messages` subcollection.
- Premium animated cold-start intro. Admin Task Management Active/Done pages. Admin
  dashboard risk-first review + Sync control.

### 2026-07-03

- Home Dashboard redesign (P1–P3 + R1) — global task feed, Attention strip, Smart
  Queue, task retention lifecycle. *Superseded on Admin Home by Design System V2
  five days later.*
- Compensation moved to the private subdoc `users/{uid}/private/compensation`.
- M1/M2/M3 hardening + C1 deployments.

### 2026-07-02

- **Phase 2 premium desktop UX** — Schedule 3.0 grid, executive dashboard, person
  inspector, ⌘K command palette.
- **Phase 3 observability** — `CrashReporter` (4 funnels → a report persisted across
  launches, even in release) + `CrashContext` + `AppLog`.
- **Fixed: total macOS navigation freeze** — the `ShellRoute` child was wrapped in an
  `AnimatedSwitcher`, duplicating go_router's shell Navigator `GlobalKey`. Never do
  this; the desktop fade lives at the page level instead.
- Schedule 4.0 (overflow · mobile actions · undo · validation) and 3.1
  (drag-to-switch). macOS app icon. DROP logo rollout. Production audit + beta plan
  + auto-schedule design exploration.

### 2026-07-01

- **Shift Assignment** — a task can target a *shift* rather than named people,
  visible only to whoever is rostered on it that day (`canUserAccessTask`).
  Recurring shift routines use a template → generated-instance split.
- **Monochrome revert** — the desktop-first redesign's indigo accent was reverted.
  → [ADR-004](docs/decisions/ADR-004-monochrome-design.md)
- Desktop punch-list: 10 screens onto `AdaptiveScaffold`. macOS keychain login fix
  (`DebugProfile.entitlements` `keychain-access-groups`), photo-upload sandbox
  entitlement, window sizing, responsive card grids.

---

## June 2026 — foundation

Summarized. Detail is in git.

### 2026-06-30
- ✓ Full rebrand: Dart package `fbro` → `drop` (repo folder + iOS bundle id still `fbro`).
- ✓ Desktop-first UI — `ShellRoute` + persistent role-aware sidebar. *(Its indigo accent was reverted the next day.)*
- ✓ Premium macOS desktop foundation + polish (schedule grid, task ticket, comms command-center).
- ✓ Fixed macOS login "No internet connection" (sandbox networking).

### 2026-06-28
- ✓ Branch cover photo on the admin task overview.
- ✓ Input validation on user-detail fields.
- ✓ Fixed account-switch push failure on a shared device.

### 2026-06-27
- ✓ Branch identity in tasks — cover banner + logo chip.
- ✓ Permanent delete for a sent broadcast (not the old soft-delete).
- ✓ Per-token FCM dispatch diagnostics. Fixed a stuck iOS keyboard in the template sheet.

### 2026-06-26
- ✓ **Auth & account provisioning redesign** — admin-only accounts; registration, OTP, Google, email verification, and the approval flow all removed. `isActive` became the sole access gate.
- ✓ **FCM token ownership** made exclusive, enforced server-side by `claimFcmToken` — fixes cross-user leak on a shared device.
- ✓ **Shift Swap hardening** — server-authoritative atomic exchange via the `approveSwap` callable; rules deny any client write setting `managerApproved`.
- ✓ Admin-editable user contact details. Token-leak audit. Activity timeline V2.

### 2026-06-25
- ✓ **Premium UX/Logic Refactor** (slices 1–2b, §5, §8–§9b) — correctness fixes, the premium component system (`AppGlassCard`, `MetricPill`, `PremiumButton`), branch media + `BranchAvatar`, brand primitives (`DropWordmark`, `DropEmptyState`, `DropLoadingState`), and the notification **operational inbox**.
- ✓ Shift Swap System — exchange model + swap notifications.
- ✓ **De-flash: premium ≠ flashy** — owner ruling; monochrome + subtle status glows only.
- ✓ Realtime polish — animated counters, smooth Pending Review list. Release stabilization + FCM routing audit.

### 2026-06-24
- ✓ **Performance Phases A–D** — reload/refetch guards, repository-level branch + template caches, warm-start preload, rebuild scoping. Plus regression fixes (offline admin stats, task stream scope).
- ✓ Simplification slices 3b–4b — dropped broadcast soft-delete, collapsed comms nav, merged categories 4→3, and **removed the Priority + Delivery-channel selectors** (delivery is derived from category).
- ✓ Schedule grid premium redesign — faces + names per shift.

### 2026-06-23
- ✓ **Killed the analytics pipeline** — open/read rate, monthly rollups, and charts deleted as vanity. Kept minimal delivery diagnostics. → [ADR-009](docs/decisions/ADR-009-no-analytics-pipeline.md)
- ✓ Lean Notification Center; task notifications open the exact task. `NotificationType` trimmed to the 11 values with a live producer.

### 2026-06-22
- ✓ **Communications Center Phase 2, Commits 1–6** — schema foundation + Broadcast History, templates + placeholder engine + premium composer, advanced recipient targeting, scheduled/recurring broadcasts, the task reminder engine, and analytics aggregation. *(Commit 6's analytics was deleted the next day.)*

### 2026-06-21
- ✓ **Communications Center Phases 1–3** — broadcast vertical slice, the `sendBroadcast` Cloud Function send engine, and the role-gated Center UI. End-to-end.
- ✓ **Branch Operations cockpit** — shift tag + workload aggregation, cubit, screens.
- ✓ Task submission media: loading UX + progress, the Submission Details review sheet, real video thumbnails. Assign employees while creating a task.

### 2026-06-20
- ✓ Task submission media upgrade — multiple images & videos per submission, attached to task events.
- ✓ Schedule assignment-grid redesign — **no staffing quotas**; assigned head-count only.
- ✓ Shift-swap hardening + Admin Pending Actions. Premium UI redesign (Branch Schedule, Admin Home, Task timeline).

### 2026-06-19
- ✓ Admin command-center redesign + reusable component library.
- ✓ Employee schedule premium redesign.
- ✓ Task proof upload + admin task experience.

### 2026-06-18
- ✓ **Task Workflow Architecture: single-write state machine** — status + activity in one write. Never split them again.
- ✓ **Operations Workflow Upgrade** — `RecurrenceConfig`, `ActivityEntry`, Task Details screen, My Tasks redesign.
- ✓ Employee Home Screen redesign v2. Inline checklist editor; task form simplified. App icon & name. Proof submission error visibility.
- ✓ Task UX overhaul — monochrome cards, "Assigned by", username removed as a legacy social field.

### 2026-06-17
- ✓ DROP THE SHOP UI redesign + Tasks crash fix.
- ✓ Shared component system — `StatusBadge`, `AppCard`, context helpers, form & layout primitives.
- ✓ Architecture de-duplication & shared utilities. Stability & UX audit.

### 2026-06-16
- ✓ **Phase 7 — Weekly Schedule & Shift Swap** (the production roster).
- ✓ **Phase 8** — QA, hardening & UI polish. **Phase 9** — task UX, admin UX & design overhaul (checklists, multi-assignee).
- ✓ **Phase 10** — production hardening; deleted the dead Phase 2 `shift` feature.
- ✓ Stabilization & workflow integration — fixed a broken build (`pubspec.yaml` name), the admin branch dropdown, realtime task streams, task templates.

### 2026-06-15
- ✓ **Phase 2** — Shift Management foundation *(later deleted as dead code)*.
- ✓ **Phase 3** — Task Management foundation. **Phase 4** — Task Workflow & Review System.
- ✓ **Phase 5** — Admin Management module. **Phase 6** — Operations Dashboards & Notifications.
- ✓ Rebrand to DROP.

### 2026-06-14
- ✓ **Phase 1 — Roles & Foundation**: `UserRole`, role-based routing + guards, role shells, security rules.
- ✓ Design system: **monochrome B&W/grey — indigo reverted**. → [ADR-004](docs/decisions/ADR-004-monochrome-design.md)
- ✓ Account approval flow *(removed 2026-06-26)*. Production profile system.

### 2026-06-13
- ✓ Authentication feature set — sign-in, forgot password, change password, profile module, settings.
- ✓ Project bootstrapped: Flutter + Firebase, Clean Architecture, Cubits.
  → [ADR-001](docs/decisions/ADR-001-firebase-backend.md) · [ADR-002](docs/decisions/ADR-002-cubit-only.md) · [ADR-003](docs/decisions/ADR-003-clean-architecture.md)
