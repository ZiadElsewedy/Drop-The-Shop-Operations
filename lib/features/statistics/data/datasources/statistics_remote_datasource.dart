import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbro/core/constants/app_constants.dart';
import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/features/statistics/data/models/statistics_model.dart';

typedef _Doc = QueryDocumentSnapshot<Map<String, dynamic>>;

/// Computes operational statistics by aggregating the branch-scoped collections
/// (users / tasks / shifts / branches). Uses single-field queries + client-side
/// counting to stay branch-scoped without composite indexes; `count()` aggregate
/// queries are a future optimization if data volume grows.
abstract class StatisticsRemoteDataSource {
  Future<StatisticsModel> adminStats();
  Future<StatisticsModel> managerStats(String branchId);
  Future<StatisticsModel> employeeStats(String uid);
}

class StatisticsRemoteDataSourceImpl implements StatisticsRemoteDataSource {
  final FirebaseFirestore _firestore;

  StatisticsRemoteDataSourceImpl(this._firestore);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(AppConstants.usersCollection);
  CollectionReference<Map<String, dynamic>> get _tasks =>
      _firestore.collection(AppConstants.tasksCollection);
  CollectionReference<Map<String, dynamic>> get _shifts =>
      _firestore.collection(AppConstants.shiftsCollection);
  CollectionReference<Map<String, dynamic>> get _branches =>
      _firestore.collection(AppConstants.branchesCollection);

  static int _count(List<_Doc> docs, bool Function(Map<String, dynamic>) test) =>
      docs.where((d) => test(d.data())).length;

  static bool _isToday(dynamic ts, DateTime startOfToday) =>
      ts is Timestamp && !ts.toDate().isBefore(startOfToday);

  bool _isActive(Map<String, dynamic> t) {
    final s = t['status'] as String? ?? 'pending';
    return s != 'approved' && s != 'rejected';
  }

  @override
  Future<StatisticsModel> adminStats() async {
    try {
      final now = DateTime.now();
      final startToday = DateTime(now.year, now.month, now.day);

      final branches = (await _branches.get())
          .docs
          .where((d) => d.data()['deletedAt'] == null)
          .toList();
      final users = (await _users.get()).docs;
      final tasks = (await _tasks.get()).docs;

      final managerBranchIds = <String>{
        for (final u in users)
          if ((u.data()['role'] as String?) == 'manager' &&
              (u.data()['branchId'] as String?) != null &&
              (u.data()['branchId'] as String).isNotEmpty)
            u.data()['branchId'] as String,
      };

      return StatisticsModel(
        totalBranches: branches.length,
        totalManagers: _count(users, (u) => u['role'] == 'manager'),
        totalEmployees: _count(users, (u) => u['role'] == 'employee'),
        pendingApprovals:
            _count(users, (u) => u['approvalStatus'] == 'pending'),
        branchesWithoutManagers:
            branches.where((b) => !managerBranchIds.contains(b.id)).length,
        activeTasks: _count(tasks, _isActive),
        completedTasks: _count(tasks, (t) => t['status'] == 'approved'),
        waitingReviews: _count(tasks, (t) => t['status'] == 'waitingReview'),
        rejectedTasksToday: _count(
            tasks,
            (t) =>
                t['status'] == 'rejected' &&
                _isToday(t['rejectedAt'], startToday)),
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load statistics.');
    }
  }

  @override
  Future<StatisticsModel> managerStats(String branchId) async {
    try {
      final now = DateTime.now();
      final startToday = DateTime(now.year, now.month, now.day);

      final users =
          (await _users.where('branchId', isEqualTo: branchId).get()).docs;
      final tasks =
          (await _tasks.where('branchId', isEqualTo: branchId).get()).docs;
      final shifts =
          (await _shifts.where('branchId', isEqualTo: branchId).get()).docs;

      bool assignedShift(Map<String, dynamic> s, String name) =>
          s['name'] == name &&
          (s['employeeId'] as String?) != null &&
          (s['employeeId'] as String).isNotEmpty;

      return StatisticsModel(
        employeesInBranch: _count(users, (u) => u['role'] == 'employee'),
        activeTasks: _count(tasks, _isActive),
        waitingReviews: _count(tasks, (t) => t['status'] == 'waitingReview'),
        completedTasksToday: _count(
            tasks,
            (t) =>
                t['status'] == 'approved' &&
                _isToday(t['approvedAt'], startToday)),
        rejectedTasks: _count(tasks, (t) => t['status'] == 'rejected'),
        dailyTasks: _count(tasks, (t) => t['type'] == 'daily'),
        specialTasks: _count(tasks, (t) => t['type'] == 'special'),
        morningShiftEmployees:
            _count(shifts, (s) => assignedShift(s, 'morning')),
        nightShiftEmployees: _count(shifts, (s) => assignedShift(s, 'night')),
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load statistics.');
    }
  }

  @override
  Future<StatisticsModel> employeeStats(String uid) async {
    try {
      final tasks =
          (await _tasks.where('assignedEmployeeId', isEqualTo: uid).get()).docs;
      final shifts =
          (await _shifts.where('employeeId', isEqualTo: uid).limit(1).get())
              .docs;

      return StatisticsModel(
        assignedTasks: tasks.length,
        completedTasks: _count(tasks, (t) => t['status'] == 'approved'),
        pendingTasks: _count(tasks, (t) => t['status'] == 'pending'),
        waitingReviews: _count(tasks, (t) => t['status'] == 'waitingReview'),
        currentShiftName:
            shifts.isEmpty ? null : shifts.first.data()['name'] as String?,
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load statistics.');
    }
  }
}
