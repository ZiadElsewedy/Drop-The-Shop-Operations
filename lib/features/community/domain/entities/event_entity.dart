import 'package:drop/core/enums/event_status.dart';
import 'package:drop/core/enums/event_type.dart';
import 'package:drop/features/community/domain/entities/event_sections.dart';

/// A **DROP event** — the flagship Community Hub object. Not a calendar entry: an
/// event is its own operational **workspace**, so a single `events/{id}` document
/// carries both its identity (title, type, hero image, date, location, owner)
/// **and** every operational section embedded inline (timeline milestones, team,
/// tasks, inventory, logistics, budget, communication, and the after-event
/// outcome). Embedding keeps an event self-contained and cheap to stream as one
/// realtime doc — the whole workspace updates live from one snapshot.
///
/// **Plain immutable class (not freezed) by design** — the same deliberate choice
/// made for `BroadcastScheduleEntity`: a value object with this many fields reads
/// cleaner without generated-file churn, while still honouring the domain
/// contract (pure Dart, no Flutter/Firebase imports). Serialization lives in
/// `EventModel`; the readiness intelligence lives in `event_readiness.dart`.
class EventEntity {
  final String id;

  // ── Identity ──
  final String title;
  final EventType type;
  final EventStatus status;
  final String? heroImageUrl;
  final String description;

  // ── Where / when ──
  final String? branchId;

  /// Free-text venue / location presentation (e.g. "DROP Flagship — Zamalek").
  final String? location;
  final DateTime? startAt;
  final DateTime? endAt;

  // ── Ownership ──
  final String? ownerId;
  final String? ownerName;
  final int? expectedAttendance;

  // ── Embedded workspace sections ──
  final List<EventMilestone> milestones;
  final List<EventAssignment> team;
  final List<EventTask> tasks;
  final List<EventInventoryItem> inventory;
  final List<EventLogisticsItem> logistics;
  final List<EventBudgetLine> budget;
  final List<EventAnnouncement> announcements;
  final EventOutcome? outcome;

  // ── Audit ──
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Soft delete (admin-only) — the doc stays as a record, the hub filters it out.
  final DateTime? deletedAt;

  const EventEntity({
    required this.id,
    required this.title,
    this.type = EventType.other,
    this.status = EventStatus.draft,
    this.heroImageUrl,
    this.description = '',
    this.branchId,
    this.location,
    this.startAt,
    this.endAt,
    this.ownerId,
    this.ownerName,
    this.expectedAttendance,
    this.milestones = const [],
    this.team = const [],
    this.tasks = const [],
    this.inventory = const [],
    this.logistics = const [],
    this.budget = const [],
    this.announcements = const [],
    this.outcome,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;
  bool get isLive => status.isLive;
  bool get isTerminal => status.isTerminal;
  bool get isPreparing => status.isPreparing;
  bool get hasHeroImage => (heroImageUrl ?? '').trim().isNotEmpty;
  bool get hasOwner => (ownerName ?? '').trim().isNotEmpty || ownerId != null;

  /// Time until the doors open — null once past / undated. Negative once started.
  Duration? get countdown =>
      startAt == null ? null : startAt!.difference(DateTime.now());

  /// The event's start is still in the future.
  bool get isUpcoming =>
      startAt != null && startAt!.isAfter(DateTime.now()) && status.isActive;

  // ── Section rollups ──
  int get doneTasks => tasks.where((t) => t.done).length;
  int get doneMilestones => milestones.where((m) => m.done).length;
  int get readyInventory => inventory.where((i) => i.ready).length;
  int get doneLogistics => logistics.where((l) => l.done).length;
  int get confirmedTeam => team.where((m) => m.confirmed).length;

  /// The count of unowned tasks — the "warn if nobody owns a task" signal.
  int get unownedTasks => tasks.where((t) => t.isUnowned).length;

  /// Every checkable operational item, and how many are complete — the single
  /// source for the preparation ring in the hero. Tasks, milestones, inventory
  /// and logistics all count equally, so real work visibly moves the number.
  int get _preparableTotal =>
      tasks.length + milestones.length + inventory.length + logistics.length;
  int get _preparableDone =>
      doneTasks + doneMilestones + readyInventory + doneLogistics;

  /// Preparation progress in the range 0..1. A brand-new event with nothing to
  /// track reads as 0 (nothing prepared yet), not a misleading 100%.
  double get preparationProgress {
    final total = _preparableTotal;
    if (total == 0) return 0;
    return _preparableDone / total;
  }

  /// Whole-percent preparation for labels.
  int get preparationPercent => (preparationProgress * 100).round();

  // ── Budget rollups ──
  double get budgetEstimated =>
      budget.fold(0, (sum, b) => sum + b.estimated);
  double get budgetActual =>
      budget.fold(0, (sum, b) => sum + (b.actual ?? 0));

  /// Committed spend so far (actual where known, else the estimate) — what the
  /// remaining figure is measured against.
  double get budgetCommitted => budget.fold(0, (sum, b) => sum + b.effective);
  double get budgetRemaining => budgetEstimated - budgetActual;
  bool get isOverBudget => budgetActual > budgetEstimated && budgetEstimated > 0;

  /// Pinned-first, then newest — the order the communication feed renders in.
  List<EventAnnouncement> get orderedAnnouncements {
    final list = [...announcements];
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  EventEntity copyWith({
    String? title,
    EventType? type,
    EventStatus? status,
    String? heroImageUrl,
    String? description,
    String? branchId,
    String? location,
    DateTime? startAt,
    DateTime? endAt,
    String? ownerId,
    String? ownerName,
    int? expectedAttendance,
    List<EventMilestone>? milestones,
    List<EventAssignment>? team,
    List<EventTask>? tasks,
    List<EventInventoryItem>? inventory,
    List<EventLogisticsItem>? logistics,
    List<EventBudgetLine>? budget,
    List<EventAnnouncement>? announcements,
    EventOutcome? outcome,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearHeroImage = false,
  }) =>
      EventEntity(
        id: id,
        title: title ?? this.title,
        type: type ?? this.type,
        status: status ?? this.status,
        heroImageUrl:
            clearHeroImage ? null : (heroImageUrl ?? this.heroImageUrl),
        description: description ?? this.description,
        branchId: branchId ?? this.branchId,
        location: location ?? this.location,
        startAt: startAt ?? this.startAt,
        endAt: endAt ?? this.endAt,
        ownerId: ownerId ?? this.ownerId,
        ownerName: ownerName ?? this.ownerName,
        expectedAttendance: expectedAttendance ?? this.expectedAttendance,
        milestones: milestones ?? this.milestones,
        team: team ?? this.team,
        tasks: tasks ?? this.tasks,
        inventory: inventory ?? this.inventory,
        logistics: logistics ?? this.logistics,
        budget: budget ?? this.budget,
        announcements: announcements ?? this.announcements,
        outcome: outcome ?? this.outcome,
        createdBy: createdBy ?? this.createdBy,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
      );
}
