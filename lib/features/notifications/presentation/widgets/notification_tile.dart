import 'package:flutter/material.dart';
import 'package:fbro/core/enums/notification_type.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/notifications/domain/entities/notification_entity.dart';

/// A single notification in the inbox — icon (tinted by type), title, body,
/// time-ago, and an unread dot. Strictly monochrome; semantic colour only for
/// the rework / rejected / approved / emergency accents (matching the task
/// badges). Tapping marks it read + deep-links.
class NotificationTile extends StatelessWidget {
  const NotificationTile({super.key, required this.notification, this.onTap});

  final NotificationEntity notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unread = notification.isUnread;
    final accent = _accentFor(notification.type);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: unread ? AppColors.darkSurfaceElevated : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      if (unread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6, top: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
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
                  const SizedBox(height: 6),
                  Text(_timeAgo(notification.createdAt),
                      style: AppTypography.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
      case NotificationType.broadcastEmergency:
        return Icons.warning_amber_rounded;
      case NotificationType.broadcastAlert:
        return Icons.notification_important_outlined;
      case NotificationType.broadcastReminder:
        return Icons.alarm_outlined;
      case NotificationType.broadcastAnnouncement:
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _accentFor(NotificationType type) {
    switch (type) {
      case NotificationType.taskApproved:
        return AppColors.success;
      case NotificationType.taskRejected:
      case NotificationType.broadcastEmergency:
        return AppColors.error;
      case NotificationType.taskRework:
      case NotificationType.broadcastAlert:
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
