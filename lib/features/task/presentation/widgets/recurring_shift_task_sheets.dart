import 'package:flutter/material.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/enums/template_repeat_mode.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/features/auth/presentation/widgets/app_button.dart';
import 'package:drop/features/auth/presentation/widgets/app_text_field.dart';
import 'package:drop/features/task/domain/entities/checklist_item.dart';
import 'package:drop/features/task/domain/entities/recurring_task_template_entity.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/widgets/task_action_sheets.dart';

/// Manage a branch's recurring shift-task templates (Shift Assignment feature)
/// — list · add · pause/resume · delete. Reuses the exact list/sheet chrome of
/// `task_template_sheets.dart`'s `_ManageTemplates`/`_TemplateForm`. Always
/// branch-scoped (a shift only means something within one branch's roster),
/// unlike checklist templates which may be global.
Future<void> showManageRecurringShiftTasksSheet({
  required BuildContext context,
  required TaskCubit cubit,
  required String branchId,
}) async {
  // Never stack one modal sheet on top of another. On desktop/macOS the nested
  // modal barriers can leave the manage sheet dimmed and input-blocked after the
  // form pops, which looks like a frozen app. Close Manage first, then present
  // the form as the only modal route.
  final action = await showSheet<_RecurringManageAction>(
    context,
    _ManageRecurringShiftTasks(cubit: cubit, branchId: branchId),
  );
  if (action == _RecurringManageAction.add && context.mounted) {
    await showSheet<bool>(
      context,
      _RecurringShiftTaskForm(cubit: cubit, branchId: branchId),
    );
  }
}

enum _RecurringManageAction { add }

class _ManageRecurringShiftTasks extends StatefulWidget {
  const _ManageRecurringShiftTasks({
    required this.cubit,
    required this.branchId,
  });
  final TaskCubit cubit;
  final String branchId;

  @override
  State<_ManageRecurringShiftTasks> createState() =>
      _ManageRecurringShiftTasksState();
}

class _ManageRecurringShiftTasksState
    extends State<_ManageRecurringShiftTasks> {
  late Future<List<RecurringTaskTemplateEntity>> _future = _load();
  bool _busy = false;

  Future<List<RecurringTaskTemplateEntity>> _load() =>
      widget.cubit.recurringTemplates(widget.branchId);

  void _reload() => setState(() => _future = _load());

  Future<void> _toggleActive(RecurringTaskTemplateEntity t) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.cubit.setRecurringTemplateActive(t, !t.active);
      _reload();
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(context, 'Could not update the recurring task.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(RecurringTaskTemplateEntity t) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.cubit.deleteRecurringTemplate(t.id);
      _reload();
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(context, 'Could not delete the recurring task.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _add() => Navigator.of(context).pop(_RecurringManageAction.add);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetTitle('Recurring Shift Tasks'),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        FutureBuilder<List<RecurringTaskTemplateEntity>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final templates = snap.data ?? const [];
            if (templates.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  'No recurring shift tasks yet. Add a daily/weekly routine '
                  'like "Open Store" that\'s assigned to a shift, not a person.',
                  style: AppTypography.bodySmall,
                ),
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: templates.length,
                itemBuilder: (context, i) {
                  final t = templates[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.schedule_rounded,
                        color: t.active
                            ? AppColors.primary
                            : AppColors.textTertiary),
                    title: Text(t.title, style: AppTypography.label),
                    subtitle: Text(
                      '${t.shift.label} · ${t.repeat.label}'
                      '${t.repeat == TemplateRepeatMode.weekly ? ' · ${_weekdayLabel(t.weekday)}' : ''}'
                      '${t.active ? '' : ' · paused'}',
                      style: AppTypography.caption,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: t.active,
                          onChanged: _busy ? null : (_) => _toggleActive(t),
                          activeTrackColor: AppColors.primary,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.error, size: 20),
                          tooltip: 'Delete',
                          onPressed: _busy ? null : () => _delete(t),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Add Recurring Shift Task',
          icon: const Icon(Icons.add_rounded,
              size: 20, color: AppColors.textDark),
          onPressed: _busy ? null : _add,
        ),
      ],
    );
  }

  static const _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static String _weekdayLabel(int weekday) =>
      _weekdayLabels[(weekday - 1).clamp(0, 6)];
}

/// Form to create a new recurring shift-task template. Pops `true` once saved
/// so the manage sheet refreshes its list.
class _RecurringShiftTaskForm extends StatefulWidget {
  const _RecurringShiftTaskForm({required this.cubit, required this.branchId});
  final TaskCubit cubit;
  final String branchId;

