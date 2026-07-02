# DROP — Production Readiness Audit (2026-07-02)

> Full-stack audit ahead of the beta release: security (rules + functions),
> performance, reliability, and release stability. Method: line-by-line review
> of `firestore.rules` (394 lines), `storage.rules`, all 10 Cloud Functions'
> authorization paths, every stream-owning cubit's lifecycle, the notification
> pipeline, and build smoke tests. Companion docs:
> [CURRENT_STATE.md](CURRENT_STATE.md) ·
> [UI_UX_AUDIT_2026-07-02.md](UI_UX_AUDIT_2026-07-02.md).

**Verdict: the architecture is sound for a small-scale internal beta.** The
rules model (admin ⊇ manager, branch isolation, server-only privileged writes)
is consistently applied; every callable checks caller role + branch; all
stream cubits cancel subscriptions and restore state on error; crash capture
and structured logging are release-active. The blockers are **deployment
state** and **two data-exposure decisions**, not code defects.

---

## 🔴 CRITICAL — resolve before beta

> **Deployed-state verification (2026-07-02, follow-up session):** the actual
> production state of project **`bazic-d9ad7`** was verified with read-only
> tooling — `firebase functions:list`, `firebase firestore:indexes`, and the
> Firebase Rules API (deployed ruleset sources fetched and **diffed
> byte-for-byte** against the repo). C1 below is now a **verified diff**, not
> an assumption; the original draft's claims about undeployed rules were
> WRONG and are retracted.

### C1 · Undeployed artifacts — verified diff vs. production

| Artifact | Deployed? | Evidence |
|---|---|---|
| `firestore.rules` | ✅ **CURRENT** (byte-identical) | ruleset `94591ea9…`, released 2026-07-01 23:40 UTC — salary freeze, shift-task rules, swap hardening, broadcast delete are all LIVE |
| `storage.rules` | ✅ **CURRENT** (byte-identical) | ruleset `f6997911…`, 2026-06-25; bucket `bazic-d9ad7.firebasestorage.app` exists → proof-upload infra is live |
| 9 of 10 Cloud Functions | ✅ deployed | all at 2026-06-26 22:04 UTC |
| **`tasks` composite index** (`branchId`+`assignmentType`+`shift`) | ❌ **MISSING** | deployed index list contains only the `notifications` index |
| **`generateShiftTaskInstances`** function | ❌ **MISSING** | absent from `functions:list`; the fleet deploy (2026-06-26) predates the 2026-07-01 shift-assignment commit |
| FCM per-token failure diagnostics (commit `8a2007b`, +26 lines in `sendBroadcast`/task-notify) | ❌ stale | committed 2026-06-27 01:11 (+03) — **7 minutes after** the 22:04 UTC fleet deploy |
| `firebase-functions` SDK `^6.1.0 → ^7.2.5` (same commit) | ❌ stale | deployed fleet built on v6 |

**C1a — the missing `tasks` index (worst production impact).** Every employee
rostered on today's schedule subscribes `watchShiftTasks` (branchId +
assignmentType + shift), which **fails `failed-precondition` without the
index**. `TaskCubit._subscribe`'s onError then emits `TaskState.error`, so
the employee's task screens show "Failed to load tasks" (recovering only when
another source stream emits) and **shift-assigned tasks never appear for
anyone**. The Shift Assignment feature is dead-on-arrival in production and
degrades the ordinary task list around it.
- **Command:** `firebase deploy --only firestore:indexes --project production`
- **Risk: LOW.** Additive; minutes to build on a small collection; no
  downtime (the query already fails today, so there is no "during migration"
  regression). Run interactively (no `--force`) and decline any prompt to
  delete indexes — the deployed `notifications` index is the same logical
  index in normalized form and must be kept.

**C1b — the missing `generateShiftTaskInstances` function.** Recurring shift
routines ("Open Store" daily) only ever get the single client-materialized
instance created the day the template is made; **no next-day instance is ever
generated**. Managers believe routines are scheduled; tomorrow nothing shows.
- **Command (surgical):**
  `firebase deploy --only functions:generateShiftTaskInstances --project production`
- **Risk: LOW–MEDIUM.** A *new* scheduled function (creates its Cloud
  Scheduler job automatically; every-24h; overlapping/duplicate runs are safe
  by design — instances use deterministic ids `rt_{templateId}_{yyyy-MM-dd}`,
  the existence check IS the dedup guarantee). The one caution: the build
  uses the repo's `firebase-functions ^7.2.5` (major bump vs. the deployed
  v6 fleet) — a surgical deploy scopes that bump to this one non-critical
  function first.

