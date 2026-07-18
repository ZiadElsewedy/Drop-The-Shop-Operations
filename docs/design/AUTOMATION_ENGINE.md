# DROP — Automated Task Engine (Audit + Hardening)

> **Status:** P0 + P1 implemented (`feature/media-upload-v2`, 2026-07-11).
> Owner-approved scope after a full automation audit. Calibrated to small-team
> scale per [product philosophy](../../PROJECT_CONTEXT.md) — **no parallel
> automation backend, no round-robin assignment engine, no standalone analytics
> dashboard**. This doc is the source of truth for how recurring/scheduled task
> automation works and why it is now deterministic.

---

## 1. What "automation" means in DROP

Two **independent** recurrence engines feed the one `tasks/{id}` collection:

| | **Path A — Shift-template recurrence** | **Path B — Per-task recurrence** |
|---|---|---|
| Blueprint | `recurringTaskTemplates/{id}` (a standing routine) | A `RecurrenceConfig` embedded on a `TaskEntity` |
| Trigger | `generateShiftTaskInstances` Cloud Function (daily) + client `_materializeTodayInstance` on template save | Client `_spawnNextRecurrence` **after** a task is approved |
| Assignment | **Shift broadcast** — `assigneeIds: []`, targets whoever is rostered on that (day, shift) | Inherits the source task's `assigneeIds` |
| Instance id | Deterministic `rt_{templateId}_{yyyy-MM-dd}` | Deterministic `rec_{sourceTaskId}` (**new** — was a random auto-id) |

There is **no single-employee selection engine**. "Automatic assignment" = a shift
task is visible to and notifies every rostered employee on its shift; a per-task
recurrence inherits its parent's assignees. This is deliberate (a small team wants
the whole shift to see the routine, not a lottery winner).

---

## 2. The duplicate bug — root cause

### Path B was the real duplicate-*task* vector (fixed)
`_spawnNextRecurrence` created the next instance with a **non-deterministic
auto-generated document id**. Its only protection against duplicates was an
*emergent* invariant (the approve state machine), not an *intrinsic* dedup key:

- Concurrent double-approve → already closed by the atomic `transitionTask`
  (only the winner reaches the spawn). ✔
- **Reopen → re-approve → duplicate.** `reopenTask` moves `approved → started`
  and keeps `recurrence` intact. The task legitimately reaches `waitingReview →
  approved` again, so the spawn runs a **second** time and — with a random id —
  writes a **second** "next" task. ✘ (reachable, this was the bug)
- Crash between commit and spawn → *zero* next tasks (a lost recurrence). ✘

### Path A duplicated *notifications*, not tasks
The deterministic id already prevented duplicate task documents, but the id check
was a non-atomic **read-then-`set`** and the notify step was unconditional, so an
overlapping run / scheduler retry could **re-notify** the whole roster (and blind-
`set` could overwrite a live doc).

### Systemic
No `maxInstances`/`retryCount` on scheduled functions (Cloud Scheduler is
at-least-once); no run history/observability.

---

## 3. Prevention strategy — idempotency made intrinsic

**Principle: one (source, occurrence) → exactly one deterministic document id,
written create-only.** Then retries, concurrency, and reopen→re-approve all
*converge* on one doc instead of multiplying.

- **Path B:** the successor's id is **`rec_{sourceTaskId}`**. Each task spawns at
  most one successor, so keying the successor on the (stable, globally-unique)
  current task id is the natural idempotency key — and, crucially, it does **not**
  depend on the deadline (which may be null). Written via the now-**atomic**
  `createTaskWithId` (Firestore transaction: get→if-exists-return-null→set). A
  duplicate spawn is a silent no-op. Lineage is stored as `recurrenceRootId`
  (root task id, propagated down the chain) + `occurrenceKey` (the successor's
  due-date key, for display).
- **Path A (Cloud Function):** `get→set` replaced by an **atomic `ref.create()`**
  (throws `ALREADY_EXISTS` → skip). Roster notification runs **only when create
  actually succeeded**, and each notification uses a **deterministic id**
  (`autoassign_{taskId}_{uid}`) written with `set`, so a re-run can never
  double-notify.
- **Scheduler:** `generateShiftTaskInstances` and `runTaskReminders` run with
  `maxInstances: 1` (no overlap) + explicit `retryCount: 0` + `timeoutSeconds`.

---

## 4. Automation Center (extends the existing collection)

No new backend. `recurringTaskTemplates/{id}` gains **operational metadata**
(additive, no migration):

| Field | Writer | Meaning |
|---|---|---|
| `updatedBy` | client | who last edited the routine |
| `lastRunAt` | Cloud Function | last generation attempt |
| `nextRunAt` | Cloud Function | next scheduled generation (computed) |
| `lastStatus` | Cloud Function | `completed` / `skipped` / `failed` |
| `lastGeneratedTaskId` | Cloud Function | the last instance produced |
| `failureCount` | Cloud Function | consecutive failures (reset on success) |

