import 'package:flutter/material.dart';
import 'package:fbro/core/enums/notification_type.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/notifications/domain/entities/notification_entity.dart';

/// The per-tile action menu (Notification Center — Phase 2).
enum NotificationTileAction { pin, unpin, archive, unarchive, delete }

/// A single notification in the inbox — icon (tinted by type), title, body,
/// time-ago, an unread dot, a pin indicator, and a per-tile actions menu
/// (pin · archive · delete). Strictly monochrome; semantic colour only for the
/// rework / rejected / approved / emergency accents. Tapping marks it read +
/// deep-links.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    this.onTap,
    this.onAction,
  });

  final NotificationEntity notification;
  final VoidCallback? onTap;
  final void Function(NotificationTileAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final unread = notification.isUnread;
    final accent = _accentFor(notification.type);
    final pinned = notification.isPinned;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: unread ? AppColors.darkSurfaceElevated : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: pinned ? AppColors.primary.withAlpha(70) : AppColors.darkBorder),
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
                      if (pinned) ...[
                        Icon(Icons.push_pin_rounded,
                            size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                      ],
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
            if (onAction != null) _menu(),
          ],
        ),
      ),
    );
  }

  Widget _menu() {
    return PopupMenuButton<NotificationTileAction>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_horiz_rounded,
          size: 18, color: AppColors.textTertiary),
      color: AppColors.darkSurfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: onAction,
      itemBuilder: (context) => [
        if (notification.isPinned)
          _item(NotificationTileAction.unpin, Icons.push_pin_outlined, 'Unpin')
        else
          _item(NotificationTileAction.pin, Icons.push_pin_rounded, 'Pin'),
        if (notification.isArchived)
          _item(NotificationTileAction.unarchive, Icons.unarchive_rounded,
              'Unarchive')
        else
          _item(NotificationTileAction.archive, Icons.archive_outlined,
              'Archive'),
        _item(NotificationTileAction.delete, Icons.delete_outline_rounded,
            'Delete',
            destructive: true),
      ],
    );
  }

  PopupMenuItem<NotificationTileAction> _item(
    NotificationTileAction value,
    IconData icon,
    String label, {
    bool destructive = false,
  }) {
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    return PopupMenuItem<NotificationTileAction>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: AppTypography.body.copyWith(color: color)),
        ],
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
      case NotificationType.taskReminder:
        return Icons.alarm_rounded;
      case NotificationType.taskOverdue:
        return Icons.running_with_errors_rounded;
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
      case NotificationType.taskOverdue:
      case NotificationType.broadcastEmergency:
        return AppColors.error;
      case NotificationType.taskRework:
      case NotificationType.taskReminder:
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
