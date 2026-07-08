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
import 'package:drop/core/widgets/app_motion.dart';
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
    final isNew = widget.existing == null;
    final shiftMode = _assignmentType == TaskAssignmentType.shift;

    // Each section (its group divider + content) fades + lifts in with a gentle
    // stagger, so opening the sheet feels like a workflow assembling rather than
    // a static form appearing.
    var step = 0;
    Widget section({String? label, IconData? icon, required Widget child}) {
      final body = label == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_SectionLabel(label, icon: icon), child],
            );
      return EntranceFade(delay: staggerDelay(step++), child: body);
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHeader(
            title: isNew ? 'New Task' : 'Edit Task',
            subtitle: isNew
                ? 'Compose the work, then choose who runs it.'
                : 'Update this task.',
          ),

          // ── Overview: the defining choice, then the essentials ──────────
          section(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Work type — the hero choice; regenerates the type-specific
              // fields below it. Locked (static card) in edit mode.
              WorkTypePicker(
                value: _workType,
                enabled: isNew,
                onChanged: (id) => setState(() {
                  _workType = id;
                  _workData = {}; // fields differ per type
                  _workFieldErrors = const {};
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _title,
                label: 'Title',
                prefixIcon: Icons.title_rounded,
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.md),
              // Type-specific fields (collapses to nothing for a general task).
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
                maxLines: 4,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
              ),
            ],
          )),

          // ── Steps: the checklist builder ────────────────────────────────
          section(
            label: 'Steps',
            icon: Icons.checklist_rounded,
            child: _ChecklistBuilder(
              controllers: _itemControllers,
              required: _itemRequired,
              onAdd: _addChecklistItem,
              onRemove: _removeChecklistItem,
              onToggleRequired: _toggleRequired,
            ),
          ),

          // ── Reference: "what good looks like" ───────────────────────────
          section(
            label: 'Reference',
            icon: Icons.image_outlined,
            child: AttachmentPickerField(
              attachments: _newRefs,
              allowVideo: false,
              title: 'Reference images',
              hint: 'Attach photos showing how this should look — the employee '
                  'sees them before starting. Photos are compressed before upload.',
              existing: _existingRefs,
              onRemoveExisting: (a) => setState(() => _existingRefs.remove(a)),
              onChanged: (list) => setState(() => _newRefs = list),
            ),
          ),

          // ── Assignment: branch, mode, and who ───────────────────────────
          section(
              label: 'Assignment',
              icon: Icons.group_outlined,
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isAdmin) ...[
                _BranchField(
                  future: _branchesFuture,
                  value: _branchId,
                  onChanged: (v) => setState(() {
                    _branchId = v;
                    _assignees.clear(); // employees differ per branch
                    _syncEmployeesFuture();
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (isNew) ...[
                const _FieldCaption('Assigned to'),
                const SizedBox(height: AppSpacing.sm),
                _Segmented<TaskAssignmentType>(
                  value: _assignmentType,
                  onChanged: (t) => setState(() => _assignmentType = t),
                  segments: [
                    for (final t in TaskAssignmentType.values)
                      _Seg(t, t.label, icon: _assignmentIcon(t)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (shiftMode)
                ShiftChipPicker(
                  value: _shift,
                  onChanged: (s) => setState(() => _shift = s),
                )
              else
                _AssigneeField(
                  future: _employeesFuture,
                  selected: _assignees,
                  onChanged: (next) => setState(() {
                    _assignees
                      ..clear()
                      ..addAll(next);
                  }),
                ),
            ],
          )),

          // ── Scheduling: priority, deadline, cadence ─────────────────────
          section(
              label: 'Scheduling',
              icon: Icons.event_note_outlined,
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FieldCaption('Priority'),
              const SizedBox(height: AppSpacing.sm),
              _Segmented<TaskPriority>(
                value: _priority,
                onChanged: (v) => setState(() => _priority = v),
                segments: const [
                  _Seg(TaskPriority.low, 'Low',
                      icon: Icons.arrow_downward_rounded),
                  _Seg(TaskPriority.normal, 'Normal',
                      icon: Icons.remove_rounded),
                  _Seg(TaskPriority.high, 'High',
                      icon: Icons.priority_high_rounded),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _DeadlineField(
                value: _deadline,
                onPick: _pickDeadline,
                onQuick: (d) => setState(() => _deadline = d),
                onClear: () => setState(() => _deadline = null),
              ),
              // Recurrence (new tasks only) — shift mode gets its own
              // Once/Daily/Weekly picker (daily/weekly saves as a recurring
              // shift-task template rather than a single task).
              if (isNew) ...[
                const SizedBox(height: AppSpacing.md),
                if (shiftMode)
                  ShiftRepeatPicker(
                    value: _shiftRepeat,
                    onChanged: (v) => setState(() => _shiftRepeat = v),
                    weekday: _shiftWeekday,
                    onWeekdayChanged: (w) =>
                        setState(() => _shiftWeekday = w),
                  )
                else ...[
                  const _FieldCaption('Repeats'),
                  const SizedBox(height: AppSpacing.sm),
                  _Segmented<RecurrenceFrequency>(
                    value: _recurrence,
                    onChanged: (v) => setState(() => _recurrence = v),
                    segments: const [
                      _Seg(RecurrenceFrequency.none, 'None'),
                      _Seg(RecurrenceFrequency.daily, 'Daily'),
                      _Seg(RecurrenceFrequency.weekly, 'Weekly'),
                      _Seg(RecurrenceFrequency.monthly, 'Monthly'),
                    ],
                  ),
                ],
              ],
            ],
          )),

          // ── Validation + submit ─────────────────────────────────────────
          _FormErrorBanner(message: _error),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: isNew ? 'Create Task' : 'Save Changes',
            icon: const Icon(Icons.check_rounded,
                size: 20, color: AppColors.onAccent),
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  static IconData _assignmentIcon(TaskAssignmentType t) => switch (t) {
        TaskAssignmentType.individual => Icons.person_outline_rounded,
        TaskAssignmentType.team => Icons.groups_2_outlined,
        TaskAssignmentType.shift => Icons.schedule_rounded,
      };
}

/// Branch picker for the admin task form — loads active branches from Firestore
/// and surfaces the choice as a premium summary tile that opens a searchable
/// chooser sheet (never a bare dropdown, so a long branch list stays scannable).
class _BranchField extends StatelessWidget {
  const _BranchField({
    required this.future,
    required this.value,
    required this.onChanged,
  });

  final Future<List<BranchEntity>> future;
  final String? value;
  final ValueChanged<String?> onChanged;

  static String _label(BranchEntity b) =>
      (b.location == null || b.location!.isEmpty)
          ? b.name
          : '${b.name} · ${b.location}';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BranchEntity>>(
      future: future,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final branches = snap.data ?? const <BranchEntity>[];
        BranchEntity? selected;
        for (final b in branches) {
          if (b.id == value) selected = b;
        }
        final ready = !loading && branches.isNotEmpty;
        return _PickerTile(
          icon: Icons.store_mall_directory_outlined,
          label: 'Branch',
          value: selected == null ? null : _label(selected),
          placeholder: loading
              ? 'Loading branches…'
              : branches.isEmpty
                  ? 'No branches — create one first'
                  : 'Select a branch',
          enabled: ready,
          onTap: () async {
            final picked = await showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.darkSurface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) =>
                  _BranchPickerSheet(branches: branches, selectedId: value),
            );
            if (picked != null) onChanged(picked);
          },
        );
      },
    );
  }
}

