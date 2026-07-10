/**
 * DROP — Communications Center send engine.
 *
 * Callable `sendBroadcast`: the authoritative broadcast write + push pipeline.
 * Responsibilities:
 *   1. validate the sender's permissions (admin / manager matrix),
 *   2. resolve recipients (all users / a branch / one individual),
 *   3. persist the broadcast doc (`broadcasts/{id}`),
 *   4. fetch the recipients' FCM tokens (`users/{uid}.fcmTokens` [+ legacy
 *      single `fcmToken`]),
 *   5. send the push via the Firebase Admin SDK,
 *   6. prune dead tokens, and
 *   7. return a delivery summary `{ success, recipientCount, ... }`.
 *
 * Implemented as a **2nd-gen** callable (`firebase-functions/v2`, the
 * `firebase-functions` v6 default). `firebase deploy --only functions` deploys it
 * and the Firebase CLI grants the public invoker for callable functions
 * automatically. (1st-gen would hit a "Cannot set CPU on GCF gen 1" deploy error
 * with firebase-functions v6.) The signed-in caller's auth arrives in
 * `request.auth`.
 *
 * Recipient-resolution / permission matrix (mirrors `BroadcastPermissions` on
 * the client and the `broadcasts` Firestore rules):
 *   - admin   → allBranches | branch (any) | user (any)
 *   - manager → branch (own only) | user (in own branch only)
 *   - employee → denied
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();
const auth = admin.auth();

const USERS = "users";
const BROADCASTS = "broadcasts";
const NOTIFICATIONS = "notifications";
const BROADCAST_SCHEDULES = "broadcastSchedules";
const TASKS = "tasks";
const TASK_REMINDERS = "taskReminders";
const REMINDER_CONFIG = "reminderConfig";
const BRANCHES = "branches";
const WEEKLY_SCHEDULES = "weekly_schedules";
const SHIFT_SWAPS = "shift_swaps";
const RECURRING_TASK_TEMPLATES = "recurringTaskTemplates";
const CONFIG = "config";
const CASES = "cases";
const REQUESTS = "requests";
const COUNTERS = "counters";

// `branchId` marker for a direct message — never a real branch id and never ''
// (mirrors BroadcastModel.directBranchMarker), so a DM never appears in a
// branch / all feed query.
const DIRECT_BRANCH_MARKER = "__direct__";

// `branchId` marker for a hand-picked multi-recipient (custom) broadcast
// (mirrors BroadcastModel.customBranchMarker).
const CUSTOM_BRANCH_MARKER = "__custom__";

// FCM multicast hard limit per request.
const MULTICAST_CHUNK = 500;

// Firestore batched-write limit.
const BATCH_LIMIT = 500;

// Maps a broadcast category to its notification `type` (mirrors
// NotificationType.fromBroadcastCategory on the client).
function categoryToType(category) {
  switch (category) {
    case "reminder":
      return "broadcastReminder";
    case "emergency":
      return "broadcastEmergency";
    case "announcement":
    default:
      return "broadcastAnnouncement";
  }
}

// FCM error codes that mean a token is permanently dead and should be pruned.
function isDeadTokenError(code) {
  return (
    code === "messaging/registration-token-not-registered" ||
    code === "messaging/invalid-registration-token" ||
    code === "messaging/invalid-argument"
  );
}

// Delivery is derived from the broadcast category (mirrors BroadcastCategory on
// the client — there is no separate priority/channel dial): announcement is a
// quiet inbox-only message; reminder + emergency also push; emergency rides at
// high FCM priority. Every category writes the in-app inbox.
function categorySendsPush(category) {
  return category !== "announcement";
}
function categoryIsHigh(category) {
  return category === "emergency";
}

/**
 * The authoritative broadcast write + push pipeline, shared by the callable
 * `sendBroadcast` and (Phase 2 Commit 4) the scheduled-broadcast poller. The
 * caller is responsible for permission validation (role → audience, branch
 * ownership); this resolves recipients, persists the doc, writes the per-recipient
 * inbox notifications (when the channel includes inbox), pushes FCM (when the
 * channel includes push), prunes dead tokens, and returns the delivery summary.
 *
 * @returns {Promise<{broadcastId: string, recipientCount: number, deliveredCount: number}>}
 */