**C1c — the stale fleet (9 functions).** Behavior-identical to production
except the missing FCM diagnostics: per-token failure reasons
(`third-party-auth-error` = APNs missing vs. `registration-token-not-registered`
= stale token) and delivery counters — exactly the logging needed to debug
C3 during beta. No user-facing change.
- **Command:** `firebase deploy --only functions --project production`
  (converges all 10 on HEAD).
- **Risk: MEDIUM — the only genuinely risky deploy in the set.** It rebuilds
  the auth-critical callables (`createUserAccount`, `adminResetPassword`,
  `approveSwap`) on the major-bumped SDK. Mitigations: run C1b first (proves
  the v7 build path on a throwaway function), then the fleet; smoke-test
  immediately (create account · approve swap · send broadcast); rollback =
  redeploy from the last-deployed tree (`git stash && git checkout 8a2007b~1 -- functions/ && firebase deploy --only functions`)
  or shift Cloud Run traffic back to the previous revision.

**Recommended sequence (30 min total, off-hours):**
1. `firebase deploy --only firestore:indexes --project production` → wait for the index to go ACTIVE (console).
2. `firebase deploy --only functions:generateShiftTaskInstances --project production`.
3. Smoke: employee task list loads for a rostered employee; a shift task appears.
4. `firebase deploy --only functions --project production`.
5. Smoke: create test account · approve a swap · send a broadcast · complete a task with proof.

### C2 · Salary data is readable by every same-branch member

**The exact leak path.** `firestore.rules`, `users` read rule:

```
match /users/{uid} {
  allow read: if isOwner(uid)
    || isAdmin()
    || (selfBranch() != ''
        && resource.data.get('branchId', '') == selfBranch());   // ← this arm
```

Firestore read rules are **document-level** — field-level read filtering does
not exist — so the third arm serves the **entire** user document (salary
fields included) to any authenticated user whose own `branchId` matches. This
arm is load-bearing and cannot simply be removed: it is what lets the app
resolve "who's on my shift today".

**The data already flows to employee devices in normal app use** — no
attacker tooling required to put it on the wire:

1. [`user_remote_datasource.dart:44`](lib/features/auth/data/datasources/user_remote_datasource.dart:44)
   — `_users.where('branchId', isEqualTo: branchId).get()` (the
   `GetUsersByBranch` use case).
