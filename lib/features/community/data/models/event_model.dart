import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drop/core/enums/event_phase.dart';
import 'package:drop/core/enums/event_status.dart';
import 'package:drop/core/enums/event_type.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/extensions/firestore_extensions.dart';
import 'package:drop/features/community/domain/entities/event_entity.dart';
import 'package:drop/features/community/domain/entities/event_sections.dart';

/// Firestore (de)serialization for [EventEntity] — collection `events/{id}`.
///
/// The event carries every workspace section embedded inline, so this maps a
/// deeply nested document (lists of milestone/task/budget/… maps + the outcome
/// map). Firestore returns nested date/time values as [Timestamp], so every
/// nested date is normalized `Timestamp ⇄ DateTime` at this boundary.
///
/// A namespace of static (de)serializers (the entity is already a plain
/// immutable class, so there's no parallel field list to keep in sync). Two write
/// shapes: [toCreateMap] (server timestamps for created/updated) and
/// [toUpdateMap] (all mutable fields + a fresh `updatedAt`).
class EventModel {
  EventModel._();

  // ─── Document ⇄ Entity ────────────────────────────────────────────────
  static EventEntity fromMap(Map<String, dynamic> map, {String? id}) =>
      EventEntity(
        id: id ?? map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        type: EventType.fromString(map['type'] as String?),
        status: EventStatus.fromString(map['status'] as String?),
        heroImageUrl: map['heroImageUrl'] as String?,
        description: map['description'] as String? ?? '',
        branchId: map['branchId'] as String?,
        location: map['location'] as String?,
        startAt: map.date('startAt'),
        endAt: map.date('endAt'),
        ownerId: map['ownerId'] as String?,
        ownerName: map['ownerName'] as String?,
        expectedAttendance: (map['expectedAttendance'] as num?)?.toInt(),
        milestones: _list(map['milestones'], _milestoneFrom),
        team: _list(map['team'], _assignmentFrom),
        tasks: _list(map['tasks'], _taskFrom),
        inventory: _list(map['inventory'], _inventoryFrom),
        logistics: _list(map['logistics'], _logisticsFrom),
        budget: _list(map['budget'], _budgetFrom),
        announcements: _list(map['announcements'], _announcementFrom),
        outcome: _outcomeFrom(map['outcome']),
        createdBy: map['createdBy'] as String?,
        createdAt: map.date('createdAt'),
        updatedAt: map.date('updatedAt'),
        deletedAt: map.date('deletedAt'),
      );

  /// The **create** payload — identity + schedule + (usually empty) sections.
  /// `createdAt`/`updatedAt` are written as server timestamps by the datasource,
  /// so they're omitted here.
  static Map<String, dynamic> toCreateMap(EventEntity e) => {
        'id': e.id,
        'title': e.title,
        'type': e.type.value,
        'status': e.status.value,
        'heroImageUrl': e.heroImageUrl,
        'description': e.description,
        'branchId': e.branchId,
        'location': e.location,
        'startAt': _tsOrNull(e.startAt),
        'endAt': _tsOrNull(e.endAt),
        'ownerId': e.ownerId,
        'ownerName': e.ownerName,
        'expectedAttendance': e.expectedAttendance,
        'createdBy': e.createdBy,
        ..._sectionsMap(e),
      };

  /// The **update** payload — every mutable field, including all sections. `id`,
  /// `createdBy` and `createdAt` are immutable, so they're excluded; `updatedAt`
  /// is stamped by the datasource.
  static Map<String, dynamic> toUpdateMap(EventEntity e) => {
        'title': e.title,
        'type': e.type.value,
        'status': e.status.value,
        'heroImageUrl': e.heroImageUrl,
        'description': e.description,
        'branchId': e.branchId,
        'location': e.location,
        'startAt': _tsOrNull(e.startAt),
        'endAt': _tsOrNull(e.endAt),
        'ownerId': e.ownerId,
        'ownerName': e.ownerName,
        'expectedAttendance': e.expectedAttendance,
        ..._sectionsMap(e),
      };

  static Map<String, dynamic> _sectionsMap(EventEntity e) => {
        'milestones': [for (final m in e.milestones) _milestoneTo(m)],
        'team': [for (final a in e.team) _assignmentTo(a)],
        'tasks': [for (final t in e.tasks) _taskTo(t)],
        'inventory': [for (final i in e.inventory) _inventoryTo(i)],
        'logistics': [for (final l in e.logistics) _logisticsTo(l)],
        'budget': [for (final b in e.budget) _budgetTo(b)],
        'announcements': [for (final a in e.announcements) _announcementTo(a)],
        'outcome': e.outcome == null ? null : _outcomeTo(e.outcome!),
      };

  // ─── Section (de)serializers ──────────────────────────────────────────
  static EventMilestone _milestoneFrom(Map<String, dynamic> m) => EventMilestone(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        phase: EventPhase.fromString(m['phase'] as String?),
        dueAt: _dt(m['dueAt']),
        done: m['done'] as bool? ?? false,
        completedAt: _dt(m['completedAt']),
      );

  static Map<String, dynamic> _milestoneTo(EventMilestone m) => {
        'id': m.id,
        'title': m.title,
        'phase': m.phase.value,
        'dueAt': _tsOrNull(m.dueAt),
        'done': m.done,
        'completedAt': _tsOrNull(m.completedAt),
      };

