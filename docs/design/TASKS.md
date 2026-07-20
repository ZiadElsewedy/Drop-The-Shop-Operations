# Tasks — the operations workflow

The core of DROP. A manager/admin creates work, an employee executes it, a
manager/admin reviews it. Everything else in the app orbits this.

Covers `features/task/` and `features/operations/` (the branch cockpit that reads
the same stream).

## Lifecycle

```
pending ──start──► started ──submit──► waitingReview ──approve──► approved
                      ▲                      │
                      └────── reject ────────┘  (rework: revisionNumber++)

pending / started ──shift deadline──► missed  (generated recurring shift task only)
```

`approved` and `missed` are terminal. An admin may reopen an approved task;
`missed` is a server-owned operational record and remains closed. Statuses live in
`core/enums/task_status.dart`; the status → colour mapping has exactly one home,
`core/widgets/status_badge.dart` (`taskStatusColor`).

### Transitions are transactional

Every move goes through **`TaskRepository.transitionTask`**, a Firestore transaction
that:

1. re-reads the doc and **verifies the expected predecessor status**,
2. appends the `ActivityEntry` to the **server's** current log,
3. bumps the additive `TaskEntity.version`.

A stale or concurrent move raises `ConflictFailure`. This fixed a real
concurrent-reviewer race where two managers could both approve and one decision
vanished. See [ADR-005](../decisions/ADR-005-server-authoritative-writes.md).

> **Never split a status change and its activity entry into two writes.** That bug
> has been fixed once (2026-06-18) and the transaction is what keeps it fixed.

The one exception is the server-side recurring-shift expiry sweep. Every 15 minutes
`autoEndRecurringShiftTasks` re-reads each due candidate in an Admin-SDK
transaction. Only a live generated instance (`sourceTemplateId` present) still in
`pending` or `started` can become `missed`; it appends the system activity entry,
sets `missedAt`, and increments `version` in that same write. It never turns
unfinished work into `completed`, `waitingReview`, or `approved`. Firestore rules
make `missed`/`missedAt` server-only and lock the record against client reopen or
deletion.

Recurrence respawn happens **post-commit**, so only the winning reviewer spawns the
next instance (`rec_{sourceTaskId}` — a deterministic id, which is what stops the
reopen → re-approve duplicate).

## Assignment

`assignmentType` (`core/enums/task_assignment_type.dart`) has three modes:

| Mode | Target | Visible to |
| --- | --- | --- |
| `individual` | named people | those people |
| `team` | named people | those people |
| `shift` | a **shift**, not a person | whoever is rostered on it **today** |

`shift` mode is the interesting one: the task belongs to the Morning or Night crew,
and who that is changes daily. Visibility resolves through the single pure gate
[`domain/task_access.dart`](../../lib/features/task/domain/task_access.dart)
(`canUserAccessTask`) — mirrored in `firestore.rules`, and the only place this
question is answered.

`assigneeIds[]` is canonical (multi-assignee); `assignedEmployeeId` is a
**denormalized mirror** of the primary that rules and statistics depend on — keep
them in sync on write.

### Recurring shift routines

These use a **template → generated instance** split, *not* the per-task
`RecurrenceConfig`:

```
recurringTaskTemplates/{id}   ← the blueprint (branch-scoped, active flag)
        │  generateShiftTaskInstances (onSchedule 24h, roster-filtered, atomic)
        ▼
tasks/rt_{templateId}_{yyyy-MM-dd}   ← the deterministic id IS the dup guard
```

The client also materializes "today" best-effort (`_materializeTodayInstance`,
unawaited) so a new template is usable before the scheduler runs. The template write
is the Save boundary — see `recurring_shift_task_sheets.dart` (single-modal
Manage → Add; never stack bottom sheets).

Every generated instance persists its exact `instanceDate`, `startsAt`, and
`deadline`. The generator and the client materializer resolve the week slot using
the saved weekly schedule in the same order as attendance: per-day `shiftHours`
override → frozen `shiftPlan` → `ShiftHours.standard`. The saved `weekStart`
instant is the local-midnight anchor, so a configured 08:30–16:30 Morning shift is
actually due at that shift end (and night windows may cross midnight). The task id
remains UTC-keyed for existing duplicate protection; the deadline itself is an
absolute timestamp.

At or after that persisted deadline, `autoEndRecurringShiftTasks` marks an
unfinished generated task **Missed**. A normal task that merely has a past deadline
remains a derived **Overdue** phase — it is not auto-closed. The expiry query needs
the deployed `tasks` composite index
`assignmentType` + `status` + `deadline`; its transaction revalidation means a
simultaneous employee submission wins instead of being overwritten. Missed records
leave active queues immediately and follow the ordinary task-retention window.

⚠️ The employee shift-task **stream** needs the `tasks` composite index
(`branchId`+`assignmentType`+`shift`) — it fails `failed-precondition` until
deployed.

## Scheduling (V2)

