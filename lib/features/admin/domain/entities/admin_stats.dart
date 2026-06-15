/// Aggregated counts for the admin reports overview (Phase 5). Simple totals
/// only — no time series or advanced analytics.
class AdminStats {
  final int totalBranches;
  final int totalManagers;
  final int totalEmployees;
  final int pendingApprovals;
  final int activeTasks;
  final int completedTasks;

  const AdminStats({
    required this.totalBranches,
    required this.totalManagers,
    required this.totalEmployees,
    required this.pendingApprovals,
    required this.activeTasks,
    required this.completedTasks,
  });
}
