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

/// The history view a broadcast falls into.
enum _HistoryView { active, archived, deleted }

/// Communications Center home (Phase 2) — the broadcast **history** for the
/// admin (all branches) or a manager (their branch + all-branches), with an
/// Active / Archived / Deleted filter and per-item actions (open · repeat ·
/// duplicate · archive · delete / restore). A FAB opens the Compose screen.
class CommunicationsScreen extends StatefulWidget {
  const CommunicationsScreen({super.key});

  @override
  State<CommunicationsScreen> createState() => _CommunicationsScreenState();
}

class _CommunicationsScreenState extends State<CommunicationsScreen> {
  _HistoryView _view = _HistoryView.active;

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

  bool _matches(BroadcastEntity b) => switch (_view) {
        _HistoryView.active => b.isActive,
        _HistoryView.archived => b.isArchived && !b.isDeleted,
        _HistoryView.deleted => b.isDeleted,
      };

  Future<void> _onAction(
      BroadcastEntity b, BroadcastCardAction action) async {
    final cubit = context.read<BroadcastCubit>();
    switch (action) {
      case BroadcastCardAction.open:
        _openDetail(b);
      case BroadcastCardAction.duplicate:
      case BroadcastCardAction.scheduleAgain:
        // Both open the composer prefilled; Schedule Again then uses the
        // composer's "Schedule" action to set a cadence.
        context.push(RouteNames.communicationsCompose, extra: b);
      case BroadcastCardAction.repeatNow:
        final user = context.currentUser;
        if (user == null) return;
        final ok = await showConfirmDialog(
          context,
          title: 'Repeat broadcast?',
          message:
              'Send "${b.title}" again now to the same audience.',
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
              'It will be hidden from the feed but kept in history (analytics '
              'preserved). You can restore it from the Deleted tab.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (ok) await cubit.setDeleted(b.id, true);
      case BroadcastCardAction.restore:
        await cubit.setDeleted(b.id, false);
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
        title: Text('Communications Center', style: AppTypography.h3),
        actions: [
          IconButton(
            tooltip: 'Scheduled',
            onPressed: () => context.push(RouteNames.communicationsSchedules),
            icon: const Icon(Icons.schedule_rounded,
                color: AppColors.textSecondary),
          ),
          IconButton(
            tooltip: 'Templates',
            onPressed: () => context.push(RouteNames.communicationsTemplates),
            icon: const Icon(Icons.dashboard_customize_outlined,
                color: AppColors.textSecondary),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RouteNames.communicationsCompose),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: Text('New Broadcast',
            style: AppTypography.label.copyWith(color: AppColors.onPrimary)),
      ),
      body: BlocConsumer<BroadcastCubit, BroadcastState>(
        listener: (context, state) =>
            state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
        builder: (context, state) => state.maybeWhen(
          loading: () => const ListSkeleton(),
          loaded: (broadcasts, _) => _body(broadcasts),
          error: (_) => _errorState(),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _body(List<BroadcastEntity> all) {
    final visible = all.where(_matches).toList();
    final activeN = all.where((b) => b.isActive).length;
    final archivedN = all.where((b) => b.isArchived && !b.isDeleted).length;
    final deletedN = all.where((b) => b.isDeleted).length;

    return Column(
      children: [
        _Segmented(
          view: _view,
          activeCount: activeN,
          archivedCount: archivedN,
          deletedCount: deletedN,
          onChanged: (v) => setState(() => _view = v),
        ),
        Expanded(child: _feed(visible)),
      ],
    );
  }

  Widget _feed(List<BroadcastEntity> broadcasts) {
    if (broadcasts.isEmpty) return _emptyState();
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.md,
          AppSpacing.pagePadding,
          AppSpacing.xxxl * 2,
        ),
        children: [
          for (var i = 0; i < broadcasts.length; i++)
            EntranceFade(
              delay: staggerDelay(i),
              child: BroadcastCard(
                broadcast: broadcasts[i],
                onTap: () => _openDetail(broadcasts[i]),
                onAction: (a) => _onAction(broadcasts[i], a),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final (title, message) = switch (_view) {
      _HistoryView.active => (
          'No broadcasts yet',
          'Send your first announcement, alert or reminder with the New '
              'Broadcast button.',
        ),
      _HistoryView.archived => (
          'Nothing archived',
          'Archived broadcasts are kept here, out of the main feed.',
        ),
      _HistoryView.deleted => (
          'Nothing deleted',
          'Deleted broadcasts appear here and can be restored.',
        ),
    };
    return RefreshIndicator(
      onRefresh: _refresh,
      child: AppEmptyState(
        icon: Icons.campaign_outlined,
        title: title,
        message: message,
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

/// The Active / Archived / Deleted segmented filter.
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.view,
    required this.activeCount,
    required this.archivedCount,
    required this.deletedCount,
    required this.onChanged,
  });

  final _HistoryView view;
  final int activeCount;
  final int archivedCount;
  final int deletedCount;
  final ValueChanged<_HistoryView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding, AppSpacing.sm, AppSpacing.pagePadding, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          children: [
            _seg('Active', activeCount, _HistoryView.active),
            _seg('Archived', archivedCount, _HistoryView.archived),
            _seg('Deleted', deletedCount, _HistoryView.deleted),
          ],
        ),
      ),
    );
  }

  Widget _seg(String label, int count, _HistoryView v) {
    final selected = view == v;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(v),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            count > 0 ? '$label · $count' : label,
            textAlign: TextAlign.center,
            style: AppTypography.label.copyWith(
              color: selected ? AppColors.onPrimary : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
