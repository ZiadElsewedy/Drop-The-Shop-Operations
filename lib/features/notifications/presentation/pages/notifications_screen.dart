import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/core/extensions/context_extensions.dart';
import 'package:fbro/core/routes/route_names.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_dialog.dart';
import 'package:fbro/core/widgets/app_empty_state.dart';
import 'package:fbro/core/widgets/app_motion.dart';
import 'package:fbro/core/widgets/app_search_field.dart';
import 'package:fbro/core/widgets/list_skeleton.dart';
import 'package:fbro/features/notifications/domain/entities/notification_entity.dart';
import 'package:fbro/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:fbro/features/notifications/presentation/cubit/notification_state.dart';
import 'package:fbro/features/notifications/presentation/notification_format.dart';
import 'package:fbro/features/notifications/presentation/widgets/notification_tile.dart';

/// The in-app Notification Center (Phase 2) — every role's notifications with
/// search, type filters, an archived view, date grouping (pinned first), swipe
/// + menu actions (pin · archive · delete), and infinite pagination. Tapping a
/// tile marks it read and deep-links. Reached from the role chrome's bell.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _scroll = ScrollController();
  String _query = '';
  NotificationFilter _filter = NotificationFilter.all;
  bool _showArchived = false;
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

  /// A task notification opens the role's Tasks screen; a broadcast notification
  /// opens its detail for admin/manager.
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

  Future<void> _onAction(
      NotificationEntity n, NotificationTileAction action) async {
    final cubit = context.read<NotificationCubit>();
    switch (action) {
      case NotificationTileAction.pin:
        await cubit.setPinned(n.id, true);
      case NotificationTileAction.unpin:
        await cubit.setPinned(n.id, false);
      case NotificationTileAction.archive:
        await cubit.setArchived(n.id, true);
      case NotificationTileAction.unarchive:
        await cubit.setArchived(n.id, false);
      case NotificationTileAction.delete:
        final ok = await showConfirmDialog(
          context,
          title: 'Delete notification?',
          message: 'This permanently removes it from your inbox.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (ok) await cubit.delete(n.id);
    }
  }

  List<NotificationEntity> _visible(List<NotificationEntity> items) => items
      .where((n) => _showArchived ? n.isArchived : !n.isArchived)
      .where(_filter.matches)
      .where((n) => notificationMatchesQuery(n, _query))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        titleSpacing: AppSpacing.pagePadding,
        title: Text(_showArchived ? 'Archived' : 'Notifications',
            style: AppTypography.h3),
        actions: [
          IconButton(
            tooltip: _showArchived ? 'Show inbox' : 'Show archived',
            onPressed: () => setState(() => _showArchived = !_showArchived),
            icon: Icon(
              _showArchived
                  ? Icons.inbox_rounded
                  : Icons.archive_outlined,
              color: AppColors.textSecondary,
            ),
          ),
          if (!_showArchived)
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
    final visible = _visible(items);
    final sections = groupNotifications(visible);
    return Column(
      children: [
        _Toolbar(
          filter: _filter,
          onQuery: (q) => setState(() => _query = q),
          onFilter: (f) => setState(() => _filter = f),
        ),
        Expanded(
          child: sections.isEmpty
              ? _empty()
              : _list(sections),
        ),
      ],
    );
  }

  Widget _list(List<NotificationSection> sections) {
    final cubit = context.read<NotificationCubit>();
    var animIndex = 0;
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding, AppSpacing.sm, AppSpacing.pagePadding, AppSpacing.xxxl),
      children: [
        for (final section in sections) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, AppSpacing.md, 0, AppSpacing.sm),
            child: Text(section.title.toUpperCase(),
                style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary, letterSpacing: 0.6)),
          ),
          for (final n in section.items)
            EntranceFade(
              delay: staggerDelay(animIndex++),
              child: Dismissible(
                key: ValueKey(n.id),
                background: _swipeBg(
                    Alignment.centerLeft,
                    n.isArchived ? Icons.unarchive_rounded : Icons.archive_outlined,
                    n.isArchived ? 'Unarchive' : 'Archive'),
                secondaryBackground: _swipeBg(Alignment.centerRight,
                    Icons.delete_outline_rounded, 'Delete', destructive: true),
                confirmDismiss: (dir) async {
                  if (dir == DismissDirection.endToStart) {
                    await _onAction(n, NotificationTileAction.delete);
                  } else {
                    await _onAction(
                        n,
                        n.isArchived
                            ? NotificationTileAction.unarchive
                            : NotificationTileAction.archive);
                  }
                  // The stream re-emits without the item; keep it in the tree
                  // until then to avoid a dismissed-widget assertion.
                  return false;
                },
                child: NotificationTile(
                  notification: n,
                  onTap: () => _onTap(n),
                  onAction: (a) => _onAction(n, a),
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

  Widget _swipeBg(Alignment align, IconData icon, String label,
      {bool destructive = false}) {
    final color = destructive ? AppColors.error : AppColors.textSecondary;
    return Container(
      alignment: align,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(label, style: AppTypography.caption.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _empty() {
    if (_query.isNotEmpty || _filter != NotificationFilter.all) {
      return const AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches',
        message: 'Try a different search or filter.',
      );
    }
    return AppEmptyState(
      icon: _showArchived
          ? Icons.archive_outlined
          : Icons.notifications_none_rounded,
      title: _showArchived ? 'Nothing archived' : "You're all caught up",
      message: _showArchived
          ? 'Archived notifications are kept here.'
          : 'Task updates and announcements will show up here.',
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

/// Search field + horizontal type-filter chips.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.filter,
    required this.onQuery,
    required this.onFilter,
  });

  final NotificationFilter filter;
  final ValueChanged<String> onQuery;
  final ValueChanged<NotificationFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding,
              AppSpacing.sm, AppSpacing.pagePadding, AppSpacing.sm),
          child: AppSearchField(
            hint: 'Search notifications',
            onChanged: onQuery,
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
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
        ),
      ],
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
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 7),
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
