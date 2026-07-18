"use strict";

const crypto = require("crypto");

// Pure helpers for the Automated Task Engine's execution records — no Firebase,
// no I/O, so they are unit-testable in isolation (see test/automation_run.test.js)
// and are the SINGLE source of the run-record shape that
// `generateShiftTaskInstances` writes. The Cloud Function does the I/O (reads,
// creates, notifications) and calls these to classify the result, so the
// observability contract stays deterministic and testable.
//
// See docs/design/AUTOMATION_ENGINE.md and docs/decisions/ADR-011.

// Log-step severities. `info` = normal progress, `warning` = a soft failure the
// run recovered from (e.g. notify failed but the task exists), `error` = the
// stage that failed the run.
const SEVERITY = { info: "info", warning: "warning", error: "error" };

// Validation results. A validation that could not be reached (an earlier stage
// short-circuited) is `skipped`, never silently omitted — an admin must be able
// to tell "passed" from "never checked".
const VALIDATION = { pass: "pass", fail: "fail", skipped: "skipped" };

// One chronological execution-log entry. `atMs` is epoch-millis (the caller
// converts to a Firestore Timestamp); `meta` is optional structured context.
function logStep(atMs, stage, severity, message, meta = null) {
  return {
    at: atMs,
    stage: String(stage),
    severity: severity || SEVERITY.info,
    message: String(message),
    meta: meta || null,
  };
}

// Builds the ordered validation block from what the run observed. Each check is
// pass/fail/skipped; a check downstream of a failure is `skipped` so the record
// distinguishes "not applicable this run" from "passed".
//   templatePresent  — the template row parsed (always true if we got here)
//   branchPresent    — the template names a branch
//   scheduleExists   — the (branch, week) weekly_schedules doc was found
//   employeesFound   — at least one eligible recipient resolved
function buildValidations({
  templatePresent,
  branchPresent,
  scheduleExists,
  employeesFound,
}) {
  const v = (name, result) => ({ name, result });
  const validations = [
    v("templateExists", templatePresent ? VALIDATION.pass : VALIDATION.fail),
    v("branchExists", branchPresent ? VALIDATION.pass : VALIDATION.fail),
  ];
  // Schedule/employees are only meaningful once the branch is known.
  if (!branchPresent) {
    validations.push(v("scheduleValid", VALIDATION.skipped));
    validations.push(v("employeesFound", VALIDATION.skipped));
    return validations;
  }
  validations.push(
    v(
      "scheduleValid",
      scheduleExists == null
        ? VALIDATION.skipped
        : scheduleExists
          ? VALIDATION.pass
          : VALIDATION.fail,
    ),
  );
  validations.push(
    v(
      "employeesFound",
      employeesFound == null
        ? VALIDATION.skipped
        : employeesFound
          ? VALIDATION.pass
          : VALIDATION.fail,
    ),
  );
  return validations;
}

// Transient gRPC/Firestore status codes worth a retry vs. a terminal bug.
// (4 DEADLINE_EXCEEDED · 8 RESOURCE_EXHAUSTED · 10 ABORTED · 13 INTERNAL ·
// 14 UNAVAILABLE.) ALREADY_EXISTS (6) is never an error here — it is the
// idempotency skip — so it is intentionally not in this set.
const RETRYABLE_CODES = new Set([4, 8, 10, 13, 14]);
const RETRYABLE_NAMES = new Set([
  "deadline-exceeded",
  "resource-exhausted",
  "aborted",
  "internal",
  "unavailable",
]);

// Normalizes a thrown value into the run's structured `error` block. `stage` is
// the step that failed (e.g. "generate", "notify"). `recovered` marks a failure
// the run continued past (a warning) rather than one that failed the run.
function classifyError(err, stage, { recovered = false } = {}) {
  if (err == null) return null;
  const code =
    (err.code != null ? err.code : err.status != null ? err.status : null);
  const message = String((err && err.message) || err);
  const retryable =
    (typeof code === "number" && RETRYABLE_CODES.has(code)) ||
    (typeof code === "string" && RETRYABLE_NAMES.has(code));
  return {
    stage: String(stage),
    code: code == null ? null : code,
    message,
    retryable,
    recovered: !!recovered,
  };
}

