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
import 'package:fbro/features/branch/domain/entities/branch_entity.dart';
import 'package:fbro/features/task/domain/entities/task_entity.dart';
import 'package:fbro/features/task/domain/entities/task_template_entity.dart';
import 'package:fbro/features/task/presentation/cubit/task_cubit.dart';

/// Create or edit a task (manager/admin). For a manager the branch is fixed to
/// [defaultBranchId]; an admin **picks** an existing branch from a dropdown
/// (loaded from Firestore — never free text, so a task can't be orphaned on a
/// branch that doesn't exist). Pass [prefill] to seed the form from a template.
Future<void> showTaskFormSheet({
  required BuildContext context,
  required TaskCubit cubit,
  TaskEntity? existing,
  TaskTemplateEntity? prefill,
  required bool isAdmin,
  required String defaultBranchId,
}) =>
    showSheet(
      context,
      _TaskFormSheet(
        cubit: cubit,
        existing: existing,
        prefill: prefill,
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
    showSheet(context, _AssignSheet(cubit: cubit, task: task));

/// Approve or reject a task with an optional review note (manager/admin).
Future<void> showReviewSheet({
  required BuildContext context,
  required TaskCubit cubit,
  required TaskEntity task,
}) =>
    showSheet(context, _ReviewSheet(cubit: cubit, task: task));

/// Shared bottom-sheet chrome (rounded top, drag handle, keyboard-aware
/// padding). Reused by the task + template sheets so they all feel the same.
Future<T?> showSheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
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
          top: AppSpacing.sm,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            Flexible(child: child),
          ],
        ),
      ),
    );

/// A small centered drag handle shown at the top of every bottom sheet.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.darkBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

class SheetTitle extends StatelessWidget {
  const SheetTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Text(text, style: AppTypography.h3),
        ),
      );
}

// ─── Create / edit ───────────────────────────────────────────────
class _TaskFormSheet extends StatefulWidget {
  const _TaskFormSheet({
    required this.cubit,
    required this.existing,
    required this.prefill,
    required this.isAdmin,
    required this.defaultBranchId,
  });

  final TaskCubit cubit;
  final TaskEntity? existing;
  final TaskTemplateEntity? prefill;
  final bool isAdmin;
  final String defaultBranchId;

  @override
  State<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<_TaskFormSheet> {
  late final _title = TextEditingController(
      text: widget.existing?.title ?? widget.prefill?.title ?? '');
  late final _desc = TextEditingController(
      text: widget.existing?.description ?? widget.prefill?.description ?? '');
  late TaskType _type =
      widget.existing?.type ?? widget.prefill?.type ?? TaskType.daily;
  late TaskPriority _priority =
      widget.existing?.priority ?? widget.prefill?.priority ?? TaskPriority.normal;
  late DateTime? _deadline = widget.existing?.deadline;

  /// Admin-only branch selection (managers use their own fixed branch).
  late String? _branchId = _initialBranch();
  late final Future<List<BranchEntity>> _branchesFuture =
      widget.isAdmin ? widget.cubit.branches() : Future.value(const []);

  String? _error;

  String? _initialBranch() {
    final fromExisting = widget.existing?.branchId;
    if (fromExisting != null && fromExisting.isNotEmpty) return fromExisting;
    final fromPrefill = widget.prefill?.branchId;
    if (fromPrefill != null && fromPrefill.isNotEmpty) return fromPrefill;
    return null;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    final branchId =
        widget.isAdmin ? (_branchId ?? '') : widget.defaultBranchId;
    if (branchId.isEmpty) {
      setState(() => _error = 'Please select a branch.');
      return;
    }
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
          SheetTitle(widget.existing == null ? 'New Task' : 'Edit Task'),
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
            _BranchDropdown(
              future: _branchesFuture,
              value: _branchId,
              onChanged: (v) => setState(() => _branchId = v),
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
                          : 'Deadline: ${_dateLabel(_deadline!)}',
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

  static String _dateLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Branch picker for the admin task form — loads active branches from Firestore
/// and presents them as a dropdown of branch ids (label = name · location).
class _BranchDropdown extends StatelessWidget {
  const _BranchDropdown({
    required this.future,
    required this.value,
    required this.onChanged,
  });

  final Future<List<BranchEntity>> future;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BranchEntity>>(
      future: future,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final branches = snap.data ?? const <BranchEntity>[];
        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.store_mall_directory_outlined,
                  size: 20, color: AppColors.textTertiary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: loading
                    ? _placeholder('Loading branches…')
                    : branches.isEmpty
                        ? _placeholder('No branches — create one first')
                        : DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: branches.any((b) => b.id == value)
                                  ? value
                                  : null,
                              isExpanded: true,
                              hint: Text('Select a branch',
                                  style: AppTypography.body
                                      .copyWith(color: AppColors.textTertiary)),
                              dropdownColor: AppColors.darkSurfaceElevated,
                              borderRadius: AppRadius.cardAll,
                              icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.textTertiary),
                              style: AppTypography.body
                                  .copyWith(color: AppColors.textPrimary),
                              items: [
                                for (final b in branches)
                                  DropdownMenuItem<String>(
                                    value: b.id,
                                    child: Text(
                                      b.location == null || b.location!.isEmpty
                                          ? b.name
                                          : '${b.name} · ${b.location}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: onChanged,
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _placeholder(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text(text,
            style: AppTypography.body.copyWith(color: AppColors.textTertiary)),
      );
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
        const SheetTitle('Assign Employee'),
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
                child: Text(
                    'No employees in this branch yet.\nAsk an admin to assign '
                    'an approved employee to this branch first.',
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
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetTitle('Review Task'),
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
      ),
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