async function dispatchBroadcast(params) {
  const title = String(params.title || "").trim();
  const body = String(params.body || params.message || "").trim();
  const category = String(params.category || "general").trim() || "general";
  const audience = String(params.audience || "").trim();
  const senderId = String(params.senderId || "").trim();
  const senderRole = String(params.senderRole || "manager").trim() || "manager";
  const senderBranch = String(params.senderBranch || "").trim();
  const senderName = String(params.senderName || "DROP").trim() || "DROP";
  const targetUserId = String(params.targetUserId || "").trim();
  const roleFilter = String(params.roleFilter || "").trim();
  const targetUserIds = Array.isArray(params.targetUserIds)
    ? params.targetUserIds.map((s) => String(s || "").trim()).filter(Boolean)
    : [];
  let branchId = String(params.branchId || "").trim();
  // Persisted recipient list — set for a custom send (drives the read rule).
  let persistedTargetIds = [];

  // Restrict a fetched user set to a single role (zigzag-merge equality — no
  // composite index). 'all'/'' means everyone.
  const applyRole = (docs) =>
    roleFilter && roleFilter !== "all"
      ? docs.filter((d) => (d.data().role || "employee") === roleFilter)
      : docs;

  // ── Resolve recipients per audience (caller has validated permissions) ──
  let recipientDocs = [];
  if (audience === "allBranches") {
    const snap = await db.collection(USERS).where("isActive", "==", true).get();
    recipientDocs = applyRole(snap.docs);
    branchId = "";
  } else if (audience === "branch") {
    const snap = await db
      .collection(USERS)
      .where("branchId", "==", branchId)
      .where("isActive", "==", true)
      .get();
    recipientDocs = applyRole(snap.docs);
  } else if (audience === "user") {
    const targetSnap = await db.collection(USERS).doc(targetUserId).get();
    if (!targetSnap.exists) {
      throw new HttpsError("not-found", "That recipient no longer exists.");
    }
    recipientDocs = [targetSnap];
    branchId = DIRECT_BRANCH_MARKER;
  } else if (audience === "custom") {
    if (targetUserIds.length === 0) {
      throw new HttpsError("invalid-argument", "Pick at least one recipient.");
    }
    const refs = targetUserIds.map((id) => db.collection(USERS).doc(id));
    const snaps = await db.getAll(...refs);
    let docs = snaps.filter((s) => s.exists);
    // A manager may only message users inside their own branch.
    if (senderRole === "manager") {
      docs = docs.filter((d) => (d.data().branchId || "") === senderBranch);
    }
    if (docs.length === 0) {
      throw new HttpsError("not-found", "None of the recipients are available.");
    }
    recipientDocs = docs;
    persistedTargetIds = docs.map((d) => d.id);
    branchId = CUSTOM_BRANCH_MARKER;
  } else {
    throw new HttpsError("invalid-argument", "Unknown broadcast audience.");
  }

  // ── Never deliver a broadcast back to its own sender for an IMPLICIT
  // audience (everyone / a branch / a role). The sender authored it — pushing
  // it to their own device + inbox is noise. EXPLICIT audiences are honoured as
  // chosen: a direct `user` message or a hand-picked `custom` list delivers to
  // exactly whoever was selected (if the sender deliberately included
  // themselves, they receive it). ──
  if (
    (audience === "allBranches" || audience === "branch") &&
    senderId
  ) {
    recipientDocs = recipientDocs.filter((d) => d.id !== senderId);
  }

  const recipientCount = recipientDocs.length;
  const isHigh = categoryIsHigh(category);
  const notifType = categoryToType(category);

  // ── Persist the broadcast doc (authoritative — schema matches BroadcastModel) ──
  const broadcastRef = db.collection(BROADCASTS).doc();
  await broadcastRef.set({
    id: broadcastRef.id,
    title,
    message: body,
    category,
    senderId,
    senderName,
    senderRole,
    audience,
    branchId,
    targetUserId: audience === "user" ? targetUserId : "",
    targetUserIds: persistedTargetIds,
    recipientCount,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // ── Persist one in-app notification doc per recipient (inbox channel only).
  // Flagged `pushedByFunction:true` so the onNotificationCreated trigger doesn't
  // double-push. Best-effort — a write failure never fails the send. ──
  // Every category writes the in-app inbox (announcement is inbox-only).
  {
    const notifPayload = {
      broadcastId: broadcastRef.id,
      category,
      route: "broadcast_detail",
      priority: isHigh ? "high" : "normal",
    };
    try {
      for (let i = 0; i < recipientDocs.length; i += BATCH_LIMIT) {
        const slice = recipientDocs.slice(i, i + BATCH_LIMIT);
        const batch = db.batch();
        for (const doc of slice) {
          const ref = db.collection(NOTIFICATIONS).doc();
          batch.set(ref, {
            id: ref.id,
            recipientUid: doc.id,
            senderUid: senderId,
            type: notifType,
            title,
            body,
            readAt: null,
            payload: notifPayload,
            pushedByFunction: true,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    } catch (err) {
      logger.warn("failed to persist broadcast notifications", { error: String(err) });
    }
  }

  // ── Push the notification (chunked; prune dead tokens) — push channels only ──
  let deliveredCount = 0;
  // Diagnostics: how many times the SAME device token was found on two different
  // recipients in one send — an ownership-drift signal (defense-in-depth #3).
  let tokenDriftCount = 0;
  if (categorySendsPush(category)) {
    // Gather FCM tokens (de-duplicated; remember each token's EXCLUSIVE owner).
    // If a token is already claimed by another recipient in this send, that's
    // drift: keep the first owner (no double-send) and log it. claimFcmToken is
    // the authoritative reconciliation; this just surfaces the race for ops.
    const tokens = [];
    const tokenOwner = new Map();
    const claimToken = (t, uid) => {
      if (!t) return;
      const existing = tokenOwner.get(t);
      if (existing === undefined) {
        tokenOwner.set(t, uid);
        tokens.push(t);
      } else if (existing !== uid) {
        tokenDriftCount++;
        logger.warn("token ownership drift during dispatch", {
          broadcastId: broadcastRef.id,
          tokenSuffix: String(t).slice(-8),
          owners: [existing, uid],
        });
      }
    };
    for (const doc of recipientDocs) {
      const u = doc.data() || {};
      const arr = Array.isArray(u.fcmTokens) ? u.fcmTokens : [];
      for (const t of arr) claimToken(t, doc.id);
      // Legacy single-token field (pre-Phase-2 docs).
      claimToken(u.fcmToken, doc.id);
    }

    // Data values must be strings — they ride along to the tap handler. Each
    // push is stamped per-token with its intended `recipientUid` below, so the
    // client can DROP any notification whose recipient != the signed-in user
    // (defense-in-depth #3 — the last guard against a drifted/stale token).
    const baseData = {
      type: notifType,
      category,
      priority: isHigh ? "high" : "normal",
      senderId,
      broadcastId: broadcastRef.id,
      route: "broadcast_detail",
      title,
      body,
    };
    const androidPriority = isHigh ? "high" : "normal";
    const apnsPriority = isHigh ? "10" : "5";

    if (tokens.length === 0) {
      // Recipients exist but none has a registered device token — they still get
      // the in-app inbox entry, just no push. Logged so a "didn't reach all"
      // report can be diagnosed (token persistence vs. the send itself).
      logger.info("broadcast push: recipients have no registered device tokens", {
        broadcastId: broadcastRef.id,
        recipientCount,
      });
    }
    // A push / messaging-API failure must NOT fail a send whose broadcast doc +
    // inbox notifications already succeeded (recipients still got the in-app
    // entry). Isolate it: log it and keep the partial delivered count.
    try {
    for (let i = 0; i < tokens.length; i += MULTICAST_CHUNK) {
      const batch = tokens.slice(i, i + MULTICAST_CHUNK);
      // One message per token so `data.recipientUid` can differ per recipient (a
      // multicast shares one data block). `sendEach` preserves response order, so
      // the dead-token pruning below still indexes `batch[idx]`.
      const messages = batch.map((token) => ({
        token,
        notification: { title, body },
        android: { priority: androidPriority },
        apns: { headers: { "apns-priority": apnsPriority } },
        data: { ...baseData, recipientUid: tokenOwner.get(token) || "" },
      }));
      const response = await messaging.sendEach(messages);
      deliveredCount += response.successCount;

      // Remove tokens FCM reports as permanently invalid, per owner.
      const removals = new Map(); // uid -> [badToken]
      response.responses.forEach((r, idx) => {
        if (r.success) return;
        const code = r.error && r.error.code;
        // DIAGNOSTIC: surface the EXACT per-token failure reason (FCM discards it
        // otherwise) — e.g. `messaging/third-party-auth-error` = iOS APNs key not
        // configured; `messaging/registration-token-not-registered` = stale token.
        logger.warn("broadcast token send failed", {
          broadcastId: broadcastRef.id,
          owner: tokenOwner.get(batch[idx]),
          tokenSuffix: String(batch[idx]).slice(-10),
          code,
          message: r.error && r.error.message,
        });
        if (isDeadTokenError(code)) {
          const badToken = batch[idx];
          const owner = tokenOwner.get(badToken);
          if (owner) {
            if (!removals.has(owner)) removals.set(owner, []);
            removals.get(owner).push(badToken);
          }
        }
      });
      await Promise.all(
        Array.from(removals.entries()).map(([uid, bad]) =>
          db
            .collection(USERS)
            .doc(uid)
            .update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...bad) })
            .catch(() => {}),
        ),
      );
    }
    } catch (err) {
      logger.error("broadcast push failed (inbox delivery already succeeded)", {
        broadcastId: broadcastRef.id,
        tokenCount: tokens.length,
        deliveredCount,
        error: String(err),
      });
    }
  }

  // Persist the delivery result on the doc so the Communications Center feed /
  // detail can show "delivered N / M" (best-effort; never fails the send).
  await broadcastRef.update({ deliveredCount }).catch(() => {});

  logger.info("broadcast dispatched", {
    broadcastId: broadcastRef.id,
    audience,
    recipientCount,
    deliveredCount,
    tokenDriftCount,
  });

  return { broadcastId: broadcastRef.id, recipientCount, deliveredCount };
}

exports.sendBroadcast = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Please sign in to send a broadcast.");
  }

  const payload = request.data || {};
  const title = String(payload.title || "").trim();
  const body = String(payload.body || payload.message || "").trim();
  const category = String(payload.category || "general").trim() || "general";
  const audience = String(payload.audience || "").trim();
  const branchId = String(payload.branchId || "").trim();
  const targetUserId = String(payload.targetUserId || "").trim();
  const roleFilter = String(payload.roleFilter || "").trim();
  const targetUserIds = Array.isArray(payload.targetUserIds)
    ? payload.targetUserIds.map((s) => String(s || "").trim()).filter(Boolean)
    : [];

  if (!title || !body) {
    throw new HttpsError("invalid-argument", "A broadcast needs a title and a message.");
  }

  // ── Load the sender (role + branch are the authority for permissions) ──
  const senderSnap = await db.collection(USERS).doc(auth.uid).get();
  if (!senderSnap.exists) {
    throw new HttpsError("permission-denied", "Your account profile was not found.");
  }
  const sender = senderSnap.data() || {};
  const senderRole = sender.role || "employee";
  const senderBranch = sender.branchId || "";

  if (senderRole !== "admin" && senderRole !== "manager") {
    throw new HttpsError("permission-denied", "Only managers and admins can send broadcasts.");
  }

  // ── Validate permissions per audience (recipient resolution is in dispatch) ──
  if (audience === "allBranches") {
    if (senderRole !== "admin") {
      throw new HttpsError("permission-denied", "Only admins can broadcast to all branches.");
    }
  } else if (audience === "branch") {
    if (!branchId) {
      throw new HttpsError("invalid-argument", "Pick a branch to broadcast to.");
    }
    if (senderRole === "manager" && branchId !== senderBranch) {
      throw new HttpsError("permission-denied", "Managers can only broadcast to their own branch.");
    }
  } else if (audience === "user") {
    if (!targetUserId) {
      throw new HttpsError("invalid-argument", "Pick a recipient.");
    }
    if (senderRole === "manager") {
      const targetSnap = await db.collection(USERS).doc(targetUserId).get();
      const target = targetSnap.exists ? targetSnap.data() || {} : {};
      if (!targetSnap.exists) {
        throw new HttpsError("not-found", "That recipient no longer exists.");
      }
      if ((target.branchId || "") !== senderBranch) {
        throw new HttpsError("permission-denied", "Managers can only message users inside their own branch.");
      }
    }
  } else if (audience === "custom") {
    if (targetUserIds.length === 0) {
      throw new HttpsError("invalid-argument", "Pick at least one recipient.");
    }
    // A manager's out-of-branch picks are filtered out inside dispatch.
  } else {
    throw new HttpsError("invalid-argument", "Unknown broadcast audience.");
  }

  const senderName = sender.fullName || sender.displayName || sender.email || "DROP";

  const result = await dispatchBroadcast({
    senderId: auth.uid,
    senderRole,
    senderBranch,
    senderName,
    title,
    body,
    category,
    audience,
    branchId,
    targetUserId,
    targetUserIds,
    roleFilter,
  });

  return { success: true, ...result };
});

// ─────────────────────────────────────────────────────────────────────────────
// createUserAccount — the secure account-provisioning path (admin-only).
//
// DROP no longer allows public registration: only an admin creates accounts.
// This callable creates the Firebase Auth user with the Admin SDK (which does
// NOT sign the calling admin out, unlike the client createUserWithEmailAndPassword)
// and seeds the `users/{uid}` document with the role/branch/shift/position plus
// the first-login flags (mustChangePassword + isProfileCompleted:false). Firestore
// rules deny ALL client creates of user docs, so this is the only creation path.
const VALID_ROLES = ["admin", "manager", "employee"];