  static EventAssignment _assignmentFrom(Map<String, dynamic> m) =>
      EventAssignment(
        id: m['id'] as String? ?? '',
        userId: m['userId'] as String?,
        name: m['name'] as String? ?? '',
        role: m['role'] as String? ?? '',
        department: m['department'] as String?,
        confirmed: m['confirmed'] as bool? ?? false,
      );

  static Map<String, dynamic> _assignmentTo(EventAssignment a) => {
        'id': a.id,
        'userId': a.userId,
        'name': a.name,
        'role': a.role,
        'department': a.department,
        'confirmed': a.confirmed,
      };

  static EventTask _taskFrom(Map<String, dynamic> m) => EventTask(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        ownerId: m['ownerId'] as String?,
        ownerName: m['ownerName'] as String?,
        priority: TaskPriority.fromString(m['priority'] as String?),
        dueAt: _dt(m['dueAt']),
        done: m['done'] as bool? ?? false,
        completedAt: _dt(m['completedAt']),
      );

  static Map<String, dynamic> _taskTo(EventTask t) => {
        'id': t.id,
        'title': t.title,
        'ownerId': t.ownerId,
        'ownerName': t.ownerName,
        'priority': t.priority.value,
        'dueAt': _tsOrNull(t.dueAt),
        'done': t.done,
        'completedAt': _tsOrNull(t.completedAt),
      };

  static EventInventoryItem _inventoryFrom(Map<String, dynamic> m) =>
      EventInventoryItem(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        category: m['category'] as String? ?? '',
        quantity: (m['quantity'] as num?)?.toInt() ?? 1,
        ownerName: m['ownerName'] as String?,
        ready: m['ready'] as bool? ?? false,
      );

  static Map<String, dynamic> _inventoryTo(EventInventoryItem i) => {
        'id': i.id,
        'name': i.name,
        'category': i.category,
        'quantity': i.quantity,
        'ownerName': i.ownerName,
        'ready': i.ready,
      };

  static EventLogisticsItem _logisticsFrom(Map<String, dynamic> m) =>
      EventLogisticsItem(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        detail: m['detail'] as String?,
        vendor: m['vendor'] as String?,
        done: m['done'] as bool? ?? false,
      );

  static Map<String, dynamic> _logisticsTo(EventLogisticsItem l) => {
        'id': l.id,
        'title': l.title,
        'detail': l.detail,
        'vendor': l.vendor,
        'done': l.done,
      };

  static EventBudgetLine _budgetFrom(Map<String, dynamic> m) => EventBudgetLine(
        id: m['id'] as String? ?? '',
        label: m['label'] as String? ?? '',
        category: m['category'] as String?,
        estimated: (m['estimated'] as num?)?.toDouble() ?? 0,
        actual: (m['actual'] as num?)?.toDouble(),
        approved: m['approved'] as bool? ?? false,
      );

  static Map<String, dynamic> _budgetTo(EventBudgetLine b) => {
        'id': b.id,
        'label': b.label,
        'category': b.category,
        'estimated': b.estimated,
        'actual': b.actual,
        'approved': b.approved,
      };

  static EventAnnouncement _announcementFrom(Map<String, dynamic> m) =>
      EventAnnouncement(
        id: m['id'] as String? ?? '',
        authorId: m['authorId'] as String?,
        authorName: m['authorName'] as String?,
        body: m['body'] as String? ?? '',
        pinned: m['pinned'] as bool? ?? false,
        important: m['important'] as bool? ?? false,
        createdAt: _dt(m['createdAt']) ?? DateTime.now(),
      );

  static Map<String, dynamic> _announcementTo(EventAnnouncement a) => {
        'id': a.id,
        'authorId': a.authorId,
        'authorName': a.authorName,
        'body': a.body,
        'pinned': a.pinned,
        'important': a.important,
        'createdAt': Timestamp.fromDate(a.createdAt),
      };

  static EventOutcome? _outcomeFrom(dynamic raw) {
    if (raw is! Map) return null;
    final m = raw.cast<String, dynamic>();
    return EventOutcome(
      revenue: (m['revenue'] as num?)?.toDouble(),
      visitors: (m['visitors'] as num?)?.toInt(),
      productsSold: (m['productsSold'] as num?)?.toInt(),
      summary: m['summary'] as String? ?? '',
      wins: _stringList(m['wins']),
      lessons: _stringList(m['lessons']),
      recommendations: _stringList(m['recommendations']),
    );
  }

  static Map<String, dynamic> _outcomeTo(EventOutcome o) => {
        'revenue': o.revenue,
        'visitors': o.visitors,
        'productsSold': o.productsSold,
        'summary': o.summary,
        'wins': o.wins,
        'lessons': o.lessons,
        'recommendations': o.recommendations,
      };

  // ─── Small shared helpers ─────────────────────────────────────────────
  /// Maps a raw Firestore list into typed items, tolerating malformed entries.
  static List<T> _list<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) from,
  ) {
    if (raw is! List) return const [];
    final out = <T>[];
    for (final e in raw) {
      if (e is Map) out.add(from(e.cast<String, dynamic>()));
    }
    return out;
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return [for (final e in raw) e.toString()];
  }

  /// Nested `Timestamp → DateTime` (top-level dates use `map.date`).
  static DateTime? _dt(dynamic v) => v is Timestamp ? v.toDate() : null;

  static Timestamp? _tsOrNull(DateTime? d) =>
      d == null ? null : Timestamp.fromDate(d);
}
