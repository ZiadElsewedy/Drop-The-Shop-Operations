# DROP — Performance Baseline

> **Phase:** 0.1 — Performance Baseline (`core/optimization` branch)
> **Date:** 2026-07-08 · **Type:** Measurement only — **no optimization, no refactor, no architecture change**
> **Scope:** `lib/` (427 Dart files / 94,923 LOC) + startup path + Firestore access + architecture metrics
> **Companion:** [`PERFORMANCE_BASELINE_ACTIONS.md`](PERFORMANCE_BASELINE_ACTIONS.md) (prioritized action list — do **not** implement in this phase)

---

## 0. How to read this document

This is a **baseline**, not an audit and not a plan. Every number here is a *current-state measurement* with the evidence that produced it, so that any future optimization can be judged against a fixed reference point.

Two classes of measurement appear:

| Class | Symbol | How captured | Trust |
|---|---|---|---|
| **Static** | 📐 | Direct source inspection (`grep`/`wc`/file reads) on the working tree at commit on `core/optimization` | Exact, reproducible now |
| **Runtime** | ⏱ | Requires a device/simulator profiling run with a signed-in account | **NOT captured in this session** — protocol in §1.4 |

**Honesty note.** This session ran static analysis only. No cold-start ms, memory MB, CPU %, or FPS figures are invented. Where a runtime number is required, the row reads **`NOT CAPTURED`** and §1.4 gives the exact command to capture it. Two startup segments are *already* instrumented in the app (`AppLog.time`) and will print to the debug console on any cold start — those are called out as "free to capture."

Severity legend: 🔴 Critical · 🟠 High · 🟡 Medium · 🟢 Low / healthy.

---

## 1. Startup performance

### 1.1 Cold-start sequence (📐 measured from `lib/main.dart`)

The app uses a **cold-start rendezvous**: a native-matching black/Lottie intro (`SplashPage`) paints on the first frame; the routed app is mounted only when **both** the intro animation has finished **and** bootstrap has completed (`_canEnterApp = _animationFinished && _readyRouter != null`, `main.dart:85`).

Awaited critical path inside `_initializeRuntime()` (`main.dart:140`):

| Step | Operation | Awaited? | Cost driver | Instrumented? |
|---|---|---|---|---|
| 1 | `Firebase.initializeApp` | ✅ await | Native Firebase init | ✅ `AppLog.time('boot','Firebase.initializeApp')` `main.dart:142` |
| 2 | `FirebaseFirestore.settings` (persistence + `CACHE_SIZE_UNLIMITED`) | sync | negligible | — |
| 3 | `AppDependencies.init()` | sync | **constructs 15 cubits + 13 repositories + 14 datasources eagerly** (§1.2) | ❌ not timed |
| 4 | `UsageTracker.init` | sync | negligible | — |
| 5 | `authCubit.restoreSession()` | ✅ await | Firebase Auth + `users/{uid}` read | ✅ `AppLog.time('auth','restoreSession')` `main.dart:163` |
| 6 | `Future.wait([statisticsCubit.load, taskCubit.load, branchCubit.loadIfNeeded])` **(authed users only)** | ✅ await | **3 Firestore round-trips gate time-to-interactive** (§1.5) | ❌ not timed |
| 7 | `createRouter(...)` | sync | negligible | — |

**Key structural facts:**
- Steps 1, 5, 6 are `await`ed **before the router is returned**, so the routed first frame does not appear until home-critical data has loaded. This is a deliberate "no empty flash" design, but it means **TTI is gated on Firestore latency**, which grows with collection size (§4, unbounded reads).
- `runApp(const LaunchApp())` fires immediately in `_bootstrap()` (`main.dart:63`), so **time-to-first-frame is decoupled** from Firebase/DI — the intro paints first.

### 1.2 DI construction cost at startup (📐)

`AppDependencies.init()` (`injection.dart:184`) builds **everything eagerly** as `static late final`:

| Constructed at startup | Count |
|---|---|
| Singleton cubits (`BlocProvider.value` in `main.dart:317`) | **15** |
| Repositories | 13 |
| Remote datasources | 14 |
| Use cases | ~30 (inline) |

Every role pays for every module: an employee who never opens the admin area still constructs `adminUsersCubit`, `broadcastScheduleCubit`, `statisticsRepository`, etc. Construction is pure (no I/O), so the cost is **allocation + a longer synchronous `init()`**, not network — but it is baseline resident memory that never releases (no scoping).