exports.createUserAccount = onCall(async (request) => {
  const callerAuth = request.auth;
  if (!callerAuth) {
    throw new HttpsError("unauthenticated", "Please sign in.");
  }

  // ── Only an admin may provision accounts ──
  const callerSnap = await db.collection(USERS).doc(callerAuth.uid).get();
  const caller = callerSnap.exists ? callerSnap.data() || {} : {};
  if ((caller.role || "employee") !== "admin") {
    throw new HttpsError("permission-denied", "Only an admin can create accounts.");
  }

  const data = request.data || {};
  const name = String(data.name || "").trim();
  const email = String(data.email || "").trim().toLowerCase();
  const password = String(data.password || "");
  const role = String(data.role || "").trim();
  const branchId = String(data.branchId || "").trim();
  const assignedShift = String(data.assignedShift || "").trim();
  const position = String(data.position || "").trim();

  // ── Validation ──
  if (!name) throw new HttpsError("invalid-argument", "A full name is required.");
  if (!email || !email.includes("@")) {
    throw new HttpsError("invalid-argument", "A valid email is required.");
  }
  if (password.length < 6) {
    throw new HttpsError("invalid-argument", "The temporary password must be at least 6 characters.");
  }
  if (!VALID_ROLES.includes(role)) {
    throw new HttpsError("invalid-argument", "Pick a valid role.");
  }
  // A manager / employee must belong to a branch; an admin may be global.
  if ((role === "manager" || role === "employee") && !branchId) {
    throw new HttpsError("invalid-argument", "Pick a branch for this account.");
  }

  // ── Create the Auth user (does NOT affect the admin's own session) ──
  let userRecord;
  try {
    userRecord = await auth.createUser({
      email,
      password,
      displayName: name,
    });
  } catch (err) {
    if (err && err.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "An account already exists with this email.");
    }
    if (err && err.code === "auth/invalid-email") {
      throw new HttpsError("invalid-argument", "The email address is not valid.");
    }
    if (err && err.code === "auth/invalid-password") {
      throw new HttpsError("invalid-argument", "The temporary password is too weak.");
    }
    logger.error("createUserAccount: auth.createUser failed", { error: String(err) });
    throw new HttpsError("internal", "Could not create the account. Please try again.");
  }

  // ── Seed the Firestore user document ──
  try {
    await db.collection(USERS).doc(userRecord.uid).set({
      uid: userRecord.uid,
      email,
      // `name` maps to displayName (canonical) mirrored to the profile fullName.
      displayName: name,
      fullName: name,
      authProvider: "admin-created",
      role,
      branchId: branchId || null,
      assignedShift: assignedShift || null,
      position: position || null,
      isActive: true,
      employmentStatus: "active",
      mustChangePassword: true,
      isProfileCompleted: false,
      isEmailVerified: false,
      // Empty profile-schema seeds (filled during Profile Completion).
      username: "",
      bio: "",
      profileImage: "",
      coverImage: "",
      createdBy: callerAuth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    // Roll back the orphaned Auth user so a retry with the same email works.
    await auth.deleteUser(userRecord.uid).catch(() => {});
    logger.error("createUserAccount: firestore seed failed", { error: String(err) });
    throw new HttpsError("internal", "Could not finish creating the account. Please try again.");
  }

  logger.info("account created", { uid: userRecord.uid, role, by: callerAuth.uid });
  return { success: true, uid: userRecord.uid };
});

// ─────────────────────────────────────────────────────────────────────────────
// adminResetPassword — admin-only account reset: set a new temporary password
// (Admin SDK) and re-force a password change on next login. Satisfies the spec's
// "reset employee accounts" without exposing Auth credentials to the client.
exports.adminResetPassword = onCall(async (request) => {
  const callerAuth = request.auth;
  if (!callerAuth) {
    throw new HttpsError("unauthenticated", "Please sign in.");
  }
  const callerSnap = await db.collection(USERS).doc(callerAuth.uid).get();
  const caller = callerSnap.exists ? callerSnap.data() || {} : {};
  if ((caller.role || "employee") !== "admin") {
    throw new HttpsError("permission-denied", "Only an admin can reset accounts.");
  }

  const data = request.data || {};
  const uid = String(data.uid || "").trim();
  const tempPassword = String(data.tempPassword || "");
  if (!uid) throw new HttpsError("invalid-argument", "Missing the account to reset.");
  if (tempPassword.length < 6) {
    throw new HttpsError("invalid-argument", "The temporary password must be at least 6 characters.");
  }

  try {
    await auth.updateUser(uid, { password: tempPassword });
  } catch (err) {
    if (err && err.code === "auth/user-not-found") {
      throw new HttpsError("not-found", "That account no longer exists.");
    }
    logger.error("adminResetPassword: updateUser failed", { error: String(err) });
    throw new HttpsError("internal", "Could not reset the account. Please try again.");
  }

  await db.collection(USERS).doc(uid).set(
    {
      mustChangePassword: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  logger.info("account reset", { uid, by: callerAuth.uid });
  return { success: true };
});

// ─────────────────────────────────────────────────────────────────────────────
// approveSwap — the server-authoritative shift-swap exchange (2026-06-25
// hardening). A coworker-approved swap is finalized HERE, never by a direct
// client write (firestore.rules deny a client setting status==managerApproved).
//
// The function re-validates against the FRESHEST schedule (TOCTOU backstop) and
// applies the exchange ATOMICALLY in a single transaction — the requester and the
// target trade shifts on the same day (only two shifts exist, so the target's
// slot is the opposite of the requester's). Either both move or nothing changes.
//
// Validation mirrors `SwapValidation` (lib/features/schedule/domain/
// swap_validation.dart) — keep the two in sync. Notifications stay client-side
// (`NotifySwapEvent` fires after this resolves), reusing the existing pipeline.
const SWAP_DAY_INDEX = {
  sunday: 0, monday: 1, tuesday: 2, wednesday: 3, thursday: 4, friday: 5, saturday: 6,
};
const SWAP_SHIFTS = ["morning", "night"];

function swapOppositeShift(s) {
  return s === "night" ? "morning" : "night";
}
// Minutes past midnight: morning 08:30–16:30, night 16:30–23:00 (mirrors
// ScheduleShift.timeRange / SwapEligibility / SwapValidation).
function swapShiftMinutes(s) {
  return s === "night"
    ? { start: 16 * 60 + 30, end: 23 * 60 }
    : { start: 8 * 60 + 30, end: 16 * 60 + 30 };
}
function swapAssignedUids(assignments, day, shift) {
  const d = assignments && assignments[day];
  const arr = d && d[shift];
  return Array.isArray(arr) ? arr : [];
}
// Smallest gap (minutes) between any two of the employee's shifts in the week.
// < 2 shifts → unconstrained. Week-bounded (the adjacent week isn't loaded) —
// mirrors SwapValidation._minGapMinutes.
function swapMinGapMinutes(assignments, uid) {
  const intervals = [];
  for (const day of Object.keys(SWAP_DAY_INDEX)) {
    const di = SWAP_DAY_INDEX[day];
    for (const sh of SWAP_SHIFTS) {
      if (swapAssignedUids(assignments, day, sh).includes(uid)) {
        const m = swapShiftMinutes(sh);
        intervals.push([di * 1440 + m.start, di * 1440 + m.end]);
      }
    }
  }
  if (intervals.length < 2) return Number.MAX_SAFE_INTEGER;
  intervals.sort((a, b) => a[0] - b[0]);
  let minGap = Number.MAX_SAFE_INTEGER;
  for (let i = 1; i < intervals.length; i++) {
    const gap = intervals[i][0] - intervals[i - 1][1];
    if (gap < minGap) minGap = gap;
  }
  return minGap;
}

exports.approveSwap = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Please sign in to approve a swap.");
  }
  const data = request.data || {};
  const swapId = String(data.swapId || "").trim();
  // The client computes the schedule doc id from the LOCAL week start (the way it
  // was created); the function would mis-format it in UTC, so it's passed in and
  // re-validated against the swap's branch + slot contents below.
  const scheduleId = String(data.scheduleId || "").trim();
  if (!swapId || !scheduleId) {
    throw new HttpsError("invalid-argument", "Missing swap or schedule reference.");
  }

  // ── Load the swap (the source of truth for branch / day / shift / parties) ──
  const swapRef = db.collection(SHIFT_SWAPS).doc(swapId);
  const swapSnap = await swapRef.get();
  if (!swapSnap.exists) {
    throw new HttpsError("not-found", "This swap request no longer exists.");
  }
  const swap = swapSnap.data() || {};
  const branchId = String(swap.branchId || "");
  const day = String(swap.day || "");
  const shift = String(swap.shift || "");
  const opp = swapOppositeShift(shift);
  const requesterId = String(swap.requesterId || "");
  const targetId = String(swap.targetId || "");

  // ── Permission: admin, or the manager of THIS branch ──
  const callerSnap = await db.collection(USERS).doc(auth.uid).get();
  if (!callerSnap.exists) {
    throw new HttpsError("permission-denied", "Your account profile was not found.");
  }
  const caller = callerSnap.data() || {};
  const callerRole = caller.role || "employee";
  const callerBranch = caller.branchId || "";
  const canApprove =
    callerRole === "admin" ||
    (callerRole === "manager" && callerBranch === branchId);
  if (!canApprove) {
    throw new HttpsError(
      "permission-denied",
      "Only the branch manager or an admin can approve a swap.",
    );
  }

  // The passed scheduleId must belong to this swap's branch (forged-id defense).
  if (!scheduleId.startsWith(`${branchId}_`)) {
    throw new HttpsError("invalid-argument", "Schedule reference does not match this branch.");
  }

  if (swap.status !== "employeeApproved") {
    throw new HttpsError("failed-precondition", "This swap isn’t awaiting manager approval.");
  }

  // ── Slow-changing config (employees + branch policy), read outside the tx ──
  const [reqSnap, tgtSnap, branchSnap] = await Promise.all([
    db.collection(USERS).doc(requesterId).get(),
    db.collection(USERS).doc(targetId).get(),
    db.collection(BRANCHES).doc(branchId).get(),
  ]);
  const reqUser = reqSnap.exists ? reqSnap.data() || {} : null;
  const tgtUser = tgtSnap.exists ? tgtSnap.data() || {} : null;
  if (!reqUser || !tgtUser) {
    throw new HttpsError("failed-precondition", "One of the employees no longer exists.");
  }
  if (reqUser.isActive === false || tgtUser.isActive === false) {
    throw new HttpsError("failed-precondition", "One of the employees is no longer active.");
  }
  const policy = (branchSnap.exists && (branchSnap.data() || {}).swapPolicy) || {};
  const restrictSamePosition = policy.restrictToSamePosition === true;
  const minRestHours =
    Number(policy.minRestHours) > 0 ? Number(policy.minRestHours) : null;

  // Role compatibility (mirror SwapPolicy.positionsCompatible — unset = ok).
  if (restrictSamePosition) {
    const pa = String(reqUser.position || "").trim().toLowerCase();
    const pb = String(tgtUser.position || "").trim().toLowerCase();
    if (pa && pb && pa !== pb) {
      throw new HttpsError(
        "failed-precondition",
        "You can only swap with a coworker in a compatible role.",
      );
    }
  }

  // Future check (mirror swapSlotInFuture). weekStart is an absolute instant
  // (local-midnight Sunday); adding the day offset + shift start gives the slot's
  // start instant, compared against now — timezone-safe (both absolute).
  const weekStartMs =
    swap.weekStart && typeof swap.weekStart.toMillis === "function"
      ? swap.weekStart.toMillis()
      : null;
  if (weekStartMs == null) {
    throw new HttpsError("failed-precondition", "This swap is malformed.");
  }
  const slotStartMs =
    weekStartMs +
    (SWAP_DAY_INDEX[day] || 0) * 24 * 60 * 60 * 1000 +
    swapShiftMinutes(shift).start * 60 * 1000;
  if (slotStartMs <= Date.now()) {
    throw new HttpsError(
      "failed-precondition",
      "This shift has already started — it can no longer be swapped.",
    );
  }

  const schedRef = db.collection(WEEKLY_SCHEDULES).doc(scheduleId);

  // ── Atomic re-validate + exchange ──
  await db.runTransaction(async (tx) => {
    const sSnap = await tx.get(swapRef);
    const schSnap = await tx.get(schedRef);
    if (!sSnap.exists) {
      throw new HttpsError("not-found", "This swap request no longer exists.");
    }
    if ((sSnap.data() || {}).status !== "employeeApproved") {
      throw new HttpsError("failed-precondition", "This swap isn’t awaiting manager approval.");
    }
    if (!schSnap.exists) {
      throw new HttpsError("failed-precondition", "The schedule for this week no longer exists.");
    }
    const sched = schSnap.data() || {};
    if (String(sched.branchId || "") !== branchId) {
      throw new HttpsError("invalid-argument", "Schedule reference does not match this branch.");
    }
    const assignments = sched.assignments || {};
    const shiftArr = swapAssignedUids(assignments, day, shift);
    const oppArr = swapAssignedUids(assignments, day, opp);

    // Slot integrity (TOCTOU): both parties must still hold their slots.
    if (!shiftArr.includes(requesterId)) {
      throw new HttpsError(
        "failed-precondition",
        "The schedule changed — the requester is no longer on that shift.",
      );
    }
    if (!oppArr.includes(targetId)) {
      throw new HttpsError(
        "failed-precondition",
        "The schedule changed — your coworker is no longer on the opposite shift.",
      );
    }

    // Post-exchange arrays (deterministic — no array-transform collisions).
    const newShiftArr = shiftArr.filter((u) => u !== requesterId);
    if (!newShiftArr.includes(targetId)) newShiftArr.push(targetId);
    const newOppArr = oppArr.filter((u) => u !== targetId);
    if (!newOppArr.includes(requesterId)) newOppArr.push(requesterId);

    // Double-booking guard: neither party ends on both shifts that day.
    for (const uid of [requesterId, targetId]) {
      if (newShiftArr.includes(uid) && newOppArr.includes(uid)) {
        throw new HttpsError(
          "failed-precondition",
          "This swap would double-book someone on the same day.",
        );
      }
    }

    // Rest-hours guard (post-exchange, week-bounded) — only if the branch sets it.
    if (minRestHours != null) {
      const after = {};
      for (const d of Object.keys(SWAP_DAY_INDEX)) {
        const dd = assignments[d] || {};
        after[d] = {};
        for (const sh of SWAP_SHIFTS) {
          after[d][sh] = Array.isArray(dd[sh]) ? dd[sh].slice() : [];
        }
      }
      after[day][shift] = newShiftArr;
      after[day][opp] = newOppArr;
      for (const uid of [requesterId, targetId]) {
        if (swapMinGapMinutes(after, uid) < minRestHours * 60) {
          throw new HttpsError(
            "failed-precondition",
            `This swap would leave less than ${minRestHours} hours of rest between shifts.`,
          );
        }
      }
    }

    tx.update(swapRef, {
      status: "managerApproved",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(schedRef, {
      [`assignments.${day}.${shift}`]: newShiftArr,
      [`assignments.${day}.${opp}`]: newOppArr,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { success: true };
});

/**
 * Firestore trigger: deliver the FCM push for a newly-created in-app
 * notification (Notification System Phase 1 — the task-event push path).
 *
 * Task notifications are written by the client (`NotifyTaskEvent`); this trigger
 * reads the recipient's `fcmTokens` and pushes. Broadcast notifications carry
 * `pushedByFunction:true` (already pushed by `sendBroadcast`), so they are
 * skipped here to avoid a double push.
 */
// ─────────────────────────────────────────────────────────────────────────────
// claimFcmToken — guarantees EXCLUSIVE token ownership (the FCM routing fix).
//
// Root problem: an FCM token is per-device, not per-user, and the client can
// only ADD it to the signed-in user's `fcmTokens` (clients can't write OTHER
// users' docs — firestore.rules). The only cross-user cleanup is the client's
// best-effort `forgetUser` on logout; if that fails (offline / force-kill /
// timing) the SAME token stays attached to multiple users, so a send to the old
// user reaches a device now used by someone else (cross-user notification leak).
//
// Fix: whenever a token is ADDED to a user, claim it exclusively here (admin
// privileges) — remove it from every OTHER user's `fcmTokens` and clear any
// matching legacy `fcmToken`. A token then belongs to AT MOST ONE user (the most
// recent to register it), independent of whether the client cleanup ran.
//
// Loop-safe: removing a token from another user SHRINKS their array (no token
// ADDED), so that update's `added` set is empty → early return, no cascade.
exports.claimFcmToken = onDocumentUpdated(`${USERS}/{uid}`, async (event) => {
  const before = event.data.before.data() || {};
  const after = event.data.after.data() || {};
  const beforeTokens = new Set(
    Array.isArray(before.fcmTokens) ? before.fcmTokens : []);
  const afterTokens = Array.isArray(after.fcmTokens) ? after.fcmTokens : [];
  const added = afterTokens.filter((t) => t && !beforeTokens.has(t));
  if (added.length === 0) return; // nothing claimed → loop-safe no-op

  const uid = event.params.uid;
  for (const token of added) {
    try {
      // Other users still holding this token in their array.
      const dupes = await db
        .collection(USERS)
        .where("fcmTokens", "array-contains", token)
        .get();
      // Other users holding it as the legacy single field.
      const legacy = await db
        .collection(USERS)
        .where("fcmToken", "==", token)
        .get();

      const batch = db.batch();
      let count = 0;
      dupes.forEach((d) => {
        if (d.id === uid) return; // keep it on the claimant
        batch.update(d.ref, {
          fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
        });
        count++;
      });
      legacy.forEach((d) => {
        if (d.id === uid) return;
        batch.update(d.ref, {
          fcmToken: admin.firestore.FieldValue.delete(),
        });
        count++;
      });
      if (count > 0) {
        await batch.commit();
        logger.info("claimFcmToken: reclaimed a token", { uid, removedFrom: count });
      }
    } catch (err) {
      logger.warn("claimFcmToken failed", { uid, error: String(err) });
    }
  }
});

/**
 * The ONLY path a client has for creating in-app notifications (M2 fix,
 * 2026-07-03). Direct `notifications/{id}` creates are denied by rules —
 * every notification doc a client produces goes through this callable, which
 * validates before writing (the docs then flow to `onNotificationCreated`
 * for push, unchanged):
 *   - the caller must be signed in, exist, and be active;
 *   - `type` must be one of the CLIENT-legit types (task lifecycle + swap
 *     workflow — reminder/broadcast types are produced server-side only);
 *   - every recipient must exist and be REACHABLE by the caller: an admin
 *     reaches anyone; everyone else only their own branch (covers all real
 *     flows: coworker swaps, employee→manager review pings, manager→staff
 *     assignments);
 *   - title/body are length-capped; the payload is reduced to known keys;
 *   - `senderUid` is SERVER-STAMPED from auth — never forgeable.
 */
const CLIENT_NOTIFICATION_TYPES = new Set([
  "taskAssigned", "taskRework", "taskSubmitted", "taskApproved", "taskRejected",
  "swapRequested", "swapAccepted", "swapApproved", "swapRejected",
]);
const NOTIFICATION_PAYLOAD_KEYS = ["taskId", "route", "revisionNumber", "swapId"];

exports.sendNotification = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Please sign in.");
  }
  const callerSnap = await db.collection(USERS).doc(auth.uid).get();
  if (!callerSnap.exists) {
    throw new HttpsError("permission-denied", "Your account profile was not found.");
  }
  const caller = callerSnap.data() || {};
  if (caller.isActive === false) {
    throw new HttpsError("permission-denied", "This account is disabled.");
  }
  const callerIsAdmin = (caller.role || "employee") === "admin";
  const callerBranch = String(caller.branchId || "");

  const items = Array.isArray(request.data && request.data.notifications)
    ? request.data.notifications
    : [];
  if (items.length === 0 || items.length > 50) {
    throw new HttpsError("invalid-argument", "Send between 1 and 50 notifications.");
  }

  const batch = db.batch();
  let queued = 0;
  for (const raw of items) {
    const recipientUid = String((raw && raw.recipientUid) || "").trim();
    const type = String((raw && raw.type) || "").trim();
    const title = String((raw && raw.title) || "").trim().slice(0, 120);
    const body = String((raw && raw.body) || "").trim().slice(0, 500);
    if (!recipientUid || (!title && !body)) {
      throw new HttpsError("invalid-argument", "Each notification needs a recipient and content.");
    }
    if (!CLIENT_NOTIFICATION_TYPES.has(type)) {
      throw new HttpsError("invalid-argument", `"${type}" is not a client notification type.`);
    }

    // Reachability: admin → anyone; others → own branch only.
    const recipientSnap = await db.collection(USERS).doc(recipientUid).get();
    if (!recipientSnap.exists) continue; // stale recipient — skip, not fatal
    const recipientBranch = String((recipientSnap.data() || {}).branchId || "");
    const reachable = callerIsAdmin
      || (callerBranch !== "" && recipientBranch === callerBranch);
    if (!reachable) {
      throw new HttpsError(
        "permission-denied",
        "You can only notify people in your own branch.",
      );
    }

    // Sanitized payload — only the keys the tap handler understands.
    const rawPayload = (raw && raw.payload) || {};
    const payload = {};
    for (const k of NOTIFICATION_PAYLOAD_KEYS) {
      if (rawPayload[k] !== undefined && rawPayload[k] !== null) {
        payload[k] = typeof rawPayload[k] === "number"
          ? rawPayload[k]
          : String(rawPayload[k]);
      }
    }

    const ref = db.collection(NOTIFICATIONS).doc();
    batch.set(ref, {
      id: ref.id,
      recipientUid,
      senderUid: auth.uid, // server-stamped — the client cannot forge this
      type,
      title,
      body,
      readAt: null,
      payload,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    queued++;
  }

  if (queued > 0) await batch.commit();
  return { created: queued };
});

exports.onNotificationCreated = onDocumentCreated(
  `${NOTIFICATIONS}/{id}`,
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const n = snap.data() || {};

    // Already pushed by the broadcast engine — don't double-send.
    if (n.pushedByFunction === true) return;

    const recipientUid = String(n.recipientUid || "").trim();
    if (!recipientUid) return;

    const title = String(n.title || "").trim();
    const body = String(n.body || "").trim();
    if (!title && !body) return;

    // Gather the recipient's device tokens (array + legacy single field).
    const userSnap = await db.collection(USERS).doc(recipientUid).get();
    if (!userSnap.exists) return;
    const user = userSnap.data() || {};
    const tokenSet = new Set();
    if (Array.isArray(user.fcmTokens)) {
      for (const t of user.fcmTokens) if (t) tokenSet.add(t);
    }
    if (user.fcmToken) tokenSet.add(user.fcmToken);
    const tokens = Array.from(tokenSet);
    if (tokens.length === 0) return;

    const payload = n.payload || {};
    // Data values must be strings — they ride along to the tap handler, which
    // feeds them to the shared deep-link resolver. EVERY target id the resolver
    // reads must be forwarded here or the deep link is lost on a background /
    // cold-start tap: taskId · caseId · requestId · broadcastId · swapId
    // (schedule route). `route` selects which id the resolver uses.
    const message = {
      notification: { title, body },
      data: {
        type: String(n.type || ""),
        // Intended recipient — the client drops a push whose recipientUid != the
        // signed-in user (defense-in-depth #3). This path is already per-recipient.
        recipientUid: String(recipientUid),
        taskId: String(payload.taskId || ""),
        caseId: String(payload.caseId || ""),
        requestId: String(payload.requestId || ""),
        broadcastId: String(payload.broadcastId || ""),
        swapId: String(payload.swapId || ""),
        category: String(payload.category || ""),
        revisionNumber:
          payload.revisionNumber == null ? "" : String(payload.revisionNumber),
        route: String(payload.route || ""),
      },
    };

    // Push (chunked) + prune dead tokens.
    const removals = [];
    let successCount = 0;
    let failureCount = 0;
    for (let i = 0; i < tokens.length; i += MULTICAST_CHUNK) {
      const batch = tokens.slice(i, i + MULTICAST_CHUNK);
      const response = await messaging.sendEachForMulticast({ ...message, tokens: batch });
      successCount += response.successCount;
      failureCount += response.failureCount;
      response.responses.forEach((r, idx) => {
        if (r.success) return;
        const code = r.error && r.error.code;
        // DIAGNOSTIC: the EXACT per-token failure reason (FCM discards it). See
        // the broadcast path for the common codes (APNs / stale-token).
        logger.warn("task notification token send failed", {
          recipientUid,
          tokenSuffix: String(batch[idx]).slice(-10),
          code,
          message: r.error && r.error.message,
        });
        if (isDeadTokenError(code)) removals.push(batch[idx]);
      });
    }
    if (removals.length > 0) {
      await db
        .collection(USERS)
        .doc(recipientUid)
        .update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...removals) })
        .catch(() => {});
    }

    // Log REAL delivery, not just the attempt count. `tokenCount` alone (the old
    // log) made a 0-delivered push look healthy.
    logger.info("notification pushed", {
      type: n.type,
      recipientUid,
      tokenCount: tokens.length,
      successCount,
      failureCount,
    });
  },
);

// ── Recurrence math (mirrors lib/.../recurrence_rule.dart) ──
function addDays(date, days) {
  const d = new Date(date.getTime());
  d.setDate(d.getDate() + days);
  return d;
}
function addMonths(date, months) {
  const d = new Date(date.getTime());
  const day = d.getDate();
  d.setDate(1);
  d.setMonth(d.getMonth() + months);
  const lastDay = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
  d.setDate(Math.min(day, lastDay));
  return d;
}

// The next run strictly after `from` (a JS Date) for a schedule doc, or null
// when the series has completed (one-time, or past endDate).
function computeScheduleNextRun(s, from) {
  const type = s.recurrenceType || "oneTime";
  if (type === "oneTime") return null;
  let next;
  if (type === "daily") next = addDays(from, 1);
  else if (type === "weekly") next = addDays(from, 7);
  else if (type === "monthly") next = addMonths(from, 1);
  else if (type === "custom") next = addDays(from, Math.max(1, Number(s.interval) || 1));
  else return null;
  const endDate = s.endDate && s.endDate.toDate ? s.endDate.toDate() : null;
  if (endDate && next > endDate) return null;
  return admin.firestore.Timestamp.fromDate(next);
}

/**
 * The scheduled-broadcast poller (Phase 2 Commit 4) — the chosen scheduler
 * architecture (a single onSchedule function, not per-schedule Cloud Scheduler
 * jobs): scales to any number of schedules with one cron job. Every 5 minutes it
 * fires every due, enabled schedule through the shared `dispatchBroadcast`
 * engine, then advances `nextRunAt` from the recurrence rule (or disables a
 * completed one-time / past-endDate schedule). Up to ~5-min firing granularity.
 *
 * Query is `nextRunAt <= now` only (a single-field inequality — automatic index);
 * the `enabled` flag is filtered in JS to avoid a composite index.
 */
exports.runBroadcastSchedules = onSchedule("every 5 minutes", async () => {
  const now = admin.firestore.Timestamp.now();
  const snap = await db
    .collection(BROADCAST_SCHEDULES)
    .where("nextRunAt", "<=", now)
    .get();

  let fired = 0;
  for (const doc of snap.docs) {
    const s = doc.data() || {};
    if (s.enabled === false) continue; // paused

    // The sender's current branch (for a manager's custom-recipient filter).
    let senderBranch = "";
    try {
      const u = await db.collection(USERS).doc(String(s.senderId || "")).get();
      senderBranch = u.exists ? u.data().branchId || "" : "";
    } catch (_) {
      // best-effort
    }

    try {
      await dispatchBroadcast({
        senderId: s.senderId,
        senderRole: s.senderRole,
        senderBranch,
        senderName: s.senderName,
        title: s.title,
        body: s.message,
        category: s.category,
        audience: s.audience,
        branchId: s.branchId || "",
        targetUserId: "",
        targetUserIds: Array.isArray(s.targetUserIds) ? s.targetUserIds : [],
        roleFilter: s.roleFilter || "",
      });
      fired += 1;
    } catch (err) {
      logger.warn("schedule dispatch failed", { id: doc.id, error: String(err) });
    }

    const nextRunAt = computeScheduleNextRun(s, now.toDate());
    await doc.ref
      .update({
        lastRunAt: now,
        runCount: (Number(s.runCount) || 0) + 1,
        nextRunAt: nextRunAt, // null disables a completed schedule
        enabled: nextRunAt !== null,
      })
      .catch((err) =>
        logger.warn("schedule advance failed", { id: doc.id, error: String(err) }),
      );
  }

  logger.info("broadcast schedules run", { due: snap.size, fired });
});

/**
 * Daily housekeeping (retention / cleanup): hard-deletes long-dead docs so the
 * collections stay lean — archived notifications older than 60 days.
 */
exports.broadcastHousekeeping = onSchedule("every 24 hours", async () => {
  const now = Date.now();
  const cutoff = (days) =>
    admin.firestore.Timestamp.fromMillis(now - days * 24 * 60 * 60 * 1000);

  const deleteQuery = async (query, label) => {
    let removed = 0;
    // Page in chunks to respect the 500-write batch limit.
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const snap = await query.limit(BATCH_LIMIT).get();
      if (snap.empty) break;
      const batch = db.batch();
      snap.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
      removed += snap.size;
      if (snap.size < BATCH_LIMIT) break;
    }
    if (removed > 0) logger.info(`housekeeping removed ${removed} ${label}`);
  };

  try {
    await deleteQuery(
      db.collection(NOTIFICATIONS).where("archivedAt", "<=", cutoff(60)),
      "old archived notifications",
    );
  } catch (err) {
    logger.warn("housekeeping failed", { error: String(err) });
  }
});