/// Searchable branch chooser opened from [_BranchField].
class _BranchPickerSheet extends StatefulWidget {
  const _BranchPickerSheet({required this.branches, required this.selectedId});
  final List<BranchEntity> branches;
  final String? selectedId;

  @override
  State<_BranchPickerSheet> createState() => _BranchPickerSheetState();
}

class _BranchPickerSheetState extends State<_BranchPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final items = q.isEmpty
        ? widget.branches
        : [
            for (final b in widget.branches)
              if ('${b.name} ${b.location ?? ''}'.toLowerCase().contains(q)) b,
          ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.md,
        AppSpacing.pagePadding,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: AppSpacing.sm),
          Text('Select branch', style: AppTypography.h3),
          const SizedBox(height: 2),
          Text('Where this work happens', style: AppTypography.caption),
          const SizedBox(height: AppSpacing.md),
          if (widget.branches.length > 6) ...[
            AppTextField(
              controller: _search,
              label: 'Search branches',
              prefixIcon: Icons.search_rounded,
              textInputAction: TextInputAction.search,
              onChanged: (s) => setState(() => _query = s),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final b = items[i];
                return _BranchRow(
                  branch: b,
                  selected: b.id == widget.selectedId,
                  onTap: () => Navigator.of(context).pop(b.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchRow extends StatelessWidget {
  const _BranchRow({
    required this.branch,
    required this.selected,
    required this.onTap,
  });
  final BranchEntity branch;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasLocation =
        branch.location != null && branch.location!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lgAll,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primarySurface
              : AppColors.darkSurfaceElevated,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.darkBorder),
        ),
        child: Row(
          children: [
            const _LeadIcon(icon: Icons.store_mall_directory_outlined),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(branch.name,
                      style: AppTypography.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (hasLocation) ...[
                    const SizedBox(height: 1),
                    Text(branch.location!,
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? AppColors.primary : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Premium checklist builder used inside the task creation / edit form — turns
/// the work into numbered, ordered steps (each optionally *required*). The
/// parent [_TaskFormSheetState] owns all state (controllers, required flags,
/// ids); this widget is stateless and just renders + calls back.
class _ChecklistBuilder extends StatelessWidget {
  const _ChecklistBuilder({
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
    final empty = controllers.isEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Break the work into steps',
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.textSecondary)),
              if (!empty) ...[
                const SizedBox(width: AppSpacing.sm),
                _CountPill(controllers.length),
              ],
            ],
          ),
          // Animated so adding / removing a step glides instead of snapping.
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: empty
                ? const _ChecklistEmpty()
                : Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Column(
                      children: [
                        for (var i = 0; i < controllers.length; i++)
                          _StepRow(
                            key: ValueKey('ci_$i'),
                            index: i + 1,
                            controller: controllers[i],
                            isRequired: required[i],
                            onToggleRequired: () => onToggleRequired(i),
                            onRemove: () => onRemove(i),
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _AddStepButton(onTap: onAdd),
        ],
      ),
    );
  }
}

/// Empty state for the checklist builder — a quiet nudge, never a wall of text.
class _ChecklistEmpty extends StatelessWidget {
  const _ChecklistEmpty();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        'Optional — add ordered steps the employee ticks off as they work.',
        style:
            AppTypography.caption.copyWith(color: AppColors.textTertiary),
      ),
    );
  }
}

/// A single editable, numbered step inside [_ChecklistBuilder].
class _StepRow extends StatelessWidget {
  const _StepRow({
    super.key,
    required this.index,
    required this.controller,
    required this.isRequired,
    required this.onToggleRequired,
    required this.onRemove,
  });

  final int index;
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
          // Step number — a quiet ordinal badge instead of a fake drag handle.
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.darkBg,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Text('$index',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Describe this step…',
                hintStyle: AppTypography.bodySmall
                    .copyWith(color: AppColors.textTertiary),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 10),
                filled: true,
                fillColor: AppColors.darkBg,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.smAll,
                  borderSide: const BorderSide(color: AppColors.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.smAll,
                  borderSide: const BorderSide(color: AppColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.smAll,
                  borderSide:
                      const BorderSide(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Required toggle: filled star = required, outline = optional.
          Tooltip(
            message: isRequired
                ? 'Required — tap to make optional'
                : 'Optional — tap to make required',
            child: IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              onPressed: onToggleRequired,
              icon: Icon(
                isRequired ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 18,
                color: isRequired
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded,
                size: 18, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Full-width dashed "add a step" affordance at the foot of the builder.
class _AddStepButton extends StatelessWidget {
  const _AddStepButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smAll,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.darkBg,
          borderRadius: AppRadius.smAll,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Text('Add step',
                style: AppTypography.labelSmall
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// A small count chip (e.g. `3`) used by section builders.
class _CountPill extends StatelessWidget {
  const _CountPill(this.count);
  final int count;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Text('$count', style: AppTypography.caption),
    );
  }
}

/// Assign-on-create field shown inside the task form — a summary tile (stacked
/// avatars + count) that opens a searchable multi-select sheet. State (the
/// selected set + the loaded future) lives on [_TaskFormSheetState]; this widget
/// renders + returns the new selection through [onChanged].
class _AssigneeField extends StatelessWidget {
  const _AssigneeField({
    required this.future,
    required this.selected,
    required this.onChanged,
  });

  final Future<List<UserEntity>>? future;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  static String _name(UserEntity u) =>
      (u.displayName != null && u.displayName!.isNotEmpty)
          ? u.displayName!
          : u.email;

  @override
  Widget build(BuildContext context) {
    if (future == null) {
      return const _PickerTile(
        icon: Icons.group_add_outlined,
        label: 'Assignees',
        placeholder: 'Pick a branch first',
        enabled: false,
      );
    }
    return FutureBuilder<List<UserEntity>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _PickerTile(
            icon: Icons.group_add_outlined,
            label: 'Assignees',
            placeholder: 'Loading team…',
            enabled: false,
          );
        }
        final employees = snap.data ?? const <UserEntity>[];
        if (employees.isEmpty) {
          return const _PickerTile(
            icon: Icons.group_add_outlined,
            label: 'Assignees',
            placeholder: 'No employees in this branch yet',
            enabled: false,
          );
        }
        final chosen = [
          for (final u in employees)
            if (selected.contains(u.uid)) u,
        ];
        final value = chosen.isEmpty
            ? null
            : chosen.length == 1
                ? _name(chosen.first)
                : '${chosen.length} people';
        return _PickerTile(
          icon: Icons.group_add_outlined,
          label: 'Assignees',
          value: value,
          placeholder: 'Unassigned — pick who runs it',
          leading: chosen.isEmpty ? null : _AvatarStack(users: chosen),
          onTap: () async {
            final result = await showModalBottomSheet<Set<String>>(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.darkSurface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) =>
                  _AssigneePickerSheet(employees: employees, initial: selected),
            );
            if (result != null) onChanged(result);
          },
        );
      },
    );
  }
}

/// Overlapping avatar cluster (up to 3 faces + a `+N` overflow) shown as the
/// leading glyph of the assignee tile once someone is picked.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.users});
  final List<UserEntity> users;

  static const double _size = 30;
  static const double _step = 19;

  @override
  Widget build(BuildContext context) {
    const maxFaces = 3;
    final faces = users.take(maxFaces).toList();
    final extra = users.length - faces.length;
    final slots = faces.length + (extra > 0 ? 1 : 0);
    final width = _size + (slots - 1) * _step;
    return SizedBox(
      width: width,
      height: _size,
      child: Stack(
        children: [
          for (var i = 0; i < faces.length; i++)
            Positioned(
              left: i * _step,
              child: _ringed(child: UserAvatar.fromUser(faces[i], size: 26)),
            ),
          if (extra > 0)
            Positioned(
              left: faces.length * _step,
              child: _ringed(
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.darkBg,
                    shape: BoxShape.circle,
                  ),
                  child: Text('+$extra',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ringed({required Widget child}) => Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: AppColors.darkSurface,
          shape: BoxShape.circle,
        ),
        child: child,
      );
}

/// Searchable multi-select employee chooser opened from [_AssigneeField]. Owns a
/// local working set and returns it on "Done" (or null if dismissed), so the
/// form only commits a deliberate selection.
class _AssigneePickerSheet extends StatefulWidget {
  const _AssigneePickerSheet({required this.employees, required this.initial});
  final List<UserEntity> employees;
  final Set<String> initial;

  @override
  State<_AssigneePickerSheet> createState() => _AssigneePickerSheetState();
}

class _AssigneePickerSheetState extends State<_AssigneePickerSheet> {
  late final Set<String> _sel = {...widget.initial};
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _name(UserEntity u) =>
      (u.displayName != null && u.displayName!.isNotEmpty)
          ? u.displayName!
          : u.email;

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final items = q.isEmpty
        ? widget.employees
        : [
            for (final u in widget.employees)
              if ('${_name(u)} ${u.email}'.toLowerCase().contains(q)) u,
          ];
    final allSelected = widget.employees.isNotEmpty &&
        widget.employees.every((u) => _sel.contains(u.uid));
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.md,
        AppSpacing.pagePadding,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: AppSpacing.sm),
          Text('Assign employees', style: AppTypography.h3),
          const SizedBox(height: 2),
          Text('Choose who runs this work', style: AppTypography.caption),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _QuickAction(
                icon: Icons.groups_2_outlined,
                label: allSelected ? 'Team selected' : 'Whole team',
                active: allSelected,
                onTap: () => setState(() {
                  if (allSelected) {
                    _sel.clear();
                  } else {
                    _sel.addAll(widget.employees.map((u) => u.uid));
                  }
                }),
              ),
              const SizedBox(width: AppSpacing.sm),
              _QuickAction(
                icon: Icons.person_off_outlined,
                label: 'Clear',
                active: false,
                onTap: _sel.isEmpty ? null : () => setState(_sel.clear),
              ),
            ],
          ),
          if (widget.employees.length > 6) ...[
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _search,
              label: 'Search team',
              prefixIcon: Icons.search_rounded,
              textInputAction: TextInputAction.search,
              onChanged: (s) => setState(() => _query = s),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, i) {
                final u = items[i];
                final selected = _sel.contains(u.uid);
                return _AssigneeRow(
                  name: _name(u),
                  email: u.email,
                  avatar: UserAvatar.fromUser(u, size: 38),
                  selected: selected,
                  onTap: () => setState(() {
                    if (selected) {
                      _sel.remove(u.uid);
                    } else {
                      _sel.add(u.uid);
                    }
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: _sel.isEmpty ? 'Done' : 'Assign ${_sel.length}',
            onPressed: () => Navigator.of(context).pop(_sel),
          ),
        ],
      ),
    );
  }
}

/// One selectable employee row inside [_AssigneePickerSheet].
class _AssigneeRow extends StatelessWidget {
  const _AssigneeRow({
    required this.name,
    required this.email,
    required this.avatar,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String email;
  final Widget avatar;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: AppTypography.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(email,
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: selected ? AppColors.success : AppColors.textTertiary,
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

// ─── Premium form primitives ─────────────────────────────────────
// A small, cohesive kit shared across the create sheet so every section reads
// as one system: a hero header, group dividers, a sliding segmented control,
// summary picker tiles, the deadline field and an animated validation banner.

/// The sheet's hero header — title + a one-line intent, so the form opens like
/// a workflow builder rather than a bare "New Task".
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.h2),
          const SizedBox(height: 2),
          Text(subtitle, style: AppTypography.caption),
        ],
      ),
    );
  }
}

/// A group divider — a small labelled heading with a trailing hairline that
/// visually partitions the long form into scannable sections.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            label.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(child: Divider(color: AppColors.darkBorder, height: 1)),
        ],
      ),
    );
  }
}

