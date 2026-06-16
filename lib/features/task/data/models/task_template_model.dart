import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbro/core/enums/task_type.dart';
import 'package:fbro/core/enums/task_priority.dart';
import 'package:fbro/features/task/domain/entities/task_template_entity.dart';

/// Firestore (de)serialization for [TaskTemplateEntity] — collection
/// `task_templates/{templateId}`.
class TaskTemplateModel {
  final String id;
  final String title;
  final String? description;
  final TaskType type;
  final TaskPriority priority;
  final String? branchId;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TaskTemplateModel({
    required this.id,
    required this.title,
    this.description,
    this.type = TaskType.daily,
    this.priority = TaskPriority.normal,
    this.branchId,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory TaskTemplateModel.fromMap(Map<String, dynamic> map, {String? id}) =>
      TaskTemplateModel(
        id: id ?? map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        description: map['description'] as String?,
        type: TaskType.fromString(map['type'] as String?),
        priority: TaskPriority.fromString(map['priority'] as String?),
        branchId: map['branchId'] as String?,
        createdBy: map['createdBy'] as String?,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      );

  factory TaskTemplateModel.fromEntity(TaskTemplateEntity e) =>
      TaskTemplateModel(
        id: e.id,
        title: e.title,
        description: e.description,
        type: e.type,
        priority: e.priority,
        branchId: e.branchId,
        createdBy: e.createdBy,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
      );

  /// Persisted fields. `createdAt`/`updatedAt` are written by the datasource as
  /// server timestamps, so they are intentionally not included here.
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.value,
        'priority': priority.value,
        'branchId': branchId,
        'createdBy': createdBy,
      };

  /// Returns a copy with the Firestore-generated [id] applied (used on create).
  TaskTemplateModel copyWithId(String id) => TaskTemplateModel(
        id: id,
        title: title,
        description: description,
        type: type,
        priority: priority,
        branchId: branchId,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  TaskTemplateEntity toEntity() => TaskTemplateEntity(
        id: id,
        title: title,
        description: description,
        type: type,
        priority: priority,
        branchId: branchId,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
