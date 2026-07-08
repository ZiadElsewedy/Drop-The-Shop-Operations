import 'package:flutter/material.dart';
import 'package:drop/core/enums/event_status.dart';
import 'package:drop/core/enums/event_type.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/features/community/domain/event_readiness.dart';

/// Presentation mapping for the Community Hub — status/type → colour + icon,
/// and the small human formatters (countdown, date, money). Kept out of the
/// domain so the enums stay Flutter-free. **Strictly monochrome discipline:** the
/// only chromatic values are the semantic status colours (success / warning /
/// error), used sparingly; everything else is white / grey.
class EventFormat {
  EventFormat._();

  /// Currency prefix for budget + revenue figures (DROP operates in Egypt).
  static const String currency = 'E£';

  // ─── Status ───────────────────────────────────────────────────────────
  static Color statusColor(EventStatus s) => switch (s) {
        EventStatus.draft => AppColors.textTertiary,
        EventStatus.planning => AppColors.textSecondary,
        EventStatus.ready => AppColors.primary,
        EventStatus.live => AppColors.success,
        EventStatus.completed => AppColors.textSecondary,
        EventStatus.archived => AppColors.textTertiary,
        EventStatus.cancelled => AppColors.error,
      };

  static IconData statusIcon(EventStatus s) => switch (s) {
        EventStatus.draft => Icons.edit_note_rounded,
        EventStatus.planning => Icons.timeline_rounded,
        EventStatus.ready => Icons.check_circle_outline_rounded,
        EventStatus.live => Icons.sensors_rounded,
        EventStatus.completed => Icons.verified_rounded,
        EventStatus.archived => Icons.archive_outlined,
        EventStatus.cancelled => Icons.cancel_outlined,
      };

  // ─── Type ─────────────────────────────────────────────────────────────
  static IconData typeIcon(EventType t) => switch (t) {
        EventType.collectionLaunch => Icons.auto_awesome_rounded,
        EventType.brandCollab => Icons.handshake_outlined,
        EventType.popUp => Icons.storefront_outlined,
        EventType.communityGathering => Icons.groups_2_outlined,
        EventType.creatorMeet => Icons.record_voice_over_outlined,
        EventType.branchOpening => Icons.store_mall_directory_outlined,
        EventType.warehouseSale => Icons.local_offer_outlined,
        EventType.internalTraining => Icons.school_outlined,
        EventType.teamBuilding => Icons.diversity_3_outlined,
        EventType.seasonalCampaign => Icons.ac_unit_rounded,
        EventType.vipEvent => Icons.diamond_outlined,
        EventType.other => Icons.celebration_outlined,
      };

  // ─── Readiness insights ───────────────────────────────────────────────
  static Color insightColor(EventInsightLevel l) => switch (l) {
        EventInsightLevel.blocker => AppColors.error,
        EventInsightLevel.warning => AppColors.warning,
        EventInsightLevel.win => AppColors.success,
      };

  static IconData insightIcon(EventInsightLevel l) => switch (l) {
        EventInsightLevel.blocker => Icons.error_outline_rounded,
        EventInsightLevel.warning => Icons.warning_amber_rounded,
        EventInsightLevel.win => Icons.check_circle_outline_rounded,
      };

  /// A readiness score → a soft colour for the ring (never neon).
  static Color scoreColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.textSecondary;
  }

  // ─── Countdown ────────────────────────────────────────────────────────
  /// A compact countdown for the hero. Positive → time remaining; a live event
  /// or a just-started one reads as its status instead of a negative number.
  static String countdownLabel(Duration? d, {bool isLive = false}) {
    if (isLive) return 'Live now';
    if (d == null) return 'Date TBC';
    if (d.isNegative) return 'Started';
    if (d.inDays >= 1) {
      final days = d.inDays;
      final hours = d.inHours % 24;
      return hours > 0 ? '${days}d ${hours}h' : '${days}d';
    }
    if (d.inHours >= 1) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }
    if (d.inMinutes >= 1) return '${d.inMinutes}m';
    return 'Now';
  }

  /// A longer, spelled-out countdown for the expanded hero.
  static String countdownLong(Duration? d, {bool isLive = false}) {
    if (isLive) return 'Happening now';
    if (d == null) return 'Date to be confirmed';
    if (d.isNegative) return 'Already started';
    if (d.inDays >= 1) {
      return 'In ${d.inDays} ${_plural(d.inDays, 'day')}';
    }
    if (d.inHours >= 1) {
      return 'In ${d.inHours} ${_plural(d.inHours, 'hour')}';
    }
    if (d.inMinutes >= 1) {
      return 'In ${d.inMinutes} ${_plural(d.inMinutes, 'minute')}';
    }
    return 'Any moment now';
  }

  // ─── Dates ────────────────────────────────────────────────────────────
  static const _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun' //
  ];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
  ];

  /// "Sat 12 Jul · 7:00 PM" — the event's headline date/time.
  static String dateLabel(DateTime? dt, {bool withTime = true}) {
    if (dt == null) return 'Date to be confirmed';
    final wd = _weekdays[(dt.weekday - 1) % 7];
    final mo = _months[(dt.month - 1) % 12];
    final base = '$wd ${dt.day} $mo';
    if (!withTime) return base;
    return '$base · ${timeLabel(dt)}';
  }

  /// "12 Jul 2026" — a compact archive date.
  static String shortDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day} ${_months[(dt.month - 1) % 12]} ${dt.year}';
  }

  static String timeLabel(DateTime dt) {
    final h24 = dt.hour;
    final ampm = h24 < 12 ? 'AM' : 'PM';
    var h = h24 % 12;
    if (h == 0) h = 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m $ampm';
  }

  /// A relative "posted 3h ago" for announcements / audit lines.
  static String relative(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return shortDate(dt);
  }

  // ─── Money ────────────────────────────────────────────────────────────
  /// "E£ 12,500" — thousands-separated, currency-prefixed, no decimals unless
  /// they matter. Manual grouping so no `intl` dependency is required.
  static String money(num value, {bool withSymbol = true}) {
    final whole = value.round();
    final digits = whole.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    final sign = whole < 0 ? '-' : '';
    final grouped = '$sign${buf.toString()}';
    return withSymbol ? '$currency $grouped' : grouped;
  }

  /// A compact count like "1.2k" for large attendance / visitor figures.
  static String compact(num value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      final v = value / 1000;
      return '${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1)}k';
    }
    return value.round().toString();
  }

  static String _plural(int n, String word) => n == 1 ? word : '${word}s';
}
