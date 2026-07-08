import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/core/widgets/live_list_item.dart';
import 'package:drop/features/task/domain/active_window.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';
import 'package:drop/features/task/presentation/widgets/task_activity_card.dart';

/// **RecentActivityFeed** — the dashboard's "what's happening" layer (DROP Design
/// System V2). The calm, vertical replacement for the dense/filtered task feed on
/// the home screen: the most recently-touched active tasks rendered as clean
/// [TaskActivityCard]s, newest first, capped at [limit]. No filter chips, no
/// group headers, no horizontal scanning — "See all" (on the section header)
/// takes the admin to the full Tasks page for anything deeper.
///
/// Lives over the app-wide [TaskCubit] stream (zero new reads) and stays live:
/// an emit re-renders the capped list. Sits inside a scrolling page, so it never
/// scrolls itself and always renders a bounded number of rows (scalable).
class RecentActivityFeed extends StatelessWidget {
  const RecentActivityFeed({
    super.key,
    this.limit = 6,
    this.branchLocked = false,
    this.branchId,
  });

  /// Max cards shown — the rest live behind "See all".
  final int limit;

  /// Manager mode — pin to [branchId].
  final bool branchLocked;
  final String? branchId;

  static int _touch(TaskEntity t) =>
      (t.updatedAt ?? t.createdAt)?.millisecondsSinceEpoch ?? 0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskCubit, TaskState>(
      builder: (context, state) {
        return state.maybeWhen(
          loaded: (tasks, busy, directory, isSubmitting, progress) {
            final branchNames = context.read<TaskCubit>().branchNames;
            final now = DateTime.now();
            final active = <TaskEntity>[
              for (final t in tasks)
                if (isTaskInActiveWindow(t, now) &&
                    (!branchLocked || t.branchId == branchId))
                  t,
            ]..sort((a, b) => _touch(b).compareTo(_touch(a)));
            final shown = active.take(limit).toList();

            if (shown.isEmpty) return const _AllClear();
            final reduceMotion = MediaQuery.of(context).disableAnimations;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, t) in shown.indexed)
                  Padding(
                    key: ValueKey('activity:${t.id}'),
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    // Each row enters once (fade + rise) and never replays on a
                    // stream emit — keyed element reuse means only a genuinely
                    // new task mounts + animates in, so a live insert slides in
                    // naturally while the settled rows stay put. Staggered on the
                    // first load; a fresh arrival (newest-first ⇒ index 0) plays
                    // immediately.
                    child: reduceMotion
                        ? TaskActivityCard(
                            task: t,
                            directory: directory,
                            branchName: branchNames[t.branchId],
                          )
                        : LiveListItem(
                            entranceDelay: staggerDelay(i),
                            highlightRadius: 20,
                            child: TaskActivityCard(
                              task: t,
                              directory: directory,
                              branchName: branchNames[t.branchId],
                            ),
                          ),
                  ),
              ],
            );
          },
          orElse: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
      },
    );
  }
}

/// A deliberately compact "nothing active" state — a full-bleed empty illustration
/// would over-dramatise a healthy queue and (inside an unbounded list) risk an
/// infinite-height layout.
class _AllClear extends StatelessWidget {
  const _AllClear();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 32,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'All clear',
            style: AppTypography.label.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text('No active tasks right now.', style: AppTypography.caption),
        ],
      ),
    );
  }
}