### 1.3 Warm start / re-entry (📐)

Re-entry is **idempotent and cheap**:
- `if (Firebase.apps.isEmpty)` guards re-init (`main.dart:141`).
- `_dependenciesInitialized` guards `init()` (`main.dart:151`).
- `_router ??= createRouter(...)` caches the router (`main.dart:183`).
- `taskCubit.load()` early-returns if the scope is unchanged and already subscribed (`task_cubit.dart:136`).

A warm start (process alive, returning from background) skips steps 1, 3, 4 and re-runs only session/warm-up. **No warm-start regression risk observed statically.**

### 1.4 ⏱ Runtime startup numbers — NOT CAPTURED (capture protocol)

| Metric | Value | Capture method |
|---|---|---|
| Cold start (process → first frame) | `NOT CAPTURED` | `flutter run --profile --trace-startup` → reads `build/start_up_info.json` |
| Time to first frame (`timeToFirstFrameMicros`) | `NOT CAPTURED` | same `start_up_info.json` |
| First frame rasterized (`timeToFirstFrameRasterizedMicros`) | `NOT CAPTURED` | same |
| Framework init (`timeToFrameworkInitMicros`) | `NOT CAPTURED` | same |
| Time to interactive (routed home usable) | `NOT CAPTURED` | DevTools Timeline: mark from launch to last home-warm-up frame; or add a one-line `AppLog.time` around step 6 |
| `Firebase.initializeApp` ms | **FREE** | already logged — read debug console (`boot ⏱ Firebase.initializeApp …ms`) |
| `restoreSession` ms | **FREE** | already logged — read debug console (`auth ⏱ restoreSession …ms`) |
| Warm start | `NOT CAPTURED` | `--trace-startup` after backgrounding |

> **Reproducible baseline command (run on a physical device, release-representative profile build, signed-in account):**
> ```
> flutter run --profile --trace-startup -d <deviceId>
> # then read build/start_up_info.json
> ```
> Capture 5 runs, report median. Do this **before** any Phase-1 optimization so deltas are attributable.

### 1.5 Startup findings

| # | Finding | Severity | Evidence | Recommended future action (do NOT implement now) |
|---|---|---|---|---|
| S1 | **TTI gated on `Future.wait` of home-critical Firestore reads** — routed frame waits on `statisticsCubit.load` + `taskCubit.load` + `branchCubit.loadIfNeeded`; `taskCubit.load` first emission scales with an **unbounded** `tasks` query (§4). | 🟠 High | `main.dart:176-181`; `task_remote_datasource.dart:134-146` | Bound the task stream (`.limit`) so first emission is O(page), not O(collection); consider rendering home shell before the stream resolves. |
| S2 | **15 eager singleton cubits** constructed for every role at startup. | 🟡 Medium | `injection.dart:184-395`; `main.dart:317-334` | Lazy-construct leaf cubits (admin/comms/statistics) behind getters; keep eager the home-critical few. |
| S3 | **Step 6 not timed** — the single most data-dependent startup segment has no instrumentation. | 🟡 Medium | `main.dart:163` times steps 1 & 5 but not 6 | Wrap step 6 in `AppLog.time('boot','home-warmup')` (1 line, trivially removable). |
| S4 | Cold-start rendezvous, offline persistence, FTF-decoupled intro | 🟢 Healthy | `main.dart:43-190` | None — this is well-engineered; preserve it. |

---

## 2. Screen performance

### 2.1 Screen inventory & size (📐)

Largest page/screen files (LOC ⇒ proxy for `build()` complexity and rebuild surface):

| Screen | LOC | Backing cubit(s) | Rebuild scoping | Notes |
|---|---|---|---|---|
| `employee_home_screen.dart` | 1941 | task, statistics, branch | 3 `BlocBuilder`, **0** `BlocSelector`, **0** `buildWhen` | Largest screen; wraps big trees per builder |
| `my_schedule_screen.dart` | 1722 | schedule, shiftSwap | 1 `BlocBuilder` + 1 `BlocConsumer`; 2 `AnimationController` | Live countdown Timer (documented) |
| `task_details_screen.dart` | 1422 | task | 1 `BlocConsumer` | Whole screen rebuilds on any task-state field |
| `admin_dashboard_screen.dart` | 1196 | statistics, task, branch | 3 `BlocBuilder` + **2 `BlocSelector`** + 2 `AnimationController` | Best-scoped large screen |
| `compose_broadcast_screen.dart` | 1159 | broadcast | 0 bloc; **21 `setState`** | Heavy local-form state |
| `manager_schedule_view.dart` | 1131 | schedule | 3 `BlocBuilder` + 1 `BlocConsumer` | — |
| `admin_task_overview_screen.dart` | 776 | task | 1 `BlocConsumer` | Backed by unbounded `watchAllTasks` |
| `my_tasks_screen.dart` | 649 | task | plain `ListView` ×2 (eager) | — |

