# Schedule V2 — Locked Scope & Pillar Plan

**Status:** Scope locked, not yet built. Owner-approved direction: *"lock scope, then build pillar by pillar."*
**Branch:** `feature/schedule-optimization`
**Date:** 2026-07-09
**Supersedes nothing.** This is the contract for the Schedule V2 work. Build only what is IN scope here. Anything in the OUT list needs a fresh owner decision before it is touched.

---

## 0. How to read this

The original V2 brief was ~20 subsystems that add up to a full Workforce-Management platform (Deputy / WhenIWork / Homebase). This document is the **triage of that brief against DROP's own philosophy**, plus the pillar plan for the parts that survive.

Two rules govern every line below:

1. **Premium ≠ enterprise.** The parts that make Schedule *feel* premium are cheap and IN. The parts that make it an *enterprise WMS* are expensive, high-risk, built for a scale DROP doesn't have — OUT until a real need appears.
2. **Extend, don't rebuild.** Schedule is a mature ~13,500-LOC feature. Most of the brief is already partly built. Every pillar names the real files it grows from.

---

## 1. Guardrails (the philosophy this plan is bound by)

Pulled from standing owner rulings — these are non-negotiable framing, not aspirations:

- **Premium lean internal ops tool, NOT enterprise/SaaS.** Not Jira/Slack/Linear/Deputy. Small-user scale. Workflow > architecture. UX > feature-count. Default to deletion. Challenge complexity. No over-engineering.
- **Stability > perfection.** 90% + zero regressions beats 100% + risk. Classify every change (bug/polish/refactor/feature) and label risk (LOW/MED/HIGH).
- **Guard intentional / previously-debated UX.** Never replace a lived-in UI without sign-off. "Work on it more" = enrich, not simplify.
- **Monochrome.** Colour only for destructive / genuine status. No %/progress-bars, no staffing quotas, no purple/indigo (all previously reverted).

### Frozen surfaces this plan must NOT touch
- **Employee mobile "My Week"** (`my_schedule_screen.dart`, premium hero + week cards) — owner-FROZEN. In-language improvements only. **Schedule V2 is the manager/admin desktop+tablet surface.**
- The **advice-never-gate** stance of Schedule Health — findings are recommendations, never enforcement.

---

## 2. What already exists (do NOT rebuild)

| Brief asks for | Already shipped |
|---|---|
| #3 Configurable shift hours | `domain/shift_hours.dart` (`ShiftHours` value object, overnight-aware) + per-week `weekly_schedules/{id}.shiftHours` overrides. Hours are **data**, resolved by `WeeklyScheduleEntity.hoursFor(day, shift)`. |
| #5/#6 Scheduling engine + health score | `domain/schedule_health.dart` — pure, unit-tested `computeScheduleHealth` → 0–100 `score` + typed `HealthFinding`s (`shortRest`, `alternation`, `longStreak`, `unevenLoad`). |
| #10 Final view redesign + #20 image export | `pages/schedule_final_view.dart` — branded read-only roster **with real PNG export** (shipped 2026-07-05). |
| #4 Assignment chip (partial) | `widgets/assignment_chip.dart` — avatar, short name, desktop drag-to-move, chip-onto-chip **swap with live drop preview**, context menu, touch action sheet, conflict/caution dots. |
| #15 Conflict / move / swap validation | `domain/move_validation.dart`, `swap_validation.dart`, `swap_eligibility.dart`, `swap_policy.dart`. |
| #1 Responsive foundation | `core/responsive/breakpoints.dart` — 4 tiers (mobile/tablet/desktop/ultrawide), `sidebarWidth`/`sidebarCollapsedWidth` (collapse already modelled), `ResponsiveBuilder`, `ContentConstraint`, tier-aware `pagePadding`. |
| Desktop shell + ⌘K | `core/widgets/app_shell.dart`, `app_sidebar.dart`, `command_palette.dart`. |

**Current manager/admin surface** = the **Schedule 3.0 weekly grid** (`widgets/schedule_grid.dart` + `shift_cell.dart`): days as columns (Sun→Sat), Morning/Night rows, pinned rail, horizontal scroll on phone, individual draggable chips, insight-driven dimming. (The 2026-06 accordion was superseded by this grid; its anti-quota/monochrome ruling still holds in the code.)

---

## 3. Scope decision

### ✅ IN — genuine DROP-premium, high leverage

