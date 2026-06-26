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
import 'package:fbro/core/widgets/app_snackbar.dart';
import 'package:fbro/core/widgets/list_skeleton.dart';
import 'package:fbro/features/communications/domain/entities/broadcast_entity.dart';
import 'package:fbro/features/communications/presentation/cubit/broadcast_cubit.dart';
import 'package:fbro/features/communications/presentation/cubit/broadcast_state.dart';
import 'package:fbro/features/communications/presentation/widgets/broadcast_card.dart';

/// The "···" overflow destinations — everything secondary lives here so the home
/// stays the feed + one primary action.
enum _NavMenu { scheduled, templates, toggleArchived }

/// Communications Center home (2026-06-23 lean redesign) — the broadcast **feed**
/// for the admin (all branches) or a manager (their branch + all-branches). The
/// feed is the only primary surface; **Scheduled, Templates, and Archived** live
/// behind the "···" overflow. A FAB opens Compose. Per-card actions: open ·
/// repeat · archive.
class CommunicationsScreen extends StatefulWidget {
  const CommunicationsScreen({super.key});

  @override
  State<CommunicationsScreen> createState() => _CommunicationsScreenState();
}

class _CommunicationsScreenState extends State<CommunicationsScreen> {
  bool _showArchived = false;

  /// Broadcast ids whose entrance animation has already played. Lets the feed
  /// animate each card **once** (on first appearance) and never again — so a live
  /// stream emit or a ListView.builder recycle on scroll doesn't replay it.
  final Set<String> _entered = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final user = context.currentUser;
    // Admin → the whole-org feed; manager → their branch + all-branches.
    final branchId = (user?.role.isAdmin ?? false) ? null : (user?.branchId ?? '');
    context.read<BroadcastCubit>().load(branchId: branchId);
  }

  Future<void> _refresh() async => _load();

  void _openDetail(BroadcastEntity b) =>
      context.push(RouteNames.communicationsDetail(b.id), extra: b);

  bool _matches(BroadcastEntity b) => _showArchived ? b.isArchived : b.isActive;

  void _onMenu(_NavMenu item) {
    switch (item) {
      case _NavMenu.scheduled:
        context.push(RouteNames.communicationsSchedules);
      case _NavMenu.templates:
        context.push(RouteNames.communicationsTemplates);
      case _NavMenu.toggleArchived:
        setState(() => _showArchived = !_showArchived);
    }
  }

  Future<void> _onAction(BroadcastEntity b, BroadcastCardAction action) async {
    final cubit = context.read<BroadcastCubit>();
    switch (action) {
      case BroadcastCardAction.open:
        _openDetail(b);
      case BroadcastCardAction.repeatNow:
        final user = context.currentUser;
        if (user == null) return;
        final ok = await showConfirmDialog(
          context,
          title: 'Repeat broadcast?',
          message: 'Send "${b.title}" again now to the same audience.',
          confirmLabel: 'Repeat',
        );
        if (!ok || !mounted) return;
        final count = await cubit.repeatNow(sender: user, source: b);
        if (count != null && mounted) {
          AppSnackbar.success(context,
              'Broadcast sent to $count ${count == 1 ? 'recipient' : 'recipients'}');
        }
      case BroadcastCardAction.archive:
        await cubit.setArchived(b.id, true);
      case BroadcastCardAction.unarchive:
        await cubit.setArchived(b.id, false);
      case BroadcastCardAction.delete:
        final ok = await showConfirmDialog(
          context,
          title: 'Delete broadcast?',
          message:
              '"${b.title}" will be permanently removed from the feed. This can\'t be undone.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (!ok || !mounted) return;
        await cubit.deleteBroadcast(b.id);
        if (mounted) AppSnackbar.success(context, 'Broadcast deleted');
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
        leading: _showArchived
            ? IconButton(
                tooltip: 'Back to feed',
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.textPrimary),
                onPressed: () => setState(() => _showArchived = false),
              )
            : null,
        title: Text(_showArchived ? 'Archived' : 'Communications Center',
            style: AppTypography.h3),
        actions: [
          PopupMenuButton<_NavMenu>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textSecondary),
            color: AppColors.darkSurfaceElevated,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            onSelected: _onMenu,
            itemBuilder: (context) => [
              _menuItem(_NavMenu.scheduled, Icons.schedule_rounded, 'Scheduled'),
              _menuItem(_NavMenu.templates, Icons.dashboard_customize_outlined,
                  'Templates'),
              _menuItem(
                  _NavMenu.toggleArchived,
                  _showArchived ? Icons.inbox_rounded : Icons.archive_outlined,
                  _showArchived ? 'Active feed' : 'Archived'),
            ],
          ),
        ],
      ),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(RouteNames.communicationsCompose),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.add_rounded),
              label: Text('New Broadcast',
                  style:
                      AppTypography.label.copyWith(color: AppColors.onPrimary)),
            ),
      body: BlocConsumer<BroadcastCubit, BroadcastState>(
        listener: (context, state) =>
            state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
        builder: (context, state) => state.maybeWhen(
          loading: () => const ListSkeleton(),
          loaded: (broadcasts, _) => _feed(broadcasts.where(_matches).toList()),
          error: (_) => _errorState(),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  PopupMenuItem<_NavMenu> _menuItem(_NavMenu value, IconData icon, String label) {
    return PopupMenuItem<_NavMenu>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textPrimary),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: AppTypography.body),
        ],
      ),
    );
  }

  Widget _feed(List<BroadcastEntity> broadcasts) {
    if (broadcasts.isEmpty) return _emptyState();
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        // Lazy: only on-screen cards are built (was a non-lazy ListView that
        // built the whole history up front).
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.md,
          AppSpacing.pagePadding,
          AppSpacing.xxxl * 2,
        ),
        itemCount: broadcasts.length,
        itemBuilder: (context, i) {
          final b = broadcasts[i];
          // Key by broadcast id (not index) so a stream update that reorders /
          // inserts reuses each card's element instead of shuffling state.
          final card = BroadcastCard(
            key: ValueKey(b.id),
            broadcast: b,
            onTap: () => _openDetail(b),
            onAction: (a) => _onAction(b, a),
          );
          // Play the entrance exactly once per broadcast. Already-seen cards
          // render bare, so neither a live emit nor a scroll-recycle replays it.
          if (_entered.contains(b.id)) return card;
          _entered.add(b.id);
          return EntranceFade(
            key: ValueKey('enter-${b.id}'),
            delay: staggerDelay(i),
            child: card,
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: AppEmptyState(
        icon: Icons.campaign_outlined,
        title: _showArchived ? 'Nothing archived' : 'No broadcasts yet',
        message: _showArchived
            ? 'Archived broadcasts are kept here, out of the main feed.'
            : 'Send your first announcement, reminder or alert with the New '
                'Broadcast button.',
      ),
    );
  }

  Widget _errorState() => AppEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load broadcasts',
        message: 'Check your connection and try again.',
        action: TextButton(
          onPressed: _load,
          child: Text('Retry',
              style: AppTypography.label.copyWith(color: AppColors.primary)),
        ),
      );
}