### 2.2 Widget-rebuild behavior (📐)

Codebase-wide rebuild-scoping primitives:

| Primitive | Count | Reading |
|---|---|---|
| `BlocBuilder<>` | **41** (in 31 files) | Broad rebuild surfaces |
| `BlocSelector<>` | **2** | Fine-grained rebuild scoping barely used |
| `BlocConsumer<>` | 15 | |
| `BlocListener<>` | 10 | |
| **`buildWhen`** | **0** | ⚠️ No `BlocBuilder` anywhere gates its rebuilds |
| `listenWhen` | 3 | |
| `context.select` | 1 | Fine-grained read barely used |
| `context.watch` | 4 | |
| `context.read` | 172 | |
| `setState` | **243** | Local rebuilds; concentrated in forms |
| `StreamBuilder` | 0 | Streams flow through cubits (good) |
| `FutureBuilder` | 12 | |

**Interpretation:** Large screens wrap sizable subtrees in a single `BlocBuilder` over a **freezed union state**. With `buildWhen` = 0 and `BlocSelector` = 2, **any** field change in a cubit's state rebuilds the whole subtree. This compounds with unbounded streams (§4): every Firestore snapshot re-emit → full state emit → full subtree rebuild.

### 2.3 List/scroll rendering — virtualization (📐)

| Pattern | Count | Reading |
|---|---|---|
| `ListView.builder` (lazy) | **10** | |
| `ListView.separated` (lazy) | 4 | |
| `ListView(children:[…])` (eager) | **76** | Non-virtualized |
| `GridView.builder` | 0 | |
| `GridView.count/extent/(…)` | 2 | |
| `SingleChildScrollView` | 32 | Non-virtualized scroll |
| `CustomScrollView` / Slivers | 0 / 1 | Slivers essentially unused |
| `.map(...)` to build child lists | 101 sites | Eager child construction |

**High-traffic list screens are predominantly eager (non-virtualized):**

| Screen | Lazy builder? | Rendering |
|---|---|---|
| `task_feed_section.dart` | ❌ | `SingleChildScrollView` (feed rows materialized, not virtualized) |
| `notifications_screen.dart` | ❌ | `ListView(children:[…])` ×2 |
| `employee_home_screen.dart` | ❌ | `ListView(children:[…])` |
| `my_tasks_screen.dart` | ❌ | `ListView(children:[…])` ×2 |
| `cases_screen.dart` | ❌ | `ListView(children:[…])` |
| `requests_screen.dart` | ❌ | `ListView(children:[…])` |
| `communications_screen.dart` | ✅ (2 builders) | Only screen using `.builder` |

For **small bounded lists this is fine**. For any list fed by an **unbounded stream** (§4), the full result set is materialized into widgets on every emit — a compounding render cost, not just a data cost.

### 2.4 ⏱ Runtime screen metrics — NOT CAPTURED

| Metric | Value | Capture method |
|---|---|---|
| Per-screen load time (nav → first painted) | `NOT CAPTURED` | DevTools Timeline / `Timeline.startSync` around route builds |
| Rebuild counts under live updates | `NOT CAPTURED` | DevTools "Track Widget Rebuilds" (Flutter Inspector) while a task stream ticks |
| Dropped/janky frames (>16ms) | `NOT CAPTURED` | DevTools Performance → Frame chart on scroll of each list screen |
| Raster vs UI thread time | `NOT CAPTURED` | DevTools Performance timeline |

> **Protocol:** In a profile build, open DevTools → Performance, enable "Track Widget Rebuilds," then (a) scroll each list screen, (b) trigger a task status change from a second device, and record rebuild counts + frame times on the 5 screens in §2.1.

### 2.5 Screen findings

