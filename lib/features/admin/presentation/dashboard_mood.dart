import 'package:drop/core/theme/app_colors.dart';
import 'package:flutter/painting.dart';

/// The operational **mood** of the dashboard — a short, human sentence that
/// replaces a static greeting subtitle so the hero reflects what is actually
/// happening right now ("2 tasks need your attention" · "Everything's running
/// smoothly" · "Quiet morning"). The dashboard should feel aware of its state,
/// not print the same line every load.
///
/// Pure + clock-injectable so it is unit-testable; derives entirely from counts
/// the dashboard already computes (no new reads, no business-logic change).
enum MoodTone { calm, attention, busy }

class DashboardMood {
  const DashboardMood(this.headline, this.tone);

  /// The contextual sentence shown under the greeting.
  final String headline;
  final MoodTone tone;

  /// Colour of the small "system pulse" dot beside the headline — meaningful,
  /// never decorative: a calm system reads a quiet light grey (all good), a
  /// board that needs attention picks up the warning accent.
  Color get pulseColor => switch (tone) {
        MoodTone.calm => AppColors.textSecondary,
        MoodTone.attention => AppColors.warning,
        MoodTone.busy => AppColors.warning,
      };

  /// True when the mood should draw the eye (headline reads white); a calm mood
  /// stays a relaxed light grey.
  bool get emphasised => tone != MoodTone.calm;
}

/// The part-of-day word for [hour] (0–23) — used for the calm/idle line.
String partOfDay(int hour) {
  if (hour < 12) return 'morning';
  if (hour < 17) return 'afternoon';
  if (hour < 21) return 'evening';
  return 'night';
}

String _plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

/// Compute the dashboard's mood from the live operational counts. [now] is
/// injectable for tests (defaults to the wall clock).
///
/// - **Calm** (nothing needs a decision): rewards the healthy state — running
///   work reads "running smoothly", a productive-but-idle board reads "all
///   caught up", a genuinely quiet board reads a time-aware "Quiet morning".
/// - **Attention** (something is waiting): a single dominant signal reads
///   specifically ("5 reviews waiting"); several at once read as one total
///   ("7 tasks need your attention").
/// - **Busy**: a heavy board escalates the tone (the pulse warms, the line can
///   carry the part of day).
DashboardMood dashboardMood({
  required int reviews,
  required int overdue,
  required int unassigned,
  required int rejected,
  required int running,
  required int completedToday,
  DateTime? now,
}) {
  final when = now ?? DateTime.now();
  final part = partOfDay(when.hour);
  final attention = overdue + reviews + unassigned + rejected;

  // ── Calm — reward a healthy operational state ──────────────────────────
  if (attention == 0) {
    if (running > 0) {
      return const DashboardMood('Everything’s running smoothly', MoodTone.calm);
    }
    if (completedToday > 0) {
      return const DashboardMood(
        'All caught up — nice work today',
        MoodTone.calm,
      );
    }
    final adj = (part == 'morning' || part == 'night') ? 'Quiet' : 'Calm';
    return DashboardMood('$adj $part', MoodTone.calm);
  }

  // ── Something needs attention ──────────────────────────────────────────
  final tone = attention >= 6 ? MoodTone.busy : MoodTone.attention;

  // One dominant category reads specifically; several read as a single total.
  final categories =
      [overdue, reviews, unassigned, rejected].where((c) => c > 0).length;
  if (categories == 1) {
    if (overdue > 0) {
      return DashboardMood('${_plural(overdue, 'task', 'tasks')} overdue', tone);
    }
    if (reviews > 0) {
      return DashboardMood(
        '${_plural(reviews, 'review', 'reviews')} waiting',
        tone,
      );
    }
    if (unassigned > 0) {
      return DashboardMood(
        '${_plural(unassigned, 'task', 'tasks')} unassigned',
        tone,
      );
    }
    return DashboardMood(
      '${_plural(rejected, 'task', 'tasks')} sent back',
      tone,
    );
  }

  final needs = attention == 1 ? 'task needs' : 'tasks need';
  final prefix = tone == MoodTone.busy ? 'Busy $part · ' : '';
  return DashboardMood('$prefix$attention $needs your attention', tone);
}
