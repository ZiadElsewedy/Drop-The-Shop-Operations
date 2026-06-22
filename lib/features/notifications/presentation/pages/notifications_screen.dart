import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/core/extensions/context_extensions.dart';
import 'package:fbro/core/routes/route_names.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_empty_state.dart';
import 'package:fbro/core/widgets/app_motion.dart';
import 'package:fbro/core/widgets/list_skeleton.dart';
import 'package:fbro/features/notifications/domain/entities/notification_entity.dart';
import 'package:fbro/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:fbro/features/notifications/presentation/cubit/notification_state.dart';
import 'package:fbro/features/notifications/presentation/widgets/notification_tile.dart';

/// The in-app notification inbox (Notification System Phase 1) — every role's
/// notifications, newest first, with an unread emphasis + "Mark all read". Tap a
/// tile to mark it read and deep-link to the related task / broadcast. Reached
/// from the role chrome's notification bell.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.currentUser?.uid;
      if (uid != null) context.read<NotificationCubit>().load(uid);
    });
  }

  void _onTap(NotificationEntity n) {
    final cubit = context.read<NotificationCubit>();
    if (n.isUnread) cubit.markRead(n.id);
    _deepLink(n);
  }

  /// Phase 1 deep-link: a task notification opens the role's Tasks screen (where
  /// the task is visible); a broadcast notification opens its detail for
  /// admin/manager (employees already see the content inline on the tile).
  void _deepLink(NotificationEntity n) {
    final role = context.currentRole;
    switch (n.route) {
      case 'task_details':
        if (role != null) context.push(RouteNames.tasksForRole(role));
      case 'broadcast_detail':
        final id = n.broadcastId;
        if (id != null &&
            id.isNotEmpty &&
            (role?.isAdmin == true || role?.isManager == true)) {
          context.push(RouteNames.communicationsDetail(id));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        titleSpacing: AppSpacing.pagePadding,
        title: Text('Notifications', style: AppTypography.h3),
        actions: [
          BlocBuilder<NotificationCubit, NotificationState>(
            builder: (context, state) {
              final hasUnread =
                  context.read<NotificationCubit>().unreadCount > 0;
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton(
                onPressed: () =>
                    context.read<NotificationCubit>().markAllRead(),
                child: Text('Mark all read',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.primary)),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationCubit, NotificationState>(
        builder: (context, state) => state.maybeWhen(
          loading: () => const ListSkeleton(),
          loaded: (items) => _feed(items),
          error: (_) => _errorState(),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _feed(List<NotificationEntity> items) {
    if (items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.notifications_none_rounded,
        title: "You're all caught up",
        message: 'Task updates and announcements will show up here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.md,
        AppSpacing.pagePadding,
        AppSpacing.xxxl,
      ),
      children: [
        for (var i = 0; i < items.length; i++)
          EntranceFade(
            delay: staggerDelay(i),
            child: NotificationTile(
              notification: items[i],
              onTap: () => _onTap(items[i]),
            ),
          ),
      ],
    );
  }

  Widget _errorState() => AppEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load notifications',
        message: 'Check your connection and try again.',
        action: TextButton(
          onPressed: () {
            final uid = context.currentUser?.uid;
            if (uid != null) context.read<NotificationCubit>().load(uid);
          },
          child: Text('Retry',
              style: AppTypography.label.copyWith(color: AppColors.primary)),
        ),
      );
}
