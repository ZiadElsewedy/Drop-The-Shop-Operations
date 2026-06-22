import 'package:flutter/material.dart';
import 'package:fbro/core/enums/task_priority.dart';
import 'package:fbro/core/enums/task_type.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_snackbar.dart';
import 'package:fbro/features/auth/presentation/widgets/app_button.dart';
import 'package:fbro/features/auth/presentation/widgets/app_text_field.dart';
import 'package:fbro/features/task/domain/entities/checklist_item.dart';
import 'package:fbro/features/task/domain/entities/task_template_entity.dart';
import 'package:fbro/features/task/presentation/cubit/task_cubit.dart';
import 'package:fbro/features/task/presentation/widgets/task_action_sheets.dart';

/// How the manager/admin wants to start a new task.
enum NewTaskChoice { blank, fromTemplate }

/// Drives the full "New Task" entry flow shared by the manager view and the
/// admin branch overview / drill-down: pick blank vs. from-template, then open
/// the (optionally prefilled) task form. [templateBranchFilter] scopes which
/// templates are offered (null = all, for admins); [defaultBranchId] seeds the
/// branch for managers (admins pick it in the form).
Future<void> startNewTaskFlow({
  required BuildContext context,
  required TaskCubit cubit,
  required bool isAdmin,
  required String defaultBranchId,
  String? templateBranchFilter,
}) async {
  final templates = await cubit.templates(branchId: templateBranchFilter);
  if (!context.mounted) return;

  final choice =
      await showNewTaskChooserSheet(context, hasTemplates: templates.isNotEmpty);
  if (!context.mounted || choice == null) return;

  if (choice == NewTaskChoice.blank) {
    await showTaskFormSheet(
      context: context,
      cubit: cubit,
      isAdmin: isAdmin,
      defaultBranchId: defaultBranchId,
    );
    return;
  }

  final template = await showTemplatePickerSheet(
    context: context,
    cubit: cubit,
    branchId: templateBranchFilter,
  );
  if (!context.mounted || template == null) return;
  await showTaskFormSheet(
    context: context,
    cubit: cubit,
    prefill: template,
    isAdmin: isAdmin,
    defaultBranchId: defaultBranchId,
  );
}

/// Step 1 of New Task: a blank task or one started from a saved template (e.g.
/// "Open Shop", "Night Checklist"). Returns the chosen path (or null if
/// dismissed). [hasTemplates] hides the template path when none exist.
Future<NewTaskChoice?> showNewTaskChooserSheet(
  BuildContext context, {
  required bool hasTemplates,
}) =>
    showSheet<NewTaskChoice>(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetTitle('Create a task'),
          _ChoiceTile(
            icon: Icons.add_task_rounded,
            title: 'Blank task',
            subtitle: 'Start from scratch',
            onTap: () => Navigator.of(context).pop(NewTaskChoice.blank),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ChoiceTile(
            icon: Icons.dashboard_customize_outlined,
            title: 'From a template',
            subtitle: hasTemplates
                ? 'Reuse a saved checklist'
                : 'No templates yet — create one from “Templates”',
            enabled: hasTemplates,
            onTap: () => Navigator.of(context).pop(NewTaskChoice.fromTemplate),
          ),
        ],
      ),
    );

/// Step 2 (when "From a template" is chosen): pick which template to use.
/// Returns the selected template, or null if dismissed.
Future<TaskTemplateEntity?> showTemplatePickerSheet({
  required BuildContext context,
  required TaskCubit cubit,
  required String? branchId,
}) =>
    showSheet<TaskTemplateEntity>(
      context,
      _TemplateList(
        future: cubit.templates(branchId: branchId),
        onTap: (t) => Navigator.of(context).pop(t),
        emptyMessage: 'No templates available.',
      ),
    );

/// Manage reusable templates (list · add · delete). A manager's templates are
/// scoped to their branch; an admin's are global (available to every branch).
Future<void> showManageTemplatesSheet({
  required BuildContext context,
  required TaskCubit cubit,
  required bool isAdmin,
  required String defaultBranchId,
}) =>
    showSheet(
      context,
      _ManageTemplates(
        cubit: cubit,
        isAdmin: isAdmin,
        defaultBranchId: defaultBranchId,
      ),
    );

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppRadius.cardAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceElevated,
            borderRadius: AppRadius.cardAll,
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.label),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTypography.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// A scrollable list of templates with an optional trailing builder (used for
/// the delete button in the manager).
class _TemplateList extends StatelessWidget {
  const _TemplateList({
    required this.future,
    required this.onTap,
    required this.emptyMessage,
    this.trailingBuilder,
  });

