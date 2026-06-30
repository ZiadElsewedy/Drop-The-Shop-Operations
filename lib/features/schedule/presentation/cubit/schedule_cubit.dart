import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:drop/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';
import 'schedule_state.dart';

/// Drives the weekly-schedule view for managers (own branch), admins (any
/// branch) and employees (read-only, own branch). Loads the schedule for a
/// (branch, week) together with the branch members (for name display + the
/// assignee picker), then keeps the view visible during mutations. Calls
/// [ScheduleRepository] directly (no use-case layer — same as branch/admin).
class ScheduleCubit extends Cubit<ScheduleState> {
  final ScheduleRepository _repository;
  final GetUsersByBranch _getUsersByBranch;

  String _branchId = '';
  DateTime _weekStart = ScheduleWeek.currentWeekStart();

  ScheduleCubit(this._repository, this._getUsersByBranch)
      : super(const ScheduleState.initial());

  String get branchId => _branchId;
  DateTime get weekStart => _weekStart;

  bool get _busy => state.maybeWhen(
        loaded: (_, _, _, _, busy) => busy,
        loading: () => true,
        orElse: () => false,
      );

  /// Loads the schedule + branch members for ([branchId], [weekStart]). Pass an
  /// empty [branchId] (admin, no branch picked yet) to render the empty view.
  Future<void> load({required String branchId, DateTime? weekStart}) async {
    _branchId = branchId;
    _weekStart = ScheduleWeek.startOf(weekStart ?? _weekStart);
    emit(const ScheduleState.loading());
    await _emitLoaded();
  }

  Future<void> previousWeek() =>
      load(branchId: _branchId, weekStart: _weekStart.subtract(const Duration(days: 7)));

  Future<void> nextWeek() =>
      load(branchId: _branchId, weekStart: _weekStart.add(const Duration(days: 7)));

  Future<void> selectBranch(String branchId) =>
      load(branchId: branchId, weekStart: _weekStart);

  Future<void> refresh() => load(branchId: _branchId, weekStart: _weekStart);

  /// Creates an empty schedule for the current (branch, week).
  Future<void> createSchedule({String? createdBy}) {
    if (_branchId.isEmpty) return Future.value();
    return _mutate(() => _repository.createSchedule(
          branchId: _branchId,
          weekStart: _weekStart,
          createdBy: createdBy,
        ));
  }

  Future<void> assign(ScheduleDay day, ScheduleShift shift, String uid) =>
      _mutate(() => _repository.assignEmployee(
            scheduleId: ScheduleWeek.docId(_branchId, _weekStart),
            day: day,
            shift: shift,
            employeeId: uid,
          ));

  Future<void> remove(ScheduleDay day, ScheduleShift shift, String uid) =>
      _mutate(() => _repository.removeEmployee(
            scheduleId: ScheduleWeek.docId(_branchId, _weekStart),
            day: day,
            shift: shift,
            employeeId: uid,
          ));

  // ── Internals ──────────────────────────────────────────────────
  Future<void> _emitLoaded() async {
    try {
      final schedule = _branchId.isEmpty
          ? null
          : await _repository.getSchedule(_branchId, _weekStart);
      final members =
          _branchId.isEmpty ? const <UserEntity>[] : await _getUsersByBranch(_branchId);
      emit(ScheduleState.loaded(
        branchId: _branchId,
        weekStart: _weekStart,
        schedule: schedule,
        members: members,
      ));
    } on Failure catch (e) {
      emit(ScheduleState.error(e.message));
    } catch (_) {
      emit(const ScheduleState.error('Failed to load the schedule.'));
    }
  }

  /// Runs [action], then reloads the view — keeping the current view visible
  /// (busy) so the UI never flickers, and restoring it on failure.
  Future<void> _mutate(Future<void> Function() action) async {
    if (_busy) return;
    final prev = state;
    state.maybeWhen(
      loaded: (b, w, s, m, _) => emit(ScheduleState.loaded(
          branchId: b, weekStart: w, schedule: s, members: m, busy: true)),
      orElse: () {},
    );
    try {
      await action();
      await _emitLoaded();
    } on Failure catch (e) {
      emit(ScheduleState.error(e.message));
      emit(prev);
    } catch (_) {
      emit(const ScheduleState.error('Something went wrong. Please try again.'));
      emit(prev);
    }
  }
}
