import 'package:flutter/material.dart';
import 'package:drop/core/enums/notification_type.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_glass_card.dart';
import 'package:drop/core/widgets/status_badge.dart';
import 'package:drop/features/notifications/domain/entities/notification_entity.dart';
import 'package:drop/features/notifications/presentation/notification_format.dart';

/// A single notification in the inbox — icon (tinted by type), title, body,
/// time-ago, and an unread dot. Strictly monochrome; semantic colour only for
/// the rework / rejected / approved / emergency / overdue accents. Tapping marks
/// it read + deep-links. Deliberately display-only (2026-06-23 simplification):
/// no per-tile menu / pin — the inbox uses swipe-to-delete instead.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    this.onTap,
  });

  final NotificationEntity notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unread = notification.isUnread;
    final accent = _accentFor(notification.type);
    final (catLabel, catColor) = _category(notification.type);
    // A critical notification (overdue · emergency) gets a stronger unread
    // indicator — the dot picks up its semantic accent and grows a touch. Subtle,
    // still monochrome elsewhere.
    final critical =
        notificationPriority(notification.type) == NotificationPriority.critical;
    final dotColor = critical ? accent : AppColors.primary;
    final dotSize = critical ? 10.0 : 8.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppGlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        elevated: unread,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon bubble — tinted by the notification's semantic accent.
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withAlpha(28),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withAlpha(60)),
              ),
              child: Icon(_iconFor(notification.type), size: 20, color: accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: AppTypography.label.copyWith(
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Unread dot — fades out when the notification is read
                      // (§5c motion); keeps its slot so the title never reflows.
                      Padding(
                        padding: const EdgeInsets.only(left: 6, top: 4),
                        child: AnimatedOpacity(
                          opacity: unread ? 1 : 0,
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOut,
                          child: Container(
                            width: dotSize,
                            height: dotSize,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: AppTypography.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Category badge + relative time.
                  Row(
                    children: [
                      StatusBadge(label: catLabel, color: catColor),
                      const SizedBox(width: AppSpacing.sm),
                      Text(_timeAgo(notification.createdAt),
                          style: AppTypography.caption),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The notification's category badge — Task · Review · Reminder · Broadcast.
  /// Monochrome for the neutral kinds; a semantic tint only where it carries
  /// meaning (a review outcome, a reminder, an emergency).
  (String, Color) _category(NotificationType type) {
    switch (type) {
      case NotificationType.taskAssigned:
        return ('Task', AppColors.textSecondary);
      case NotificationType.taskSubmitted:
      case NotificationType.taskApproved:
      case NotificationType.taskRejected:
      case NotificationType.taskRework:
        return ('Review', _accentFor(type));
      case NotificationType.taskReminder:
      case NotificationType.taskOverdue:
      case NotificationType.broadcastReminder:
        return ('Reminder', AppColors.warning);
      case NotificationType.broadcastEmergency:
        return ('Broadcast', AppColors.error);
      case NotificationType.broadcastAnnouncement:
        return ('Broadcast', AppColors.textSecondary);
      case NotificationType.swapRequested:
      case NotificationType.swapAccepted:
      case NotificationType.swapApproved:
      case NotificationType.swapRejected:
        return ('Schedule', _accentFor(type));
    }
  }

  IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.taskAssigned:
        return Icons.assignment_outlined;
      case NotificationType.taskRework:
        return Icons.replay_rounded;
      case NotificationType.taskSubmitted:
        return Icons.upload_file_outlined;
      case NotificationType.taskApproved:
        return Icons.check_circle_outline_rounded;
      case NotificationType.taskRejected:
        return Icons.cancel_outlined;
      case NotificationType.taskReminder:
        return Icons.alarm_rounded;
      case NotificationType.taskOverdue:
        return Icons.running_with_errors_rounded;
      case NotificationType.broadcastEmergency:
        return Icons.warning_amber_rounded;
      case NotificationType.broadcastReminder:
        return Icons.alarm_outlined;
      case NotificationType.broadcastAnnouncement:
        return Icons.campaign_outlined;
      case NotificationType.swapRequested:
      case NotificationType.swapAccepted:
        return Icons.swap_horiz_rounded;
      case NotificationType.swapApproved:
        return Icons.check_circle_outline_rounded;
      case NotificationType.swapRejected:
        return Icons.cancel_outlined;
    }
  }

  Color _accentFor(NotificationType type) {
    switch (type) {
      case NotificationType.taskApproved:
      case NotificationType.swapApproved:
        return AppColors.success;
      case NotificationType.taskRejected:
      case NotificationType.taskOverdue:
      case NotificationType.broadcastEmergency:
      case NotificationType.swapRejected:
        return AppColors.error;
      case NotificationType.taskRework:
      case NotificationType.taskReminder:
      case NotificationType.swapAccepted:
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  static String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${time.day} ${months[time.month - 1]}';
  }
}
