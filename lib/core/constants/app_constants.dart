class AppConstants {
  AppConstants._();

  static const String appName = 'DROP';
  static const String usersCollection = 'users';
  static const String tasksCollection = 'tasks';
  static const String taskTemplatesCollection = 'task_templates';
  static const String recurringTaskTemplatesCollection = 'recurringTaskTemplates';
  static const String branchesCollection = 'branches';
  static const String weeklySchedulesCollection = 'weekly_schedules';
  static const String shiftTemplatesCollection = 'shift_templates';
  static const String shiftSwapsCollection = 'shift_swaps';
  static const String broadcastsCollection = 'broadcasts';
  static const String notificationsCollection = 'notifications';

  /// Case Management (private conversation until resolution). The reporter's
  /// identity lives in the private subcollection `cases/{id}/reporter/identity`;
  /// the conversation lives in `cases/{id}/messages`.
  static const String casesCollection = 'cases';

  /// Operations Requests (in-the-moment approvals during the work day). The
  /// event-driven timeline lives in the subcollection `requests/{id}/events`; a
  /// monotonic reference sequence lives at `counters/requests`.
  static const String requestsCollection = 'requests';
  static const String countersCollection = 'counters';

  /// Community Hub / DROP Events. Each event is a single self-contained document
  /// (`events/{id}`) with every workspace section embedded inline; the hero image
  /// lives in Storage at `events/{id}/hero.<ext>`.
  static const String eventsCollection = 'events';

  /// Immutable Event Tracking + Audit Log. One append-only document per important
  /// business action (`audit_logs/{id}`) — who did what, to which entity, when,
  /// from where. Never edited; never hard-deleted (admin soft-delete only). All
  /// writes flow through the central `EventTrackingService`.
  static const String auditLogsCollection = 'audit_logs';

  // ─── Communications Center — Phase 2 ──────────────────────────
  static const String broadcastTemplatesCollection = 'broadcastTemplates';
  static const String broadcastSchedulesCollection = 'broadcastSchedules';
  static const String reminderConfigCollection = 'reminderConfig';
  static const String savedAudiencesCollection = 'savedAudiences';
  static const String taskRemindersCollection = 'taskReminders';
}
