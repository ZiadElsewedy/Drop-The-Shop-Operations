import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbro/features/branch/domain/entities/branch_entity.dart';

/// Firestore (de)serialization for [BranchEntity] — collection `branches/{id}`.
class BranchModel {
  final String id;
  final String name;
  final String? location;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const BranchModel({
    required this.id,
    required this.name,
    this.location,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory BranchModel.fromMap(Map<String, dynamic> map, {String? id}) =>
      BranchModel(
        id: id ?? map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        location: map['location'] as String?,
        isActive: map['isActive'] as bool? ?? true,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
        deletedAt: (map['deletedAt'] as Timestamp?)?.toDate(),
      );

  factory BranchModel.fromEntity(BranchEntity e) => BranchModel(
        id: e.id,
        name: e.name,
        location: e.location,
        isActive: e.isActive,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        deletedAt: e.deletedAt,
      );

  /// Writable fields. Timestamps + `deletedAt` are managed by the datasource
  /// (server timestamps / soft-delete), so they're excluded here.
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'location': location,
        'isActive': isActive,
      };

  BranchModel copyWithId(String id) => BranchModel(
        id: id,
        name: name,
        location: location,
        isActive: isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );

  BranchEntity toEntity() => BranchEntity(
        id: id,
        name: name,
        location: location,
        isActive: isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );
}
