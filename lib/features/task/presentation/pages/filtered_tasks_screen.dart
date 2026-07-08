import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/drop_empty_state.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/task_feed.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';
import 'package:drop/features/task/presentation/widgets/task_activity_card.dart';

/// A reusable **filtered task list** the dashboard's Needs-Attention tiles push
/// into (Overdue · Unassigned · Rejected · …). It renders the live task stream
/// through a [TaskFeedFilter] as clean [TaskActivityCard]s — the same preview →
/// full-details flow as the dashboard — pushed on the caller's navigator so
/// **Back returns to the dashboard exactly where it was** (scroll + state kept).
///
/// One small screen instead of a bespoke page per signal: pass a [title] and the
/// [filter] (a preset, or a status/branch/assignee narrowing) and it derives the
/// list from `applyFeed` (so its ordering + membership match the feed engine).
class FilteredTasksScreen extends StatelessWidget {
  const FilteredTasksScreen({
    super.key,
    required this.title,
    required this.filter,
    this.emptyMessage = 'Nothing needs attention here right now.',
  });

  final String title;
  final TaskFeedFilter filter;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: title,
      body: BlocBuilder<TaskCubit, TaskState>(
        builder: (context, state) {
          return state.maybeWhen(
            loaded: (tasks, busy, directory, isSubmitting, progress) {
              final branchNames = context.read<TaskCubit>().branchNames;
              final now = DateTime.now();
              final List<TaskEntity> list = applyFeed(
                tasks,
                filter,
                now,
                directory: directory,
                branchNames: branchNames,
              );
              if (list.isEmpty) {
                return DropEmptyState(
                  title: 'All clear',
                  message: emptyMessage,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding,
                  AppSpacing.md,
                  AppSpacing.pagePadding,
                  AppSpacing.xxxl,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) => Padding(
                  key: ValueKey('filtered:${list[i].id}'),
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: TaskActivityCard(
                    task: list[i],
                    directory: directory,
                    branchName: branchNames[list[i].branchId],
                  ),
                ),
              );
            },
            orElse: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
      ),
    );
  }
}
