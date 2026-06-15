import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/branch/data/datasources/branch_remote_datasource.dart';
import 'package:fbro/features/branch/data/models/branch_model.dart';
import 'package:fbro/features/branch/domain/entities/branch_entity.dart';
import 'package:fbro/features/branch/domain/repositories/branch_repository.dart';

class BranchRepositoryImpl implements BranchRepository {
  final BranchRemoteDataSource _remote;

  BranchRepositoryImpl(this._remote);

  @override
  Future<List<BranchEntity>> getBranches({bool includeDeleted = false}) async {
    try {
      final models = await _remote.getBranches(includeDeleted: includeDeleted);
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<BranchEntity> createBranch(BranchEntity branch) async {
    try {
      final created = await _remote.createBranch(BranchModel.fromEntity(branch));
      return created.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> updateBranch(BranchEntity branch) async {
    try {
      await _remote.updateBranch(BranchModel.fromEntity(branch));
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> setBranchActive(String branchId, bool isActive) async {
    try {
      await _remote.setBranchActive(branchId, isActive);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> deleteBranch(String branchId) async {
    try {
      await _remote.softDeleteBranch(branchId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
