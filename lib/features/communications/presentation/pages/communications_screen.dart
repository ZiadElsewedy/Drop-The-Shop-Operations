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
import 'package:fbro/core/widgets/app_snackbar.dart';
import 'package:fbro/core/widgets/list_skeleton.dart';
import 'package:fbro/features/communications/domain/entities/broadcast_entity.dart';
import 'package:fbro/features/communications/presentation/cubit/broadcast_cubit.dart';
import 'package:fbro/features/communications/presentation/cubit/broadcast_state.dart';
import 'package:fbro/features/communications/presentation/widgets/broadcast_card.dart';

/// Communications Center home (Phase 3) — the recent-broadcasts feed for the
/// admin (all branches) or a manager (their branch + all-branches). A FAB opens
/// the Compose screen. Reached from the role chrome's Communications action
/// (admin + manager only; the router blocks employees).
class CommunicationsScreen extends StatefulWidget {
  const CommunicationsScreen({super.key});

  @override
  State<CommunicationsScreen> createState() => _CommunicationsScreenState();
}

class _CommunicationsScreenState extends State<CommunicationsScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        titleSpacing: AppSpacing.pagePadding,
        title: Text('Communications Center', style: AppTypography.h3),
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
          loaded: (broadcasts, _) => _feed(broadcasts),
          error: (_) => _errorState(),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _feed(List<BroadcastEntity> broadcasts) {
    if (broadcasts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: const AppEmptyState(
          icon: Icons.campaign_outlined,
          title: 'No broadcasts yet',
          message:
              'Send your first announcement, alert or reminder with the New '
              'Broadcast button.',
        ),
      );
    }
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
              ),
            ),
        ],
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