2. Called with an *employee* signed in by `ScheduleCubit._emitLoaded`
   (members for My Week / today's-team) and `TaskCubit` (assignee directory)
   — i.e. **every employee session downloads every same-branch user doc**.
3. [`user_model.dart:125`](lib/features/auth/data/models/user_model.dart:125)
   parses `salaryAmount` (and salaryType/paymentMethod/paymentNumber) into
   the in-memory `UserEntity`. The UI never renders a coworker's salary, but
   the values sit in memory and in the TLS payload — visible with DevTools,
   a debug proxy, or five lines of REST:

```
POST https://firestore.googleapis.com/v1/projects/bazic-d9ad7/databases/(default)/documents:runQuery
Authorization: Bearer <any employee's ID token>
{"structuredQuery":{"from":[{"collectionId":"users"}],
 "where":{"fieldFilter":{"field":{"fieldPath":"branchId"},
 "op":"EQUAL","value":{"stringValue":"<their-branch-id>"}}}}}
```

→ returns every same-branch coworker's `salaryAmount`, `salaryType`,
`paymentMethod`, `paymentNumber` (plus phone/address/emergencyContact — PII
that is arguably acceptable for a team directory, unlike pay). Note this
includes the **manager's own doc** (managers carry the same `branchId`), so
employees can read their manager's salary too. The 2026-07-01 rules deploy
does NOT help — the deployed freeze protects **writes**, not reads.

**Migration plan — `users/{uid}/private/compensation` subdocument.**
Four ordered phases, each independently shippable and rollback-safe:

1. **Rules (additive — can ride any deploy):**
   ```
   match /users/{uid}/private/{doc} {
     allow read: if isOwner(uid) || isAdmin();
     allow create: if isAdmin();
     allow update: if isAdmin()
       || (isOwner(uid) && doc == 'compensation'
           && request.resource.data.diff(resource.data)
                .affectedKeys().hasOnly(['paymentNumber']));
     allow delete: if false;
   }
   ```
   Preserves today's exact contract: admin writes everything;
   the employee may update only their own `paymentNumber`.
2. **Client dual-read/dual-write (~2–3 h):**
   `UserAdminRemoteDataSource.updateUserCompensation` +
   `ProfileRemoteDataSource` (paymentNumber) write the subdoc; reads prefer
   the subdoc and fall back to the legacy top-level fields. Compensation is
   fetched **on demand** (admin Details dialog, own Edit Profile — one read
   per open), never joined into the branch query. Cubit/UI surfaces
   unchanged.
3. **One-time migration (Admin SDK script, ~1 h):** for each user doc with
   any of the four fields → copy to `private/compensation`, then
   `FieldValue.delete()` the top-level fields. Idempotent; run after the
   client release so the fallback read never goes dark.
4. **Cleanup (~1–2 h):** drop the four fields from `UserModel` parsing, keep
   (harmless) or remove the freeze conditions in the `users` self-update
   rule, update `user_compensation_test` + docs.

Total ≈ **1 day**. There is **no cheaper mitigation** — rules cannot
field-filter reads, so any fix that keeps branch-member directory reads must
move the data. **Owner decision:** acceptable to defer through a
trusted-staff beta; must ship before any wider rollout.

### C3 · iOS push is dead until the entitlement lands (owner, Xcode)
Unchanged since 2026-06-26: no `aps-environment` entitlement / APNs key for
`com.example.fbro`. Every push (task assignment, broadcast, swap events) is
silently dropped on iOS; notification-tap navigation is unreachable there.
Android + inbox are unaffected. The step-by-step checklist is in
CURRENT_STATE.md ("iOS push action checklist"). **If beta includes iPhone
users, this is a blocker; macOS/Android-only beta can proceed.**

---

## 🟠 MEDIUM — schedule the fix, not blockers for a trusted beta

> **Why these are Medium and not Critical:** every item below either (a)
> requires a *malicious authenticated insider* using raw SDK/REST tooling —
> beta users are the owner's own staff — or (b) degrades quality/cost without
> corrupting data or crossing a privilege boundary. And not Low, because each
> has a concrete failure story with real operational or trust impact.

### M1 · A swap requester can forge the coworker-acceptance step
`shift_swaps` update permits either involved employee to set any status except
`managerApproved`. A malicious **requester** could set `employeeApproved`
directly (raw SDK), making the queue show "coworker accepted" without consent.
**Severity reasoning:** Medium, not Critical — the schedule itself cannot be
corrupted (final approval is function-only and `approveSwap` re-validates
slots/policy server-side); the harm is deceiving a human manager into
approving a trade the coworker never agreed to. Not Low — it defeats the
whole point of the two-step consent chain and needs only one curl command
from an insider. **Fix:** status-transition validation in the rule
(requester → `cancelled` only; target → `employeeApproved`/`rejected`;
manager → `rejected`). Pure rules change — can ride any deploy.

### M2 · Notification docs are client-created with sender trust
`notifications` create allows any signed-in user to write a notification to
**anyone** (only `senderUid` must be their own). Worse than inbox spam: the
deployed `onNotificationCreated` trigger **converts that doc into a real
push** — an insider can push arbitrary text (with deep-link `data`) to any
user's phone.
**Severity reasoning:** Medium, not Critical — insider-only, no data
exposure, no privilege escalation, and every forged doc permanently records
the forger's uid (`senderUid` is rules-enforced), so it's attributable. Not
Low because push-with-deep-link is a plausible phishing/disruption vector.
**Fix option (post-beta):** route task/swap notifications through a callable
like broadcasts, or constrain `type` + recipient patterns in rules.

### M3 · Task proof/attachment storage is app-wide readable + writable
`tasks/{taskId}/**` in Storage: any signed-in user may read/write.
**Overwriting `proof.jpg` at a known task id after approval is an
evidence-tamper vector**, and cross-branch reads of proof photos are
possible with a leaked id.
**Severity reasoning:** Medium, not Critical — task ids are unguessable
20-char auto-ids, and Firestore task docs (where ids are learned) are
branch-scoped, so the practical attacker is someone already inside the
branch; the activity log's original tokened URL partially mitigates tamper.
Not Low because review decisions trust these photos. Storage rules can't
consult Firestore cheaply — documented tradeoff. **Fix option:** random
per-attachment path tokens, or writes behind a function.

### M4 · Unbounded task streams
`watchAllTasks` (admin) and `watchTasksByBranch` stream their entire scope
with no `limit()`/date window.
**Severity reasoning:** Medium, not Critical — zero security impact and
correct behavior at the lean target scale (one store, tens of tasks/week);
it is a **cost/latency time bomb**, not a bug: at thousands of accumulated
tasks every admin session re-reads the full collection and holds it in
memory. Not Low because task documents accrete forever (approved tasks are
locked, never deleted), so this degrades monotonically. **Fix when it
matters:** date-window the streams (open tasks + last 30 days), page the
history.

### M5 · Employee shift-task subscription resolves "today" once
`TaskCubit._subscribeEmployeeShifts` resolves the employee's shifts for
**today at subscribe time**. An app left open across midnight keeps
streaming yesterday's shift scope until any reload.
**Severity reasoning:** Medium, not Low — the failure lands exactly on the
feature's flagship use case (the *morning opening checklist* is what's
invisible if the app sat open overnight), and the user sees nothing wrong —
no error, just a missing task. Not Critical — self-heals on any
background/foreground cycle, pull-to-refresh, or navigation, which happens
within minutes of real phone use. **Fix option:** re-resolve on app-resume
(lifecycle observer) — cheaper and more reliable than a midnight timer.

