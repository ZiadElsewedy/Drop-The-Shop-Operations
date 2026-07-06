import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';

/// Schedule Health (Schedule 5.0) — a pure, week-level wellbeing read of the
/// roster. It looks at each person's **weekly pattern** (not individual
/// shifts): grouped runs of the same shift with a day off before switching
/// (M·M·M·off·N·N·N) keep sleep cycles stable; frequent morning ↔ night
/// flips, night → next-morning turnarounds and 6–7-day runs wear people down.
///
/// This is **advice, never enforcement** — findings are recommendations for
/// the manager's judgment and can never block an edit or a publish (the same
/// facts-not-quotas ruling the insight strip follows).
enum HealthFindingKind { shortRest, alternation, longStreak, unevenLoad }

/// One recommendation surfaced by the Schedule Health card. Person-level
/// findings carry the [uid]; team-level findings (workload spread) don't.
class HealthFinding {
  const HealthFinding({
    required this.kind,
    required this.title,
    required this.recommendation,
    this.uid,
  });

  final HealthFindingKind kind;
  final String? uid;

  /// What was observed — e.g. `Ahmed M. flips morning ↔ night 3× this week`.
  final String title;

  /// What to do about it — one actionable sentence.
  final String recommendation;
}

/// The week's overall health read: a 0–100 [score], its label, and the
/// per-person / team [findings] that explain it.
class ScheduleHealth {
  const ScheduleHealth({required this.score, required this.findings});

  final int score;
  final List<HealthFinding> findings;

  bool get isHealthy => findings.isEmpty;

  String get label => score >= 85
      ? 'Healthy'
      : score >= 60
          ? 'Fair'
          : 'Strained';
}

/// Analyzes the week in one pass over `members × 7 days` (trivially cheap for
/// a branch team) — call it once per build alongside `computeScheduleInsights`.
///
/// [nameOf] renders a person's display name (the view passes its `shortName`
/// helper so health text matches the grid chips). [previousSaturdayNight] —
/// last week's Saturday-night crew — lets the Sunday-morning turnaround count
/// as a short rest too.
ScheduleHealth computeScheduleHealth(
  WeeklyScheduleEntity schedule,
  List<UserEntity> members, {
  String Function(UserEntity user)? nameOf,
  Set<String> previousSaturdayNight = const {},
}) {
  String name(UserEntity u) =>
      nameOf?.call(u) ?? (u.displayName?.trim().isNotEmpty == true
          ? u.displayName!.trim()
          : u.email);

  final findings = <HealthFinding>[];
  var score = 100;
  final shiftCounts = <UserEntity, int>{};

  for (final member in members) {
    // The person's week as a day-by-day pattern. `null` = off;
    // a double-booked day is excluded from pattern analysis (the roster
    // conflict is already flagged red by the insight strip).
    final week = <ScheduleShift?>[
      for (final day in ScheduleDay.values)
        switch (schedule.shiftsFor(member.uid, day)) {
          [] => null,
          [final only] => only,
          _ => null, // both shifts — double-booking, handled elsewhere
        },
    ];
    var workedDays = 0;
    for (final day in ScheduleDay.values) {
      if (schedule.shiftsFor(member.uid, day).isNotEmpty) workedDays++;
    }
    if (workedDays > 0) shiftCounts[member] = workedDays;

    var shortRests = 0;
    var alternations = 0;
    // Last week's Saturday night → this Sunday morning (weekend nights end
    // 00:30, mornings start 08:30 — the tightest turnaround there is).
    if (previousSaturdayNight.contains(member.uid) &&
        week.first == ScheduleShift.morning) {
      shortRests++;
    }
    for (var d = 1; d < week.length; d++) {
      final prev = week[d - 1];
      final curr = week[d];
      if (prev == null || curr == null || prev == curr) continue;
      if (prev == ScheduleShift.night && curr == ScheduleShift.morning) {
        // Night ends 23:00 (00:30 weekends), next morning starts 08:30 —
        // only ~8–9.5h to commute, sleep and return.
        shortRests++;
      } else {
        // Morning → night on adjacent days is a soft flip (24h apart) —
        // fine once, a sleep-cycle churn when repeated.
        alternations++;
      }
    }

    if (shortRests > 0) {
      score -= 10 * shortRests;
      findings.add(HealthFinding(
        kind: HealthFindingKind.shortRest,
        uid: member.uid,
        title: shortRests == 1
            ? '${name(member)} opens the morning right after a night shift'
            : '${name(member)} opens the morning right after a night shift '
                '$shortRests×',
        recommendation:
            'Leave a day off (or keep them on nights) between a night shift '
            'and their next morning.',
      ));
    }
    if (shortRests + alternations >= 2) {
      score -= 6;
      findings.add(HealthFinding(
        kind: HealthFindingKind.alternation,
        uid: member.uid,
        title: '${name(member)} flips between morning and night '
            '${shortRests + alternations}× this week',
        recommendation:
            'Group their morning shifts together, then their night shifts — '
            'a day off between the two runs keeps their sleep steady.',
      ));
    }

    // Longest run of consecutive worked days (any shift, doubles included).
    var run = 0;
    var longestRun = 0;
    for (final day in ScheduleDay.values) {
      if (schedule.shiftsFor(member.uid, day).isNotEmpty) {
        run++;
        if (run > longestRun) longestRun = run;
      } else {
        run = 0;
      }
    }
    if (longestRun >= 6) {
      // A full 7-day week with no day off is a bigger deal than a 6-day run —
      // on its own it should already read "Fair", not "Healthy".
      score -= longestRun >= 7 ? 16 : 8;
      findings.add(HealthFinding(
        kind: HealthFindingKind.longStreak,
        uid: member.uid,
        title: '${name(member)} works $longestRun days in a row',
        recommendation: 'Add a day off mid-week to break the run.',
      ));
    }

    // Double-booked days quietly weigh on the score (the insight strip
    // already names them, so no duplicate finding here).
    for (final day in ScheduleDay.values) {
      if (schedule.shiftsFor(member.uid, day).length > 1) score -= 8;
    }
  }

  // Team-level: a big spread between the heaviest and lightest scheduled
  // person. A fact for judgment (part-timers exist), so caution not fault.
  if (shiftCounts.length >= 2) {
    UserEntity? heaviest;
    UserEntity? lightest;
    for (final entry in shiftCounts.entries) {
      if (heaviest == null || entry.value > shiftCounts[heaviest]!) {
        heaviest = entry.key;
      }
      if (lightest == null || entry.value < shiftCounts[lightest]!) {
        lightest = entry.key;
      }
    }
    final spread = shiftCounts[heaviest]! - shiftCounts[lightest]!;
    if (spread >= 4) {
      score -= 5;
      findings.add(HealthFinding(
        kind: HealthFindingKind.unevenLoad,
        title: 'Workload is uneven: ${name(heaviest!)} '
            '${shiftCounts[heaviest]} days · ${name(lightest!)} '
            '${shiftCounts[lightest]}',
        recommendation:
            'If both are full-time, shift a day or two toward the lighter '
            'side of the roster.',
      ));
    }
  }

  // Most pressing first: short rest > flips > long runs > balance.
  findings.sort((a, b) => a.kind.index.compareTo(b.kind.index));
  return ScheduleHealth(score: score.clamp(0, 100), findings: findings);
}
