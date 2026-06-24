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
import 'package:fbro/features/notifications/presentation/notification_format.dart';
import 'package:fbro/features/notifications/presentation/widgets/notification_tile.dart';

/// The in-app Notification Center — every role's action inbox. Deliberately lean
/// (2026-06-23 simplification): an **All / Unread** filter, **Needs action**
/// notifications grouped above **Earlier**, tap to open (marks read + deep-links),
/// swipe to delete, and mark-all-read. No search / type filters / pin / archive
/// surface — those were power-user clutter for a small ops team.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _scroll = ScrollController();
  NotificationFilter _filter = NotificationFilter.all;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.currentUser?.uid;
      if (uid != null) context.read<NotificationCubit>().load(uid);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    final cubit = context.read<NotificationCubit>();
    if (!cubit.hasMore) return;
    setState(() => _loadingMore = true);
    await cubit.loadMore();
    if (mounted) setState(() => _loadingMore = false);
  }

  void _onTap(NotificationEntity n) {
    final cubit = context.read<NotificationCubit>();
    if (n.isUnread) cubit.markRead(n.id);
    _deepLink(n);
  }

  /// A task notification opens the **exact task**; a broadcast notification opens
  /// its detail for admin/manager (the body is the message for employees).
  void _deepLink(NotificationEntity n) {
    final role = context.currentRole;
    switch (n.route) {
      case 'task_details':
        final taskId = n.taskId;
        if (taskId != null && taskId.isNotEmpty) {
          context.push(RouteNames.taskDetail(taskId));
        } else if (role != null) {
          context.push(RouteNames.tasksForRole(role));
        }
      case 'broadcast_detail':
        final id = n.broadcastId;
        if (id != null &&
            id.isNotEmpty &&
            (role?.isAdmin == true || role?.isManager == true)) {
          context.push(RouteNames.communicationsDetail(id));
        }
    }
  }

  /// Non-archived notifications passing the active filter. Archived notifications
  /// stay hidden (archive remains in the data layer, not the UI).
  List<NotificationEntity> _visible(List<NotificationEntity> items) => items
      .where((n) => !n.isArchived)
      .where(_filter.matches)
      .toList();

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
          loaded: (items) => _content(items),
          error: (_) => _errorState(),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _content(List<NotificationEntity> items) {
    final sections = groupByPriority(_visible(items));
    return Column(
      children: [
        _FilterBar(
          filter: _filter,
          onFilter: (f) => setState(() => _filter = f),
        ),
        Expanded(child: sections.isEmpty ? _empty() : _list(sections)),
      ],
    );
  }

  Widget _list(List<NotificationSection> sections) {
    final cubit = context.read<NotificationCubit>();
    var animIndex = 0;
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding, AppSpacing.sm,
          AppSpacing.pagePadding, AppSpacing.xxxl),
      children: [
        for (final section in sections) ...[
          Padding(
            padding:
                const EdgeInsets.fromLTRB(2, AppSpacing.md, 0, AppSpacing.sm),
            child: Text(section.title.toUpperCase(),
                style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary, letterSpacing: 0.6)),
          ),
          for (final n in section.items)
            EntranceFade(
              delay: staggerDelay(animIndex++),
              child: Dismissible(
                key: ValueKey(n.id),
                direction: DismissDirection.endToStart,
                background: _deleteBg(),
                confirmDismiss: (_) async {
                  await cubit.delete(n.id);
                  // The stream re-emits without the item; keep it in the tree
                  // until then to avoid a dismissed-widget assertion.
                  return false;
                },
                child: NotificationTile(
                  notification: n,
                  onTap: () => _onTap(n),
                ),
              ),
            ),
        ],
        if (cubit.hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: _loadingMore
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : TextButton(
                      onPressed: _loadMore,
                      child: Text('Load more',
                          style: AppTypography.label
                              .copyWith(color: AppColors.primary)),
                    ),
            ),
          ),
      ],
    );
  }

  Widget _deleteBg() {
    return Container(
      alignment: Alignment.centerRight,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(24),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
          const SizedBox(width: 6),
          Text('Delete',
              style: AppTypography.caption.copyWith(color: AppColors.error)),
        ],
      ),
    );
  }

  Widget _empty() {
    if (_filter == NotificationFilter.unread) {
      return const AppEmptyState(
        icon: Icons.done_all_rounded,
        title: 'No unread notifications',
        message: "You're all caught up.",
      );
    }
    return const AppEmptyState(
      icon: Icons.notifications_none_rounded,
      title: "You're all caught up",
      message: 'Task updates and announcements will show up here.',
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

/// All / Unread filter chips.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.onFilter});

  final NotificationFilter filter;
  final ValueChanged<NotificationFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding, AppSpacing.sm, AppSpacing.pagePadding, 0),
      child: Row(
        children: [
          for (final f in NotificationFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _Chip(
                label: f.label,
                selected: filter == f,
                onTap: () => onFilter(f),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.darkBorder),
        ),
        child: Text(label,
            style: AppTypography.caption.copyWith(
              color: selected ? AppColors.onPrimary : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            )),
      ),
    );
  }
}
