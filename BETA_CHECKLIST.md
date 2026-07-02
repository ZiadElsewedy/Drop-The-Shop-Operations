# DROP — Beta Release Checklist & QA Plan (2026-07-02)

> Everything needed to put DROP in front of the first real users: one owner
> (admin), one store manager, and employees. Work through **Pre-flight** once,
> then run the **role walkthroughs** on real devices, then keep the
> **scenario drills** as the regression script for every beta build.
> Companion: [PRODUCTION_AUDIT_2026-07-02.md](PRODUCTION_AUDIT_2026-07-02.md).

---

## 0 · Pre-flight (owner, once — blocking)

- [ ] `firebase deploy --only firestore:indexes --project production` → wait
      until the `tasks` composite index shows ACTIVE (audit C1a — employee
      shift-task streams fail without it).
- [ ] `firebase deploy --only functions:generateShiftTaskInstances --project production`
      (audit C1b — recurring shift tasks never materialize without it).
- [ ] `firebase deploy --only functions --project production` (audit C1c —
      converges the fleet on HEAD, adds the FCM failure diagnostics).
      *Rules + storage are verified already deployed and current — no rules
      deploy needed unless M1 hardening is bundled in.*
- [ ] Post-deploy smoke: create a test account → sign in → complete a task
      with proof photo → approve a swap → send a broadcast → shift task
      visible to a rostered employee.
- [ ] If iPhones are in the beta: iOS push checklist (audit C3 — Xcode Push
      capability + APNs key). Otherwise state clearly to testers: *no push on
      iPhone yet, use the in-app inbox*.
- [ ] Decide audit C2 (salary read exposure) — ship now or accept for a
      trusted-staff beta.
- [ ] Tag the build (`git tag beta-1`) so feedback maps to a known version.

## 1 · Onboarding & first login (per new user)

- [ ] Admin creates the account (Create Account → role, branch, position,
      compensation) — credentials dialog shows the temp password.
- [ ] New user signs in → **forced password change** appears, can't be
      skipped (back/deep-link attempts bounce).
- [ ] Profile completion: phone/address/emergency validated (Arabic input
      accepted), photo optional, lands on the correct role home.
- [ ] Deactivated account: blocked at login with the "disabled" message; a
      mid-session deactivation signs the user out.
- [ ] Forgot password delivers the reset email.

## 2 · Daily workflow (employee, on a phone)

- [ ] Home shows today's shift, swaps section, and the active-window task
      counts (old approved work does NOT inflate the ring).
- [ ] Task: start → tick required checklist → complete with notes + proof
      photo → status becomes Waiting Review; a failed upload keeps the task
      started (retry works offline→online).
- [ ] Shift task ("Open Store") is visible to whoever is rostered on that
      shift **today** — and not to others.
- [ ] My Schedule: today hero card correct; **My Week → Swaps → back keeps
      rendering** (the fixed bug — verify on the phone); pull-to-refresh
      keeps the view (no blank/skeleton flash).
- [ ] Swap request: only future shifts offer Swap; picker shows only
      opposite-shift coworkers; the request appears on the coworker's Home
      in realtime.

## 3 · Schedule management (manager, desktop + phone)

- [ ] Grid renders the week; today highlighted; insight strip counts match
      reality (open / one-person / double-booked).
- [ ] Desktop: drag-to-move, drag-onto-person switch, right-click menu
      (move · switch with… · remove) — each success shows **UNDO** and undo
      restores exactly.
- [ ] Blocked edits explain themselves: dragging someone onto a day they
      already work the other shift is refused with the day named; emptying a
      shift asks for confirmation.
- [ ] Mobile: long-press a chip → action sheet; Move via the week map;
      Switch shows the trade preview before confirm; Remove offers UNDO.
- [ ] Crowded cell (>4 people) shows "+N more" → full shift panel.
- [ ] Swap queue chip: coworker-accepted swap → approve → schedule updates
      + both employees notified; reject notifies both.
- [ ] Position policy (if set on the branch): cross-position switch is
      blocked with the policy reason — same answer via drag AND via the
      employee swap flow.

## 4 · Oversight (admin/owner)

- [ ] Dashboard counters live-update after a review; Pending Actions rows
      deep-link correctly (Reviews → drill-down, Swaps → queue sheet).
- [ ] Branch management: create/edit branch, upload logo/cover, swap-policy
      section saves.
- [ ] User management: change role/branch/position, Edit Info (contact +
      compensation), reset account issues a new temp password + re-forces
      the change.
- [ ] Reports/statistics screens populate for a branch with real data.
- [ ] ⌘K palette + ⌘1–⌘9 sidebar nav on the Mac; right-click menus work.

