# DROP — Sprint 2: Render Performance & Rebuild Audit

> **`core/optimization`** · **Date:** 2026-07-08 · **Role:** Lead Flutter Performance Engineer
> **Mandate:** reduce unnecessary rebuilds & rendering work — **pixel-perfect, zero behavior/UX/feature/backend change.**
> **Companion:** [`PERFORMANCE_BASELINE.md`](PERFORMANCE_BASELINE.md) §2/§5 (rebuild-scoping baseline)

---

## 0. Verification constraint (read first)

Live pixel verification (running the app + DevTools "Track Widget Rebuilds") is **blocked this session** — the profile build fails on macOS code-signing and the 6 target screens need an authenticated session (documented in Phase 0.2). That materially shapes what I **implement** vs. **recommend**:

- **Implemented** = only changes that are **behavior-identical by construction** and fully verifiable by analyzer + the 597-test suite (i.e. `const`). `dart fix` only adds `const` where the expression is a *guaranteed compile-time constant*, so there is no way for it to change a pixel.
- **Recommended (not implemented)** = `BlocSelector`/`buildWhen`, list virtualization, `child:` hoisting. These are real wins, but a too-narrow `buildWhen`/selector causes a **silent stale-UI regression** that only a running app reveals. Implementing them blind would violate this sprint's #1 rule (*zero UI regressions*) and the project's *stability > perfection* ruling. Each is documented with the exact slice to select and an estimated rebuild reduction, ready to implement the moment live verification is available.

This is the honest senior-engineer split: ship the provable win now; stage the runtime-verifiable wins with precise instructions.

---

## Step 1 — Build/Rebuild audit (Bloc primitives)

**Whole-`lib` census:**

| Primitive | Count | Reading |
|---|---|---|
| `BlocBuilder<>` | 41 | Broad rebuild surfaces |
| `BlocConsumer<>` | 15 | builder + listener combined |
| `BlocListener<>` | 10 | side-effects only (no rebuild) |
| **`BlocSelector<>`** | **2** | fine-grained rebuild — barely used |
| **`buildWhen`** | **0** | ⚠️ no `BlocBuilder` gates its rebuilds |
| `listenWhen` | 3 | |
| `context.select` | 1 | |
| `context.watch` | 4 | |

**Per-file `BlocBuilder`+`BlocConsumer` hotspots:**

| File | count | Notes |
|---|---|---|
| `manager_schedule_view.dart` | 4 | 🔒 schedule UI frozen (memory) |
| `branch_operations_screen.dart` | 3 | operations cockpit |
| `employee_home_screen.dart` | 3 | 🔒 premium home, frozen |
| `admin_dashboard_screen.dart` | 3 | **already uses 2 `BlocSelector`** — the model to copy |
| `my_schedule_screen.dart` | 2 | 🔒 frozen |
| `swap_view.dart`, `profile_page.dart`, `operations_metric_screen.dart`, `notifications_screen.dart`, `cases_screen.dart` | 2 each | |

**Assessment:** the dominant anti-pattern is a large tree wrapped in one `BlocBuilder<Cubit, FreezedUnionState>` with **no `buildWhen`**, so *any* state field change rebuilds the whole subtree. `admin_dashboard` is the counter-example that already does it right (`BlocSelector` for the header counters). This is the biggest *structural* rebuild win — but see §0: it needs runtime verification and several targets are UI-frozen.

---

## Step 2 — Widget extraction audit

Screens > 300 LOC (large `build()` = large rebuild surface): `employee_home` 1941 🔒, `my_schedule` 1722 🔒, `task_details` 1422, `admin_dashboard` 1196, `compose_broadcast` 1159, `admin_task_overview` 776, `branch_operations` 671, `my_tasks` 649, `edit_profile` 596, `communications` 581, `operations_metric` 575, `request_detail` 543, `broadcast_templates` 532, `employee_management` 509, `pending_review` 496.

Widgets > 250 LOC: `manager_schedule_view` 1131 🔒, `swap_view` 932, `work_type_panel` 905, `activity_timeline` 773, `task_feed_section` 706, `task_feed_expansion` 667, `task_card` 664, `dynamic_work_form` 652, `task_template_sheets` 610, `admin_user_sheets` 597, `chip_action_sheet` 586, `day_details_sheet` 551.