| # | Finding | Severity | Evidence |
|---|---|---|---|
| SC1 | **Eager (non-virtualized) rendering on high-traffic list screens** backed by unbounded streams — full result set → widgets on every emit. | 🟠 High | §2.3 table; feeds use `SingleChildScrollView`/plain `ListView` |
| SC2 | **Wholesale rebuilds** — `buildWhen`=0, `BlocSelector`=2 across the app; 1000+ LOC screens rebuild whole subtrees on any state field. | 🟠 High | §2.2; `employee_home_screen.dart` 3 `BlocBuilder`/0 selector |
| SC3 | 5 screens > 1000 LOC with large single `build()` surfaces. | 🟡 Medium | §2.1 |
| SC4 | `compose_broadcast_screen.dart` — 21 `setState` in one form screen. | 🟡 Medium | §2.1 |
| SC5 | `admin_dashboard_screen.dart` uses `BlocSelector` ×2 — the only well-scoped large screen. | 🟢 Healthy pattern | §2.1 |

---

## 3. Resource usage

### 3.1 Live Firestore stream subscriptions (📐 — the main "resident cost" proxy)

Cubits that hold `StreamSubscription`s (live listeners open while alive):

| Cubit | Opens listener on | Bounded? |
|---|---|---|
| `auth_cubit` | `authStateChanges` + `watchUser(uid)` | n/a (single doc) |
| `task_cubit` | role-scoped task stream(s) + shift-task stream(s) | ❌ **unbounded** |
| `notification_cubit` | `watch(uid, limit)` | ✅ `.limit` (no cursor) |
| `case_list_cubit` | role-scoped case list | ❌ unbounded |
| `case_conversation_cubit` | `cases/{id}/messages` (per open case) | ❌ unbounded |
| `requests_list_cubit` | role-scoped request list | ❌ unbounded |
| `request_detail_cubit` | request + `requests/{id}/events` (per open request) | ❌ unbounded |
| `broadcast_cubit` | broadcast feed | ❌ unbounded |
| `branch_operations_cubit` | task stream × members × roster | ❌ unbounded |
| `shift_swap_cubit` | swap stream | ❌ unbounded |

**Streams open at cold start for an authenticated employee (≈4–6 listeners):**
- auth: `authStateChanges` + `watchUser` = 2
- task: `watchEmployeeTasks` + `watchShiftTasks` × (0–2 shifts today) = 1–3
- notifications: `watch(uid, limit)` = 1
- statistics + branch: **one-shot `.get()`** (no stream)

An **admin** at cold start opens `watchAllTasks` — a listener on the **entire `tasks` collection**.

**Subscription hygiene (📐):** 15 `StreamSubscription` declarations; cubits cancel on `close()`/re-subscribe (`task_cubit._subs` + `close()` at `task_cubit.dart:1258`). No leak observed statically. The `my_schedule_screen` live-countdown `Timer` must unmount in tests (documented). ✅

### 3.2 Timers & animations (📐)

| Resource | Count | Notes |
|---|---|---|
| `AnimationController` | 41 | Dispose discipline not audited per-site (runtime check) |
| `Timer` / `Timer.periodic` | 4 | Includes `UsageTracker` 20s debounce flush + schedule countdown |

### 3.3 Offline cache & memory posture (📐)

- `Settings.cacheSizeBytes = CACHE_SIZE_UNLIMITED` (`main.dart:155`) — the on-device Firestore cache **grows without bound**; combined with unbounded reads, the device accumulates entire collection histories locally.
- 15 eager singleton cubits (§1.2) are **resident for the whole process** (no scoping/disposal).
- Unbounded lists are deserialized `List<Model>` → `List<Entity>` and **held in cubit state**; size scales with collection.

### 3.4 Network / images (📐)

| Item | Count | Notes |
|---|---|---|
| `Image.network` | 13 | **No caching wrapper** — no `cached_network_image`, no custom `ImageCacheManager` |
| `NetworkImage` | 0 | |
| `CachedNetworkImage` | 0 | Not a dependency |
| `Image.asset` | 1 | |
| Lottie | splash intro | |

Branch cover banners / logos and profile images load via raw `Image.network`; Flutter's in-memory `ImageCache` applies, but there is **no persistent disk cache**, so images re-download across sessions.

### 3.5 ⏱ Runtime resource numbers — NOT CAPTURED