  final Future<List<TaskTemplateEntity>> future;
  final ValueChanged<TaskTemplateEntity> onTap;
  final String emptyMessage;
  final Widget Function(TaskTemplateEntity)? trailingBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetTitle('Templates'),
        FutureBuilder<List<TaskTemplateEntity>>(
          future: future,
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
                child: Text(emptyMessage, style: AppTypography.bodySmall),
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: templates.length,
                itemBuilder: (context, i) {
                  final t = templates[i];
                  final global = (t.branchId ?? '').isEmpty;
                  final count = t.checklistItems.length;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.checklist_rtl_rounded,
                        color: AppColors.primary),
                    title: Text(t.title, style: AppTypography.label),
                    subtitle: Text(
                      '${count == 0 ? 'no steps' : '$count steps'} · '
                      '${t.type.value}${global ? ' · global' : ''}',
                      style: AppTypography.caption,
                    ),
                    trailing: trailingBuilder?.call(t),
                    onTap: () => onTap(t),
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

class _ManageTemplates extends StatefulWidget {
  const _ManageTemplates({
    required this.cubit,
    required this.isAdmin,
    required this.defaultBranchId,
  });
  final TaskCubit cubit;
  final bool isAdmin;
  final String defaultBranchId;

  @override
  State<_ManageTemplates> createState() => _ManageTemplatesState();
}

class _ManageTemplatesState extends State<_ManageTemplates> {
  late Future<List<TaskTemplateEntity>> _future = _load();
  bool _busy = false;

  Future<List<TaskTemplateEntity>> _load() => widget.cubit.templates(
      branchId: widget.isAdmin ? null : widget.defaultBranchId);

  void _reload() => setState(() => _future = _load());

  Future<void> _delete(TaskTemplateEntity t) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.cubit.deleteTemplate(t.id);
      _reload();
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Could not delete the template.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final created = await showSheet<bool>(
      context,
      _TemplateForm(
        cubit: widget.cubit,
        isAdmin: widget.isAdmin,
        defaultBranchId: widget.defaultBranchId,
      ),
    );
    if (created == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        _TemplateList(
          future: _future,
          onTap: (_) {},
          emptyMessage: widget.isAdmin
              ? 'No templates yet. Add reusable global checklists like '
                  '“Open Shop” or “Night Checklist”.'
              : 'No templates for your branch yet. Add reusable checklists '
                  'like “Open Shop” or “Night Checklist”.',
          trailingBuilder: (t) => IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error, size: 20),
            tooltip: 'Delete',
            onPressed: _busy ? null : () => _delete(t),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Add Template',
          icon: const Icon(Icons.add_rounded,
              size: 20, color: AppColors.textDark),
          onPressed: _busy ? null : _add,
        ),
      ],
    );
  }
}

/// Form to create a new template. Pops `true` once saved so the manager
/// refreshes its list.
class _TemplateForm extends StatefulWidget {
  const _TemplateForm({
    required this.cubit,
    required this.isAdmin,
    required this.defaultBranchId,
  });
  final TaskCubit cubit;
  final bool isAdmin;
  final String defaultBranchId;

  @override
  State<_TemplateForm> createState() => _TemplateFormState();
}

/// Holds the live editing state of one checklist row (its text + required flag).
class _ChecklistRow {
  _ChecklistRow(this.id, {String text = ''})
      : controller = TextEditingController(text: text);
  final String id;
  final TextEditingController controller;
  bool isRequired = true;
}

class _TemplateFormState extends State<_TemplateForm> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  TaskType _type = TaskType.daily;
  TaskPriority _priority = TaskPriority.normal;
  final List<_ChecklistRow> _items = [];
  int _idSeq = 0;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Start with a couple of empty steps to invite a checklist.
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
    // Clear any stale error from a previous attempt.
    if (_error != null) setState(() => _error = null);

    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
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
      await widget.cubit.saveTemplate(
        title: title,
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        type: _type,
        priority: _priority,
        checklistItems: checklist,
        // Admin templates are global ('' = every branch); a manager's are
        // scoped to their own branch.
        branchId: widget.isAdmin ? '' : widget.defaultBranchId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save. Please try again.');
    } finally {
      // Always clear the loading state — even if mounted becomes false while
      // awaiting (e.g. the sheet was dismissed externally).
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
          const SheetTitle('New Checklist Template'),
          AppTextField(
            controller: _title,
            label: 'Title',
            hint: 'e.g. Open Shop',
            prefixIcon: Icons.title_rounded,
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _desc,
            label: 'Description (optional)',
            prefixIcon: Icons.notes_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          _SimpleDropdown<TaskType>(
            label: 'Type',
            value: _type,
            items: TaskType.values,
            labelOf: (t) => t.value,
            onChanged: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: AppSpacing.md),
          _SimpleDropdown<TaskPriority>(
            label: 'Priority',
            value: _priority,
            items: TaskPriority.values,
            labelOf: (p) => p.value,
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
            label: 'Save Template',
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
          // Required / optional toggle.
          IconButton(
            tooltip: row.isRequired ? 'Required' : 'Optional',
            onPressed: () => setState(() => row.isRequired = !row.isRequired),
            icon: Icon(
              row.isRequired
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              size: 20,
              color: row.isRequired
                  ? AppColors.primary
                  : AppColors.textTertiary,
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

class _SimpleDropdown<T> extends StatelessWidget {
  const _SimpleDropdown({
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
