# DROP Design System V2 — Foundation

> The inheritance contract for every DROP surface. Phase 1 established this while
> redesigning the Admin dashboard; Branches, Requests, Cases, Communications,
> Inventory, Analytics and every future module compose the **same** primitives so
> the product reads as one system.

## Philosophy — calm through hierarchy

The dashboard answers one question: **"what needs my attention right now?"** — not
"here is every row in the database." The fix for visual competition is **ranking,
spacing and grouping**, never removing richness. Keep the crafted DROP identity
(glass surfaces, living-border motion, rich metrics, monochrome + single accent).
The goal is **premium**, not minimal. Do **not** flatten into a generic
Linear/Jira/Notion clone.

### Progressive disclosure (the layer ladder)

Every module home is arranged as layers, top to bottom:

1. **L1 — Needs attention.** The dominant layer: the few things that require a
   decision now (pending review · overdue · unassigned · rejected · swaps).
2. **L2 — Today's health.** Light supporting metrics (completed today · running ·
   delayed · approval rate). No charts.
3. **L3 — Recent activity.** A clean vertical feed of what's happening.
4. **L4 — Deep navigation.** Quick actions, module directory, pulses.

## Tokens (already canonical — reuse, don't redeclare)

| Concern | Source |
| --- | --- |
| Spacing | `AppSpacing` (`xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · xxxl 48`) |
| Radius | `AppRadius` (`card 20 · button 18 · full 999`, + `*All` `BorderRadius`) |
| Colour | `AppColors` — **strictly monochrome**; `accent`/`primary` = white; semantic `success`/`warning`/`error` **only for status**, used sparingly |
| Type | `AppTypography` (`display · h1 28 · h2 · h3 18 · labelLarge · label · labelSmall · caption`) |

### Text hierarchy — a 4-step ramp (2026-07-09)

Rank importance with **brightness before colour**. The neutral ladder is four
clearly-separated steps, each visibly darker than the last — no two share a
brightness, so a title never competes with its supporting line. Reach for the
faintest level that still reads; **never place two adjacent text elements on the
same grey** (a label and its value, a title and its subtitle must step apart).

| Level | Token | Hex | Use |
| --- | --- | --- | --- |
| White | `textPrimary` | `#FFFFFF` | page/task titles · primary values & important metrics · the thing the eye should hit first |
| Light grey | `textSecondary` | `#A7A7AF` | section subtitles · secondary info · **assignee / branch names** · supporting + metric labels |
| Medium grey | `textTertiary` | `#6E6E77` | metadata · **relative timestamps** · helper text · sublabels · eyebrows/kickers · contextual notes |
| Dark grey | `textQuaternary` | `#48484E` | disabled / inactive · **placeholders** · decorative meta · zero-state numbers |

The canonical pattern for a metric cell is a clean 3-step ramp — **white value →
light-grey label → medium-grey sublabel** (`AttentionTile`, `StatStrip`, digest
rows all follow it). A field is **light-grey label → white value → dark-grey
placeholder** (the placeholder only shows when empty, so it never sits beside the
value).

## Surfaces & cards

- **`GlassContainer`** — the one premium surface (gradient + hairline border + soft
  depth). `onTap` for press/hover feedback; `highlight`+`accent` to flag "act on
  this"; `glow` for a subtle status halo; `elevated:false` for a flat inset tile.
  On **desktop hover** a tappable card gently **elevates** (−2px lift + deeper
  shadow + warmed border; a flat tile picks up a soft hover shadow) — pointer
  feedback is on by default, honours reduced motion. Don't re-roll hover per card.
- **`AppGlassCard`** — status-glow card wrapper over `GlassContainer`.
- Never re-declare the card `BoxDecoration` — compose `GlassContainer`.
- **Date/time pickers** are themed monochrome (`DatePickerTheme`/`TimePickerTheme`
  in `AppTheme.dark`) — never drop a raw Material picker; the app theme dresses it.

## CTA hierarchy (one primary per screen)

| Tier | Component | Use |
| --- | --- | --- |
| **Primary** | the hero's filled monochrome CTA (`_PrimaryCta` pattern — white fill, dark label) — **exactly one per screen** | the single action the screen exists to drive (e.g. *Create Task*) |
| **Secondary** | `PremiumButton` | inline card actions |
| **Tertiary** | `ActionCard` (vertical) / `ActionCard(secondary:true)` (horizontal) / text buttons | quick actions + module directory |

## V2 primitives (`lib/core/widgets/`)

