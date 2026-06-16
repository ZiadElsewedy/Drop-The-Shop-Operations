import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fbro/core/enums/task_status.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_snackbar.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fbro/features/auth/presentation/widgets/app_button.dart';
import 'package:fbro/features/auth/presentation/widgets/app_text_field.dart';
import 'package:fbro/features/task/domain/entities/task_entity.dart';
import 'package:fbro/features/task/presentation/cubit/task_cubit.dart';
import 'package:fbro/features/task/presentation/cubit/task_state.dart';
import 'package:fbro/features/task/presentation/widgets/task_card.dart';
import 'package:fbro/features/task/presentation/widgets/task_empty_state.dart';

/// Employee task screen (Phase 4). Shows the employee's own assigned tasks and
/// drives their side of the workflow: start → complete (with notes + optional
/// proof image) → submit for review. Rejected tasks can be restarted.
class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key});

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final user = context.read<AuthCubit>().state.maybeWhen(
          authenticated: (u) => u,
          orElse: () => null,
        );
    if (user != null) context.read<TaskCubit>().load(user);
  }

  void _complete(TaskEntity task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          _CompleteSheet(cubit: context.read<TaskCubit>(), task: task),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        title: Text('My Tasks', style: AppTypography.h3),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary),
            tooltip: 'Refresh',
            onPressed: () => context.read<TaskCubit>().refresh(),
          ),
        ],
      ),
      body: BlocConsumer<TaskCubit, TaskState>(
        listener: (context, state) =>
            state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
        builder: (context, state) => state.maybeWhen(
          loading: () => const Center(child: CircularProgressIndicator()),
          loaded: (tasks, busy) => _list(tasks, busy),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _list(List<TaskEntity> tasks, bool busy) {
    return Column(
      children: [
        if (busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<TaskCubit>().refresh(),
            child: tasks.isEmpty
                ? const TaskEmptyState(
                    icon: Icons.checklist_rounded,
                    message: 'No tasks assigned to you yet.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding,
                      AppSpacing.lg,
                      AppSpacing.pagePadding,
                      AppSpacing.xxxl,
                    ),
                    children: [for (final t in tasks) _card(t)],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _card(TaskEntity task) {
    final cubit = context.read<TaskCubit>();
    final actions = <Widget>[];
    switch (task.status) {
      case TaskStatus.pending:
        actions.add(TaskActionButton(
          label: 'Start',
          icon: Icons.play_arrow_rounded,
          onPressed: () => cubit.startTask(task),
        ));
      case TaskStatus.started:
        actions.add(TaskActionButton(
          label: 'Complete',
          icon: Icons.check_rounded,
          onPressed: () => _complete(task),
        ));
      case TaskStatus.completed:
        actions.add(TaskActionButton(
          label: 'Submit for Review',
          icon: Icons.send_rounded,
          onPressed: () => cubit.submitForReview(task),
        ));
      case TaskStatus.rejected:
        actions.add(TaskActionButton(
          label: 'Restart',
          icon: Icons.replay_rounded,
          color: AppColors.warning,
          onPressed: () => cubit.startTask(task),
        ));
      case TaskStatus.waitingReview:
      case TaskStatus.approved:
        break;
    }
    return TaskCard(task: task, actions: actions);
  }
}

/// Bottom sheet for completing a task: optional notes + optional proof image.
class _CompleteSheet extends StatefulWidget {
  const _CompleteSheet({required this.cubit, required this.task});
  final TaskCubit cubit;
  final TaskEntity task;

  @override
  State<_CompleteSheet> createState() => _CompleteSheetState();
}

class _CompleteSheetState extends State<_CompleteSheet> {
  final _notes = TextEditingController();
  File? _proof;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1024,
      );
      if (picked != null) setState(() => _proof = File(picked.path));
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Could not pick an image.');
    }
  }

  void _submit() {
    final notes = _notes.text.trim();
    widget.cubit.completeTask(
      widget.task,
      notes: notes.isEmpty ? null : notes,
      proof: _proof,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
            Text('Complete Task', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _notes,
              label: 'Notes (optional)',
              prefixIcon: Icons.notes_rounded,
            ),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: _pickProof,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Row(
                  children: [
                    if (_proof != null)
                      ClipRRect(
                        borderRadius: AppRadius.cardAll,
                        child: Image.file(_proof!,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            cacheWidth: 200),
                      )
                    else
                      const Icon(Icons.add_a_photo_outlined,
                          size: 22, color: AppColors.textTertiary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        _proof == null
                            ? 'Attach proof image (optional)'
                            : 'Proof image selected — tap to change',
                        style: AppTypography.body,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(label: 'Mark Completed', onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
