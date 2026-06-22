import 'package:flutter/material.dart';
import 'package:fbro/core/enums/broadcast_audience.dart';
import 'package:fbro/core/enums/broadcast_category.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/features/communications/domain/entities/broadcast_entity.dart';

/// Shared presentation formatting for the Communications Center — keeps the
/// label / icon / colour mapping (and the monochrome "colour only for status"
/// rule) in one place, out of the pure `core/enums` values.

/// Compact relative time ("just now", "5m", "3h", "2d") then an absolute date.
String broadcastTimeAgo(DateTime? dt) {
  if (dt == null) return 'just now';
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day} ${_month(dt.month)} ${dt.year}';
}

/// Longer, human date for the detail screen ("21 Jun 2026 • 4:59 PM").
String broadcastFullDate(DateTime? dt) {
  if (dt == null) return '—';
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour < 12 ? 'AM' : 'PM';
  return '${dt.day} ${_month(dt.month)} ${dt.year} • $h:$m $ampm';
}

/// The audience label for a feed/detail chip ("Everyone" / "Branch" / "Direct").
String audienceLabel(BroadcastEntity b) => switch (b.audience) {
      BroadcastAudience.allBranches => 'Everyone',
      BroadcastAudience.branch => 'Branch',
      BroadcastAudience.user => 'Direct',
    };

IconData audienceIcon(BroadcastAudience a) => switch (a) {
      BroadcastAudience.allBranches => Icons.public_rounded,
      BroadcastAudience.branch => Icons.store_mall_directory_outlined,
      BroadcastAudience.user => Icons.person_outline_rounded,
    };

IconData categoryIcon(BroadcastCategory c) => switch (c) {
      BroadcastCategory.announcement => Icons.campaign_outlined,
      BroadcastCategory.alert => Icons.warning_amber_rounded,
      BroadcastCategory.reminder => Icons.alarm_rounded,
      BroadcastCategory.emergency => Icons.error_outline_rounded,
    };

/// Status colour for a category — monochrome by default; only the urgent
/// categories carry a semantic colour (alert → warning, emergency → error).
Color categoryColor(BroadcastCategory c) => switch (c) {
      BroadcastCategory.alert => AppColors.warning,
      BroadcastCategory.emergency => AppColors.error,
      _ => AppColors.textSecondary,
    };

String _month(int m) => const [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ][(m - 1).clamp(0, 11)];