Generic + module-agnostic — entity mapping stays in features. **Every primitive:**
a `Semantics` label, ≥44px targets, text-scale-safe layout, honours reduced motion
(`MediaQuery.disableAnimations`), and lazy/`.builder` + capped visible count for any
collection (safe at 100 branches / 5,000 employees / multi-tenant).

- **`PageHero`** — eyebrow · title (`h1`) · subtitle · one `primaryAction` · quiet
  `trailing`. The header lockup of every module surface. Stacks the CTA full-width
  on narrow widths.
- **`AttentionTile`** — a priority triage cell: soft-accent glyph · big
  `AnimatedCount` · label · optional sublabel · `onTap`. Stays monochrome at zero,
  tints only when there's work. `AttentionTile.radius` is exposed so a feature can
  wrap the single most-urgent tile in `LiveStatusBorder` (the primitive itself does
  **not** depend on the task feature).
- **`StatStrip` / `Stat`** — a quiet single-`GlassContainer` row of `value/label`
  facts (the "Today" layer). Divided row when it fits, 2-up wrap when it doesn't.
- **`ActivityCard`** — a clean vertical feed row (`leading · title · subtitle ……
  trailing · meta`). The V2 replacement for the horizontal "spreadsheet" feed;
  generic slots, feature code maps its entity onto them.

## Navigation — preview, never lose context

**Pattern:** tap → **preview sheet** → optional **full details** → back to exactly
where you were (scroll + state preserved).

- Tasks: `showTaskPreviewSheet(context, task:, directory:)` opens a draggable
  preview with quick actions; "Open full details" → `openTaskDetails(...)` (a local
  `Navigator.push`, so the dashboard stays mounted underneath).
- Filtered drills: push a small reusable screen (e.g. `FilteredTasksScreen(title:,
  filter:)`) on the caller's navigator — **never** a route swap that loses the
  dashboard.
- Put a `PageStorageKey` on the dashboard scroll view; use `push` (never `go`) for
  drills, so scroll offset + filters survive round-trips.

## Live & reactive

Surfaces update themselves. Each section is a scoped `BlocSelector` over the live
streams (task stream · statistics · shift swaps · requests · cases), so a stream
emit rebuilds **only** the section whose number moved. Manual refresh (a "Sync"
control) is a quiet escape hatch — **never** the update mechanism.

## States

- **Empty:** `DropEmptyState` / `AppEmptyState` (branded / routine). ⚠️ Only as a
  **direct `RefreshIndicator`/body child** (bounded height). Inside an unbounded
  `ListView`, use a compact inline empty (see `RecentActivityFeed._AllClear`) — a
  full-bleed empty forces an infinite-height layout.
- **Zero ≠ empty.** A zero value is a *healthy* state, not a switched-off one —
  reward it. An `AttentionTile` at zero shows a check + a reassuring line
  (`clearedMessage`: "No overdue tasks") instead of a bare "0"; an empty feed reads
  "All clear / everything is handled", not "no data". Never leave a lone grey "0".
- **Loading:** `DropLoadingState` (full page) / structure-suggesting **skeleton
  rows** shaped like the real content (`Skeleton`), not a bare spinner, for an
  inline list.

## Living system (the dashboard is never static)

Even at zero work the surface should feel alive and under control. Two devices:

- **Contextual mood** (`dashboard_mood.dart`): the hero subtitle reads the live
  operational state ("2 tasks need your attention" / "Everything's running
  smoothly" / "Quiet morning"), escalating calm → attention → busy, rather than a
  static greeting. Derive it from counts you already have; keep it a pure function.
- **A "live" pulse:** a small breathing dot (a slow expanding ring) says the system
  is awake. Its colour is *meaningful* (calm vs attention), never decoration.
- **Depth over colour:** build layering with a **two-layer shadow** (tight contact +
  soft ambient) on `GlassContainer`, not with tint. The eye should know what's near
  and what's background without any new hue.

## Motion

Motion **communicates**, never decorates — animate entrance (`EntranceFade` +
`staggerDelay`), metric changes (`AnimatedCount` count-up, or an `AnimatedSwitcher`
cross-fade for a formatted value like `96%`), hover elevation (`GlassContainer`),
button press-scale, previews, and state changes only. Live feed rows use
`LiveListItem` (keyed reuse ⇒ only a genuinely new row animates in — natural
inserts, settled rows stay put). **Gate every animation on reduced motion**
(`MediaQuery.disableAnimations`) — provide a static fallback, don't just shorten
the duration. `LiveStatusBorder` is reserved for the single most-urgent actionable
signal on a surface — its motion/colours are frozen; don't modify it.
