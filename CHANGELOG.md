# Changelog

All notable changes to **DROP — Operations Management System** (Dart package id
`drop`) are recorded here. After every completed feature, append a short summary
of what was **added / removed / fixed / refactored**. See
[PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) for architecture.

The project adheres loosely to [Keep a Changelog](https://keepachangelog.com)
and [Semantic Versioning](https://semver.org).

---

## [Unreleased]

### Changed (2026-07-10 — Schedule Builder UX polish: calm, grid-first, presentation-only, `feature/schedule-optimization`)

Owner-directed **presentation-only** refinement of the manager/admin Schedule
Builder — no data model, business logic, Firestore, Cubit, analyzer, or save-path
change (every edit/save/drag/swap path is byte-identical). The screen was
presenting the grid, week stats, health, insights, legend and the team inspector
all at once; it now reads **calm and grid-first**, with everything secondary
demoted behind interaction.

- **Contextual inspector rail** (`manager_schedule_view.dart` desktop branch):
  the right rail (`schedule_inspector_drawer.dart` — This Week totals + Team +
  per-employee detail) is now a **collapsible, resizable workspace** instead of a
  permanent fixture. A toolbar toggle (`view_sidebar`) opens/closes it; a
  draggable splitter resizes it (280–460px); state is **remembered for the
  session** (open + width, via `_InspectorPrefs`, matching Focus Mode's
  in-session model — no local-prefs store exists yet). It is **hidden by default
  on the narrower desktop tier** (1024–1600) and **open by default on ultrawide**
  (≥1600). When collapsed the grid **reclaims the width automatically**
  (`ClipRect` + `OverflowBox` + `AnimatedContainer`, reduced-motion honoured, drag
  suppresses the animation). The drawer gained an optional in-rail collapse
  header and now **fills the width it's given** (fixed `width` param removed).
- **Below-grid review band lightened** (`schedule_overview_surface.dart`
  rewritten): the three competing bordered cards became **one borderless,
  typography-led band** parted by hairlines (no large dark blocks). **Health**
  keeps its score / category chips / top findings but at reduced weight (score
  36→32px, at most 3 one-liners). **Insights** trimmed to a few attention-fact
  lines (the totals paragraph dropped — totals live in the rail). **Legend** is
  now **near-invisible — collapsed by default** to a single quiet line, expanding
  only on tap (it exists for learning).
- **More breathing room around the grid**: the left column's vertical rhythm was
  opened up (top `md`→`lg`, grid→band `lg`→`xl`, bottom `xl`→`xxl`), so the eye
  lands on the grid first.
- **Tests:** `schedule_overview_surface_test.dart` updated for the collapsed
  legend (+1 legend expand/collapse test); `schedule_inspector_drawer_test.dart`
  unchanged and green. `flutter analyze` clean; full suite **682 pass / 3
  pre-existing fail** (the documented splash-centering ×2 + stale
  notification-grouping, all in untouched files). **Frozen pending owner
  on-device review.**

### Added (2026-07-09 — Schedule V2, Pillar 5: Shift Templates & configurable shift system, `feature/schedule-optimization`)

The **first pillar to extend the scheduling data model** — the hardcoded
Morning/Night hours become **reusable, per-branch Shift Templates**. **Additive
and backward-compatible by construction:** every legacy schedule resolves exactly
as before, and the frozen surfaces (Final View · Health Analyzer · Inspector ·
Grid interactions · Assignment chips · Desktop layout · Export flow · Routes)
were **not touched**. Design-reviewed + owner-approved before code.

- **Data model (additive):**
  - New collection **`shift_templates/{id}`** — per-branch library keyed
    `{branch}__{role}`. A template = `{ branchId, name, role, startMinutes,
    endMinutes }` reusing the overnight-aware `ShiftHours`. Three standing roles
    (Morning · Weekday night · Weekend night) + a reserved `custom` (future).
    **Seeded lazily** with defaults matching the old `ShiftHours.standard`, so
    adopting templates is behaviour-neutral.
  - The week doc (`weekly_schedules/{id}`) gains an **optional `shiftPlan`
    snapshot** (morning / weekday-night / weekend-night `ShiftHours`), captured
    **at creation** from the branch's current templates. **Absent on every legacy
    week.** The existing per-slot `shiftHours` override is unchanged.
- **Resolution (one entity-only seam):** `WeeklyScheduleEntity.hoursFor` now
  resolves **per-slot override → the week's `shiftPlan` snapshot →
  `ShiftHours.standard`**. A legacy week (no snapshot) skips the middle step →
  **identical** to before, so nothing that reads `hoursFor` (grid, employee views,
  Final View, `shift_window`) changed or was threaded new state.
- **History-safe by construction:** each week freezes its own snapshot, so a later
  template edit can never rewrite a past week.
- **The 3-way edit scope** (`ScheduleCubit.applyShiftHours`): **This week only** →
  a frozen per-slot override (the existing `setShiftHours`); **Future schedules**
  → updates the template (only weeks created afterward snapshot it); **Update
  globally** → updates the template **and** re-stamps this week + every future
  existing week (`ScheduleRepository.restampShiftPlan`; past weeks stay frozen).
- **UI (simple, no enterprise config):** a **Shift-templates manager sheet**
  (view templates · hours · which slots each drives · edit hours) reached from the
  day sheet's *Shift hours* section, plus the **"Apply changes to…" scope dialog**;
  the day-sheet hours editor now routes through it. Overnight is native (`end >
  1440`); validation covers empty/duplicate names + invalid ranges.
- **Architecture (modular):** `core/enums/shift_template_role.dart` +
  `shift_hours_scope.dart`; domain `shift_plan.dart`, `shift_template.dart`
  (`ShiftTemplate` + `ShiftTemplateSet` + validation), `repositories/
  shift_template_repository.dart`; data `models/shift_template_model.dart`,
  `datasources/shift_template_remote_datasource.dart`, `repositories/
  shift_template_repository_impl.dart`; presentation `cubit/shift_template_cubit
  .dart` (+ state), widgets `shift_hours_scope_dialog.dart` +
  `shift_templates_sheet.dart`. `ScheduleCubit` gains the template repo (snapshot
  + scoped edits); `ScheduleRepository`/datasource gain `createSchedule(shiftPlan)`
  + `restampShiftPlan`. Wired in `injection.dart`.
- **Rules:** additive `match /shift_templates/{id}` mirroring `weekly_schedules`
  (`canReachBranch` → manager+admin CRUD their branch, members read).
  **⚠️ Needs a `firestore.rules` deploy before managers can use templates.**
- **Tests (+24):** `shift_template_test.dart` (role mapping, plan resolution,
  **legacy → standard**, overnight, `ShiftTemplateSet` plan/defaults/validation),
  `shift_template_model_test.dart` (template + week-snapshot round-trip,
  **legacy doc → null → standard**), `shift_template_cubit_test.dart`
  (**this-week vs future vs global** writes + snapshot-on-create),
  `shift_hours_scope_dialog_test.dart` (the picker). `flutter analyze` clean;
  full suite **681 pass / 3 pre-existing fail**. Out-of-scope kept out (no
  metadata/history/versioning/publishing/analytics/auto-scheduling/AI). Pillar 5
  frozen pending review.

### Changed (2026-07-09 — Schedule V2, Pillar 4: Final View redesign, `feature/schedule-optimization`)

The **Final View was redesigned from scratch** into a premium, **read-only,
print/export-ready** schedule — a modern spreadsheet (Apple Numbers / Notion
tables) in DROP's monochrome language. **Presentation only.** The frozen surfaces
(Health Analyzer · Inspector · Grid interactions · Assignment chips · Desktop
layout · Domain models · Firestore · Cubits · Routes) were **not touched**.

- **Added — `final_schedule_sheet.dart`** (`FinalScheduleSheet`, a dedicated,
  testable presentation surface — *not* the editor with another mode): one
  **employee per row**, one **day per column** (Sun→Sat with dates), and a single
  scannable **token per cell** — `M` · `N` · `M/N` · `OFF` · `LEAVE` · `VAC`. A
  document header (DROP · branch · **Week of** · **Generated** · **Manager**), a
  bottom **day-notes row** (only when notes exist), and a **legend**. Typography +
  whitespace carry the hierarchy: employee names lead, shift tokens are the scan
  target; subtle zebra rows + hairline column rules, no chips/avatars/heavy
  shadows. Designed as a **fixed-width (1600) landscape document** with natural
  height (≈ A4-landscape for a typical roster), `FittedBox`-scaled to any screen —
  so it exports consistently to PNG/print/PDF.
- **Removed everything editor-ish from the Final View:** the old grid-reuse export
  canvas (`_ExportCanvas`) and its `_FinalHeader` / `_FactPill` / `_LegendDot`
  helpers are gone — no drag/drop, inspector, health, analytics/fact-pills,
  suggestions, or builder controls in the published view.
- **Kept intact:** the launch signature (`showScheduleFinalView(...)`, so the
  editor toolbar is unchanged), the **PNG export** mechanism
  (`RepaintBoundary` → `toImage(1.5×)` → Downloads), the preview toolbar
  (Back · Dashboard · Save PNG), and `scheduleExportFilename`. The `filter` /
  `previousSaturdayNight` params are retained for the launch signature but the
  published sheet always shows the whole week (no health cues).
- **Reuse only:** reads `WeeklyScheduleEntity` / `UserEntity` / `ShiftHours` /
  `LeaveType` / `ScheduleWeek` / `AppDateFormatter` — **no new scheduling logic.**
- **Tests — `schedule_final_view_test.dart` rewritten (7):** sheet rendering
  (header/tokens/legend/day-notes), **empty notes** (no notes row), **large
  roster** (22 people, no overflow), **export layout** (fixed 1600 width,
  landscape), page integration + toolbar, and **responsiveness** (narrow tablet +
  wide desktop both scale without overflow) + the stable filename. `flutter
  analyze` clean; full suite **657 pass / 3 pre-existing fail**. No
  schema/rules/functions/DI/route/dependency change. **Final View frozen pending
  review.**

### Changed (2026-07-09 — Schedule screen layout rebalance, `feature/schedule-optimization`)

A **presentation-only** rebalance of the manager/admin schedule screen so the
**grid is unambiguously the hero**, the right rail stays light, and the space
that used to sit empty below the grid earns its keep. **No business logic / no
domain change** — the frozen Pillar-3 analyzer and every edit/save path are
untouched; this only moves and re-dresses existing widgets.

- **Added — `schedule_overview_surface.dart`** (`ScheduleOverviewSurface`): the
  new **secondary information surface below the grid**. A calm, Apple/Linear-style
  band of three compact cards laid out across the available width (three columns
  on desktop, folding to two then one as it narrows):
  - **Schedule Health** — a **prominent 0–100 score** + status, the five-category
    breakdown (tap a lens to filter), and the **top findings as one-liners**; each
    finding's fix (the explanation) is revealed **only on tap** (“View →”).
  - **Insights** — the week's attention facts (open cover · single cover ·
    double-booked · short rest · leave clash) + a quiet totals line, distinct from
    the rail's summary and from Health's findings.
  - **Legend** — shift hours, leave types, and the drag/drop hints.
- **Moved the global Schedule Health out of the right rail** into that surface, so
  the inspector rail is now just **Weekly summary + Team list + contextual
  employee detail**. The rail is also **narrower (340→300)** with a **softer
  hairline divider**, so it recedes behind the grid.
- **Removed — `schedule_health_card.dart`** (+ its test): fully superseded by the
  surface's richer, dashboard-style health block. The `_gridHint` row was folded
  into the Legend card.
- **Verification:** `flutter analyze` clean; new `schedule_overview_surface_test.dart`
  (4 — layout, prominent score, tap-to-reveal fix, category filter, calm healthy
  state) + inspector test updated (health no longer in the rail). Full suite **653
  pass / 3 pre-existing fail**. No schema/rules/functions/DI/route/dependency
  change. **Schedule screen is frozen pending review; next milestone: Final View
  redesign.**

### Added (2026-07-09 — Schedule V2, Pillar 3: Health Analyzer, `feature/schedule-optimization`)

Third pillar of **Schedule V2** — Schedule Health rebuilt from a single function
into a **modular, rule-based domain engine**, the single source of truth for
schedule quality. **100% backward compatible** (the old public API + its test
are untouched); the existing UI is enriched, not redesigned.

> **⚠️ Owner-directed scope change (recorded):** the Schedule V2 contract
> originally scoped this pillar as *"do **not** rebuild into rule classes — add
> derived subscores over the existing engine."* The owner **overrode that** with
> an explicit, prescriptive brief for a modular analyzer with independent rules.
> The *bounded 5-rule analyzer is now IN*; the enterprise parts (background
> **isolates**, a configurable per-branch **policy** engine) stay OUT. See
> `docs/design/SCHEDULE_V2.md` §Pillar 3 + the annotated ❌ #5/7 row.

- **Added — `domain/health/` package** (pure Dart, Flutter-free, unit-tested):
  - `schedule_analysis.dart` — `ScheduleAnalysis.of(...)` reduces the roster to
    shared per-member (`MemberWeek`) + per-slot signals in **one pass**; rules
    read these, none re-walks the roster (single traversal, no duplicated calc).
  - `schedule_rule.dart` — `ScheduleRule` (abstract, pure `evaluate(analysis)`) +
    `ScheduleRuleResult` + `RuleFinding` + `ScheduleHealthSeverity`
    (none/low/medium/high) + `ScheduleRuleCategory`.
  - `rules/` — **five completely independent rules**: `CoverageRule` (gaps,
    lone/overstaffed, all relative to the branch's own rhythm — **never a
    quota**), `WorkloadRule` (weekly hours, shift volume, uneven spread),
    `FairnessRule` (night/weekend/morning concentration), `RestRule` (short rest,
    consecutive nights, long streak, morning↔night churn), `ConflictRule`
    (double-booking, in-slot duplicate, on-leave placement). No switch/if-else
    chains, no rule-to-rule coupling.
  - `schedule_health_report.dart` — `ScheduleHealthReport`: `overallScore`,
    `overallSeverity`, the five `ScheduleRuleResult`s, flattened + ranked
    `findings`/`suggestions`, `findingsFor(uid)`, and the shared `analysis`.
  - `schedule_health_analyzer.dart` — `ScheduleHealthAnalyzer` folds the rules
    over the analysis → report. **Synchronous, no async/isolates.** Adding a lens
    = one rule file + one `defaultRules` entry (Open/Closed).
- **Refactored — `domain/schedule_health.dart` → the backward-compatible facade.**
  `ScheduleHealth`/`HealthFinding`/`HealthFindingKind` preserved;
  `computeScheduleHealth()` now **delegates to the analyzer** and projects the
  report's shared analysis back through the **original scoring formula** —
  **byte-for-byte identical** output. `scheduleHealthFromReport()` exposes that
  projection.
- **Changed — `schedule_health_card.dart` consumes the report** (not a redesign):
  overall score `/100`, severity dot, and a **clickable category breakdown** (tap
  a lens → filter its findings), with the richer rule wording. Strictly
  monochrome (white → grey → amber). `manager_schedule_view.dart` computes the
  report once per build via the analyzer (same cost as the old single call);
  `schedule_inspector_drawer.dart` threads the report through (its per-employee
  wellbeing flags now read `report.findingsFor(uid)`). Grid untouched — cell
  drill-through deliberately deferred ("no layout work").
- **Tests:** `test/schedule_health_analyzer_test.dart` (**24** — each rule in
  isolation, analyzer aggregation, OCP custom-rule set, backward compatibility
  incl. the silent double-book penalty) + the frozen
  `test/schedule_health_test.dart` (6, **unchanged, still green**). `flutter
  analyze` clean; full suite **649 pass / 3 pre-existing fail** (the 2
  splash-centering + 1 stale `notification_grouping` tests, all in untouched
  files). No schema/rules/functions/DI/route/dependency change.

### Added (2026-07-09 — Schedule V2, inspector drawer, `feature/schedule-optimization`)

The right-hand rail (Pillar 1b) had a big empty area below its stats — turned it
into a **real inspector drawer**. Presentation only: **no schema/rules/backend
change**; all facts derived read-only from the loaded roster.

- **Added — `schedule_inspector_drawer.dart`** (extracted, stateless, testable
  in isolation — selection lifted to the parent): default view is the week
  overview + Schedule Health + a **tappable team roster**; tap a person and it
  swaps to their **week detail** — weekly **hours** (from the week's resolved
  overnight-aware `ShiftHours`), the morning/night/weekend split, days worked,
  **consecutive-day** streak, days off, a Sun→Sat **at-a-glance** strip, and any
  wellbeing flags (`health.findings` for that uid). Back returns to overview; a
  stale selection falls back to overview.
- **Added — `domain/employee_week_stats.dart`** (`EmployeeWeekStats` +
  `computeEmployeeWeekStats`): pure one-pass per-person week derivation.
- `manager_schedule_view.dart` holds only the `_selectedUid` and renders the
  widget (the ~330 lines of inline inspector were moved into the widget).
- **Tests:** `test/schedule_inspector_drawer_test.dart` (4) +
  `test/employee_week_stats_test.dart` (3). Full schedule/shell regression:
  **67 pass**, analyze clean. (The isolated widget test caught a value-row
  overflow before it shipped.)

### Added (2026-07-09 — Schedule V2, Pillar 2: Assignment Craft, `feature/schedule-optimization`)

Second pillar of **Schedule V2** — premium assignment-chip interaction, built by
**extending** `assignment_chip.dart` (no scheduling-architecture change). Every
new path reuses the **one validated move seam** (`onMoveChip` →
`MoveValidation.checkMove` → the existing Firestore write). Presentation +
interaction only.

- **Premium chips:** larger avatar (17→18) with the existing initials fallback,
  and the person's **`position`** ("Cashier"/"Supervisor") trailing the name in
  a quieter tone — single-line, ellipsizes first so a chip never outgrows the
  140px cell. Desktop hover tooltip shows the **full name + position** (touch
  keeps its caution-only tooltip, unchanged).
- **Bigger, richer target:** roomier chip padding (easier to grab) + a whisper
  of lift (soft shadow) on hover / keyboard focus.
- **Cross-day drag:** confirmed already routed through `MoveValidation` (the cell
  DragTarget was never same-day-only) — now **test-locked**.
- **Keyboard move (desktop):** Tab focuses a chip (focus ring), **arrows move the
  person** — ←/→ hop days on the same shift, ↑/↓ flip Morning↔Night — through the
  same validated seam. Edges are a quiet no-op.
- **Motion:** a one-shot **scale-in** when a person lands in a slot (chips keyed
  by uid so a person who stays put never re-animates); scale-only so it stays
  hit-testable mid-animation; honours reduce-motion.
- **Touch unchanged:** drag/keyboard/focus are desktop-gated; long-press still
  opens the action sheet (test-locked).
- **Tests:** `test/assignment_chip_interactions_test.dart` (6) — cross-day drag,
  ArrowRight/ArrowDown moves, edge no-op, position rendering, touch long-press.
  Full schedule/shell regression: **60 pass**, analyze clean.

### Added (2026-07-09 — Schedule V2, Pillar 1: Focus Mode + adaptive inspector, `feature/schedule-optimization`)

First pillar of the **Schedule V2** plan (scope locked in
`docs/design/SCHEDULE_V2.md` — a 20-point WMS brief triaged down to 7 lean
pillars). Presentation/chrome only: **no schema/rules/functions/route/DI change.**

- **Added — Pillar 1b, adaptive inspector layout** (`manager_schedule_view.dart`):
  on desktop / iPad-landscape (≥1024) the manager+admin schedule stops being a
  stretched phone — the **grid becomes the hero** in a left column and the
  at-a-glance analytics (**week totals + Schedule Health card**) dock into a
  right-hand **inspector rail**, visible alongside the roster instead of scrolled
  past. Touch widths keep the single stacked column + tap-to-open bottom sheets.
  Pure recomposition of existing widgets — the same insights/health are computed
  once and every edit/validation/save path is byte-identical. Verified via
  `flutter analyze` (clean) + the schedule/shell suite (58 pass, no regression).

- **Added — Focus Mode** (`core/widgets/app_shell.dart` + `app_sidebar.dart`):
  the persistent desktop nav sidebar collapses so the active screen runs
  full-width — Notion/Linear-style distraction-free mode. Toggle with **⌘\\** or
  the header collapse control; a quiet floating handle (⌘\\ too) restores it.
  App-wide (collapsing the shell sidebar is global by nature), MED risk but
  contained. Reduced-motion honoured; Semantics labels on both controls.
- **Architecture note:** `AppShell` became a `StatefulWidget` holding the
  `_focusMode` flag. Only the **sidebar width** animates (clip + `OverflowBox`
  so its contents never reflow); the `Expanded(child: …)` shell Navigator keeps
  a **stable position** in the tree, so the GlobalKey child is never remounted
  (the macOS nav-freeze failure mode) — guarded by a test.
- **Persistence:** in-session only — the shell is mounted once by the
  `ShellRoute`, so the choice survives every route change but resets on a cold
  launch. Cross-restart memory needs a local-prefs store the app doesn't have
  yet (deliberately not adding a dependency without sign-off).
- **Tests:** `test/focus_mode_test.dart` (3) — collapse hands content full
  width, restore brings the sidebar back, and the shell child `Element` is never
  remounted across toggles. Shell-adjacent suite (brand chrome, first-login
  gate, notification-tap probe) still green: 16/16.

### Added / Refactored (2026-07-08 — DROP Design System V2, Phase 1: Admin dashboard + reusable primitives, `core/optimization`)

Re-ranked the Admin Home around **"what needs my attention right now?"** through
*calm hierarchy* (never reduction — kept the premium DROP identity), and extracted
its building blocks as **reusable core primitives** every future module inherits.
Presentation + design-system foundation only: **no schema/rules/functions/backend/
business-logic change** — every cubit call, route and save path is identical. New
contract doc: `docs/design/DESIGN_SYSTEM_V2.md`.

- **Added — 4 core primitives** (`lib/core/widgets/`): `PageHero` (module-hero
  lockup with one primary CTA), `AttentionTile` (priority triage cell), `StatStrip`
  (quiet fact row), `ActivityCard` (clean vertical feed row — replaces the
  horizontal spreadsheet). Each ships a Semantics label, ≥44px targets,
  reduced-motion honouring, and lazy/capped collection rendering. Pure core — the
  living border is applied by the feature via `AttentionTile.radius`, not imported.
- **Added — task feature widgets:** `RecentActivityFeed` + `TaskActivityCard`
  (map tasks → `ActivityCard`), the reusable `FilteredTasksScreen`, shared
  `showTaskPreviewSheet`/`openTaskDetails` (`task_preview_sheet.dart`), and pure
  `task_metrics.dart` derivations.
- **Refactored — Admin Home** (`admin_dashboard_screen.dart`): Hero (Create Task
  CTA) → **Needs attention** dominant (Pending review · Overdue · Unassigned ·
  Sent-back · Swaps; most-urgent tile carries the living border, each drills to a
  filtered task view) → **Today** strip → **Recent activity** (no home filters) →
  **Operations digest** (requests · cases · schedule coverage) → Quick actions /
  Manage / Branch pulse. Kept the scoped-`BlocSelector` live architecture, added
  `PageStorageKey` + reduced-motion entrance gating.
- **Refactored — `task_feed_section.dart`** now delegates to the shared preview
  sheet (behaviour-identical for admin **and** manager home; one implementation).
- **Removed from Home:** the horizontal task "spreadsheet" + its filter chips (the
  full filtered feed still lives on the Tasks page via "See all").
- **Verification:** `flutter analyze` clean; new `task_metrics_test.dart` (8) +
  `dashboard_primitives_test.dart`; full suite **609 pass / 3 pre-existing fail**
  (2 splash-centering + 1 stale notification-category test, all in untouched files).

### Hardening (2026-07-08 — Production Readiness Audit, `core/optimization`)

Reliability audit — **report first, then only provably-safe fixes.** New
`docs/PRODUCTION_READINESS_AUDIT.md` covers reliability, error handling,
lifecycle, leaks, offline, disposal, logging, retry, loading/error/empty states,
Firebase exceptions. **Verdict: already well-hardened** — zero critical/high
defects. Confirmed healthy (documented so they're defended): no memory leaks
(every flagged controller is param-owned or a correct stream-merge teardown);
**every** cubit `.listen()` has `onError` → `.error` state with an
`if (!_hasSnapshot)` guard (no data-clobber, no stuck-loading); Firebase/Timeout
→ honest `ServerException` messages; loading/error/empty states + retry across 38
screens; offline persistence + `count()` cache fallback; 4 crash funnels +
release breadcrumbs; 0 `print()`.

- **Implemented (M1) — observability for best-effort swallows:** the 6
  intentional `catch (_) {}` enrichment sites (branch-name / member-directory /
  seen-dot persistence in `task_cubit`, `case_list_cubit`, `requests_list_cubit`,
  `case_seen_store`) now route through `AppLog.warning` so a **persistent** silent
  failure leaves a crash-report breadcrumb. Control flow unchanged (still caught,
  non-fatal). Analyzer clean; suite unchanged (same 3 pre-existing, unrelated
  failures).
- **Recommended, not implemented:** M2 — 35 `developer.log` calls bypass
  `AppLog` breadcrumbs (staged consistency pass). Lows: static-service timer
  cancel, one release `debugPrint` in splash, no `.empty` state factory (handled
  at widget layer). Not done blind — codebase is otherwise production-ready.

### Performance (2026-07-08 — Sprint 2: Render/Rebuild audit + const pass, `core/optimization`)

Rendering-performance sprint — **pixel-perfect, zero behavior/UX/feature/backend
change.** New audit `docs/performance/SPRINT2_RENDER_AUDIT.md` (Steps 1–8:
Bloc-rebuild, extraction, const, lists, heavy widgets, images, animations,
render-tree) with per-screen `BlocSelector`/`buildWhen` recommendations + rebuild
estimates.

- **Phase A implemented — `const` pass:** `flutter_lints` doesn't enable
  `prefer_const_*`, hiding **174** missing-`const` sites. Applied via `dart fix`
  (**~130 fixes across 56 files** — `SizedBox`/`Padding`/`Text`/`Icon`/
  `EdgeInsets`/`Divider`/`BorderRadius`/`Duration`). Behavior-identical by
  construction (`dart fix` only adds `const` to guaranteed compile-time
  constants → those widgets are canonicalized once and skip rebuild). Removed 2
  redundant nested `const`s in `app_theme.dart` that the fixer over-added. Lint
  config restored to original; analyzer clean; suite unchanged (same 3
  pre-existing, unrelated failures); no generated files touched.
- **Phases B–E recommended, deliberately NOT implemented blind:** `BlocSelector`
  for scalar chrome (Notifications/Cases/Requests/Statistics/Profile), `child:`
  hoisting on animation builders, plain-`ListView`→`.builder` on paginated feeds,
  persistent image cache. Each needs live rebuild-count/pixel verification (still
  blocked on the Phase 0.2 signing/auth issue); implementing them blind would
  risk the silent stale-UI regressions this sprint forbids. Home/Schedule
  rebuild-scoping left untouched (owner-frozen premium UI).

### Refactored (2026-07-08 — Sprint 1 Quick Win #3: split `task_action_sheets.dart`, `core/optimization`)

Organizational refactor — **pure extraction, zero behavior/UI/API change** (analyzer
clean; full suite unchanged — same 3 pre-existing, unrelated failures).

- Split the 2,447-line `task_action_sheets.dart` (40 classes) into a
  `task_action_sheets/` folder of **8 Dart `part` files** grouped by
  responsibility: `task_form_sheet`, `branch_picker_sheet`, `checklist_builder`,
  `assignee_picker_sheet`, `assign_sheet`, `review_sheet`, `shift_pickers`, and
  `shared/form_primitives`. Main file drops to **136 lines** (imports + `part`
  directives + the 4 public `show*` entry points + `SheetHandle`/`SheetTitle`).
- **`part`/`part of` (one library)** was chosen over separate libraries so the
  ~33 interdependent `_`-private widgets keep sharing scope **without being made
  public** — no visibility change, no circular-import risk, and every external
  import of `task_action_sheets.dart` (6 files) stays valid unchanged.
- Public API identical: `showTaskFormSheet`, `showAssignSheet`, `showReviewSheet`,
  `showSheet`, `SheetHandle`, `SheetTitle`, `ShiftChipPicker`, `ShiftRepeatPicker`,
  `WeekdayChipPicker`. No widgets deleted, no abstractions/base classes added.
- Noted but **not touched** (out of scope): `SheetHandle` is also defined in
  `schedule/.../sheet_chrome.dart` — a cross-feature duplicate to consolidate in a
  later `core/widgets` promotion pass, not here.

### Added (2026-07-08 — Sprint 1 Quick Win #2: Firestore Query Audit, `core/optimization`)

Audit only — **no code changed, no limits/pagination/indexes added.** New doc
`docs/performance/FIRESTORE_QUERY_AUDIT.md` inventories every client Firestore
query (all 14 `*_remote_datasource.dart`) with collection/where/orderBy/limit/
cursor/get-vs-stream/purpose/est-docs/behavior/issue/recommendation, grouped by
feature. Grounded in the **real internal-ops scale** (not theoretical 100k).
Findings: query layer is healthy — point reads + naturally-bounded collections
dominate; `notifications` (`where`+`orderBy`+`limit(30)`+composite index) and the
statistics `count()` aggregation are exemplary; **no composite index is missing**.
Only structural work = **deferred pagination on 6 admin/global streams**
(`watchAllTasks` first, then cases/requests/broadcasts/schedules/swaps) + one
consistency cleanup (`managerStats` → `count()`). Prioritized as Safe Quick Wins /
Needs investigation / Needs pagination later.

### Refactored (2026-07-08 — Sprint 1: single `AppDateFormatter`, `core/optimization`)

Code-quality consolidation — **maintainability only, zero visual change** (every
screen shows the exact same text; verified by analyzer + the full suite, incl.
the `clockTime`/`attachmentTimestamp` output-pinning tests).

- **Added** `lib/core/utils/app_date_formatter.dart` — the single source for
  turning a `DateTime` into a user-visible string. Pure Dart (no Flutter, no
  `intl`). Exposes only the styles the app actually shows: `time` (`4:32 PM`),
  `dayMonth` (`6 Jul`), `dayMonthYear` (`6 Jul 2026`), `monthDayYear`
  (`Jul 6, 2026`), `dayMonthYearTime` (`20 Jun 2026 • 4:32 PM`),
  `weekdayDayMonth` (`Monday, 6 Jul`), `numeric` (`8/7/2026`), `relative`
  (`Just now`/`5m ago`/…/`6 Jul`). Locked by `test/app_date_formatter_test.dart`.
- **Removed 21 duplicated month-name arrays** (+2 long-weekday arrays, +4
  copy-pasted 12h AM/PM blocks) across 21 files (task cards/feeds/details/sheets,
  schedule, admin, cases, profile, employee home, notifications, communications,
  requests, auth). Net `lib/`: **+58 / −250** lines.
- Feature format helpers (`activity_format`, `attachment_format`,
  `communications_format`, `request_format`) now **delegate** to
  `AppDateFormatter` (their public call sites are unchanged; only the duplicated
  internals were deleted).
- **Not unified (documented):** the domain `notify_task_event` usecase (would add
  a `domain → core/utils` dependency the codebase deliberately avoids), 24-hour
  shift-window times (`ShiftHours.format`), machine `yyyy-MM-dd` keys/filenames/
  persisted values, and elapsed-`Duration` labels (video length, "Waiting 3d",
  "Synced 3m ago", swap "2w ago"). The 3 divergent relative-time variants
  (requests/communications/tasks) keep their own wording but share the formatter
  for their absolute fallback.

### Added (2026-07-08 — Phase 0.1: Performance Baseline, `core/optimization`)

Measurement-only phase — **zero code changes**, no refactor, no optimization. Two
new documents under `docs/performance/`:

- `PERFORMANCE_BASELINE.md` — current-state measurement across startup, screens,
  resource usage, Firestore usage, and architecture metrics. Static metrics
  (📐) captured directly from source (`grep`/`wc`/reads); runtime metrics (⏱ —
  cold/warm start ms, TTFF/TTI, memory, CPU, FPS) are honestly marked
  `NOT CAPTURED` with a reproducible `flutter run --profile --trace-startup` +
  DevTools capture protocol (no numbers fabricated).
- `PERFORMANCE_BASELINE_ACTIONS.md` — every finding prioritized Critical/High/
  Medium/Low (backlog only, nothing implemented).
- **Headline findings:** 🔴 unbounded Firestore reads/streams — **0 `startAfter`
  cursors anywhere**, only 2 `.limit()` sites (notifications, profile); 🟠 TTI
  gated on `Future.wait` of home-critical reads; 🟠 non-virtualized list
  rendering (10 `.builder` vs 76 plain `ListView`); 🟠 wholesale rebuilds
  (`buildWhen`=0, `BlocSelector`=2, `BlocBuilder`=41); 🟠 `task_cubit` 1264 LOC /
  `task_action_sheets` 2452 LOC. Two prior-audit facts corrected (notifications
  have **no** cursor; `package:intl` used in **0** files).

### Fixed (2026-07-08 — Requests close-out: generated state + analyzer clean)

- Regenerated `requests_list_state.freezed.dart` after the Requests list state
  was simplified, fixing the stale `loaded(requests, busy, branchNames,
  selectedId)` generated signature that broke `RequestsListCubit` and
  `RequestsScreen`.
- Restored the `RequestRepository.getRequest` contract and
  `RequestStatus.isNegative` helper expected by the implementation and request
  tests.
- Cleaned the unrelated `AuthCubit` constructor lint so `flutter analyze` now
  finishes with **No issues found**. Focused Requests suites: **44 passing**.

### Added (2026-07-08 — Requests: admin soft delete + reopen; premium card pass)

Owner ask: delete (but soft), admin reopen as an escape hatch, and a more
premium card. All three verified live on macOS (reopen exercised end-to-end on
REQ-000002: Approved → Reopen → Pending with approve/reject + comments unlocked
→ re-Approved).

- **Soft delete (admin-only).** `deleteRequest` now stamps `deletedAt` instead
  of hard-deleting — the doc + its events stay as a record; the inbox streams
  filter deleted docs **client-side** (a `where(deletedAt, isNull)` query would
  drop every pre-existing doc missing the field). UI: a quiet trash icon in the
  detail header (admin only) with a destructive confirm → success toast → pop.
  Passes the existing rules as a plain admin update — **no rules change**.
- **Admin reopen.** `canReopenRequest` = admin ∧ decided. `reopen()` sends the
  request back to `pending`, clears `decided*`, stamps
  `reopenedBy/Name/At`; comments and the manager's Approve/Reject unlock again
  (the same pure predicates gate everything, so no new hierarchy logic).
  UI: a ghost "Reopen request" bar on a decided request (admin only), confirm
  dialog. New `RequestEventKind.reopened` renders as a pending-tinted
  `replay` chip; `onRequestUpdated` writes the event ("Reopened by X") and
  notifies the branch approvers + requester. ⚠️ The timeline chip +
  notifications require a **functions deploy**; until then reopen still works,
  the old deployed function just ignores the pending transition safely.
- **Premium card pass** (`request_card.dart`): 44pt icon tile with a soft
  status-tinted vertical gradient wash, refined title/summary rhythm, and the
  REQ reference (`# REQ-000002`) as a quiet trailing meta. **Pending rows alone
  wear a faint status-tinted border** — signal over volume; decided rows stay on
  the hairline. Detail action bar now three-state: decide / reopen / none.
- Tests: +8 (reopen/delete access, cubit reopen + soft-delete routing, model
  `deletedAt`, `reopened` kind parse) — 44 request tests green; freezed regen;
  `functions/index.js` syntax-checked.

### Fixed (2026-07-08 — New Request mobile UI: tile overflow + picker redesign)

On phones the New Request type picker rendered every tile with "BOTTOM
OVERFLOWED BY 5.7 PIXELS" — the grid used a fixed `childAspectRatio`, so on a
narrow screen the tile height came out shorter than its content.

- **Phone/tablet picker → full-width rows** (icon tile · title · full blurb ·
  chevron): rows size to their content so they *can't* overflow, blurbs read in
  full instead of truncating, and touch targets are bigger. The guiding question
  ("What do you need your manager to approve?") now leads the list — the mobile
  app bar has no subtitle slot, so it was previously invisible on phones.
- **Desktop picker** keeps the card grid but with a fixed `mainAxisExtent`
  (never an aspect ratio), so tiles are overflow-proof at any window width.
- **Latent bug caught by the new test:** the shared `AttachmentPickerField`
  header (`Text(title) + Spacer + counts`, used by task proof upload too) could
  overflow horizontally on narrow widths / large accessibility text — the title
  is now `Expanded` + ellipsized (identical rendering when space suffices).
- **Regression test** `request_create_picker_test.dart`: pumps the create flow
  at iPhone size (390×844) and desktop (1440×900), asserts zero layout
  exceptions, and walks type-tap → single-message form. All request suites
  green (36).

### Changed (2026-07-08 — Requests are employee→manager approvals; create is employee-only)

Owner ruling refinement: Requests are **employee approval requests**, not a
generic workflow engine. Flow is one-directional — an **employee** files, their
**branch manager** decides; the **admin** has global visibility and may decide
when necessary but is not expected to create requests. No super-admin, no
admin-to-admin workflow, no approval queue.

- **Create is employee-only:** the "New request" FAB on `RequestsScreen` (its
  only entry point) now renders for employees only. Because authors (employees)
  and deciders (manager/admin) are disjoint roles, **self-approval is impossible
  structurally** — no guard logic was added, none is needed. `canDecideRequest`
  stays exactly "admin or own-branch manager".
- **Copy reframed** (this + the previous pass): list subtitle per role ("Approval
  requests from your branch" / "…across every branch" / "Your approval
  requests"), role-aware empty states, create form says "What do you need your
  manager to approve?" + "Message to your manager", type blurbs speak to the
  employee ("Ask…", "Get your manager's help…", "Anything else that needs a
  manager's OK"), new-request notification says "New approval request".
- **Data cleanup:** deleted the admin-authored smoke-test request (REQ-000001)
  filed during the freeze verification — it contradicted the rule and confused
  the owner.
- **Verified live** (macOS, admin): no FAB, clean empty state, no freeze. All
  request test suites green; `flutter analyze` clean.

### Changed (2026-07-08 — Requests simplified to a lean approval, not a ticket)

Owner ruling ([[project_requests_simplicity]]): a Request is "someone asking
approval before doing something" — it must feel like sending a message that
needs a yes/no, **not** a Jira/helpdesk ticket. Stripped everything that made it
feel like a ticketing platform. Flow is now only **Create → Pending → Approved /
Rejected**.

- **Statuses → 3.** `RequestStatus` is now `pending / approved / rejected`
  (dropped `completed` + `cancelled`). `approved`/`rejected` are terminal;
  `isActive` = pending. `RequestEventKind` lost `completed`/`cancelled`.
- **Form → Type + one message.** Deleted the per-type dynamic schema
  (`request_schema.dart`, `request_field_spec.dart`, `dynamic_request_form.dart`).
  A request now captures a single free-text **message** (`details['message']`);
  `RequestEntity.summary`/`message` read it. Create screen = pick type → one
  message field → optional attachments → submit. Type-picker cards resized
  (`GridView.extent`, no more giant tiles).
- **Removed priority + approvalPolicy.** Deleted `RequestPriority` +
  `RequestApprovalPolicy` (enums, entity/model fields, ordering, card chip,
  create toggle, detail meta). Deciding is simply admin (global) or the
  own-branch manager — `canDecideRequest` no longer consults a policy; the
  `firestore.rules` update gate dropped the `adminOnly`/`cancelled` clauses.
- **Metrics slimmed** to Pending/Approved/Rejected counts that double as the KPI
  filters (dropped avg-approval-time, top-type, "done today").
- **Detail actions** are just Approve / Reject (no complete/cancel); the detail
  shows a **Message** card; a decided request is read-only.
- **Cloud Functions** (`onRequestCreated`/`onRequestUpdated`): approver routing is
  now "branch managers + admins" (no policy); dropped the priority tag and the
  `completed`/`cancelled` lifecycle branches. `refCode` (REQ-######) + the
  submitted/decision events + notifications are unchanged.
- **Kept intentionally:** the server `refCode` sequence (invisible, doesn't make
  the UX feel like a ticket) and the `requestCompleted`/`requestCancelled`
  notification enum values (harmless back-compat for any already-sent notices).
- **Verified live** (macOS): file a request → Pending → open → Approve → the
  decision chip + read-only lock render, `REQ-000001` assigned. Tests: the 8
  request suites updated/trimmed (36→ still green); full suite 535 pass (3
  pre-existing failures are in the separate in-progress notifications/splash
  work, not requests).

### Fixed (2026-07-08 — Requests screen froze on open (empty-state infinite height))

Opening **Requests** (or any list rendering an empty state as a `ListView`
child) hard-froze the desktop app. This is the *real* cause of the "clicking
Requests freezes" report — distinct from, and not fixed by, the earlier
`AnimatedDropLogo` sidebar change below.

- **Root cause:** `DropEmptyState` / `AppEmptyState` use the "fill the viewport,
  still scroll" idiom (`LayoutBuilder` → `SingleChildScrollView` →
  `ConstrainedBox(minHeight: constraints.maxHeight)`). That is correct as a
  direct `RefreshIndicator` child (bounded height), but `RequestsScreen` renders
  the empty state **inside its `ListView`**, which gives children *unbounded*
  height. `minHeight` became `Infinity` → `BoxConstraints forces an infinite
  height` re-thrown **every frame**, drowning the UI thread = the freeze.
  Reproduced live: the assertion flooded the log the instant Requests opened;
  gone after the fix.
- **Fixed:** both empty-state widgets now clamp `minHeight` to `0` when
  `constraints.maxHeight` is not finite (`isFinite ? maxHeight : 0`) — identical
  behaviour in the normal bounded case, safe when nested in any scrollable.
- **Scope:** two core widgets only (`drop_empty_state.dart`,
  `app_empty_state.dart`); no route, schema, rules, repository, cubit, DI, or
  function change. Protects every empty-list surface app-wide.

### Fixed (2026-07-07 — Desktop sidebar idle freeze when clicking Reports/Requests)

Clicking the old Reports/Requests area on macOS desktop could look like the app
froze even though the target route was not crashing. The live process had an
empty `last_crash.log`, the widget tree was still on `AdminShell`, and sampling
showed Flutter frame/path work at idle.

- **Root cause:** persistent `AppSidebar` chrome mounted `AnimatedDropLogo`, so
  the forever-running shimmer kept the desktop UI/raster pipeline hot while the
  user was idle or navigating.
- **Fixed:** `AppSidebar` now uses static `DropLogo` again; `AnimatedDropLogo`
  stays limited to transient brand surfaces. `brand_chrome_test.dart` now asserts
  the sidebar does not mount `AnimatedDropLogo`.
- **Scope:** no route, schema, rules, repository, cubit, DI, function,
  dependency, or generated-file change.
### Refactored (2026-07-08 — Work Details design system: one language, composed per type)

A **presentation-only** unification of the work-type detail experience — no
business logic, no domain changes, every save/read path identical. Instead of
each work type inventing a layout, there is now **one Apple-flavoured section
kit** that every type *composes* differently.

- **New design-system kit** `work_detail_sections.dart` — the shared alphabet:
  `WorkCard` (the one card surface), `WorkStatStrip`/`WorkStat` (Apple
  Health/Wallet three-up metrics), `WorkProgressBar`, `WorkSegmentBar`
  (pass/warn/fail distribution), `WorkStatePill` (monochrome; red only for the
  off-nominal case), `WorkFacts` (premium captured-data, not a table),
  `WorkEyebrow`, and `WorkFmt` number/money formatting.
- **`WorkTypePanel` is now a composer, not a custom layout.** It assembles the
  same sections per type: **Purchase** → budget card (Budget · Spent ·
  Remaining + burn-down progress + within/over-budget state); **Inventory** →
  Expected · Counted · Difference with a reconciled/surplus/shrinkage state;
  **Inspection** → score card (`n of N passed`) + pass/warn/fail segment bar +
  markable points; **Transfer** → route (dispatch → destination) + a connected
  timeline. An **unrecognised type composes the generic sections** from its own
  declared fields/timeline/points — so a new work type still gets a premium
  detail view with **no screen edit** (the Open/Closed promise, preserved).
- **Screen hierarchy** now reads Summary → Status → **Metrics** → Details →
  Evidence → Activity → Review: the work panel moved directly under the status
  header on both mobile and the desktop two-column record, so the whole job is
  legible in seconds.
- **Shared blocks elevated** into the same language: the **Checklist** now leads
  with an "X of Y done" progress bar inside a card (reads as completed work),
  and **Submitted Work** is a premium summary card (Notes / Evidence).
- Panel tests rewritten to the new system (budget, over-budget, inspection
  score + points, transfer route + timeline, reconciled fast-path); `flutter
  analyze` clean, full suite green.

### Refactored (2026-07-08 — Create Work sheet: premium workflow-builder UX)

A focused, **presentation-only** pass on the create/edit task sheet
(`task_action_sheets.dart` + `dynamic_work_form.dart`) — no logic, architecture,
persistence or business rules changed. The long flat stack of bordered
containers now reads as a **workflow builder**: grouped, staggered sections
(Overview · Steps · Reference · Assignment · Scheduling) that fade + lift in on
open, with a monochrome premium kit shared across the form.

- **Work type is now a hero card → rich chooser sheet** (was a row of chips):
  the defining choice opens the form as an icon · kind · blurb summary, and
  tapping it reveals a scannable sheet listing every registered type with its
  one-line blurb. Locked to a static (lock-glyphed) card in edit mode, unchanged.
- **Dropdown-heavy selectors replaced by modern controls:** priority, assignment
  mode and recurrence are **sliding iOS-style segmented controls** (`_Segmented`
  with an eased white thumb); the **admin branch dropdown** and the **assignee
  picker** are now **searchable bottom sheets** fronted by summary tiles (branch
  name / stacked assignee avatars + count). Same state, same `assigneeIds` /
  `branchId` / `assignmentType` / `priority` / `recurrence` wiring underneath.
- **Premium checklist builder:** numbered, ordered steps (an ordinal badge
  instead of a fake drag handle), an animated add/remove, a dashed "Add step"
  affordance, and a quiet empty state.
- **Better validation & scheduling:** the top-level error is an **animated
  monochrome error banner** (slides open / collapses) instead of raw red text;
  the deadline is a summary tile with **Today / Tomorrow / Next week** quick
  chips over the calendar picker.
- **Consistency:** kept the app-wide "New Task" / "Create Task" wording, the
  shift-mode pickers (`ShiftChipPicker` / `ShiftRepeatPicker`, still reused by the
  recurring-shift sheet), and every save path. Tests updated for the new
  work-type interaction; `flutter analyze` clean, full suite green.

### Added (2026-07-07 — Work-type framework: polymorphic tasks (complete: domain · persistence · create · details · workflow))

A task is no longer "title + description + checklist." Each **operational work
type owns its own fields, milestones and rules** behind a Strategy + Registry, so
adding a completely new kind of work is **one definition file + one line in the
registry** — no `switch`, no screen edits, no rules change (Open/Closed). Ships
end-to-end: the domain framework, its persistence seam, the dynamic create form,
the adaptive details screen, and the cubit workflow wiring.

- **Workflow wiring:** the employee's "Submit for review" now routes through the
  type's `validateSubmission` (`completeAndSubmit` counts proof being uploaded
  *now* via `WorkContext.withPendingProof`; `submitForReview` too) — an inventory
  count can't submit without a counted qty, a transfer without its handover
  photo, an inspection until every point is marked (this also *fixes* inspections,
  which the old checklist-completed gate would have wrongly blocked). The
  **manager fast-path**: reconciled / passed / within-budget work (`fastTrack`
  disposition) floats to the top of the Pending Review leaf with a "ready to
  fast-track" note. Tests: `task_submission_gate_test.dart` (gate blocks/passes).

- **Adaptive details screen** (`work_type_panel.dart`): a `WorkTypePanel`
  injected into both mobile + desktop layouts renders, driven entirely by the
  definition (the screen never branches on type): the type summary/metric, a
  manager **"Auto-approvable"** fast-path hint (`reviewDisposition`), read-only
  captured setup fields, the **inspection pass/warning/fail** point marker
  (monochrome; red only for the failure case), employee **completion capture**
  (counted qty / amount spent, buffered → Save, reusing `DynamicWorkForm`), and
  the **milestone spine** (Transfer's Dispatched → Received with a compact "Log"
  action). The plain checklist section is suppressed when a type owns it
  (`usesChecklistAsPoints`). New cubit methods `updateWorkData` (merge into
  `data`) + `logWorkEvent` (milestone → `activityLog`), each a single
  `_updateTask` write — **permitted for an assignee by the existing denylist
  rules, no rules change**. Setup-vs-completion field split (`capturedAtCompletion`
  → `setupFields`/`completionFields`) so the create form no longer shows the
  manager employee-captured fields. 7 panel widget tests.

- **Dynamic create form** (`dynamic_work_form.dart`, `work_type_presenter.dart`):
  the create sheet gained a monochrome **`WorkTypePicker`** (chips over
  `WorkTypeRegistry.all`, locked in edit mode) and a **`DynamicWorkForm`** that
  renders one input per `WorkFieldSpec` for all 9 field kinds
  (text/multiline/number/integer/currency/date/time/toggle/select), reports a
  `Map<String,dynamic>` up, and highlights `validateSetup` field errors inline.
  Wired additively into the existing premium sheet (title → type → dynamic fields
  → …); `TaskCubit.createTask` now takes `workType`/`data`; recurring shift
  templates stay General-only for now (guarded, no silent drop). 7 widget tests.

- **Work-type kernel** (`domain/work_types/`, Flutter-free + unit-testable):
  - `WorkTypeDefinition` (Strategy) + `BaseWorkType` (parity defaults — a type
    overrides only what differs); `WorkTypeRegistry` (Registry/Factory) resolves
    by a stable string id, **unknown/legacy/null → `general`** (safe rollback, no
    migration).
  - `WorkFieldSpec` / `WorkFieldKind` (9 kinds; self-validating), `WorkContext`
    (entity-decoupled live snapshot), `WorkDraft` (create-time snapshot),
    `WorkEvent` (per-type **timeline milestones** layered on the generic
    `activityLog.status` — no `TaskStatus` enum growth), `ReviewDisposition`
    (`standard`/`fastTrack` — the **manager fast-path**), `WorkValidation`.
- **5 real operational types**, each a self-contained file with full behaviour
  (fields · timeline · setup+submission gates · progress · review disposition ·
  proof · summary · analytics): **General** (parity), **Transfer/Handover**
  (dispatch→receive handshake, proof-on-dispatch, peer-confirmed fast-track),
  **Purchase/Errand** (budget vs. spend, receipt proof, over-budget/reimbursement
  → standard review), **Inventory Count** (variance, discrepancy-must-be-explained
  gate, reconciled → fast-track), **Inspection** (reuses the generic checklist as
  points, per-point pass/warning/fail in `data`, any fail → standard review).
- **Persistence (additive, backward-safe):** `TaskEntity`/`TaskModel` gain
  `workType` (string, default `general`) + `data` (`Map<String,dynamic>`, keyed by
  field key). The model converts `DateTime ↔ Timestamp` inside `data` (recursing
  nested maps/lists). Old docs default cleanly; **no migration**. Single adapter
  `TaskWorkX` (`workDefinition`/`workContext`/`workDraft`) is the only seam
  between the entity and the kernel.
- **Tests:** `work_type_registry_test.dart` (22 — resolution/fallback + all 5
  types' divergent behaviour), `task_model_work_type_test.dart` (round-trip incl.
  DateTime, nested maps, legacy back-compat, adapter). Existing task suite green
  (zero regressions).

### Added (2026-07-07 — Configurable shift hours (end times are data, not code))

The night-shift close is no longer a hardcoded `weekend → 00:30`; shift hours are
**configurable per (day, shift)** and editable in-app, with the same value flowing
to every surface and to the live countdown.

- **New domain `ShiftHours`** (`domain/shift_hours.dart`) — start/end as minutes
  past midnight; **end may exceed 1440 for overnight** (00:30 = 1470, 01:00 =
  1500), the single source of truth for *"does it cross midnight and until when"*.
  `format()`, `crossesMidnight`, `toMap`/`fromMap` (guarded), and
  `ShiftHours.standard(day, shift)` (the standing baseline, overridable).
- **Per-week overrides on the schedule doc** — additive
  `weekly_schedules/{id}.shiftHours = { <day>: { <shift>: {start,end} } }` (like
  `dayNotes`/`leave`; **no rules change**), resolved through
  `WeeklyScheduleEntity.hoursFor(day, shift)` (override ?? standard). Per-week
  storage is the natural home for the stated future needs (Ramadan, holidays,
  seasonal, special events); the `hoursFor` seam lets a branch-level standing
  layer slot in later without touching call sites.
- **Manager/admin editor** in the day sheet (`day_details_sheet.dart` → new
  *Shift hours* section): each shift shows its configured `16:30 → 01:00`, a
  *Custom* badge when overridden, an **edit** action (time picker — an end
  at/before the start is read as the next day, so 01:00 becomes overnight) and a
  **reset to default**. Writes via `ScheduleCubit.setShiftHours` →
  repository/datasource (dotted-path `shiftHours.<day>.<shift>`).
- **Config-driven everywhere** — `ShiftWindow` (`startOf`/`endOf`/`phaseOf`/
  `nightSpillEnd`) takes the resolved `ShiftHours`, so the live status is
  **On now** until the configured close (Friday until 00:30, Saturday until
  01:00, past midnight). The employee hero countdown, week rows, and shift sheet,
  plus the manager shift-details sheet and day-sheet header, all render
  `hoursFor(day, shift)` (arrow form `16:30 → 01:00`). The old hardcoded
  weekend branch and the tiny "till 00:30" label are gone.
- **Visual refinement** (frozen layout, existing tokens only): the configured
  time now reads at **secondary** (not the dimmest tertiary) with **tabular
  figures** on every time/countdown label, so times align down the week column
  and the live countdown never nudges the label as digits change.

Tests: `shift_hours_test.dart` (value object, overnight formatting, parse
guards, `standard` defaults, `hoursFor` override resolution, Firestore
round-trip), `shift_window_test.dart` (configured overnight phase past midnight),
and an employee-display test that a configured Saturday 01:00 renders
`16:30 → 01:00`. Suite: **504 pass / 2 pre-existing splash failures**;
`flutter analyze` 0 new.

### Fixed (2026-07-07 — My Schedule shift-window API mismatch)

- Fixed the two analyzer errors in `my_schedule_screen.dart` caused by stale
  calls to removed `ShiftWindow.spillingNightFrom` and `ShiftWindow.phase`
  helpers. The employee hero now uses `ShiftWindow.nightSpillEnd` and
  `ShiftWindow.phaseOf` with the loaded schedule's `ShiftHours`.
- Added `ShiftWindow.startOf(...)` so configured start times participate in
  phase/countdown math alongside configured end times.
- Employee My Week time displays now format from
  `WeeklyScheduleEntity.hoursFor(...)`: hero countdown, week rows, next-shift
  start labels and the shift detail sheet all stay aligned with `shiftHours`
  overrides. The previous-week Saturday tail still falls back to standing hours
  because only that previous crew set is cached.

Tests: `flutter analyze lib/features/schedule/domain/shift_window.dart
lib/features/schedule/presentation/pages/my_schedule_screen.dart
test/shift_window_test.dart`; `flutter test test/shift_window_test.dart
test/my_schedule_tab_test.dart`.

### Added (2026-07-07 — Multi-line day notes + premium employee shift sheet)

Owner-directed enhancement (mockup-driven, inside the frozen premium UI): the
day note becomes a **multi-line briefing shown as bullets**, and the employee's
tap-to-open shift sheet is upgraded to the mockup (day · shift · arrow time ·
notes bullets · manager · team · **Swap Shift**).

- **Notes are now multi-line, no schema change.** `dayNotes.<day>` stays a
  single string; the manager types **one instruction per line** and each line
  renders as a bullet (`WeeklyScheduleEntity.noteLinesFor`, unit-tested).
  Manager entry (`day_details_sheet.dart`) is now a 3–8 line field, cap raised
  120 → 600 chars, Enter inserts a newline, explicit save. No Firestore rules
  change (verified: no note-length constraint).
- **Cards stay clean and glanceable.** The full note text is no longer printed
  on the today hero or week rows — each shows a quiet **"Note / N notes"
  indicator** instead; the full bulleted note lives only in the sheet (owner
  ruling: don't duplicate notes on the card).
- **Premium shift sheet** (`_ShiftDetailsSheet` rebuilt): day + shift title,
  **arrow time `16:30 → 00:30`**, **Notes as bullets** (un-truncated), manager,
  teammates, and a **Swap Shift** button when the slot is still requestable and
  a coworker holds the opposite shift. Handles off/leave days too (note +
  manager, no time/team/swap).
- **Rows/hero are now tappable → the sheet.** The inline `Swap`/`Today`/`Past`/
  `—` trailing widgets are gone from the week rows (Swap moved into the sheet);
  a chevron marks a row that opens details. Plain off days with nothing to show
  stay inert.
- **Arrow time on employee surfaces:** `_arrowRange` renders the loaded
  `ShiftHours` with the arrow separator on the hero countdown, week rows and
  sheet; manager/admin surfaces keep their existing en-dash styling.

Tests: `noteLinesFor` split cases + reworked widget tests (note indicator on
card / bullets in the sheet, arrow times, Swap offered in the sheet on today's
future shift, clean rows). Suite: **489 pass / 2 pre-existing splash
failures**. `flutter analyze`: 0 new.

### Changed (2026-07-07 — Employee My Week: premium UI kept by owner ruling + live improvements)

An answer-first minimal rework of the employee My Week tab was built and
**reverted the same session by owner ruling** — the premium hero/week-cards UI
is THE employee schedule UI on every tier, and the owner wants **visible
craft, not reduction** ("something that clearly had work spent on it"). The
mobile schedule UI is now **frozen except for incremental improvements** inside
its design language. The functional wins from the rework were kept and folded
into the premium UI:

- **Added — live shift-status pill** (hero countdown row): `In 4h 30m` before
  the shift (always, not only <2h; `In 2d` beyond 48h), `On now · till 00:30`
  while it runs, quiet `Ended` after — re-rendered on a minute-aligned tick so
  it never goes stale.
- **Fixed — weekend/midnight time math is structural:**
  `ShiftHours` + `WeeklyScheduleEntity.hoursFor(...)` + pure
  [`shift_window.dart`](lib/features/schedule/domain/shift_window.dart)
  (configured start/end/phase on `[start, end)`, spill detection; unit-tested).
  Overnight shifts are **active past midnight until their configured end**
  (naive same-day math read "ended" all evening), and during the small-hours
  tail the hero **keeps showing the running night shift** instead of flipping to
  "Day Off" — the Sat→Sun tail crosses the week seam via
  `ScheduleCubit.previousSaturdayNight`.
- **Fixed — today's still-future shift is swappable:** the week row's
  redundant "Today" pill no longer eats the action slot when the shift hasn't
  started (the row is already highlighted + filled day chip); it still shows
  for today's started shift.
- **Added — "Next shift · Thursday Night · 16:30"** line on off/leave-day
  heroes (new `WeeklyScheduleEntity.nextShiftAfter`, unit-tested); says
  "No more shifts this week" when the week is done.
- **Fixed — day notes never truncate:** hero + week-row notes wrap in full
  (were single-line ellipsized 11px captions) — notes are first-class.
- **Added — Swaps tab warning dot (phones):** while a pending swap on a
  **still-future** slot targets the user (stale requests filtered via
  `SwapEligibility`, so an unanswered old request never nags).

Tests: `shift_window_test.dart` (midnight rollover, phases, spill window) +
reworked `my_schedule_tab_test.dart` (swap-on-today via a next-week fixture,
un-truncated notes, exact leave + next-shift line, tab-dot show/stale, both
legacy regression tests kept; every test unmounts — the countdown pill owns a
minute Timer). Suite: **487 pass / 2 pre-existing splash failures**.
Deferred as before: Employee Home generic "Off today" when leave exists
(follow-up task spawned).

### Changed (2026-07-06 — Task Details activity timeline rework: hero head + ledger rows)

The Task Details **activity timeline** was rebuilt from a stack of heavy
per-event cards into a **flight-recorder** read (new
`presentation/widgets/activity_timeline.dart`, replacing the private
`_ActivityTimeline`/`_EventCard` in `task_details_screen.dart`; used by both
the mobile and desktop layouts):

- **Hero current-status card** at the head — `CURRENT STATUS` eyebrow, big
  state-coloured title, "Approved by / Submitted by …" actor line with avatar +
  quiet hairline role chip, relative **and wall-clock** time (new
  `clockTime()` in `activity_format.dart`), note callout + media. The head
  node carries a slow **breathing glow only while the task is in flight**
  (pending/started/completed/in-review/rework); terminal states sit still —
  same philosophy as the cards' living borders. One animation controller
  total.
- **History as compact ledger rows** — no per-event card chrome (borders /
  shadows / repeated panels deleted): state-coloured node + title, tiny
  avatar + `name · Role`, right-aligned relative + exact time, notes as
  quote-lines with a state-coloured accent edge, media as micro-thumbnails
  (`+N` overflow + "3 photos · 1 video" summary). Roughly 60% less vertical
  space per event; submission rows still open the `SubmissionDetailsSheet`.
- **Colour-blended spine** — each connecting segment fades this event's state
  colour into the next one's, so a rework loop literally reads as colour flow
  (amber → red → purple …).
- **Fold for long histories** — past 8 history rows the timeline folds behind
  "Show N earlier events" (head + 6 newest stay visible).
- **Soft state palette centralised** — the living-border hues are now public
  `kState*` consts in `activity_format.dart` (canonical; `task_card.dart`
  aliases them) and `activityColor` maps every activity kind onto them
  (started → purple, created/assigned → baby blue, rework/issue → soft red
  `#F87171`, review/warning → amber, approved → green, completed → neutral).
  Admin feed dots + task-feed expansion timelines inherit the same hues.
- Tests: new `activity_timeline_test.dart` (palette pins, `clockTime`, hero +
  ledger render, fold/expand) + `note_category_test.dart` expectations aligned
  to the soft palette. 467 passing (2 pre-existing splash-centering failures
  unrelated to this change).

### Added (2026-07-06 — Schedule 5.0: leave & day notes, health analysis, presentation Final View)

A usability/operations upgrade of the manager/admin **Schedule** surface — same
monochrome design language, architecture and interactions; 16-point owner brief.

- **Leave, day notes and shift-hour overrides (schema, additive):**
  `weekly_schedules/{id}` gains `dayNotes { <day>: text }`,
  `leave { <day>: { <uid>: <type> } }`, and
  `shiftHours { <day>: { <shift>: { start, end } } }`. Leave is day-level;
  `ShiftHours` stores minutes after the slot day's midnight, with overnight
  ends allowed past 1440. New repo/datasource writes `setDayNote` / `setLeave`
  / `setShiftHours` (dotted-path updates + `FieldValue.delete()` for clears)
  through the existing `_mutate` busy cycle. **No rules change needed** — the
  generic manager/admin `weekly_schedules` update rule already covers the new
  fields. No deploy required.
- **Grid (Schedule 5.0):** a new **day-info footer row** shows leave mini-pills
  (`Ahmed · Sick`; *pending* renders hollow/italic) and the day-note pill
  directly under each day — visible without opening anything; tap it or the day
  header → the new **day sheet** (`day_details_sheet.dart`: date + weekend
  hours, Morning/Night staffing facts, 120-char note editor, add/remove leave
  via the shared employee picker + a type picker). Cells grew **128×122 →
  136×140** (stretching to full width on desktop as before); every staffed cell
  carries a **quiet corner count** (staffing at a glance); empty editor cells
  are a small dashed **"Open"** (the old icon + "No one" placeholder removed);
  today's column adds a whisper of white tint on top of the existing ring.
  day headers carry late-close tags from `WeeklyScheduleEntity.hoursFor(...)`
  (`ShiftHours.standard` keeps Thu/Fri/Sat nights at `16:30 – 00:30`; overrides
  can extend or adjust individual slots).
- **Insights (extended, still one pass per build):** new facts **short rest**
  (night → next-day morning, ~8–9.5h turnaround; amber) and **on leave &
  assigned** (red) join open/one-person/double-booked on the clickable insight
  strip; affected chips get an **amber dot + tooltip**. Week totals power a new
  compact **week summary** caption under the grid (`14 morning · 12 night · 2
  on leave · 1 open · 6 people scheduled`).
- **Schedule Health (new pure `domain/schedule_health.dart`):** week-level
  wellbeing read per person — grouped-run analysis (M·M·M·off·N·N·N is the
  healthy shape), **morning↔night ping-pong**, **night→morning short rests**,
  **6/7-day runs**, team **workload spread** — scored 0–100 → **Healthy / Fair
  / Strained** with actionable recommendations ("Group their morning shifts…").
  Rendered as a collapsed one-row **Schedule Health card** under the grid
  (`schedule_health_card.dart`), expandable to the findings. **Advice, never a
  gate** — nothing blocks an edit or publish (facts-not-quotas ruling).
- **Guarded edits:** moving/switching someone onto a day they're marked on
  leave asks for explicit confirmation (same confirm-not-block pattern as
  `wouldEmptySlot`); the assign picker rows caption `On leave · <type>`.
- **Final View → presentation mode:** the export grid renders print-clean
  (`presentation` flag on grid/cell/chip): **no dashed placeholders, hover/drag
  affordances, editing indicators or empty-state icons** — empty slots are quiet
  em-dashes, **all names render** (no "+N more" collapsing), leave + notes
  print when present, weekend tags included, legend reduced to a single
  *Today* dot, new *on leave* fact pill. Toolbar/PNG export flow unchanged.
- **Width:** the desktop toolbar padding now matches the grid's 24px page
  padding (was 40px) so the toolbar aligns with the week and the schedule uses
  the full desktop width.
- **Employee parity (same-day follow-up slice):** the employee **My Schedule**
  now tells the same story as the manager grid — week rows and the today hero
  name a recorded leave instead of a generic "Off"/"Day Off" (**Annual Leave ·
  Sick Leave · Day Off · Leave Requested**, matching icon), show the manager's
  day note, and every night time-label is schedule-aware via
  `WeeklyScheduleEntity.hoursFor(...)` (default Thu/Fri/Sat =
  `16:30 – 00:30`; overrides can differ). A person rostered *and* marked away
  sees "Also marked … — check with your manager".
- **Cross-week short rest:** `ScheduleCubit` now also loads the **previous
  week's Saturday-night crew** (third parallel read, best-effort — a missing
  week or failed read = empty set, never fails the load; exposed as cubit
  context `previousSaturdayNight`, not in the freezed state). Insights + health
  consume it, so **Saturday night (ends 00:30!) → Sunday morning** finally
  counts as a short rest; only the Sunday-morning slot highlights (last week's
  night isn't on this grid). Threaded into the Final View for consistent
  printed cues.
- **Tests:** `schedule_health_test` + `weekly_schedule_model_test` (new),
  `schedule_grid_test` (+4: weekend tags, leave/notes strip + day-tap,
  presentation, corner count), `schedule_insights_test` (+4 incl. cross-week),
  `schedule_final_view_test` (presentation assertions), `my_schedule_tab_test`
  (+1: employee leave/notes/weekend-hours row). Full suite: **463 pass, 2
  fail** (the 2 = pre-existing desktop splash-framing tests, verified failing
  on a clean tree). `flutter analyze`: 7 pre-existing infos, 0 new.
- **Not in this slice (deliberate deferral):** an employee leave *request*
  flow — managers record `pending` manually after a conversation. A
  request→approve pipeline would duplicate the swap/Cases machinery for a
  small team; revisit only if the manual flow proves painful in practice.

### Changed (2026-07-06 — Living-border orbit: per-state colour palette)

Reworked the `LiveStatusBorder` colour model back to **per-state persistent
colours** with a **soft, muted palette** (owner spec — motion / architecture
unchanged, colours only). The orbit now holds each state's own colour for as long
as that state lasts and **eases smoothly to the new colour on a state change**
(no snap), replacing the previous amber-persistent + transient-flash model.

- **Palette** (`liveActivityColor(task)`, all soft + slightly desaturated to blend
  with the dark dashboard): pending → **baby blue `#7DD3FC`** · started → **purple
  `#A78BFA`** · in review → **amber `#F59E0B`** · rejected → **soft red `#F87171`**
  · overdue → **orange `#FB923C`** (*takes precedence*) · approved / completed →
  `null` (no orbit, only the static border).
- **Widget:** dropped the transient-flash machinery (`flashColor` / `flashKey` /
  the amber→state→amber envelope). `LiveStatusBorder` now takes just
  `color`/`speed`/`pulse`; a `color` change drives a smooth `_Phase.changing`
  colour ease (`Color.lerp` + `easeInOut`) over `transitionDuration`, then steady.
  **Every bit of motion is byte-for-byte unchanged** — the corner-eased warp LUT,
  +8% corner highlight, overdue pulse, comet, inner bloom, controllers, and perf
  strategy (no rebuilds during animation, no heavy `paint()` allocations).
- **Call sites** updated (task cards + Admin Task Queue) — removed the flash
  args; the Task Queue orbit is orange when overdue else amber, from the same
  shared palette.
- **Tests** updated (`task_card_live_status_test.dart`, 11): per-state palette +
  overdue override, per-state speed, pulse, and orbit pass-through / loop /
  **smooth colour ease (no snap)** / graceful terminal fade-out. `flutter
  analyze`: 7 pre-existing infos, 0 new. Full suite: **445 pass, 2 fail** (the 2 =
  pre-existing desktop splash-framing tests).

### Fixed (2026-07-05 — Recurring shift-task Save freeze)

Fixed the app appearing frozen after **Save Recurring Shift Task**. The Manage
sheet previously opened the Add form as a second modal bottom sheet; after Save,
the stacked modal barriers could leave the underlying screen dimmed and
input-blocked. Add now dismisses Manage before presenting the form, guaranteeing
one modal route/barrier at a time and returning to Operations after Save.

Also removed nonessential post-save latency: template persistence is now the
Save boundary, while deterministic today-instance creation, roster resolution,
and assignment notification run best-effort via an unawaited
`_materializeTodayInstance`. The scheduled generator remains the fallback and
duplicate prevention is unchanged. Added `recurring_shift_task_test.dart` to
prove Save does not await a stalled instance write. No schema/rules/function,
route, dependency, or deploy change.

### Added / Refactored (2026-07-05 — Branch Operations premium KPI drill-downs)

Made all four Branch Operations KPI cards — **Active tasks, Overdue, Pending
review, Staff active** — accessible premium hover/press entry points. They open
the new reusable `OperationsMetricScreen` through the cockpit's existing local
`Navigator.push` pattern, with a distinct branded hero, supporting facts, live
count and responsive content for each metric: prioritized active tasks,
oldest-first overdue triage, the review queue, and today's staff roster with
employee drill-downs. The faint bottom-right hero watermark now renders the
real asset-backed `DropLogo`, while the leading plaque keeps its metric-specific
icon; this uses a new opt-in `BrandWatermark.assetLogo` mode so existing branded
heroes remain unchanged. Staff Active deliberately retains its existing meaning:
**rostered today**, not clocked in.

Refactored the three task classifications into public pure predicates in
`branch_workload.dart`, shared by the headline aggregation and detail lists so
their semantics cannot diverge. The screen reuses the inherited live
`BranchOperationsCubit` / `TaskCubit`, `ManagerTaskCard`, and `WorkloadCard`.
No new Cubit/state, backend query, repository/use case, DI, global route,
dependency, schema/rules/function, or deploy change. Focused Operations suite:
**14 pass**; `flutter analyze`: no new diagnostics (8 pre-existing infos in the
current dirty tree).

### Added (2026-07-05 — Communications feed bulk selection)

The Communications Center Active and Archived feeds now provide per-card
checkboxes and a **Select all / Clear all** control for the current view.
Selected broadcasts can be confirmation-gated **Archive/Restore** or permanently
**Delete**d; the responsive action row avoids phone-width overflow, disables
itself while writes run, and clears selection when switching feed views.

`BroadcastCubit.setArchivedMany` / `deleteBroadcasts` sequence the existing
single-document repository operations, retaining the same permission and
realtime-stream behavior. Client/Cubit only: no schema, rules, Cloud Function,
route, DI, dependency, or new-file change. `broadcast_card_test.dart`: **3 pass**;
`flutter analyze`: no new diagnostics (8 pre-existing infos in the current dirty
tree).

### Changed (2026-07-05 — Living-border orbit: amber default + transient state flash)

Refined the `LiveStatusBorder` orbit into a premium **"living border"** per the
owner's final spec (motion + colours only; no layout/logic change). The orbit is
now **always a single persistent amber accent** (`#F59E0B`, matching the dashboard
accent) — state colours are **transient**, flashed for one orbit on a state change,
then it returns to amber. Reverses the previous per-state persistent colours
(indigo/emerald/purple) — those are gone; the palette is now amber-family.

- **Persistent accent.** `kLivingBorderAccent` (Amber 400) is the default orbit
  colour in every steady state; `liveActivityColor(task)` returns it for any active
  task, `null` when settled (approved/completed → no orbit).
- **Transient state-change flash.** `liveFlashColor(task)` (all amber-family:
  Amber 600 started · Amber 300 in-review · Amber-red rejected · Orange overdue) is
  eased in over ~320 ms, held for **one full orbit**, then eased back to amber and
  the loop continues in the accent. Driven by the reused `_seq` controller; a
  `flashKey` (`(status, overdue)`) fires the flash on change.
- **Per-state speed + overdue pulse.** `liveOrbitSpeed(task)` scales the lap time
  (pending 1.0 · started 1.2 · review 0.9 · rejected 1.3 · overdue 1.1); overdue
  adds a very subtle glow-**intensity** pulse (0.7–1.0×), never a speed change.
- **Premium, non-constant motion.** New corner-eased warp — a per-size **phase→
  distance LUT** (integrate 1/speed, dipping through each arc) so the head slows
  slightly into each rounded corner and accelerates back out on the straights;
  plus a subtle **corner brightness bump** (+8%) as it rounds a corner. Comet: 2 px,
  80–120 px width-scaled, 30-step tail, round head, inner bloom clipped to the
  interior (**no outer glow**).
- **Perf strategy kept** (owner constraint): pass-through when inactive; no
  per-frame rebuilds; two reused controllers; painter caches its `PathMetric`,
  corner map + warp LUT by size, reuses its `Paint`s, precomputes the tail falloff.
- **Dashboard scope (started).** Wired the living border onto the Admin Dashboard
  **Task Queue card** (`_TaskStatusStrip`): amber orbit while the queue has work
  needing attention, flashes orange as an overdue count changes, pulses when
  overdue, no orbit when clear. Remaining actionable cards (Pending Actions, Active
  Tasks, Waiting Review, Broadcast Sending, Sync chip) are a **follow-up** — the
  Overview / Analytics / KPI stat cards stay static per spec.
- **Tests +11** (`task_card_live_status_test.dart` — persistent amber, transient
  flash colours, per-state speed, overdue pulse, flash key, and orbit
  pass-through / loop / flash→steady / graceful terminal fade-out). `flutter
  analyze`: 7 pre-existing infos, 0 new. Full suite: **445 pass, 2 fail** (the 2 =
  pre-existing desktop splash-framing tests, unrelated).

### Added (2026-07-05 — One-time employee Welcome / onboarding)

A cinematic, once-per-account Welcome screen shown to a new **employee** right
after profile completion (accountability · teamwork · one place for the work).
Follows the established gated-flag pattern. **No rules/functions/deploy change**
(the flag is a non-privileged self-write the `users` freeze-list rule already
permits; the rules comment was tidied only).

- **Added `UserEntity.hasCompletedOnboarding`** (`@Default(true)` — existing
  users are never interrupted). `UserModel` round-trips it (legacy `?? true`;
  excluded from `toMap` like the other provisioning flags). New
  `setOnboardingCompleted` on datasource / repository / repository-impl.
- **Added `AuthCubit.completeOnboarding()`**; `completeProfile()` now also seeds
  `hasCompletedOnboarding:false` so a new employee is shown Welcome exactly once.
- **Refactored** the router's first-login decision into a pure, unit-tested
  `firstLoginLocation(user)` (temp-password → profile completion → employees'
  `/welcome`), replacing three repetitive redirect blocks (behavior-preserving).
- **Added `OnboardingWelcomePage`** (`/welcome`, outside the app shell) — strictly
  monochrome, single-screen, staggered reveal (reuses `FadeSlideTransition` +
  `AppButton`). Adaptive hero: launch Lottie on tablet/desktop, `AnimatedDropLogo`
  on phones (same no-heavy-Lottie-on-phones split as the splash; bounded 480px
  decode). New `RouteNames.welcome`.
- **Tests +13** (`first_login_gate_test` 8, `onboarding_welcome_page_test` 3,
  `user_model_test` +2). `flutter analyze`: 7 pre-existing infos, 0 new. Full
  suite: **429 pass, 2 fail** (the 2 = pre-existing desktop splash-framing tests).

### Added / Fixed (2026-07-05 — Mobile splash premium pass)

Presentation-only; mobile cold-start splash only. No Firebase schema, rules,
functions, route, Cubit, or new dependency. Desktop/tablet splash and the shared
`_OperationsWordmark` / `_PremiumLoadingBar` widgets are untouched.

- **Orchestrated staggered entrance.** The brand group now reveals as one
  choreographed sequence off the single intro controller — the logo blooms
  first, `OPERATIONS` rises in a beat behind it, then the loading bar draws in —
  instead of the wordmark and bar appearing at full opacity from frame 1. Driven
  by a pure `_reveal(v, start, end, curve)` window mapper.
- **Animated hero logo.** The mobile splash now uses `AnimatedDropLogo` (the
  monochrome light-sweep) as the hero, matching the desktop splash + login brand
  panel; it previously used the static `DropLogo`.
- **Breathing atmosphere.** New `_AmbientBackdrop` — a layered, strictly
  monochrome backdrop (faint wide halo for depth + a soft central pool that
  slowly breathes in radius/intensity) so the screen feels alive during the
  bootstrap wait instead of frozen. Replaces the flat single-radial background
  and the per-logo glow box (one light source now, not two).
- **Coverage.** New `test/splash_mobile_test.dart` (animated hero + OPERATIONS
  present · completion hand-off after the ~1.8s intro · animation-gated startup
  error stays visible through the entrance + Retry) — **3 pass**. `flutter
  analyze`: 7 pre-existing infos, 0 new. Full suite: **416 pass, 2 fail**.
- ⚠️ **Pre-existing (not from this change):** `test/splash_centering_test.dart`
  has 2 red **desktop** framing tests — the by-eye `kLogoManualNudgeX = 120` /
  `kLogoManualScale = 1.50` tuning (2026-07-05) doesn't match the combined-bbox
  centering math the test still asserts. Verified red at HEAD with this change
  stashed. Needs the owner to reconcile the tuning with the test (separate,
  desktop-only follow-up).

### Added / Fixed (2026-07-05 — Schedule Final View + PNG export)

Client/presentation-only; no Firebase schema, rules, functions, route-name,
Cubit, or new dependency (`path_provider` reused).

- **Added a `Final view` action** to the manager/admin schedule toolbar. It
  opens the currently loaded branch/week and active shift filter as an opaque
  root-navigator preview, covering the persistent desktop sidebar and all edit
  chrome.
- **Fixed the initial screenshot-mode implementation:** `Save PNG` now captures
  an isolated 1600×900 `RepaintBoundary` at 1.5× and writes a real 2400×1350
  PNG to Downloads; the previous button only hid controls and saved nothing.
- Added the macOS sandbox `files.downloads.read-write` entitlement in both
  debug and release; without it the automatic Downloads write was denied.
- **Added a persistent Back action** (plus Escape) in a responsive toolbar that
  is structurally outside the capture boundary, so navigation controls and the
  desktop sidebar never enter the exported image.
- Added a distinct role-aware **Dashboard** exit using
  `RouteNames.homeForRole`, while Back continues to return to the editor.
- **Redesigned the export canvas** to eliminate the oversized dead area:
  larger roster rows, compact identity/week header, four useful roster facts,
  framed grid + legend, and a restrained footer. `ScheduleGrid` now exposes
  optional presentation sizing while preserving editor defaults exactly.
- Added/updated `schedule_final_view_test.dart`; focused schedule tests:
  **15 pass**; full suite: **415 pass**. `flutter analyze`: 7 pre-existing
  infos, 0 new.

### Fixed / Refactored (2026-07-05 — intro polish, card-grid, undo bugfixes)

Client-only; no Firebase schema, rules, functions, or deploy change.

- **Fixed** the cold-start intro to always play over a fixed **5s**, instead of
  whatever length the `assets/0704.json` composition happens to encode
  (`SplashPage._introDuration` now overrides the Lottie controller's duration).
- **Added** a premium monochrome indeterminate **loading bar** (168×3, a white
  band sweeping across a dim track) directly under the splash logo, visible for
  the whole intro (previously a bare spinner shown only after the animation
  finished, if bootstrap was still pending), added an **'OPERATIONS' wordmark**
  under the logo so the splash is the full brand lockup, and **stripped the
  splash layout to exactly `Scaffold → Center → Column(min) → [logo,
  'OPERATIONS', bar]`** — removed the old `Stack`/`Align(bottomCenter)`/
  `SafeArea` (the logo was `Center`-ed while the indicator was pinned to the
  bottom edge, which read as off-centre).
- **Fixed the "still slightly off-centre" splash logo by measuring the asset,
  not the layout:** decoded the actual frames of `assets/0704.json` and found
  the DROP artwork's bright-pixel bounding-box centre sits **(+4, +21)px**
  (settled-tail mean) below/right of the 720×405 frame's geometric centre (the
  drop-arrow tail pads the bottom of every frame). Added
  `kLogoVisualCenterOffset = Offset(4, 21)` applied as an inverse, scale-aware
  `Transform.translate` (paint-only) so the ARTWORK — not the padded frame —
  lands on the window centre. New `test/splash_visual_centering_test.dart`
  re-measures the real asset pixels on every run and fails if the constant
  drifts (swap the Lottie → test forces a re-measure); it also documents the
  intro's camera move (mid-flight artwork swings ±≈18px by design — that
  motion is the cinematic, not a layout bug). Also verified with TextPainter
  that this engine appends letter-spacing after the last glyph (Δ == 24 for 2
  glyphs @ls:12), so the OPERATIONS leading-pad compensation is correct, and
  locked it with a glyph-centring widget test.
- **Superseded the horizontal bbox compensation with the owner's manual visual
  correction:** desktop/tablet keeps `Offset(120, 0)` with a centre-anchored
  `1.50×` scale. The adjustment is no longer applied to phones.
- **Replaced mobile Lottie with a local premium static intro:** phone widths
  below 600px return before `_LaunchAssetLottie` is constructed, so the ~12MB
  JSON and 102 embedded WebPs are never parsed/decoded there. Mobile now uses a
  responsive 108–136px `DropLogo`, subtle radial light, short 1.8s fade/settle,
  compact OPERATIONS treatment, and a 210px loading bar inside `SafeArea`.
  Desktop/tablet Lottie and bootstrap behavior remain unchanged.
- **Framed the whole lockup as one unit at the optical centre** (owner: "the
  group sits too low — centre the combined bbox, move it up 80–100px"): the
  Lottie frame bakes ~59px of dead space above the artwork
  (`kLogoArtworkTop = 59`, settled-tail mean, pixel-locked), and dead-centre
  reads low optically. A balancer `SizedBox(height: 2·lift)` at the column's
  end (pure layout, no Transform) now places the **combined visible bbox
  (artwork top → bar bottom) exactly `kSplashOpticalLift` (50px) above the
  window centre**. Asserted at both
  1440×900 and 1024×720.
- **OPERATIONS luxury pass:** metallic glyph gradient (white → silver,
  `TextStyle.foreground` shader), triple white glow (bloom 30 / glow 12 /
  core 4), soft black drop shadow, brighter ~4.4s light sweep (alpha 140),
  fontSize 15 — strictly monochrome (white/silver/grey only).
- **Premium splash treatments (2026-07-05 second pass):** soft radial light
  pool behind the logo; 'OPERATIONS' upgraded to tracking-12 pure-white caps
  with dual white outer glow, a whisper of drop shadow, a subtle ~4.4s passing
  light sweep, and a leading pad equal to one tracking unit (Flutter appends
  letter-spacing after the last glyph, which otherwise drags wide-tracked text
  visually left of centre); loading bar upgraded to `_PremiumLoadingBar`
  (240×3.5, rounded, faint white halo `BoxShadow`, easing sweep band). Added
  The temporary debug centre crosshair was removed after visual tuning.
  The debug-only `assert` still prints `MediaQuery` size/centre/padding and
  a `test/splash_centering_test.dart` proving the logo + column centre equal
  the window centre (padding is `EdgeInsets.zero`, so the macOS title bar adds
  no offset).
- **Changed** `AppSidebar`'s brand header from the static `DropLogo` to the
  shimmering `AnimatedDropLogo` (owner-requested 2026-07-05) — **reversed on
  2026-07-07** after the persistent desktop animation was root-caused as an idle
  freeze/CPU issue; Splash/Login keep their animated treatment.
- **Fixed** mismatched card heights on the admin dashboard's Overview grid
  (e.g. the "Managers" metric card sitting visibly shorter than its row
  siblings): `DashboardMetricCard` now reserves the trend line's height even
  when a card has none, via `Visibility(maintainSize: true)` (not `Opacity`,
  which cost an extra compositing layer and left a stray blank node in the
  accessibility tree).
- **Refactored** `ResponsiveCardGrid` from a `Wrap`-based layout (each card's
  own natural height) to a row-chunked layout where each row is wrapped in
  `IntrinsicHeight` + `CrossAxisAlignment.stretch`, so cards sharing a row
  always match the tallest sibling — fixes the same "uneven cards" look on the
  Tasks page grids (`my_tasks_screen.dart`, `branch_task_list_screen.dart`,
  `pending_review_screen.dart`), which all wrap `ResponsiveCardGrid` around
  variable-height task cards.
- **Fixed** the schedule undo bar occasionally staying on screen indefinitely:
  `SnackBar`'s built-in `duration` pauses while the bar is hovered and can be
  orphaned by a rebuild. `manager_schedule_view.dart` now drives the 5s
  dismiss with an explicit `Timer` that closes the specific
  `ScaffoldFeatureController` returned by `showSnackBar` (never the ambient
  `hideCurrentSnackBar()`, which could otherwise kill an unrelated later
  snackbar if the user swiped the undo bar away early).
- Reviewed via `/code-review`; verification: `flutter analyze` 7 pre-existing
  infos, 0 new; **412 tests pass** (`test/responsive_card_grid_test.dart`
  updated for the row-based layout; `test/brand_chrome_test.dart` unchanged
  and green — `AnimatedDropLogo` renders a real `DropLogo` internally).

### Added / Refactored (2026-07-04 — premium animated cold-start intro)

Client/startup-only; no Firebase schema, rules, functions, or deploy change.

- **Added** the supplied `assets/0704.json` as the full-screen black DROP intro
  via `lottie` (registered in `pubspec.yaml`). Playback uses the composition's
  real duration and signals completion from its controller—no arbitrary splash
  delay.
- **Refactored cold start** around `LaunchApp` in `main.dart`: Flutter paints the
  first black frame, then Firebase initialization, Firestore persistence, DI,
  auth restoration/user-doc fetch, and the existing essential home preload run
  while Lottie plays. `MaterialApp.router` mounts only after **both** animation
  and bootstrap complete; `createRouter(initialLocation:)` enters the resolved
  Login / first-login gate / role home directly, so the intro never double-plays.
- **Preserved the current auth contract:** no Welcome/registration/pending-
  approval flow; inactive accounts are blocked, and `mustChangePassword` →
  `isProfileCompleted` → role home remains authoritative.
- **Hardened failure paths:** malformed/missing Lottie falls back to `DropLogo`
  without deadlocking; bootstrap failure holds the final frame and offers Retry.
- **Optimized the raster-heavy export:** the current ~1.1MB, 720×405, 30fps,
  155-frame JSON embeds 102 full-frame WebPs (~113MiB decoded at source size).
  Parsing runs off the UI isolate and embedded images decode at a bounded 480px
  width (~51MiB estimated); no extra raster render cache is used.
- **Removed native white flash:** Android launch/normal themes and both Android
  launch drawables are black; iOS LaunchScreen is black with no stale launch
  image. Analysis: 7 pre-existing infos, 0 new; **406 tests pass**; native launch
  XML validates.

### Added (2026-07-04 — Case Management: inbox unread indicators)

Client-only; no new dependency (reuses `path_provider`), no schema/rules/
functions/deploy change.

- **Added** `CaseSeenStore` (`core/services/case_seen_store.dart`): persists
  per-user, per-case "last opened" timestamps to a JSON file in the app-support
  dir (uid-namespaced; in-memory fallback on web/sandbox). Pure `caseIsUnread`
  decision extracted.
- **Added** an `unreadIds` set to `CaseListState.loaded` (freezed): `CaseListCubit`
  computes it from the store and marks a case seen on open (`select` desktop /
  `markSeen` mobile); the desktop-open case stays read as new replies arrive.
- **Added** a monochrome unread treatment to `CaseListTile` — an 8px dot gutter,
  bold subject, brighter preview + timestamp. Inbox ordering unchanged.
- Tests: `test/case_seen_store_test.dart` (+8), `test/case_list_tile_test.dart`
  (+2). Analysis: 7 pre-existing infos, 0 new · **406 tests pass** (+10).

### Fixed / Added (2026-07-04 — Case Management: premium conversation pass)

Presentation/cubit only; no schema/rules/functions/deploy change, no new deps.

- **Fixed** a message-loss defect in `CaseComposer`: it cleared the input before
  the async send resolved, so a failed send discarded the user's text. `onSend`
  is now `Future<bool>` (`CaseConversationCubit.sendMessage` returns success); the
  composer clears **only on success** and keeps text + attachments on failure.
- **Added** desktop chat ergonomics: Enter sends / Shift+Enter newline on desktop
  (mobile unchanged); focus retained after send.
- **Added** `case_thread.dart` (`caseThread`): synthesizes the `opening` message
  from the case doc when the server-written one (`onCaseCreated`, not yet
  deployed) is absent, and suppresses it once the real one exists — so a fresh
  case never opens with an empty thread.
- **Added** smart auto-scroll to the conversation: new replies only auto-scroll
  when the reader is at the bottom (or it's their own message); otherwise a
  floating "New messages" pill jumps to the latest.
- Tests: `test/case_thread_test.dart` (+5), `test/case_composer_test.dart` (+4).
  Analysis: 7 pre-existing infos, 0 new · **396 tests pass** (+9).

### Added / Refactored (2026-07-04 — Admin Task Management: Active/Done segmented pages)

Presentation-only; no schema/route/cubit/repo/rules/deploy change.

- **Added a shared `SegmentedTabBar`** (`core/widgets/segmented_tab_bar.dart`): an
  Apple-style monochrome segmented control (dark track, white sliding selector,
  no ripple) that implements `PreferredSizeWidget` for the `AdaptiveScaffold.bottom`
  slot and drives a `TabController`.
- **Split `AdminTaskOverviewScreen` into Active / Done pages** behind the pill +
  swipe (`_TaskLens`). The **Active** lens keeps the attention-first order and the
  Active/Pending review/Overdue framing; the **Done** lens re-sorts branches by
  most-completed (approved → completion rate) and re-frames cards + the company
  summary to Done · In review · Open (with an "N of M done / All complete"
  caption). Same `_BranchMetrics`, re-sorted via `_sortForLens` and re-framed —
  no data-layer change.
- **Refactored** the employee `my_tasks_screen` to reuse `SegmentedTabBar`
  (deleted its private `_TabBar`; identical look).
- Added `test/segmented_tab_bar_test.dart`. Analysis: 7 pre-existing infos, 0 new
  · **387 tests pass** (+3).

### Added / Fixed (2026-07-04 — Admin dashboard Sync control + rail label fix)

Presentation-only follow-up on the risk-first pass; no schema/route/cubit/repo/
rules/deploy change.

- **Added a header Sync control** (`_SyncButton` in `admin_dashboard_screen.dart`).
  Desktop shows a labelled pill beside the ⌘K hint; mobile shows an icon-only tap
  target next to the greeting. Tapping force-refreshes the three live sources
  (statistics · task stream · shift swaps); the icon spins while a refresh is in
  flight (min ~650 ms so a cached answer still feels responsive) and otherwise
  reads **“Synced just now / 3m ago / 2h ago / 1d ago”**, ticking via a local 30 s
  timer. Pull-to-refresh is unchanged and now shares the same await path.
- **`_load` now awaits** all three cubit futures under a single
  `_syncing`/`_lastSynced` pair, so both the button spinner and the pull-to-refresh
  reflect real completion instead of firing and forgetting.
- **Fixed the truncated Manage shortcuts:** in the 330px desktop rail the 2-up grid
  broke single words mid-word (“Employee\ns”). Manage now renders **1-up** in the
  rail (wide `maxItemWidth` when compact); mobile was already single-column.
- Added `sync_status_label_test.dart` (pure `syncLabel` clock cases). Analysis:
  7 pre-existing infos, 0 new · **384 tests pass** (+5).

### Changed (2026-07-04 — Admin dashboard risk-first design review)

Implemented the real-UI dashboard critique as a presentation-only pass; no
schema, route, cubit, repository, DI, rules, or deployment change.

- **Flipped the hierarchy:** `branchesWithoutManagers` now drives a highlighted
  top banner — “N branches need a manager” → **Assign now** → `/admin/managers`.
  The oversized all-clear hero/progress/CTA was replaced with a compact live
  task-status strip.
- **Reduced empty-state noise:** Pending Actions stays discoverable but collapses
  to a quiet **Nothing queued** row when empty.
- **Eliminated truncated CTAs:** the 330px rail is a stable 2-up grid (180px
  target instead of 150px), “Create Account” is **New Account**, and
  `ActionCard` labels/subtitles wrap instead of ever using ellipsis.
- **Separated action priority:** added `ActionCard.secondary` (flat horizontal)
  for Manage/navigation shortcuts; primary Quick actions remain elevated and
  vertical.
- **Rebalanced Overview:** fixed 2×2 KPI grid; Managers now uses a distinct admin
  badge icon; all four metrics retain the same tappable chevron affordance.
- **Accessibility:** dashboard supporting text and chevrons moved from
  `textTertiary` to `textSecondary` for readable contrast on near-black.
- Added `action_card_test.dart` (narrow primary + secondary no-truncation cases)
  and updated the Pending Actions empty-state test. Full analysis: 7 pre-existing
  infos, 0 new; focused widget tests: **5 pass**.

### Changed (2026-07-04 — Case Management System: Reports reframed as private conversations)

Rebuilt the Reports feature from scratch as a **Case Management System** — a
**Case** is a temporary, private conversation between an employee and a
manager/admin about a specific issue, kept open until resolution.

- **Renamed** `lib/features/reports/` → `lib/features/cases/`, collection
  `reports` → `cases`, and all `report*` enums/entities/cubits/routes/functions/
  rules → `case*`. Routes `/cases`, `/cases/create`, `/case/:caseId`.
- **Added** a **real chat conversation** on a `cases/{id}/messages` subcollection
  (streamed in realtime for every role) — `CaseMessage` (opening | message |
  system) rendered as bubbles + centered system chips + date separators. A reply
  is a single message `add`.
- **Fixed** the reply-sending bug **structurally**: the old design rewrote the
  whole `activityLog` array from a stale client snapshot (lost updates) and gave
  employees no realtime stream. The subcollection + single-`add` model removes
  the class of bug; employees now see replies live.
- **Added** a **desktop split-pane** workspace (inbox pane │ conversation) and
  removed the old centered-720 detail layout. Mobile keeps list → push.
- **Moved** the status control into the **top header**; new lifecycle
  **Open → In Discussion → Waiting Response → Closed**; **closed cases are
  read-only** (composer disabled + Firestore rule denies message-create on a
  closed case). Recipients can Reopen.
- **Replaced** the 4-level severity with a single **`urgent`** flag; **added** a
  **Personal** category (defaults to Admin · Confidential). Inbox orders active
  cases first (urgent-first, latest activity) with **Closed** in a collapsed
  archive.
- **Rewrote** the Cloud Functions as three single-responsibility triggers —
  `onCaseCreated` (opening message + notify), `onCaseUpdated` (status system
  message + notify), `onCaseMessageCreated` (bump `lastMessage*` + notify the
  other party). Notification types → `caseOpened`/`caseUpdated`/`caseClosed`/
  `caseReplied`; route `case_details`; inbox category **Cases**.
- **Migration:** none — Reports was never deployed (rules/functions/indexes deploy
  was still pending), so this is a clean rename/restructure. `flutter analyze`
  clean (0 new) · **377 tests pass** (5 new case suites; report suites removed) ·
  `node --check` OK. Deploy: `firestore:rules` · `storage` · `firestore:indexes` ·
  `functions:onCaseCreated,onCaseUpdated,onCaseMessageCreated,onNotificationCreated`.

### Fixed (2026-07-04 — employee Reports "Failed to load your reports")

Root-caused the employee mobile Reports failure (admin desktop worked). The
`collectionGroup('reporter').where('createdByUserId'==uid)` "My Reports" query
was denied because its Firestore rule was **nested** under
`match /reports/{reportId}` — a path-scoped rule does NOT authorize a
collection-group query (documented Firestore behavior), so the query returned
**`permission-denied`** even with the index present. **Fix:** promoted the rule
to a collection-group rule with the recursive wildcard —
`match /{path=**}/reporter/{docId}` (top-level sibling of the reports match;
identical read/create/deny conditions). Also surfaced the exact Firestore error:
`report_remote_datasource.getMyReports` was swallowing `e.code` — it now logs
`[REPORTS]` query/code/message/stack and keeps the code in the thrown message.
⚠️ **Redeploy `firebase deploy --only firestore:rules`.** (The admin list uses a
plain `reports` orderBy → auto-indexed → unaffected; only employees hit the
collection-group query.)

### Changed (2026-07-04 — Reports simplified: escalation messages, not tasks)

Owner feedback: Reports felt too task-like. Stripped the Task-borrowed machinery
down to a lightweight escalation-message system with a **chat/support** feel:

- **Anonymous privacy removed** — privacy is now just **normal / confidential**.
- **Categories reduced 12 → 5**: **Sales · Inventory · Staff · Security ·
  Operations** (Security → admin by default; the rest → manager).
- **Lifecycle reduced** to **New → Under Review → Waiting Reply → Resolved**
  (dropped acknowledged / inProgress / closed / rejected).
- **Ownership removed** — no `assignedTo` / `resolvedBy` / "Assign to me" /
  "Owned by". Recipients just move the status.
- **Detail UI is now a premium conversation** — message-first opening card + a
  chat **reply thread** (`report_thread.dart`, left/right bubbles + quiet status
  markers) + a compact recipient status bar + a pinned reply composer. The
  task-style `report_timeline.dart` was deleted.
- **Notification types trimmed** to `reportSubmitted` / `reportUpdated` /
  `reportResolved` / `reportCommented`; `onReportUpdated` maps the new statuses
  and no longer handles assignment.
- Rules: dropped `assignedTo`/`resolvedBy` from the reporter-update freeze.
- `flutter analyze` clean (0 new) · **368 tests pass** · `node --check` OK ·
  freezed regenerated. Filing rules unchanged (admin can't file; manager →
  admin-only; employee → manager/admin/both).

### Added (2026-07-03 — Reports Center / Escalation System)

A first-class, branch-scoped internal **Reports Center** (Reports / Escalation
System) — any employee files a categorized, severity-rated report, routes it to
their manager and/or admin (optionally **confidential / anonymous**), and the
recipient acknowledges → works → resolves it, with a full audit **timeline +
discussion thread** and **attachments**. Replaces WhatsApp/verbal complaints.
Built as a full Clean-Architecture slice modeled on the Task feature.

- **Enums** (`core/enums/`): `ReportCategory` (12, + `label`/`hint`/smart
  `defaultRecipient`), `ReportRecipient` (manager/admin/both, `includesManager`
  → `visibleToManager`), `ReportPrivacy` (normal/confidential/anonymous),
  `ReportSeverity` (+ SLA window), `ReportStatus` (open→acknowledged→inProgress→
  resolved→closed, +rejected, `canTransitionTo`).
- **Domain** (`features/reports/domain/`): `ReportEntity` (freezed; reuses task
  `ActivityEntry` + `TaskAttachment`; a comment = an activity entry with
  `status:'comment'`), `ReportIdentity` (private reporter value object),
  `report_urgency.dart` (pure client-side SLA/urgency + ranking — **no cron**),
  `ReportRepository` + `CreateReport`/`UpdateReport`/`UploadReportAttachment`.
- **Data**: `ReportModel` (+ reporter-subdoc (de)serialization),
  `ReportRemoteDataSource` (batched report+identity create, collectionGroup
  `reporter` "My Reports", Storage `reports/{id}/attachments/`),
  `ReportRepositoryImpl`.
- **Presentation**: app-wide `ReportCubit`/`ReportState`; `ReportsCenterScreen`
  (role-scoped list + filters + search), `CreateReportScreen` (≤30s flow),
  `ReportDetailsScreen` (record + action panel + reveal + discussion + timeline);
  `report_card`/`report_timeline`/`report_format` widgets. Strictly monochrome.
- **Privacy split (rule-enforced):** the report doc carries **no creator uid**;
  the reporter identity lives in the private subdoc
  `reports/{id}/reporter/identity` (owner + admin only) — mirrors the
  compensation subdoc. `reporterDisplayName` rides the doc only when privacy is
  `normal`; managers see "Confidential Sender" / "Anonymous". Reporter-authored
  timeline entries are de-identified on confidential/anonymous reports.
- **Notifications (server-side):** 6 `report*` `NotificationType`s + a Reports
  inbox category; **`onReportCreated` / `onReportUpdated`** Cloud Functions fan
  out per-recipient notification docs via the Admin SDK (a manager can't read a
  confidential reporter to notify them client-side); `onNotificationCreated`
  now carries `reportId` in the push data; tap → `/report/:id`.
- **Rules / storage / indexes:** `reports/{id}` + `reporter/{docId}` Firestore
  rules (`isReportReporter` get-helper; `visibleToManager` manager gate);
  `reports/**` create-only Storage; collection-group `reporter` field index.
- **Wiring / nav:** DI + provider; routes `/reports`, `/reports/create`,
  `/report/:reportId`; Reports destination in the desktop sidebar (all roles) +
  a mobile app-bar action.
- **Role-based filing (2026-07-04 owner feedback):** admins **can't file**
  (receive/manage only — FAB hidden + create screen bounces them); a **manager
  files → routed to admin only** (escalation up; recipient locked with an
  "Escalated to the Admin" note); an **employee files → manager / admin / both**.
- **Tests:** `report_urgency_test`, `report_routing_test`, `report_model_test`
  (+23). `flutter analyze` clean (7 pre-existing infos, 0 new); **366 tests
  pass**; `node --check` OK; freezed regenerated.
- ⚠️ **Deploy:** `firebase deploy --only firestore:rules`, `--only storage`,
  `--only firestore:indexes`, and
  `--only functions:onReportCreated,functions:onReportUpdated,functions:onNotificationCreated`.
- **Deferred** (owner-selected out; model leaves room): manager→admin
  re-escalation action, admin/manager dashboard count widgets, SLA push
  reminders.

### Added (2026-07-03 — note categories + feed telemetry; Smart Queue opt-in)

- **Smart Queue is opt-in again** — default sort reverted to **Due date
  (grouped)**; Smart Queue stays an explicit sort mode. Validate the heuristic
  before promoting it.
- **Note categories** — new `NoteCategory` (info / warning / issue), stored as
  the note's activity kind (`note` / `noteWarning` / `noteIssue`; no schema
  change, `info` = back-compat `note`). `TaskCubit.addNote(category:)`;
  `activity_format` renders each distinctly; the note sheet gained a category
  selector.
- **Animated attention counters** — the strip always renders the three pills
  (muted at zero) so each `AnimatedCount` tweens smoothly through changes,
  including to/from zero (no all-clear layout swap).
- **Lightweight feed telemetry** — new `UsageTracker` (`core/services`): a single
  `usageStats/feed` counters doc (`FieldValue.increment`), **debounced to ~one
  write/20s**, best-effort, test-safe (no-op until `init`, wired in `main.dart`).
  Tracks `preset_{name}` · `sort_{name}` · `expansion_open` · `quick_approve` ·
  `note_create`. New `usageStats/{doc}` rule (signed-in write, admin read).
- `flutter analyze` clean (7 pre-existing infos) · **343 tests pass** (+2).
  ⚠️ **Deploy for telemetry:** `firebase deploy --only firestore:rules`.

### Added (2026-07-03 — R1 refinements + Smart Queue, Home Dashboard redesign)

- **Attention strip: Blocked → Unassigned** (owner ruling — "blocked" = can't
  progress for lack of an owner). Strip is now Overdue · Pending review ·
  Unassigned; the Unassigned pill filters to the `unassigned` preset.
- **Proof-safe approve:** a task whose submission carries proof shows a
  lightweight confirm sheet (evidence thumbnails + Approve/Cancel) before
  approving; proofless tasks stay one-tap (`TaskFeedActions`).
- **Sticky action footer:** actions extracted into a reusable `TaskFeedActions`;
  the mobile bottom sheet pins it as a footer (`TaskFeedExpansion(showActions:
  false)` scroll body + pinned footer) so quick actions stay visible.
- **Quick manager notes:** new `Note` action → note sheet →
  **`TaskCubit.addNote`** appends a `note` activity entry (no status change; new
  `note` kind in `activity_format`). One additive cubit method, no new cubit.
- **Smart Queue (P3-lite):** new `FeedSort.smart` (now the **default**) — a
  simple 5-tier `smartRank` (overdue+high · pending review · overdue · due today
  · normal). Smart renders a flat ranked list (grouping hidden); other sorts
  restore grouping. Deliberately not the full urgency engine — validate first.
- `flutter analyze` clean (7 pre-existing infos) · **341 tests pass** (+5).

### Added (2026-07-03 — inline expandable feed row + Attention strip, redesign R1)

Owner priority after P2 (before P3): remove the friction of opening
`TaskDetailsScreen` for routine triage. Presentation-only.

- **Inline expandable task row (R1)** — `task_feed_expansion.dart`, ONE shared
  triage surface (description · branch/shift/due/assignee facts · checklist
  preview + progress · attachment/proof thumbnails · compact status timeline ·
  quick actions Approve/Reject/Reassign/Open-full-details). Actions read the
  app-wide `TaskCubit` lazily on tap (no new cubit).
  - **Desktop** = inline accordion (`_expandedId`, one open at a time;
    `AnimatedSize` height + `TweenAnimationBuilder` fade; row `selected`
    highlight + chevron flip; scroll preserved).
  - **Mobile** = the same surface in a `DraggableScrollableSheet` bottom sheet.
    `context.isDesktop` selects the presentation.
- **Attention Needed strip** (`_AttentionStrip`) above the feed — Overdue ·
  Pending review · Blocked counts over the scope's active set (independent of
  the user's filter); each pill filters the feed; "all clear" state at zero.
  **"Blocked" = `rejected`/rework** (owner to confirm vs. unassigned).
- `flutter analyze` clean (7 pre-existing infos) · **336 tests pass** (+6
  `task_feed_expansion_test.dart`). Next: P3 urgency engine.

### Added (2026-07-03 — homepage global task feed + badge dedupe, redesign P1/P2)

Owner re-prioritized to homepage usability first. Presentation-only (no deploy).

- **Badge dedupe (P1):** `taskBadgeFor` dropped its `Approved`/`Rejected`
  branches — the card's status pill already renders those, so the word stacked
  twice ("Approved" over "Approved"). The lifecycle badge now carries only
  `REWORK #n` / `NEW`.
- **Global active-task feed (P2)** on the admin + manager homepages — reach any
  task in ≤2 taps, no Branch→Employee→Task drill:
  - `features/task/domain/task_feed.dart` — pure engine: `TaskFeedFilter`
    (branch/assignee/shift/priority/status/search/preset/grouping/sort),
    `applyFeed` (active-window base + AND filters + search), `groupFeed`
    (Due-time/Branch/Employee/Priority), 4 pinned presets. O(n), no index.
  - `task_feed_row.dart` — dense scannable row (status dot · title · branch ·
    High-only flag · assignee · overdue-aware due · 2px checklist track).
  - `task_feed_section.dart` — composable homepage feed over the app-wide
    `TaskCubit` (no new cubit/query): preset chips · search · group/sort menus ·
    admin branch scope · collapsible grouped rows → tap to `TaskDetailsScreen`.
  - Wired into `AdminDashboardScreen` (main column, **replacing** the redundant
    `_ActivityFeed`, now deleted) and `ManagerHomeScreen` (`branchLocked`; also
    now loads `TaskCubit`).
- Deferred: urgency "Smart" sort (P3) and the inline row-expansion triage
  surface (P2 taps straight to details for now).
- `flutter analyze` clean (7 pre-existing infos) · **330 tests pass** (+28:
  `task_feed_test` 23, `task_feed_row_test` 5).

### Added (2026-07-03 — task retention lifecycle, Home Dashboard redesign P3)

Design proposal + first implemented slice of the home-dashboard redesign
([HOME_DASHBOARD_REDESIGN.md](HOME_DASHBOARD_REDESIGN.md)). Owner picked the
**task lifecycle (P3)** to build first — completed tasks no longer accumulate
in active views forever.

- **`archivedAt` on tasks (server-managed soft archive).** New
  `TaskEntity.archivedAt` + `isArchived`; `TaskModel` round-trips it (written
  in `toMap` so an admin reopen clears it, always null on a live task).
  `TaskRepositoryImpl._newestFirst` filters archived out of **every** active
  list/stream — the single clutter gate. `getTask` bypasses it (deep-links to
  archived tasks still resolve) and statistics read Firestore directly, so
  lifetime "completed" counts are unaffected. `TaskCubit.reopenTask` clears
  `archivedAt` (un-archives on admin reopen).
- **`taskHousekeeping` Cloud Function** (`onSchedule` every 24h): archives
  approved tasks older than `archiveAfterDays` (default 30) — stamps
  `archivedAt` + cold-tiers their `tasks/{id}/` Storage evidence to COLDLINE
  (~85% cheaper); **hard-delete is opt-in** (`deleteAfterDays`, default null =
  soft archive forever, per owner). Archive pass pages by `approvedAt` with a
  cursor and skips already-archived docs → no composite index, outage-tolerant,
  no starvation. Config in `config/taskRetention` (defaults when absent).
- **Architecture note:** kept archive **in place** (not a separate collection)
  because statistics count approved tasks straight from `tasks`, and the
  Firestore `isNull` gotcha (missing fields aren't matched) would make a
  server-side filter need a migration. *Server-side* read-bounding of the admin
  all-tasks stream is deferred + costed (not needed at current volume).
- `flutter analyze` clean (7 pre-existing infos) · **302 tests pass** (+6
  `task_archive_test.dart`) · `node --check functions/index.js` OK.
- ⚠️ **Deploy (owner, surgical):** `firebase deploy --only
  functions:taskHousekeeping`. No rules / indexes / storage-rule change.
  Rollback = `firebase functions:delete taskHousekeeping`.

### Security (2026-07-03 — M1/M2/M3 hardening + C1 deployments, all live)

Remaining production-blocker fixes (per-blocker commits, each deployed to
`bazic-d9ad7` and verified):

- **C1a/C1b deployments:** the `tasks` composite index (READY; audit
  correction — the equality-only shift query also ran index-free via merge
  join, so prod was never broken) and `generateShiftTaskInstances` (surgical
  deploy; scheduler ENABLED; forced run clean).
- **M2 — notification forgery closed:** new **`sendNotification` callable**
  is the ONLY client path for notification docs (client-type whitelist ·
  admin-or-same-branch recipients · length caps · sanitized payload ·
  server-stamped `senderUid`); `NotificationRemoteDataSource.create/createMany`
  now call it; `notifications` `create: if false`. The push trigger
  (`onNotificationCreated`) is unchanged.
- **M1 — swap consent forgery closed:** `shift_swaps` update enforces
  per-party status transitions (target: pending→employeeApproved|rejected;
  requester: pending|employeeApproved→cancelled; employee writes locked to
  `status`+`updatedAt`); `approveSwap`'s existing
  status==employeeApproved gate verified.
- **M3 — proof tampering closed:** Storage `tasks/**` is create-only
  (update/delete denied); uploads already use unique push-id paths (no fixed
  `proof.jpg` remains), so evidence is immutable from upload.


### Security (2026-07-03 — C2: compensation moved to a private subdocument)

Production blocker fix (audit C2). Salary data lived on the branch-readable
`users/{uid}` doc — Firestore reads are document-level, so every same-branch
member received coworkers' `salaryAmount`/`salaryType`/`paymentMethod`/
`paymentNumber` in normal app use (the branch query behind schedule/team
surfaces). **Moved to `users/{uid}/private/compensation`:**

- **Rules:** new `users/{uid}/private/{docId}` block — read = owner + admin
  only (managers deliberately excluded); create/update = admin, or the owner
  touching ONLY `paymentNumber` (field-diff enforced); delete denied.
  **Deployed.**
- **Client:** new plain `UserCompensation` value object
  (`admin/domain/entities/user_compensation.dart`, SwapPolicy precedent);
  the 4 fields REMOVED from `UserEntity`/`UserModel` (public user fetch can
  never carry salary data); `UserAdminRepository.updateUserCompensation` now
  writes the subdocument + new `getUserCompensation` (subdoc with legacy
  fallback); `AdminUsersCubit.compensationFor` non-emitting on-demand load;
  admin Details dialog / desktop inspector render compensation via
  FutureBuilder; Edit-Info sheet pre-fetches it; profile `paymentNumber`
  reads overlay from the subdoc and writes go to it (`editMap` no longer
  emits the key).
- **Migration:** `tool/migrate_compensation.js` (privileged REST, gcloud
  identity; dry-run default · pre-write JSON backup (gitignored) ·
  write→verify→delete per user · `--rollback` · final residue scan).
  **Executed against production: 1/1 user migrated, 0 residue, VERIFIED.**
- **Owner ruling applied while here:** the self-service Contact-details +
  Salary-payment-number sections in Edit Profile (and the "Salary sent to"
  profile row) are **manager/employee-only** — hidden for admin, and an
  admin save never writes those fields (the admin manages compensation,
  never receives it in-app).
- Tests: `user_compensation_test` rewritten for the subdocument model (+
  UserModel no-echo guard) and `user_admin_update_details_test` gains a
  routes-to-subdoc test.


### Added (2026-07-02 — Schedule 4.0: overflow · mobile actions · undo · validation)

Stabilize-then-finish pass on the schedule (owner phase plan). Phase 1
verified the mobile blank-My-Week fix (test green) and closed the last
"schedule disappears on navigation" path; Phase 2 completed Schedule 4.0.

- **Stabilization — silent same-scope reload:** `ScheduleCubit.load` no longer
  emits `loading` when the data already on screen is the requested (branch,
  week) — a screen revisit / pull-to-refresh keeps the schedule visible while
  refetching (unchanged data → no emission at all, bloc dedupes). A real
  branch/week change still shows the loader. `_MyWeekTab`'s `orElse` now
  renders the loader instead of a blank `SizedBox` (stale-state guard).
  New `schedule_silent_reload_test.dart`.
- **Crowded cells:** `ShiftCell` shows all chips up to 4 people; beyond that,
  the first 3 + a **tappable "+N more"** pill that opens the shift panel
  (so a "+1 more" hiding exactly one person can never happen). The hover
  "+ assign" affordance hides at chip capacity (no overpaint).
- **Mobile move/switch/remove:** long-pressing a chip on touch now opens a
  premium **action sheet** (`chip_action_sheet.dart`) — Move (mini week map,
  invalid slots disabled *with the reason shown on tap*), Switch (pick a
  coworker's (person, slot) row → **preview both sides of the trade** →
  confirm), Remove. Desktop right-click menu gains "Switch shifts with…"
  opening the same flow at the picker step — one flow, no platform drift.
- **Undo (5s):** `ScheduleCubit` records the exact inverse of every
  move / exchange / remove (`undoWindow` = 5s; single-use; invalidated by any
  newer mutation; the undo never records an undo-of-undo). The view shows a
  monochrome floating snackbar with **UNDO** for the same window.
  New `schedule_undo_test.dart` (6 tests).
- **Constraint validation:** new pure `domain/move_validation.dart` —
  `checkMove` / `checkExchange` return `null` or a user-facing reason:
  double-booking is **blocked** (with the day named), position compatibility
  on an exchange follows the branch's existing `SwapPolicy` (the same rule
  employee swaps obey — manager edits can never contradict it). Emptying a
  shift is a **confirm dialog, not a block** (facts, never quotas — the
  settled ruling). Every grid edit path (drag-move, drag-switch, context
  menu, action sheet) funnels through validated helpers in
  `manager_schedule_view` — blocked edits state their reason, successes
  offer UNDO. New `move_validation_test.dart` (10 tests).
- **Approval integrity (audited):** drag-to-switch does NOT bypass the swap
  approval flow — `weekly_schedules` writes require `canReachBranch`
  (admin/own-branch manager) so employees have no direct roster write path;
  employee swaps still go request → coworker accept → manager approve via
  the `approveSwap` callable (clients are denied `status → managerApproved`
  by rules). Manager/admin direct edits are the sanctioned instant path.

`flutter analyze` clean (7 pre-existing infos); **293 tests pass** (+25).

### Added (2026-07-02 — production audit, beta plan, auto-schedule design)

Three deliverable documents in the repo root (owner phase plan, phases 3–5):

- **[PRODUCTION_AUDIT_2026-07-02.md](PRODUCTION_AUDIT_2026-07-02.md)** — full
  security/performance/reliability/release audit. Critical: **C1** undeployed
  rules/indexes/functions (the single biggest risk — deploy before beta),
  **C2** salary fields readable by any same-branch member (recommend a
  `users/{uid}/private/compensation` subdoc), **C3** iOS push entitlement
  still missing. Five medium + five low findings with fixes. macOS debug +
  web release builds verified green.
- **[BETA_CHECKLIST.md](BETA_CHECKLIST.md)** — pre-flight deploy gate, role
  walkthroughs (onboarding → daily workflow → schedule → oversight →
  notifications), ten realistic scenario drills (S1 sick day … S10 new-hire
  day one), and a lean beta feedback design (`feedback/{id}` collection + one
  in-app sheet + admin triage list; ~half-day build, not yet implemented).
- **[AUTO_SCHEDULE_DESIGN.md](AUTO_SCHEDULE_DESIGN.md)** — Phase 5 design
  (NO implementation): pure-Dart `ScheduleGeneratorService` using greedy
  weighted scoring + repair passes (constraint solver + rule engine evaluated
  and rejected as over-engineering at 14 slots/week); hard constraints reuse
  `MoveValidation`/`SwapValidation` semantics; draft → review-in-grid →
  publish UX reusing the Schedule 4.0 edit tools; `staffingTemplate` as a
  hidden generator input reconciling the no-quotas ruling. Feasibility: HIGH,
  ~4 days phased.

### Fixed (2026-07-02 — admin Pending Actions swap row now opens the queue)

Owner report: clicking "N Swap Requests" on the admin home pushed the
Schedule screen with **no branch selected** — the admin then had to pick the
branch and hunt for the swap chip. The row's whole point is one-tap access.

- `admin_dashboard_screen.dart` `onSwaps` now opens **`showSwapQueueSheet`**
  directly (all-branches, actionable approve/reject — the same sheet the
  schedule strip chip opens). The dashboard already streams
  `ShiftSwapCubit.loadAll()`, so the sheet is live the moment it opens.
  Reviews/Overdue rows keep their existing (correct) deep-links.
- Deliberately did NOT add a swaps entry to the ⌘K palette — palette entries
  are route-based and swaps live in a sheet; wiring a callback kind for one
  entry is machinery the lean ruling rejects. The Pending Actions row is the
  canonical entry point.

`flutter analyze` clean (7 pre-existing infos); **268 tests pass**.

### Added (2026-07-02 — macOS app icon + animated brand logo)

Owner request: brand the macOS app icon (Dock/Finder) with the DROP artwork
and make the in-app logo animated.

- **macOS app icon:** new Big Sur-style icon — Apple-grid squircle (824pt,
  r 185) with a dark monochrome gradient, hairline border, and the white
  DROP wordmark centered — composed from `assets/drop_logo.png` by a Swift
  script (AppKit, high-interpolation tint+composite). Master committed at
  `assets/icon/app_icon_macos.png` (1024²); all 7 sizes regenerated into
  `macos/Runner/Assets.xcassets/AppIcon.appiconset/` via `sips`. The
  `flutter_launcher_icons` pubspec config gained a `macos:` block pointing
  at the master for reproducibility (Android/iOS config untouched).
  **Verified in the built bundle** — `DROP.app/Contents/Resources/
  AppIcon.icns` carries the new artwork (macOS debug build green).
- **`AnimatedDropLogo`** (`core/widgets/animated_drop_logo.dart`): the
  wordmark sits at ~88% white and a soft **diagonal band of light sweeps
  across it** once per ~3.2s cycle (ShaderMask `srcATop`, eased, rests
  between passes — a beam, not a strobe; strictly monochrome). Wired where
  the brand is the hero: the **Splash** lockup (on top of its existing
  entrance fade/scale) and the **Login desktop brand panel**. Quiet chrome
  marks stay static.

`flutter analyze` clean (7 pre-existing infos); **268 tests pass** (+1
AnimatedDropLogo loop test in `brand_chrome_test.dart`).
⚠️ If the Dock still shows the old icon after installing, macOS icon cache
may need a nudge (`killall Dock`).

### Added (2026-07-02 — Schedule 3.1: drag-to-switch + brand polish)

Owner request on the Branch Schedules surface: premium polish, the DROP logo
on the screen, and person-onto-person drag ("drag Ziad onto Richard and they
switch shifts").

- **Drag-to-switch (exchange):** new `ScheduleCubit.exchange` — two people
  trade slots in a single busy cycle, same safety ordering as `move` (both
  assigned to their NEW slots first, then released from the old ones, so a
  failed write never strands anyone off the schedule; self-swap and
  same-slot trades are no-ops). `AssignmentChip` is now itself a
  `DragTarget`: hovering a dragged person over another chip shows a primary
  ring + ⇄ cue; dropping fires the exchange. The chip target sits inside the
  cell target so it wins the hit test — dropping on a **person** = switch,
  dropping on the cell's **empty space** = the existing move. Threaded
  `onSwapChip` through `ShiftCell` → `ScheduleGrid` →
  `manager_schedule_view` (admin + manager both get it). Desktop-only, like
  all chip dragging; the grid hint now names the gesture.
- **Brand on the schedule surface:** quiet `DropLogo` signature at the right
  end of the grid-hint row; the two plain empty states ("Select a branch",
  "No schedule for this week") upgraded to the brand-led `DropEmptyState`
  (faded DROP mark + action), per the §9b empty-state convention.

New `test/schedule_exchange_test.dart` (4 tests: exchange call ordering ·
self-swap no-op · same-slot no-op · a real drag of one chip onto another
fires `onSwapChip` and never the cell move). `flutter analyze` clean (7
pre-existing infos); **267 tests pass** (+4).

### Added (2026-07-02 — DROP logo rollout across the app chrome)

Owner request: use the real DROP logo (`assets/drop_logo.png`) on the homepage
and all important screens. Applied through the three shared chrome widgets so
every screen is covered without per-screen edits, staying monochrome/lean:

- **Role homes (mobile):** `RoleScaffold`'s app bar title is now a brand
  lockup — `DropLogo` (22px, full white) + the dashboard title — on the
  admin, manager, and employee homepages.
- **Desktop (every screen):** the persistent `AppSidebar` brand header now
  renders the real artwork (`DropLogo` 30px) instead of the typographic
  `DropWordmark` (which remains in use by `BrandWatermark`).
- **All migrated mobile screens:** `AdaptiveScaffold` gains
  **`showBrandMark`** (default **on**) — a quiet, non-interactive tertiary
  `DropLogo` (16px) closes every mobile app bar (tasks, schedule,
  notifications, profile, settings, comms, admin screens…). Desktop skips it
  (the sidebar already brands the window).
- Refreshed `DropLogo`'s stale doc comment (still cited the removed
  register/pending-approval pages).

New `test/brand_chrome_test.dart` (4 tests: role-home lockup · sidebar
artwork · mobile mark present · opt-out). `flutter analyze` clean (7
pre-existing infos); **263 tests pass** (+4).

### Fixed (2026-07-02 — mobile blank "My Week" after visiting the Swaps tab)

Owner report: on mobile, Schedule → My Week rendered fine initially, but after
opening the Swaps tab and returning, the week went blank (or only reappeared
after a manual refresh). Reproduced first in a widget test, then fixed.

- **Root cause (rendering, not data):** `TabBarView` disposes the My Week tab
  when the user visits Swaps and recreates it on return. `_MyWeekTabState`'s
  900 ms entrance `AnimationController` starts at 0.0 and was only ever played
  from the `BlocConsumer` **listener** — which fires on state *changes* only.
  On return the `ScheduleCubit` is still `loaded` and emits nothing new, so
  the animation never ran and every section rendered at **opacity 0** (the
  data was there, invisible). A manual refresh "fixed" it because the
  loading → loaded transition finally fired the listener. Fix: on mount, if
  the cubit is already `loaded`, snap the controller to 1.0 (content shows
  instantly, no gratuitous replay); the entrance stagger still plays for real
  load/refresh cycles. The Swaps flow itself was audited clean — it never
  touches `ScheduleState`.
- **Also fixed in the same screen:** `_load()` cached the current user into a
  field **without `setState`**, so `SwapListView` was built with
  `currentUid: ''` until an incidental rebuild — with an empty uid a swap
  card matches neither requester nor target and renders **no
  Accept/Decline/Cancel actions**. The uid is now resolved at build time
  (`context.currentUser`), and the dead field is gone.
- New regression test [`my_schedule_tab_test.dart`](test/my_schedule_tab_test.dart)
  drives the real `MyScheduleScreen` through the tab round-trip and asserts
  the week content is at full opacity after returning.

`flutter analyze` clean (7 pre-existing infos); **259 tests pass** (+1).

### Added (2026-07-02 — Phase 3: crash monitoring + production-grade observability)

Product-hardening pass: complete crash capture + structured logging
infrastructure, built on (and extending) the existing `AppLog` from the
freeze-fix session — one centralized system, no scattered prints.

- **Global crash capture** (new
  [`core/observability/crash_reporter.dart`](lib/core/observability/crash_reporter.dart)):
  four funnels converge on one structured report — `FlutterError.onError`
  (framework errors; debug keeps the red-screen behaviour),
  `PlatformDispatcher.instance.onError` (platform/engine + uncaught async;
  returns true so a handled error can't kill the app), `runZonedGuarded`
  (whole `main` bootstrap runs inside the guarded zone), and
  `Isolate.current.addErrorListener`. Every crash produces the structured
  🔴 CRASH block: timestamp · source · **screen · route · current user ·
  role** (from `CrashContext`, fed passively by the navigator observers +
  the auth listener) · error · **full stacktrace** · **last action** (the
  last 🟡 CALL) · the last **30 log breadcrumbs**.
- **Persistent crash log + export (Part 6):** the report is written to
  `Application Support/last_crash.log` (path_provider, promoted to a direct
  dependency) — **even in release**; the write path is re-entrancy-guarded
  and exception-swallowing so the crash handler can never crash. On the next
  launch a MaterialBanner offers **Copy report** (clipboard) / **Dismiss**;
  both clear the file.
- **`AppLog` extended to the full category set:** 🟡 CALL · 🟢 SUCCESS ·
  🔵 ROUTE · **🟣 STATE** (new; `AppBlocObserver` transitions moved onto it,
  formatted `loading → loaded`) · **🟠 WARNING** (new) · 🔴 ERROR. Every
  method takes optional **`meta`** (rendered `{k=v …}`); every line =
  timestamp + category + module + message. **Breadcrumb ring buffer**
  (last 30 lines, all categories) records ALWAYS — including release, where
  console output stays off — so crash reports carry the lead-up.
- **Async performance timing:** `AppLog.time` now logs
  `⏱ label finished in Nms` and **escalates >1000 ms to 🟠 WARNING**.
  Instrumented hot spots: Firebase boot, session restore, FCM
  permission/token, **schedule load** (`getSchedule` + `getUsersByBranch`),
  **statistics load** (per-role), **notifications** (time-to-first-snapshot
  on the stream).
- Navigation logging (root + shell observers, exact paths, redirect
  decisions) and cubit lifecycle logging were already live from the
  freeze-fix session and are unchanged apart from the 🟣 recategorisation.

`flutter analyze` clean (7 pre-existing infos); **258 tests pass** (+7
`observability_test.dart`); macOS debug build green. New dependency:
`path_provider ^2.1.4` (already in the lock transitively).

### Fixed (2026-07-02 — macOS navigation freeze + APNS warning; global debug logging)

Root-cause investigation of the reported macOS freeze ("clicking Tasks /
Notifications sometimes freezes the UI") — full report delivered before any
code change.

- **CRITICAL — navigation freeze fixed.** Phase 2's `AppShell` wrapped the
  `ShellRoute` child in an `AnimatedSwitcher` keyed by the active sidebar
  destination. That child is **go_router's shell `Navigator` — one widget
  holding a `GlobalKey`** — so the cross-fade mounted the same GlobalKey twice
  mid-transition → "Duplicate GlobalKey detected" → corrupted element tree →
  the shell navigator stopped responding to clicks. Desktop-only (mobile
  passes through) and only on cross-destination navigation — matching the
  symptoms exactly. **Fix: the wrapper is removed** (with a guard comment);
  the intended desktop fade already exists at the page level (every shell
  route's `CustomTransitionPage` fades on ≥1024pt), so nothing is visually
  lost. Audited the rest of the navigation flow: redirect is loop-free and
  fully synchronous, guards consistent, splash awaits `mounted`-guarded,
  palette/inspector overlays live on the root navigator — no other defects.
- **APNS warning fixed at the source.** `registerToken` fired
  `FirebaseMessaging.getToken()` the instant sign-in completed, on a platform
  (macOS) whose Runner has **no `aps-environment` entitlement** — the APNS
  token can never arrive, so every sign-in logged "APNS token has not been
  set…". New `supportsPushNotifications` /
  `requiresApnsToken` gates in `platform_capabilities.dart`:
  `NotificationService.init`/`registerToken` now skip cleanly on non-push
  platforms (no permission prompt on desktop), and on Apple platforms
  `getAPNSToken()` is checked (and aborted on null) **before** `getToken()`
  — fixing the too-early call on iOS as well; `onTokenRefresh` re-registers
  when a token appears later. Not the freeze (the call was fire-and-forget),
  but it was real noise + a dead-end prompt.
- **Global debug logging system** (`core/utils/app_logger.dart`, debug builds
  only): **`AppLog`** — yellow `call()` function-entry logs, green
  `success()`, red `error()`, cyan `route()`, and `time()` (async operation
  timing: yellow start → green with elapsed ms → red + rethrow).
  **`AppBlocObserver`** (wired in `main`) logs every cubit's
  create/state-change/error/close. **`LoggingNavigatorObserver`** on BOTH the
  root router and the shell navigator logs push/pop/replace with real paths
  (transition pages now carry `name: state.uri`); the router redirect logs
  every redirect decision (`redirect /a → /b`). Instrumented: Firebase boot,
  session restore, FCM permission/token flow.

`flutter analyze` clean (7 pre-existing infos); **251 tests pass**; macOS debug
build green. ⚠️ Needs an on-Mac click-through of Tasks/Notifications to confirm
the freeze is gone (this session verified the mechanism, not the running GUI).

### Changed (2026-07-02 — Phase 2 premium desktop UX: Schedule 3.0 · executive dashboard · person inspector · ⌘K)

Owner-approved visual/UX overhaul (mock-first: three approved wireframes;
scope decisions locked as move-only drag & drop, full ⌘K palette, fact-chips
without percentages). **Presentation layer only** — every interaction lands on
writes the cubits already had; no schema/rules/repository change, no deploy.

- **Schedule 3.0 (the priority screen).** Every assigned person is now an
  individual **`AssignmentChip`** (avatar + name) — a click target, a desktop
  **drag handle** (`Draggable`/`DragTarget`; drop on another cell = move via
  new single-busy-cycle `ScheduleCubit.move`, assign-before-remove so a failed
  write never strands anyone), and a **context-menu anchor** (right-click on
  desktop, long-press on touch: move to opposite shift — disabled when it
  would double-book — and remove). Cells rebuilt (`ShiftCell` → stateful):
  hover border + inline "+ add", drop-target highlight, dashed empties, today
  ring kept. New pure **`schedule_insights.dart`** derives week facts — open
  shifts, one-person shifts, **double-booked people** (the new conflict
  indicator: red hairline + dot on the chip, both slots of the day flagged) —
  rendered as a clickable **insight strip** that *highlights* the matching
  cells (rest of the grid dims 35%); all-clear collapses to one quiet line.
  The old coverage %-bar card is gone (percentages re-read as quotas — a
  settled rejection); the floating swap footer became a **"N swaps waiting"
  chip** on the same strip → existing swap queue sheet. Tests:
  `schedule_insights_test.dart` (4).
- **macOS interaction layer (built once, reused).**
  **`core/widgets/app_context_menu.dart`** (the app-wide right-click menu),
  **`core/widgets/command_palette.dart`** — **⌘K** opens Go-to (sidebar
  destinations with their ⌘n hints) · role-gated Actions · People (from the
  warm task directory), keyboard-first (↑↓/↵/esc, prefix-ranked matching);
  bound in `AppShell` next to ⌘1–⌘9 (`AppShell.sectionsForRole` now public so
  palette and sidebar share one source). **`core/widgets/hover_lift.dart`**
  (reusable hover rise+shadow). Sidebar navigation now **cross-fades the
  content pane** (180 ms, keyed by active destination so intra-section pushes
  never double-animate).
- **Admin dashboard — executive two-column (desktop).** Wide main column tells
  the operational story: greeting + **"Search or run a command ⌘K" pill** →
  pulse hero → metric grid → new **Live activity feed** (newest
  `ActivityEntry`s across all branches, actor · action · task · time-ago, via
  the existing `activity_format` helpers). Fixed 330px right rail keeps the
  queues in view: Pending Actions, quick actions + manage (compact 2-up), and
  a new **Branch pulse** (per-branch open/review counts from the live stream).
  The Phase D rebuild-scoping (`_StatsSection`/`_DynamicSection`/
  `_PendingSection`) is preserved; mobile layout unchanged.
- **Employee management.** The Details dialog is replaced on desktop by a
  **person inspector** (`user_inspector_panel.dart`) — a 380px right
  slide-over (260 ms) with header + inline actions (Edit info · Reset ·
  De/Activate), Contact / Work / Compensation sections (empty rows collapse),
  and this-week metric chips (`computeEmployeeMetrics`). **Right-click on any
  employee card** opens the full action menu (Details / Edit info / Change
  branch / Set position / Reset / Deactivate). **Create Account** on desktop
  is a **2×2 of section cards** (Identity · Access · Work · Compensation) at
  960px instead of one long column; mobile keeps the single column.

`flutter analyze` clean (7 pre-existing infos, 0 new); **251 tests pass** (+4);
macOS debug build green.

### Added (2026-07-02 — UI/UX audit pass: compensation record, self-service profile, ⌘ navigation)

Full-app UI/UX audit against the "premium macOS app" brief (report:
[UI_UX_AUDIT_2026-07-02.md](UI_UX_AUDIT_2026-07-02.md)). The audit **verified as
already-done**: the DROP branding sweep (every user-visible surface — window
title, Info.plists, Android label, web manifest, in-app brand primitives — was
already DROP; the only `fbro` remnants are the registered Firebase iOS bundle id
and the repo folder name, which must not change), the monochrome design system +
desktop shell, the branded splash, and the schedule insights (coverage summary ·
broken-assignment banner · pending-swap alert). Two owner rulings were applied
over the brief: **no indigo** (strictly monochrome) and **lean, not enterprise**.
Three real gaps were implemented:

- **Compensation record (admin)** — `UserEntity`/`UserModel` gain
  `salaryAmount` (double), `salaryType` (`monthly`/`weekly`/`daily`),
  `paymentMethod` (`cash`/`bank`/`wallet`/`instapay`), and `paymentNumber` (the
  wallet/account number salary is transferred to). `UserModel.toMap` excludes
  all four (a routine write can never clobber them). New
  `UserAdminRepository.updateUserCompensation` (always writes all four keys —
  null clears); `AdminUsersCubit.updateDetails` gains a `writeCompensation`
  block (one busy cycle for the Edit Info sheet) and `setCompensation(uid)`
  serves the Create Account flow (a failed compensation write warns but never
  blocks the credentials hand-off). New shared
  `admin/presentation/widgets/compensation_fields.dart` (`CompensationFields` +
  canonical option maps + `salarySummary`) renders the section on **Create
  Account** and the **Edit Info** sheet; the employee **Details** dialog shows
  Salary / Paid via / Payment no. **`firestore.rules`:** the `users` self-update
  rule now freezes `salaryAmount`/`salaryType`/`paymentMethod` (admin-only);
  `paymentNumber` stays self-editable. ⚠️ **Deploy required:**
  `firebase deploy --only firestore:rules`.
- **Self-service profile (employee)** — `ProfileEntity` gains `address`,
  `emergencyContact`, `paymentNumber` (read side; the write pipeline already
  supported the first two since onboarding), threaded `paymentNumber` through
  `editMap` → datasource → repository → `UpdateProfile` → `ProfileCubit.save`.
  **Edit Profile** gains validated "Contact details" (phone · address ·
  emergency contact) and "Salary payment number" sections; the **Profile** page
  displays them. Employees can now correct their own contact/payment data any
  time — no admin relay, no stale copy (same `users/{uid}` doc the admin reads).
- **⌘1–⌘9 sidebar navigation (macOS/desktop)** — `AppShell` binds meta+digit
  shortcuts to the role's sidebar destinations (`CallbackShortcuts` +
  autofocused `FocusScope`); `AppSidebar` rows reveal their `⌘n` hint on hover
  for discoverability.

`flutter analyze` clean (7 pre-existing infos, 0 new); **247 tests pass** (+7 in
new `test/user_compensation_test.dart`); freezed regenerated; macOS debug build
green.

### Added (2026-07-01 — Shift Assignment feature: assign a task to a shift, not a person)

A task can now be assigned to **a shift** (Morning/Night) instead of named
employees — for shift-bound routines ("Open Store", "Close Store") where the
roster rotates daily. Read the existing task/schedule/recurrence code first
(entities, models, repositories, cubits, Firestore schema) and **reused every
matching primitive instead of duplicating**: the pre-existing `TaskEntity.shift`
field (previously just an Operations filter tag) is repurposed as the real
assignment target in this mode; visibility reuses `WeeklyScheduleEntity`'s
existing `shiftsFor`/`isAssigned`/`employeesFor` (the same "who's on shift X
today" logic `computeBranchWorkload` already relies on) with **zero new
schedule math**; notifications reuse the existing `NotifyTaskEvent` call
unchanged, just with a roster-resolved recipient list.

- **New enums** `core/enums/task_assignment_type.dart` (`individual`/`team`/
  `shift` — "team" is a UX-level alias for multi-select individual, no new
  entity) and `template_repeat_mode.dart` (`once`/`daily`/`weekly`, distinct
  from the existing per-task `RecurrenceFrequency`).
- **`TaskEntity`/`TaskModel`** gain `assignmentType`, `instanceDate` (the
  calendar day a shift instance is *for*), and `sourceTemplateId` (links a
  generated instance back to its template). Missing `assignmentType` on any
  pre-existing task parses to `individual` — **zero-migration back-compat**.
- **New pure domain helper** [`canUserAccessTask`](lib/features/task/domain/task_access.dart)
  — the single shared visibility gate: individual/team unchanged (`uid ∈
  assigneeIds`); shift mode requires `uid` to be rostered on `task.shift`
  *today* per the branch's weekly schedule. Tested in `test/task_access_test.dart`.
- **`TaskCubit`** now merges **multiple task streams** instead of one: an
  employee keeps their existing assignee stream and gains one
  `watchShiftTasks(branchId, shift)` subscription per shift they're rostered on
  today (`_subscribeEmployeeShifts`, via `ScheduleRepository.getSchedule` +
  `shiftsFor` — a new `ScheduleRepository` dependency on `TaskCubit`); each
  source's latest snapshot is merged/deduped by id on every update. Creating a
  shift task resolves notification recipients from **today's roster**
  (`_shiftRecipients`) instead of a fixed assignee list.
- **Recurring shift tasks get a proper Template ⇄ Instance split** — not the
  existing per-task `RecurrenceConfig` (approve-triggered, wrong for a shift
  routine nobody may ever complete, and would silently reuse/mutate one task
  forever instead of producing a trackable record per day). New
  [`RecurringTaskTemplateEntity`](lib/features/task/domain/entities/recurring_task_template_entity.dart)
  (collection `recurringTaskTemplates`, always branch-scoped) is the permanent
  blueprint; the new Cloud Function **`generateShiftTaskInstances`**
  (`functions/index.js`, `onSchedule` every 24h, modeled on the existing
  `runTaskReminders`) creates one real `tasks/{id}` per due date at a
  **deterministic id** (`rt_{templateId}_{yyyy-MM-dd}`, UTC) — the existence
  check against that id **is** the entire duplicate-prevention guarantee (no
  separate ledger needed), so every day's completion is independently
  trackable and overlapping/duplicate function runs are always safe.
  `TaskCubit.createRecurringShiftTemplate` also materializes **today's**
  instance client-side immediately via a new dedicated repository method,
  **`TaskRepository.createTaskWithId`** (a caller-assigned-id create that
  stamps both `createdAt`/`updatedAt` as server timestamps) — deliberately
  *not* a reuse of the existing `updateTask` (which only ever stamps
  `updatedAt`, which would have left `createdAt` permanently null and broken
  `sortTasksNewestFirst`'s "pending → always newest" ordering forever) — at the
  **same** deterministic id the Cloud Function uses, so the two paths can
  never double-create a day's instance.
- **UI:** `task_action_sheets.dart` gains an "Assigned to" chip row (Employee/
  Team/Shift, new-task only — the mode is fixed at creation and never
  editable) that swaps the employee picker for `ShiftChipPicker` +
  `ShiftRepeatPicker` (Once/Daily/Weekly [+ weekday]) in shift mode. New
  `recurring_shift_task_sheets.dart` ("Manage Recurring Shift Tasks" —
  list/pause-resume/delete), wired from `BranchOperationsScreen`'s app bar.
  `task_card.dart`/`task_details_screen.dart` now show "Morning Shift"/"Night
  Shift" instead of the (previously misleading) "Unassigned" for these tasks.
- **`firestore.rules`:** new `isShiftTaskInMyBranch()` helper ORed into the
  `tasks` read/update rules (branch-scoped trust, same bounded employee-write
  fields as the existing `isTaskAssignee()` path — an explicit, owner-confirmed
  tradeoff, not per-shift-verified; the UI is the real gate via client-side
  `canUserAccessTask`), plus a new `recurringTaskTemplates/{id}` block mirroring
  `task_templates`. New composite index (`tasks`: `branchId`+`assignmentType`+
  `shift` in `firestore.indexes.json`).

⚠️ **Deploy required before this works end-to-end:** `firebase deploy --only
firestore:rules,firestore:indexes,functions` — until then `watchShiftTasks`
fails `failed-precondition` and daily/weekly instances won't auto-generate
(shift-mode task creation and the client-side "materialize today" path still
work without the deploy).

`flutter analyze` clean (7 pre-existing infos, 0 new); **240 tests pass**
(incl. 8 new in `task_access_test.dart`); `dart run build_runner build
--delete-conflicting-outputs` regenerated the `.freezed.dart` files;
`node --check functions/index.js` clean.

### Fixed (2026-07-01 — macOS photo upload: missing sandbox entitlement + dead-end camera options)

Owner report: photo upload didn't work on the macOS build. Diagnosed by reading
the `image_picker_macos`/`file_selector` plugin source directly (not guessed):
on macOS, `image_picker` has no Photos-library integration — it opens the native
`NSOpenPanel` (file chooser) and returns a real file path. Since the app runs
**sandboxed** (`com.apple.security.app-sandbox`), reading that file's bytes back
(`File(picked.path)`, done at every call site: profile avatar/cover, task
proof/reference images, branch logo/cover) requires a declared entitlement —
without it the panel opens and a photo can be picked, but the read then fails
("Operation not permitted") and the upload never starts. Same class of bug as
the earlier keychain/network entitlement fixes on this branch.

- Added **`com.apple.security.files.user-selected.read-only`** to both
  `macos/Runner/DebugProfile.entitlements` and `Release.entitlements` (kept in
  sync, per the standing rule). Read-only is enough — the app never writes back
  to the picked file.
- `image_picker`'s `ImageSource.camera` isn't implemented on macOS/Windows/Linux
  (throws `StateError` without a registered `cameraDelegate`), so the "Take a
  photo" / "Record a video" rows in the Edit Profile avatar picker and the task
  `AttachmentPickerField` were dead ends on desktop. New
  `lib/core/utils/platform_capabilities.dart` (`supportsCameraCapture`, `!kIsWeb
  && (Platform.isAndroid || Platform.isIOS)`) gates both, so desktop only offers
  the picker path that actually works there; mobile is unchanged.

`flutter analyze` clean (7 pre-existing infos, 0 new); **233 tests pass**.
Verified the picker-UI change live (emulator-backed web build — this container
has no macOS build target); the sandbox-read fix itself is a documented Apple
requirement for `NSOpenPanel`-sourced files under the App Sandbox, the same
mechanism already confirmed for this plugin's `pickImage`/`pickMultiImage`.

### Fixed (2026-07-01 — live QA on Firebase emulators: Employees grid + Change Password heading)

First **live, running-app** verification pass (every earlier desktop-polish entry
below was static: code + `flutter analyze`/`test` only). Installed a local Flutter
SDK, built the app for web, pointed it at local Firebase Auth/Firestore/Storage
emulators (seeded admin/manager/3 employees across 2 branches with tasks in every
status), and drove it with Chromium at a 1440×900 desktop viewport through every
sidebar destination for all three roles plus the full first-login gate. Confirmed
the whole desktop redesign (dashboards, task/branch/schedule/comms/analytics
surfaces, forms, sheets) renders and fits as documented. Found and fixed two real bugs:

- **Employees page wasn't using the responsive grid.** `EmployeeManagementScreen`
  rendered its `EmployeeCard`s in a plain `ListView` (never wrapped in
  `ResponsiveCardGrid`), unlike the sibling Managers page — so on any desktop
  window it stayed a single full-width column instead of the 2-up grid every other
  admin list uses. Fixed by wrapping it in `ResponsiveCardGrid(runSpacing: 0,
  ultrawideColumns: 2)`, matching `admin_users_list_view.dart`.
- **Change Password showed its title twice.** The page still carried a
  pre-migration in-body heading (`Text('Change\nPassword', style:
  displayMedium)`) left over from before it was wired into `AdaptiveScaffold`,
  which already renders the `title: 'Change Password'` in the app bar (mobile) /
  page header (desktop). The leftover duplicate was hard-wrapped onto two lines by
  a stale literal `\n`. Removed the redundant heading (and the now-unused
  `isDark`/`AppColors` import), kept the one-line instructional subtitle.

`flutter analyze` clean (7 pre-existing infos, 0 new); **233 tests pass**;
`flutter build web --release` green. The emulator harness (seed script, temp
`dev_tools/main_emulator.dart` entrypoint, Playwright driver) was scratch-only —
not committed.

### Changed (2026-07-01 — full-screen UI audit: form/detail column widths)

Swept **every** page (39) for desktop-width behaviour. Beyond the card grids
(below), the remaining issue was **forms and detail screens stretching to the
full 1280 dashboard width**, which reads poorly. Added a `contentMaxWidth`
override to `AdaptiveScaffold` (feeds its `ContentConstraint`) and applied a
comfortable column width to the screens that are read, not scanned:

- **Forms** centred to a narrow column: Change Password (560), Create Account &
  Edit Profile (620).
- **Read/list panes** centred: Settings & Profile (680), Notifications inbox
  (760 — kept single-column; a chronological + swipeable feed shouldn't grid).
- **Left full-bleed (correct as-is):** the schedule grids
  (`branch_schedule_screen`, `schedule_management_screen`,
  `constrainContent: false`), analytics (charts want width), and the dashboards
  (already responsive grids via `RoleScaffold`). Auth-gate pages
  (`force_password_change`, `profile_completion`) already centre via
  `AuthScaffold`.
- **Cleanup:** removed 3 dead unused-parameter warnings from `settings_page`
  (`iconColor`/`labelColor`/`subtitleColor` — no caller ever set them). Analyzer
  now 7 issues (was 10), all pre-existing `auth_cubit` style infos.

`flutter analyze` (7 pre-existing infos, 0 new) · **231 tests pass** · macOS
build green.

### Fixed (2026-07-01 — oversized heroes/cards/dashboards on macOS)

Owner feedback: on a large macOS window the cockpit cover, the stat cards and
the dashboards were **way too big**. Fixes:

- **Branch Operations cover was ~700px tall** (a 16:9 `AspectRatio` at full
  width). Now a fixed slim **230px** banner (190 on mobile), image still
  `BoxFit.cover`. (`branch_operations_screen._BranchHero`)
- **Cockpit summary was a 2×2 grid of giant stat cards** → on desktop it's now
  one tight **row of four** compact tiles. (`_SummaryHeader`)
- **Admin dashboard laid every card 2-per-row** (each ~630px). `_grid` is now a
  width-aware `ResponsiveCardGrid` (3–4 compact tiles per row on desktop).
- **`StatGrid`** (shared manager + employee dashboards) was hardcoded to 2
  columns → now **2–4** width-aware columns (`statGridColumns`).
- **Global content width tightened 1280 → 1120** (`Breakpoints.contentMaxWidth`)
  so heroes/cards/buttons read premium instead of sprawling on wide monitors.

`flutter analyze` clean (7 pre-existing infos) · **233 tests pass** · macOS build
green.

### Fixed (2026-07-01 — task cards were still too wide on macOS)

Follow-up to the card-grid work: at a typical ~1440 macOS window a 2-column task
card was still ~540px — too wide/uncomfortable. Two fixes:

- **`ResponsiveCardGrid` gained a `maxItemWidth` mode**: the column count is now
  derived from the available width so **no card is ever wider than the limit**
  (a lone card sits in one narrow cell instead of stretching). Applied to every
  task-card surface at **480** (workload cards 460, branch-overview cards 520),
  giving a comfortable ~350–465px card and 2–3 columns depending on window size.
- **Two more task screens were still single-column full-width and are now
  gridded:** the **Branch Operations cockpit** (employee `WorkloadCard`s — the
  screen shown when you tap a branch) and **Employee detail** (that employee's
  task cards, gridded within each status group). These were the widest offenders.

`flutter analyze` clean (7 pre-existing infos) · **233 tests pass** (+2
`maxItemWidth` cases) · macOS build green.

### Changed (2026-07-01 — task screens use desktop width: responsive card grids)

On wide macOS windows the task screens rendered one over-wide card per row (a
single branch cover ballooned to ~half the screen). New reusable
**`ResponsiveCardGrid`** (`core/widgets`) lays cards out width-aware: 1 column on
mobile (unchanged), 2 on desktop, 3 on ultrawide — via a `Wrap` so each card
keeps its natural height. An optional `runSpacing: 0` lets cards that already
carry their own bottom margin (the task cards) avoid double spacing.

- **Admin Task Management** (`admin_task_overview_screen`): branch cards now grid
  (2/3 columns) so several branches show at once and each cover photo stays a
  sensible height instead of half the screen.
- **Branch task list** (`branch_task_list_screen`) and **My Tasks**
  (`my_tasks_screen`, both the sectioned Active tab and the Done tab): task cards
  lay out 2-up on desktop.
- **Employees / Managers** (`admin_users_list_view`) and **Branches**
  (`branch_management_screen`): user/branch cards lay out 2-up (these richer
  management cards are capped at `ultrawideColumns: 2` so they never get cramped).
- **Pending Review** (`pending_review_screen`): the leaf task-card level grids
  2-up; the drill-down navigation rows stay full-width (they're nav, not cards).
- **Scheduled broadcasts** (`broadcast_schedules_screen`): schedule cards grid
  2-up.
- **Deliberately left single-column** (premium ≠ everything-is-a-grid): the
  Notifications inbox (chronological + swipe-to-action) and the Communications
  feed (already a desktop command-center with a side panel).
- Mobile layout unchanged (single column). `flutter analyze` clean;
  **231 tests pass** (+4 `responsive_card_grid_test`); macOS build green.
- Also removed the temporary keychain sign-in diagnostics (issue confirmed fixed)
  while keeping the explicit `keychain-error` → actionable-message mapping.

### Changed (2026-07-01 — desktop punch-list: 10 screens onto AdaptiveScaffold)

Completed the desktop-header migration punch-list — every remaining screen on a
raw mobile `AppBar` now uses `AdaptiveScaffold` (premium desktop page header
beside the persistent sidebar; mobile keeps the app bar). All monochrome,
`flutter analyze` clean (no new issues), macOS build green.

- **AdaptiveScaffold gained two params:** `titleWidget` (a custom title lockup —
  e.g. branch avatar + name — that replaces the plain title in both tiers) and
  `bottomBar` (a pinned bottom action bar → `Scaffold.bottomNavigationBar` on
  both tiers, for the broadcast send bar).
- **Tasks:** `branch_task_list_screen` (+ subtitle), `pending_review_screen`
  (custom drill-up `leading` preserved, contextual per-level subtitle),
  `task_detail_loader_screen` (error state).
- **Operations:** `branch_operations_screen` (reactive branch avatar+name via
  `titleWidget`, scaled up on desktop), `employee_detail_screen` (avatar+name+role
  lockup via `titleWidget`, scaled up on desktop).
- **Schedule:** `my_schedule_screen` (TabBar via `bottom:`; removed a dead no-op
  "Notifications" app-bar button).
- **Admin:** `admin_users_list_view` (+ optional `subtitle` param).
- **Communications:** `compose_broadcast_screen` (send bar via `bottomBar`),
  `broadcast_detail_screen`, `broadcast_templates_screen`,
  `broadcast_schedules_screen` — all with desktop subtitles where useful.
- **Auth/onboarding pages now responsive too** (were the last stretched-mobile
  screens). New reusable **`AuthScaffold`** (`features/auth/.../widgets`): mobile
  keeps the transparent app bar; desktop centres the page content in a
  comfortable ~440px column on the dark canvas (matching the Login panel) with a
  slim top utility row (back button / "Sign out"). Applied to
  `forgot_password_page` (back), `force_password_change_page` +
  `profile_completion_page` (Sign out). Verified live on the Reset Password page.

### Fixed (2026-07-01 — macOS keychain login, desktop window sizing, monochrome revert)

Production-hardening pass on the `feature/macos-desktop` branch.

- **macOS keychain login crash — SOLVED (root cause: Debug entitlements).**
  Sign-in failed with *"An error occurred when accessing the keychain"*. **Audit
  result:** the error is a `FirebaseAuthException` (code **`keychain-error`**)
  from FirebaseAuth's **native** macOS session persistence — **not**
  `flutter_secure_storage`, which is declared in `pubspec.yaml` but **unused
  anywhere in `lib/`**. **Root cause:** `DebugProfile.entitlements` (used by
  `flutter run -d macos`) was **missing `keychain-access-groups`**. Signing was
  configured (`DEVELOPMENT_TEAM = 7Q3PY75VGH`, Apple Development cert) and the
  Keychain Sharing capability had been added — but only to `Release.entitlements`,
  so the **debug build** the owner was running had no declared keychain group and
  FirebaseAuth's keychain write failed. **Fix:** added
  `keychain-access-groups` = `$(AppIdentifierPrefix)com.example.fbro` to
  `DebugProfile.entitlements` and restored the App Sandbox so Debug matches
  Release. **Verified:** the debug binary now embeds
  `keychain-access-groups = 7Q3PY75VGH.com.example.fbro`, signed by the Apple
  Development cert. Also: added temporary debug-only diagnostics around the
  sign-in call (`auth.keychain` log) and an explicit `keychain-error` →
  actionable message in `auth_remote_datasource.dart`. **Keep both entitlement
  files in sync going forward.**
- **Desktop layout now actually engages.** The macOS window opened at the
  storyboard default (~800×600), below the **1024pt** desktop breakpoint, so the
  app fell back to the cramped *mobile* layout. `MainFlutterWindow.swift` now
  opens at **1440×900** (clamped to the visible screen) with a **1024×720
  minimum**, so the premium split/sidebar desktop UI always renders.
- **Premium macOS window chrome.** `MainFlutterWindow.swift` hides the window
  title text (`titleVisibility = .hidden`), makes the title bar transparent, and
  sets the window background to the app near-black (`#0A0A0B`) — so the title bar
  blends seamlessly into the app (Linear/Things style) instead of a grey bar
  reading "DROP". Content is **not** pushed under the title bar, so the
  traffic-light buttons never collide with the sidebar or page headers.
- **Indigo reverted → strictly monochrome (locked owner ruling).** This branch
  had reintroduced indigo `#5B5FEF` as the accent; per the standing decision the
  product is monochrome. The `AppColors.accent*` tokens (32 call sites across 16
  files) now resolve to the **white-on-black** accent — primary CTAs are white
  with dark text, active nav / links / focus are white or a low-opacity white
  wash. No call sites changed (every indigo fill was paired with `onAccent`);
  stale "indigo" comments updated. `flutter analyze` clean (no new issues);
  macOS debug build signs and runs; verified on the live login screen.
- **Login brand panel uses the real DROP logo.** The desktop sign-in brand panel
  rendered a typographic `DropWordmark` + accent dot; it now shows the actual
  `assets/drop_logo.png` artwork (the DROP wordmark with the down-arrow), tinted
  white via the existing `DropLogo` widget — matching the mobile `DropAuthMark`
  lockup. Verified on the live login screen.

### Added (2026-06-30 — Premium desktop polish: schedule grid, task ticket, comms command-center)

The final desktop-quality pass on the priority screens (beyond AppBar swaps).

- **Calm desktop transitions:** sidebar/route changes now fade (~160ms) on
  desktop instead of the mobile slide; the dashboard/onboarding fade dropped
  400ms→180ms. Mobile keeps the slide. (`app_router.dart`)
- **Schedule = wide ops dashboard:** the weekly grid (`schedule_grid.dart`) now
  stretches its 7 day-columns to fill the desktop width (no horizontal scroll)
  via a `LayoutBuilder`; mobile keeps fixed scrolling cells. The controls
  (`manager_schedule_view.dart`) collapse into a single dense desktop toolbar
  (branch identity · branch picker · week navigator · shift filter) and the grid
  hint is desktop-aware.
- **Task Details = Linear/Jira ticket:** desktop renders a two-column layout —
  the record (status, description, reference, checklist, submitted proof,
  activity timeline) on the left and a dedicated **action panel** (assignment,
  recurrence, approve/rework/submit) on the right. Mobile layout untouched.
  (`task_details_screen.dart`)
- **Communications = command-center:** desktop adds a right command panel with
  live **delivery analytics** (broadcasts · recipients · delivered · delivery
  rate) and quick links (New Broadcast · Templates · Scheduled · Archived)
  beside the history feed. (`communications_screen.dart`)
- **More screens migrated to `AdaptiveScaffold`:** my-tasks (TabBar via `bottom`),
  employee management, create account, branch management. Key FABs/CTAs adopt the
  indigo accent.

### Added (2026-06-30 — Desktop-first UI: ShellRoute, persistent sidebar, indigo accent)

The macOS app was a stretched mobile UI (per-screen app bars, pushed screens, no
persistent nav). This pass establishes a true desktop-first architecture.

- **`ShellRoute` + `AppShell`** (`lib/core/widgets/app_shell.dart`): a single,
  role-aware persistent sidebar now wraps **every authenticated route** (mounted
  once, never re-animates). Auth/splash/onboarding stay outside the shell. The
  router (`app_router.dart`) was restructured to nest all in-app routes under the
  shell; redirect guards and transitions are unchanged. Mobile/tablet are a no-op
  pass-through (original chrome preserved).
- **`AppSidebar`** (`lib/core/widgets/app_sidebar.dart`): premium monochrome rail
  with sectioned, role-based destinations, hover states, active-destination
  resolution from the current location, and a pinned user footer with an
  unread-aware indicator. Indigo accent marks the single active item.
- **`AdaptiveScaffold`** (`lib/core/widgets/adaptive_scaffold.dart`): the per-screen
  migration primitive — mobile keeps the `AppBar`; desktop drops it for a calm,
  spacious in-body page header (large title, optional subtitle, right-aligned
  actions, auto back button, optional custom leading) with a width-constrained body.
- **Indigo accent** added to `AppColors` (`accent #5B5FEF` + hover/pressed/surface/
  border/onAccent), applied *only* to important interactive elements: active nav,
  primary CTA button (`AppButton` primary is now indigo, flat — no glow), key FABs,
  and links. The monochrome base is otherwise unchanged.
- **Premium desktop Login**: split layout (brand canvas + focused sign-in panel)
  on desktop; the original centred lockup on mobile.
- **Screens migrated to `AdaptiveScaffold`** (no desktop app bar): notifications,
  settings, change-password, profile, edit-profile, analytics, schedule
  management, branch schedule, communications center, admin task management; the
  three role dashboards via `RoleScaffold` (which now defers desktop chrome to the
  shell). Replaced the previous `RoleScaffold`-owned desktop sidebar
  (`desktop_nav_sidebar.dart` removed) with the shell.
- ⚠️ ~21 secondary screens still render their own `AppBar` on desktop (they now
  have the sidebar, but not the desktop header). They are listed in CURRENT_STATE
  as the remaining mechanical `AdaptiveScaffold` migration. Validate the whole
  pass with `flutter analyze` + run (no Dart SDK was available in the change env).

### Fixed (2026-06-30 — macOS login "No internet connection" root cause)

The macOS desktop build could not sign in — Firebase Auth surfaced a generic
"no internet connection" error even with a working network. **Root cause:** the
app runs in the macOS App Sandbox (`com.apple.security.app-sandbox` = true) but
was **not granted the outgoing-network entitlement** `com.apple.security.network.client`.
`DebugProfile.entitlements` only had `network.server` (incoming sockets, e.g. the
Flutter debug VM service) and `Release.entitlements` had **no network entitlement
at all** — so every outbound HTTPS call from Firebase Auth/Firestore/Storage/FCM
was blocked by the sandbox, which the native SDK reports as a connectivity error.

- Added `com.apple.security.network.client` to **both** `macos/Runner/DebugProfile.entitlements`
  and `macos/Runner/Release.entitlements` (the latter previously had no network access,
  so release builds could never reach Firebase).
- Hardened auth error mapping in `auth_remote_datasource.dart`: `signInWithEmail`
  (and password reset / change) now also catch `SocketException`, `TimeoutException`,
  `HandshakeException`/`TlsException` and `PlatformException` (previously only
  `FirebaseAuthException`), mapping each to a precise, actionable message — DNS
  failure, SSL/TLS error, blocked/unreachable network, timeout, misconfigured API
  key, disabled provider — instead of one opaque bucket. The null-`user` case is
  handled explicitly. `network-request-failed` now reads as "could not reach the
  authentication server / check the app is allowed network access" rather than
  implying a wrong password.

### Changed (2026-06-30 — Full DROP rebrand: Dart package `fbro` → `drop`)

Completed the rebrand the visual identity started, removing the last source-level
`FBRO` references. A previous attempt was reverted because it used an invalid
package name (`Drop`, uppercase) and didn't update imports; this pass does it
correctly and completely.

- `pubspec.yaml` `name: fbro` → `name: drop` (+ DROP OPERATIONS description); all
  **272** Dart files updated `package:fbro/…` → `package:drop/…` (lib + test).
- Platform display names rebranded to **DROP** / **DROP OPERATIONS**: macOS
  `PRODUCT_NAME`/copyright (+ built product `DROP.app`, scheme + pbxproj refs),
  Windows `Runner.rc`/`main.cpp`/`CMakeLists.txt`, Linux window titles +
  `CMakeLists.txt` binary name, `.vscode`/`.claude` launch configs.
- **Intentionally retained:** the bundle/application identifier `com.example.fbro`
  (macOS/iOS/Android + GoogleService-Info.plist + google-services.json +
  firebase_options.dart + Linux APPLICATION_ID + RunnerTests ids). These are
  registered with Firebase; changing them without re-registering the apps in the
  Firebase console would break Auth. A note documenting this was added to
  `AppInfo.xcconfig`. ⚠️ Validate with `flutter pub get && flutter analyze &&
  dart run build_runner build` (no Dart SDK was available in the change
  environment).

### Added (2026-06-30 — Premium macOS desktop layout foundation)

First-class desktop chrome so the app stops feeling like a stretched phone UI.

- `lib/core/responsive/breakpoints.dart`: `DeviceType` (mobile/tablet/desktop/
  ultrawide), centralised thresholds, `BuildContext` responsive extensions
  (`isDesktop`, `deviceType`, tier-aware `pagePadding`, `gridColumns`),
  `ResponsiveBuilder`, and `ContentConstraint` (centred max-width column).
- `lib/core/widgets/desktop_nav_sidebar.dart`: premium persistent left sidebar
  (DROP wordmark, hover-reactive destinations, active accent pill + leading bar,
  mouse-click cursors) — the native-desktop counterpart to the mobile bottom nav.
- `RoleScaffold` is now window-aware: desktop/ultrawide widths render the sidebar
  + a slim desktop top bar + content constrained to a comfortable width; mobile/
  tablet keep the original app bar + bottom nav unchanged. Navigation semantics
  are identical (still routes the same destinations). Resize-safe (MediaQuery-driven).

### Added (2026-06-28 — Branch cover photo on the admin task overview)

Owner request: show the branch **cover photo** on the branch cards in the admin Task
Management overview (`AdminTaskOverviewScreen`), matching the branch-identity banner
already on Task Details. Each `_BranchOverviewCard` now leads with a `_CoverHeader`
(16:7 cover image + dark scrim + logo/name/location + attention pill + chevron
overlaid) **when the branch has an uploaded `coverUrl`**; branches without media keep
the plain text header. Metrics (Active / Pending review / Overdue / Completion) always
render below on the dark surface so they stay legible over any photo. `_BranchRow`
gained `coverUrl`/`logoUrl` (populated from `TaskCubit.branches()` → already-loaded
`BranchEntity`; synthetic "Unknown branch" rows have none). Reuses `BranchAvatar` +
the existing §8b media pipeline — no new data layer, no deploy. `flutter analyze`
clean; **227 tests pass**.

### Added (2026-06-28 — Input validation on user-detail fields)

Owner request: a newly-created user completing their profile (and admins entering
contact details) must not be able to type the wrong kind of value — a phone field
must hold a **number**, not an email; a name must be **letters**, not digits, etc.
New shared **`Validators`** util (`lib/core/utils/validators.dart`, pure + unicode-
aware so Arabic names/addresses pass): `phone` (digits + `+ - ( )`, 7–15 digits,
rejects letters/`@`), `name` (letters only), `address`, `emergencyContact` (must
contain a phone number), `email`; each takes `required` so the same rule serves a
mandatory onboarding field and an optional admin "clear-to-empty" field. `AppTextField`
gained an **`inputFormatters`** hook; phone fields use `Validators.phoneInput` so
letters/`@` can't even be typed. Wired into **`ProfileCompletionPage`** (first-login
required fields), the admin **Edit details** sheet (was un-validated, now form-checked
when non-empty) and **Create account** (name/email use the shared validators). New
`validators_test.dart` (**+10 tests → 227 pass**). `flutter analyze` clean. Client-only,
**no deploy**.

### Fixed (2026-06-28 — Account-switch push failure on a shared device)

Owner-reported: on a shared Samsung phone, push to the **currently** signed-in account
works, but after switching to a **second** account, pushes to that account fail
persistently. **Root cause (L1 client gap):** a device's FCM token is per-device, not
per-user — `getToken()` returns the **same** token across accounts. `registerToken(uid)`
set `_uid = uid` and then called `_rotateToken`, whose dedup guard
(`_currentToken == token && _uid == uid`) early-returns. If the prior session's
`_currentToken` survived in memory (any switch path that bypassed `forgetUser`), the
guard matched and the new user's doc **never** received the token → `claimFcmToken`
had nothing to reclaim → every push to that user reported "0 registered tokens".
**Fix:** `NotificationService.registerToken` now clears `_currentToken` whenever the
uid changes, forcing a fresh `fcmTokens` write that `claimFcmToken` reclaims from the
prior owner — independent of whether the client `forgetUser` cleanup ran. Client-only,
**no deploy** (server `claimFcmToken` unchanged). `flutter analyze` clean.

### Added (2026-06-27 — Delete a sent broadcast)

Owner request: an option to **permanently delete** broadcasts from the Communications
feed (the earlier 2026-06-24 "simplification" had removed broadcast delete, leaving
archive-only). Re-added as a real **hard delete** of the `broadcasts/{id}` doc (not
the old soft-delete/`deletedAt` + "Deleted view" — that stays gone). Full slice:
`BroadcastRepository.delete` / `BroadcastRemoteDataSource.delete` (`doc(id).delete()`)
/ `BroadcastCubit.deleteBroadcast` (feed-preserving error handling) → a **Delete**
(destructive) item in the broadcast card overflow menu **and** the detail-screen
overflow (pops back after deleting), each behind a confirm dialog. **Firestore rule:**
`broadcasts` `delete` now allowed for an **admin**, the **original sender**
(`senderId == uid`), or the **owning-branch manager** (`canReachBranch(branchId)`) —
was `if false`. The live feed stream re-emits without the doc. `flutter analyze`
clean; **217 tests pass**. ⚠️ **Deploy required:** `firebase deploy --only
firestore:rules` — until then the client delete fails with permission-denied.
_Note: deleting the broadcast doc does not remove the per-recipient `notifications/{id}`
inbox entries already delivered (separate collection); acceptable — recipients keep
what they received._

### Fixed (2026-06-27 — iOS keyboard stuck in the broadcast template sheet)

The Communications Center **template editor** (`_TemplateEditor`, a modal bottom
sheet with title + multiline message fields) had no way to dismiss the iOS keyboard
— a multiline field shows no "Done" key and tapping outside doesn't unfocus by
default, so the keyboard felt stuck and the sheet was hard to close. Added three
standard affordances: **tap anywhere outside a field** (`GestureDetector` →
`FocusScope.unfocus`), **drag-to-dismiss** (`ListView.keyboardDismissBehavior:
onDrag`), and an explicit **close (✕) button** in the header (drops the keyboard
then pops the sheet). Presentation-only; `flutter analyze` clean. No deploy needed.

### Added (2026-06-27 — Broadcast/notification dispatch diagnostics: per-token FCM errors)

Follow-up to the `sendBroadcast` audit. The push paths **discarded the per-token FCM
error** (only used it to prune dead tokens), and `onNotificationCreated` logged
`tokenCount` (the *attempt* count) as `"notification pushed"` — which made a
0-delivered push look healthy and hid *why* `deliveredCount` was 0. Added per-token
failure logging to **both** paths (`dispatchBroadcast` + `onNotificationCreated`)
surfacing the exact `code`/`message` (e.g. `messaging/third-party-auth-error` = iOS
APNs key not configured; `messaging/registration-token-not-registered` = stale
token), plus real `successCount`/`failureCount` on the task path. **Audit verdict:**
recipient query (`where isActive == true` / branch / single / `getAll`), sender
self-exclusion (implicit audiences only), token field (`fcmTokens` array + legacy
`fcmToken`), and flattening are all **correct** — `deliveredCount: 0` with stored
tokens means FCM **rejects them at send time** (then the dead-token pruning, which
also fires on `messaging/invalid-argument`, empties the array → later sends log "no
registered device tokens"). `node --check` valid. ⚠️ **Deploy** `firebase deploy
--only functions` to activate the logging, then one test send reveals the exact code.

### Added (2026-06-27 — Branch identity in tasks: cover banner + logo chip)

Surface each branch's **media** (logo + cover) on task surfaces so a task visibly
belongs to its branch — extending the §8 branch media + the §8b app-wide
`BranchCubit` directory into the task feature (no new schema / rules / DI). Strictly
monochrome; reuses the Operations branch-hero cover pattern + the shared
`BranchAvatar`. `flutter analyze` clean; **217 tests pass**. **No deploy needed.**

- **Task Details — branch cover banner.** `task_details_screen` resolves the task's
  branch via `context.watch<BranchCubit>().branchById(task.branchId)` and, when the
  branch has an uploaded **`coverUrl`**, leads the details body with a slim 16:6
  `_BranchBanner` — the cover photo behind a dark scrim with the branch `BranchAvatar`
  (logo) + name + location overlaid. Hidden when the branch has no cover (no empty
  placeholder). The recently de-flashed `_StatusHeader` is untouched (the banner is
  additive, above it).
- **Task card — branch logo chip.** `TaskCard` gains an optional `branchLogoUrl`; the
  branch signal chip now leads with the branch's actual **logo** (`BranchAvatar`,
  18px) when one is uploaded, falling back to the store glyph otherwise (new
  `_BranchChip`). `ManagerTaskCard` resolves it from the app-wide `BranchCubit`
  directory (`branchById(task.branchId)?.logoUrl`). `TaskCard` itself stays
  provider-free (the value is threaded in), so the existing `task_card_layout_test`
  is unaffected.
- **Requires branch media:** the banner/logo only appear for branches that have a
  cover/logo uploaded (Admin → Branches → edit → Branch media). Branches without
  media render exactly as before (store glyph + name).

### Added + Diagnosed (2026-06-26 — Admin-editable user contact details + notification delivery diagnosis)

Two owner requests. **(1)** Admins can now record/edit more information about a
person **at any time after account creation** (not forced at provisioning). **(2)**
Diagnosed why push notifications "fail / nothing received" — the **server side is
healthy** (all 9 Cloud Functions deployed; `onNotificationCreated` logs successful
pushes today), so the fault is **client/platform config**, dominated by iOS. `flutter
analyze` clean (no new issues); **217 tests pass** (+5: `user_model` contact
round-trip + `user_admin_update_details` merge-map coverage). No Cloud Function /
rules change; **no deploy needed** for these changes.

- **Admin "Edit Info" (contact details).** New `UserEntity`/`UserModel` fields
  **`address`** + **`emergencyContact`** (`phoneNumber` already existed; freezed
  regenerated). New `UserAdminRepository.updateUserDetails(uid, {displayName,
  phoneNumber, address, emergencyContact})` → the existing `updateUser` merge write
  (only non-null fields written; `displayName` mirrors to the legacy `fullName`
  key) + `AdminUsersCubit.updateDetails`. New **`showEditDetailsSheet`** (Full name ·
  Phone · Address · Emergency contact, pre-filled, editable/clearable) wired as an
  **Edit Info** action on **both** the Employees and Managers lists; the employee
  **Details** dialog now shows phone/address/emergency when present. Admins already
  have full `users/{uid}` write per `firestore.rules` — no rule change. The fields
  are non-privileged (not frozen by the self-update rule), so they coexist with
  profile onboarding (which already collects address/emergency contact).
- **Notification diagnosis (no code change).** Verified `firebase functions:list` →
  all 9 functions live; `onNotificationCreated` logs `"notification pushed"` with
  `tokenCount ≥ 1` as recently as today; a broadcast logged `deliveredCount: 0`
  (recipient had **no registered device token**). Root causes are platform/config:
  - **iOS (primary blocker):** ✅ **bundle-id mismatch FIXED** — the iOS bundle id
    was changed `com.ziadelsewedy.fbro` → **`com.example.fbro`** in
    `ios/Runner.xcodeproj/project.pbxproj` (all 3 Runner configs), so the app now
    matches the existing `GoogleService-Info.plist` + `firebase_options.dart` +
    Android (reuses the one Firebase iOS app — no plist swap, no `flutterfire
    configure`). **Still owner to-dos (Xcode/Apple, not code):** **no
    `Runner.entitlements`** at all (no `aps-environment` → iOS can't obtain an
    APNs/FCM token) — add the **Push Notifications** + **Background Modes → Remote
    notifications** capabilities in Xcode; and an **APNs Auth Key** must be uploaded
    to Firebase → Cloud Messaging. (No native signing files were half-edited beyond
    the bundle id, which would break the build.)
  - **Android:** correctly configured (`applicationId com.example.fbro` matches
    `google-services.json`; `POST_NOTIFICATIONS` merges from the `firebase_messaging`
    plugin). Residual failures are device-side: the runtime notification-permission
    grant (Android 13+) or a recipient who never registered a token (e.g. only ever
    signed in on the mis-configured iOS build).

### Changed + Removed + Added (2026-06-26 — Auth & account provisioning redesign: admin-only accounts)

**Core business change: DROP no longer allows public registration — only an admin
creates accounts.** The entire authentication + provisioning system was migrated
to an admin-provisioned model across every layer (data model, backend, security
rules, routing, AuthCubit, admin module, auth UI). ⚠️ This env's Flutter is
**3.10.4 / Dart 3.10.4** (< the project's `^3.12.1`), so `build_runner` / `analyze`
/ `test` can't run here — the freezed files for `UserEntity` + `AuthState` were
**hand-edited**; run `dart run build_runner build --delete-conflicting-outputs`,
`flutter analyze`, `flutter test` on a current SDK (3.12.2). `node --check
functions/index.js` valid; all changed Dart parse-checked (`dart format`).
⚠️ **Deploy required before client cutover:** `firebase deploy --only
functions,firestore:rules` — until the new functions + rules are live, account
creation + the `create: if false` lockdown aren't in effect.

- **Removed (completely):** public registration / signup, phone-OTP sign-in,
  Google sign-in, email-verification gating, and the approval / pending-approval
  flow. Deleted: `register_page` · `phone_otp_page` · `email_verification_page` ·
  `pending_approval_page` · `otp_input` · `pending_approvals_screen` · the
  `approval_status` enum · use cases {`register_with_email`, `sign_in_with_google`,
  `verify_phone_number`, `sign_in_with_otp`, `send_email_verification`,
  `check_email_verified`, `save_user`, `delete_account`} · the `google_sign_in`
  dependency. `AuthState` dropped `otpSent` + `awaitingEmailVerification`;
  `AuthAction` is now {emailSignIn, forgotPassword, changePassword}.
- **Data model (`users/{uid}`):** `UserEntity`/`UserModel` gained
  `mustChangePassword` (default false), `isProfileCompleted` (default true),
  `employmentStatus` (HR label, default `active`), `createdBy`. Removed
  `approvalStatus` + `isApproved`; `hasAppAccess` is now simply `isActive` (the
  single access gate). Legacy docs default to NOT forced so no one is trapped.
  `name` maps to the existing `displayName` (mirrored to profile `fullName`).
- **Backend (`functions/index.js`):** two admin-only callables —
  **`createUserAccount`** (Admin SDK creates the Auth user — without signing the
  admin out — then seeds the `users/{uid}` doc with role/branch/shift/position +
  `mustChangePassword:true` + `isProfileCompleted:false` + `createdBy`;
  email-already-exists → `already-exists`; rolls back the orphaned Auth user if
  the Firestore seed fails) and **`adminResetPassword`** (new temp password +
  re-force a change). Both validate the caller is an admin.
- **Firestore rules:** `users` `create: if false` (server-side Admin SDK is the
  ONLY creation path); the self-update rule freezes all privileged fields (role,
  isActive, branchId, assignedShift, position, **employmentStatus**, **createdBy**)
  and allows only profile fields + the two first-login flags. Dropped every
  `approvalStatus` reference.
- **Routing:** new gate `unauthenticated → Login`, `mustChangePassword → Force
  Password Change`, `!isProfileCompleted → Profile Completion`, else role home.
  The redirect now only bounces an **explicitly** unauthenticated session to
  Login, so a transient cubit state (e.g. the in-flight forced change) never
  flickers the user out. New routes `/force-password-change`, `/complete-profile`,
  `/admin/users/create`; removed `/register`, `/phone`, `/email-verification`,
  `/pending-approval`, `/admin/approvals`.
- **AuthCubit:** trimmed to email/password + reset + change; a **deactivated
  account is blocked at login + signed out** with "This account has been disabled
  — contact your administrator." New `forcePasswordChange` (change → clear
  `mustChangePassword` → refresh) and `completeProfile` (set `isProfileCompleted`
  → refresh); `watchCurrentUser` also force-signs-out on a mid-session deactivate.
- **Auth UI (premium, strictly monochrome — no indigo, per the locked design
  ruling):** Login redesigned (centered `DropAuthMark`, soft monochrome gradient,
  smooth focus, beautiful CTA; **no** signup / Google / phone affordances + an
  "Accounts are created by your administrator" note). New **Force Password
  Change** + **Profile Completion** (phone / emergency contact / birth date /
  address required, profile photo optional) screens. Settings dropped Verify Email
  + Delete Account (lifecycle is admin-owned).
- **Admin → User Management → Create Account:** new `CreateAccountScreen` (Full
  Name · Email · Temporary Password · Role · Branch · Assigned Shift · Position →
  the `createUserAccount` callable; shows the temp credentials to hand off),
  reached from the Employees FAB + the Admin Home "Create Account" quick action.
  `AdminUsersCubit`/`UserAdminRepository`/datasource dropped approve/reject/
  pending; added `createAccount`/`resetAccount`/`changeEmploymentStatus`. Admin
  user card/sheets/employee details drop approval, add **Reset account** +
  Employment status; the Admin Home "Pending approvals" panel + `PendingActions`'
  approvals queue were removed.
- **Statistics:** dropped the user-approval `pendingApprovals` query (the field is
  retained as an always-0 deprecated remnant to avoid a codegen churn).
- **Profile:** `emergencyContact` + `address` threaded through the write path
  (`editMap`/`updateProfile`/`ProfileCubit.save`) for onboarding; stored on
  `users/{uid}`.
- **Tests:** `user_model_test` covers the new provisioning fields +
  `displayName`/`fullName` fallback; `pending_actions_widget_test` updated to the
  approval-free panel.

### Added (2026-06-26 — FCM token ownership: layered defense-in-depth)

Hardened notification routing into a **three-layer** defense so no push can reach
the wrong account under app crashes, interrupted logout, multi-account device
reuse, or token-refresh races. Builds on the pre-sign-out cleanup (Layer 1) +
`claimFcmToken` (Layer 2) already in place. `node --check` valid; changed Dart
parse-checked. ⚠️ Deploy `functions`; run `flutter analyze`/`test` on a current SDK.

- **Layer 1 — pre-sign-out cleanup (client, already shipped).** `AuthCubit.signOut()`
  awaits `onPreSignOut` (→ `NotificationService.forgetUser`) to remove this device's
  token **while still authenticated**, then signs out. (Re-confirmed it awaits the
  Firestore write before `_signOut()`.)
- **Layer 2 — `claimFcmToken` (server, authoritative).** Unchanged — the source of
  truth for exclusive token ownership (reclaims a token from all other users the
  moment a new owner registers it; loop-safe).
- **Layer 3a — per-recipient push stamping (server).** Every push now carries
  `data.recipientUid` (the intended owner). `dispatchBroadcast` sends **one message
  per token via `messaging.sendEach`** (a multicast can't vary `data` per token),
  each stamped with `tokenOwner.get(token)`; `onNotificationCreated` (already
  per-recipient) stamps `recipientUid`.
- **Layer 3b — client drop-guard (the guarantee).** `NotificationService` now checks
  `data.recipientUid` against the signed-in `_uid` on **foreground** display and on
  **tap** (`_isForCurrentUser`); a mismatch is **dropped** (never shown/routed) and
  **self-heals** (`_handleMismatch` re-registers this device's token so
  `claimFcmToken` reclaims it). An absent stamp is allowed (back-compat). So even a
  drifted/stale token that receives a push cannot surface it to the wrong user.
- **Layer 3c — dispatch diagnostics.** `dispatchBroadcast` detects when the **same
  token is found on two different recipients in one send** (an ownership-drift
  signal), logs a `warn` (token suffix + the two uids), and reports `tokenDriftCount`
  in the dispatch summary — operational visibility into mismatches.
- **Documented residual:** for a **backgrounded/terminated** app, the OS renders the
  `notification` banner before app code runs, so the client guard can't suppress
  that banner for a (rare, short-lived) drifted token — but the **tap is guarded**
  (no wrong-content routing + self-heal) and foreground/in-app inbox are fully
  protected. Suppressing the background banner too would need data-only messages +
  local-notification rendering (a larger change, not in scope).

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
