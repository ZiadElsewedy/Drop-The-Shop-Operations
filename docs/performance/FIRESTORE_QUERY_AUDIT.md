# DROP — Firestore Query Audit

> **Sprint 1 · Quick Win #2 · `core/optimization`** · **Date:** 2026-07-08
> **Type:** Engineering audit — **measurement only. No code changed. No limits added. No pagination introduced.**
> **Companion baselines:** [`PERFORMANCE_BASELINE.md`](PERFORMANCE_BASELINE.md) · [`PERFORMANCE_BASELINE_ACTIONS.md`](PERFORMANCE_BASELINE_ACTIONS.md)

---

## 0. How to read this

Every client-side Firestore query in `lib/` is inventoried below, grouped by feature. All queries live in the **`data/datasources/*_remote_datasource.dart`** layer (Firebase is quarantined there — verified), so the "Datasource" column is implied per section and the "Repository" is the matching `*_repository_impl.dart`.

**Evaluation is grounded in the real product, not theory.** DROP is a **premium internal operations platform** — a handful of branches, tens of employees, managers, and a few admins. That materially changes the verdicts: a query that reads a *whole collection* is often **completely fine** here because the collection is naturally tiny (branches, users, templates, a branch's swaps). The audit only flags a full read as a concern when the collection **grows without a natural small bound** (tasks, cases, requests, broadcasts, schedules over time).

Document-count columns are **order-of-magnitude estimates** for this product's scale (no production telemetry was available this session — the runtime profiling pass was blocked on signing/credentials). They are labelled as estimates, not measured facts.

### Classification legend

| Tag | Meaning |
|---|---|
| ✅ **Correct as-is** | Doc-get, naturally-bounded collection, or already limited+indexed. Leave it. |
| 🟡 **`limit()` candidate (later)** | Grows over time but branch/user-scoped; fine now, would benefit from a cap eventually. |
| 🟠 **Pagination later** | Unbounded full-collection read on a growing collection; the real scaling work (deferred, not this sprint). |
| 🔷 **Index** | Needs / relies on a composite index. |
| 🔧 **Restructure** | A structural improvement is available (consistency, N+1, aggregation). |

---

## 1. Index status (summary)

**Existing composite / collection-group indexes** (`firestore.indexes.json`):

| Index | Backs query | Verdict |
|---|---|---|
| `notifications`: `recipientUid ASC, createdAt DESC` | `notification.watch()` (where + orderBy + limit) | ✅ correct & required |
| `tasks`: `branchId ASC, assignmentType ASC, shift ASC` | `task.watchShiftTasks()` | ✅ correct & required |
| `reporter` (CG): `createdByUserId ASC` | `case.getMyCases()` collectionGroup | ✅ correct & required |

**Missing composite indexes: none required.** Every other query is either a **single-field** filter/`orderBy` (auto-indexed by Firestore: `createdAt`, `lastMessageAt`, `lastEventAt`, `name`, `title`, `weekStart`, `role`, `branchId`, `assigneeIds` array, `username`) or a **multiple-equality** query served by Firestore's automatic zig-zag merge join (no composite needed). One query (`watchBranchCases`, two equality filters) is worth a **deploy-time verification** because the cases feature's rules/indexes are still pending deploy (see §12 & project memory) — but it should not need a composite index.

---

## 2. Tasks  · `task_remote_datasource.dart` / `TaskRepositoryImpl`

Collections: `tasks`, `task_templates`, `recurringTaskTemplates`.

| Query | where / orderBy / limit / startAfter | get/stream | Purpose | Est. docs | Current behavior | Potential issue | Recommendation |
|---|---|---|---|---|---|---|---|
| `watchAllTasks` | `orderBy(createdAt desc)` · no limit · no cursor | stream | Admin global task overview | **100s→1000s+ (grows)** | Streams the **entire** `tasks` collection; re-emits full set on any change | Cost/memory/first-paint grow with total task history | 🟠 **Pagination later** — the single highest-value target; also §6 of the perf baseline |
| `getAllTasks` | `orderBy(createdAt desc)` · no limit | get | One-shot admin overview (stream is the live path) | 100s→1000s+ | Reads whole collection once | Same as above; verify caller (stream variant is the live one) | 🟠 Pagination later (or confirm unused) |
| `watchTasksByBranch` | `where(branchId ==)` · no orderBy | stream | Manager's branch task feed | 10s→100s | Branch-scoped live stream, sorted client-side | Grows with a branch's task history | 🟡 `limit()` candidate later |
| `getTasksByBranch` | `where(branchId ==)` | get | One-shot branch tasks | 10s→100s | Branch-scoped one-shot | Grows over time | 🟡 later |
| `watchEmployeeTasks` | `where(assigneeIds array-contains)` · no orderBy | stream | Employee's own task feed | 10s | Assignee-scoped live stream | Naturally small (one person's tasks) | 🟡 later (low) — near-`limit`-safe by nature |
| `getEmployeeTasks` | `where(assigneeIds array-contains)` | get | One-shot employee tasks | 10s | Assignee-scoped one-shot | Small | 🟡 later (low) |
| `watchShiftTasks` | `where(branchId ==, assignmentType ==, shift ==)` 🔷 composite | stream | Shift-scoped task board (today's shift) | <20 | Tightly scoped; **has its composite index** | None | ✅ **Correct as-is** |
| `getTask` | `doc(id).get()` | get | Open one task | 1 | Point read | None | ✅ Correct as-is |
| `getTemplates` | `orderBy(title)` · no limit | get | Task-template picker | 10s–50 | Reads all templates | Curated set, stays small | ✅ Correct as-is |
| `getRecurringTemplates` | `where(branchId ==)` | get | Branch recurring blueprints | <20 | Branch-scoped | Small | ✅ Correct as-is |

---

## 3. Schedule & Swaps · `schedule_remote_datasource.dart` / `ScheduleRepositoryImpl`

Collections: `weekly_schedules`, `shift_swaps`.

| Query | where / orderBy / limit | get/stream | Purpose | Est. docs | Current behavior | Potential issue | Recommendation |
|---|---|---|---|---|---|---|---|
| `getSchedule` | `doc(branchId_weekStart).get()` | get | One week for one branch | 1 | **Deterministic doc id** (`ScheduleWeek.docId`) — ideal | None | ✅ **Correct as-is (exemplary)** |
| `getBranchSchedules` | `where(branchId ==)` | get | All weeks for a branch | ~52/yr/branch | Grows ~1 doc/week | Unbounded over years | 🟡 `limit()` / `where(weekStart >=)` candidate later |
| `getAllSchedules` | none (full) | get | Admin all-branch schedule view | branches × weeks | Full collection | Grows over time | 🟠 Pagination later (or scope by week) |
| `watchBranchSwaps` | `where(branchId ==)` | stream | Branch swap queue (manager) | 10s | Branch-scoped live | Grows slowly | 🟡 later (low) |
| `watchEmployeeSwaps` | 2× `where(requesterId ==)` / `where(targetId ==)`, merged | stream | Employee's swaps (either side) | <20 | Two scoped streams merged client-side | Small; merge is intentional | ✅ Correct as-is |
| `watchAllSwaps` | none (full) | stream | Admin cross-branch swap queue | 10s→100s | Full collection live | Grows over time | 🟠 Pagination later (low) |
| `getBranchSwaps` / `getEmployeeSwaps` / `getAllSwaps` | branch / uid / none | get | One-shot variants of the above | as above | Same scoping as the watch variants | Same | 🟡/🟠 mirror the stream verdicts |

---

## 4. Cases · `case_remote_datasource.dart` / `CaseRepositoryImpl`

Collections: `cases` (+ subcollections `cases/{id}/messages`, `cases/{id}/reporter/identity`).

| Query | where / orderBy / limit | get/stream | Purpose | Est. docs | Current behavior | Potential issue | Recommendation |
|---|---|---|---|---|---|---|---|
| `watchAllCases` | `orderBy(lastMessageAt desc)` · no limit | stream | Admin case inbox | 10s→100s (grows) | Full collection live | Grows over time | 🟠 Pagination later |
| `watchBranchCases` | `where(branchId ==, visibleToManager ==)` · no orderBy | stream | Manager branch inbox | 10s | Two-equality live stream (merge-join, no composite) | Grows; **verify on deploy** (cases indexes pending) | 🟡 later + 🔷 **verify index at deploy** |
| `getMyCases` | CG `reporter` `where(createdByUserId ==)` 🔷 then N× `doc(id).get()` | get | Employee's own cases | <20 | Collection-group lookup → **N follow-up doc reads** | N+1 read pattern (small N here) | ✅ Correct as-is · 🔧 restructure only if N grows |
| `watchMessages` | subcollection `orderBy(createdAt asc)` · no limit | stream | One case's conversation | 1–100s per case | Full thread per open case | A very long case grows | ✅ Correct as-is · 🟡 limit later (low) |
| `getCase` / `watchCase` | `doc(id)` | get/stream | Open one case | 1 | Point read | None | ✅ Correct as-is |
| `revealReporter` | `reporter/identity` `doc.get()` | get | Reveal confidential reporter | 1 | Point read of private doc | None | ✅ Correct as-is |

---

## 5. Requests · `request_remote_datasource.dart` / `RequestRepositoryImpl`

Collections: `requests` (+ subcollection `requests/{id}/events`).

| Query | where / orderBy / limit | get/stream | Purpose | Est. docs | Current behavior | Potential issue | Recommendation |
|---|---|---|---|---|---|---|---|
| `watchAllRequests` | `orderBy(lastEventAt desc)` · no limit | stream | Admin request inbox | 10s→100s (grows) | Full collection live | Grows over time | 🟠 Pagination later |
| `watchBranchRequests` | `where(branchId ==)` · no orderBy (client-sorted) | stream | Manager branch inbox | 10s | Single-equality live; **code comments confirm** the deliberate small-volume choice | Grows slowly | 🟡 `limit()` candidate later |
| `watchMyRequests` | `where(requesterId ==)` · no orderBy | stream | Employee's own requests | <20 | Own-scoped live | Small | ✅ Correct as-is |
| `watchEvents` | subcollection `orderBy(createdAt asc)` | stream | One request's timeline | <20 | Full timeline per request | Tiny | ✅ Correct as-is |
| `getRequest` / `watchRequest` | `doc(id)` | get/stream | Open one request | 1 | Point read | None | ✅ Correct as-is |

---

## 6. Communications · `broadcast*_remote_datasource.dart`

Collections: `broadcasts`, `broadcastTemplates`, `broadcastSchedules`.

| Query | where / orderBy / limit | get/stream | Purpose | Est. docs | Current behavior | Potential issue | Recommendation |
|---|---|---|---|---|---|---|---|
| `watchBroadcasts` (all) | `orderBy(createdAt desc)` · no limit | stream | Admin broadcast history | 10s→100s (grows) | Full collection live | Grows with send history | 🟠 Pagination later |
| `watchBroadcasts` (branch) | `where(branchId whereIn [branchId, ''])` · no orderBy | stream | Branch-scoped feed (+ org-wide) | 10s | `whereIn` (single-field) live | Grows over time | 🟡 `limit()` candidate later |
| `broadcast_schedule.getSchedules` | full **or** `where(senderId ==)` | get | Scheduled-broadcast admin/mine | <20 | Small set | None | ✅ Correct as-is |
| `broadcast_template.getTemplates` | none (full) | get | Template picker | 10s–50 | Curated set | Stays small | ✅ Correct as-is |

---

## 7. Notifications · `notification_remote_datasource.dart` — the reference implementation

Collection: `notifications`.

| Query | where / orderBy / limit | get/stream | Purpose | Est. docs | Current behavior | Potential issue | Recommendation |
|---|---|---|---|---|---|---|---|
| `watch` | `where(recipientUid ==)` · `orderBy(createdAt desc)` · **`limit(30)`** 🔷 composite | stream | User notification inbox | ≤30 read | **Bounded + indexed** — the pattern other feeds should copy | None | ✅✅ **Correct as-is (exemplary)** |
| `markAllRead` | `where(recipientUid ==)` then client-filter unread | get | Bulk mark-as-read | 10s–100s | Reads all of a user's notifications to find unread | Grows with a user's history | 🟡 later (low) — could filter `where(readAt == null)` (needs an index) |

---

## 8. Statistics · `statistics_remote_datasource.dart`

Collections read: `users`, `tasks`, `branches`, `weekly_schedules`.

| Query | shape | get | Purpose | Est. docs | Current behavior | Potential issue | Recommendation |
|---|---|---|---|---|---|---|---|
| `adminStats` counts | `count().get()` on `users`/`tasks` by role/status | agg | Dashboard KPI totals | count only | **Server-side aggregation** — no docs downloaded | None | ✅✅ **Correct as-is (exemplary)** |
| `adminStats` branches | `_branches.get()` (full) | get | Branch coverage math | 1–20 | Reads all branches (tiny) | None | ✅ Correct as-is |
| `adminStats` managers | `where(role == manager)` | get | Manager coverage | <20 | Small scoped read | None | ✅ Correct as-is |
| `adminStats` schedules | `where(weekStart` range`)` | get | This-week coverage | ~branches | Range on single field (auto-index) | None | ✅ Correct as-is |
| `adminStats` rejectedToday | `where(rejectedAt` range`)` | get | Today's rejections | small | Range on single field | None | ✅ Correct as-is |
| `managerStats` | `where(branchId ==)` on `users` **and** `tasks`, counted **client-side** | get | Manager dashboard | 10s→100s tasks | Downloads branch tasks to count them | **Inconsistent with `adminStats`** (which uses `count()`); grows with branch task history | 🔧 **Restructure candidate** — switch counts to `count()` aggregation (→ §11 "needs investigation") |
| `employeeStats` | `where(assigneeIds array-contains)` on `tasks` + schedule doc | get | Employee dashboard | 10s | Own tasks + one schedule doc | Small | ✅ Correct as-is |

---

## 9. Users / Auth · `user_remote_datasource.dart` · Admin · `user_admin_remote_datasource.dart`

Collection: `users` (+ `users/{uid}/private/compensation`).

| Query | shape | get/stream | Purpose | Est. docs | Current behavior | Potential issue | Recommendation |
|---|---|---|---|---|---|---|---|
| `getUser` / `watchUser` | `doc(uid)` | get/stream | Session user / live profile | 1 | Point read | None | ✅ Correct as-is |
| `getUsersByBranch` | `where(branchId ==)` | get | Branch member directory (assignee pickers) | 10s | Branch-scoped | Bounded by branch headcount | ✅ Correct as-is |
| `getAllUsers` | none (full) | get | Admin user administration | 20–200 | Full `users` read | Bounded by org size (naturally small) | ✅ Correct as-is · 🟡 limit only if org becomes large |
| `getUsersByRole` | `where(role ==)` | get | Managers / employees lists | 10s–100s | Role-scoped | Bounded by org size | ✅ Correct as-is |
| `getCompensation` | `private/compensation` `doc.get()` (+ legacy fallback) | get | One user's pay | 1 | Point read | None | ✅ Correct as-is |

---

## 10. Profile · `profile_remote_datasource.dart` · Branch · `branch_remote_datasource.dart`

| Query | shape | get | Purpose | Est. docs | Current behavior | Potential issue | Recommendation |
|---|---|---|---|---|---|---|---|
| `getProfile` | `doc(uid)` + `private/compensation` doc | get | Profile page | 1–2 | Point reads | None | ✅ Correct as-is |
| `isUsernameAvailable` | `where(username ==)` · **`limit(1)`** | get | Username uniqueness | ≤1 | **Bounded** | None | ✅✅ Correct as-is (exemplary) |
| `getBranches` | `orderBy(name)` (full) | get | Branch list / dropdowns | 1–20 | Full read, tiny | None | ✅ Correct as-is |

---

## 11. Cross-cutting observations

1. **The "unbounded" family is a small, well-understood set.** Every full-collection *growing* read is one of exactly six: `watchAllTasks`/`getAllTasks`, `watchAllCases`, `watchAllRequests`, `watchBroadcasts(all)`, `getAllSchedules`, `watchAllSwaps` — all **admin/global overview** surfaces. Everything branch- or user-scoped is naturally bounded at this product's scale.
2. **Notifications and the statistics `count()` aggregation are the templates.** When pagination work eventually happens, copy `notification.watch()` (where + orderBy + `limit` + composite index; add a `startAfter` cursor) and the `_aggCount` pattern — they already exist in-repo.
3. **Ordering is deliberately client-side** on branch/user-scoped streams (the datasource comments say so) to avoid composite indexes at small volume. That is a **correct** trade-off for internal scale — do not "fix" it into composite indexes prematurely.
4. **One genuine consistency gap:** `managerStats` downloads branch tasks to count client-side while `adminStats` uses `count()`. Not urgent, but the odd one out.
5. **Server-side note (context, out of scope):** Cloud Functions (`functions/index.js`) also run ~80 Firestore reads/queries with the Admin SDK (broadcast fan-out, swap finalization, notification writes). These run server-side, are not on the user-latency path, and bypass client rules — they are **out of scope** for this client-query audit and should be assessed separately if function cost becomes a concern.

---

## 12. Prioritized action list (measurement output — do **not** implement this sprint)

### 🟢 Safe Quick Wins (low risk, high clarity — when a later sprint touches these)

These are the cheapest, lowest-risk bounded-read wins. Each is a `limit()` (and optionally a cursor) on an **admin/global list that a human never scrolls past the first screen of** — capping it changes nothing a user sees today but removes the growth risk:

| # | Query | Why it's safe |
|---|---|---|
| Q1 | `notification.markAllRead` unread filter | Add `where(readAt == null)` (+ its index) — smaller read, identical result |
| Q2 | `broadcast_template.getTemplates`, `broadcast_schedule.getSchedules`, `task.getTemplates`, `branch.getBranches`, `getUsersByBranch` | Already tiny/bounded — **explicitly leave as-is**; documented so no one "optimizes" them needlessly |
| Q3 | `getBranchSchedules` → add `where(weekStart >= …)` window | A branch never needs *all* historical weeks at once |

> **Note:** per this sprint's rules, "safe quick win" here means *low-risk when eventually done* — **nothing is changed now.**

### 🔍 Needs investigation

| # | Item | Question to answer first |
|---|---|---|
| I1 | `managerStats` client-side counting | Convert to `count()` aggregation (like `adminStats`)? Confirm the derived fields it needs can all be expressed as counts. 🔧 |
| I2 | `watchBranchCases` two-equality query | Confirm at **deploy** that `branchId + visibleToManager` serves without a composite index (cases rules/indexes are still pending — project memory). 🔷 |
| I3 | `getAllTasks` (one-shot) | Confirm whether it still has a live caller, or is superseded by `watchAllTasks` and can be removed. |
| I4 | `getMyCases` N+1 (collectionGroup → N doc-gets) | Fine at current N (<20); revisit only if an employee accrues many cases. 🔧 |

### 📄 Needs pagination later (deferred — the real scaling work, per perf baseline §6)

Ordered by growth pressure. All are **admin/global live streams over growing collections** with **no `limit()` and no `startAfter`**:

| # | Query | Feature | Growth driver |
|---|---|---|---|
| P1 | `watchAllTasks` / `getAllTasks` | Tasks | Total task history — **highest priority** |
| P2 | `watchAllCases` | Cases | Case history across branches |
| P3 | `watchAllRequests` | Requests | Request history across branches |
| P4 | `watchBroadcasts(all)` | Communications | Broadcast send history |
| P5 | `getAllSchedules` | Schedule | branches × weeks over time |
| P6 | `watchAllSwaps` / `getAllSwaps` | Swaps | Swap history (slowest-growing) |

Secondary (branch/user-scoped, 🟡 `limit()` candidates that only matter after years of data): `watchTasksByBranch`, `getTasksByBranch`, `watchBranchCases`, `watchBranchRequests`, `watchBranchSwaps`, `watchBroadcasts(branch)`, `watchMessages`.

---

## 13. Bottom line

For a **premium internal ops tool at its real scale, the query layer is in good shape**: point reads and naturally-bounded collections dominate, `notifications` and the statistics `count()` aggregation are already best-practice, and no composite index is missing. The only structural work is **deferred pagination on six admin/global streams** (P1–P6, tasks first) and **one consistency cleanup** (`managerStats` → `count()`). None of it is urgent at today's data volumes, and **none of it was changed in this audit.**

---

*Audit performed by static inspection of all 14 `*_remote_datasource.dart` files on `core/optimization` @ 2026-07-08. Document counts are labelled estimates (no production telemetry captured this session). No queries were modified; no limits, cursors, or indexes were added.*
