import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/enums/schedule_day.dart';
import 'package:fbro/core/enums/schedule_shift.dart';
import 'package:fbro/core/enums/swap_status.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/schedule/domain/entities/shift_swap_entity.dart';
import 'package:fbro/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:fbro/features/schedule/domain/swap_eligibility.dart';
import 'shift_swap_state.dart';

/// Drives the shift-swap workflow (Phase 7). An employee requests a swap on one
/// of their slots; the target coworker approves; the branch manager approves —
/// which rewrites the schedule. The list shown depends on the view: an employee
/// sees swaps involving them ([loadMine]); a manager sees their branch's queue
/// ([loadBranch]). Calls [ScheduleRepository] directly (no use-case layer).
/// Which slice of swaps the cubit is showing: the signed-in employee's own
/// ([mine]), one branch's queue ([branch], manager), or every branch ([all],
/// admin).
enum SwapScope { mine, branch, all }

class ShiftSwapCubit extends Cubit<ShiftSwapState> {
  final ScheduleRepository _repository;

  /// Reload context — drives which fetch [_load]/[_mutate] re-run.
  SwapScope _scope = SwapScope.mine;
  String _key = '';

  ShiftSwapCubit(this._repository) : super(const ShiftSwapState.initial());

  List<ShiftSwapEntity> get _swaps =>
      state.maybeWhen(loaded: (s, _) => s, orElse: () => const []);

  bool get _busy => state.maybeWhen(
        loaded: (_, busy) => busy,
        loading: () => true,
        orElse: () => false,
      );

  /// Employee view — swaps where [uid] is requester or target.
  Future<void> loadMine(String uid) async {
    _scope = SwapScope.mine;
    _key = uid;
    await _load();
  }

  /// Manager view — the branch's swap queue.
  Future<void> loadBranch(String branchId) async {
    _scope = SwapScope.branch;
    _key = branchId;
    await _load();
  }

  /// Admin view — every branch's swap queue.
  Future<void> loadAll() async {
    _scope = SwapScope.all;
    _key = '';
    await _load();
  }

  Future<void> refresh() => _load();

  // ── Employee actions ───────────────────────────────────────────
  Future<void> requestSwap({
    required String branchId,
    required DateTime weekStart,
    required ScheduleDay day,
    required ScheduleShift shift,
    required String requesterId,
    String? requesterName,
    required String targetId,
    String? targetName,
    String? note,
  }) async {
    // Authoritative client gate (spec §2): no swaps for past/in-progress shifts.
    if (!SwapEligibility.isRequestable(weekStart, day, shift)) {
      final prev = _swaps;
      emit(const ShiftSwapState.error(SwapEligibility.pastShiftMessage));
      emit(ShiftSwapState.loaded(prev));
      return;
    }
    await _mutate(() => _repository.createSwap(ShiftSwapEntity(
          id: '',
          branchId: branchId,
          weekStart: weekStart,
          day: day,
          shift: shift,
          requesterId: requesterId,
          requesterName: requesterName,
          targetId: targetId,
          targetName: targetName,
          note: note,
        )));
  }

  /// One-shot fetch of every **open** swap request (not resolved), across all
  /// branches — used by the Admin Home "Pending Actions" panel for at-a-glance
  /// operational visibility. Does not emit (mirrors `AdminUsersCubit.pendingUsers`).
  Future<List<ShiftSwapEntity>> pendingSwaps() async {
    try {
      final all = await _repository.getAllSwaps();
      return all.where((s) => !s.status.isResolved).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Target coworker approves → awaiting manager.
  Future<void> coworkerApprove(ShiftSwapEntity swap) => _mutate(() => _repository
      .updateSwapStatus(swapId: swap.id, status: SwapStatus.employeeApproved));

  /// Reject the swap (requester cancel, coworker decline, or manager reject).
  Future<void> reject(ShiftSwapEntity swap) => _mutate(() =>
      _repository.updateSwapStatus(swapId: swap.id, status: SwapStatus.rejected));

  // ── Manager action ─────────────────────────────────────────────
  /// Manager approves → schedule updates automatically.
  Future<void> managerApprove(ShiftSwapEntity swap) =>
      _mutate(() => _repository.managerApproveSwap(swap));

  // ── Internals ──────────────────────────────────────────────────
  Future<List<ShiftSwapEntity>> _fetch() {
    switch (_scope) {
      case SwapScope.mine:
        return _repository.getEmployeeSwaps(_key);
      case SwapScope.branch:
        return _repository.getBranchSwaps(_key);
      case SwapScope.all:
        return _repository.getAllSwaps();
    }
  }

  /// True when there's nothing to fetch — an empty key for the mine/branch
  /// scopes (the all scope needs no key).
  bool get _noTarget => _scope != SwapScope.all && _key.isEmpty;

  Future<void> _load() async {
    if (_noTarget) {
      emit(const ShiftSwapState.loaded([]));
      return;
    }
    emit(const ShiftSwapState.loading());
    try {
      emit(ShiftSwapState.loaded(await _fetch()));
    } on Failure catch (e) {
      emit(ShiftSwapState.error(e.message));
    } catch (_) {
      emit(const ShiftSwapState.error('Failed to load swap requests.'));
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (_busy || _noTarget) return;
    final prev = _swaps;
    emit(ShiftSwapState.loaded(prev, busy: true));
    try {
      await action();
      emit(ShiftSwapState.loaded(await _fetch()));
    } on Failure catch (e) {
      emit(ShiftSwapState.error(e.message));
      emit(ShiftSwapState.loaded(prev));
    } catch (_) {
      emit(const ShiftSwapState.error('Something went wrong. Please try again.'));
      emit(ShiftSwapState.loaded(prev));
    }
  }
}