| # | Item | Lands in |
|---|---|---|
| 1 | Adaptive Mac vs iPad layout | Pillar 1 |
| 2 | Focus mode (collapse sidebar) | Pillar 1 |
| 4 | Assignment chip craft (bigger, position, initials, cross-day drag, keyboard move) | Pillar 2 |
| 6 | Health score **breakdown made clickable** (extend the existing engine) | Pillar 3 |
| 10 | Final view / export polish (mostly done) | Pillar 5 |
| 16 | Premium motion | Pillar 6 |
| 18 | Accessibility | Pillar 6 |

### 🟡 IN but bounded — the one worthwhile idea from the "enterprise" set

| # | Item | Why it survives | Lands in |
|---|---|---|---|
| 3 | **Named, reusable shift templates** with an explicit *"only this week / future / update template"* choice | Naturally bounded; builds directly on `shift_hours`; history-safe by construction. The single highest-value structural idea in the brief. | Pillar 4 |

### ❌ OUT — enterprise WMS bloat (contradicts standing rulings). Revisit only on the stated trigger.

| # | Item | Why out | Revisit trigger |
|---|---|---|---|
| 5/7 | 9-class isolated Rule-Engine + configurable policy engine | 4 finding kinds is not a "giant if-statement" problem. Abstraction cost > benefit. | Finding kinds grow past ~10 AND rules need per-branch config. |
| 8 | Full metadata audit trail (createdBy/updatedBy/reason/previousEmployee/source) | Jira-grade traceability the owner explicitly rejected on Requests. | A real dispute/accountability need appears. |
| 9 | Schedule history / snapshots / rollback / compare revisions | Versioning system for a handful of managers. | Managers actually ask to undo a *published* week. |
| — | Versioning (v1/v2/v3), draft-vs-published, shift locking | Enterprise workflow engine. | Employees see wrong in-progress edits AND that causes real confusion. |
| 11 | Excel keyboard interaction (arrow/tab/copy/paste/range/fill/undo/redo) | Huge surface, tiny payoff at this scale. | Managers build schedules for >50 people regularly. |
| 13/14 | Workload heatmaps + AI assignment suggestions | WMS analytics. Pillar 3 already surfaces *who's overloaded* via findings. | Explicit owner ask after Pillar 3 ships. |
| 17 | Background isolates / "hundreds of employees" | Premature — not DROP's scale. Memoized caching (Pillar 3) is enough. | Profiler shows real jank on a real branch. |
| 19 | Offline edit + pending-ops + conflict-resolution/merge | Distributed-systems complexity. Firestore offline persistence already covers reads. | Managers routinely edit on flaky connections AND lose edits. |
| 20 | PDF / Print / CSV / Excel export | PNG already ships. Format sprawl. | A concrete "I need CSV for payroll" request. |

**All ❌ items live in Pillar 7 (Reserve). They are parked, not planned.**

---

## 4. The 7 pillars

Each pillar states **Goal · Architecture · UX · Logic · Risk · Out-of-scope · Done-when**. Ordering = build order.

### Pillar 1 — Adaptive Shell (Mac vs iPad) + Focus Mode
- **Goal:** the manager/admin schedule stops feeling like a stretched phone. Mac = roomy, hover, floating inspector. iPad = touch, bottom sheets, Apple-Calendar feel.
- **Architecture:** extend `core/responsive/breakpoints.dart` (tiers + `sidebarCollapsedWidth` already exist). Inside `manager_schedule_view.dart`, branch layout on `context.deviceType`: desktop/ultrawide → `Row(grid | floating inspector panel)`; tablet → grid + bottom-sheet inspector. Focus Mode = a shell-level toggle that collapses `app_sidebar.dart`, bound to a keyboard shortcut via existing shortcut infra. Toolbar stays visible when collapsed.
- **UX:** wider gutters + larger grid + resizable/hover on Mac; larger tap targets + bottom sheets on iPad; shared design language; sidebar collapse toggle; ⌘-based toggle.
- **Logic:** none new. Pure layout + `focusMode` / `inspectorOpen` UI state. Use `BlocSelector` so toggling chrome never rebuilds the grid.
- **Risk:** **MED** (touches the shared shell). Guard: mobile employee My Week untouched.
- **Out-of-scope:** split-view multitasking beyond what the OS gives for free.
- **Done-when:** Mac shows inspector + collapsible sidebar; iPad shows bottom-sheet inspector; grid never rebuilds on chrome toggle; My Week unchanged.