// ── Task reminder rules (mirrors lib/features/task/domain/reminder_rules.dart) ──
const REMINDER_ORDER = ["due24h", "due1h", "overdue"];

function reminderInQuietHours(hour, startHour, endHour) {
  if (startHour === endHour) return false;
  if (startHour < endHour) return hour >= startHour && hour < endHour;
  return hour >= startHour || hour < endHour; // wraps midnight
}

function reminderDueKind(deadline, now, lastKind, count, cfg) {
  if (!cfg.enabled) return null;
  if (count >= cfg.maxReminders) return null;
  if (reminderInQuietHours(now.getUTCHours(), cfg.quietStartHour, cfg.quietEndHour)) {
    return null;
  }
  const diffMs = deadline.getTime() - now.getTime();
  let kind;
  if (diffMs < 0) kind = "overdue";
  else if (diffMs <= 60 * 60 * 1000) kind = "due1h";
  else if (diffMs <= 24 * 60 * 60 * 1000) kind = "due24h";
  else return null;
  // Only escalate forward.
  if (lastKind && REMINDER_ORDER.indexOf(kind) <= REMINDER_ORDER.indexOf(lastKind)) {
    return null;
  }
  return kind;
}

/**
 * Automated task reminders (Phase 2 Commit 5). Every 30 minutes it scans tasks
 * due within 24h (or overdue) and sends an in-app + push reminder to the
 * assignees, escalating due24h → due1h → overdue with a per-task ledger
 * (`taskReminders/{taskId}`) + quiet hours + a max-reminders cap to avoid spam.
 * Config lives in `reminderConfig/global` (defaults applied when absent). Quiet
 * hours are evaluated in UTC (the function's timezone).
 */
