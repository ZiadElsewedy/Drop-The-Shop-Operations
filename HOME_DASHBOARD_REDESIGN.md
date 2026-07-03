# DROP — Home Dashboard Redesign & Task Lifecycle Architecture

> **Design + architecture proposal** (2026-07-03, design only — no code in this
> pass). Scope: the **admin + manager home dashboards** and the **completed-task
> lifecycle**. Companion docs: [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) ·
> [AUTO_SCHEDULE_DESIGN.md](AUTO_SCHEDULE_DESIGN.md) (format precedent).

---

## 0. Reconciliation with locked rulings (read first)

Three items in the brief conflict with standing owner rulings. Per the
precedent set in the 2026-07-02 UI/UX audit ("two owner rulings were applied
over the brief"), this proposal resolves them as follows — each is one line to
change if you re-rule:

| Brief asks | Standing ruling | This proposal |
| --- | --- | --- |
| Indigo accent `#5B5FEF` | **Strictly monochrome** — indigo reverted twice (2026-06-17, 2026-07-01); `AppColors.accent` = white | Designed monochrome. Every accent use goes through the single `AppColors.accent` token — flipping it to `0xFF5B5FEF` re-skins the whole dashboard in one line, **only if you explicitly re-rule**. |
| "Enterprise-grade, Linear/Notion/Stripe" | **Lean, not enterprise** (product philosophy) | Interpreted as *polish quality*, not feature surface. Enterprise-shaped features in the brief (saved-view builder, health score) are trimmed below with reasons. |
| **Branch Health Score** KPI | **Facts, never quotas** — coverage %/composite scores are a settled rejection (Schedule 2.0/3.0) | Replaced with a **Needs-attention fact chip** (overdue · in review · unassigned counts). A composite score hides which fact is wrong; three counts *are* the diagnosis. |

Everything else in the brief is adopted.

---

## 1. Diagnosis — why the current home fails operations

**The navigation tax.** To see live work today an admin walks
`Tasks → AdminTaskOverviewScreen (branch cards) → BranchTaskListScreen →
TaskDetailsScreen` — **3 hops before the first task title**, and the branch →
employee mental model forces you to know *where* a problem is before you can
see *that* it exists. The screenshot you attached is hop 2.

**The data is already there.** `TaskCubit` is app-wide, warm-preloaded at
sign-in, and already holds a **live all-branches snapshot stream** for admin
(`watchAllTasks`) and a branch stream for managers (`watchTasksByBranch`).
The homepage simply doesn't render it. This redesign is therefore almost
entirely **presentation-layer** — zero new Firestore queries for the feed.

**The duplicate badge.** `TaskCard` stacks two pills that say the same thing:
`taskBadgeFor()` returns an "Approved"/"Rejected" lifecycle badge
([task_badge.dart:18-23](lib/features/task/presentation/widgets/task_badge.dart))
*and* `_StatusPill` renders "Approved" from the same status two rows down
([task_card.dart:101-115](lib/features/task/presentation/widgets/task_card.dart)).
Redundant signal = the opposite of premium.

**Done tasks never leave.** Approved tasks stay in every list and every
stream forever — clutter now, unbounded snapshot growth later.

---

## 2. Information architecture

### Principle: **Home = the operational surface, not a menu.**

Admin and manager homes become a **command surface** whose primary object is
the **global active-task feed**. Everything above the feed is a *lens* onto
it (KPIs filter it; branch rows scope it), never a dead-end number.

**Employee home is out of scope** — employees execute rather than monitor;
their home (progress ring + actionable list) already matches their job.

### Reach-any-task guarantee

| Journey | Before | After |
| --- | --- | --- |
| See any active task | Home → Tasks → Branch → list (3) | **On the homepage (0)** |
| Open its details | +1 = 4 taps | **1 tap** (feed row → `TaskDetailsScreen`) |
| All overdue, everywhere | not possible | 1 tap (Overdue preset / KPI) |
| One branch's tasks | 2 taps | 1 tap (branch-pulse row or scope menu) |

### Wireframe hierarchy — desktop (≥1024pt, macOS primary)

```
┌────────────┬──────────────────────────────────────────────┬─ 330px rail ──┐
│            │ Good morning, Salah · Thu 3 Jul        [⌘K]  │ PENDING       │
│  Sidebar   │ ⚠ 3 overdue · 2 in review        ← attention │  Reviews (2) →│
│  (exists)  │──────────────────────────────────────────────│  Swaps (1)  → │
│            │ ┌────────┬────────┬────────┬────────┐        │───────────────│
│            │ │ ACTIVE │OVERDUE │ REVIEW │ DONE   │ ← KPI  │ Quick actions │
│            │ │   14   │  3 ⚑   │   2    │ today 6│  strip │  (exists 2-up)│
│            │ └────────┴────────┴────────┴────────┘        │───────────────│
│            │──── sticky ──────────────────────────────────│ BRANCH PULSE  │
│            │ [All branches ▾][Overdue][Review][Due today] │  Arkan   4·1 →│
│            │ [Unassigned]  🔍 search   group: Due ▾  ⇅    │  Maadi   6·0 →│
│            │──────────────────────────────────────────────│  (row taps    │
│            │ ▾ OVERDUE (3)                                │   scope feed) │
│            │   ● open the shop      Arkan  RI Rich  27 Jun│               │
│            │   ● clean the boxes    Arkan  ZE Ziad  27 Jun│               │
│            │ ▾ TODAY (5)                                  │               │
│            │   ● gard represent     Arkan  RI Rich  28 Jun│               │
│            │ ▸ THIS WEEK (4)   ▸ LATER (2)                │               │
└────────────┴──────────────────────────────────────────────┴───────────────┘
```

- **Main column** = greeting/attention → KPI strip → **feed** (the page's body).
  The current main-column `_ActivityFeed` is **removed** — the live feed *is*
  the activity surface now (both derive from the same stream; two live lists
  of the same events is noise). The rail is unchanged.
- **Manager home**: identical feed, branch-locked (no scope menu, no branch
  grouping option); KPI strip already exists as branch metrics — gets tap-wiring.

### Wireframe hierarchy — mobile

```
AppBar (DropLogo · greeting · bell)
KPI strip → horizontal 2×2 grid (tappable, same wiring)
Filter chips → single horizontally-scrolling row (sticky)
  [Overdue][Review][Due today][Unassigned] [branch ▾] [🔍]
Feed → same grouped list, TaskFeedRow relaxes to 2 lines
```

---

## 3. The Global Task Feed (core deliverable)

### 3.1 What's in the feed

**Active work only**: `pending · started · waitingReview · rejected`, plus
`approved` **today** (so "Done today" is visible, precedent:
[active_window.dart](lib/features/task/domain/active_window.dart)). Older
approved tasks are lifecycle-managed out (§5). `completed` (legacy limbo
state) is included with `waitingReview`.

### 3.2 Filter model — one immutable value object

```dart
/// lib/features/task/domain/task_feed.dart  (pure Dart, unit-tested —
/// same pattern as move_validation.dart / schedule_insights.dart)
class TaskFeedFilter {
  final String? branchId;        // null = all branches (admin only)
  final String? assigneeUid;     // employee filter
  final ScheduleShift? shift;    // morning / night (task.shift)
  final TaskPriority? priority;
  final TaskStatus? status;
  final String query;            // smart search (see 3.4)
  final FeedPreset? preset;      // overdue / review / dueToday / unassigned
  final FeedGrouping grouping;   // due (default) / branch / employee / priority
  final FeedSort sort;           // dueDate (default) / priority / newest
}

List<TaskEntity> applyFeed(List<TaskEntity> all, TaskFeedFilter f, DateTime now);
List<FeedGroup> groupFeed(List<TaskEntity> filtered, FeedGrouping g, {directory, branchNames});
```

Filtering is **client-side over the existing stream**. Rationale: the active
set per scope is 10²-sized in this product's reality (small-team internal
tool); a pure O(n) pass per rebuild is free, needs **zero composite indexes**,
and makes every filter combination instant and offline-capable. Server-side
filtering is the enterprise reflex we don't need — revisit only if a scope
exceeds ~1–2k live tasks.

### 3.3 Presets — fixed, not a saved-view builder

Four **pinned presets** as one-tap chips (compound filters):

| Preset | Definition | Why it earns a chip |
| --- | --- | --- |
| **Overdue** | `deadline < now`, non-terminal | The #1 operational question |
| **Needs review** | `waitingReview` | The manager's queue — money left on the table |
| **Due today** | deadline ∈ today | The shift-start briefing |
| **Unassigned** | `assigneeIds.isEmpty` ∧ individual/team type | Work that will silently not happen |

A **user-defined saved-view builder is rejected** (5-question filter: at this
team size nobody maintains a view library; it's Jira furniture). "Morning
shift tasks" from the brief = the shift filter chip — one tap, no saved view
needed. If a real recurring combination emerges in use, promote it to a fifth
preset in code (a 3-line change) rather than shipping view-management UI.

### 3.4 Search, sort, grouping

- **Search**: case-insensitive substring over title · description · resolved
  assignee names · branch name. Debounced 200ms, filters in place. No search
  service/index — the haystack is already in memory.
- **Sort**: due date (default — operations is deadline-driven), priority,
  newest. Sort applies *within* groups.
- **Grouping** (collapsible headers, count + `AnimatedCount`, chevron):
  - **Due time (default)**: Overdue / Today / This week / Later / Done today.
    *Why default:* urgency buckets answer "what do I act on now?"; defaulting
    to branch grouping would rebuild the exact branch-first mental model this
    redesign exists to kill.
  - **Branch** (admin only) · **Employee** · **Priority** — one segmented menu.
  - Collapse state is per-session (`PageStorageKey`), not persisted.

### 3.5 `TaskFeedRow` — the dense row (new widget)

The full `TaskCard` is a reading surface; a monitoring feed needs a **28–36px
scanning row** (Linear-style). One line, fixed columns:

```
● In progress   Open the shop            [Arkan] [⚑] ZE Ziad   Due 28 Jun
▲status dot+pill ▲title (flex, w600)     ▲chips  ▲High ▲avatar+name ▲due (red if overdue)
```

- Status = small dot + short label from the **canonical `taskStatusColor`**
  (no third colour map — same rule as the card).
- Checklist progress: a **2px underline track** across the row bottom (only
  when a checklist exists) — progress without a fat bar.
- Priority: **High only** shows ⚑ (existing noise ruling; Medium/Low show
  nothing).
- Overdue: due label turns `AppColors.error` + "· Overdue". No pulsing.
- Hover (desktop): `HoverLift` whisper rise + row actions ghost in (Review /
  Open). Right-click: `showAppContextMenu` (Open · Assign · Review · Copy
  title). Click anywhere → `TaskDetailsScreen`.
- Surface: transparent rows on the page background, hairline separators —
  **not** stacked cards. Cards-in-a-feed is what makes the current screenshot
  feel heavy; rows are what make 30 tasks scannable.

### 3.6 KPI strip — numbers that are lenses

Four `DashboardMetricCard`s (existing widget, gains `onTap`):
**Active · Overdue · In review · Done today**. Tap = set the matching preset
+ smooth-scroll to the feed. **Counts derive from the same in-memory stream
as the feed** (extending the `_DynamicSection` pattern — the dashboard
already computes overdue/review live because `StatisticsCubit`'s TTL cache
went stale after reviews). *Rationale: the number you tap is exactly the list
you get — a KPI sourced from a different query than its drill-down is how
dashboards lose user trust.* `StatisticsCubit` remains for people/schedule
figures.

Greeting row keeps date + ⌘K hint and gains the **attention chip** ("⚠ 3
overdue · 2 in review", hidden at zero) → taps to the Overdue preset. This
replaces the brief's health score (§0) and the current `_Hero` pulse card
(which duplicates what the KPI strip + feed now say).

### 3.7 Task card badge fix (the screenshot bug)

`taskBadgeFor()` drops the `approved` and `rejected` branches — the status
pill already carries both states. The lifecycle badge keeps only what the
pill *cannot* say: **`REWORK #n`** (revision count) and **`NEW`** (unseen).
One pill per fact, never two. (`task_badge` tests updated accordingly.)

---

## 4. Flutter widget structure

```
lib/features/task/
├── domain/
│   └── task_feed.dart                    NEW  pure filter/group/search/sort + presets
├── presentation/widgets/
│   ├── task_feed_row.dart                NEW  dense row (status dot · title · chips ·
│   │                                          assignee · due · 2px checklist track)
│   ├── task_feed_bar.dart                NEW  sticky bar: scope ▾ · preset chips ·
│   │                                          search · group ▾ · sort (SliverPersistentHeader)
│   ├── task_feed_section.dart            NEW  composes bar + grouped slivers; owns the
│   │                                          ephemeral TaskFeedFilter (StatefulWidget —
│   │                                          no new cubit; reads app-wide TaskCubit)
│   └── task_badge.dart                   EDIT drop approved/rejected branches
├── admin/presentation/pages/
│   └── admin_dashboard_screen.dart       EDIT main column → greeting+attention · KPI
│                                              strip (tap-wired) · TaskFeedSection;
│                                              _Hero + main-column _ActivityFeed removed;
│                                              rail unchanged (Branch-pulse rows get
│                                              onTap → branch-scoped feed)
├── manager/presentation/pages/
│   └── manager_home_screen.dart          EDIT TaskFeedSection(branchLocked: true)
└── core/widgets/
    └── dashboard_metric_card.dart        EDIT optional onTap + pressed state
test/
└── task_feed_test.dart                   NEW  pure unit tests (filter × group × search
                                               × presets × active-window inclusion)
```

**No new cubit, repository, datasource, or DI change.** The feed reads the
app-wide `TaskCubit` stream (already scope-keyed per role, already warm);
filter state is screen-local and ephemeral. This matches the
`pending_review_screen` precedent (self-contained StatefulWidget over the
shared stream) and the lean ruling: *workflow > architecture*.

Micro-interactions (all existing primitives, no new dependency):
`EntranceFade` staggers groups on first load only; `LiveListItem` keys rows
(`t:{id}`) so stream emits never re-animate the visible list and a genuinely
new task slides in + highlights; `AnimatedCount` on KPI values and group
counts; 180ms `easeOutCubic` on group collapse. **Never gate entrance
animation on a bloc transition alone** (locked TabBarView rule).

---

## 5. Completed-task lifecycle (Done ≠ gone ≠ forever)

### 5.1 Options analysis

| | A · Soft archive (flag) | B · Auto-delete after retention | C · Archive collection |
| --- | --- | --- | --- |
| Firestore cost | Docs accumulate forever — reads/snapshots grow | Bounded collection — cheapest long-run | **Doubles** writes (copy+delete), splits queries |
| Performance | Streams degrade over years | Bounded stream payloads | Two collections to index/query |
| Audit history | Full, forever | Full within window, then gone | Full — but **no reader exists**: the analytics pipeline was already deleted as vanity (Decision A, 2026-06-23) |
| UX | Clean *if* every query filters the flag | Clean | Clean |
| Ops burden | None | One scheduled function (fleet pattern exists) | Migration + copy integrity + rules ×2 |

### 5.2 Recommendation: **A → B pipeline** (archive flag, then hard delete). C is rejected.

An approved task's value decays: day 0 it's "done today" signal → week 1 it's
rework/dispute reference → day 90 it's noise nobody will ever read (this is an
ops tool, not a compliance system — and if a longer audit window is ever
needed, that's a **config number**, not new infrastructure).

**Lifecycle:** `approved` → *(7 days, visible under an explicit Archived
toggle / status filter, never in the default feed)* → `archivedAt` stamped →
*(90 days)* → **hard-deleted, including its Storage evidence files**.

### 5.3 Firestore structure

```
tasks/{taskId}
  ...existing fields...
  archivedAt: Timestamp   // absent = live; set by taskHousekeeping only
  expireAt:   Timestamp   // approvedAt + deleteAfterDays; delete marker

config/taskRetention      // admin-editable (Settings, later; console for now)
  { archiveAfterDays: 7, deleteAfterDays: 90 }
```

- **Rules:** neither field joins the employee bounded-write whitelist
  (`isTaskAssignee` field list — already excluded by construction). The
  housekeeping function writes via Admin SDK (bypasses rules); no rule deploy
  strictly required, though adding the two fields to the *frozen* set for
  employee writes is a one-line hardening.
- **Queries:** existing role streams are **unchanged** (no `isNull` filters,
  no new composite indexes, no migration backfill for legacy docs). The feed
  excludes archived client-side (`archivedAt == null && activeWindow`);
  deletion is what bounds the collection (~90 days ≈ low hundreds of docs at
  DROP's scale → snapshot payloads stay trivial forever).

### 5.4 Scheduled cleanup — one function, both jobs

New **`taskHousekeeping`** (`functions/index.js`, `onSchedule('every 24 hours')`,
mirroring the existing `broadcastHousekeeping` — v7 SDK build):

```
1. read config/taskRetention (defaults 7/90)
2. ARCHIVE: tasks where status == approved
     && approvedAt < now − archiveAfterDays && !archivedAt
   → batch set { archivedAt: now, expireAt: approvedAt + deleteAfterDays }
3. DELETE:  tasks where expireAt < now   (limit 200/run — self-draining backlog)
   → for each: recursively delete Storage prefix tasks/{id}/ THEN the doc
4. log { archived, deleted, storageObjects } for the fleet diagnostics
```

**Why not Firestore TTL policies?** TTL was evaluated and rejected: it deletes
*documents only*, orphaning every task's proof/reference images in Storage
(unbounded, unauditable leak of exactly the evidence M3 just made immutable),
and its 24–72h lag + per-field gcloud setup adds a second mechanism to
operate. The daily function is *already required* for archive stamping;
letting it own deletion keeps **one mechanism, fully config-driven, with
Storage cleanup ordered before the doc delete** (a crash re-runs safely: the
doc still exists, prefix delete is idempotent).

**Rollout order:** ship client (§3/§4, archived-aware feed) → deploy
`taskHousekeeping` surgically (`firebase deploy --only
functions:taskHousekeeping` — same playbook as `generateShiftTaskInstances`;
avoids the stale-fleet C1c issue) → create `config/taskRetention` → force one
run and verify counts. Rollback = delete the function; flags are inert.

### 5.5 Query optimization summary

- Feed: **0 new reads** — projection over existing streams.
- KPIs: **0 new reads** — derived from the same snapshot.
- Archive browser (deferred until asked): single query
  `where('archivedAt', '>', epoch0) orderBy archivedAt desc limit 50` —
  automatic single-field index, paginated, no stream.
- Collection size: bounded by retention → every future stream/read on `tasks`
  is bounded too. This is the single biggest long-term cost/perf lever in the
  proposal.

---

## 6. Performance considerations (client)

1. **Rebuild scoping:** feed section subscribes via `context.select` /
   `BlocSelector` on the task list identity only (the `_DynamicSection`
   pattern) — typing in search never rebuilds the KPI strip and vice-versa.
2. **Pure + memoized filtering:** `applyFeed` recomputes only when
   `(tasks, filter)` changes (cached last-result pair in the section state);
   O(n) over ≤ a few hundred entities is sub-millisecond.
3. **Slivers end-to-end:** `CustomScrollView` + `SliverPersistentHeader`
   (sticky bar) + `SliverList` per group — collapsed groups build zero rows;
   no shrink-wrapped `ListView`s inside columns.
4. **Stable keys:** `LiveListItem('t:{id}')` preserves element/scroll state
   across stream emits (locked pattern from the Pending-Review drill).
5. **Images:** `BranchAvatar`/`UserAvatar` already cache; rows render at
   fixed extent (`itemExtent`) for cheap layout on desktop.
6. **Startup:** nothing new to load — the feed paints from the warm
   `TaskCubit` snapshot on first frame of the dashboard.

---

## 7. UX rationale index (decision → why)

| Decision | Rationale |
| --- | --- |
| Feed on the homepage, rows not cards | Monitoring is a scanning task; 3-hop discovery was the core friction; density is what makes Linear feel premium |
| Due-time as default grouping | Answers "what now?"; branch-default would resurrect the old mental model |
| KPIs = filters on the same data | Tap-through trust: the number *is* the list; no cross-source drift |
| Fixed presets over saved views | Lean ruling; 4 chips cover the brief's examples; view-builders rot at this team size |
| One status pill per card/row | The screenshot's stacked "Approved/Approved" is redundant signal; badge now only says what the pill can't (REWORK #n / NEW) |
| Attention chip over health score | Facts-never-quotas ruling; three counts diagnose, a score obscures |
| Monochrome + single accent token | Locked ruling ×2; token architecture keeps the indigo option one line away |
| Archive→delete over archive-forever | Ops tool, not compliance system; bounded collection = bounded cost/perf forever; retention is config, not code |
| Housekeeping function over TTL | Storage evidence must die with the doc; one mechanism; config-driven |
| No new cubit/DI | Stream + pure functions already cover it; workflow > architecture |
| Employee home untouched | Executors need their day, not a monitoring surface |

---

## 8. Build phasing (when approved)

| Phase | Content | Size |
| --- | --- | --- |
| **P1** | Badge dedupe (§3.7) + KPI tap-wiring + attention chip | ~½ day |
| **P2** | `task_feed.dart` + row/bar/section + admin & manager home recomposition + tests | ~1–2 days |
| **P3** | Lifecycle: fields + `taskHousekeeping` + config doc + surgical deploy + verify run | ~½ day + deploy |

Each phase ships independently; P1 is pure polish, P2 is presentation-only
(nothing to deploy), P3 is the only server-side change.

---

# Refinements v2 (2026-07-03, owner review)

Four changes accepted after the v1 review. Where they contradict v1, **v2
wins** (noted inline).

## R1 — Hybrid feed: rows **and** an expandable task surface

v1's rows-only feed is refined to a **row → expand** model (not rows-only, not
cards-only):

- The dense `TaskFeedRow` stays the resting state (scanning).
- Clicking a row **expands it in place** into a premium surface (desktop) or
  opens the same content as a **bottom sheet** (mobile) — one shared widget,
  two presentations. Expansion reveals: description · checklist with
  interactive items · assignees/branch/shift chips · mini activity (last
  event) · role actions (Open details · Review/Approve · Reassign). A second
  click, or opening another row, collapses it (accordion — one open at a time,
  so the feed never becomes a wall).
- "Open details" in the expanded surface still pushes the full
  `TaskDetailsScreen` for the record view; the expansion is the **80%
  triage** case (glance → act) that avoids a full navigation.

New widget `task_feed_expansion.dart` (the shared expanded body);
`task_feed_row.dart` gains an `expanded` state + `AnimatedSize`
(180ms `easeOutCubic`). Mobile wraps the same body in
`showModalBottomSheet` (drag handle, `DraggableScrollableSheet`). Still no new
cubit — the expanded checklist ticks call the existing
`TaskCubit.toggleChecklistItem`.

## R2 — Task retention: revised recommendation (v1's hard-delete default is dropped)

v1 defaulted to **archive → hard-delete at 90 days**. After costing it, that
default is **wrong for DROP** — the savings are a rounding error and you lose
audit history you can't get back. **The real cost driver is query
amplification, not stored bytes.**

### Cost model (state the assumptions, everything scales linearly)

- 5 branches × ~20 tasks/day = **~100 tasks/day ≈ 36k/year**.
- Firestore task doc ≈ **5 KB**; images (proof + reference) ≈ **1.5 × 600 KB =
  ~0.9 MB/task** (in Cloud Storage, not Firestore).
- Prices = Google **list** (us multi-region; regional is ~40–50% less):
  Firestore reads **$0.06 / 100k**, storage **$0.18 / GiB·mo**; Cloud Storage
  Standard **$0.026 / GB·mo**, Coldline **$0.004**, Archive **$0.0012**.

### Three-year accumulation (~108k tasks, ~96 GB images)

| Option | Firestore storage | Image storage | Audit | Reversible | Notes |
| --- | --- | --- | --- | --- | --- |
| **1 · Soft archive forever** | 0.53 GiB → **~$0.10/mo** | 96 GB Std → **~$2.50/mo** | Full, forever | n/a | Docs are KB — keeping them is ~free; images are the whole bill |
| **2 · Archive + cold-tier images** | ~$0.10/mo | 96 GB Coldline → **~$0.38/mo** (Archive → ~$0.12/mo) | Full, forever | n/a | **~85% image saving** vs Std, history intact |
| **3 · Hard delete at 90d** | negligible | ~8 GB live → **~$0.20/mo** | 90 days only | **No** | Saves ~$0.30/mo over #2 — and it's irreversible |

**The number that dwarfs all of the above — read amplification:**

| Feed query | Reads / cold app-open (yr 3) | 15 opens/day | Monthly cost |
| --- | --- | --- | --- |
| **Unbounded** (streams whole `tasks`) | ~108,000 | 1.62M/day | **~$29/mo and climbing** |
| **Bounded** (active + approved-today ≈ 200 live) | ~200 | 3,000/day | **~$0.05/mo, flat forever** |

Retention moves the bill by **cents**; bounding the hot query moves it by
**~500×**. So:

### Recommendation (v2): **Option 2 — soft-archive forever + cold-tier images. Hard-delete is opt-in, off by default.**

- Keep the Firestore doc **forever** (full audit/rework/dispute history for
  pennies).
- On archive (approved + N days), the `taskHousekeeping` function **rewrites
  the task's Storage objects to Coldline** (Admin SDK — unaffected by the M3
  create-only *client* rule; the client still can't mutate them). ~85% image
  saving, retrieval is rare (`$0.02/GB` if ever needed).
- `deleteAfterDays` stays in `config/taskRetention` but is **null (off) by
  default** — set it (7/30/90/365) only if a specific org wants purging.
  Coldline's 90-day early-delete minimum means purge, if enabled, should be
  ≥ 90 days to avoid the minimum-duration fee.
- **The non-negotiable** (independent of retention): the homepage feed and its
  role streams must be **bounded** to non-archived + active-window — never a
  full-collection stream. This is the single most important line item in the
  whole proposal and it's a client query change, not a schema one.

`config/taskRetention` → `{ archiveAfterDays: 7, coldTierImages: true,
deleteAfterDays: null }`. Storage field on the task: keep `archivedAt`; drop
the v1 `expireAt` unless `deleteAfterDays` is set.

## R3 — Employee home redesign (lightweight operational surface)

v1 left the employee home out of scope; now in. Employees **execute**, so the
home answers three questions in one screen, no navigation:

1. **Am I on today, and until when?** — a **shift hero** (Morning · 08:00–16:00
   · "On shift now" / "Off today" / countdown to start).
2. **How am I doing today?** — a **progress ring** (done ÷ in-window today,
   from `active_window.dart`) + a 3-stat strip: **To do · In review
   (submitted, awaiting manager) · Done today**. ("Pending reviews" for an
   employee = *their own* `waitingReview` submissions — work handed off, so
   they know what's still pending on the manager, not a review queue they act
   on.)
3. **What do I do next?** — **Today's tasks**, urgency-ranked (R4), as slightly
   richer actionable rows (bigger touch targets) with the primary action inline
   (Start · Submit · Fix & resubmit). Same expand-in-place body as R1.

Plus the existing **swaps** section (incoming Accept/Decline). No monitoring
chrome, no branch scope, no KPI-as-filter — that's a manager's job. Reuses
`active_window.dart`, `AnimatedCount`, the shared expansion body; edits
`employee_home_screen.dart` only.

## R4 — Urgency ranking engine (powers dynamic sort **and** grouping)

New pure module `lib/features/task/domain/task_urgency.dart` (unit-tested, same
class as `move_validation.dart`). It produces a **tier** (dominant bucket) and
an **intra-tier score** (tie-break) from four signals: overdue state, review
urgency, priority, due proximity. The tiers double as the default group
headers, so one engine drives both "group by urgency" and the "Smart" sort —
this replaces v1's "group by due-time (default)" with **group by urgency
(default)**, which is exactly the dynamic ranking asked for.

```dart
enum UrgencyTier { overdue, needsReview, rework, dueToday, dueSoon, scheduled, noDate }

enum UrgencyLens { reviewer, executor } // viewer reviews vs. executes the work

/// Dominant bucket. `needsReview` ranks high for a reviewer (their queue) but
/// low for the executor who submitted it (it's just "waiting on the manager").
UrgencyTier tierOf(TaskEntity t, DateTime now, UrgencyLens lens);

/// Higher = more urgent *within* a tier. Tuned, capped, monotonic.
double intraScore(TaskEntity t, DateTime now, UrgencyLens lens) {
  var s = 0.0;
  if (overdue)        s += min(hoursOverdue, 72);          // older overdue floats up
  if (needsReview && lens == reviewer) s += min(hoursSinceSubmit, 48);
  if (hasDeadline && !overdue) s += max(0, 48 - hoursUntilDue); // sooner = higher
  s += switch (t.priority) { high => 40, medium => 15, low => 0 };
  if (t.status == started && hoursSinceStarted > 8) s += 6;     // stalled nudge
  return s;
}

/// Sort key: tier dominates, then intra-score desc, then deadline asc.
int compareUrgency(TaskEntity a, TaskEntity b, DateTime now, UrgencyLens lens);
```

- **Lens** is the key subtlety: the admin/manager feed uses `reviewer`
  (so `waitingReview` bubbles up — money waiting on their approval); the
  employee home uses `executor` (their `rejected`/rework and due-today work
  rank first; submitted work sinks). Same engine, one parameter.
- **Deterministic + testable**: `now` injected, all terms capped so scores are
  bounded and stable across rebuilds; `task_urgency_test.dart` asserts ordering
  invariants (overdue > any non-overdue; high > low within tier; older-overdue
  > newer-overdue).
- The "Smart" sort is the default; explicit sorts (due / priority / newest)
  remain as overrides. Grouping menu adds **Urgency** (the tiers) as default,
  Branch / Employee / Priority as alternates.

### v2 widget/module delta (added to §4)

```
lib/features/task/
├── domain/
│   ├── task_urgency.dart              NEW  tier + intra-score + comparator (R4)
│   └── task_feed.dart                 EDIT default grouping = urgency; sort = Smart
├── presentation/widgets/
│   ├── task_feed_expansion.dart       NEW  shared expanded body (desktop inline / mobile sheet)
│   └── task_feed_row.dart             EDIT expanded state + AnimatedSize (R1)
├── employee/presentation/pages/
│   └── employee_home_screen.dart      EDIT shift hero · ring · 3-stat · urgency-ranked today (R3)
└── functions/index.js                 EDIT taskHousekeeping: cold-tier images on archive (R2)
test/ task_urgency_test.dart           NEW
```

---

# P3 — lifecycle: IMPLEMENTED (2026-07-03)

Owner picked P3 to build first. Shipped as **archive-in-place** — and the
architecture shifted from R2 at implementation time for two reasons found by
reading the actual code:

1. **Statistics count approved tasks directly from `tasks`** (admin
   `completedTasks` + `activeTasks`, employee `completedTasks`, via `count()`
   aggregates in `statistics_remote_datasource.dart`). **Moving archived tasks
   to a separate collection would undercount lifetime "completed."** → archived
   tasks **stay in `tasks`**.
2. **The Firestore `isNull` gotcha** — a `where('archivedAt', isNull: true)`
   query does **not** match documents missing the field, so a server-side
   "hide archived" filter would either silently drop every legacy doc or need a
   full backfill migration. → archived tasks are filtered out **client-side**
   in the one repository mapping (`TaskRepositoryImpl._newestFirst`), which is
   migration-free and safe for every existing doc.

**What shipped (client + function, no rules/index/storage-rule change):**
- `TaskEntity.archivedAt` (+ `isArchived`) and `TaskModel` (round-trips;
  **written in `toMap`** so an admin reopen clears it, but only ever null on a
  live task). Server-managed by the function.
- `TaskRepositoryImpl._newestFirst` drops archived from **every** active
  list/stream (the single clutter gate). `getTask` bypasses it → deep-links to
  archived tasks still resolve; stats read Firestore directly → lifetime counts
  intact.
- `TaskCubit.reopenTask` clears `archivedAt` (admin reopen un-archives).
- `taskHousekeeping` (`functions/index.js`, `onSchedule` 24h): **archive**
  approved tasks older than `archiveAfterDays` (default 30) — stamp `archivedAt`
  + cold-tier `tasks/{id}/` Storage to COLDLINE; **delete** opt-in only when
  `deleteAfterDays` is set (soft-archive-forever by default, per owner). Archive
  pass pages by `approvedAt` with a cursor + skips already-archived → no
  composite index, outage-tolerant, no starvation.
- Config `config/taskRetention` `{ archiveAfterDays: 30, coldTierImages: true,
  deleteAfterDays: null }` — read via Admin SDK, defaults when absent (doc
  optional; no client rule needed).
- Tests: `test/task_archive_test.dart` (6) — serialization + the repo filter.

**Verify:** `flutter analyze` clean (7 pre-existing infos) · **302 tests pass**
(+6) · `node --check functions/index.js` OK · freezed regenerated.

**Deploy footprint (surgical, owner — production `bazic-d9ad7`):**
`firebase deploy --only functions:taskHousekeeping` (same playbook as
`generateShiftTaskInstances`; dodges the stale C1c fleet). Optionally create
`config/taskRetention` to override defaults. **Nothing else** — no rules, no
indexes, no storage rules. Rollback = `firebase functions:delete
taskHousekeeping`; the `archivedAt` field is inert without it.

**Still deferred (documented, not built):** *server-side* read-bounding of the
admin `watchAllTasks` stream (the ~500× cost lever at scale). It requires
either the `tasks_archive` collection-move (with a stats-count update to sum
both collections via cheap `count()` aggregates + a `getTask` archive
fallback) **or** an `archivedAt`-on-all-docs backfill migration to make the
`isNull` filter safe. Not needed at current volume; scoped here so it's a
known, costed follow-up rather than a surprise.

## P3 — clarifications (owner review, 2026-07-03)

### C1. Read-amplification risk is REAL and currently UNSOLVED (explicit)

`TaskRepositoryImpl._newestFirst` filtering `isArchived` solves **UI clutter
only**. It does **not** reduce Firestore reads: the admin `watchAllTasks`
snapshot stream still subscribes to the **entire `tasks` collection**, downloads
every doc (archived included), and the client discards archived ones **after**
they were billed. So:

- **Reads scale with total `tasks` size, not with active-task count.** Every
  admin cold app-open re-reads the whole collection (~108k docs ≈ **$0.06/open**
  at year-3 projections; ~$29/mo at 15 opens/day — see the R2 cost table).
- The `taskHousekeeping` archive pass itself also reads archived docs while
  paging (bounded per run by `RUN_CAP`, but still non-zero).
- **This is deliberately deferred, not overlooked** — at current volume (tens of
  tasks) it's fractions of a cent; it only matters at scale, and P4 is now the
  lowest priority (see C4). Filtering was chosen for clutter now; bounding is a
  separate, later lever.

### C2. Migration-safe server-side query strategies (future, pick at P4)

Ordered by preference. All avoid the `isNull` missing-field trap and all keep
the stats/deep-link contract intact:

1. **`isActive` boolean, dual-written + backfilled (recommended).** Every task
   carries `isActive: true` from creation (`toMap`); `taskHousekeeping` flips it
   `false` on archive. Streams query `where('isActive', isEqualTo: true)`.
   *Migration-safe path:* the function's **first runs backfill** `isActive` onto
   legacy docs (set true for non-archived, false for archived) **before** the
   client query switches — deploy function → confirm backfill complete → deploy
   the client query change. A boolean equality needs no composite index and
   `true` matches only docs that explicitly hold it (so the backfill gate is
   what makes it safe). Reads then scale with **active** count. Stats keep
   reading `status`/`approvedAt` directly (unaffected).
2. **`tasks_archive` collection-move.** Archived docs leave `tasks` entirely →
   the live collection is inherently bounded, streams need **zero query change**.
   Cost: `taskHousekeeping` does copy+delete per archive (one-time, negligible),
   **statistics must sum `tasks` + `tasks_archive`** via two cheap `count()`
   aggregates (count() bills ~1 read/1000 docs), and `getTask` needs an archive
   fallback for old deep-links. Cleanest bound, most moving parts.
3. **Time-boxed stream window.** Stream only
   `where('createdAt', >, now - Ndays)` + always-include the small set of
   non-terminal older tasks via a second query. Rejected: an old-but-still-open
   task can slip the window; more fragile than (1).

**Recommendation:** option 1 (`isActive` + gated backfill) when P4 is picked up —
it's the least invasive, index-free, and leaves stats untouched.

### C3. Cold-tiering = Storage **class** change, NOT compression, NOT bucket rules

To be exact about what `taskHousekeeping` does today:

- It calls `file.setStorageClass("COLDLINE")` **per object** via the Admin SDK —
  a server-side **rewrite of each object's storage class** from Standard →
  Coldline. This lowers the **$/GB storage price (~$0.026 → ~$0.004)**; the
  **bytes are unchanged** (no re-encoding). Retrieval later costs a small
  per-GB fee, which is why it's only applied to *archived* (rarely-read) proof.
- It is **not** image/video compression — that's a separate concern, done at
  **pick time** by `image_picker` (`imageQuality`/`maxWidth` in
  `AttachmentLimits`), which reduces bytes *before upload*. Cold-tiering reduces
  *price-per-stored-byte after archive*. Two different levers.
- It is **not** GCS **Object Lifecycle Management** (bucket-level, age-based
  auto-transition rules configured on the bucket, no code). That's the standard
  alternative and arguably simpler, but it can only key off object **age**, not
  the task's archival decision. **Option for P4:** replace the per-object
  `setStorageClass` with a one-time bucket lifecycle rule (e.g. "Standard →
  Coldline after 30 days on prefix `tasks/`") — no per-object writes, but
  coarser (ties tiering to upload age, not archive state). Left as-is for now
  since the function already owns the archive decision.

### C4. Re-prioritized — homepage UX first, retention last

Owner ruling: primary pain is **homepage usability + active-task
discoverability**, not retention. New order (supersedes the earlier phasing):

| New | Was | Scope |
| --- | --- | --- |
| **P1** | old P1 | Homepage UX improvements (badge dedupe · tappable KPIs · attention chip) |
| **P2** | old P2 | Global task feed + filters/search/grouping (no urgency engine yet) |
| **P3** | (R4) | Urgency ranking engine → the feed's "Smart" sort/grouping |
| **P4** | old P3 lifecycle | Retention read-bounding (C1/C2) + cold-tier revisit (C3) — **paused** |

The archive lifecycle already shipped stays as-is (soft-archive + clutter
filter); **no further backend/infra work** until P1–P3 land.

---

# P1 + P2 — IMPLEMENTED (2026-07-03)

Homepage UX + the global feed, per the re-prioritization. **Presentation-only —
nothing to deploy.**

**P1 — homepage UX:**
- **Badge dedupe (the flagged bug).** `taskBadgeFor` no longer returns
  `Approved`/`Rejected` — the card's status pill already shows those, so the
  word stacked twice. The badge now carries only `REWORK #n` / `NEW`
  (`task_badge.dart`; `task_badge_test.dart` updated).

**P2 — global active-task feed on the homepage:**
- **`task_feed.dart`** (pure engine, 23 tests): `TaskFeedFilter` (branch ·
  assignee · shift · priority · status · search · preset · grouping · sort) +
  `applyFeed` (active-window base + AND-composed filters + search over
  title/description/branch/assignee) + `groupFeed` (Due-time / Branch /
  Employee / Priority, ordered) + 4 pinned presets. O(n), no index, offline.
- **`task_feed_row.dart`** (5 tests): the dense scannable row — status dot +
  short label · title · branch chip · High-only flag · assignee · due
  (red + "· late" when overdue) · 2px checklist underline. Colour from the
  canonical `taskStatusColor`.
- **`task_feed_section.dart`**: the composable homepage feed over the app-wide
  `TaskCubit` (no new cubit/query) — preset chips + search + group/sort menus
  (+ branch scope for admin) + collapsible grouped rows; row taps through to
  `TaskDetailsScreen` (any task in ≤2 taps). `branchLocked` for managers.
- **Wired in:** `AdminDashboardScreen` (main column — **replaced** the
  redundant `_ActivityFeed`, which was deleted; the feed is the activity
  surface now) on desktop + mobile; `ManagerHomeScreen` (`branchLocked`, and it
  now also loads `TaskCubit`).

**Deferred to P3 (next):** the urgency ranking engine → the feed's "Smart"
sort/grouping (P2 ships Due-date / Priority / Newest). **Deferred refinement:**
the R1 inline row-expansion / bottom-sheet triage surface — P2 taps straight to
the full details screen for now.

`flutter analyze` clean (7 pre-existing infos) · **330 tests pass** (+28).
⚠️ On-device visual QA suggested (feed density on a phone; the admin
main-column feed replacing the activity list).

---

# R1 (inline expandable row) + Attention strip — IMPLEMENTED (2026-07-03)

Owner priority after P2: the remaining friction was navigating into
`TaskDetailsScreen` for routine triage. Presentation-only.

**R1 — accordion expansion, one shared surface, two presentations:**
- **`task_feed_expansion.dart`** — the single shared triage surface: description ·
  facts (branch · shift · due [red if overdue] · assignee) · checklist preview +
  progress · attachment/proof thumbnails · compact status timeline (newest-first) ·
  quick actions. Actions read the app-wide `TaskCubit` **lazily on tap** (no new
  cubit, and rendering needs no provider).
  - **Approve** → instant `approveTask`; **Reject** → the canonical
    `showReviewSheet` (reason capture); **Reassign** → `showAssignSheet` (hidden
    for shift tasks / approved); **Open full details** → the full screen. Actions
    call `onClose` (collapse desktop / pop sheet mobile).
- **Desktop = inline accordion** in `task_feed_section.dart`: `_expandedId` (one
  open at a time), rendered under the row via **`AnimatedSize` (height) +
  `TweenAnimationBuilder` opacity (fade)**; the row shows a `selected` highlight +
  chevron flip. Scroll is preserved (the outer dashboard `ListView` +
  `LiveListItem` keys).
- **Mobile = bottom sheet**: the same surface in a `DraggableScrollableSheet`
  (drag handle · 0.7 initial · row header on top). `context.isDesktop` picks the
  presentation.

**Attention Needed strip** — a stable triage bar above the feed
(`_AttentionStrip`): **Overdue · Pending review · Blocked** counts over the
scope's active set (not the user's preset/query, so counts stay stable). Each
pill is tappable → filters the feed (overdue/needs-review presets · blocked =
`rejected` status). "All clear" state when nothing needs attention.

> **⚠️ "Blocked" interpretation (owner, confirm):** mapped to **`rejected` /
> rework** tasks — work bounced back from review, blocked from completion. If you
> meant **unassigned** (work with no owner), it's a one-line change in
> `_AttentionStrip` + the count predicate.

`flutter analyze` clean (7 pre-existing infos) · **336 tests pass** (+6
`task_feed_expansion_test.dart`). ⚠️ On-device QA: accordion animation + the
mobile bottom sheet on a real phone.

---

# R1 refinements + Smart Queue (P3-lite) — IMPLEMENTED (2026-07-03)

Owner: three R1 refinements + a lightweight Smart Queue *before* the full
urgency engine. Presentation-only except one additive cubit method.

- **Attention strip: Blocked → Unassigned (owner ruling).** "Blocked" now means
  *can't progress for lack of an owner* → **unassigned** individual/team tasks
  (shift tasks target a shift, never "unassigned"). The strip is now
  **Overdue · Pending review · Unassigned**; the Unassigned pill taps the
  `unassigned` preset.
- **Approval safety (proof).** Approve is now **proof-safe**: a submission
  carrying proof (any `activityLog` attachment or legacy `proofImageUrl`) shows
  a **lightweight confirm sheet** (evidence thumbnails + Approve/Cancel) before
  approving; proofless tasks stay one-tap. In `TaskFeedActions._approve`.
- **Sticky action footer.** The quick actions were extracted into a reusable
  **`TaskFeedActions`** widget. Desktop inline = actions at the surface bottom;
  **mobile bottom sheet = a pinned footer** (`TaskFeedExpansion(showActions:
  false)` in the scroll body + `TaskFeedActions` in a bordered footer that stays
  visible as content grows).
- **Quick manager notes.** New **`Note`** action → a small note sheet
  (`_NoteSheet`) → **`TaskCubit.addNote(task, text)`** appends a `note` activity
  entry (no status change; rendered via a new `note` kind in `activity_format`).
  The one added cubit method — mirrors `toggleChecklistItem`'s append pattern,
  no new cubit.
- **Smart Queue (lightweight, P3-lite).** New **`FeedSort.smart`** = the
  **default**, a simple 5-tier `smartRank`: `0` overdue+high · `1` pending
  review · `2` overdue · `3` due today · `4` normal (ties broken by due date).
  When Smart is active the feed is a **single flat ranked list** (group headers
  hidden, grouping menu hidden); switching sort to Due date / Priority / Newest
  restores grouping. **Deliberately NOT the full urgency engine** — validate
  this ranking in real use first, then evolve into `task_urgency.dart` (the
  tier + `reviewer`/`executor` lens design still stands).

`flutter analyze` clean (7 pre-existing infos) · **341 tests pass** (+5).
> **Note:** Smart Queue is the **default sort**, so the feed now opens as a flat
> ranked queue rather than the P2 due-time groups. Easy to flip back (change the
> `TaskFeedFilter.sort` default) if you'd rather groups stay the default and
> Smart be opt-in.

⚠️ On-device QA: the approve-confirm + note sheets on a phone; Smart Queue order.

---

# Smart-not-default + note categories + counters + telemetry (2026-07-03)

Owner: don't make Smart the default yet; add note metadata + animated counters;
then lightweight usage telemetry *before* the full urgency engine.

- **Smart Queue reverted to opt-in.** Default sort is back to **Due date
  (grouped)**; Smart Queue stays an explicit sort mode (menu order: Smart Queue ·
  Due date · Priority · Newest). One-line default change; the flat-when-smart
  rendering is unchanged. Rationale: compare real behavior before promoting the
  unvalidated heuristic.
- **Note categories (info / warning / issue).** New `NoteCategory` enum
  ([note_category.dart](lib/features/task/domain/note_category.dart)) stored as
  the note's activity **kind** (`note` / `noteWarning` / `noteIssue` — no schema
  change; `info` reuses the plain `note` for back-compat). `TaskCubit.addNote`
  takes a `category`; `activity_format` renders each with a distinct
  title/colour/icon (warning=amber, issue=red). The note sheet gained a 3-chip
  category selector. Sets up future filtering + timeline hierarchy.
- **Animated attention counters.** The strip now **always renders the three
  pills** (muted at zero) instead of swapping to an "all clear" chip, so each
  pill's `AnimatedCount` persists in the tree and tweens smoothly through any
  change — including to/from zero.
- **Lightweight feed telemetry.** New
  [`UsageTracker`](lib/core/services/usage_tracker.dart) — a **single aggregate
  counters doc** `usageStats/feed` of `FieldValue.increment` fields, **debounced
  to ~one write/20s** (a burst of expansions = one write; dodges single-doc
  contention), **best-effort** (never affects UI), **test-safe** (no-op until
  `init`). Tracks the five owner-requested signals: `preset_{name}` (chips +
  attention pills) · `sort_{name}` · `expansion_open` · `quick_approve` ·
  `note_create`. `init` wired in `main.dart`. **Rules:** `usageStats/{doc}` —
  signed-in write (increment), admin read.

`flutter analyze` clean (7 pre-existing infos) · **343 tests pass** (+2
`note_category_test.dart`). ⚠️ **Deploy required for telemetry:** `firebase
deploy --only firestore:rules` (until then increments are permission-denied —
harmless, telemetry just records nothing). Read the data at `usageStats/feed`
in the Firestore console. Everything else is client-only (no deploy).