| Metric | Value | Capture method |
|---|---|---|
| Resident memory (idle home) | `NOT CAPTURED` | DevTools Memory → snapshot on home |
| Memory growth over a session | `NOT CAPTURED` | DevTools Memory timeline over 5-min usage |
| CPU (idle / scroll / live update) | `NOT CAPTURED` | DevTools CPU profiler / Xcode Instruments |
| Firestore reads per screen open | `NOT CAPTURED` | Firebase console Usage, or instrument datasource `.get()`/snapshot doc counts |
| Network bytes per session | `NOT CAPTURED` | Charles/Proxyman or Firebase console |

> **Existing hook:** `UsageTracker` (`core/services/usage_tracker.dart`) already writes counter telemetry to `usageStats/feed`. It counts **product events**, not Firestore reads — but it is the pattern to extend if per-feature read counting is later wanted (do not extend in this phase).

### 3.6 Resource findings

| # | Finding | Severity | Evidence |
|---|---|---|---|
| R1 | **`CACHE_SIZE_UNLIMITED` + unbounded reads** → unbounded on-device cache + resident list memory. | 🟠 High | `main.dart:155`; §3.1/§3.3 |
| R2 | **No persistent image cache** — 13 `Image.network` sites re-download across sessions. | 🟡 Medium | §3.4 |
| R3 | Admin task stream is a listener over the **whole** `tasks` collection. | 🔴 Critical (see §4) | `task_cubit.dart:177`; `task_remote_datasource.dart:134` |
| R4 | Subscription cancel-on-close hygiene | 🟢 Healthy | `task_cubit.dart:1258` |

---

## 4. Firestore usage

### 4.1 Collections accessed (📐 — `app_constants.dart`)

`users`, `tasks`, `task_templates`, `recurringTaskTemplates`, `branches`, `weekly_schedules`, `shift_swaps`, `broadcasts`, `notifications`, `cases` (+ `cases/{id}/messages`, `cases/{id}/reporter/identity`), `requests` (+ `requests/{id}/events`), `counters`, `broadcastTemplates`, `broadcastSchedules`, `reminderConfig`, `savedAudiences` (declared, unused), `taskReminders`, `usageStats/feed` (telemetry). **~18 collections.**

### 4.2 Per-datasource operation census (📐)

Counts are **static call-site occurrences** per remote datasource (not runtime frequency):

| Datasource | get | snap | set | upd | add | del | where | orderBy | **limit** | **cursor** | callable |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `task` | 7 | 4 | 7 | 0 | 0 | 3 | 8 | 3 | **0** | **0** | 0 |
| `schedule` | 7 | 4 | 3 | 5 | 1 | 3 | 7 | 0 | 0 | 0 | 1 |
| `statistics` | 12 | 0 | 0 | 0 | 0 | 0 | 15 | 0 | 0 | 0 | 0 |
| `case` | 4 | 4 | 2 | 1 | 1 | 1 | 4 | 2 | 0 | 0 | 0 |
| `request` | 1 | 5 | 1 | 2 | 1 | 0 | 2 | 2 | 0 | 0 | 0 |
| `notification` | 1 | 1 | 4 | 0 | 0 | 1 | 3 | 1 | **1** | **0** | 1 |
| `broadcast` | 0 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 0 | 0 | 1 |
| `broadcast_schedule` | 2 | 0 | 3 | 0 | 0 | 1 | 1 | 0 | 0 | 0 | 0 |
| `broadcast_template` | 1 | 0 | 4 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 |
| `profile` | 3 | 0 | 2 | 0 | 0 | 0 | 1 | 0 | **1** | 0 | 0 |
| `user` (auth) | 2 | 1 | 3 | 0 | 0 | 0 | 2 | 0 | 0 | 0 | 0 |
| `user_admin` | 4 | 0 | 2 | 0 | 0 | 0 | 2 | 0 | 0 | 0 | 2 |
| `branch` | 1 | 0 | 5 | 0 | 0 | 0 | 1 | 1 | 0 | 0 | 0 |
| `auth` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

### 4.3 Pagination posture (📐 — the headline finding)

