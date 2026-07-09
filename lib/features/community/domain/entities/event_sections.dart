import 'package:drop/core/enums/event_phase.dart';
import 'package:drop/core/enums/task_priority.dart';

/// The embedded **workspace sections** of an [EventEntity]. Each event is its own
/// operational workspace, and these value objects are the chapters that live
/// inside the single `events/{id}` document (timeline, team, tasks, inventory,
/// logistics, budget, communication, and the after-event outcome).
///
/// **All plain immutable classes (not freezed) by design** — deliberate for
/// value objects with this shape (no generated-file churn), the same choice made
/// for `BroadcastScheduleEntity`. They honour the domain-layer contract: pure
/// Dart, no Flutter/Firebase imports. Serialization lives in `EventModel`.

/// A planning **milestone** on the event timeline, grouped by [phase]. Toggling
/// it done is what makes the timeline visibly advance.
class EventMilestone {
  final String id;
  final String title;
  final EventPhase phase;
  final DateTime? dueAt;
  final bool done;
  final DateTime? completedAt;

  const EventMilestone({
    required this.id,
    required this.title,
    this.phase = EventPhase.planning,
    this.dueAt,
    this.done = false,
    this.completedAt,
  });

  /// Overdue only matters while it's still open.
  bool get isOverdue =>
      !done && dueAt != null && dueAt!.isBefore(DateTime.now());

  EventMilestone copyWith({
    String? title,
    EventPhase? phase,
    DateTime? dueAt,
    bool? done,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) =>
      EventMilestone(
        id: id,
        title: title ?? this.title,
        phase: phase ?? this.phase,
        dueAt: dueAt ?? this.dueAt,
        done: done ?? this.done,
        completedAt:
            clearCompletedAt ? null : (completedAt ?? this.completedAt),
      );
}

/// A **team assignment** — who owns what for this event. [userId] links to a real
/// DROP account when picked from the directory; [name] is always present so an
/// external helper (a vendor contact, a guest host) can be listed too.
class EventAssignment {
  final String id;
  final String? userId;
  final String name;

  /// What they're doing (e.g. "Setup Lead", "Floor Host", "Photographer").
  final String role;

  /// Optional department / team label.
  final String? department;
  final bool confirmed;

  const EventAssignment({
    required this.id,
    this.userId,
    required this.name,
    this.role = '',
    this.department,
    this.confirmed = false,
  });

  EventAssignment copyWith({
    String? userId,
    String? name,
    String? role,
    String? department,
    bool? confirmed,
  }) =>
      EventAssignment(
        id: id,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        role: role ?? this.role,
        department: department ?? this.department,
        confirmed: confirmed ?? this.confirmed,
      );
}

/// An **operational task / checklist item** for the event. Completing tasks
/// drives the preparation progress automatically.
class EventTask {
  final String id;
  final String title;
  final String? ownerId;
  final String? ownerName;
  final TaskPriority priority;
  final DateTime? dueAt;
  final bool done;
  final DateTime? completedAt;

  const EventTask({
    required this.id,
    required this.title,
    this.ownerId,
    this.ownerName,
    this.priority = TaskPriority.normal,
    this.dueAt,
    this.done = false,
    this.completedAt,
  });

  /// A task with nobody's name on it — the readiness engine flags these.
  bool get isUnowned => (ownerName ?? '').trim().isEmpty && ownerId == null;

  bool get isOverdue =>
      !done && dueAt != null && dueAt!.isBefore(DateTime.now());

  EventTask copyWith({
    String? title,
    String? ownerId,
    String? ownerName,
    TaskPriority? priority,
    DateTime? dueAt,
    bool? done,
    DateTime? completedAt,
    bool clearOwner = false,
    bool clearCompletedAt = false,
  }) =>
      EventTask(
        id: id,
        title: title ?? this.title,
        ownerId: clearOwner ? null : (ownerId ?? this.ownerId),
        ownerName: clearOwner ? null : (ownerName ?? this.ownerName),
        priority: priority ?? this.priority,
        dueAt: dueAt ?? this.dueAt,
        done: done ?? this.done,
        completedAt:
            clearCompletedAt ? null : (completedAt ?? this.completedAt),
      );
}

/// Something the event **needs on hand** — product, equipment, marketing assets,
/// decorations, packaging, uniforms. [ready] flips once it's secured.
class EventInventoryItem {
  final String id;
  final String name;

  /// A light free-text grouping (e.g. "Product", "Decor", "Marketing").
  final String category;
  final int quantity;
  final String? ownerName;
  final bool ready;