**Assessment:** the sprint rule is *"extract only when it reduces rebuild scope; do NOT extract for clean-code."* Most of these are large because the *design* is rich (premium cards, timelines), not because a rebuild-hot subtree is inlined. The genuine extraction-for-rebuild wins overlap 1:1 with the `BlocSelector` targets in Step 8 (extract the state-dependent header/badge so the static body stops rebuilding). Standalone extraction with no rebuild benefit is **explicitly declined** per the rules.

---

## Step 3 — Const audit ✅ (IMPLEMENTED — see Phase A)

The project includes only `flutter_lints/flutter.yaml`, which **does not enable** `prefer_const_constructors`, `prefer_const_literals_to_create_immutables`, or `prefer_const_declarations`. Temporarily enabling them surfaced:

| Lint | Missing sites |
|---|---|
| `prefer_const_constructors` | **159** |
| `prefer_const_literals_to_create_immutables` | **14** |
| `prefer_const_declarations` | **1** |
| **Total** | **174** |

Spread across task sheets, work-type panels, schedule widgets, dashboards, etc. Every one is a `SizedBox`/`Padding`/`Text`/`Icon`/`EdgeInsets`/`Divider`/`Duration`/`BorderRadius` (exactly the sprint's examples) whose arguments are already compile-time constants. **Benefit:** a `const` widget is canonicalized once and its element **short-circuits rebuild** (`Widget.canUpdate` + identical instance) — it is skipped on every parent rebuild, and allocates zero garbage per build. **This is the safe, measurable, fully-verifiable win → implemented in Phase A.**

---

## Step 4 — List rendering audit

| Pattern | Count |
|---|---|
| `ListView.builder` (lazy) | 10 |
| `ListView.separated` (lazy) | 4 |
| `ListView(children:[…])` (eager) | 76 |
| `shrinkWrap: true` | 14 |
| `NeverScrollableScrollPhysics` | 1 |
| `CustomScrollView` / Slivers | 0 / 1 |

**Assessment:** the high-traffic feeds (`task_feed_section`, `notifications`, `my_tasks`, `cases`, `requests`) render eagerly (plain `ListView`/`SingleChildScrollView`). For **small bounded** lists that is correct and cheaper than a viewport (no scroll-offset machinery). It only bites when a feed is backed by an **unbounded stream** — which is exactly the deferred pagination work in the [Firestore audit](FIRESTORE_QUERY_AUDIT.md) (P1–P6). **Converting plain→`.builder` changes scroll/extent behavior and must be verified live**, and pairs naturally with pagination — so it is **recommended, deferred**, not done blind here. `shrinkWrap+NeverScrollable` nested lists (14) are the standard "inner list inside an outer scroll" idiom and are bounded — leave.

---

## Step 5 — Heavy widget audit

| Widget | Count | Verdict |
|---|---|---|
| `CustomPaint` | 7 | ✅ Justified — incl. `LiveStatusBorder` orbit (**load-bearing, memory-frozen — do NOT touch**), splash, progress rings |
| `ClipRRect` | 15 | ✅ Justified — rounded media/cards; cheap |
| `LayoutBuilder` | 13 | ✅ Responsive breakpoints; each gates real layout branching |
| `AnimatedBuilder` | 12 | ✅ mostly correct; a few `child:`-hoist candidates (Step 7) |
| `Opacity` | 19 files | ⚠️ mostly animated/drag ghosts; a static `Opacity` with a constant value could be a color-alpha instead, but the difference is negligible — leave |
| `AnimatedOpacity` | 6 | ✅ Justified |
| `IntrinsicHeight` | 5 | ⚠️ The one real "extra layout pass" smell — but each is for equal-height rows (intentional). Review only with live layout profiling; **not touched**. |
| `ShaderMask` | 2 | ✅ splash light-sweep / logo |
| `BackdropFilter`, `ClipPath`, `IntrinsicWidth` | 0 | — |

**Assessment:** nothing here is unjustified enough to remove **without proving it via a layout/raster profile** (which is blocked). No removals — the sprint rule is *"do NOT remove anything until proven unnecessary."*

---

## Step 6 — Image audit

| Item | Count |
|---|---|
| `Image.network` | 13 (branch banners/logos, avatars) |
| `Image.asset` | 1 |
| `CachedNetworkImage` / cache manager | **0** |

**Assessment:** Flutter's in-memory `ImageCache` applies, but there is **no persistent disk cache**, so branch/avatar images re-download & re-decode across sessions (baseline finding R2). Fixing it means adding a caching image widget/dependency — borderline against *"no feature/backend change"* and needs a visual pass to confirm identical rendering. **Recommended, deferred.** No oversized bundled assets found (only 1 `Image.asset`; Lottie for splash).

---

## Step 7 — Animation audit

| Widget | Count |
|---|---|
| `AnimationController` | 32 |
| `AnimatedContainer` | 29 |
| `TweenAnimationBuilder` | 10 |
| `AnimatedBuilder` | 12 |
| `AnimatedSwitcher` | 3 |

**Assessment:** animation usage is disciplined (controllers dispose; `task_feed_section` already passes a `child:` through its `TweenAnimationBuilder` — the correct pattern). The safe, measurable opportunity is **`child:` hoisting**: any `AnimatedBuilder`/`TweenAnimationBuilder` whose closure rebuilds a subtree that does **not** read the animation value should pass that subtree as `child:` so it is built once and reused every frame. There are a handful of candidates among the 12 `AnimatedBuilder` sites. This is **behavior-identical** (the `child` is passed straight through) — but each requires reading the closure to confirm the subtree is animation-independent, and the per-site win is small. **Recommended; a follow-up `child:`-hoist pass** (safe to do without live verification, but low individual ROI — batched carefully it's worth a dedicated pass).

---

## Step 8 — Render-tree audit (per target screen)

For each screen the sprint named, the concrete `BlocSelector`/`buildWhen` fix and its estimated rebuild reduction. **All recommended, none implemented blind** (§0).

| Screen | Current | Fix | Est. rebuild reduction |
|---|---|---|---|
| **Notifications** | 2 `BlocBuilder` over the full notification state; the unread-count header + category pills rebuild on every list tick | `BlocSelector` for the unread count & selected-category; keep the list in its own builder | Header/pills stop rebuilding on list-item changes (~every stream tick → only on count/filter change) |
| **Cases** | `BlocBuilder` wraps inbox + header | `BlocSelector` for the section counts; list keeps its builder | Counts rebuild only when a count changes |
| **Requests** | same shape as Cases | same | same |
| **Dashboard (admin)** | **already** uses 2 `BlocSelector` ✅ | none — reference implementation | — |
| **Statistics** | `BlocBuilder` over stats union | `buildWhen` on the loaded→loaded transitions; `BlocSelector` per KPI tile | Each KPI tile rebuilds only when its number changes |
| **Home (employee)** 🔒 | 3 `BlocBuilder`, premium/frozen | `buildWhen` on the hero counts **only after live sign-off** | Deferred — frozen UI, highest regression risk |
| **Tasks / feed** | `BlocBuilder` rebuilds feed on stream tick | correct — the list *did* change; `BlocSelector` only for the toolbar counts | Toolbar counts stop rebuilding with the list |
| **Profile** | 2 `BlocBuilder` | `BlocSelector` for avatar/name vs. the rest | Small |

**Pattern:** wrap the *scalar-derived* chrome (counts, badges, filter state) in `BlocSelector`; leave the list body in its `BlocBuilder`. Never widen a `buildWhen` you can't prove complete. Do **not** touch the 🔒 frozen screens without sign-off.

---

## Prioritized plan

| Phase | Optimization | Risk | Verifiable now? | Status |
|---|---|---|---|---|
| **A** | `const` pass (174 sites) | **None** (compile-time constant) | ✅ analyzer + tests | ✅ **Implemented** |
| B | `child:` hoisting on animation builders | Low (child passthrough) | ✅ per-site read | 🔸 Recommended (dedicated pass) |
| C | `BlocSelector` for scalar chrome on Notifications/Cases/Requests/Statistics/Profile | Medium (stale-UI if slice incomplete) | ❌ needs live rebuild-count verify | 🔸 Recommended |
| D | plain `ListView`→`.builder` on paginated feeds | Medium (scroll/extent) | ❌ needs live verify + pairs w/ pagination | 🔸 Deferred (with Firestore P1–P6) |
| E | persistent image cache | Low–Med (dependency) | ❌ visual pass | 🔸 Deferred |
| — | Home/Schedule 🔒 rebuild scoping | High (frozen UI) | ❌ | 🚫 Not without owner sign-off |

**Bottom line:** Phase A is the measurable, zero-risk win shipped this sprint. B–E are staged with exact instructions and estimates, gated on the live verification that is currently blocked — deliberately *not* implemented blind, per *zero UI regressions* + *stability > perfection*.

---

*Audited by static inspection on `core/optimization` @ 2026-07-08. Only Phase A (const) was implemented; all rebuild-scope changes are documented recommendations pending live pixel/rebuild verification.*