- **`startAfter` cursor pagination: 0 occurrences across the entire `lib/`.** No feature paginates.
- **Only 2 `.limit()` sites total:** `notification_remote_datasource.dart:77` (`.limit(limit)`) and `profile_remote_datasource.dart:188` (`.limit(1)`, username uniqueness check).
- Every list stream in **tasks, cases, requests, broadcasts, schedules, shift_swaps, task_templates** reads/streams the **full result set**:
  - `task_remote_datasource.dart:100` — `getAllTasks()` → `_tasks.orderBy(createdAt).get()` (**entire `tasks` collection**)
  - `:134` `watchAllTasks`, `:138` `watchTasksByBranch`, `:144` `watchEmployeeTasks`, `:150` `watchShiftTasks` — all `.snapshots()` with **no `.limit()`**
  - `:369` `getTemplates()` → `orderBy('title').get()` (all templates)

> ⚠️ **Prior-audit correction:** `OPTIMIZATION_AUDIT_2026-07-08.md` states notifications use `.limit()` **+ `startAfter` cursor**. Verified false: notifications use `.limit(limit)` **only** — there is **no `startAfter` anywhere in `lib/`**. The `notification_cubit.loadMore()` grows `_limit` and re-subscribes; it does not cursor-page.

### 4.4 Server-side aggregation (📐 — a healthy precedent)

`statistics_remote_datasource.dart:53` uses `count().get()` aggregate queries for admin dashboard totals (`_aggCount` over `employees`, `tasks`, `approved`, `waitingReview`, `rejected`) with an offline fallback to cached-doc counting. **Branch-level** stats, however, read full `where('branchId', …).get()` document sets and count client-side (`:169-193`).

### 4.5 Client-side work on unbounded input (📐)

- `task_feed.dart` sorts/groups the full task list **client-side on the main isolate** (pure functions in `task_ordering.dart` / `active_window.dart` — good testability, but O(n) over unbounded n on every emit).
- Statistics branch view counts full document lists client-side (`statistics_remote_datasource.dart:_count`).

### 4.6 Embedded arrays (📐 — latent doc-size risk)

`TaskModel` embeds `activityLog[]`, `checklist[]`, `referenceAttachments[]` in the task doc; whole-doc `set(merge:true)` writes re-transmit the growing arrays. Firestore's 1 MB doc cap is a latent cliff for long-lived, heavily-reworked tasks. (Cases/requests already use subcollections — `cases/{id}/messages`, `requests/{id}/events`.)

### 4.7 Firestore findings

| # | Finding | Severity | Evidence | Recommended future action (do NOT implement now) |
|---|---|---|---|---|
| F1 | **Unbounded collection reads/streams — no `.limit()`, no cursor** on tasks/cases/requests/broadcasts/schedules/templates. | 🔴 **Critical** | §4.3; `task_remote_datasource.dart:100/134-158/369` | Add `.limit(N)` + `startAfterDocument` cursor per list stream (replicate the notifications `.limit` pattern, add the missing cursor). Feature-by-feature, tasks first. |
| F2 | **Client-side sort/group/count of unbounded lists on the main isolate.** | 🟠 High | §4.5; `task_feed.dart`, `statistics_remote_datasource.dart:169` | Push filter/sort into queries; keep pure grouping only on bounded pages. |
| F3 | **Full re-emit on every snapshot** — unbounded streams re-deserialize + re-render the whole set on any change. | 🟠 High | §4.3 + §2.3 | Follows from F1; bounded pages shrink the re-emit. |
| F4 | Branch-level statistics read full doc sets (admin totals already use `count()`). | 🟡 Medium | §4.4 | Extend `count()` aggregation to branch counts. |
| F5 | Unbounded embedded arrays (`activityLog`) — latent 1 MB doc cliff. | 🟡 Medium (latent) | §4.6 | Monitor; migrate to subcollection only on evidence of growth. |
| F6 | `savedAudiences` collection declared, never read. | 🟢 Low | `app_constants.dart:30` | Delete or implement. |
| F7 | Server-authoritative aggregation + subscription hygiene | 🟢 Healthy | §4.4, §3.1 | None. |

---

## 5. Architecture metrics

### 5.1 Codebase size (📐)

| Metric | Value |
|---|---|
| `lib/` Dart files | 427 |
| `lib/` total LOC | 94,923 |
| Hand-written LOC | 71,427 (390 files) |
| Generated LOC (freezed) | 23,496 (37 files) |
| `.g.dart` (json_serializable) | 0 files |
| Widget classes (`StatelessWidget` + `StatefulWidget`) | 413 + 108 = **521** |
| Cubit classes | 17 |
| Shared components (`core/widgets/`) | 39 |
| Tests | 97 files / 10,746 LOC (738 cases per prior audit) |

