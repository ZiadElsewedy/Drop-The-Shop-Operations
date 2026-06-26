import 'package:fbro/core/enums/schedule_day.dart';
import 'package:fbro/core/enums/schedule_shift.dart';
import 'package:fbro/core/enums/swap_status.dart';
import 'package:fbro/features/schedule/domain/entities/shift_swap_entity.dart';
import 'package:fbro/features/schedule/domain/entities/weekly_schedule_entity.dart';

/// Contract for weekly-schedule + shift-swap data access (Phase 7). Branch/role
/// access is enforced server-side by `firestore.rules` (admin: all branches;
/// manager: own branch; employee: read own branch + create/act on their swaps).
abstract class ScheduleRepository {
  /// The branch's schedule for the week containing [weekStart], or null if the
  /// manager hasn't created one yet.
  Future<WeeklyScheduleEntity?> getSchedule(
      String branchId, DateTime weekStart);

  /// All of a branch's weekly schedules (newest week first).
  Future<List<WeeklyScheduleEntity>> getBranchSchedules(String branchId);

  /// Every branch's schedules — admin only.
  Future<List<WeeklyScheduleEntity>> getAllSchedules();

  /// Creates an empty schedule for ([branchId], [weekStart]).
  Future<WeeklyScheduleEntity> createSchedule({
    required String branchId,
    required DateTime weekStart,
    String? createdBy,
  });

  /// Adds [employeeId] to a (day, shift) slot of the schedule [scheduleId].
  Future<void> assignEmployee({
    required String scheduleId,
    required ScheduleDay day,
    required ScheduleShift shift,
    required String employeeId,
  });

  /// Removes [employeeId] from a (day, shift) slot of the schedule [scheduleId].
  Future<void> removeEmployee({
    required String scheduleId,
    required ScheduleDay day,
    required ScheduleShift shift,
    required String employeeId,
  });

  // ── Shift swaps ──
  /// Swap requests for a branch — the manager's approval queue.
  Future<List<ShiftSwapEntity>> getBranchSwaps(String branchId);

  /// Swap requests involving [uid] (as requester or target).
  Future<List<ShiftSwapEntity>> getEmployeeSwaps(String uid);

  /// Every branch's swap requests — admin only (powers the Admin Home overview).
  Future<List<ShiftSwapEntity>> getAllSwaps();

  /// Realtime swap streams (newest first) — the live source behind employee /
  /// manager / admin pending-swap surfaces, so an accept/reject/approve reflects
  /// instantly without a manual refresh.
  Stream<List<ShiftSwapEntity>> watchEmployeeSwaps(String uid);
  Stream<List<ShiftSwapEntity>> watchBranchSwaps(String branchId);
  Stream<List<ShiftSwapEntity>> watchAllSwaps();

  /// Creates a swap request (status pending).
  Future<ShiftSwapEntity> createSwap(ShiftSwapEntity swap);

  /// Sets a swap to [status] — used for coworker approval, and rejections by any
  /// party. (Manager approval also rewrites the schedule — see
  /// [managerApproveSwap].)
  Future<void> updateSwapStatus({
    required String swapId,
    required SwapStatus status,
  });

  /// Manager approval: finalizes the swap via the server-authoritative
  /// `approveSwap` Cloud Function, which re-validates against the freshest
  /// schedule and **atomically exchanges the two slots** — the requester and the
  /// target trade shifts on the same day (Ziad's Night ⇄ Ahmed's Morning), then
  /// the swap is marked [SwapStatus.managerApproved]. Either both move or nothing
  /// changes; a partial roster mutation is impossible.
  Future<void> managerApproveSwap(ShiftSwapEntity swap);
}