// The cumulative health-counter deltas to merge onto the template after a run.
// Returned as plain numbers/flags; the Cloud Function maps these to
// `FieldValue.increment` / server timestamps (keeping this module I/O-free).
// `status` is completed | skipped | failed.
function healthDeltas(status, durationMs) {
  const dur = Number.isFinite(durationMs) && durationMs >= 0 ? durationMs : 0;
  const failed = status === "failed";
  return {
    runCountDelta: 1,
    successCountDelta: status === "completed" ? 1 : 0,
    skippedCountDelta: status === "skipped" ? 1 : 0,
    failedCountDelta: failed ? 1 : 0,
    totalDurationMsDelta: dur,
    // `failureCount` is CONSECUTIVE failures: increment on failure, reset to 0
    // on any non-failure (mirrors the pre-existing rollup semantics).
    resetConsecutiveFailures: !failed,
    markLastSuccess: status === "completed",
    markLastFailure: failed,
  };
}

// Execution delay: how late the actual run started vs. its scheduled tick.
// Clamped at 0 (a run can't start before it was scheduled in any meaningful
// sense; clock skew shouldn't surface as negative delay).
function executionDelayMs(scheduledAtMs, actualAtMs) {
  if (!Number.isFinite(scheduledAtMs) || !Number.isFinite(actualAtMs)) return 0;
  return Math.max(0, actualAtMs - scheduledAtMs);
}

// A globally-unique, human-readable correlation id for one automation execution
// (one template on one day): `AUT-{yyyymmdd}-{6-hex hash of templateId}`. It is
// stamped on every resource the run produces — the run record, the generated
// task, its notifications, and its audit events — so any one of them can trace
// back to the whole execution. **Deterministic** (derived from templateId +
// dateKey, not a counter): a scheduler retry re-computes the identical id, so the
// task created on the first pass and the run row rewritten on a retry always
// share it. A sequence like `-000241` would need a counter doc (extra write +
// contention) and could not be reproduced idempotently, so it is deliberately
// not used.
function correlationId(templateId, dateKey) {
  const compact = String(dateKey || "").replace(/-/g, "");
  const hash = crypto
    .createHash("sha1")
    .update(String(templateId || ""))
    .digest("hex")
    .slice(0, 6)
    .toUpperCase();
  return `AUT-${compact}-${hash}`;
}

// Assembles the immutable **execution snapshot** embedded in a run — exactly what
// existed at execution time, so an old run renders correctly forever even after
// the template, branch, employees, schedule, or checklist change. Only immutable
// primitives are stored (never full user/branch documents): identity + version,
// the task blueprint, the schedule, branch id+name, and lightweight recipients
// (`uid` · `displayName` · `role` · `assignedShift`). Pure — the caller resolves
// `branchName` and `recipients` via I/O and passes them in.
function buildExecutionSnapshot({
  templateId,
  name,
  version = 1,
  checklistCount = 0,
  priority = "normal",
  proofRequired = false,
  scheduleType = "daily",
  days = [],
  shift = null,
  branchId = null,
  branchName = null,
  timezone = "UTC",
  recipients = [],
}) {
  return {
    automation: { id: templateId, name: name || "", version },
    template: {
      id: templateId,
      name: name || "",
      version,
      checklistCount,
      priority,
      proofRequired: !!proofRequired,
    },
    schedule: {
      type: scheduleType,
      days,
      shift,
      branchId,
      timezone,
    },
    target: { branchId, branchName },
    recipients: recipients.map((r) => ({
      uid: r.uid,
      displayName: r.name || r.uid,
      role: r.role || null,
      assignedShift: shift,
    })),
    recipientCount: recipients.length,
  };
}

module.exports = {
  SEVERITY,
  VALIDATION,
  logStep,
  buildValidations,
  classifyError,
  healthDeltas,
  executionDelayMs,
  correlationId,
  buildExecutionSnapshot,
};
