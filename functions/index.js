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
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

const USERS = "users";
const BROADCASTS = "broadcasts";
const NOTIFICATIONS = "notifications";

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
    case "alert":
      return "broadcastAlert";
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

// Whether a broadcast should ride at high FCM priority (Phase 2). High-delivery
// priorities (`high` / `emergency`) and the legacy emergency category qualify.
// Mirrors BroadcastPriority.isHighDelivery on the client.
function isHighDelivery(priority, category) {
  return priority === "high" || priority === "emergency" || category === "emergency";
}

// Channel gating (Phase 2). Missing channel → "both" (the widest default),
// mirroring BroadcastChannel.fromString.
function channelSendsPush(channel) {
  return channel !== "inbox"; // push | both | (unknown→both)
}
function channelWritesInbox(channel) {
  return channel !== "push"; // inbox | both | (unknown→both)
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
  const priority = String(params.priority || "normal").trim() || "normal";
  const channel = String(params.channel || "both").trim() || "both";
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

  const recipientCount = recipientDocs.length;
  const isHigh = isHighDelivery(priority, category);
  const notifType = categoryToType(category);

  // ── Persist the broadcast doc (authoritative — schema matches BroadcastModel) ──
  const broadcastRef = db.collection(BROADCASTS).doc();
  await broadcastRef.set({
    id: broadcastRef.id,
    title,
    message: body,
    category,
    priority,
    channel,
    senderId,
    senderName,
    senderRole,
    audience,
    branchId,
    targetUserId: audience === "user" ? targetUserId : "",
    targetUserIds: persistedTargetIds,
    recipientCount,
    openedCount: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // ── Persist one in-app notification doc per recipient (inbox channel only).
  // Flagged `pushedByFunction:true` so the onNotificationCreated trigger doesn't
  // double-push. Best-effort — a write failure never fails the send. ──
  if (channelWritesInbox(channel)) {
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
  if (channelSendsPush(channel)) {
    // Gather FCM tokens (de-duplicated; remember each token's owner).
    const tokens = [];
    const tokenOwner = new Map();
    for (const doc of recipientDocs) {
      const u = doc.data() || {};
      const arr = Array.isArray(u.fcmTokens) ? u.fcmTokens : [];
      for (const t of arr) {
        if (t && !tokenOwner.has(t)) {
          tokenOwner.set(t, doc.id);
          tokens.push(t);
        }
      }
      // Legacy single-token field (pre-Phase-2 docs).
      if (u.fcmToken && !tokenOwner.has(u.fcmToken)) {
        tokenOwner.set(u.fcmToken, doc.id);
        tokens.push(u.fcmToken);
      }
    }

    const message = {
      notification: { title, body },
      // High-priority broadcasts ride at high priority on both platforms.
      android: { priority: isHigh ? "high" : "normal" },
      apns: { headers: { "apns-priority": isHigh ? "10" : "5" } },
      // Data values must be strings — they ride along to the tap handler.
      data: {
        type: notifType,
        category,
        priority: isHigh ? "high" : "normal",
        senderId,
        broadcastId: broadcastRef.id,
        route: "broadcast_detail",
        title,
        body,
      },
    };

    for (let i = 0; i < tokens.length; i += MULTICAST_CHUNK) {
      const batch = tokens.slice(i, i + MULTICAST_CHUNK);
      const response = await messaging.sendEachForMulticast({ ...message, tokens: batch });
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
  }

  // Persist the delivery result on the doc so the Communications Center feed /
  // detail can show "delivered N / M" (best-effort; never fails the send).
  await broadcastRef.update({ deliveredCount }).catch(() => {});

  logger.info("broadcast dispatched", {
    broadcastId: broadcastRef.id,
    audience,
    channel,
    priority,
    recipientCount,
    deliveredCount,
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
  const priority = String(payload.priority || "normal").trim() || "normal";
  const channel = String(payload.channel || "both").trim() || "both";
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
    priority,
    channel,
    audience,
    branchId,
    targetUserId,
    targetUserIds,
    roleFilter,
  });

  return { success: true, ...result };
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
