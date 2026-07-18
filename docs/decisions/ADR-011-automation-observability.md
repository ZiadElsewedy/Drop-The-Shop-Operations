# ADR-011 — Automation execution observability (a scoped carve-out of ADR-009/010)

**Status:** Accepted · **Date:** 2026-07-18

## Context

The Automated Task Engine (recurring shift-task generation) has run
server-side since [ADR-005](ADR-005-server-authoritative-writes.md), writing a
thin per-run row to `automationRuns/{templateId}_{dateKey}` and rollups onto the
template. But that history had **no client reader** — accepted debt under
[ADR-009](ADR-009-no-analytics-pipeline.md) — and the row was too thin to debug a
run: it recorded an outcome, not *why* that outcome, *who* was targeted, *what*
was validated, or *where* a failure occurred. Automation definition edits
(pause / resume / config change / delete) wrote **no audit at all**.

The owner asked for production-grade observability: for any run, answer *did it
execute, when, why, who was targeted, what was generated/notified, what was
validated, did it fail and at which step, how long did it take.*

This pulls against two standing decisions:

- **[ADR-009](ADR-009-no-analytics-pipeline.md)** — no analytics pipeline; a
  metric may not be built without naming the decision it changes.
- **[ADR-010](ADR-010-lean-over-enterprise.md)** — lean, not enterprise SaaS.

## Decision

Draw a line: **operational observability of executions is in scope; a
time-series analytics/replay platform is not.** "Did this run, and why did it do
what it did" is debugging infrastructure. "Chart automation throughput over
quarters" is the analytics shape ADR-009 rejected. We build the former.

This ADR **names the decision it changes** (ADR-009's "no reader / no metric"),
as ADR-009 requires, and scopes the reversal narrowly:

**In scope (built):**
- Enrich the existing `automationRuns/{templateId}_{dateKey}` row (same one write
  per template per day — richer payload, not more writes) with structured
  blocks: `schedule`, `validations[]` (each pass/fail/skipped), `target` (uids +
  **names** + explicit `matched`), `generation`/`generated`, `notification`,
  a structured `error` (stage · code · retryable · recovered), and an
  **embedded** chronological `logs[]` step timeline.
- **Cumulative health counters** on the template (`runCount`, `successCount`,
  `failedCount`, `skippedCount`, `totalDurationMs`, `lastSuccessAt`,
  `lastFailureAt`, `configVersion`), incremented O(1) per run. Success rate and
  average duration are **derived on the client** (`AutomationHealth`) and never
  stored — that is the ADR-009 line.
- **Server-derived lifecycle audit** (`onRecurringTemplateWritten`): the client
  mutates the template directly and never writes its own audit
  ([ADR-005](ADR-005-server-authoritative-writes.md)); the trigger diffs
  before/after and appends `automation.created|paused|resumed|config_changed|
  deleted` to `audit_logs` with the change set.
- A **thin client read layer** (`AutomationRunEntity` + `AutomationRunModel` +
  `TaskRepository.getAutomationRuns` + paginated cursor) — the data foundation
  for a future Details screen. **No screen** is built in this phase.

**Out of scope (declined as the enterprise shape):**
- Per-run Firestore read/write counters, CF version / region / cold-start
  metadata, stored stack traces.
- A **replay engine** (re-executing a past run risks double-creation).
- Any standalone analytics/time-series surface — that remains ADR-009 territory.

## Consequences

- **Cost is near-zero at steady state.** The run write count is unchanged (richer
  payload, same one `set(merge)` per template/day); health counters fold into the
  existing rollup write; the lifecycle trigger costs 1 read + 1 write per *human*
  template edit (rare). A Details screen reads 1 template doc + a 20-row page.
- **Idempotency preserved.** Deterministic run id (retry overwrites, never
  appends); the lifecycle trigger is idempotent (audit id derived from the
  CloudEvent id) and terminates (`configVersion` is excluded from the diff, so a
  generation run's rollup write produces no audit and no version bump).
- **New indexes:** `automationRuns` `(branchId, templateId, startedAt desc)` for
  the paginated per-template history (branchId is filtered because the rules gate
  a manager's read on `branchId == selfBranch`), and `(branchId, status,
  startedAt desc)` for a future branch-failure view.
- **`automationRuns` reader debt (ADR-009) is retired** under this decision.
- If a future need for genuine analytics appears, it needs its **own** ADR — this
  one does not authorize it.

## Alternatives considered

- **Logs as a subcollection** (`automationRuns/{id}/logs/{n}`) — rejected: a run
  has ~7–12 bounded steps («1MB), so embedding renders the whole timeline in one
  read; a subcollection only pays off at thousands of steps, which cannot occur.
- **Runs as a template subcollection** — rejected: the top-level collection
  already carries the CF writer, rules, and retention; moving it would be a
  rewrite for no gain and breaks "extend, don't rewrite."
- **Computing health by aggregating runs on read** — rejected: unbounded reads
  and effectively an analytics query; incremental counters are O(1).