/// A small caption above a control (e.g. above a segmented control).
class _FieldCaption extends StatelessWidget {
  const _FieldCaption(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: AppTypography.labelSmall
          .copyWith(color: AppColors.textSecondary));
}

/// The soft rounded 36px icon tile that leads a [_PickerTile] / list row.
class _LeadIcon extends StatelessWidget {
  const _LeadIcon({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child:
          Icon(icon, size: 18, color: AppColors.textSecondary),
    );
  }
}

/// A tappable summary row — a leading glyph, a label, and the current value (or
/// a muted placeholder). The house replacement for dropdown-style selectors:
/// the *value* stays visible in the form; the *choosing* happens in a sheet.
class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    this.value,
    this.placeholder,
    this.leading,
    this.onTap,
    this.onClear,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? placeholder;
  final Widget? leading;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final filled = value != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppRadius.xlAll,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: AppRadius.xlAll,
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            children: [
              leading ?? _LeadIcon(icon: icon),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textTertiary)),
                    const SizedBox(height: 2),
                    Text(
                      filled ? value! : (placeholder ?? ''),
                      style: AppTypography.body.copyWith(
                        color: filled
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                        fontWeight: filled ? FontWeight.w500 : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (onClear != null && filled)
                GestureDetector(
                  onTap: onClear,
                  behavior: HitTestBehavior.opaque,
                  child: const Icon(Icons.close_rounded,
                      size: 18, color: AppColors.textTertiary),
                )
              else if (enabled)
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// The optional-deadline control — a summary tile plus quick "Today / Tomorrow /
/// Next week" chips, so the common cases are one tap and precise dates stay one
/// tap deeper (progressive disclosure). Empty by default; nothing is imposed.
class _DeadlineField extends StatelessWidget {
  const _DeadlineField({
    required this.value,
    required this.onPick,
    required this.onQuick,
    required this.onClear,
  });

  final DateTime? value;
  final VoidCallback onPick;
  final ValueChanged<DateTime> onQuick;
  final VoidCallback onClear;

  static String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final quicks = <(String, DateTime)>[
      ('Today', today),
      ('Tomorrow', today.add(const Duration(days: 1))),
      ('Next week', today.add(const Duration(days: 7))),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PickerTile(
          icon: Icons.event_outlined,
          label: 'Deadline',
          value: value == null ? null : _fmt(value!),
          placeholder: 'No deadline',
          onTap: onPick,
          onClear: onClear,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (label, date) in quicks)
              _MiniChip(
                label: label,
                selected: value != null && _sameDay(value!, date),
                onTap: () => onQuick(date),
              ),
          ],
        ),
      ],
    );
  }
}

