import 'package:flutter/material.dart';
import 'package:drop/core/enums/recurrence_frequency.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/task_assignment_type.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/enums/task_type.dart';
import 'package:drop/core/enums/template_repeat_mode.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/auth/presentation/widgets/app_dropdown_field.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/widgets/app_button.dart';
import 'package:drop/features/auth/presentation/widgets/app_text_field.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/task/domain/entities/checklist_item.dart';
import 'package:drop/features/task/domain/entities/recurrence_config.dart';
import 'package:drop/features/task/domain/entities/task_attachment.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/entities/task_template_entity.dart';
import 'package:drop/features/task/presentation/attachment_format.dart';
import 'package:drop/features/task/domain/work_types/work_draft.dart';
import 'package:drop/features/task/domain/work_types/work_type_registry.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/widgets/attachment_gallery.dart';
import 'package:drop/features/task/presentation/widgets/attachment_picker.dart';
import 'package:drop/features/task/presentation/widgets/dynamic_work_form.dart';

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
  late TaskPriority _priority =
      widget.existing?.priority ?? widget.prefill?.priority ?? TaskPriority.normal;

  /// Work-type selection + its schema-driven field values. The type is chosen on
  /// a new task (locked when editing — a task's kind never changes mid-life);
  /// [_workData] holds the values for the type's dynamic fields, seeded from an
  /// existing task and reset when the type changes.
  late String _workType = widget.existing?.workType ?? 'general';
  late Map<String, dynamic> _workData = {...?widget.existing?.data};
  Map<String, String> _workFieldErrors = const {};

  late DateTime? _deadline = widget.existing?.deadline;
  late RecurrenceFrequency _recurrence =
      widget.existing?.recurrence?.frequency ?? RecurrenceFrequency.none;

  /// Shift Assignment feature — new tasks only (an existing task/instance never
  /// changes its assignment mode, so these are seeded once and the selector to
  /// change them is hidden in edit mode; see the `widget.existing == null`
  /// gates in [build]).
  late TaskAssignmentType _assignmentType =
      widget.existing?.assignmentType ?? TaskAssignmentType.individual;
  late ScheduleShift? _shift = widget.existing?.shift;
  TemplateRepeatMode _shiftRepeat = TemplateRepeatMode.once;
  int _shiftWeekday = DateTime.now().weekday;

  /// Checklist state: parallel lists for controllers, required flag, id,
  /// and the original [ChecklistItem] (only set when editing an existing task,
  /// so we can preserve the completed/completedAt state on save).
  final List<TextEditingController> _itemControllers = [];
  final List<bool> _itemRequired = [];
  final List<String> _itemIds = [];
  final List<ChecklistItem?> _itemOriginals = [];

  /// Reference images: the already-uploaded ones kept on this task (removable in
  /// edit mode) + the newly-picked ones to upload on save.
  late final List<TaskAttachment> _existingRefs = [
    ...?widget.existing?.referenceAttachments,
  ];
  List<PickedAttachment> _newRefs = [];

  /// Admin-only branch selection (managers use their own fixed branch).
  late String? _branchId = _initialBranch();
  late final Future<List<BranchEntity>> _branchesFuture =
      widget.isAdmin ? widget.cubit.branches() : Future.value(const []);

  /// Assign-on-create: the selected employee uids (seeded from the existing task
  /// when editing) + the branch their list was loaded for, so an admin re-picking
  /// a branch reloads the team and clears a now-irrelevant selection.
  late final Set<String> _assignees = {...?widget.existing?.assigneeIds};
  Future<List<UserEntity>>? _employeesFuture;
  String _employeesBranch = '';

  String? _error;

  String? _initialBranch() {
    final fromExisting = widget.existing?.branchId;
    if (fromExisting != null && fromExisting.isNotEmpty) return fromExisting;
    final fromPrefill = widget.prefill?.branchId;
    if (fromPrefill != null && fromPrefill.isNotEmpty) return fromPrefill;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _initChecklist();
    _syncEmployeesFuture();
  }

  /// (Re)loads the branch's employee list for the assignee picker when the
  /// effective branch changes (manager: fixed; admin: the picked branch).
  void _syncEmployeesFuture() {
    final branch =
        (widget.isAdmin ? _branchId : widget.defaultBranchId)?.trim() ?? '';
    if (branch == _employeesBranch) return;
    _employeesBranch = branch;
    _employeesFuture =
        branch.isEmpty ? null : widget.cubit.branchEmployees(branch);
  }

  void _initChecklist() {
    if (widget.existing != null) {
      // Edit mode: seed from the task's existing checklist items, preserving state
      for (final item in widget.existing!.checklist) {
        _itemControllers.add(TextEditingController(text: item.title));
        _itemRequired.add(item.isRequired);
        _itemIds.add(item.id);
        _itemOriginals.add(item);
      }
    } else if (widget.prefill != null) {
      // New task from template: seed from the template's checklist items
      for (final t in widget.prefill!.checklistItems) {
        _itemControllers.add(TextEditingController(text: t.title));
        _itemRequired.add(t.isRequired);
        _itemIds.add(t.id);
        _itemOriginals.add(null);
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    for (final c in _itemControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addChecklistItem() {
    setState(() {
      _itemControllers.add(TextEditingController());
      _itemRequired.add(true);
      _itemIds.add('ci_${DateTime.now().millisecondsSinceEpoch}_${_itemControllers.length}');
      _itemOriginals.add(null);
    });
  }

  void _removeChecklistItem(int i) {
    _itemControllers[i].dispose();
    setState(() {
      _itemControllers.removeAt(i);
      _itemRequired.removeAt(i);
      _itemIds.removeAt(i);
      _itemOriginals.removeAt(i);
    });
  }

  void _toggleRequired(int i) =>
      setState(() => _itemRequired[i] = !_itemRequired[i]);

  List<ChecklistItem> _buildChecklist() {
    final result = <ChecklistItem>[];
    for (var i = 0; i < _itemControllers.length; i++) {
      final title = _itemControllers[i].text.trim();
      if (title.isEmpty) continue;
      final original = _itemOriginals[i];
      if (original != null) {
        // Preserve completed state, update title + required
        result.add(original.copyWith(title: title, isRequired: _itemRequired[i]));
      } else {
        result.add(ChecklistItem(
          id: _itemIds[i],
          title: title,
          isRequired: _itemRequired[i],
        ));
      }
    }
    return result;
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
    if (widget.existing == null &&
        _assignmentType == TaskAssignmentType.shift &&
        _shift == null) {
      setState(() => _error = 'Please select a shift.');
      return;
    }
    final description = _desc.text.trim().isEmpty ? null : _desc.text.trim();
    final checklist = _buildChecklist();

    // Work-type setup gate — each type validates its own fields (a general task
    // declares none, so this is a no-op for it).
    final workDef = WorkTypeRegistry.instance.byId(_workType);
    final setup = workDef.validateSetup(WorkDraft(
      data: _workData,
      checklistCount: checklist.length,
      assigneeCount: _assignees.length,
    ));
    if (!setup.ok) {
      setState(() {
        _workFieldErrors = setup.fieldErrors;
        _error = setup.firstError;
      });
      return;
    }

    final existing = widget.existing;
    if (existing == null) {
      if (_assignmentType == TaskAssignmentType.shift) {
        if (_shiftRepeat == TemplateRepeatMode.once) {
          widget.cubit.createTask(
            title: title,
            description: description,
            type: TaskType.daily,
            workType: _workType,
            data: _workData,
            priority: _priority,
            branchId: branchId,
            deadline: _deadline,
            checklist: checklist,
            referenceAttachments: _newRefs,
            assignmentType: TaskAssignmentType.shift,
            shift: _shift,
            instanceDate: _deadline,
          );
        } else {
          // Recurring shift templates generate general instances; a specialised
          // work type would be silently dropped, so require General here (until
          // templates learn to carry a work type).
          if (_workType != 'general') {
            setState(() => _error =
                'Recurring shift templates support General tasks only for now — '
                'choose "Once", or set the work type to General.');
            return;
          }
          widget.cubit.createRecurringShiftTemplate(
            title: title,
            description: description,
            priority: _priority,
            branchId: branchId,
            shift: _shift!,
            checklistItems: [
              for (final c in checklist)
                ChecklistItemTemplate(
                    id: c.id, title: c.title, isRequired: c.isRequired),
            ],
            repeat: _shiftRepeat,
            weekday: _shiftWeekday,
          );
        }
      } else {
        // Infer type from recurrence: recurring = daily routine, else special
        final inferredType = _recurrence != RecurrenceFrequency.none
            ? TaskType.daily
            : TaskType.special;
        widget.cubit.createTask(
          title: title,
          description: description,
          type: inferredType,
          workType: _workType,
          data: _workData,
          priority: _priority,
          branchId: branchId,
          deadline: _deadline,
          assigneeIds: _assignees.toList(),
          checklist: checklist,
          recurrence: _recurrence == RecurrenceFrequency.none
              ? null
              : RecurrenceConfig(frequency: _recurrence),
          referenceAttachments: _newRefs,
          assignmentType: _assignmentType,
        );
      }
    } else {
      widget.cubit.editTask(
        existing.copyWith(
          title: title,
          description: description,
          workType: _workType,
          data: _workData,
          priority: _priority,
          branchId: branchId,
          deadline: _deadline,
          assigneeIds: _assignees.toList(),
          checklist: checklist,
          // Persist the kept references (removed ones drop off here); newly
          // picked ones upload via newReferenceAttachments below.
          referenceAttachments: _existingRefs,
        ),
        newReferenceAttachments: _newRefs,
      );
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
          // Work type — picking the kind of work regenerates the type-specific
          // fields below it. Locked in edit mode.
          WorkTypePicker(
            value: _workType,
            enabled: widget.existing == null,
            onChanged: (id) => setState(() {
              _workType = id;
              _workData = {}; // fields differ per type
              _workFieldErrors = const {};
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          DynamicWorkForm(
            definition: WorkTypeRegistry.instance.byId(_workType),
            initialData: _workData,
            errors: _workFieldErrors,
            onChanged: (data) => _workData = data,
          ),
          AppTextField(
            controller: _desc,
            label: 'Description (optional)',
            prefixIcon: Icons.notes_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          // Reference images — "what good looks like" the employee sees before
          // starting (images only; distinct from their proof on submission).
          AttachmentPickerField(
            attachments: _newRefs,
            allowVideo: false,
            title: 'Reference images',
            hint:
                'Attach photos showing how this should look — the employee sees '
                'them before starting. Photos are compressed before upload.',
            existing: _existingRefs,
            onRemoveExisting: (a) =>
                setState(() => _existingRefs.remove(a)),
            onChanged: (list) => setState(() => _newRefs = list),
          ),
          const SizedBox(height: AppSpacing.md),
          _InlineChecklistEditor(
            controllers: _itemControllers,
            required: _itemRequired,
            onAdd: _addChecklistItem,
            onRemove: _removeChecklistItem,
            onToggleRequired: _toggleRequired,
          ),
          if (widget.isAdmin) ...[
            const SizedBox(height: AppSpacing.md),
            _BranchDropdown(
              future: _branchesFuture,
              value: _branchId,
              onChanged: (v) => setState(() {
                _branchId = v;
                _assignees.clear(); // employees differ per branch
                _syncEmployeesFuture();
              }),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (widget.existing == null) ...[
            _AssignedToPicker(
              value: _assignmentType,
              onChanged: (t) => setState(() => _assignmentType = t),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_assignmentType != TaskAssignmentType.shift)
            _AssigneePicker(
              future: _employeesFuture,
              selected: _assignees,
              onToggle: (uid) => setState(() {
                _assignees.contains(uid)
                    ? _assignees.remove(uid)
                    : _assignees.add(uid);
              }),
              onToggleAll: (all) => setState(() {
                final ids = all.map((u) => u.uid);
                if (ids.every(_assignees.contains)) {
                  _assignees.removeAll(ids);
                } else {
                  _assignees.addAll(ids);
                }
              }),
            )
          else
            ShiftChipPicker(
              value: _shift,
              onChanged: (s) => setState(() => _shift = s),
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
          const SizedBox(height: AppSpacing.md),
          // Recurrence picker (new tasks only) — shift mode gets its own
          // Once/Daily/Weekly picker instead (daily/weekly saves as a
          // recurring shift-task template rather than a single task).
          if (widget.existing == null)
            if (_assignmentType == TaskAssignmentType.shift)
              ShiftRepeatPicker(
                value: _shiftRepeat,
                onChanged: (v) => setState(() => _shiftRepeat = v),
                weekday: _shiftWeekday,
                onWeekdayChanged: (w) => setState(() => _shiftWeekday = w),
              )
            else
              _RecurrencePicker(
                value: _recurrence,
                onChanged: (v) => setState(() => _recurrence = v),
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

/// Inline checklist editor used inside the task creation / edit form.
/// The parent [_TaskFormSheetState] owns all state (controllers, required flags,
/// ids); this widget is stateless and just renders + calls back.
class _InlineChecklistEditor extends StatelessWidget {
  const _InlineChecklistEditor({
    required this.controllers,
    required this.required,
    required this.onAdd,
    required this.onRemove,
    required this.onToggleRequired,
  });

  final List<TextEditingController> controllers;
  final List<bool> required;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final void Function(int) onToggleRequired;

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
          // Header row
          Row(
            children: [
              const Icon(Icons.checklist_rounded,
                  size: 16, color: AppColors.textTertiary),
              const SizedBox(width: AppSpacing.sm),
              Text('Checklist', style: AppTypography.labelSmall),
              if (controllers.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.darkBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.darkBorder),
                  ),
                  child: Text('${controllers.length}',
                      style: AppTypography.caption),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.darkBorder),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text('Add step',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Items
          if (controllers.isEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('No steps yet. Tap "Add step" to build the checklist.',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textTertiary)),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < controllers.length; i++)
              _ChecklistItemRow(
                key: ValueKey('ci_$i'),
                controller: controllers[i],
                isRequired: required[i],
                onToggleRequired: () => onToggleRequired(i),
                onRemove: () => onRemove(i),
              ),
          ],
        ],
      ),
    );
  }
}

/// A single editable row inside [_InlineChecklistEditor].
class _ChecklistItemRow extends StatelessWidget {
  const _ChecklistItemRow({
    super.key,
    required this.controller,
    required this.isRequired,
    required this.onToggleRequired,
    required this.onRemove,
  });

  final TextEditingController controller;
  final bool isRequired;
  final VoidCallback onToggleRequired;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.drag_indicator_rounded,
              size: 18, color: AppColors.darkBorder),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTypography.bodySmall,
              decoration: InputDecoration(
                hintText: 'Step description…',
                hintStyle: AppTypography.bodySmall
                    .copyWith(color: AppColors.textTertiary),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 10),
                filled: true,
                fillColor: AppColors.darkBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Required toggle: filled star = required, outline = optional
          Tooltip(
            message: isRequired
                ? 'Required — tap to make optional'
                : 'Optional — tap to make required',
            child: GestureDetector(
              onTap: onToggleRequired,
              child: Icon(
                isRequired
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 18,
                color: isRequired
                    ? AppColors.textSecondary
                    : AppColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                size: 18, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Assign-on-create picker shown inside the task form — select one or more of
/// the branch's employees as you create the task (no more "create, then assign").
/// State (the selected set + the loaded future) lives on [_TaskFormSheetState];
/// this widget renders + calls back.
class _AssigneePicker extends StatelessWidget {
  const _AssigneePicker({
    required this.future,
    required this.selected,
    required this.onToggle,
    required this.onToggleAll,
  });

  final Future<List<UserEntity>>? future;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final ValueChanged<List<UserEntity>> onToggleAll;

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
      child: future == null
          ? _withHint('Pick a branch to choose who to assign.')
          : FutureBuilder<List<UserEntity>>(
              future: future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return _withHint('Loading team…');
                }
                final employees = snap.data ?? const <UserEntity>[];
                if (employees.isEmpty) {
                  return _withHint('No employees in this branch yet.');
                }
                final allSelected =
                    employees.every((u) => selected.contains(u.uid));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headerRow(
                      trailing: GestureDetector(
                        onTap: () => onToggleAll(employees),
                        child: Text(allSelected ? 'Clear all' : 'Whole team',
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textSecondary)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final u in employees)
                          _EmployeeChip(
                            user: u,
                            selected: selected.contains(u.uid),
                            onTap: () => onToggle(u.uid),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _withHint(String hint) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerRow(),
          const SizedBox(height: AppSpacing.sm),
          Text(hint,
              style:
                  AppTypography.caption.copyWith(color: AppColors.textTertiary)),
        ],
      );

  Widget _headerRow({Widget? trailing}) => Row(
        children: [
          const Icon(Icons.group_add_outlined,
              size: 16, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Text('Assign to', style: AppTypography.labelSmall),
          if (selected.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Text('${selected.length}', style: AppTypography.caption),
            ),
          ],
          const Spacer(),
          ?trailing,
        ],
      );
}

/// A selectable employee chip (avatar + name + toggle) used by [_AssigneePicker].
class _EmployeeChip extends StatelessWidget {
  const _EmployeeChip({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final UserEntity user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = (user.displayName != null && user.displayName!.isNotEmpty)
        ? user.displayName!
        : user.email;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withAlpha(28) : AppColors.darkBg,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.darkBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar.fromUser(user, size: 24),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color:
                      selected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              size: 16,
              color: selected ? AppColors.primary : AppColors.textTertiary,
            ),
          ],
        ),
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
          _SubmittedWork(task: widget.task),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _notes,
            label: 'What needs fixing? (optional)',
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
          // Sends the task back for the employee to fix and resubmit (bumps the
          // revision → REWORK #n).
          AppButton.secondary(
            label: 'Request Rework',
            onPressed: () {
              widget.cubit.reworkTask(widget.task, reviewNotes: _note);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          // Terminal "Reject" — distinct from rework (no resubmit expected).
          TextButton(
            onPressed: () {
              widget.cubit.rejectTask(widget.task, reviewNotes: _note);
              Navigator.of(context).pop();
            },
            child: Text('Reject',
                style: AppTypography.label.copyWith(color: AppColors.error)),
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

/// The employee's submitted work shown to the reviewing manager: their notes and
/// the proof photo (if any). Renders nothing when there's neither.
class _SubmittedWork extends StatelessWidget {
  const _SubmittedWork({required this.task});
  final TaskEntity task;

  @override
  Widget build(BuildContext context) {
    final notes = task.notes ?? '';
    final media = latestAttachments(task);
    if (notes.isEmpty && media.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Container(
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
            Text('Submitted work', style: AppTypography.labelSmall),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(notes, style: AppTypography.bodySmall),
            ],
            if (media.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              AttachmentGallery(attachments: media, tileSize: 80),
            ],
          ],
        ),
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

/// "Assigned to" mode chip row (Employee / Team / Shift) — new tasks only.
/// Employee/Team both keep the existing [_AssigneePicker] (Team is a UX-level
/// alias for multi-select individual, same `assigneeIds` mechanism); Shift
/// swaps it for [ShiftChipPicker] (Shift Assignment feature).
class _AssignedToPicker extends StatelessWidget {
  const _AssignedToPicker({required this.value, required this.onChanged});
  final TaskAssignmentType value;
  final void Function(TaskAssignmentType) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.group_outlined,
                size: 16, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            Text('Assigned to', style: AppTypography.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final type in TaskAssignmentType.values)
              GestureDetector(
                onTap: () => onChanged(type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: value == type
                        ? AppColors.primary
                        : AppColors.darkSurfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: value == type
                          ? AppColors.primary
                          : AppColors.darkBorder,
                    ),
                  ),
                  child: Text(
                    type.label,
                    style: AppTypography.caption.copyWith(
                      color: value == type
                          ? AppColors.onPrimary
                          : AppColors.textSecondary,
                      fontWeight:
                          value == type ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Morning/Night shift chip picker, shown instead of [_AssigneePicker] when
/// "Shift" is the assigned-to mode (Shift Assignment feature) — the task
/// targets whoever is rostered on the picked shift, not named employees.
class ShiftChipPicker extends StatelessWidget {
  const ShiftChipPicker({super.key, required this.value, required this.onChanged});
  final ScheduleShift? value;
  final void Function(ScheduleShift) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule_rounded,
                size: 16, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            Text('Shift', style: AppTypography.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final shift in ScheduleShift.values)
              GestureDetector(
                onTap: () => onChanged(shift),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: value == shift
                        ? AppColors.primary
                        : AppColors.darkSurfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: value == shift
                          ? AppColors.primary
                          : AppColors.darkBorder,
                    ),
                  ),
                  child: Text(
                    '${shift.label} · ${shift.timeRange}',
                    style: AppTypography.caption.copyWith(
                      color: value == shift
                          ? AppColors.onPrimary
                          : AppColors.textSecondary,
                      fontWeight:
                          value == shift ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Once/Daily/Weekly repeat picker for a shift task — replaces
/// [_RecurrencePicker] only in shift mode. Once creates a single instance;
/// Daily/Weekly create a [RecurringTaskTemplateEntity] instead (via
/// `TaskCubit.createRecurringShiftTemplate`), so a weekday selector appears
/// when Weekly is picked.
class ShiftRepeatPicker extends StatelessWidget {
  const ShiftRepeatPicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.weekday,
    required this.onWeekdayChanged,
    this.modes = TemplateRepeatMode.values,
  });
  final TemplateRepeatMode value;
  final void Function(TemplateRepeatMode) onChanged;
  final int weekday;
  final void Function(int) onWeekdayChanged;

  /// Which repeat modes to offer — the task form offers all three (Once
  /// creates a single task); the recurring-template management sheet only
  /// offers Daily/Weekly (a template is never "once" by definition).
  final List<TemplateRepeatMode> modes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.repeat_rounded,
                size: 16, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            Text('Repeats', style: AppTypography.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final mode in modes)
              GestureDetector(
                onTap: () => onChanged(mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: value == mode
                        ? AppColors.primary
                        : AppColors.darkSurfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: value == mode
                          ? AppColors.primary
                          : AppColors.darkBorder,
                    ),
                  ),
                  child: Text(
                    mode.label,
                    style: AppTypography.caption.copyWith(
                      color: value == mode
                          ? AppColors.onPrimary
                          : AppColors.textSecondary,
                      fontWeight:
                          value == mode ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (value == TemplateRepeatMode.weekly) ...[
          const SizedBox(height: AppSpacing.md),
          WeekdayChipPicker(value: weekday, onChanged: onWeekdayChanged),
        ],
      ],
    );
  }
}

/// Mon–Sun weekday chip row for [ShiftRepeatPicker]'s Weekly mode
/// (`DateTime.monday` = 1 … `DateTime.sunday` = 7, matching
/// [RecurringTaskTemplateEntity.weekday]).
class WeekdayChipPicker extends StatelessWidget {
  const WeekdayChipPicker({super.key, required this.value, required this.onChanged});
  final int value;
  final void Function(int) onChanged;

  static const _labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      children: [
        for (var i = 0; i < 7; i++)
          GestureDetector(
            onTap: () => onChanged(i + 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 40,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: value == i + 1
                    ? AppColors.primary
                    : AppColors.darkSurfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: value == i + 1
                      ? AppColors.primary
                      : AppColors.darkBorder,
                ),
              ),
              child: Text(
                _labels[i],
                style: AppTypography.caption.copyWith(
                  color: value == i + 1
                      ? AppColors.onPrimary
                      : AppColors.textSecondary,
                  fontWeight:
                      value == i + 1 ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Compact recurrence selector: chips for None / Daily / Weekly / Monthly.
class _RecurrencePicker extends StatelessWidget {
  const _RecurrencePicker({required this.value, required this.onChanged});
  final RecurrenceFrequency value;
  final void Function(RecurrenceFrequency) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.repeat_rounded,
                size: 16, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            Text('Repeats', style: AppTypography.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final freq in RecurrenceFrequency.values)
              GestureDetector(
                onTap: () => onChanged(freq),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: value == freq
                        ? AppColors.primary
                        : AppColors.darkSurfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: value == freq
                          ? AppColors.primary
                          : AppColors.darkBorder,
                    ),
                  ),
                  child: Text(
                    freq.label,
                    style: AppTypography.caption.copyWith(
                      color: value == freq
                          ? AppColors.onPrimary
                          : AppColors.textSecondary,
                      fontWeight: value == freq
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
