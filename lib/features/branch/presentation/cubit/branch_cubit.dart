import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/branch/domain/entities/branch_entity.dart';
import 'package:fbro/features/branch/domain/repositories/branch_repository.dart';
import 'branch_state.dart';

/// Admin branch management (Phase 5). Calls [BranchRepository] directly (the
/// admin module has no use-case layer — see PROJECT_CONTEXT). Keeps the list
/// visible during mutations and restores it on error.
class BranchCubit extends Cubit<BranchState> {
  final BranchRepository _repository;

  BranchCubit(this._repository) : super(const BranchState.initial());

  List<BranchEntity> get _branches =>
      state.maybeWhen(loaded: (b, _) => b, orElse: () => const []);

  bool get _busy => state.maybeWhen(
        loaded: (_, busy) => busy,
        loading: () => true,
        orElse: () => false,
      );

  Future<void> load() async {
    emit(const BranchState.loading());
    try {
      emit(BranchState.loaded(await _repository.getBranches()));
    } on Failure catch (e) {
      emit(BranchState.error(e.message));
    } catch (_) {
      emit(const BranchState.error('Failed to load branches.'));
    }
  }

  Future<void> createBranch({required String name, String? location}) =>
      _mutate(() => _repository.createBranch(
            BranchEntity(id: '', name: name, location: location),
          ));

  Future<void> editBranch(BranchEntity branch) =>
      _mutate(() => _repository.updateBranch(branch));

  Future<void> setActive(BranchEntity branch, bool isActive) =>
      _mutate(() => _repository.setBranchActive(branch.id, isActive));

  Future<void> deleteBranch(BranchEntity branch) =>
      _mutate(() => _repository.deleteBranch(branch.id));

  Future<void> _mutate(Future<void> Function() action) async {
    if (_busy) return;
    final prev = _branches;
    emit(BranchState.loaded(prev, busy: true));
    try {
      await action();
      emit(BranchState.loaded(await _repository.getBranches()));
    } on Failure catch (e) {
      emit(BranchState.error(e.message));
      emit(BranchState.loaded(prev));
    } catch (_) {
      emit(const BranchState.error('Something went wrong. Please try again.'));
      emit(BranchState.loaded(prev));
    }
  }
}