/// A compact selectable chip for quick presets (e.g. deadline shortcuts).
class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.darkSurfaceElevated,
          borderRadius: AppRadius.fullAll,
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.darkBorder),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? AppColors.onPrimary : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// One option in a [_Segmented] control.
class _Seg<T> {
  const _Seg(this.value, this.label, {this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// A premium iOS-style segmented control with a sliding thumb — the house
/// replacement for a short single-choice dropdown (priority, assignment mode,
/// recurrence). Equal-width segments; the white thumb eases to the selection.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<_Seg<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final n = segments.length;
    final index = segments.indexWhere((s) => s.value == value);
    // Align.x for equal-width slots: -1 at slot 0 … +1 at slot n-1.
    final thumbX = n <= 1 ? 0.0 : (2 * (index < 0 ? 0 : index) / (n - 1)) - 1;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Stack(
        children: [
          if (index >= 0)
            Positioned.fill(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: Alignment(thumbX, 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  heightFactor: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (final seg in segments)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(seg.value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: _SegLabel(seg: seg, selected: seg.value == value),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegLabel extends StatelessWidget {
  const _SegLabel({required this.seg, required this.selected});
  final _Seg seg;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.onPrimary : AppColors.textSecondary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (seg.icon != null) ...[
          Icon(seg.icon, size: 15, color: color),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(seg.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }
}

/// Animated, monochrome-friendly validation banner shown above the CTA. Slides
/// open when a message arrives and collapses cleanly when it clears, so an error
/// reads as a deliberate moment rather than red text jumping in.
class _FormErrorBanner extends StatelessWidget {
  const _FormErrorBanner({required this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: EntranceFade(
                offset: 8,
                duration: const Duration(milliseconds: 220),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorSurface,
                    borderRadius: AppRadius.lgAll,
                    border: Border.all(color: AppColors.error.withAlpha(90)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 18, color: AppColors.error),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(message!,
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.error)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// Morning/Night shift chip picker, shown instead of [_AssigneeField] when
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

