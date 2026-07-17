# DROP — Current State

> **Today's snapshot. Nothing historical.** The moment something here becomes
> history, it moves to [CHANGELOG.md](CHANGELOG.md) and leaves this file.
>
> **Last verified against the code:** 2026-07-16.

## At a glance

| | |
| --- | --- |
| **Branch** | `feature/attendance-management` |
| **Build** | `flutter analyze` clean (1 pre-existing info) |
| **Tests** | **875 pass · 2 fail** across 134 files (~18s) — see [Known issues](#known-issues) |
| **Blocking release** | Firebase deploy (rules · indexes · functions) · iOS push unconfigured · attendance on-device QA |
| **Platforms** | iOS · Android · macOS |

DROP is **feature-complete for its intended scope** and gated on deployment and QA,
not on code. The largest open risk is that a growing set of features depend on Cloud
Functions and rules that have **never been deployed** — they fail at runtime, not at
compile time.

---

## Branches

| Branch | Holds | State |
| --- | --- | --- |
| **`feature/attendance-management`** ← current | Attendance P1–P3 (data · corrections · GPS · UI) | Committed, **not merged**, deploy + QA pending |
| `main` | Trunk | Behind this branch |
| `feature/media-upload-v2` | Media hardening + Automation Engine | Committed (`e3bf049`), needs deploy |
| `core/optimization` | Design System V2, Task Scheduling V2 | Merged to `main` via PR #14 |
| `feature/macos-desktop` | Desktop shell, Schedule 3.0–4.0, ⌘K | Landed |
| `feature/notifications-v2` | Notifications V2 pilot | Committed, functions undeployed |

~15 other stale feature branches exist from earlier phases and are candidates for
pruning. `Community-Hub` is **dead** — the feature was removed 2026-07-15.

---

## Features

### Complete

| Feature | Notes |
| --- | --- |
| **Auth** | Admin-provisioned email/password. No registration/Google/OTP/approval. First-login gate: force password change → profile completion → (employees) Welcome → role home |
| **Roles & routing** | 40 routes, role-guarded. admin ⊇ manager |
| **Profile** | View/edit, avatar/cover upload, contact + payment (payment in a private subdoc; hidden for admin) |
| **Tasks** | Full workflow: create → execute (checklist · notes · proof) → review. Multi-assignee, recurrence, activity timeline, templates, shift assignment, work-type framework, Scheduling V2 (start/due windows + quick deadline presets). Create Task sheet has a premium monochrome surface/motion pass. |
| **Schedule** | Weekly roster, shift swaps, leave, day notes, configurable shift hours, shift templates, Final View + PNG export |
| **Branches** | CRUD, soft delete, swap policy, GPS geofences |
| **Admin** | User administration, account provisioning, Admin Home V2 command center |
| **Operations** | Branch Operations cockpit, workload derivation, KPI drills |
| **Communications** | Broadcasts, templates, custom audiences, scheduler, reminders |
| **Notifications** | In-app inbox + deep-link resolver. **Android push only** |
| **Cases** | Private employee ↔ manager/admin conversations, confidential reporter split |
| **Requests** | Employee → manager yes/no approvals |
| **Statistics** | Live role-scoped counts on all three dashboards |
| **Design system** | Monochrome V2 primitives. Admin Dashboard V2 owner-signed-off |
| **Observability** | `AppLog` + `CrashReporter` (4 funnels, persisted across launches) |

### In progress

**Attendance** — the only feature not closed out. Code is complete across all three
phases and committed; what remains is deployment and on-device verification.

| Phase | State |
| --- | --- |
| P1 — data foundation | Done. Deterministic `attendance/{uid}_{yyyyMMdd}_{shift}` id, `AttendanceCalculator` |
| P2 — corrections + audit | Done. Server-authoritative audit + `attendance_corrections/` approval object |
| P3 — GPS engine | Done. `geolocator`, Haversine verification, separate clock-in/out verifications |
| P3 — UI | Done. Employee clock screen · admin board · geofence editor |
| **Deploy** | ❌ **Not done** — functions + rules + indexes |
| **On-device QA** | ❌ **Not done** — GPS needs real hardware; simulators cannot validate this |

> Attendance minutes feed payroll. Do not ship it on a simulator's word.

### Removed — do not re-add

| Feature | Removed | Why |
| --- | --- | --- |
| **Schedule Health** | 2026-07-15 | [ADR-007](docs/decisions/ADR-007-schedule-health-removed.md) — advice that never gated anything |
| **Community Hub / DROP Events** | 2026-07-15 | Owner request. Live Firestore data left untouched |
| **Analytics pipeline** | 2026-06-23 | [ADR-009](docs/decisions/ADR-009-no-analytics-pipeline.md) — vanity metrics |
| **Attendance breaks** | 2026-07-15 | Descoped for MVP. `AttendanceBreak` kept as a dormant extension point |
| **Shift foundation (Phase 2)** | Phase 10 | Dead code; the weekly schedule is the roster |
| **Public registration / OTP / Google** | 2026-06-26 | DROP is admin-provisioned |

---

## Known issues

### Failing tests (2)

`test/splash_centering_test.dart` — both cases fail. The splash lockup's optical
centering is off: the combined logo→bar bounding box centre sits at **375.5** where
the test expects **400 ±1** (and **291.7** vs **310 ±1** at 1024×720). Either the
splash layout regressed or `kSplashOpticalLift` changed without the test following.
**Pre-existing and unrelated to any current work** — but it means `flutter test` is
not green, so a real regression could hide behind it. Worth fixing or deleting.

### Configuration gaps

- **iOS push is unconfigured** — no entitlements, no `aps-environment`, no APNs key.
  FCM cannot deliver to iOS. Android works. This has been open since Phase 11.
- **Firebase Storage** must be enabled in the console for proof/media uploads.
  A "not authorized" error on upload is *this*, not a code bug.
- **First admin** is bootstrapped out of band (set `role: admin`, `isActive: true`
  in the console).

### Accepted debt

- **Light theme** exists in `AppTheme.light` but is not wired up — the app is
  hardcoded to dark in `main.dart`.
- **Legacy social fields** (`followersCount` / `followingCount` / `postsCount` /
  `likesCount`) linger on `ProfileEntity`, unused. Safe to delete.
- **Account deletion** removes the Auth user but leaves `users/{uid}` in Firestore.
  Needs an `auth.user().onDelete` function.
- **`automationRuns` telemetry has no reader.** By [ADR-009](docs/decisions/ADR-009-no-analytics-pipeline.md)'s
  own test it should be deleted unless someone names the decision it changes.
- **44 `developer.log` calls across 17 files bypass `AppLog`** (was 35/10 — drifting).
  Their output is *not* captured in the breadcrumb ring, so those events are missing
  from crash reports — a real observability gap, given `AppLog` claims to be the
  single entry point. Each site needs a scope/category judgment, so it's a staged
  consistency pass, not a sweep. (`print()` calls: 0.)
- **`savedAudiences`** is declared in `app_constants.dart` with no reads and no rules.
  Delete or implement.
- **Non-realtime lists** — tasks are fully streamed; schedule/branch/admin/swap
  lists reload after mutation + pull-to-refresh.
- **Stats aggregate client-side.** If data grows, move to Firestore `count()`.

---

## Pending work

### 🚨 Deploy (the critical path)

Nothing below works in production until it is deployed. Each has been "pending" for
a while; treat this list as **believed-pending and worth verifying against the
console** before assuming.

| Target | Carries | Blocks |
| --- | --- | --- |
| `functions` | 21 functions incl. `onAttendanceWritten`, `onAttendanceCorrectionWritten`, `autoCloseAttendance`, `generateShiftTaskInstances`, `onCase*`, `onRequest*`, `sendBroadcast`, `claimFcmToken` | Attendance audit · automation · cases · requests · **all push** |
| `firestore:rules` | Task review-field freeze + non-decreasing `activityLog`; attendance + corrections; cases; requests | Task hardening (P0/P1), attendance, cases |
| `firestore:indexes` | `tasks` composite (`branchId`+`assignmentType`+`shift`) | Employee shift-task stream — fails `failed-precondition` without it |
| `storage` | `validMedia()` + orphan GC | Media hardening |

```bash
firebase deploy --only functions,firestore:rules,firestore:indexes,storage
```

Requires the **Blaze** plan.

### Then

1. **On-device attendance QA** — GPS clock in/out on real hardware, both platforms.
2. **Fix or delete `splash_centering_test.dart`** so the suite is green.
3. **Configure iOS push** — APNs key + Push/Background-Modes capability.
4. **Merge `feature/attendance-management`** once deployed and QA'd.
5. **Show the Automation Center to the owner.** It has never been seen: it is a
   bottom sheet behind **one unlabeled icon** on `BranchOperationsScreen`. Built,
   committed, effectively invisible.
6. **Prune ~15 stale branches.**

---

## Active architecture decisions

Full records in [docs/decisions/](docs/decisions/). The ones most likely to be
unknowingly reversed:

| Decision | Don't |
| --- | --- |
| [ADR-004](docs/decisions/ADR-004-monochrome-design.md) — monochrome | Add a brand colour. Indigo has been rejected twice |
| [ADR-007](docs/decisions/ADR-007-schedule-health-removed.md) — no Schedule Health | Re-add scoring. Direction flipped twice already |
| [ADR-008](docs/decisions/ADR-008-requests-are-approvals.md) — Requests are approvals | Add statuses, assignment, or priority |
| [ADR-009](docs/decisions/ADR-009-no-analytics-pipeline.md) — no analytics | Build a metric without naming the decision it changes |
| [ADR-005](docs/decisions/ADR-005-server-authoritative-writes.md) — server-authoritative | Let a client write its own audit trail |
| [ADR-010](docs/decisions/ADR-010-lean-over-enterprise.md) — lean | Reach for the enterprise shape |

**Owner-frozen surfaces** — improve in-language, never replace without sign-off:

- **Employee My Week** (premium hero + week cards) — frozen 2026-07-07.
- **`LiveStatusBorder` orbit** — motion is load-bearing; per-state colours have been
  changed many times. Confirm before touching colours; never touch the motion.
- **Admin Dashboard V2** — closed and signed off.

---

## Current priorities

1. **Deploy.** Everything else is downstream of it. A growing share of the app is
   inert in production and fails at runtime rather than at compile time.
2. **Close out attendance** — on-device QA, then merge.
3. **Get the suite green** — 2 failures is 2 too many to notice a third.
4. **Surface what's already built.** The Automation Center is invisible; the
   attendance UI is unseen. Shipped-but-unreachable is indistinguishable from
   not-built.

---

## Verifying this file

If you change status, gaps, or priorities, update this file **in the same task**.

```bash
flutter analyze                          # expect: 1 info
flutter test                             # expect: 875 pass, 2 fail (splash)
grep -c "static const String" lib/core/routes/route_names.dart   # expect: 40
ls lib/features | wc -l                  # expect: 17
```

Routes live in [route_names.dart](lib/core/routes/route_names.dart) — read them
there rather than duplicating the table here. Firestore/Storage schema lives in
[docs/design/DATA_MODEL.md](docs/design/DATA_MODEL.md).