### 5.2 Largest files (📐)

| File | LOC | Kind |
|---|---|---|
| `task_action_sheets.dart` | 2452 | widget (40 classes) |
| `employee_home_screen.dart` | 1941 | screen |
| `my_schedule_screen.dart` | 1722 | screen |
| `task_details_screen.dart` | 1422 | screen |
| `task_entity.freezed.dart` | 1295 | *generated* |
| `task_cubit.dart` | **1264** | cubit |
| `admin_dashboard_screen.dart` | 1196 | screen |
| `auth_state.freezed.dart` | 1178 | *generated* |
| `compose_broadcast_screen.dart` | 1159 | screen |
| `manager_schedule_view.dart` | 1131 | widget |

### 5.3 Largest cubits (📐 — hand-written, excl. `.freezed`)

| Cubit | LOC | Reading |
|---|---|---|
| `task_cubit` | **1264** | God object: CRUD + lifecycle + checklist + notes + proof upload + templates + recurring templates; 3 repos + 7 use cases; holds `_subs` list |
| `case_list_cubit` | 392 | |
| `schedule_cubit` | 334 | |
| `broadcast_cubit` | 300 | |
| `auth_cubit` | 286 | |
| `shift_swap_cubit` | 267 | |
| `request_detail_cubit` | 237 | |
| `admin_users_cubit` | 229 | |

(Total hand-written cubit LOC: 4,501 across 17 cubits — `task_cubit` alone is **28%**.)

### 5.4 Largest widget files (📐)

`task_action_sheets.dart` 2452 · `manager_schedule_view.dart` 1131 · `swap_view.dart` 932 · `work_type_panel.dart` 905 · `activity_timeline.dart` 773 · `task_feed_section.dart` 706 · `task_feed_expansion.dart` 667 · `task_card.dart` 664 · `dynamic_work_form.dart` 652.

### 5.5 Rebuild-scoping census (📐)

`BlocBuilder` **41** · `BlocSelector` **2** · `BlocConsumer` 15 · `BlocListener` 10 · **`buildWhen` 0** · `listenWhen` 3 · `context.select` 1 · `context.watch` 4 · `context.read` 172 · `setState` 243 · `StreamBuilder` 0 · `FutureBuilder` 12. (See §2.2 for interpretation.)

### 5.6 `const` usage (📐)

**4,013** `const` occurrences across `lib/` (excluding generated). `const` discipline is strong — this is a healthy widget-caching signal, not a bottleneck. `analysis_options.yaml` present (lint config).

### 5.7 Duplicated utilities (📐)

| Duplication | Count | Evidence |
|---|---|---|
| **Hardcoded month-name arrays** (`['Jan','Feb',…]`) | **20 files** | `grep -lF "'Jan'"` |
| **Inline date/time formatters** (`_fmt`/`_relative`/`timeAgo`/weekday maps) | **~24 files** | §7.1 of prior audit corroborated |
| `package:intl` shared formatter | **0 files** | No centralized date util exists |
| Raw `showModalBottomSheet` (no wrapper) | **23 sites** | |
| Raw `showDialog` | 6 sites | `AppDialog` exists but **0 usages** |
| Raw `ScaffoldMessenger.of` (snackbars) | 3 sites | `AppSnackbar`/`context.showSuccess` centralizes the rest |
| Hardcoded `Color(0x…)` literals | **65** | Theme tokens centralized in `core/theme/`; these are strays |

> ⚠️ **Prior-audit correction:** the earlier audit said `intl` is "used in exactly 1 file today." Verified: **0 files import `package:intl`.** There is no shared date-formatting utility at all — all 24 date-format sites are bespoke.

### 5.8 Architecture findings

| # | Finding | Severity | Evidence |
|---|---|---|---|
| A1 | `task_cubit.dart` — 1264 LOC god object (28% of all cubit LOC); template mgmt mixed with live-task lifecycle. | 🟠 High | §5.3 |
| A2 | `task_action_sheets.dart` — 2452 LOC / 40 classes in one file. | 🟠 High | §5.2 |
| A3 | `buildWhen`=0, `BlocSelector`=2 app-wide → wholesale rebuilds. | 🟠 High | §5.5, §2.2 |
| A4 | Date/time formatting duplicated across ~24 files; no shared util. | 🟡 Medium | §5.7 |
| A5 | 23 raw bottom-sheets / 6 raw dialogs (`AppDialog` unused) / 65 stray color literals. | 🟡 Medium | §5.7 |
| A6 | 5 screens > 1000 LOC. | 🟡 Medium | §5.2 |
| A7 | Strong `const` discipline (4,013), clean layer separation, 39 shared components. | 🟢 Healthy | §5.1, §5.6 |

