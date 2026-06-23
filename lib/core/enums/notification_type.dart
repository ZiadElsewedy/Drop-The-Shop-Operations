/// The operational push-notification events DROP sends.
/// These are the agreed `type` values for the FCM **data** payload and the
/// `notifications/{id}.type` field — the contract shared by the client triggers
/// (`NotifyTaskEvent`), the `sendBroadcast` / `runTaskReminders` Cloud Functions,
/// and the in-app inbox.
///
/// **Every value here has a live producer.** Earlier revisions carried ~16
/// "reserved" schedule / swap / admin types that nothing ever wrote; they were
/// trimmed (2026-06-23 stabilization pass) to keep the surface honest. When a
/// later phase wires a real producer (a client trigger or a Cloud Function),
/// add the value back here **and** mirror it in the producer — not before.
///
/// Inbox grouping is by name prefix (`task*` → Tasks, `broadcast*` → Broadcasts),
/// so a new type should keep that naming convention.
enum NotificationType {
  // ── Task lifecycle (client `NotifyTaskEvent` via TaskCubit) ──
  taskAssigned,
  taskRework,
  taskSubmitted,
  taskApproved,
  taskRejected,
  // ── Task reminders (`runTaskReminders` Cloud Function) ──
  taskReminder,
  taskOverdue,
  // ── Broadcast events (`sendBroadcast` / `dispatchBroadcast` Cloud Function) ──
  broadcastAnnouncement,
  broadcastReminder,
  broadcastEmergency;

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
