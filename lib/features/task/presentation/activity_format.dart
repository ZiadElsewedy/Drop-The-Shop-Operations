import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';

/// Presentation helpers that map a task [ActivityEntry.status] string onto a
/// human label + dot colour, and format an event time. Shared by the Task
/// Details activity timeline and the admin recent-activity feed so the mapping
/// lives in exactly one place.

/// Human-readable title for a task activity entry (its post-transition status).
String activityTitle(String status) => switch (status) {
      'pending' => 'Task created',
      'assigned' => 'Assigned to employee',
      'started' => 'Started',
      'completed' => 'Completed',
      'waitingReview' => 'Submitted for review',
      'approved' => 'Approved',
      'rejected' => 'Rework requested',
      'cancelled' => 'Cancelled',
      'note' => 'Note',
      'noteWarning' => 'Warning',
      'noteIssue' => 'Issue',
      _ => status,
    };

/// Dot / accent colour for a task activity entry.
Color activityColor(String status) => switch (status) {
      'approved' => AppColors.success,
      'rejected' || 'noteIssue' => AppColors.error,
      'waitingReview' || 'noteWarning' => AppColors.warning,
      'started' || 'assigned' => AppColors.textPrimary,
      _ => AppColors.textTertiary,
    };

/// Glyph for a task activity entry — used by the richer timeline event cards.
IconData activityIcon(String status) => switch (status) {
      'pending' => Icons.add_task_rounded,
      'assigned' => Icons.person_add_alt_1_rounded,
      'started' => Icons.play_arrow_rounded,
      'completed' => Icons.check_rounded,
      'waitingReview' => Icons.hourglass_top_rounded,
      'approved' => Icons.verified_rounded,
      'rejected' => Icons.replay_rounded,
      'cancelled' => Icons.close_rounded,
      'note' => Icons.chat_bubble_outline_rounded,
      'noteWarning' => Icons.warning_amber_rounded,
      'noteIssue' => Icons.report_gmailerrorred_rounded,
      _ => Icons.circle_outlined,
    };

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Compact relative time ("Just now", "5m ago", "3h ago", "2d ago", "19 Jun").
String relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day} ${_months[dt.month - 1]}';
}
