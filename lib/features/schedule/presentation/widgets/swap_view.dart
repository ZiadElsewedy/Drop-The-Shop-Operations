import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/enums/schedule_day.dart';
import 'package:fbro/core/enums/schedule_shift.dart';
import 'package:fbro/core/enums/swap_status.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_snackbar.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/auth/presentation/widgets/app_button.dart';
import 'package:fbro/features/auth/presentation/widgets/app_text_field.dart';
import 'package:fbro/features/branch/domain/entities/branch_entity.dart';
import 'package:fbro/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:fbro/features/branch/presentation/cubit/branch_state.dart';
import 'package:fbro/features/schedule/domain/entities/shift_swap_entity.dart';
import 'package:fbro/features/schedule/domain/swap_eligibility.dart';
import 'package:fbro/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:fbro/features/schedule/presentation/cubit/shift_swap_state.dart';
import 'package:fbro/features/schedule/presentation/widgets/schedule_helpers.dart';

/// List of shift-swap requests with role-appropriate actions (Phase 7). Used on
/// the employee "Swaps" tab ([isManager] = false) and the manager "Swap
/// Requests" tab ([isManager] = true). Reads [ShiftSwapCubit] from context.
class SwapListView extends StatelessWidget {
  const SwapListView({
    super.key,
    required this.isManager,
    required this.currentUid,
    this.showBranch = false,
  });

  final bool isManager;
  final String currentUid;

  /// Show each swap's branch (admin views span multiple branches). Resolved via
  /// [BranchCubit]; the manager view leaves this off (single, known branch).
  final bool showBranch;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ShiftSwapCubit, ShiftSwapState>(
      listener: (context, state) =>
          state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
      builder: (context, state) => state.maybeWhen(
        loading: () => const Center(child: CircularProgressIndicator()),
        loaded: (swaps, busy) => _list(context, swaps, busy),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _list(BuildContext context, List<ShiftSwapEntity> swaps, bool busy) {
    return Column(
      children: [
        if (busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<ShiftSwapCubit>().refresh(),
            child: swaps.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: AppSpacing.xxxl * 2),
                      const Icon(Icons.swap_horiz_rounded,
                          size: 56, color: AppColors.textTertiary),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        isManager
                            ? 'No swap requests for your branch.'
                            : 'You have no swap requests.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding,
                        AppSpacing.lg, AppSpacing.pagePadding, AppSpacing.xxxl),
                    children: [
                      for (final s in swaps) _SwapCard(
                        swap: s,
                        isManager: isManager,
                        currentUid: currentUid,
                        showBranch: showBranch,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _SwapCard extends StatelessWidget {
  const _SwapCard({
    required this.swap,
    required this.isManager,
    required this.currentUid,
    this.showBranch = false,
  });

  final ShiftSwapEntity swap;
  final bool isManager;
  final String currentUid;
  final bool showBranch;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ShiftSwapCubit>();
    final requester = swap.requesterName ?? 'Employee';
    final target = swap.targetName ?? 'Coworker';
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('$requester → $target', style: AppTypography.label),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SwapStatusChip(status: swap.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text('${swap.day.label} · ${swap.shift.label}',
                  style: AppTypography.bodySmall),
              if (swap.createdAt != null) ...[
                const SizedBox(width: AppSpacing.sm),
                const Text('·',
                    style: TextStyle(color: AppColors.textTertiary)),
                const SizedBox(width: AppSpacing.sm),
                Text(_relativeTime(swap.createdAt!),
                    style: AppTypography.caption),
              ],
            ],
          ),
          if (showBranch) ...[
            const SizedBox(height: AppSpacing.xs),
            _BranchLine(branchId: swap.branchId),
          ],
          if ((swap.note ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(swap.note!, style: AppTypography.bodySmall),
          ],
          ..._actions(context, cubit),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context, ShiftSwapCubit cubit) {
    final buttons = <Widget>[];
    if (isManager) {
      // Manager acts once the coworker has approved.
      if (swap.status.isEmployeeApproved) {
        buttons.add(_SwapButton(
          label: 'Approve',
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.success,
          onPressed: () => cubit.managerApprove(swap),
        ));
        buttons.add(_SwapButton(
          label: 'Reject',
          icon: Icons.cancel_outlined,
          color: AppColors.error,
          onPressed: () => cubit.reject(swap),
        ));
      }
    } else {
      final isTarget = swap.targetId == currentUid;
      final isRequester = swap.requesterId == currentUid;
      if (isTarget && swap.status.isPending) {
        buttons.add(_SwapButton(
          label: 'Approve',
          icon: Icons.check_rounded,
          color: AppColors.success,
          onPressed: () => cubit.coworkerApprove(swap),
        ));
        buttons.add(_SwapButton(
          label: 'Decline',
          icon: Icons.close_rounded,
          color: AppColors.error,
          onPressed: () => cubit.reject(swap),
        ));
      } else if (isRequester && !swap.status.isResolved) {
        buttons.add(_SwapButton(
          label: 'Cancel',
          icon: Icons.undo_rounded,
          color: AppColors.warning,
          onPressed: () => cubit.reject(swap),
        ));
      }
    }
    if (buttons.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpacing.md),
      Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: buttons),
    ];
  }
}

/// Compact "submitted N ago" label for a swap's createdAt timestamp.
String _relativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${(d.inDays / 7).floor()}w ago';
}

/// Resolves a swap's `branchId` to a branch name via [BranchCubit] (admin queue
/// spans branches). Falls back to a short id if the branch list isn't loaded.
class _BranchLine extends StatelessWidget {
  const _BranchLine({required this.branchId});
  final String branchId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BranchCubit, BranchState>(
      builder: (context, state) {
        final branches = state.maybeWhen(
          loaded: (b, _) => b,
          orElse: () => const <BranchEntity>[],
        );
        String name = branchId.isEmpty ? 'Unassigned branch' : branchId;
        for (final b in branches) {
          if (b.id == branchId) {
            name = b.name;
            break;
          }
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.store_mall_directory_outlined,
                size: 13, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(name, style: AppTypography.caption),
          ],
        );
      },
    );
  }
}

class _SwapButton extends StatelessWidget {
  const _SwapButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color ?? AppColors.primary,
        backgroundColor: AppColors.darkSurfaceElevated,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        textStyle: AppTypography.caption,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _SwapStatusChip extends StatelessWidget {
  const _SwapStatusChip({required this.status});
  final SwapStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SwapStatus.pending => AppColors.textTertiary,
      SwapStatus.employeeApproved => AppColors.warning,
      SwapStatus.managerApproved => AppColors.success,
      SwapStatus.rejected => AppColors.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(status.label,
          style: AppTypography.caption.copyWith(color: color)),
    );
  }
}

