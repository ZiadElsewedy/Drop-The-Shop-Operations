/// The operational push-notification events DROP THE SHOP sends.
/// These are the agreed `type` values for the FCM **data** payload and the
/// `notifications/{id}.type` field — the contract shared by the client triggers
/// (`NotifyTaskEvent`), the `sendBroadcast` Cloud Function, and the in-app inbox.
///
/// **Notification System Phase 1** activated the task + broadcast events:
/// [taskAssigned] · [taskRework] · [taskSubmitted] · [taskApproved] ·
/// [taskRejected], and the broadcast group ([broadcastAnnouncement] /
/// [broadcastAlert] / [broadcastReminder] / [broadcastEmergency]). The remaining
/// values stay as the contract for later phases (schedule / swaps / admin) — they
/// have no server trigger yet.
enum NotificationType {
  // ── Task events (Notification System Phase 1) ──
  taskAssigned,
  taskRework,
  taskSubmitted,
  taskApproved,
  taskRejected,
  // ── Task reminders (Communications Center Phase 2 Commit 5) ──
  taskReminder,
  taskOverdue,
  // ── Broadcast events (Communications Center → Notification System Phase 1) ──
  broadcastAnnouncement,
  broadcastAlert,
  broadcastReminder,
  broadcastEmergency,
  // ── Employee (contract — later phases) ──
  shiftChanged,
  managerNote,
  // ── Employee · weekly schedule + swaps (Phase 7) ──
  tomorrowShiftReminder,
  swapApproved,
  swapRejected,
  // ── Manager ──
  taskWaitingReview,
  employeeCompletedTask,
  newEmployeePendingApproval,
  shiftWithoutEmployees,
  // ── Manager · shift swaps (Phase 7) ──
  newSwapRequest,
  swapPendingApproval,
  // ── Admin ──
  newEmployeeRegistration,
  branchWithoutManager,
  manyRejectedTasks,
  branchWithoutActiveEmployees,
  // ── Admin · weekly schedule (Phase 7) ──
  branchWithoutSchedule;

  String get value => name;

  static NotificationType? fromString(String? raw) {
    for (final t in NotificationType.values) {
      if (t.name == raw) return t;
    }
    return null;
  }

  /// Maps a broadcast [BroadcastCategory] string (announcement / alert /
  /// reminder / emergency) to its notification type. Unknown / missing →
  /// [broadcastAnnouncement] (the neutral default). Mirrored by the
  /// `sendBroadcast` Cloud Function's `categoryToType`.
  static NotificationType fromBroadcastCategory(String? category) {
    switch (category) {
      case 'alert':
        return broadcastAlert;
      case 'reminder':
        return broadcastReminder;
      case 'emergency':
        return broadcastEmergency;
      case 'announcement':
      default:
        return broadcastAnnouncement;
    }
  }
}