exports.runTaskReminders = onSchedule("every 30 minutes", async () => {
  const now = new Date();

  // Config (defaults when the doc is absent).
  let cfg = { enabled: true, quietStartHour: 22, quietEndHour: 7, maxReminders: 3 };
  try {
    const cSnap = await db.collection(REMINDER_CONFIG).doc("global").get();
    if (cSnap.exists) {
      const c = cSnap.data() || {};
      cfg = {
        enabled: c.enabled !== false,
        quietStartHour: Number.isFinite(c.quietStartHour) ? c.quietStartHour : 22,
        quietEndHour: Number.isFinite(c.quietEndHour) ? c.quietEndHour : 7,
        maxReminders: Number.isFinite(c.maxReminders) ? c.maxReminders : 3,
      };
    }
  } catch (_) {
    // best-effort; use defaults
  }
  if (!cfg.enabled) {
    logger.info("task reminders disabled");
    return;
  }

  // Tasks due within 24h or already overdue (single-field inequality).
  const soon = admin.firestore.Timestamp.fromMillis(now.getTime() + 24 * 60 * 60 * 1000);
  const snap = await db.collection(TASKS).where("deadline", "<=", soon).get();

  const TERMINAL = new Set(["approved", "rejected"]);
  let sent = 0;
  for (const doc of snap.docs) {
    const t = doc.data() || {};
    if (TERMINAL.has(t.status || "pending")) continue;
    const deadline = t.deadline && t.deadline.toDate ? t.deadline.toDate() : null;
    if (!deadline) continue;
    const assignees = Array.isArray(t.assigneeIds) ? t.assigneeIds.filter(Boolean) : [];
    if (assignees.length === 0) continue;

    // Per-task reminder ledger.
    const ledgerRef = db.collection(TASK_REMINDERS).doc(doc.id);
    let lastKind = null;
    let count = 0;
    try {
      const lSnap = await ledgerRef.get();
      if (lSnap.exists) {
        const l = lSnap.data() || {};
        lastKind = l.lastKind || null;
        count = Number(l.count) || 0;
      }
    } catch (_) {
      // best-effort
    }

    const kind = reminderDueKind(deadline, now, lastKind, count, cfg);
    if (!kind) continue;

    const type = kind === "overdue" ? "taskOverdue" : "taskReminder";
    const title = kind === "overdue" ? "Task Overdue" : "Task Reminder";
    const dueLabel = kind === "overdue" ? "is overdue" : "is due soon";
    const body = `${t.title || "A task"} ${dueLabel}`;
    const payload = { taskId: doc.id, route: "task_details", kind };

    try {
      const batch = db.batch();
      for (const uid of assignees) {
        const ref = db.collection(NOTIFICATIONS).doc();
        batch.set(ref, {
          id: ref.id,
          recipientUid: uid,
          senderUid: "system",
          type,
          title,
          body,
          readAt: null,
          payload,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      await ledgerRef.set(
        {
          taskId: doc.id,
          lastKind: kind,
          count: count + 1,
          lastSentAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      sent += 1;
    } catch (err) {
      logger.warn("task reminder failed", { taskId: doc.id, error: String(err) });
    }
  }

  logger.info("task reminders run", { scanned: snap.size, sent });
});

// ── Recurring shift-task instance generation (Shift Assignment feature) ──

// yyyy-MM-dd in UTC (a Cloud Function has no per-branch local time, so UTC is
// the deterministic convention — mirrors ScheduleWeek's date-key format).
function isoDate(d) {
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

// 1 = Monday … 7 = Sunday (matches RecurringTaskTemplateEntity.weekday /
// Dart's DateTime.weekday convention).
function isoWeekday(d) {
  const jsDay = d.getUTCDay(); // 0 = Sunday … 6 = Saturday
  return jsDay === 0 ? 7 : jsDay;
}

// weekly_schedules.assignments.<day> key spelling — matches SWAP_DAY_INDEX.
const SCHEDULE_DAY_NAMES = [
  "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
];
function scheduleDayName(d) {
  return SCHEDULE_DAY_NAMES[d.getUTCDay()];
}

// The Sunday (UTC midnight) that starts the week containing d, as a
// yyyy-MM-dd key — mirrors ScheduleWeek.startOf/docId (`<branchId>_<key>`).
function weekStartKey(d) {
  const sunday = new Date(Date.UTC(
    d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() - d.getUTCDay(),
  ));
  return isoDate(sunday);
}

/**
 * Daily instance generation for recurring shift-task templates (Shift
 * Assignment feature). Scans active `recurringTaskTemplates` and, for each one
 * due today (daily, or weekly matching today's ISO weekday), creates *one*
 * real `tasks/{id}` document at a **deterministic id**
 * (`rt_{templateId}_{yyyy-MM-dd}`, UTC) — the existence check against that id
 * is the entire duplicate-prevention guarantee (no separate ledger needed),
 * so overlapping/duplicate runs are always safe. Mirrors `runTaskReminders`'s
 * style (small collection scan, per-item try/catch, summary log). Notifies
 * today's rostered employees by writing straight to `notifications` (reuses
 * the existing `onNotificationCreated` trigger — no new push logic) and
 * `swapAssignedUids` (already defined above for `approveSwap`) to read the
 * roster off the same `weekly_schedules` doc shape.
 */
exports.generateShiftTaskInstances = onSchedule("every 24 hours", async () => {
  const now = new Date();
  const todayKey = isoDate(now);
  const todayDow = isoWeekday(now);
  const dayName = scheduleDayName(now);

  const snap = await db
    .collection(RECURRING_TASK_TEMPLATES)
    .where("active", "==", true)
    .get();

  let created = 0;
  for (const doc of snap.docs) {
    const t = doc.data() || {};
    const repeat = t.repeat || "daily";
    // "once" is defensive only — the client never persists a template row
    // with repeat:"once" (a single shift task is created directly instead).
    if (repeat === "once") continue;
    if (repeat === "weekly" && Number(t.weekday) !== todayDow) continue;

    const branchId = String(t.branchId || "");
    if (!branchId) continue;
    const shift = t.shift === "night" ? "night" : "morning";
    const instanceId = `rt_${doc.id}_${todayKey}`;
    const ref = db.collection(TASKS).doc(instanceId);

    try {
      if ((await ref.get()).exists) continue; // already generated today

      const checklist = Array.isArray(t.checklistItems)
        ? t.checklistItems.map((c) => ({
            id: String((c && c.id) || ""),
            title: String((c && c.title) || ""),
            isRequired: !c || c.isRequired !== false,
            completed: false,
            completedAt: null,
          }))
        : [];

      await ref.set({
        id: instanceId,
        title: t.title || "",
        description: t.description || null,
        type: "daily",
        status: "pending",
        priority: t.priority || "normal",
        branchId,
        assigneeIds: [],
        assignedEmployeeId: null,
        checklist,
        referenceAttachments: [],
        createdBy: t.createdBy || null,
        assignedShiftId: null,
        shift,
        assignmentType: "shift",
        instanceDate: admin.firestore.Timestamp.fromDate(
          new Date(`${todayKey}T00:00:00.000Z`),
        ),
        sourceTemplateId: doc.id,
        deadline: null,
        notes: null,
        proofImageUrl: null,
        startedAt: null,
        submittedAt: null,
        approvedBy: null,
        approvedAt: null,
        rejectedBy: null,
        rejectedAt: null,
        reviewNotes: null,
        revisionNumber: 0,
        requiresRework: false,
        rejectionReason: null,
        recurrence: null,
        activityLog: [
          {
            status: "pending",
            actorId: "system",
            actorName: null,
            at: admin.firestore.Timestamp.fromDate(now),
            note: "Auto-generated (recurring shift task)",
            attachments: [],
          },
        ],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      created++;

      // Notify today's rostered employees on this shift (best-effort).
      try {
        const scheduleId = `${branchId}_${weekStartKey(now)}`;
        const schedSnap = await db.collection(WEEKLY_SCHEDULES).doc(scheduleId).get();
        const uids = schedSnap.exists
          ? swapAssignedUids(schedSnap.data().assignments || {}, dayName, shift)
          : [];
        if (uids.length) {
          const batch = db.batch();
          for (const uid of uids) {
            const nref = db.collection(NOTIFICATIONS).doc();
            batch.set(nref, {
              id: nref.id,
              recipientUid: uid,
              senderUid: "system",
              type: "taskAssigned",
              title: "New Task Assigned",
              body: t.title || "A new shift task was assigned",
              readAt: null,
              payload: { taskId: instanceId, route: "task_details" },
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
          await batch.commit();
        }
      } catch (notifyErr) {
        logger.warn("shift task notify failed", {
          taskId: instanceId,
          error: String(notifyErr),
        });
      }
    } catch (err) {
      logger.warn("shift task instance generation failed", {
        templateId: doc.id,
        error: String(err),
      });
    }
  }

  logger.info("shift task instances generated", { templates: snap.size, created });
});

/**
 * Task retention sweep (Home Dashboard redesign, P3). Runs daily:
 *
 *  1. ARCHIVE — every APPROVED task older than `archiveAfterDays` (default 30)
 *     is soft-archived: `archivedAt` is stamped so the client filters it out of
 *     active lists/feeds. The doc STAYS in `tasks` (never moved to another
 *     collection), so statistics' lifetime "completed" counts, audit history,
 *     and `/task/:id` deep-links keep working. When `coldTierImages` is true its
 *     Storage evidence under `tasks/{id}/` is re-classed to COLDLINE (~85%
 *     cheaper storage; archived proof is rarely read again).
 *  2. DELETE (opt-in) — only when `deleteAfterDays` is a positive number: an
 *     archived task older than that is hard-deleted, its `tasks/{id}/` Storage
 *     prefix FIRST (so evidence never orphans), then the doc. Off by default —
 *     soft archive is forever unless an org explicitly opts into purging.
 *
 * Config in `config/taskRetention` (defaults applied when the doc is absent).
 * All queries are single-field inequalities on an auto-indexed field (no
 * composite index to deploy). Idempotent + outage-tolerant: the archive pass
 * pages by `approvedAt` with a cursor and skips already-archived docs, so it
 * never starves; the Storage ops are safe to repeat.
 */
exports.taskHousekeeping = onSchedule("every 24 hours", async () => {
  const now = Date.now();
  const nowTs = admin.firestore.Timestamp.fromMillis(now);
  const cutoff = (days) =>
    admin.firestore.Timestamp.fromMillis(now - days * 24 * 60 * 60 * 1000);

  // Config (defaults when the doc is absent). `deleteAfterDays` is opt-in: any
  // non-positive / missing value keeps soft archive forever.
  let cfg = { archiveAfterDays: 30, coldTierImages: true, deleteAfterDays: null };
  try {
    const cSnap = await db.collection(CONFIG).doc("taskRetention").get();
    if (cSnap.exists) {
      const c = cSnap.data() || {};
      cfg = {
        archiveAfterDays: Number.isFinite(c.archiveAfterDays) && c.archiveAfterDays > 0
          ? c.archiveAfterDays : 30,
        coldTierImages: c.coldTierImages !== false,
        deleteAfterDays: Number.isFinite(c.deleteAfterDays) && c.deleteAfterDays > 0
          ? c.deleteAfterDays : null,
      };
    }
  } catch (_) {
    // best-effort; use defaults
  }

  const bucket = admin.storage().bucket();
  let archived = 0;
  let coldTiered = 0;
  let deleted = 0;

  // Best-effort: re-class every object under tasks/{id}/ to a colder class.
  const coldTier = async (taskId) => {
    try {
      const [files] = await bucket.getFiles({ prefix: `${TASKS}/${taskId}/` });
      for (const f of files) {
        try {
          const [meta] = await f.getMetadata();
          if (String(meta.storageClass || "STANDARD").toUpperCase() === "COLDLINE") continue;
          await f.setStorageClass("COLDLINE");
          coldTiered++;
        } catch (e) {
          logger.warn("cold-tier object failed", { taskId, file: f.name, error: String(e) });
        }
      }
    } catch (e) {
      logger.warn("cold-tier list failed", { taskId, error: String(e) });
    }
  };

  // ── 1. ARCHIVE approved tasks past the window ──
  // `approvedAt` is set ONLY on a currently-approved task (an admin reopen
  // clears it), so `approvedAt <= cutoff` returns exactly the approved tasks
  // old enough to archive. We page by `approvedAt` (cursor) and skip any doc
  // already archived, so re-runs / long outages can't starve un-archived docs.
  const RUN_CAP = 5000; // bound per-run scan; daily cadence drains any backlog
  try {
    let scanned = 0;
    let last = null;
    // eslint-disable-next-line no-constant-condition
    while (scanned < RUN_CAP) {
      let q = db
        .collection(TASKS)
        .where("approvedAt", "<=", cutoff(cfg.archiveAfterDays))
        .orderBy("approvedAt", "asc")
        .limit(BATCH_LIMIT);
      if (last) q = q.startAfter(last);
      const snap = await q.get();
      if (snap.empty) break;

      const batch = db.batch();
      const toColdTier = [];
      let n = 0;
      for (const doc of snap.docs) {
        last = doc;
        const t = doc.data() || {};
        if ((t.status || "") !== "approved") continue; // reopened → skip
        if (t.archivedAt) continue; // already archived on a prior run
        batch.update(doc.ref, { archivedAt: nowTs });
        if (cfg.coldTierImages) toColdTier.push(doc.id);
        n++;
      }
      if (n > 0) await batch.commit();
      archived += n;
      for (const id of toColdTier) await coldTier(id);

      scanned += snap.size;
      if (snap.size < BATCH_LIMIT) break;
    }
  } catch (err) {
    logger.warn("task archive sweep failed", { error: String(err) });
  }

  // ── 2. DELETE archived tasks past the (opt-in) purge window ──
  if (cfg.deleteAfterDays) {
    try {
      const snap = await db
        .collection(TASKS)
        .where("archivedAt", "<=", cutoff(cfg.deleteAfterDays))
        .limit(BATCH_LIMIT)
        .get();
      for (const doc of snap.docs) {
        // Evidence first, so a crash between the two never orphans Storage.
        try {
          await bucket.deleteFiles({ prefix: `${TASKS}/${doc.id}/`, force: true });
        } catch (e) {
          logger.warn("delete task storage failed", { taskId: doc.id, error: String(e) });
        }
        await doc.ref.delete();
        deleted++;
      }
    } catch (err) {
      logger.warn("task delete sweep failed", { error: String(err) });
    }
  }

  logger.info("task housekeeping done", { archived, coldTiered, deleted });
});

/**
 * ── Case Management notification fan-out ─────────────────────────────────────
 *
 * Case notifications are produced SERVER-SIDE (not by the client) because a
 * case's reporter identity lives in the private `cases/{id}/reporter/identity`
 * subdoc — a manager can't read it, so they can't notify a confidential reporter
 * from their own client. The Admin SDK also owns the `opening` + `system`
 * messages (clients can't forge them — see firestore.rules). These triggers
 * write per-recipient `notifications/{id}` docs with the Admin SDK (bypassing
 * the `create: if false` rule); `onNotificationCreated` then delivers the FCM
 * push (they intentionally do NOT set `pushedByFunction`). `senderUid` is left
 * empty (system) so a recipient reading their own notification can never resolve
 * a confidential reporter from it.
 */

// Reads the reporter uid from a case's private identity subdoc (best-effort).
async function caseReporterUid(caseId) {
  try {
    const idSnap = await db
      .collection(CASES)
      .doc(caseId)
      .collection("reporter")
      .doc("identity")
      .get();
    if (idSnap.exists) return String((idSnap.data() || {}).createdByUserId || "");
  } catch (e) {
    logger.warn("case identity read failed", { caseId, error: String(e) });
  }
  return "";
}

// The routed recipients for a case (branch managers and/or admins), minus the
// reporter. Mirrors the client `CaseRecipient` routing.
async function resolveCaseRecipients(caseData, excludeUid) {
  const recipient = String(caseData.recipient || "manager");
  const branchId = String(caseData.branchId || "");
  const out = new Set();
  if (recipient === "manager" || recipient === "both") {
    try {
      const snap = await db
        .collection(USERS)
        .where("branchId", "==", branchId)
        .where("role", "==", "manager")
        .get();
      snap.docs.forEach((d) => {
        if ((d.data() || {}).isActive !== false) out.add(d.id);
      });
    } catch (e) {
      logger.warn("case manager lookup failed", { error: String(e) });
    }
  }
  if (recipient === "admin" || recipient === "both") {
    try {
      const snap = await db.collection(USERS).where("role", "==", "admin").get();
      snap.docs.forEach((d) => {
        if ((d.data() || {}).isActive !== false) out.add(d.id);
      });
    } catch (e) {
      logger.warn("case admin lookup failed", { error: String(e) });
    }
  }
  out.delete(excludeUid);
  out.delete("");
  return [...out];
}

// Writes one in-app notification doc per recipient (Admin SDK). onNotificationCreated
// handles the push. senderUid is intentionally empty (privacy). Best-effort.
async function writeCaseNotifications(recipientUids, { type, title, body, caseId }) {
  const uids = [...new Set(recipientUids.filter(Boolean))];
  if (uids.length === 0) return;
  const payload = { caseId, route: "case_details" };
  try {
    for (let i = 0; i < uids.length; i += BATCH_LIMIT) {
      const slice = uids.slice(i, i + BATCH_LIMIT);
      const batch = db.batch();
      for (const uid of slice) {
        const ref = db.collection(NOTIFICATIONS).doc();
        batch.set(ref, {
          id: ref.id,
          recipientUid: uid,
          senderUid: "", // system — never leak a confidential reporter
          type,
          title: String(title || "").slice(0, 120),
          body: String(body || "").slice(0, 500),
          readAt: null,
          payload,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  } catch (err) {
    logger.warn("failed to persist case notifications", { error: String(err) });
  }
}

// A one-line preview of a message for the inbox row.
function caseMessagePreview(text, attachments) {
  const t = String(text || "").trim();
  if (t) return t.slice(0, 140);
  if (Array.isArray(attachments) && attachments.length > 0) return "📎 Attachment";
  return "";
}

// Human label for a status-change system message.
function caseStatusSystemLabel(status) {
  switch (status) {
    case "inDiscussion": return "Marked In Discussion";
    case "waitingResponse": return "Waiting for a response";
    case "closed": return "Case closed";
    case "open": return "Case reopened";
    default: return "Status updated";
  }
}

// Appends a server-authored message (opening / system) + bumps the parent case.
// Clients cannot write these kinds (firestore.rules), so they are trusted.
async function appendServerCaseMessage(caseId, message, preview) {
  try {
    const msgRef = db.collection(CASES).doc(caseId).collection("messages").doc();
    const batch = db.batch();
    batch.set(msgRef, {
      ...message,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    batch.update(db.collection(CASES).doc(caseId), {
      lastMessagePreview: preview,
      messageCount: admin.firestore.FieldValue.increment(1),
      lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await batch.commit();
  } catch (e) {
    logger.warn("failed to append server case message", { caseId, error: String(e) });
  }
}

// A new case → write the opening message (de-identified per privacy) + notify
// the routed recipients (branch managers / admins).
exports.onCaseCreated = onDocumentCreated(`${CASES}/{caseId}`, async (event) => {
  const snap = event.data;
  if (!snap) return;
  const caseData = snap.data() || {};
  const caseId = event.params.caseId;

  const reporterUid = await caseReporterUid(caseId);
  const confidential = String(caseData.privacy || "normal") !== "normal";
  const description = String(caseData.description || "");
  const attachments = Array.isArray(caseData.attachments) ? caseData.attachments : [];

  await appendServerCaseMessage(
    caseId,
    {
      authorId: confidential ? "" : reporterUid,
      authorName: confidential
        ? "Confidential Sender"
        : String(caseData.reporterDisplayName || "Reporter"),
      authorRole: "reporter",
      kind: "opening",
      text: description || null,
      attachments,
      systemEvent: null,
    },
    caseMessagePreview(description, attachments),
  );

  const recipients = await resolveCaseRecipients(caseData, reporterUid);
  if (recipients.length === 0) return;
  const urgent = caseData.urgent === true;
  await writeCaseNotifications(recipients, {
    type: "caseOpened",
    title: urgent ? "New Case • Urgent" : "New Case",
    body: String(caseData.subject || "A new case was opened"),
    caseId,
  });
});

// A case status changed → append a system message + notify the affected party.
// Only reacts to a real status transition (its own lastMessage* bumps do not
// change status, so there is no re-fire loop).
exports.onCaseUpdated = onDocumentUpdated(`${CASES}/{caseId}`, async (event) => {
  const before = (event.data && event.data.before && event.data.before.data()) || {};
  const after = (event.data && event.data.after && event.data.after.data()) || {};
  const caseId = event.params.caseId;

  const beforeStatus = String(before.status || "open");
  const afterStatus = String(after.status || "open");
  if (beforeStatus === afterStatus) return;

  const label = caseStatusSystemLabel(afterStatus);
  await appendServerCaseMessage(
    caseId,
    {
      authorId: "",
      authorName: "System",
      authorRole: "system",
      kind: "system",
      text: label,
      attachments: [],
      systemEvent: afterStatus,
    },
    label,
  );

  const reporterUid = await caseReporterUid(caseId);
  const reopened = beforeStatus === "closed" && afterStatus !== "closed";
  if (reopened) {
    const recipients = await resolveCaseRecipients(after, reporterUid);
    await writeCaseNotifications(recipients, {
      type: "caseUpdated",
      title: "Case Reopened",
      body: String(after.subject || "A case was reopened"),
      caseId,
    });
  } else if (reporterUid) {
    const closed = afterStatus === "closed";
    const bodyByStatus = {
      inDiscussion: "Your case is now in discussion",
      waitingResponse: "A response is needed on your case",
      closed: "Your case was closed",
    };
    await writeCaseNotifications([reporterUid], {
      type: closed ? "caseClosed" : "caseUpdated",
      title: closed ? "Case Closed" : "Case Update",
      body: bodyByStatus[afterStatus] || String(after.subject || "Case updated"),
      caseId,
    });
  }
});

// A new conversation message → bump the parent case + notify the OTHER party.
// opening/system messages are handled by their own creators (skipped here).
exports.onCaseMessageCreated = onDocumentCreated(
  `${CASES}/{caseId}/messages/{messageId}`,
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const message = snap.data() || {};
    const caseId = event.params.caseId;
    if (String(message.kind || "message") !== "message") return;

    const preview = caseMessagePreview(
      message.text,
      Array.isArray(message.attachments) ? message.attachments : [],
    );
    try {
      await db.collection(CASES).doc(caseId).update({
        lastMessagePreview: preview,
        messageCount: admin.firestore.FieldValue.increment(1),
        lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logger.warn("failed to bump case on message", { caseId, error: String(e) });
    }

    const caseSnap = await db.collection(CASES).doc(caseId).get();
    const caseData = caseSnap.exists ? (caseSnap.data() || {}) : {};
    const reporterUid = await caseReporterUid(caseId);
    const authorId = String(message.authorId || "");
    const byReporter = authorId === "" || authorId === reporterUid;
    if (byReporter) {
      const recipients = await resolveCaseRecipients(caseData, reporterUid);
      await writeCaseNotifications(recipients, {
        type: "caseReplied",
        title: "New Case Reply",
        body: String(caseData.subject || "New reply on a case"),
        caseId,
      });
    } else if (reporterUid && authorId !== reporterUid) {
      await writeCaseNotifications([reporterUid], {
        type: "caseReplied",
        title: "New Case Reply",
        body: String(caseData.subject || "New reply on your case"),
        caseId,
      });
    }
  },
);


// ═══════════════════════════════════════════════════════════════════════════
//  Operations Requests (in-the-moment approvals) — server-side timeline +
//  notifications + the human-friendly REQ-###### sequence.
//
//  The client writes the request doc + its comment/attachment events; the Admin
//  SDK owns everything a client can't be trusted with:
//    • the opening `submitted` timeline event + the REQ-###### refCode,
//    • the decision events (approved/rejected),
//    • the `lastEvent*` inbox bumps,
//    • every notification (routing depends on branch/role/policy lookups).
//  No re-fire loop: the lastEvent*/refCode bumps never change `status`, and the
//  server-written events are `submitted`/lifecycle kinds the event trigger skips.
// ═══════════════════════════════════════════════════════════════════════════

// A one-line preview of a request event for the inbox row.
function requestEventPreview(text, attachments) {
  const t = String(text || "").trim();
  if (t) return t.slice(0, 140);
  if (Array.isArray(attachments) && attachments.length > 0) return "📎 Attachment";
  return "";
}

// The routed approvers for a request — the request's own-branch managers and all
// admins — minus [excludeUid]. A request is a simple approval, so the decider is
// always "the branch manager or an admin"; there is no per-type policy.
async function resolveRequestApprovers(requestData, excludeUid) {
  const branchId = String(requestData.branchId || "");
  const out = new Set();
  if (branchId) {
    try {
      const snap = await db.collection(USERS)
        .where("branchId", "==", branchId)
        .where("role", "==", "manager").get();
      snap.docs.forEach((d) => {
        if ((d.data() || {}).isActive !== false) out.add(d.id);
      });
    } catch (e) { logger.warn("request manager lookup failed", { error: String(e) }); }
  }
  try {
    const snap = await db.collection(USERS).where("role", "==", "admin").get();
    snap.docs.forEach((d) => {
      if ((d.data() || {}).isActive !== false) out.add(d.id);
    });
  } catch (e) { logger.warn("request admin lookup failed", { error: String(e) }); }
  out.delete(excludeUid);
  out.delete("");
  return [...out];
}

// Writes one in-app notification doc per recipient (Admin SDK). onNotificationCreated
// handles the matching push. Best-effort.
async function writeRequestNotifications(recipientUids, { type, title, body, requestId, senderUid }) {
  const uids = [...new Set(recipientUids.filter(Boolean))];
  if (uids.length === 0) return;
  const payload = { requestId, route: "request_details" };
  try {
    for (let i = 0; i < uids.length; i += BATCH_LIMIT) {
      const slice = uids.slice(i, i + BATCH_LIMIT);
      const batch = db.batch();
      for (const uid of slice) {
        const ref = db.collection(NOTIFICATIONS).doc();
        batch.set(ref, {
          id: ref.id,
          recipientUid: uid,
          senderUid: String(senderUid || ""),
          type,
          title: String(title || "").slice(0, 120),
          body: String(body || "").slice(0, 500),
          readAt: null,
          payload,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  } catch (err) {
    logger.warn("failed to persist request notifications", { error: String(err) });
  }
}

// Appends a server-authored timeline event (submitted / lifecycle) + bumps the
// parent request. Clients cannot write these kinds (firestore.rules).
async function appendServerRequestEvent(requestId, ev, preview) {
  try {
    const evRef = db.collection(REQUESTS).doc(requestId).collection("events").doc();
    const batch = db.batch();
    batch.set(evRef, { ...ev, createdAt: admin.firestore.FieldValue.serverTimestamp() });
    batch.update(db.collection(REQUESTS).doc(requestId), {
      lastEventPreview: preview,
      eventCount: admin.firestore.FieldValue.increment(1),
      lastEventAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await batch.commit();
  } catch (e) {
    logger.warn("failed to append server request event", { requestId, error: String(e) });
  }
}

// Allocates the next human-friendly REQ-###### code via a counter transaction.
async function nextRequestRefCode() {
  const ref = db.collection(COUNTERS).doc("requests");
  try {
    const seq = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const current = snap.exists ? Number((snap.data() || {}).seq || 0) : 0;
      const next = current + 1;
      tx.set(ref, {
        seq: next,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      return next;
    });
    return { seq, refCode: `REQ-${String(seq).padStart(6, "0")}` };
  } catch (e) {
    logger.warn("failed to allocate request ref", { error: String(e) });
    return { seq: null, refCode: null };
  }
}

// A new request → assign REQ-######, write the opening `submitted` event, and
// notify the routed approvers.
exports.onRequestCreated = onDocumentCreated(`${REQUESTS}/{requestId}`, async (event) => {
  const snap = event.data;
  if (!snap) return;
  const data = snap.data() || {};
  const requestId = event.params.requestId;

  // 1) Ref code (idempotent — skip if a retriggered create already assigned one).
  if (!data.refCode) {
    const { seq, refCode } = await nextRequestRefCode();
    if (refCode) {
      try {
        await db.collection(REQUESTS).doc(requestId).update({ refCode, seq });
      } catch (e) {
        logger.warn("failed to write request refCode", { requestId, error: String(e) });
      }
    }
  }

  // 2) Opening timeline event (from the requester's summary + opening media).
  const summary = String(data.lastEventPreview || "").trim();
  const attachments = Array.isArray(data.attachments) ? data.attachments : [];
  await appendServerRequestEvent(
    requestId,
    {
      authorId: String(data.requesterId || ""),
      authorName: String(data.requesterName || "Requester"),
      actor: "requester",
      kind: "submitted",
      text: summary || null,
      attachments,
    },
    requestEventPreview(summary, attachments),
  );

  // 3) Notify the routed approvers.
  const requesterUid = String(data.requesterId || "");
  const approvers = await resolveRequestApprovers(data, requesterUid);
  await writeRequestNotifications(approvers, {
    type: "requestSubmitted",
    title: "New approval request",
    body: summary ||
      `${String(data.requesterName || "An employee")} asked for your approval`,
    requestId,
    senderUid: requesterUid,
  });
});

// A request's status changed → append the lifecycle event + notify the affected
// party. Ignores its own lastEvent*/refCode bumps (status unchanged → no re-fire).
exports.onRequestUpdated = onDocumentUpdated(`${REQUESTS}/{requestId}`, async (event) => {
  const before = (event.data && event.data.before && event.data.before.data()) || {};
  const after = (event.data && event.data.after && event.data.after.data()) || {};
  const requestId = event.params.requestId;

  const beforeStatus = String(before.status || "pending");
  const afterStatus = String(after.status || "pending");
  if (beforeStatus === afterStatus) return;

  // approved / rejected = a decision; pending (from a decided state) = an
  // admin REOPEN — the client cleared `decided*` and stamped `reopened*`.
  const kinds = { approved: "approved", rejected: "rejected", pending: "reopened" };
  const kind = kinds[afterStatus];
  if (!kind) return;

  const deciderName = String(after.decidedByName || "").trim();
  const reopenerName = String(after.reopenedByName || "").trim();
  const label = {
    approved: deciderName ? `Approved by ${deciderName}` : "Approved",
    rejected: deciderName ? `Rejected by ${deciderName}` : "Rejected",
    pending: reopenerName ? `Reopened by ${reopenerName}` : "Reopened",
  }[afterStatus];
  const actorUid = afterStatus === "pending"
    ? String(after.reopenedBy || "")
    : String(after.decidedBy || "");

  await appendServerRequestEvent(
    requestId,
    {
      authorId: actorUid,
      authorName: (afterStatus === "pending" ? reopenerName : deciderName) || "System",
      actor: "system",
      kind,
      text: label,
      attachments: [],
    },
    label,
  );

  const requesterUid = String(after.requesterId || "");
  if (afterStatus === "pending") {
    // Reopened → it needs a decision again: tell the branch approvers (minus
    // the admin who reopened) and the requester.
    const approvers = await resolveRequestApprovers(after, actorUid);
    const body = reopenerName
      ? `${reopenerName} reopened this request — it needs a decision again`
      : "This request was reopened and needs a decision again";
    await writeRequestNotifications(approvers, {
      type: "requestSubmitted",
      title: "Request reopened",
      body,
      requestId,
      senderUid: actorUid,
    });
    if (requesterUid && requesterUid !== actorUid) {
      await writeRequestNotifications([requesterUid], {
        type: "requestSubmitted",
        title: "Request reopened",
        body: "Your request is being reviewed again",
        requestId,
        senderUid: actorUid,
      });
    }
    return;
  }

  // Notify the requester of the decision.
  if (requesterUid) {
    const byStatus = {
      approved: { type: "requestApproved", title: "Request Approved", body: "Your request was approved" },
      rejected: { type: "requestRejected", title: "Request Rejected", body: "Your request was rejected" },
    }[afterStatus];
    await writeRequestNotifications([requesterUid], {
      ...byStatus,
      requestId,
      senderUid: String(after.decidedBy || ""),
    });
  }
});

// A new comment/attachment event → bump the parent + notify the OTHER party.
// submitted/lifecycle events are written by the functions above (skipped here).
exports.onRequestEventCreated = onDocumentCreated(
  `${REQUESTS}/{requestId}/events/{eventId}`,
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const ev = snap.data() || {};
    const requestId = event.params.requestId;
    const kind = String(ev.kind || "comment");
    if (kind !== "comment" && kind !== "attachmentAdded") return;

    const preview = requestEventPreview(ev.text, Array.isArray(ev.attachments) ? ev.attachments : []);
    try {
      await db.collection(REQUESTS).doc(requestId).update({
        lastEventPreview: preview,
        eventCount: admin.firestore.FieldValue.increment(1),
        lastEventAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logger.warn("failed to bump request on event", { requestId, error: String(e) });
    }

    const reqSnap = await db.collection(REQUESTS).doc(requestId).get();
    const data = reqSnap.exists ? (reqSnap.data() || {}) : {};
    const requesterUid = String(data.requesterId || "");
    const authorId = String(ev.authorId || "");
    const byRequester = authorId !== "" && authorId === requesterUid;
    if (byRequester) {
      const approvers = await resolveRequestApprovers(data, requesterUid);
      await writeRequestNotifications(approvers, {
        type: "requestCommented",
        title: "New Request Comment",
        body: preview || "New comment on a request",
        requestId,
        senderUid: authorId,
      });
    } else if (requesterUid && authorId !== requesterUid) {
      await writeRequestNotifications([requesterUid], {
        type: "requestCommented",
        title: "New Request Comment",
        body: preview || "New comment on your request",
        requestId,
        senderUid: authorId,
      });
    }
  },
);
