import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drop/core/extensions/firestore_extensions.dart';
import 'package:drop/core/enums/attachment_type.dart';
import 'package:drop/core/enums/recurrence_frequency.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/task_type.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/features/task/domain/entities/activity_entry.dart';
import 'package:drop/features/task/domain/entities/checklist_item.dart';
import 'package:drop/features/task/domain/entities/recurrence_config.dart';
import 'package:drop/features/task/domain/entities/task_attachment.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';

/// Firestore (de)serialization for [TaskEntity] — collection `tasks/{taskId}`.
///
/// Multi-assignee (Phase 9): the canonical field is `assigneeIds` (array). For
/// backward compatibility with the legacy single-assignee schema, [fromMap]
/// falls back to a `assignedEmployeeId` string when no array is present, and
/// [toMap] keeps `assignedEmployeeId` in sync as the **primary** assignee
/// (first id, or null) so existing Firestore rules / statistics queries that
/// key off it keep working without a migration.
class TaskModel {
  final String id;
  final String title;
  final String? description;
  final TaskType type;
  final TaskStatus status;
  final TaskPriority priority;
  final String? branchId;
  final List<String> assigneeIds;
  final List<ChecklistItem> checklist;
  final List<TaskAttachment> referenceAttachments;
  final String? createdBy;
  final String? assignedShiftId;
  final ScheduleShift? shift;
  final DateTime? deadline;
  final String? notes;
  final String? proofImageUrl;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectedBy;
  final DateTime? rejectedAt;
  final String? reviewNotes;
  final int revisionNumber;
  final bool requiresRework;
  final String? rejectionReason;
  final RecurrenceConfig? recurrence;
  final List<ActivityEntry> activityLog;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TaskModel({
    required this.id,
    required this.title,
    this.description,
    this.type = TaskType.daily,
    this.status = TaskStatus.pending,
    this.priority = TaskPriority.normal,
    this.branchId,
    this.assigneeIds = const [],
    this.checklist = const [],
    this.referenceAttachments = const [],
    this.createdBy,
    this.assignedShiftId,
    this.shift,
    this.deadline,
    this.notes,
    this.proofImageUrl,
    this.startedAt,
    this.submittedAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedAt,
    this.reviewNotes,
    this.revisionNumber = 0,
    this.requiresRework = false,
    this.rejectionReason,
    this.recurrence,
    this.activityLog = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory TaskModel.fromMap(Map<String, dynamic> map, {String? id}) => TaskModel(
        id: id ?? map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        description: map['description'] as String?,
        type: TaskType.fromString(map['type'] as String?),
        status: TaskStatus.fromString(map['status'] as String?),
        priority: TaskPriority.fromString(map['priority'] as String?),
        branchId: map['branchId'] as String?,
        assigneeIds: _assigneesFromMap(map),
        checklist: _checklistFromList(map['checklist']),
        referenceAttachments: _attachmentsFromList(map['referenceAttachments']),
        createdBy: map['createdBy'] as String?,
        assignedShiftId: map['assignedShiftId'] as String?,
        shift: ScheduleShift.fromStringOrNull(map['shift'] as String?),
        deadline: map.date('deadline'),
        notes: map['notes'] as String?,
        proofImageUrl: map['proofImageUrl'] as String?,
        startedAt: map.date('startedAt'),
        submittedAt: map.date('submittedAt'),
        approvedBy: map['approvedBy'] as String?,
        approvedAt: map.date('approvedAt'),
        rejectedBy: map['rejectedBy'] as String?,
        rejectedAt: map.date('rejectedAt'),
        reviewNotes: map['reviewNotes'] as String?,
        revisionNumber: (map['revisionNumber'] as num?)?.toInt() ?? 0,
        requiresRework: map['requiresRework'] as bool? ?? false,
        rejectionReason: map['rejectionReason'] as String?,
        recurrence: _recurrenceFromMap(map['recurrence']),
        activityLog: _activityLogFromList(map['activityLog']),
        createdAt: map.date('createdAt'),
        updatedAt: map.date('updatedAt'),
      );

  factory TaskModel.fromEntity(TaskEntity e) => TaskModel(
        id: e.id,
        title: e.title,
        description: e.description,
        type: e.type,
        status: e.status,
        priority: e.priority,
        branchId: e.branchId,
        assigneeIds: e.assigneeIds,
        checklist: e.checklist,
        referenceAttachments: e.referenceAttachments,
        createdBy: e.createdBy,
        assignedShiftId: e.assignedShiftId,
        shift: e.shift,
        deadline: e.deadline,
        notes: e.notes,
        proofImageUrl: e.proofImageUrl,
        startedAt: e.startedAt,
        submittedAt: e.submittedAt,
        approvedBy: e.approvedBy,
        approvedAt: e.approvedAt,
        rejectedBy: e.rejectedBy,
        rejectedAt: e.rejectedAt,
        reviewNotes: e.reviewNotes,
        revisionNumber: e.revisionNumber,
        requiresRework: e.requiresRework,
        rejectionReason: e.rejectionReason,
        recurrence: e.recurrence,
        activityLog: e.activityLog,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
      );

  /// Persisted fields. `createdAt`/`updatedAt` are written by the datasource as
  /// server timestamps, so they are intentionally not included here. `deadline`
  /// is converted to a [Timestamp] when present. `assignedEmployeeId` mirrors
  /// the primary assignee for backward compatibility (rules / statistics).
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.value,
        'status': status.value,
        'priority': priority.value,
        'branchId': branchId,
        'assigneeIds': assigneeIds,
        'assignedEmployeeId': assigneeIds.isEmpty ? null : assigneeIds.first,
        'checklist': _checklistToList(checklist),
        'referenceAttachments': _attachmentsToList(referenceAttachments),
        'createdBy': createdBy,
        'assignedShiftId': assignedShiftId,
        'shift': shift?.value,
        'deadline': deadline == null ? null : Timestamp.fromDate(deadline!),
        'notes': notes,
        'proofImageUrl': proofImageUrl,
        'startedAt': startedAt == null ? null : Timestamp.fromDate(startedAt!),
        'submittedAt': submittedAt == null ? null : Timestamp.fromDate(submittedAt!),
        'approvedBy': approvedBy,
        'approvedAt': approvedAt == null ? null : Timestamp.fromDate(approvedAt!),
        'rejectedBy': rejectedBy,
        'rejectedAt': rejectedAt == null ? null : Timestamp.fromDate(rejectedAt!),
        'reviewNotes': reviewNotes,
        'revisionNumber': revisionNumber,
        'requiresRework': requiresRework,
        'rejectionReason': rejectionReason,
        'recurrence': _recurrenceToMap(recurrence),
        'activityLog': _activityLogToList(activityLog),
      };

  /// Returns a copy with the Firestore-generated [id] applied (used on create).
  TaskModel copyWithId(String id) => TaskModel(
        id: id,
        title: title,
        description: description,
        type: type,
        status: status,
        priority: priority,
        branchId: branchId,
        assigneeIds: assigneeIds,
        checklist: checklist,
        referenceAttachments: referenceAttachments,
        createdBy: createdBy,
        assignedShiftId: assignedShiftId,
        shift: shift,
        deadline: deadline,
        notes: notes,
        proofImageUrl: proofImageUrl,
        startedAt: startedAt,
        submittedAt: submittedAt,
        approvedBy: approvedBy,
        approvedAt: approvedAt,
        rejectedBy: rejectedBy,
        rejectedAt: rejectedAt,
        reviewNotes: reviewNotes,
        revisionNumber: revisionNumber,
        requiresRework: requiresRework,
        rejectionReason: rejectionReason,
        recurrence: recurrence,
        activityLog: activityLog,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  TaskEntity toEntity() => TaskEntity(
        id: id,
        title: title,
        description: description,
        type: type,
        status: status,
        priority: priority,
        branchId: branchId,
        assigneeIds: assigneeIds,
        checklist: checklist,
        referenceAttachments: referenceAttachments,
        createdBy: createdBy,
        assignedShiftId: assignedShiftId,
        shift: shift,
        deadline: deadline,
        notes: notes,
        proofImageUrl: proofImageUrl,
        startedAt: startedAt,
        submittedAt: submittedAt,
        approvedBy: approvedBy,
        approvedAt: approvedAt,
        rejectedBy: rejectedBy,
        rejectedAt: rejectedAt,
        reviewNotes: reviewNotes,
        revisionNumber: revisionNumber,
        requiresRework: requiresRework,
        rejectionReason: rejectionReason,
        recurrence: recurrence,
        activityLog: activityLog,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  /// Reads `assigneeIds` (array); falls back to the legacy single
  /// `assignedEmployeeId` string for documents written before Phase 9.
  static List<String> _assigneesFromMap(Map<String, dynamic> map) {
    final raw = map['assigneeIds'];
    if (raw is List) {
      final ids = raw.whereType<String>().where((s) => s.isNotEmpty).toList();
      if (ids.isNotEmpty) return ids;
    }
    final legacy = map['assignedEmployeeId'] as String?;
    return (legacy != null && legacy.isNotEmpty) ? [legacy] : const [];
  }

  static List<ChecklistItem> _checklistFromList(dynamic raw) {
    if (raw is! List) return const [];
    final items = <ChecklistItem>[];
    for (final e in raw) {
      if (e is Map) {
        final title = e['title'] as String? ?? '';
        if (title.isEmpty) continue;
        items.add(ChecklistItem(
          id: e['id'] as String? ?? '',
          title: title,
          isRequired: e['isRequired'] as bool? ?? true,
          completed: e['completed'] as bool? ?? false,
          completedAt: (e['completedAt'] as Timestamp?)?.toDate(),
        ));
      }
    }
    return items;
  }

  static List<Map<String, dynamic>> _checklistToList(List<ChecklistItem> items) =>
      [
        for (final i in items)
          {
            'id': i.id,
            'title': i.title,
            'isRequired': i.isRequired,
            'completed': i.completed,
            'completedAt':
                i.completedAt == null ? null : Timestamp.fromDate(i.completedAt!),
          },
      ];

  static RecurrenceConfig? _recurrenceFromMap(dynamic raw) {
    if (raw is! Map) return null;
    return RecurrenceConfig(
      frequency: RecurrenceFrequency.fromString(raw['frequency'] as String?),
      interval: (raw['interval'] as int?) ?? 1,
      weekday: (raw['weekday'] as int?) ?? 1,
      hour: (raw['hour'] as int?) ?? 9,
      minute: (raw['minute'] as int?) ?? 0,
    );
  }

  static Map<String, dynamic>? _recurrenceToMap(RecurrenceConfig? r) {
    if (r == null) return null;
    return {
      'frequency': r.frequency.value,
      'interval': r.interval,
      'weekday': r.weekday,
      'hour': r.hour,
      'minute': r.minute,
    };
  }

  static List<ActivityEntry> _activityLogFromList(dynamic raw) {
    if (raw is! List) return const [];
    final result = <ActivityEntry>[];
    for (final e in raw) {
      if (e is Map) {
        final at = (e['at'] as Timestamp?)?.toDate();
        if (at == null) continue;
        result.add(ActivityEntry(
          status: e['status'] as String? ?? '',
          actorId: e['actorId'] as String? ?? '',
          actorName: e['actorName'] as String?,
          at: at,
          note: e['note'] as String?,
          attachments: _attachmentsFromList(e['attachments']),
        ));
      }
    }
    return result;
  }

  static List<Map<String, dynamic>> _activityLogToList(
          List<ActivityEntry> log) =>
      [
        for (final e in log)
          {
            'status': e.status,
            'actorId': e.actorId,
            'actorName': e.actorName,
            'at': Timestamp.fromDate(e.at),
            'note': e.note,
            'attachments': _attachmentsToList(e.attachments),
          },
      ];

  static List<TaskAttachment> _attachmentsFromList(dynamic raw) {
    if (raw is! List) return const [];
    final result = <TaskAttachment>[];
    for (final a in raw) {
      if (a is Map) {
        final url = a['url'] as String? ?? '';
        if (url.isEmpty) continue;
        result.add(TaskAttachment(
          id: a['id'] as String? ?? '',
          url: url,
          type: AttachmentType.fromString(a['type'] as String?),
          uploadedAt:
              (a['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          uploadedBy: a['uploadedBy'] as String? ?? '',
          uploadedByName: a['uploadedByName'] as String?,
          durationMs: (a['durationMs'] as num?)?.toInt(),
        ));
      }
    }
    return result;
  }

  static List<Map<String, dynamic>> _attachmentsToList(
          List<TaskAttachment> items) =>
      [
        for (final a in items)
          {
            'id': a.id,
            'url': a.url,
            'type': a.type.value,
            'uploadedAt': Timestamp.fromDate(a.uploadedAt),
            'uploadedBy': a.uploadedBy,
            'uploadedByName': a.uploadedByName,
            'durationMs': a.durationMs,
          },
      ];
}