/// Bottom sheet for an employee to request a swap on one of their slots: pick a
/// coworker (any other branch employee) + optional note, then send.
Future<void> showSwapRequestSheet({
  required BuildContext context,
  required ShiftSwapCubit cubit,
  required String branchId,
  required DateTime weekStart,
  required ScheduleDay day,
  required ScheduleShift shift,
  required UserEntity requester,
  required List<UserEntity> coworkers,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) => _SwapRequestSheet(
      cubit: cubit,
      branchId: branchId,
      weekStart: weekStart,
      day: day,
      shift: shift,
      requester: requester,
      coworkers: coworkers,
    ),
  );
}

class _SwapRequestSheet extends StatefulWidget {
  const _SwapRequestSheet({
    required this.cubit,
    required this.branchId,
    required this.weekStart,
    required this.day,
    required this.shift,
    required this.requester,
    required this.coworkers,
  });

  final ShiftSwapCubit cubit;
  final String branchId;
  final DateTime weekStart;
  final ScheduleDay day;
  final ScheduleShift shift;
  final UserEntity requester;
  final List<UserEntity> coworkers;

  @override
  State<_SwapRequestSheet> createState() => _SwapRequestSheetState();
}

class _SwapRequestSheetState extends State<_SwapRequestSheet> {
  final _note = TextEditingController();
  UserEntity? _target;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _send() {
    final target = _target;
    if (target == null) {
      AppSnackbar.error(context, 'Pick a coworker to swap with.');
      return;
    }
    // Immediate feedback (spec §2): can't swap a past/in-progress shift. The
    // cubit re-validates as the authoritative gate.
    if (!SwapEligibility.isRequestable(
        widget.weekStart, widget.day, widget.shift)) {
      AppSnackbar.error(context, SwapEligibility.pastShiftMessage);
      return;
    }
    final note = _note.text.trim();
    widget.cubit.requestSwap(
      branchId: widget.branchId,
      weekStart: widget.weekStart,
      day: widget.day,
      shift: widget.shift,
      requesterId: widget.requester.uid,
      requesterName: userDisplayName(widget.requester),
      targetId: target.uid,
      targetName: userDisplayName(target),
      note: note.isEmpty ? null : note,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final others =
        widget.coworkers.where((u) => u.uid != widget.requester.uid).toList();
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.pagePadding,
        right: AppSpacing.pagePadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request Swap', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            Text('${widget.day.label} · ${widget.shift.label}',
                style: AppTypography.bodySmall),
            const SizedBox(height: AppSpacing.lg),
            Text('Coworker to take this shift', style: AppTypography.labelSmall),
            const SizedBox(height: AppSpacing.sm),
            if (others.isEmpty)
              Text('No coworkers available in your branch.',
                  style: AppTypography.bodySmall)
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: others.length,
                  itemBuilder: (context, i) {
                    final u = others[i];
                    final selected = _target?.uid == u.uid;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textTertiary,
                      ),
                      title:
                          Text(userDisplayName(u), style: AppTypography.label),
                      subtitle: Text(u.email, style: AppTypography.caption),
                      onTap: () => setState(() => _target = u),
                    );
                  },
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _note,
              label: 'Note (optional)',
              prefixIcon: Icons.notes_rounded,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(label: 'Send Request', onPressed: _send),
          ],
        ),
      ),
    );
  }
}