---

## 6. Consolidated bottleneck register (severity-ranked)

| Rank | ID | Bottleneck | Severity | Class | Primary evidence |
|---|---|---|---|---|---|
| 1 | F1 | Unbounded Firestore reads/streams (no `.limit`/cursor) | 🔴 Critical | Static + runtime | `task_remote_datasource.dart:100/134-158` |
| 2 | S1 | TTI gated on `Future.wait` of home-critical reads (scales with F1) | 🟠 High | Static | `main.dart:176-181` |
| 3 | SC1 | Eager (non-virtualized) list rendering on high-traffic screens | 🟠 High | Static | §2.3 |
| 4 | SC2/A3 | Wholesale rebuilds — `buildWhen`=0, `BlocSelector`=2 | 🟠 High | Static | §2.2 |
| 5 | F2/F3 | Client-side sort/group + full re-emit on unbounded input | 🟠 High | Static | `task_feed.dart` |
| 6 | R1 | `CACHE_SIZE_UNLIMITED` + unbounded resident lists | 🟠 High | Static | `main.dart:155` |
| 7 | A1 | `task_cubit` god object (1264 LOC) | 🟠 High | Static | §5.3 |
| 8 | A2 | `task_action_sheets` 2452 LOC / 40 classes | 🟠 High | Static | §5.2 |
| 9 | S2 | 15 eager singleton cubits at startup | 🟡 Medium | Static | `injection.dart` |
| 10 | R2 | No persistent image cache (13 `Image.network`) | 🟡 Medium | Static | §3.4 |
| 11 | F4 | Branch stats read full doc sets | 🟡 Medium | Static | §4.4 |
| 12 | F5 | Unbounded embedded `activityLog` (latent) | 🟡 Medium | Static | §4.6 |
| 13 | A4/A5 | Date-format + sheet/dialog/color duplication | 🟡 Medium | Static | §5.7 |
| 14 | A6/SC3 | 5 screens > 1000 LOC | 🟡 Medium | Static | §5.2 |
| 15 | SC4 | 21 `setState` in `compose_broadcast_screen` | 🟡 Medium | Static | §2.1 |
| 16 | F6 | `savedAudiences` dead collection | 🟢 Low | Static | `app_constants.dart:30` |
| 17 | S3 | Home-warmup step not timed | 🟢 Low | Static | `main.dart:163` |

---

## 7. Measurement gaps (what a device run must still capture)

Everything in this baseline is **static** unless marked ⏱. The following require a profiling run on a physical device with a signed-in account, captured **before** any Phase-1 change:

1. Cold/warm start ms + TTFF/TTI (`flutter run --profile --trace-startup` → `build/start_up_info.json`) — §1.4
2. Per-screen load times + rebuild counts + frame jank (DevTools Performance + "Track Widget Rebuilds") — §2.4
3. Idle/peak memory + growth curve; CPU under scroll/live-update (DevTools Memory/CPU or Xcode Instruments) — §3.5
4. Actual Firestore reads/writes per screen (Firebase console Usage) — §3.5

**Free wins already available:** `AppLog.time` prints `Firebase.initializeApp` and `restoreSession` durations on every debug cold start (§1.1) — read them from the console for the first two startup segments with zero new code.

---

## 8. Instrumentation status

**No production code was changed for this baseline.** No temporary instrumentation was added — all figures come from source inspection plus the app's **pre-existing** `AppLog.time` hooks and `UsageTracker`. If runtime capture (§7) later needs a timing probe, the only suggested temporary edit is a single `AppLog.time('boot','home-warmup', …)` wrapper around `main.dart:176` (step 6), which is trivially removable and isolated to one line.

---

*Baseline captured on `core/optimization` @ 2026-07-08. Static metrics reproducible via the `grep`/`wc`/`find` queries cited inline. Runtime rows are honestly marked `NOT CAPTURED` pending a device profiling run — no runtime numbers were fabricated.*
