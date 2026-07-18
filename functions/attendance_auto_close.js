"use strict";

// The pure auto-close decision for a still-open attendance session — no Firebase,
// no I/O, so it is unit-testable in isolation (see test/auto_close.test.js) and is
// the SINGLE source of the rule that `autoCloseAttendance` sweeps with.
//
// A session is closed when EITHER:
//   • it has a scheduled end and `scheduledEnd + grace` has passed (the normal
//     "forgot to clock out" case), OR
//   • it has been open longer than the max-session cap measured from clock-in —
//     the R7 safety net that catches an UNSCHEDULED session (no scheduledEnd) or
//     one running pathologically long.
//
// It is deliberately conservative: an already-closed (`clockOut`) or soft-deleted
// session is never due, so the sweep never overwrites a manual close and is safe
// to re-run (idempotent — the caller also filters on `status == inProgress`).
//
// All times are epoch-millis numbers; the caller converts Firestore Timestamps.
function isAutoCloseDue({
  clockOutMs = null,
  deleted = false,
  scheduledEndMs = null,
  clockInMs = null,
  nowMs,
  graceMs,
  maxSessionMs,
}) {
  // Already closed or removed — nothing to do (never overwrite a manual close).
  if (clockOutMs != null || deleted) return false;

  // Scheduled sessions: close once the scheduled end + grace has elapsed.
  if (scheduledEndMs != null && scheduledEndMs + graceMs <= nowMs) return true;

  // Safety net: any open session past the max duration from its clock-in.
  if (clockInMs != null && clockInMs + maxSessionMs <= nowMs) return true;

  return false;
}

module.exports = { isAutoCloseDue };
