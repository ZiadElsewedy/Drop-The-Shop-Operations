import 'package:drop/features/community/domain/entities/event_entity.dart';

/// How urgently an insight wants attention.
enum EventInsightLevel { blocker, warning, win }

/// One line of operational intelligence about an event — a blocker to clear, a
/// warning to weigh, or a win to celebrate. Purely descriptive (no Flutter), so
/// the readiness panel maps [level] → colour/icon itself.
class EventInsight {
  final String title;
  final String detail;
  final EventInsightLevel level;

  const EventInsight(this.title, this.detail, this.level);
}

/// The computed **readiness** of an event — a 0..100 score, a headline, and the
/// ranked insights behind it. This is the "think beyond CRUD" layer: it detects
/// missing owners, unowned tasks, overdue work, over-budget spend, thin
/// preparation near the date, and surfaces what's already locked in.
///
/// Pure + deterministic so it's unit-tested independently of any UI. Computed by
/// [EventReadiness.assess].
class EventReadiness {
  final int score;
  final String headline;
  final List<EventInsight> insights;

  const EventReadiness({
    required this.score,
    required this.headline,
    required this.insights,
  });

  List<EventInsight> get blockers =>
      insights.where((i) => i.level == EventInsightLevel.blocker).toList();
  List<EventInsight> get warnings =>
      insights.where((i) => i.level == EventInsightLevel.warning).toList();
  List<EventInsight> get wins =>
      insights.where((i) => i.level == EventInsightLevel.win).toList();

  bool get hasBlockers => blockers.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;

  /// The single most important thing to look at (a blocker, else a warning, else
  /// the top win), or null when there's nothing to say.
  EventInsight? get topInsight => insights.isEmpty ? null : insights.first;

