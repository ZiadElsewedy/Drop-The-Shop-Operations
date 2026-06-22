import 'package:fbro/core/enums/schedule_day.dart';
import 'package:fbro/core/enums/schedule_shift.dart';
import 'package:fbro/core/enums/swap_status.dart';
import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/schedule/data/datasources/schedule_remote_datasource.dart';
import 'package:fbro/features/schedule/data/models/shift_swap_model.dart';
import 'package:fbro/features/schedule/data/models/weekly_schedule_model.dart';
import 'package:fbro/features/schedule/domain/entities/shift_swap_entity.dart';
import 'package:fbro/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:fbro/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:fbro/features/schedule/domain/schedule_week.dart';

class ScheduleRepositoryImpl implements ScheduleRepository {
  final ScheduleRemoteDataSource _remote;

  ScheduleRepositoryImpl(this._remote);

  @override
  Future<WeeklyScheduleEntity?> getSchedule(
      String branchId, DateTime weekStart) async {
    try {
      final model = await _remote.getSchedule(branchId, weekStart);
      return model?.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<WeeklyScheduleEntity>> getBranchSchedules(String branchId) async {
    try {
      final models = await _remote.getBranchSchedules(branchId);
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<WeeklyScheduleEntity>> getAllSchedules() async {
    try {
      final models = await _remote.getAllSchedules();
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<WeeklyScheduleEntity> createSchedule({
    required String branchId,
    required DateTime weekStart,
    String? createdBy,
  }) async {
    try {
      final start = ScheduleWeek.startOf(weekStart);
      final created = await _remote.createSchedule(
        WeeklyScheduleModel.empty(
          id: ScheduleWeek.docId(branchId, start),
          branchId: branchId,
          weekStart: start,
          createdBy: createdBy,
        ),
      );
      return created.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> assignEmployee({
    required String scheduleId,
    required ScheduleDay day,
    required ScheduleShift shift,
    required String employeeId,
  }) async {
    try {
      await _remote.assignEmployee(
        scheduleId: scheduleId,
        day: day,
        shift: shift,
        employeeId: employeeId,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> removeEmployee({
    required String scheduleId,
    required ScheduleDay day,
    required ScheduleShift shift,
    required String employeeId,
  }) async {
    try {
      await _remote.removeEmployee(
        scheduleId: scheduleId,
        day: day,
        shift: shift,
        employeeId: employeeId,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  // ── Shift swaps ────────────────────────────────────────────────
  @override
  Future<List<ShiftSwapEntity>> getBranchSwaps(String branchId) async {
    try {
      final models = await _remote.getBranchSwaps(branchId);
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<ShiftSwapEntity>> getEmployeeSwaps(String uid) async {
    try {
      final models = await _remote.getEmployeeSwaps(uid);
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<ShiftSwapEntity>> getAllSwaps() async {
    try {
      final models = await _remote.getAllSwaps();
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<ShiftSwapEntity> createSwap(ShiftSwapEntity swap) async {
    try {
      final created = await _remote.createSwap(ShiftSwapModel.fromEntity(swap));
      return created.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> updateSwapStatus({
    required String swapId,
    required SwapStatus status,
  }) async {
    try {
      await _remote.updateSwapStatus(swapId: swapId, status: status);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> managerApproveSwap(ShiftSwapEntity swap) async {
    try {
      // 1) Mark approved. 2) Apply to the schedule: requester gives up the slot,
      // target takes it. The manager has branch-write access (firestore.rules),
      // so both writes are permitted.
      await _remote.updateSwapStatus(
          swapId: swap.id, status: SwapStatus.managerApproved);
      final scheduleId = ScheduleWeek.docId(swap.branchId, swap.weekStart);
      await _remote.removeEmployee(
        scheduleId: scheduleId,
        day: swap.day,
        shift: swap.shift,
        employeeId: swap.requesterId,
      );
      await _remote.assignEmployee(
        scheduleId: scheduleId,
        day: swap.day,
        shift: swap.shift,
        employeeId: swap.targetId,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