  @override
  State<_RecurringShiftTaskForm> createState() =>
      _RecurringShiftTaskFormState();
}

class _RecurringShiftTaskFormState extends State<_RecurringShiftTaskForm> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  TaskPriority _priority = TaskPriority.normal;
  ScheduleShift? _shift;
  TemplateRepeatMode _repeat = TemplateRepeatMode.daily;
  int _weekday = DateTime.now().weekday;
  final List<_ChecklistRow> _items = [];
  int _idSeq = 0;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _items
      ..add(_ChecklistRow('c${_idSeq++}'))
      ..add(_ChecklistRow('c${_idSeq++}'));
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    for (final i in _items) {
      i.controller.dispose();
    }
    super.dispose();
  }

  void _addItem() => setState(() => _items.add(_ChecklistRow('c${_idSeq++}')));

  void _removeItem(_ChecklistRow row) {
    setState(() {
      _items.remove(row);
      row.controller.dispose();
    });
  }

  Future<void> _save() async {
    if (_error != null) setState(() => _error = null);

    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    if (_shift == null) {
      setState(() => _error = 'Please select a shift.');
      return;
    }
    final checklist = <ChecklistItemTemplate>[
      for (final row in _items)
        if (row.controller.text.trim().isNotEmpty)
          ChecklistItemTemplate(
            id: row.id,
            title: row.controller.text.trim(),
            isRequired: row.isRequired,
          ),
    ];
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.cubit.createRecurringShiftTemplate(
        title: title,
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        priority: _priority,
        branchId: widget.branchId,
        shift: _shift!,
        checklistItems: checklist,
        repeat: _repeat,
        weekday: _weekday,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save. Please try again.');
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetTitle('New Recurring Shift Task'),
          AppTextField(
            controller: _title,
            label: 'Title',
            hint: 'e.g. Open Store',
            prefixIcon: Icons.title_rounded,
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _desc,
            label: 'Description (optional)',
            prefixIcon: Icons.notes_rounded,
          ),
          const SizedBox(height: AppSpacing.lg),
          ShiftChipPicker(
            value: _shift,
            onChanged: (s) => setState(() => _shift = s),
          ),
          const SizedBox(height: AppSpacing.lg),
          ShiftRepeatPicker(
            value: _repeat,
            onChanged: (v) => setState(() => _repeat = v),
            weekday: _weekday,
            onWeekdayChanged: (w) => setState(() => _weekday = w),
            modes: const [TemplateRepeatMode.daily, TemplateRepeatMode.weekly],
          ),
          const SizedBox(height: AppSpacing.lg),
          _PriorityDropdown(
            value: _priority,
            onChanged: (v) => setState(() => _priority = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Icon(Icons.checklist_rounded,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text('Checklist steps', style: AppTypography.labelSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final row in _items) _checklistRow(row),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add step'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!,
                style: AppTypography.caption.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Save Recurring Shift Task',
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _checklistRow(_ChecklistRow row) {
    return Padding(
      key: ValueKey(row.id),
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.darkSurfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: TextField(
                controller: row.controller,
                style: AppTypography.body
                    .copyWith(color: AppColors.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Step description',
                  hintStyle: AppTypography.body
                      .copyWith(color: AppColors.textTertiary),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: row.isRequired ? 'Required' : 'Optional',
            onPressed: () => setState(() => row.isRequired = !row.isRequired),
            icon: Icon(
              row.isRequired ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 20,
              color:
                  row.isRequired ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: () => _removeItem(row),
            icon: const Icon(Icons.close_rounded,
                size: 18, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Holds the live editing state of one checklist row (its text + required flag).
class _ChecklistRow {
  _ChecklistRow(this.id, {String text = ''})
      : controller = TextEditingController(text: text);
  final String id;
  final TextEditingController controller;
  bool isRequired = true;
}

/// Minimal priority dropdown, mirroring the small private dropdowns each
/// sheets file already keeps for its own form (see `task_action_sheets.dart`'s
/// `_Dropdown` / `task_template_sheets.dart`'s `_SimpleDropdown`).
class _PriorityDropdown extends StatelessWidget {
  const _PriorityDropdown({required this.value, required this.onChanged});
  final TaskPriority value;
  final void Function(TaskPriority) onChanged;

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
        child: DropdownButton<TaskPriority>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.darkSurfaceElevated,
          borderRadius: AppRadius.cardAll,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textTertiary),
          style: AppTypography.body.copyWith(color: AppColors.textPrimary),
          items: [
            for (final p in TaskPriority.values)
              DropdownMenuItem(value: p, child: Text('Priority: ${p.value}')),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