## 5 · Notifications (mixed roles)

- [ ] Task assignment → push (Android) + inbox entry; tapping opens the
      exact task, cold-start included.
- [ ] Broadcast to branch → all branch members (sender excluded); DM → only
      the target; emergency category arrives as push.
- [ ] Swap lifecycle events reach the right people (request → coworker;
      accept → manager; approve/reject → both employees).
- [ ] Account switch on a shared device: pushes follow the new account, the
      old account gets nothing (token reclaim).

---

## 6 · Scenario drills (realistic store situations)

Run these as scripted rehearsals with the actual beta users; each doubles as
training. **Pass = the flow completes without anyone asking "how do I…?"**

| # | Scenario | Script | Expected |
|---|----------|--------|----------|
| S1 | **Employee calls in sick** (morning, day-of) | Manager opens Schedule on their phone → long-press the sick person → Remove (confirm if the shift empties) → cell sheet → Assign a replacement | Roster correct in <1 min; replacement sees the shift on their Home |
| S2 | **Two employees want to trade next Tuesday** | Employee A requests the swap from My Week → B accepts from Home → manager approves from the queue chip | Schedule swaps both; all three see the outcome without refreshing |
| S3 | **Manager fat-fingers a drag** | Drag someone to the wrong day → tap UNDO within 5 s | Original roster restored exactly |
| S4 | **Opening routine** | Recurring shift task "Open Store" (Morning, daily) exists → today's rostered morning crew completes it with proof | Tomorrow's instance auto-generates; yesterday's completion history intact |
| S5 | **Overdue task escalation** | Let a due task lapse | Reminder/overdue notification fires (function schedule ≤30 min); manager sees it flagged |
| S6 | **Urgent broadcast** ("Health inspector on the way") | Manager sends an emergency-category broadcast to the branch | Push arrives (Android), pinned in inboxes; delivery counts on the detail screen |
| S7 | **Review + rework loop** | Manager rejects a submission with a note → employee fixes + resubmits → approve | Timeline shows the full loop; approval locks the task; recurring next-instance spawns |
| S8 | **Offline resilience** | Airplane-mode the phone → browse schedule/tasks → complete a checklist item → back online | Cached views render; the write syncs; no crash, no data loss |
| S9 | **Shared device account switch** | Employee logs out, manager logs in on the same phone | Manager sees only manager surfaces; pushes route to the manager account |
| S10 | **New hire day one** | Full pipeline: create account → first login gate → first task → first schedule appearance | Under 10 minutes end-to-end, no admin hand-holding beyond the credentials |

---

## 7 · Beta feedback system (design — lean)

**Principle:** feedback capture must be *one tap from anywhere, under 20
seconds to file*, or store staff won't file it. No external tools, no forms
with ten fields.

**Design (deliberately minimal — one collection, one sheet, one list):**

1. **`feedback/{id}` collection** — `{ uid, role, branchId, route (from
   CrashContext.route), platform, appVersion, type: bug|confusion|idea,
   message, screenshotUrl?, createdAt, status: new|seen|done }`.
   Rules: create = any signed-in user stamping their own uid; read/update =
   admin only. (Same trust model as notifications.)
2. **Entry point** — a "Send feedback" row in Settings *plus* a long-press on
   the version label anywhere the sidebar/profile shows it. Opens one sheet:
   three big type chips (🐞 Something broke · 🤔 Confusing · 💡 Idea), one
   multiline field, optional screenshot attach (reuses the existing picker +
   Storage pipeline), Send. **Route/role/version auto-attach silently** — the
   context the user would never think to write down (this is why in-app beats
   a WhatsApp group: zero-effort context).
3. **Admin triage** — a simple list under Admin (newest first, unread badge,
   swipe to mark done). No dashboards, no analytics — the owner reads every
   item at beta scale.
4. **Crash reports** — already handled: the next-launch banner exports the
   persisted crash report; instruct beta users to paste it into the feedback
   sheet when they see it.
5. **Cadence** — a 15-minute weekly review of `feedback` + crash logs during
   the beta; every item becomes: fix now / backlog / won't-fix with a reason.

**Estimated build cost:** ~half a day (entity + datasource + rules + sheet +
admin list), reusing AppSnackbar/sheet chrome/attachment picker. Not built in
this pass — flagged for the next session so beta can start collecting from
day one.

---

## 8 · Exit criteria for the beta phase

- Zero S1–S10 scenario failures across two consecutive weekly builds.
- No new CRITICAL findings; audit M1 (swap-status rule) deployed.
- Crash log empty (or every crash root-caused) for 2 weeks of real usage.
- Feedback triage list at inbox-zero with owner dispositions.
