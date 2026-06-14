import 'package:flutter/material.dart';
import 'package:fbro/core/enums/task_priority.dart';
import 'package:fbro/core/enums/task_type.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/auth/presentation/widgets/app_button.dart';
import 'package:fbro/features/auth/presentation/widgets/app_text_field.dart';
import 'package:fbro/features/task/domain/entities/task_entity.dart';
import 'package:fbro/features/task/presentation/cubit/task_cubit.dart';

/// Create or edit a task (manager/admin). For a manager the branch is fixed to
/// [defaultBranchId]; an admin can type any branch.
Future<void> showTaskFormSheet({
  required BuildContext context,
  required TaskCubit cubit,
  TaskEntity? existing,
  required bool isAdmin,
  required String defaultBranchId,
}) =>
    _showSheet(
      context,
      _TaskFormSheet(
        cubit: cubit,
        existing: existing,
        isAdmin: isAdmin,
        defaultBranchId: defaultBranchId,
      ),
    );

/// Pick an employee in the task's branch to assign (or unassign).
Future<void> showAssignSheet({
  required BuildContext context,
  required TaskCubit cubit,
  required TaskEntity task,
}) =>
    _showSheet(context, _AssignSheet(cubit: cubit, task: task));

/// Approve or reject a task with an optional review note (manager/admin).
Future<void> showReviewSheet({
  required BuildContext context,
  required TaskCubit cubit,
  required TaskEntity task,
}) =>
    _showSheet(context, _ReviewSheet(cubit: cubit, task: task));

Future<void> _showSheet(BuildContext context, Widget child) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.pagePadding,
          right: AppSpacing.pagePadding,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
        ),
        child: child,
      ),
    );

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Text(text, style: AppTypography.h3),
      );
}

// ─── Create / edit ───────────────────────────────────────────────
class _TaskFormSheet extends StatefulWidget {
  const _TaskFormSheet({
    required this.cubit,
    required this.existing,
    required this.isAdmin,
    required this.defaultBranchId,
  });

  final TaskCubit cubit;
  final TaskEntity? existing;
  final bool isAdmin;
  final String defaultBranchId;

  @override
  State<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<_TaskFormSheet> {
  late final _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final _desc =
      TextEditingController(text: widget.existing?.description ?? '');
  late final _branch = TextEditingController(
      text: widget.existing?.branchId ?? widget.defaultBranchId);
  late TaskType _type = widget.existing?.type ?? TaskType.daily;
  late TaskPriority _priority = widget.existing?.priority ?? TaskPriority.normal;
  late DateTime? _deadline = widget.existing?.deadline;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _branch.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    final branchId =
        widget.isAdmin ? _branch.text.trim() : widget.defaultBranchId;
    final description = _desc.text.trim().isEmpty ? null : _desc.text.trim();

    final existing = widget.existing;
    if (existing == null) {
      widget.cubit.createTask(
        title: title,
        description: description,
        type: _type,
        priority: _priority,
        branchId: branchId,
        deadline: _deadline,
      );
    } else {
      widget.cubit.editTask(existing.copyWith(
        title: title,
        description: description,
        type: _type,
        priority: _priority,
        branchId: branchId,
        deadline: _deadline,
      ));
    }
    Navigator.of(context).pop();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetTitle(widget.existing == null ? 'New Task' : 'Edit Task'),
          AppTextField(
            controller: _title,
            label: 'Title',
            prefixIcon: Icons.title_rounded,
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _desc,
            label: 'Description (optional)',
            prefixIcon: Icons.notes_rounded,
          ),
          if (widget.isAdmin) ...[
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _branch,
              label: 'Branch',
              hint: 'e.g. cairo',
              prefixIcon: Icons.store_mall_directory_outlined,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _Dropdown<TaskType>(
            label: 'Type',
            value: _type,
            items: TaskType.values,
            labelOf: (t) => t.value,
            onChanged: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: AppSpacing.md),
          _Dropdown<TaskPriority>(
            label: 'Priority',
            value: _priority,
            items: TaskPriority.values,
            labelOf: (p) => p.value,
            onChanged: (v) => setState(() => _priority = v),
          ),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: _pickDeadline,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_outlined,
                      size: 20, color: AppColors.textTertiary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      _deadline == null
                          ? 'Set deadline (optional)'
                          : 'Deadline: ${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}',
                      style: AppTypography.body,
                    ),
                  ),
                  if (_deadline != null)
                    GestureDetector(
                      onTap: () => setState(() => _deadline = null),
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: AppColors.textTertiary),
                    ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!,
                style: AppTypography.caption.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: widget.existing == null ? 'Create Task' : 'Save Changes',
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

// ─── Assign ──────────────────────────────────────────────────────
class _AssignSheet extends StatefulWidget {
  const _AssignSheet({required this.cubit, required this.task});
  final TaskCubit cubit;
  final TaskEntity task;
  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  late final Future<List<UserEntity>> _future =
      widget.cubit.branchEmployees(widget.task.branchId ?? '');

  void _assign(String? employeeId) {
    widget.cubit
        .assignEmployee(taskId: widget.task.id, employeeId: employeeId);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final assigned = widget.task.assignedEmployeeId;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SheetTitle('Assign Employee'),
        if (assigned != null && assigned.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_off_outlined,
                color: AppColors.textSecondary),
            title: Text('Unassign', style: AppTypography.label),
            onTap: () => _assign(null),
          ),
        FutureBuilder<List<UserEntity>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final employees = snap.data ?? const [];
            if (employees.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text('No employees found in this branch.',
                    style: AppTypography.bodySmall),
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: employees.length,
                itemBuilder: (context, i) {
                  final u = employees[i];
                  final name = (u.displayName != null &&
                          u.displayName!.isNotEmpty)
                      ? u.displayName!
                      : u.email;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline_rounded,
                        color: AppColors.primary),
                    title: Text(name, style: AppTypography.label),
                    subtitle: Text(u.email, style: AppTypography.caption),
                    trailing: u.uid == assigned
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.success, size: 18)
                        : null,
                    onTap: () => _assign(u.uid),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─── Review ──────────────────────────────────────────────────────
class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.cubit, required this.task});
  final TaskCubit cubit;
  final TaskEntity task;
  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  String? get _note => _notes.text.trim().isEmpty ? null : _notes.text.trim();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SheetTitle('Review Task'),
        Text(widget.task.title, style: AppTypography.label),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _notes,
          label: 'Review note (optional)',
          prefixIcon: Icons.rate_review_outlined,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: 'Approve',
          icon: const Icon(Icons.check_circle_outline_rounded,
              size: 20, color: AppColors.textDark),
          onPressed: () {
            widget.cubit.approveTask(widget.task, reviewNotes: _note);
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton.secondary(
          label: 'Reject',
          onPressed: () {
            widget.cubit.rejectTask(widget.task, reviewNotes: _note);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

// ─── Shared dropdown ─────────────────────────────────────────────
class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final void Function(T) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.darkSurfaceElevated,
          borderRadius: AppRadius.cardAll,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textTertiary),
          style: AppTypography.body.copyWith(color: AppColors.textPrimary),
          items: [
            for (final item in items)
              DropdownMenuItem<T>(
                value: item,
                child: Text('$label: ${labelOf(item)}'),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