The existing **Manage Recurring Shift Tasks** sheet is the Automation Center; no
new route or feature module exists. Branch Operations exposes it through a visible
branch-scoped Automation summary (active/paused counts + earliest check), and the
sheet renders one rich card per routine: active/paused/error state, human schedule,
next check, generation outcome, failure count and a link to
`lastGeneratedTaskId`. Create, pause/resume and delete still use the existing
`TaskCubit` paths. Client `toMap` writes only `updatedBy` — the rollups are
Cloud-Function-owned (like `version`/`createdAt`), so a client edit can't regress
them. Template read failures render an error/retry state; they are not treated as
an empty branch.

The presentation is deliberately honest about backend gaps:

- `nextRunAt` is labelled **Next automation check**, not guaranteed publish time;
  the current 24-hour scheduler makes it advisory.
- Templates do not carry a frozen start/end window, so the Shift window row says
  that exact hours are unavailable instead of inferring configurable roster hours.
- Automatic `Missed` does not exist yet (`TaskStatus` has no such state and
  generated tasks have no deadline), so the neutral policy row says **Not enabled**
  and explains that tasks currently remain open.
- `lastStatus` describes the **generator** (`completed` / `skipped` / `failed`),
  not employee task completion; the UI therefore says Generated successfully,
  Already generated or Last generation failed.

---

## 5. Automation History (`automationRuns`)

Operational execution telemetry — **distinct from `audit_logs`** (business facts).
Written by the Cloud Function per (template, day) at a **deterministic id**
`{templateId}_{yyyy-MM-dd}`, so the history is itself idempotent (a retry
overwrites the run row, never appends a duplicate):

```
automationRuns/{templateId}_{dateKey}
  templateId, branchId, dateKey
  startedAt, finishedAt, durationMs
  executionId            // per-invocation correlation id
  status                 // completed | skipped | failed
  outcome                // created | alreadyExists | noEligibleEmployees | error
  generatedTaskId, recipientCount, failureReason
```

This is the server-side debugging record, but the Flutter app currently has **no
reader** for it; the Automation Center reads only the template rollups in §4.
Runs older than `config/taskRetention.automationRunRetentionDays` (default 90)
are pruned by the daily `taskHousekeeping` sweep (bounded, idempotent), so the
collection stays small. Until a concrete operational decision needs the history,
the missing reader remains accepted debt under ADR-009.

## 6. Audit events (reuses Event Tracking — no parallel system)

Business-meaningful automation facts are written to the existing `audit_logs`
collection (Admin SDK, `actorId: "system"`), via new `AuditEventType`s:
`task.auto_generated`, `automation.assigned`, `automation.failed`
(+ `automation` `AuditEntityType`). `automationRuns` (§5) is operational run
telemetry, not audit — the two are complementary, mirroring how `taskReminders`
and `broadcastSchedules` already sit beside `audit_logs`.

---

## 7. Automatic assignment flow (documented + hardened)

```
Shift task generated (assignmentType: shift, assigneeIds: [])
        ↓
weekly_schedules/{branch}_{weekStart}.assignments[day][shift]  → rostered uids
        ↓  FILTER (new)
  drop on-leave uids (leave[day][uid]) · drop inactive users (isActive == false)
        ↓
eligible recipients → one deterministic notification each
        ↓
(none eligible) → run recorded outcome: noEligibleEmployees (task still created)
```

Previously the raw roster was notified (on-leave / deactivated employees
included) and an empty roster failed silently. Now the roster is filtered and the
"no eligible employees" case is a first-class recorded outcome.

---

## 8. Firestore

- `recurringTaskTemplates`: +6 additive fields (§4). Existing rules unchanged.
- `tasks`: +`recurrenceRootId` / `occurrenceKey` (additive, nullable).
- `automationRuns/{id}`: **new** — read: admin, or manager of the run's branch;
  **write: server-only** (`allow write: if false`; the Admin SDK bypasses rules).
- No composite indexes required (single-field reads only).

## 9. Cloud Function summary (`generateShiftTaskInstances`)

Atomic `create` (dedup) · notify-on-create-only with deterministic notif ids ·
roster filtering (active + not-on-leave) · `automationRuns` history ·
`recurringTaskTemplates` rollups · `audit_logs` events · `maxInstances:1` +
`retryCount:0` + `timeoutSeconds`. **UTC date key** is kept deliberately (a
Cloud Function has no per-branch local time; determinism is the priority — a
branch-local "today" is a noted P2).

---

## 10. Deferred (P2 — not built)

- Automation **Dashboard** as a separate analytics surface → folded into the
  Center for this team size.
- `assignmentStrategy` scaffolding for future non-broadcast strategies.
- Branch-local timezone "today".
- Monthly recurrence for **shift** templates (per-task recurrence already has it).
- Firestore-native TTL on `automationRuns` (today a bounded `taskHousekeeping`
  age-prune covers it — `automationRunRetentionDays`, default 90).

## 11. Deploy checklist (owner's machine)

1. `firebase deploy --only functions:generateShiftTaskInstances,functions:runTaskReminders,functions:taskHousekeeping`
2. `firebase deploy --only firestore:rules` (the new `automationRuns` block)
3. No data migration — every new field is additive and defaults cleanly.