**Increment status**
- **✅ 1a — Focus Mode (shipped 2026-07-09):** `app_shell.dart` now stateful; ⌘\ + a sidebar collapse control + a floating restore handle. Only the sidebar *width* animates (clip + `OverflowBox`), so the `Expanded(child)` shell Navigator is never remounted — guarded by `test/focus_mode_test.dart`. It is **app-wide** (collapsing the shell sidebar is global by nature; route-gating it to the schedule would be *more* code for less value). **Persistence is in-session only** — the app has no local-prefs store yet; cross-restart memory needs one small dependency (`shared_preferences`) and an owner OK. Reduced-motion + Semantics done here already.
- **✅ 1b — Adaptive layout (shipped 2026-07-09):** `manager_schedule_view.dart` splits on `context.isDesktop`. Desktop / iPad-landscape (≥1024) → `Row(grid hero | inspector rail)`; the rail docks the week totals + `ScheduleHealthCard` that used to sit *below* the grid. Touch widths keep the byte-identical stacked `ListView` + bottom-sheet detail. Presentation-only recomposition of existing widgets — insights/health computed once, every edit/validation/save path unchanged.
- **✅ Inspector drawer (shipped 2026-07-09, owner-directed):** the rail's empty lower area became a real drawer — extracted to `widgets/schedule_inspector_drawer.dart` (stateless, selection lifted → tests in isolation with no cubits). Overview + **team roster** → tap a person → **week detail** (hours from resolved `ShiftHours`, morning/night/weekend split, consecutive-day streak, days off, Sun→Sat glance, wellbeing flags from `health.findings`). Backed by pure `domain/employee_week_stats.dart`. This is the lean read-only slice of brief #12 (metadata panel) — no per-employee analytics engine, no persistence. Tests: `schedule_inspector_drawer_test.dart` (4) + `employee_week_stats_test.dart` (3).

**Pillar 1 is complete.** Next: Pillar 2 (Assignment Craft).

> **TODO (deferred, owner decision):** Focus Mode persistence across a cold launch. Needs a local-prefs store the app lacks (`shared_preferences`, one std dep). Left as in-session-only until we decide to add it — do not implement without an explicit GO.

### Pillar 2 — Assignment Craft ✅ (shipped 2026-07-09)
- **Goal:** the chip is the atom of the schedule — make it richer and easier to move.
- **Architecture:** enriched `widgets/assignment_chip.dart` (already avatar + drag + swap-drop + preview) — no scheduling-architecture change. Threaded a keyboard-move callback `assignment_chip → shift_cell → schedule_grid`, where it maps straight onto the existing `onMoveChip`.
- **What shipped:**
  - **Premium chip:** avatar 17→18, initials fallback via `UserAvatar` (already existed), `user.position` trails the name (single-line, ellipsizes first so it never outgrows the 140px cell). Desktop hover tooltip = full name + position; touch tooltip unchanged.
  - **Bigger target + lift:** roomier padding; soft shadow on hover / focus.
  - **Cross-day drag:** was *already* routed through `MoveValidation` (the `ShiftCell` DragTarget was never same-day-restricted) — now test-locked.
  - **Keyboard move (desktop):** `Focus` + arrow keys (←/→ days same shift, ↑/↓ Morning↔Night) → same `onMoveChip` → `MoveValidation` → same Firestore write. Edges are a consumed no-op. Focus ring on the chip.
  - **Motion:** one-shot scale-in on placement; chips keyed by uid so a person who stays put never re-animates; scale-only (stays hit-testable); reduce-motion aware.
  - **Touch unchanged:** drag/keyboard/focus desktop-gated; long-press → action sheet (test-locked).
- **Logic:** all legality via `move_validation.dart` — **no new persistence, no new write path** (verified).
- **Risk:** LOW–MED, realised LOW (isolated widget + validation reuse).
- **Tests:** `test/assignment_chip_interactions_test.dart` (6). Regression: 60 pass, analyze clean.
- **Explicitly NOT built (per constraints):** bulk/range selection, Excel keys, AI, quotas, audit — none touched.

**Pillar 2 is complete.** Next: Pillar 3 (Health, Made Legible).