  /// Assess [e]. Score blends real preparation (up to 55 pts) with operational
  /// coverage (owner, date, venue, team, tasks, artwork, budget — up to 45 pts),
  /// then ranks the insights blocker → warning → win.
  static EventReadiness assess(EventEntity e) {
    final now = DateTime.now();

    // ── Score ──
    var coverage = 0.0;
    if (e.hasOwner) coverage += 8;
    if (e.startAt != null) coverage += 7;
    if ((e.location ?? '').trim().isNotEmpty) coverage += 5;
    if (e.team.isNotEmpty) coverage += 8;
    if (e.tasks.isNotEmpty) coverage += 5;
    if (e.hasHeroImage) coverage += 4;
    if (e.budget.isNotEmpty && !e.isOverBudget) coverage += 8;

    final base = e.preparationProgress * 55;
    final score = (base + coverage).clamp(0, 100).round();

    // ── Insights ──
    final blockers = <EventInsight>[];
    final warnings = <EventInsight>[];
    final wins = <EventInsight>[];

    // Blockers — the things that must be true before an event can run.
    if (!e.hasOwner) {
      blockers.add(const EventInsight(
        'No event owner',
        'Assign someone accountable for this event.',
        EventInsightLevel.blocker,
      ));
    }
    if (e.startAt == null) {
      blockers.add(const EventInsight(
        'No date set',
        'Set when the event happens so the countdown and timeline work.',
        EventInsightLevel.blocker,
      ));
    }
    if (e.team.isEmpty) {
      blockers.add(const EventInsight(
        'Nobody assigned',
        'Add the team who will make this happen.',
        EventInsightLevel.blocker,
      ));
    }
    if (e.unownedTasks > 0) {
      blockers.add(EventInsight(
        '${e.unownedTasks} ${_plural(e.unownedTasks, 'task')} with no owner',
        'Every task needs a name on it, or it slips.',
        EventInsightLevel.blocker,
      ));
    }
    if (e.isOverBudget) {
      blockers.add(EventInsight(
        'Over budget',
        'Actual spend has passed the estimate — review the budget.',
        EventInsightLevel.blocker,
      ));
    }

    // Warnings — worth addressing, not fatal.
    if (!e.hasHeroImage) {
      warnings.add(const EventInsight(
        'No event artwork',
        'A hero image makes the event feel real to the team.',
        EventInsightLevel.warning,
      ));
    }
    if (e.tasks.isEmpty) {
      warnings.add(const EventInsight(
        'No task list yet',
        'Break the event into tasks so preparation can be tracked.',
        EventInsightLevel.warning,
      ));
    }
    if (e.inventory.isEmpty && e.type.isPublicFacing) {
      warnings.add(const EventInsight(
        'No inventory tracked',
        'List the products, assets and equipment the event needs.',
        EventInsightLevel.warning,
      ));
    }
    final overdueTasks = e.tasks.where((t) => t.isOverdue).length;
    if (overdueTasks > 0) {
      warnings.add(EventInsight(
        '$overdueTasks ${_plural(overdueTasks, 'task')} overdue',
        'Past their due date and still open.',
        EventInsightLevel.warning,
      ));
    }
    final overdueMilestones = e.milestones.where((m) => m.isOverdue).length;
    if (overdueMilestones > 0) {
      warnings.add(EventInsight(
        '$overdueMilestones ${_plural(overdueMilestones, 'milestone')} overdue',
        'Timeline milestones that have slipped.',
        EventInsightLevel.warning,
      ));
    }
    final unconfirmed = e.team.length - e.confirmedTeam;
    if (e.team.isNotEmpty && unconfirmed > 0) {
      warnings.add(EventInsight(
        '$unconfirmed on the team ${unconfirmed == 1 ? "hasn't" : "haven't"} confirmed',
        'Chase confirmations so nobody assumes someone else has it.',
        EventInsightLevel.warning,
      ));
    }
    // Behind on prep as the date approaches.
    final c = e.countdown;
    if (e.isPreparing &&
        c != null &&
        c.inDays <= 7 &&
        !c.isNegative &&
        e.preparationProgress < 0.6 &&
        e._hasAnythingToPrepare) {
      warnings.add(EventInsight(
        'Behind on preparation',
        'Only ${e.preparationPercent}% ready with ${_daysLabel(c)} to go.',
        EventInsightLevel.warning,
      ));
    }

    // Wins — reinforce what's already locked in.
    if (e.preparationProgress >= 0.8 && e._hasAnythingToPrepare) {
      wins.add(const EventInsight(
        'Preparation nearly complete',
        'The checklist is almost fully done.',
        EventInsightLevel.win,
      ));
    }
    if (e.team.isNotEmpty && unconfirmed == 0) {
      wins.add(const EventInsight(
        'Team locked in',
        'Everyone assigned has confirmed.',
        EventInsightLevel.win,
      ));
    }
    if (e.budget.isNotEmpty && e.budget.every((b) => b.approved)) {
      wins.add(const EventInsight(
        'Budget approved',
        'Every budget line has sign-off.',
        EventInsightLevel.win,
      ));
    }

    final insights = [...blockers, ...warnings, ...wins];

    final String headline;
    if (blockers.isNotEmpty) {
      headline = 'Needs attention';
    } else if (score >= 80) {
      headline = 'On track';
    } else if (score >= 50) {
      headline = 'Coming together';
    } else {
      headline = 'Early days';
    }

    return EventReadiness(
      score: score,
      headline: headline,
      insights: insights,
    );
  }

  static String _plural(int n, String word) => n == 1 ? word : '${word}s';

  static String _daysLabel(Duration c) {
    if (c.inDays >= 1) return '${c.inDays} ${_plural(c.inDays, 'day')}';
    if (c.inHours >= 1) return '${c.inHours} ${_plural(c.inHours, 'hour')}';
    return 'hours';
  }
}

extension _EventPrepX on EventEntity {
  /// Is there anything to prepare at all? (Avoids "0% ready" noise on an event
  /// that has no checklist yet — that's covered by the "No task list" warning.)
  bool get _hasAnythingToPrepare =>
      milestones.isNotEmpty ||
      tasks.isNotEmpty ||
      inventory.isNotEmpty ||
      logistics.isNotEmpty;
}