### M6 · Employee task-update rule allows content edits
An assigned employee may edit title/description/checklist **content** (rules
freeze assignees/branch/creator/review-status/attribution fields only).
**Severity reasoning:** Medium-by-courtesy, accepted — deliberate
internal-trust design consistent with M2's model; a hostile employee could
rewrite a task's instructions, but every status transition is recorded in
`activityLog` with actor attribution, and the blast radius is one branch's
task text. Not worth a rules-complexity explosion for a trusted-staff tool.
**Accept for beta; revisit only if the trust model changes.**

---

## 🟡 LOW — cosmetic / hygiene

- **L1** · `task_templates`/`broadcastTemplates` read: any manager reads every
  branch's templates (info leak of checklist/wording only).
- **L2** · "Temporary" `developer.log` diagnostics in `NotificationService`
  ship in release binaries (low volume; consider gating with `kDebugMode`).
- **L3** · Legacy social fields (follower/post counters) still in the profile
  schema — unused; remove post-beta.
- **L4** · `flutter analyze`: 7 pre-existing `prefer_initializing_formals`
  infos in `auth_cubit.dart` (style only).
- **L5** · Crash-report banner polls for the messenger (20×250 ms) — works,
  slightly inelegant.

---

## ✅ What the audit CONFIRMED healthy

**Security.** Admin-provisioned auth (client `create: if false` on users);
self-update freezes every privileged field (role/branch/isActive/position/
employmentStatus/createdBy + salary trio); managers never write user docs; all
four callables (`sendBroadcast`, `createUserAccount`, `adminResetPassword`,
`approveSwap`) verify caller role + branch server-side with forged-id
defenses; broadcast client writes are field-diff-locked to `archivedAt`;
approved tasks are locked records (no edit/delete; admin reopen only);
`managerApproved` swap status is function-only; FCM tokens are exclusively
owned (`claimFcmToken`) with per-recipient stamping + client drop-guard.

**Performance.** Rules `selfDoc()` get is cached per request. Repository
caches (branches 10-min TTL, templates 20-min) shared across all cubits;
idempotent loads everywhere (Task/Profile/ShiftSwap/Notification, and now
Schedule same-scope silent reload); rebuild scoping via `BlocSelector` on the
dashboards; no duplicate listeners found — every stream cubit is
subscription-keyed and cancels on close/re-scope.

**Reliability.** CrashReporter: 4 funnels → structured report persisted to
Application Support **even in release**, next-launch export banner. AppLog
breadcrumb ring always-on (feeds crash reports), >1s timing escalation.
Firestore offline persistence + unlimited cache. Every cubit mutation restores
the previous state on failure; task-stream errors log the real error and show
a friendly retryable message; orphaned schedule assignments are surfaced and
resolvable, never masked.

**Release stability.** macOS debug build + web release build green (smoke,
this session — see CURRENT_STATE). Startup: splash (1400 ms brand dwell) →
session restore → first-login gate → role home; redirect is pure/synchronous
(no navigation stalls); deactivated accounts blocked at login AND mid-session.
Deep link `/task/:id` has skeleton/error/retry states and works from cold
start. Notification taps are recipient-guarded (wrong-account pushes dropped
+ self-healing re-registration). The macOS freeze (duplicate GlobalKey) and
blank-My-Week (TabBarView entrance animation) root causes are fixed with
regression tests + guard comments.

---

## Pre-beta action list (ordered, revised after deployed-state verification)

1. `firebase deploy --only firestore:indexes --project production` → index ACTIVE (C1a — unblocks employee task streams).
2. `firebase deploy --only functions:generateShiftTaskInstances --project production` (C1b) → smoke shift tasks.
3. `firebase deploy --only functions --project production` (C1c — converge the fleet, brings FCM diagnostics) → smoke create-account/swap/broadcast.
4. M1 rule hardening (cheap, pure rules change — bundle into the next rules deploy).
5. Decide C2 (salary subcollection) — before or immediately after beta.
6. If iPhone users are in the beta: complete the iOS push checklist (C3).
7. On-device QA pass per BETA_CHECKLIST.md (see Phase 4).

*(Rules + storage deploys were removed from this list — verified already
live and byte-identical to the repo.)*
