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
    // Data values must be strings — they ride along to the tap handler.
    const message = {
      notification: { title, body },
      data: {
        type: String(n.type || ""),
        // Intended recipient — the client drops a push whose recipientUid != the
        // signed-in user (defense-in-depth #3). This path is already per-recipient.
        recipientUid: String(recipientUid),
        taskId: String(payload.taskId || ""),
        broadcastId: String(payload.broadcastId || ""),
        category: String(payload.category || ""),
        revisionNumber:
          payload.revisionNumber == null ? "" : String(payload.revisionNumber),
        route: String(payload.route || ""),
      },
    };

    // Push (chunked) + prune dead tokens.
    const removals = [];
    for (let i = 0; i < tokens.length; i += MULTICAST_CHUNK) {
      const batch = tokens.slice(i, i + MULTICAST_CHUNK);
      const response = await messaging.sendEachForMulticast({ ...message, tokens: batch });
      response.responses.forEach((r, idx) => {
        if (r.success) return;
        const code = r.error && r.error.code;
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

    logger.info("notification pushed", {
      type: n.type,
      recipientUid,
      tokenCount: tokens.length,
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

