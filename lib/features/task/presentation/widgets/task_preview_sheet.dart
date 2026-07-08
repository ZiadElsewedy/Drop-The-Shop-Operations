import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/pages/task_details_screen.dart';
import 'package:drop/features/task/presentation/widgets/task_feed_expansion.dart';
import 'package:drop/features/task/presentation/widgets/task_feed_row.dart';

/// The shared **task preview → optional full details** navigation pattern (DROP
/// Design System V2). Tapping a task anywhere on the dashboard opens a draggable
/// preview sheet — a read of the task plus its quick actions and a sticky footer
/// — so the admin can triage without ever leaving the dashboard (scroll + state
/// preserved). "Open full details" is a deliberate second step, not the default.
///
/// Extracted from the feed's private sheet so the activity feed, the filtered
/// task lists and the feed rows all present the same surface. Feature-level (it
/// needs `TaskCubit` for branch names + the quick actions) — the generic
/// pattern is documented in `docs/design/DESIGN_SYSTEM_V2.md`.

/// Push the full-screen [TaskDetailsScreen] with the app's standard slide/fade
/// transition, keeping the caller's screen on the stack (Back returns to it).
void openTaskDetails(
  BuildContext context,
  TaskEntity task,
  Map<String, UserEntity> directory,
) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, anim, sec) =>
          TaskDetailsScreen(task: task, directory: directory),
      transitionsBuilder: (ctx, anim, sec, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: const Interval(0, 0.6)),
          child: child,
        ),
      ),
    ),
  );
}

/// Open the draggable task preview sheet for [task]. [branchName] is resolved
/// from the live [TaskCubit] directory when omitted. "Open full details" pops the
/// sheet and pushes [TaskDetailsScreen] on the caller's navigator.
void showTaskPreviewSheet(
  BuildContext context, {
  required TaskEntity task,
  required Map<String, UserEntity> directory,
  String? branchName,
}) {
  final resolvedBranch =
      branchName ?? context.read<TaskCubit>().branchNames[task.branchId];
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      // Scrollable body + a PINNED action footer (stays visible as content
      // grows) — the triage surface's sticky-footer requirement.
      builder: (ctx, scroll) => Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.darkBorder,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                0,
                AppSpacing.pagePadding,
                AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TaskFeedRow(
                    task: task,
                    directory: directory,
                    branchName: resolvedBranch,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TaskFeedExpansion(
                    task: task,
                    directory: directory,
                    branchName: resolvedBranch,
                    onOpenDetails: () {},
                    showActions: false,
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              AppSpacing.md,
              AppSpacing.pagePadding,
              MediaQuery.of(ctx).padding.bottom + AppSpacing.md,
            ),
            decoration: const BoxDecoration(
              color: AppColors.darkSurface,
              border: Border(top: BorderSide(color: AppColors.darkBorder)),
            ),
            child: TaskFeedActions(
              task: task,
              onOpenDetails: () {
                Navigator.of(ctx).pop();
                openTaskDetails(context, task, directory);
              },
              onClose: () => Navigator.of(ctx).maybePop(),
            ),
          ),
        ],
      ),
    ),
  );
}