`startsAt` + `dueAt` (the due side is the existing `deadline`, aliased). Both
additive — no migration.

Create-mode quick deadline presets (`Tomorrow` / `2 days` / `Week`) sit on a
compact duration rail and set `startsAt` to the current creation time and `dueAt`
to +1/+2/+7 days. They are deadline presets, not shift suggestions, so
outside-shift-hours warnings do not apply to those windows. Picking one moves the
rail thumb and animates the duration rail under the Start/Due rows.

**`TaskSchedulePhase` is derived, not persisted** — Scheduled / Active / Due-soon /
Overdue / Done, computed from the times + lifecycle in pure
`domain/task_schedule.dart`. It is not a replacement for lifecycle state:
`TaskStatus.missed` is the narrow server-only terminal result for an expired
generated recurring shift task, while **Overdue** remains a derived phase for any
other open task.

Smart defaults pre-fill start/due from the assigned shift's hours
(`shiftDefaultSchedule`) as a *suggestion that is never locked*. For
individual/team, `TaskCubit.resolveAssigneeShift` reads the branch roster and the
pure `assigneeShiftFit` decides: unanimous → suggest · mixed → a Morning/Night/Custom
chooser · none → manual. The banner keeps the **original** shift after edits
("Originally: …"). Due-before-start is blocking; outside-shift-hours is a warning.

## Work types

Polymorphic tasks via **Strategy + Registry**. Adding a type is **1 file + 1 line**
(open/closed). `workType` + `data` are additive; an unknown type degrades to
`general` rather than crashing. `TaskWorkX` is the only adapter seam — all save
paths are identical.

## Composition

`TaskCubit` is the hybrid described in [ADR-002](../decisions/ADR-002-cubit-only.md):

| Concern | Path |
| --- | --- |
| Writes | use cases (`CreateTask`, `UpdateTask`, `AssignTask`, `UploadTaskAttachment`, …) |
| Realtime lists | `TaskRepository.watch{AllTasks,TasksByBranch,EmployeeTasks}` directly |
| Templates | `TaskRepository` directly |
| Admin branch picker | `BranchRepository` directly |
| Employee's shift(s) today | `ScheduleRepository` directly |

It also warms a per-branch **user directory** (`_ensureDirectory` via
`GetUsersByBranch`) so cards render real names and avatars instead of uids.

## Ordering

Admin query uses Firestore `orderBy('createdAt', descending: true)` (index-free).
**Filtered branch/employee queries stay filter-only** — a filter + `orderBy` needs a
composite index, which broke loading and was reverted. They are ordered in Dart by
`sortTasksNewestFirst` ([`domain/task_ordering.dart`](../../lib/features/task/domain/task_ordering.dart),
pending-timestamp on top). This is a deliberate Firebase trade
([ADR-001](../decisions/ADR-001-firebase-backend.md)) — don't "optimize" it back
into the query without adding the index.

## Media

All uploads go through the single seam `core/media/media_upload_service.dart`.

- `TaskAttachment` (+ `AttachmentLimits`), attached to `ActivityEntry.attachments[]`.
- Mobile-only pre-upload editing: crop/rotate/flip (`image_cropper`) and video
  transcode (`video_compress`), gated on `supportsImageEditing` /
  `supportsVideoCompression` — desktop uploads are untouched.
- Submission uploads run through `mapPooled` (concurrency cap 3, fixed-denominator
  progress).
- **Cancellable:** the overlay's Cancel → `TaskCubit.cancelSubmission()` aborts every
  in-flight upload via `UploadCanceller`, hidden during `finalizing` so the Firestore
  write can't be orphaned mid-commit.
- **Partial retry:** a per-task `_uploadedCache` re-uploads only what didn't already
  succeed.
- Video thumbnails are local and view-time (`video_thumbnail_image.dart`, LRU cache)
  — no server posters.

## Operations cockpit

`features/operations/` reads the same branch stream and derives, never writes
(writes stay in `TaskCubit`, so both see changes live).

`computeBranchWorkload` is pure and deterministic (`day`/`now` injectable): it joins
the task stream × `getUsersByBranch` × today's `weekly_schedule`, sorts
overload-first. The public predicates (`isOperationalActiveTask` / `…Overdue` /
`…PendingReview`) are shared by the headline counts **and** the drill lists, so a KPI
can never disagree with the list it opens.

## Retention

`taskHousekeeping` (onSchedule 24h) soft-archives approved tasks past
`archiveAfterDays` (`archivedAt`; clients filter it out), cold-tiers their Storage
media, and hard-deletes only under an opt-in `deleteAfterDays` purge. Owner ruling:
**soft-archive forever** is the default.

## Related

[DATA_MODEL](DATA_MODEL.md) · [SCHEDULE](SCHEDULE.md) ·
[AUTOMATION_ENGINE](AUTOMATION_ENGINE.md) · [AUDIT_LOG](AUDIT_LOG.md)
