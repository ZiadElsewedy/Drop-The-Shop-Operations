"use strict";

const test = require("node:test");
const assert = require("node:assert");
const {
  VALIDATION,
  buildValidations,
  classifyError,
  healthDeltas,
  executionDelayMs,
  logStep,
} = require("../automation_run");

test("validations: all pass when everything resolved", () => {
  const v = buildValidations({
    templatePresent: true,
    branchPresent: true,
    scheduleExists: true,
    employeesFound: true,
  });
  assert.deepStrictEqual(
    v.map((x) => `${x.name}:${x.result}`),
    [
      "templateExists:pass",
      "branchExists:pass",
      "scheduleValid:pass",
      "employeesFound:pass",
    ],
  );
});

test("validations: missing branch skips (not fails) the downstream checks", () => {
  const v = buildValidations({
    templatePresent: true,
    branchPresent: false,
    scheduleExists: null,
    employeesFound: null,
  });
  const byName = Object.fromEntries(v.map((x) => [x.name, x.result]));
  assert.strictEqual(byName.branchExists, VALIDATION.fail);
  assert.strictEqual(byName.scheduleValid, VALIDATION.skipped);
  assert.strictEqual(byName.employeesFound, VALIDATION.skipped);
});

test("validations: no schedule doc fails scheduleValid and skips employees", () => {
  const v = buildValidations({
    templatePresent: true,
    branchPresent: true,
    scheduleExists: false,
    employeesFound: null,
  });
  const byName = Object.fromEntries(v.map((x) => [x.name, x.result]));
  assert.strictEqual(byName.scheduleValid, VALIDATION.fail);
  assert.strictEqual(byName.employeesFound, VALIDATION.skipped);
});

test("validations: schedule present but nobody eligible fails employeesFound", () => {
  const v = buildValidations({
    templatePresent: true,
    branchPresent: true,
    scheduleExists: true,
    employeesFound: false,
  });
  const byName = Object.fromEntries(v.map((x) => [x.name, x.result]));
  assert.strictEqual(byName.scheduleValid, VALIDATION.pass);
  assert.strictEqual(byName.employeesFound, VALIDATION.fail);
});

test("classifyError: null in, null out", () => {
  assert.strictEqual(classifyError(null, "generate"), null);
});

test("classifyError: transient code is retryable", () => {
  const e = classifyError({ code: 14, message: "backend unavailable" }, "generate");
  assert.strictEqual(e.stage, "generate");
  assert.strictEqual(e.code, 14);
  assert.strictEqual(e.retryable, true);
  assert.strictEqual(e.recovered, false);
});

test("classifyError: string status name is retryable", () => {
  const e = classifyError({ code: "unavailable", message: "x" }, "notify");
  assert.strictEqual(e.retryable, true);
});

test("classifyError: a plain bug is terminal and can be marked recovered", () => {
  const e = classifyError(new Error("bad map"), "notify", { recovered: true });
  assert.strictEqual(e.retryable, false);
  assert.strictEqual(e.recovered, true);
  assert.strictEqual(e.code, null);
  assert.match(e.message, /bad map/);
});

test("healthDeltas: a completed run counts success and resets consecutive failures", () => {
  const d = healthDeltas("completed", 1200);
  assert.strictEqual(d.runCountDelta, 1);
  assert.strictEqual(d.successCountDelta, 1);
  assert.strictEqual(d.failedCountDelta, 0);
  assert.strictEqual(d.totalDurationMsDelta, 1200);
  assert.strictEqual(d.resetConsecutiveFailures, true);
  assert.strictEqual(d.markLastSuccess, true);
  assert.strictEqual(d.markLastFailure, false);
});

test("healthDeltas: a failed run counts failure and does NOT reset consecutive", () => {
  const d = healthDeltas("failed", 50);
  assert.strictEqual(d.failedCountDelta, 1);
  assert.strictEqual(d.successCountDelta, 0);
  assert.strictEqual(d.resetConsecutiveFailures, false);
  assert.strictEqual(d.markLastFailure, true);
});

test("healthDeltas: a skipped run is neither success nor failure but resets consecutive", () => {
  const d = healthDeltas("skipped", 10);
  assert.strictEqual(d.skippedCountDelta, 1);
  assert.strictEqual(d.successCountDelta, 0);
  assert.strictEqual(d.failedCountDelta, 0);
  assert.strictEqual(d.resetConsecutiveFailures, true);
});

test("healthDeltas: a negative/NaN duration is coerced to 0", () => {
  assert.strictEqual(healthDeltas("completed", -5).totalDurationMsDelta, 0);
  assert.strictEqual(healthDeltas("completed", NaN).totalDurationMsDelta, 0);
});

test("executionDelayMs: positive delay, clamped at 0 for early/invalid", () => {
  assert.strictEqual(executionDelayMs(1000, 4000), 3000);
  assert.strictEqual(executionDelayMs(4000, 1000), 0);
  assert.strictEqual(executionDelayMs(NaN, 1000), 0);
});

test("logStep: shape carries timestamp, stage, severity, message, meta", () => {
  const s = logStep(42, "generate", "info", "Task created", { taskId: "t1" });
  assert.deepStrictEqual(s, {
    at: 42,
    stage: "generate",
    severity: "info",
    message: "Task created",
    meta: { taskId: "t1" },
  });
});