### Pillar 3 — Health, Made Legible
- **Goal:** turn the existing 0–100 score into a clickable breakdown that drills into the exact cells.
- **Architecture:** keep `domain/schedule_health.dart`. Do **not** rebuild into 9 rule classes. Add derived per-category subscores (Coverage / Fairness / Rest / Conflicts / Workload) computed from the existing findings. Extend `widgets/schedule_health_card.dart` to render the breakdown; each category taps through to highlight affected cells by reusing the existing insight-highlight path (`schedule_insights.dart` + the grid's `activeInsight` dimming).
- **UX:** Overall Health % + label (exists) → tap a category → grid lights the offending slots, dims the rest.
- **Logic:** subscores are pure/derived. Memoize `computeScheduleHealth` per schedule identity so rebuilds don't recompute. Advice-never-gate stays.
- **Risk:** **LOW.**
- **Out-of-scope:** heatmaps, AI fixes, one-click auto-fix (❌ #13/#14).
- **Done-when:** breakdown renders; each category drills to cells; no recompute on unrelated rebuilds.

### Pillar 4 — Shift Templates (the bounded 🟡)
- **Goal:** named, reusable shift-hour templates (e.g. Morning 08:30→16:30, Weekday Night 15:00→23:00) with an explicit change scope. **Never silently overwrite historical schedules.**
- **Architecture:** build on `shift_hours.dart`. Introduce a small template store (named `{label, morningHours, nightHours}`). When hours are edited, present three choices: **① Only this week** (writes the existing per-week `shiftHours` override — `ScheduleCubit.setShiftHours`), **② Future schedules** (updates the template; unpublished/future weeks resolve it at build time), **③ Update template globally**. Historical / already-resolved weeks keep their frozen `shiftHours` snapshot regardless.
- **UX:** template picker in the day-hours editor; a 3-way radio on save (mirrors the brief's mock exactly).
- **Logic:** resolution order per cell = frozen per-week override → referenced template → standard default. History-safety is structural: past weeks always carry their own snapshot.
- **Risk:** **MED–HIGH** — this is the only pillar that changes the data model + resolution rules. **Requires its own mini-design + unit tests before code, and an explicit owner GO.**
- **Out-of-scope:** versioning of templates, template audit trail (❌).
- **Done-when:** templates are named + reusable; the 3-way scope choice works; a template edit provably never mutates a historical week (test-guarded).

### Pillar 5 — Final View & Export Polish
- **Goal:** tighten the already-shipped Final View toward a "premium branded Excel sheet."
- **Architecture:** `pages/schedule_final_view.dart` already = branded read-only roster + PNG export. Refine typography/contrast; columns Employee · Mon–Sun · Notes; cell tokens M / N / OFF / Leave / Vacation. Keep PNG; add PDF **only if** trivial via the existing capture→print path.
- **UX:** pure presentation — no builder / health / assignment controls (already the rule).
- **Logic:** none new. Format only.
- **Risk:** **LOW.**
- **Out-of-scope:** CSV/Excel (❌ #20).
- **Done-when:** roster reads as an export-quality sheet; PNG intact.

### Pillar 6 — Motion & Accessibility
- **Goal:** subtle Apple-philosophy motion + a11y pass across the new surfaces.
- **Architecture:** apply the Design-System-V2 core standards (Semantics, ≥44px targets, reduced-motion) to Pillars 1–5. Subtle fade/slide/scale on chip insert, inspector open, health drill.
- **UX:** subtle only — no flashy effects.
- **Logic:** none.
- **Risk:** **LOW.**
- **Done-when:** reduced-motion respected; screen-reader labels on chips/inspector/health; targets ≥44px.

### Pillar 7 — Reserve (explicitly deferred)
Everything in §3 ❌. **Not built.** Each carries a revisit trigger in the table above. Do not start any of these without a fresh owner decision.

---

## 5. Sequencing & dependencies

```
1 Adaptive Shell ──► 2 Assignment Craft ──► 3 Health Legible ──► 5 Final View ──► 6 Motion/A11y
                                                                   ▲
                          4 Shift Templates (own mini-design + GO) ┘  (gated, parallel-able after 1)
```

- **1 → 2 → 3** is the core sequence; each is independently shippable and low/med risk.
- **4** is gated behind its own design + owner GO because it alone touches the data model.
- **5, 6** are polish; run last (6 sweeps everything built before it).
- **7** stays parked.

---

## 6. Change classification (per working rules)

| Pillar | Class | Risk |
|---|---|---|
| 1 Adaptive Shell + Focus | feature + refactor | MED |
| 2 Assignment Craft | polish + feature | LOW–MED |
| 3 Health Legible | feature (presentation over existing logic) | LOW |
| 4 Shift Templates | feature (data model) | MED–HIGH |
| 5 Final View polish | polish | LOW |
| 6 Motion / A11y | polish | LOW |

---

## 7. Open questions to resolve at each pillar's kickoff
- **P1:** Is Focus Mode global (all screens) or schedule-only? Recommend schedule-first, generalise if it lands well.
- **P4:** Where do templates live — a dedicated `shift_templates` collection, or a field on branch settings? (Decide at P4 design.) Are templates global or per-branch?
- **P5:** Is PDF actually wanted, or is PNG enough? (Default: PNG only unless asked.)
