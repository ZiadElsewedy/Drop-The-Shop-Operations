import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbro/core/constants/app_constants.dart';
import 'package:fbro/core/enums/schedule_day.dart';
import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/features/schedule/domain/schedule_week.dart';
import 'package:fbro/features/statistics/data/models/statistics_model.dart';

typedef _Doc = QueryDocumentSnapshot<Map<String, dynamic>>;

/// Computes operational statistics by aggregating the branch-scoped collections
/// (users / tasks / weekly_schedules / branches). Uses single-field queries +
/// client-side counting to stay branch-scoped without composite indexes;
/// `count()` aggregate queries are a future optimization if data volume grows.
///
/// Phase 7: the "today's shift" / morning-night / coverage figures now come from
/// the **weekly schedule** (`weekly_schedules`), the production roster, rather
/// than the Phase 2 `shifts` placeholder collection.
abstract class StatisticsRemoteDataSource {
  Future<StatisticsModel> adminStats();
  Future<StatisticsModel> managerStats(String branchId);
  Future<StatisticsModel> employeeStats(String uid, String? branchId);
}

class StatisticsRemoteDataSourceImpl implements StatisticsRemoteDataSource {
  final FirebaseFirestore _firestore;

  StatisticsRemoteDataSourceImpl(this._firestore);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(AppConstants.usersCollection);
  CollectionReference<Map<String, dynamic>> get _tasks =>
      _firestore.collection(AppConstants.tasksCollection);
  CollectionReference<Map<String, dynamic>> get _branches =>
      _firestore.collection(AppConstants.branchesCollection);
  CollectionReference<Map<String, dynamic>> get _schedules =>
      _firestore.collection(AppConstants.weeklySchedulesCollection);

  static int _count(List<_Doc> docs, bool Function(Map<String, dynamic>) test) =>
      docs.where((d) => test(d.data())).length;

  static bool _isToday(dynamic ts, DateTime startOfToday) =>
      ts is Timestamp && !ts.toDate().isBefore(startOfToday);

  /// Employee uids assigned to a (day, shift) slot in a schedule doc's map.
  static List<String> _slot(
      Map<String, dynamic>? schedule, String day, String shift) {
    final assignments = schedule?['assignments'] as Map<String, dynamic>?;
    final dayMap = assignments?[day] as Map<String, dynamic>?;
    final list = dayMap?[shift] as List?;
    return list?.whereType<String>().toList() ?? const [];
  }

  bool _isActive(Map<String, dynamic> t) {
    final s = t['status'] as String? ?? 'pending';
    return s != 'approved' && s != 'rejected';
  }

  @override
  Future<StatisticsModel> adminStats() async {
    try {
      final now = DateTime.now();
      final startToday = DateTime(now.year, now.month, now.day);
      final weekStart = ScheduleWeek.currentWeekStart();

      final branches = (await _branches.get())
          .docs
          .where((d) => d.data()['deletedAt'] == null)
          .toList();
      final users = (await _users.get()).docs;
      final tasks = (await _tasks.get()).docs;
      final schedules = (await _schedules.get()).docs;

      final managerBranchIds = <String>{
        for (final u in users)
          if ((u.data()['role'] as String?) == 'manager' &&
              (u.data()['branchId'] as String?) != null &&
              (u.data()['branchId'] as String).isNotEmpty)
            u.data()['branchId'] as String,
      };

      // Branches with a schedule published for the current week (coverage).
      final scheduledBranchIds = <String>{
        for (final s in schedules)
          if (_isCurrentWeek(s.data()['weekStart'], weekStart) &&
              (s.data()['branchId'] as String?) != null)
            s.data()['branchId'] as String,
      };

      return StatisticsModel(
        totalBranches: branches.length,
        totalManagers: _count(users, (u) => u['role'] == 'manager'),
        totalEmployees: _count(users, (u) => u['role'] == 'employee'),
        pendingApprovals:
            _count(users, (u) => u['approvalStatus'] == 'pending'),
        branchesWithoutManagers:
            branches.where((b) => !managerBranchIds.contains(b.id)).length,
        branchesWithSchedule:
            branches.where((b) => scheduledBranchIds.contains(b.id)).length,
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
      final schedule =
          (await _schedules.doc(ScheduleWeek.docId(branchId, now)).get())
              .data();

      // Today's shift staffing from this week's weekly schedule.
      final todayKey = ScheduleDay.today().value;
      final morning = _slot(schedule, todayKey, 'morning');
      final night = _slot(schedule, todayKey, 'night');

      return StatisticsModel(
        employeesInBranch: _count(users, (u) => u['role'] == 'employee'),
        scheduledToday: {...morning, ...night}.length,
        morningShiftEmployees: morning.length,
        nightShiftEmployees: night.length,
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
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load statistics.');
    }
  }

  @override
  Future<StatisticsModel> employeeStats(String uid, String? branchId) async {
    try {
      final now = DateTime.now();
      // Multi-assignee (Phase 9): a task counts for this employee if their uid
      // is in `assigneeIds`.
      final tasks =
          (await _tasks.where('assigneeIds', arrayContains: uid).get()).docs;

      String? currentShiftName;
      String? upcomingShiftName;
      if (branchId != null && branchId.isNotEmpty) {
        final schedule =
            (await _schedules.doc(ScheduleWeek.docId(branchId, now)).get())
                .data();
        if (schedule != null) {
          final days = ScheduleDay.values;
          final todayIdx = ScheduleDay.today().index;

          // Current: today's shift that includes this employee.
          for (final shift in const ['morning', 'night']) {
            if (_slot(schedule, days[todayIdx].value, shift).contains(uid)) {
              currentShiftName = shift;
              break;
            }
          }

          // Upcoming: the next slot later this week that includes them.
          search:
          for (var i = todayIdx + 1; i < days.length; i++) {
            for (final shift in const ['morning', 'night']) {
              if (_slot(schedule, days[i].value, shift).contains(uid)) {
                final shiftLabel =
                    '${shift[0].toUpperCase()}${shift.substring(1)}';
                upcomingShiftName = '${days[i].shortLabel} · $shiftLabel';
                break search;
              }
            }
          }
        }
      }

      return StatisticsModel(
        assignedTasks: tasks.length,
        completedTasks: _count(tasks, (t) => t['status'] == 'approved'),
        pendingTasks: _count(tasks, (t) => t['status'] == 'pending'),
        waitingReviews: _count(tasks, (t) => t['status'] == 'waitingReview'),
        currentShiftName: currentShiftName,
        upcomingShiftName: upcomingShiftName,
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load statistics.');
    }
  }

  static bool _isCurrentWeek(dynamic ts, DateTime weekStart) =>
      ts is Timestamp && ScheduleWeek.startOf(ts.toDate()) == weekStart;
}
