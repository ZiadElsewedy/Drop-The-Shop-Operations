/// Lifecycle of a task, stored as a string in `tasks/{taskId}.status`:
///
/// `pending → started → completed → waitingReview → approved | rejected`
///
/// A recurring shift task may also be ended by the automation deadline sweep as
/// [missed] when its shift ends before it is completed.
///
/// Employees drive a task up to [waitingReview] (start / complete their own
/// work); only a manager/admin sets the terminal [approved] / [rejected] on
/// review (enforced by `firestore.rules`). [missed] is server-set only.
enum TaskStatus {
  pending,
  started,
  completed,
  waitingReview,
  approved,
  rejected,
  missed;

  String get value => name;

  bool get isPending => this == TaskStatus.pending;
  bool get isStarted => this == TaskStatus.started;
  bool get isCompleted => this == TaskStatus.completed;
  bool get isWaitingReview => this == TaskStatus.waitingReview;
  bool get isApproved => this == TaskStatus.approved;
  bool get isRejected => this == TaskStatus.rejected;
  bool get isMissed => this == TaskStatus.missed;

  /// Whether this is a terminal review outcome (approved / rejected) that only
  /// a manager/admin may set.
  bool get isReviewed => isApproved || isRejected;

  /// A closed lifecycle outcome. A missed task is no longer actionable, even
  /// though it was not reviewed or approved.
  bool get isTerminal => isApproved || isMissed;

  /// Whether the lifecycle can still progress. Individual screens may use a
  /// narrower operational definition (for example, review work is not an
  /// employee's active task), but a missed task is never active.
  bool get isActive => !isTerminal;

  /// Parses the stored string; unknown/missing → [pending].
  static TaskStatus fromString(String? raw) {
    switch (raw) {
      case 'started':
        return TaskStatus.started;
      case 'completed':
        return TaskStatus.completed;
      case 'waitingReview':
        return TaskStatus.waitingReview;
      case 'approved':
        return TaskStatus.approved;
      case 'rejected':
        return TaskStatus.rejected;
      case 'missed':
        return TaskStatus.missed;
      case 'pending':
      default:
        return TaskStatus.pending;
    }
  }
}
