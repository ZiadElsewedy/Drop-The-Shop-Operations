import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbro/core/constants/app_constants.dart';
import 'package:fbro/core/enums/schedule_day.dart';
import 'package:fbro/core/enums/schedule_shift.dart';
import 'package:fbro/core/enums/swap_status.dart';
import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/features/schedule/data/models/shift_swap_model.dart';
import 'package:fbro/features/schedule/data/models/weekly_schedule_model.dart';
import 'package:fbro/features/schedule/domain/schedule_week.dart';

/// Firestore access for the weekly schedule + shift swaps (Phase 7). Schedules
/// live at `weekly_schedules/{branchId_yyyy-MM-dd}` (deterministic id → one doc
/// per branch+week, addressed without a query). Swaps live at `shift_swaps/{id}`.
/// Branch/role access is enforced server-side in `firestore.rules`.
abstract class ScheduleRemoteDataSource {
  // ── Weekly schedules ──
  Future<WeeklyScheduleModel?> getSchedule(String branchId, DateTime weekStart);
  Future<List<WeeklyScheduleModel>> getBranchSchedules(String branchId);
  Future<List<WeeklyScheduleModel>> getAllSchedules();
  Future<WeeklyScheduleModel> createSchedule(WeeklyScheduleModel schedule);
  Future<void> assignEmployee({
    required String scheduleId,
    required ScheduleDay day,
    required ScheduleShift shift,
    required String employeeId,
  });
  Future<void> removeEmployee({
    required String scheduleId,
    required ScheduleDay day,
    required ScheduleShift shift,
    required String employeeId,
  });

  // ── Shift swaps ──
  Future<List<ShiftSwapModel>> getBranchSwaps(String branchId);
  Future<List<ShiftSwapModel>> getEmployeeSwaps(String uid);
  Future<List<ShiftSwapModel>> getAllSwaps();
  Future<ShiftSwapModel> createSwap(ShiftSwapModel swap);
  Future<void> updateSwapStatus({
    required String swapId,
    required SwapStatus status,
  });
}

class ScheduleRemoteDataSourceImpl implements ScheduleRemoteDataSource {
  final FirebaseFirestore _firestore;

  ScheduleRemoteDataSourceImpl(this._firestore);

  CollectionReference<Map<String, dynamic>> get _schedules =>
      _firestore.collection(AppConstants.weeklySchedulesCollection);
  CollectionReference<Map<String, dynamic>> get _swaps =>
      _firestore.collection(AppConstants.shiftSwapsCollection);

  // ── Weekly schedules ───────────────────────────────────────────
  @override
  Future<WeeklyScheduleModel?> getSchedule(
      String branchId, DateTime weekStart) async {
    try {
      final doc =
          await _schedules.doc(ScheduleWeek.docId(branchId, weekStart)).get();
      if (!doc.exists || doc.data() == null) return null;
      return WeeklyScheduleModel.fromMap(doc.data()!, id: doc.id);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load the schedule.');
    }
  }

  @override
  Future<List<WeeklyScheduleModel>> getBranchSchedules(String branchId) async {
    try {
      // Single-field query (no composite index); sorted client-side, newest week
      // first — same pattern as the statistics datasource.
      final snap =
          await _schedules.where('branchId', isEqualTo: branchId).get();
      return _sortByWeek(snap.docs);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load branch schedules.');
    }
  }

  @override
  Future<List<WeeklyScheduleModel>> getAllSchedules() async {
    try {
      final snap = await _schedules.get();
      return _sortByWeek(snap.docs);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load schedules.');
    }
  }

  @override
  Future<WeeklyScheduleModel> createSchedule(
      WeeklyScheduleModel schedule) async {
    try {
      final docRef =
          _schedules.doc(ScheduleWeek.docId(schedule.branchId, schedule.weekStart));
      await docRef.set({
        ...schedule.toMap(),
        'id': docRef.id,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return WeeklyScheduleModel.fromMap(schedule.toMap(), id: docRef.id);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to create the schedule.');
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
      // Targeted nested-array update — no read/modify/write race. The dotted
      // path creates intermediate maps/arrays if they don't exist yet.
      await _schedules.doc(scheduleId).update({
        'assignments.${day.value}.${shift.value}':
            FieldValue.arrayUnion([employeeId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to assign the employee.');
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
      await _schedules.doc(scheduleId).update({
        'assignments.${day.value}.${shift.value}':
            FieldValue.arrayRemove([employeeId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to remove the employee.');
    }
  }

  // ── Shift swaps ────────────────────────────────────────────────
  @override
  Future<List<ShiftSwapModel>> getBranchSwaps(String branchId) async {
    try {
      final snap = await _swaps.where('branchId', isEqualTo: branchId).get();
      return _sortSwaps(
          snap.docs.map((d) => ShiftSwapModel.fromMap(d.data(), id: d.id)));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load swap requests.');
    }
  }

  @override
  Future<List<ShiftSwapModel>> getEmployeeSwaps(String uid) async {
    try {
      // Firestore has no OR across fields; query each side and merge by id.
      final asRequester = await _swaps.where('requesterId', isEqualTo: uid).get();
      final asTarget = await _swaps.where('targetId', isEqualTo: uid).get();
      final byId = <String, ShiftSwapModel>{};
      for (final d in [...asRequester.docs, ...asTarget.docs]) {
        byId[d.id] = ShiftSwapModel.fromMap(d.data(), id: d.id);
      }
      return _sortSwaps(byId.values);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load your swap requests.');
    }
  }

  @override
  Future<List<ShiftSwapModel>> getAllSwaps() async {
    try {
      final snap = await _swaps.get();
      return _sortSwaps(
          snap.docs.map((d) => ShiftSwapModel.fromMap(d.data(), id: d.id)));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load swap requests.');
    }
  }

  @override
  Future<ShiftSwapModel> createSwap(ShiftSwapModel swap) async {
    try {
      final docRef = _swaps.doc();
      final created = swap.copyWithId(docRef.id);
      await docRef.set({
        ...created.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return created;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to send the swap request.');
    }
  }

  @override
  Future<void> updateSwapStatus({
    required String swapId,
    required SwapStatus status,
  }) async {
    try {
      await _swaps.doc(swapId).set({
        'status': status.value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update the swap request.');
    }
  }

  List<WeeklyScheduleModel> _sortByWeek(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final models =
        docs.map((d) => WeeklyScheduleModel.fromMap(d.data(), id: d.id)).toList();
    models.sort((a, b) => b.weekStart.compareTo(a.weekStart));
    return models;
  }

  List<ShiftSwapModel> _sortSwaps(Iterable<ShiftSwapModel> swaps) {
    final list = swaps.toList();
    // Newest first (null createdAt — just-written — sorts to the top).
    list.sort((a, b) => (b.createdAt ?? DateTime.now())
        .compareTo(a.createdAt ?? DateTime.now()));
    return list;
  }
}