  const EventInventoryItem({
    required this.id,
    required this.name,
    this.category = '',
    this.quantity = 1,
    this.ownerName,
    this.ready = false,
  });

  EventInventoryItem copyWith({
    String? name,
    String? category,
    int? quantity,
    String? ownerName,
    bool? ready,
  }) =>
      EventInventoryItem(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        quantity: quantity ?? this.quantity,
        ownerName: ownerName ?? this.ownerName,
        ready: ready ?? this.ready,
      );
}

/// A **logistics** line — transport, setup, vendors, parking, security, power,
/// internet, furniture. [done] flips once it's arranged.
class EventLogisticsItem {
  final String id;
  final String title;
  final String? detail;
  final String? vendor;
  final bool done;

  const EventLogisticsItem({
    required this.id,
    required this.title,
    this.detail,
    this.vendor,
    this.done = false,
  });

  EventLogisticsItem copyWith({
    String? title,
    String? detail,
    String? vendor,
    bool? done,
  }) =>
      EventLogisticsItem(
        id: id,
        title: title ?? this.title,
        detail: detail ?? this.detail,
        vendor: vendor ?? this.vendor,
        done: done ?? this.done,
      );
}

/// A **budget** line — estimated vs actual, with an approval flag. The budget
/// section sums these for Estimated / Actual / Remaining.
class EventBudgetLine {
  final String id;
  final String label;
  final String? category;
  final double estimated;
  final double? actual;
  final bool approved;

  const EventBudgetLine({
    required this.id,
    required this.label,
    this.category,
    this.estimated = 0,
    this.actual,
    this.approved = false,
  });

  /// The number that counts against the budget — actual once known, else the
  /// estimate.
  double get effective => actual ?? estimated;

  /// Spent more than estimated on this line.
  bool get isOverEstimate => actual != null && actual! > estimated;

  EventBudgetLine copyWith({
    String? label,
    String? category,
    double? estimated,
    double? actual,
    bool? approved,
    bool clearActual = false,
  }) =>
      EventBudgetLine(
        id: id,
        label: label ?? this.label,
        category: category ?? this.category,
        estimated: estimated ?? this.estimated,
        actual: clearActual ? null : (actual ?? this.actual),
        approved: approved ?? this.approved,
      );
}

/// A **communication** post pinned to the event — announcements, updates,
/// important notices, emergency messages. [important] lifts it visually; a
/// pinned post stays at the top.
class EventAnnouncement {
  final String id;
  final String? authorId;
  final String? authorName;
  final String body;
  final bool pinned;
  final bool important;
  final DateTime createdAt;

  const EventAnnouncement({
    required this.id,
    this.authorId,
    this.authorName,
    required this.body,
    this.pinned = false,
    this.important = false,
    required this.createdAt,
  });

  EventAnnouncement copyWith({
    String? body,
    bool? pinned,
    bool? important,
  }) =>
      EventAnnouncement(
        id: id,
        authorId: authorId,
        authorName: authorName,
        body: body ?? this.body,
        pinned: pinned ?? this.pinned,
        important: important ?? this.important,
        createdAt: createdAt,
      );
}

/// The **after-event** record — the story the event leaves behind. Populated
/// once an event is completed: the numbers, and the qualitative wins / lessons /
/// recommendations that make the next one better.
class EventOutcome {
  final double? revenue;
  final int? visitors;
  final int? productsSold;
  final String summary;
  final List<String> wins;
  final List<String> lessons;
  final List<String> recommendations;

  const EventOutcome({
    this.revenue,
    this.visitors,
    this.productsSold,
    this.summary = '',
    this.wins = const [],
    this.lessons = const [],
    this.recommendations = const [],
  });

  bool get hasNumbers =>
      revenue != null || visitors != null || productsSold != null;

  bool get isEmpty =>
      !hasNumbers &&
      summary.trim().isEmpty &&
      wins.isEmpty &&
      lessons.isEmpty &&
      recommendations.isEmpty;

  EventOutcome copyWith({
    double? revenue,
    int? visitors,
    int? productsSold,
    String? summary,
    List<String>? wins,
    List<String>? lessons,
    List<String>? recommendations,
  }) =>
      EventOutcome(
        revenue: revenue ?? this.revenue,
        visitors: visitors ?? this.visitors,
        productsSold: productsSold ?? this.productsSold,
        summary: summary ?? this.summary,
        wins: wins ?? this.wins,
        lessons: lessons ?? this.lessons,
        recommendations: recommendations ?? this.recommendations,
      );
}
