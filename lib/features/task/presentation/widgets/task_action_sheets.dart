import 'package:flutter/material.dart';
import 'package:fbro/core/enums/task_priority.dart';
import 'package:fbro/core/enums/task_type.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/auth/presentation/widgets/app_dropdown_field.dart';
import 'package:fbro/core/widgets/user_avatar.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/auth/presentation/widgets/app_button.dart';
import 'package:fbro/features/auth/presentation/widgets/app_text_field.dart';
import 'package:fbro/features/branch/domain/entities/branch_entity.dart';
import 'package:fbro/features/task/domain/entities/checklist_item.dart';
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

/// Pick one or more employees in the task's branch to assign (or the whole
/// team), or clear the assignment.
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
        // A task created from a checklist template gets its checklist generated.
        checklist: widget.prefill?.buildTaskChecklist() ?? const [],
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
          if (widget.existing == null &&
              (widget.prefill?.checklistItems.isNotEmpty ?? false)) ...[
            const SizedBox(height: AppSpacing.md),
            _ChecklistPreview(items: widget.prefill!.checklistItems),
          ],
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
        return AppDropdownField<String>(
          value: branches.any((b) => b.id == value) ? value : null,
          prefixIcon: Icons.store_mall_directory_outlined,
          hint: 'Select a branch',
          placeholder: loading
              ? 'Loading branches…'
              : branches.isEmpty
                  ? 'No branches — create one first'
                  : null,
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
        );
      },
    );
  }
}

/// Read-only preview of a template's checklist, shown in the New Task form so
/// the manager sees what the employee will be asked to complete.
class _ChecklistPreview extends StatelessWidget {
  const _ChecklistPreview({required this.items});
  final List<ChecklistItemTemplate> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rounded,
                  size: 16, color: AppColors.textTertiary),
              const SizedBox(width: AppSpacing.sm),
              Text('Checklist · ${items.length} steps',
                  style: AppTypography.labelSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.radio_button_unchecked_rounded,
                      size: 15, color: AppColors.textTertiary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                      child: Text(i.title, style: AppTypography.bodySmall)),
                  if (!i.isRequired)
                    Text('optional', style: AppTypography.caption),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Assign (multi-select) ───────────────────────────────────────
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

  late final Set<String> _selected = {...widget.task.assigneeIds};

  void _save() {
    widget.cubit
        .assignEmployees(taskId: widget.task.id, employeeIds: _selected.toList());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetTitle('Assign Employees'),
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
            final allSelected =
                employees.every((u) => _selected.contains(u.uid));
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick actions: whole team / clear.
                Row(
                  children: [
                    _QuickAction(
                      icon: Icons.groups_2_outlined,
                      label: allSelected ? 'Team selected' : 'Assign whole team',
                      active: allSelected,
                      onTap: () => setState(() {
                        if (allSelected) {
                          _selected.clear();
                        } else {
                          _selected.addAll(employees.map((u) => u.uid));
                        }
                      }),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _QuickAction(
                      icon: Icons.person_off_outlined,
                      label: 'Clear',
                      active: false,
                      onTap: _selected.isEmpty
                          ? null
                          : () => setState(_selected.clear),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: employees.length,
                    itemBuilder: (context, i) {
                      final u = employees[i];
                      final name =
                          (u.displayName != null && u.displayName!.isNotEmpty)
                              ? u.displayName!
                              : u.email;
                      final selected = _selected.contains(u.uid);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: UserAvatar.fromUser(u, size: 38),
                        title: Text(name, style: AppTypography.label),
                        subtitle: Text(u.email, style: AppTypography.caption),
                        trailing: Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: selected
                              ? AppColors.success
                              : AppColors.textTertiary,
                          size: 22,
                        ),
                        onTap: () => setState(() {
                          if (selected) {
                            _selected.remove(u.uid);
                          } else {
                            _selected.add(u.uid);
                          }
                        }),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: _selected.isEmpty
                      ? 'Unassign'
                      : 'Assign ${_selected.length}',
                  onPressed: _save,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: disabled ? 0.5 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary.withAlpha(28)
                  : AppColors.darkSurfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: active ? AppColors.primary : AppColors.darkBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16,
                    color: active ? AppColors.primary : AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(label,
                      style: AppTypography.caption.copyWith(
                          color: active
                              ? AppColors.primary
                              : AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ),
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
          if (widget.task.hasChecklist) ...[
            const SizedBox(height: AppSpacing.md),
            _ReviewChecklist(task: widget.task),
          ],
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

/// Read-only checklist progress for the manager review sheet ("4 / 5 completed"
/// or "100% complete") with each item's state.
class _ReviewChecklist extends StatelessWidget {
  const _ReviewChecklist({required this.task});
  final TaskEntity task;

  @override
  Widget build(BuildContext context) {
    final done = task.checklistDone;
    final total = task.checklistTotal;
    final complete = done == total;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded,
                  size: 16,
                  color: complete ? AppColors.success : AppColors.textTertiary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                complete ? '100% complete' : '$done / $total completed',
                style: AppTypography.labelSmall.copyWith(
                  color:
                      complete ? AppColors.success : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final i in task.checklist)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    i.completed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color:
                        i.completed ? AppColors.success : AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(i.title,
                        style: AppTypography.bodySmall.copyWith(
                          color: i.completed
                              ? AppColors.textTertiary
                              : AppColors.textPrimary,
                        )),
                  ),
                ],
              ),
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
