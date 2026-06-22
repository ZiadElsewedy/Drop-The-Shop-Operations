# DROP THE SHOP (FBRO) — Manual QA Checklist

> **Purpose:** prepare the app for real production testing. Run every scenario on
> a **real device/emulator** against the live Firebase project and tick each box.
> This checklist was derived from a full code trace — the **Code-verified** column
> is the expected result from reading the implementation; the **On-device** box is
> for the human tester to confirm.
>
> Treat this as a living test sheet, not source code. See
> [CURRENT_STATE.md](CURRENT_STATE.md) for status and [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md)
> for architecture.

---

## 0. Preconditions — MUST be done first (else many scenarios fail)

| # | Setup step | Why | Done |
| - | ---------- | --- | ---- |
| P1 | **Deploy security rules**: `firebase deploy --only firestore:rules,storage` | The committed `users` read fix + `weekly_schedules` / `shift_swaps` rules are **not live** until deployed. Without them: *See teammates*, *Open My Schedule*, and *Shift swaps* fail with permission errors. | ☐ |
| P2 | **Enable Firebase Storage** in the console | Task **proof upload** writes to `tasks/{id}/proof.jpg`. Without Storage enabled, upload fails. | ☐ |
| P3 | **Bootstrap the first admin** in the Firebase console: set `role: admin`, `approvalStatus: approved`, `isActive: true` on one user doc | Every sign-up (incl. the founder's) is seeded `pending`/inactive; you need one admin to approve the rest. | ☐ |
| P4 | Confirm Auth providers enabled: Email/Password, Google, Phone | Login scenarios depend on them. | ☐ |
| P5 | (iOS push only) APNs key + Push capability | FCM token + foreground messages. **Sending** events is out of scope (no server trigger) — do not test push delivery. | ☐ |
| P6 | Build & launch: `flutter run` (release or debug) on the target device | — | ☐ |

**Suggested test accounts:** `admin@…` (bootstrapped), `mgr@…` (to promote), `emp1@…`, `emp2@…` (employees in the same branch).

---

## 1. Employee scenarios

| # | Step | Expected result | Code-verified | On-device |
| - | ---- | --------------- | ------------- | --------- |
| E1 | **Register** with email + password (+ name) | Account created; routed to **Email Verification**; a verification email is sent. New doc seeded `pending` + `isActive:false`, no branch. | ✅ | ☐ |
| E2 | **Verify email** — open the email, click the link, return to the app | The app polls every ~4s and auto-advances once verified → lands on **Pending Approval**. | ✅ | ☐ |
| E3 | **Wait for approval** — leave the app on Pending Approval; (as admin elsewhere) approve this user | Screen redirects to the employee home **in real time** (live `users/{uid}` listener), no re-login, no manual refresh. | ✅ | ☐ |
| E4 | **Login** (after sign-out) with the same credentials | Lands directly on employee home (approved + active). | ✅ | ☐ |
| E5 | **Open My Schedule** (calendar icon) | "My Week" tab loads. Shows today's shift / "Off today" + "My week" list. If the manager hasn't published this week → "No schedule published for this week yet." | ✅ (needs P1) | ☐ |
| E6 | **See teammates** — on a day/shift you're assigned, check "Working with" + "Manager" on the Today card | Coworker names on the same shift + the branch manager's name render (not "Unknown"). | ✅ (needs P1) | ☐ |
| E7 | **Receive assigned task** — (manager assigns you a task elsewhere) watch My Tasks (✓ icon) | The new task appears **automatically** — task lists are realtime Firestore streams; no pull-to-refresh needed. | ✅ real-time | ☐ |
| E8 | **Start task** — open the task card → tap **Start Task** | Status → **In Progress**; task details screen stays open. | ✅ | ☐ |
| E9 | **Tick checklist** (if present) — tap each required item | Items check off; progress bar advances; "Mark Complete" only activates when all required items are done. | ✅ | ☐ |
| E10 | **Complete and submit** — tap **Mark Complete** → add optional notes → optional proof image → tap **Complete & Submit** | Status → **In Review** in one action; task disappears from Active, appears in the In Review section. | ✅ | ☐ |
| E11 | **Upload proof** — in step E10, attach an image before tapping **Complete & Submit** | Image uploads; proof visible in task details (needs P2). If Storage disabled, task still submits with a warning snackbar. | ✅ (needs P2 for upload; resilient without) | ☐ |

---

## 2. Manager scenarios

> Precondition: the manager account must have a **branchId** (assigned by admin on
> approval or promotion). A branch-less manager sees empty/limbo views.

| # | Step | Expected result | Code-verified | On-device |
| - | ---- | --------------- | ------------- | --------- |
| M1 | **Create weekly schedule** — Schedule → (current week) → **Create Schedule** | An empty roster grid (Sun→Sat, Morning/Night) appears. | ✅ | ☐ |
| M2 | **Assign employees** — on a day/shift tap **Add**, pick employees; remove via the ✕ chip | Names appear/disappear under the slot immediately. | ✅ | ☐ |
| M3 | **Create task** — Tasks → **New Task** (title, type, priority, deadline) | Task created in the manager's branch, status Pending. | ✅ | ☐ |
| M4 | **Assign task** — on the task tap **Assign**, pick a branch employee | Card shows "assigned"; the employee can now see it (E7). | ✅ | ☐ |
| M5 | **Review completed task** — when a task is **Waiting Review**, tap **Review** | Review sheet opens with the title + optional note field. | ✅ | ☐ |
| M6 | **Approve** | Status → **Approved**; `approvedBy`/`approvedAt` recorded. | ✅ | ☐ |
| M7 | **Reject** (on another waiting task) | Status → **Rejected**; employee can **Restart** it. | ✅ | ☐ |
| M8 | **Approve shift swap** — Schedule → **Swap Requests** tab; for a request the coworker already approved ("Awaiting manager"), tap **Approve** | Swap → **Approved**; the schedule slot is rewritten (requester removed, target added). Switch to the Schedule tab + **pull to refresh** to see the updated roster. | ✅ (needs P1) | ☐ |

---

## 3. Admin scenarios

| # | Step | Expected result | Code-verified | On-device |
| - | ---- | --------------- | ------------- | --------- |
| A1 | **Create branch** — Branches → add (name + optional location) | Branch appears in the list; available in branch pickers. | ✅ | ☐ |
| A2 | **Approve employee** — Pending Approvals → **Approve** → pick role **Employee** + a **branch** | User becomes approved + active with that role/branch; drops off the pending list. *(Tip: always pick a branch, or the employee can't see a schedule.)* | ✅ | ☐ |
| A3 | **Promote manager** — Managers → **Add Manager** → pick an approved employee | User's role → manager; **their existing branch is kept** (fixed bug — previously wiped). | ✅ | ☐ |
| A4 | **Change manager branch** — Managers → **Assign Branch** | Manager's `branchId` updates; their schedule/tasks now scope to the new branch. | ✅ | ☐ |
| A5 | **Move employee** — Employees → **Change Branch** | Employee's `branchId` updates; they now see the new branch's schedule. | ✅ | ☐ |
| A6 | **Check analytics** — Admin dashboard | Branch / manager / employee / pending counts, **schedule coverage** (`x/y`), task stats render. Pull to refresh after making changes. | ✅ (refresh) | ☐ |

---

## 4. Real-time verification

| # | Check | Expected | Code-verified | On-device |
| - | ----- | -------- | ------------- | --------- |
| R1 | **Approvals** — pending employee's app open; admin approves on another device | Redirects **instantly** (push via Firestore listener). | ✅ real-time | ☐ |
| R2 | **Task assignment** — employee's My Tasks open; manager assigns | Appears **automatically** — task lists are realtime Firestore snapshot streams (`TaskCubit`). No refresh needed. | ✅ real-time | ☐ |
| R3 | **Schedules** — employee's My Schedule open; manager edits | Appears **after pull-to-refresh / reopen**. | ⚠️ refresh-based | ☐ |
| R4 | **Shift swaps** — target/manager sees a new request | Appears **after pull-to-refresh / reopen**; the acting user's own list updates immediately. | ⚠️ refresh-based | ☐ |

> **Realtime:** approval gate + task lists are push (live streams). Schedule /
> branch / admin / swap lists are correct after a pull-to-refresh — by design
> (Future-based data layer). Don't log "stale list" as a bug for those.

---

## 5. Offline verification

| # | Step | Expected | Code-verified | On-device |
| - | ---- | -------- | ------------- | --------- |
| O1 | Load a few screens online, then enable Airplane Mode; reopen those screens | **Cached data** still renders (Firestore offline persistence). | ✅ | ☐ |
| O2 | While offline, change a task status / edit the schedule | The UI updates from the local cache (write is queued). | ✅ | ☐ |
| O3 | While offline, try to **upload a task proof image** | Expected to **fail/queue** — Storage has no offline cache. Acceptable; verify it shows an error, not a crash. | ✅ (no crash) | ☐ |
| O4 | Re-enable network | Queued writes **sync** automatically; lists reconcile. | ✅ | ☐ |
| O5 | Throughout, confirm **no crashes / no infinite spinners** | Errors surface as snackbars; screens recover. | ✅ | ☐ |

---

## 6. UI / branding

| # | Check | Expected | Code-verified | On-device |
| - | ----- | -------- | ------------- | --------- |
| U1 | **Logo** | DROP wordmark on Splash, Login, Register, Pending Approval (white-tinted). | ✅ | ☐ |
| U2 | **Branding** | App title/name is **DROP**; monochrome black-and-white theme throughout. | ✅ | ☐ |
| U3 | **Navigation** | Role guards hold — an employee can't reach `/admin/*` or `/manager/*` (deep-link is bounced home); back navigation works. | ✅ | ☐ |
| U4 | **Loading states** | Spinners on first load; `LinearProgressIndicator` during mutations; lists stay visible (no flicker). | ✅ | ☐ |
| U5 | **Error states** | Failures show a red snackbar (e.g. bad login, permission error); the screen keeps its last data. | ✅ | ☐ |
| U6 | **No prototype UI** | No "arrives in a later phase" screens reachable from the app (the calendar icon opens the weekly Schedule). | ✅ | ☐ |

---

## Known limitations (expected — do NOT file as bugs)

- **Managers cannot approve users** — approval is admin-only by design.
- **Real-time scope:** task lists are live streams (appear immediately). Schedule /
  admin / swap / branch lists update on pull-to-refresh — by design.
- **Push notification delivery** is not implemented (no server trigger); only token
  registration + foreground snackbars exist.
- **Rejected users** see the generic "Pending Approval" screen (access is correctly
  blocked; the copy just doesn't say "rejected").
- **Account deletion** removes the Auth account but not the `users/{uid}` doc.
- **Recurring tasks** auto-spawn the next instance on approve; the newly created task starts as **Pending** and must be separately assigned if the assignees need to change.
- **Activity log** is embedded in the task document (no separate subcollection). Query-based analytics on individual timeline entries are not supported; roll-up counts by status/branchId are available via the statistics feature.

## Sign-off

| Role suite | Tester | Date | Pass / Fail | Notes |
| ---------- | ------ | ---- | ----------- | ----- |
| Employee   |        |      |             |       |
| Manager    |        |      |             |       |
| Admin      |        |      |             |       |
| Real-time  |        |      |             |       |
| Offline    |        |      |             |       |
| UI         |        |      |             |       |
