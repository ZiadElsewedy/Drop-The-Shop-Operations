"use strict";

const test = require("node:test");
const assert = require("node:assert");
const { isAutoCloseDue } = require("../attendance_auto_close");

// Fixed clock + the default knobs (2h grace, 16h max session), in millis.
const NOW = Date.UTC(2026, 6, 13, 20, 0, 0); // 2026-07-13 20:00 UTC
const GRACE = 120 * 60 * 1000;
const MAX = 16 * 60 * 60 * 1000;

function due(overrides) {
  return isAutoCloseDue({
    nowMs: NOW,
    graceMs: GRACE,
    maxSessionMs: MAX,
    ...overrides,
  });
}

test("scheduled session past end + grace is due", () => {
  // Ended 3h ago (> 2h grace).
  assert.strictEqual(due({ scheduledEndMs: NOW - 3 * 3600e3 }), true);
});

test("scheduled session still inside the grace window is NOT due", () => {
  // Ended 1h ago (< 2h grace).
  assert.strictEqual(due({ scheduledEndMs: NOW - 1 * 3600e3 }), false);
});

test("unscheduled session past the max cap is due (R7 safety net)", () => {
  // No scheduledEnd; clocked in 17h ago (> 16h cap).
  assert.strictEqual(due({ clockInMs: NOW - 17 * 3600e3 }), true);
});

test("unscheduled session under the max cap is NOT due", () => {
  // No scheduledEnd; clocked in 10h ago (< 16h cap).
  assert.strictEqual(due({ clockInMs: NOW - 10 * 3600e3 }), false);
});

test("a scheduled session under grace but past the max cap still closes", () => {
  // Odd overnight case: scheduledEnd only 30m ago (under grace) but the person
  // clocked in 20h ago — the safety net catches it.
  assert.strictEqual(
    due({ scheduledEndMs: NOW - 30 * 60e3, clockInMs: NOW - 20 * 3600e3 }),
    true,
  );
});

test("an already clocked-out session is never due (no double close)", () => {
  assert.strictEqual(
    due({ scheduledEndMs: NOW - 5 * 3600e3, clockOutMs: NOW - 4 * 3600e3 }),
    false,
  );
});

test("a soft-deleted session is never due", () => {
  assert.strictEqual(
    due({ scheduledEndMs: NOW - 5 * 3600e3, deleted: true }),
    false,
  );
});

test("a session with neither a scheduled end nor a clock-in is not due", () => {
  assert.strictEqual(due({}), false);
});

test("exactly at the max cap boundary is due (>= comparison)", () => {
  assert.strictEqual(due({ clockInMs: NOW - MAX }), true);
});
