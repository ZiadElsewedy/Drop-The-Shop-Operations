/// The four headline numbers on the Branch Operations summary header — the
/// "branch health in under 3 seconds" read. Computed for the *current shift
/// lens* over the same branch data as the employee cards below it (see
/// [computeBranchWorkload]).
class BranchSummary {
  const BranchSummary({
    this.activeTasks = 0,
    this.overdueTasks = 0,
    this.pendingReviews = 0,
    this.staffActive = 0,
  });

  /// Open, employee-actionable tasks — pending / started / rework.
  final int activeTasks;

  /// Active tasks already past their deadline.
  final int overdueTasks;

  /// Tasks awaiting a manager/admin decision — completed / waiting review.
  final int pendingReviews;

  /// Employees on shift (for the current lens) — rostered today.
  final int staffActive;

  bool get isAllClear => overdueTasks == 0 && pendingReviews == 0;
}
