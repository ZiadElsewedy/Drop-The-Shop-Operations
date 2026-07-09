part of '../task_action_sheets.dart';

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

  late DateTime? _startsAt = widget.existing?.startsAt;
  late DateTime? _deadline = widget.existing?.deadline;

  /// The shift the schedule was suggested from (Scheduling V2). **Persists**
  /// through customization so the banner can show "Originally: …" + Reset —
  /// cleared only when the shift/assignees no longer resolve to one.
  ScheduleShift? _scheduleSource;

  /// True once the manager edited either time away from the suggestion.
  bool _scheduleCustom = false;

  /// The assignees are rostered on **different** shifts — prompt for a choice
  /// instead of auto-filling.
  bool _mixedShifts = false;

  /// A rostered-shift resolve is in flight (async schedule read).
  bool _resolvingShift = false;

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
    // Scheduling V2 — a due-before-start window is invalid (an outside-shift
    // window is only a non-blocking warning, so it does not stop here).
    final scheduleError = _scheduleError;
    if (scheduleError != null) {
      setState(() => _error = scheduleError);
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
            startsAt: _startsAt,
            deadline: _deadline,
            checklist: checklist,
            referenceAttachments: _newRefs,
            assignmentType: TaskAssignmentType.shift,
            shift: _shift,
            instanceDate: _startsAt ?? _deadline,
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
          startsAt: _startsAt,
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
          startsAt: _startsAt,
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

  /// Pick a full date **and** time (Task Scheduling V2 — start/due carry a time,
  /// not just a date). Cancelling the time step keeps the current time-of-day.
  Future<DateTime?> _pickDateTime(DateTime? current) async {
    final now = DateTime.now();
    final base = current ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    final t = time ?? TimeOfDay.fromDateTime(base);
    return DateTime(date.year, date.month, date.day, t.hour, t.minute);
  }

  Future<void> _pickStart() async {
    final dt = await _pickDateTime(_startsAt);
    if (dt != null) {
      // Manual edit → custom (the source is kept so the banner can offer Reset).
      setState(() {
        _startsAt = dt;
        _scheduleCustom = true;
      });
    }
  }

  Future<void> _pickDue() async {
    final dt = await _pickDateTime(_deadline);
    if (dt != null) {
      setState(() {
        _deadline = dt;
        _scheduleCustom = true;
      });
    }
  }

  /// The effective branch for schedule lookups (admin picks; manager is fixed).
  String get _effectiveBranchId =>
      (widget.isAdmin ? _branchId : widget.defaultBranchId)?.trim() ?? '';

  /// Apply [shift]'s standard hours as the smart-default window for the current
  /// day (keeps any date already chosen; overnight ends roll to the next day).
  void _suggestFromShift(ScheduleShift shift) {
    final date = _startsAt ?? _deadline ?? DateTime.now();
    final def = shiftDefaultSchedule(date, shift);
    _startsAt = def.start;
    _deadline = def.due;
    _scheduleSource = shift;
    _scheduleCustom = false;
  }

  void _resetToSource() {
    final shift = _scheduleSource;
    if (shift != null) setState(() => _suggestFromShift(shift));
  }

  /// Resolve the rostered shift of the current (individual/team) assignees and
  /// pre-fill the schedule as a smart default: a unanimous shift is suggested,
  /// mixed shifts prompt a choice, none leaves it manual. Best-effort + async.
  Future<void> _resolveAssigneeSchedule() async {
    if (_assignmentType == TaskAssignmentType.shift) return;
    final uids = _assignees.toList();
    final branchId = _effectiveBranchId;
    if (uids.isEmpty || branchId.isEmpty) {
      setState(() => _mixedShifts = false);
      return;
    }
    setState(() => _resolvingShift = true);
    final date = _startsAt ?? _deadline ?? DateTime.now();
    final res = await widget.cubit
        .resolveAssigneeShift(branchId: branchId, uids: uids, date: date);
    if (!mounted) return;
    setState(() {
      _resolvingShift = false;
      switch (res.fit) {
        case AssigneeShiftFit.unanimous:
          _mixedShifts = false;
          if (_scheduleCustom) {
            _scheduleSource = res.shift; // keep the manager's times, update banner
          } else {
            _suggestFromShift(res.shift!);
          }
        case AssigneeShiftFit.mixed:
          _mixedShifts = true;
          if (!_scheduleCustom) _scheduleSource = null; // ambiguous → user chooses
        case AssigneeShiftFit.none:
          _mixedShifts = false;
      }
    });
  }

  /// The banner's suggestion source (e.g. "Morning shift · 08:30 – 16:30"), or
  /// null when no shift resolved.
  String? get _scheduleSourceLabel {
    final shift = _scheduleSource;
    if (shift == null) return null;
    final date = _startsAt ?? _deadline ?? DateTime.now();
    final hours = ShiftHours.standard(ScheduleDay.fromDate(date), shift);
    return '${shift.label} shift · ${hours.format()}';
  }

  /// Blocking validation — a due time at/before the start. Absolute instants, so
  /// a legitimate overnight window (start 23:00 → due 03:00 next day) passes.
  String? get _scheduleError {
    final s = _startsAt, d = _deadline;
    if (s != null && d != null && !d.isAfter(s)) {
      return 'The due time must be after the start time.';
    }
    return null;
  }

  /// Non-blocking advisory — a custom schedule that falls outside the source
  /// shift's hours (keep the user in control; never prevents saving).
  String? get _scheduleWarning {
    final shift = _scheduleSource;
    final s = _startsAt, d = _deadline;
    if (shift == null || !_scheduleCustom || s == null || d == null) return null;
    final window = shiftDefaultSchedule(s, shift);
    if (s.isBefore(window.start) || d.isAfter(window.due)) {
      final hours = ShiftHours.standard(ScheduleDay.fromDate(s), shift);
      return 'Outside ${shift.label} shift hours (${hours.format()})';
    }
    return null;
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
                  onChanged: (t) {
                    setState(() {
                      _assignmentType = t;
                      if (t == TaskAssignmentType.shift) _mixedShifts = false;
                    });
                    // Switching to individual/team re-resolves the roster.
                    if (t != TaskAssignmentType.shift) {
                      _resolveAssigneeSchedule();
                    }
                  },
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
                  onChanged: (s) => setState(() {
                    _shift = s;
                    // Picking a shift pre-fills the schedule as a smart default
                    // (never a lock — the manager can still edit or reset).
                    _suggestFromShift(s);
                  }),
                )
              else
                _AssigneeField(
                  future: _employeesFuture,
                  selected: _assignees,
                  onChanged: (next) {
                    setState(() {
                      _assignees
                        ..clear()
                        ..addAll(next);
                    });
                    // Pre-fill the schedule from the assignees' rostered shift.
                    _resolveAssigneeSchedule();
                  },
                ),
            ],
          )),

          // ── Schedule: when the work starts and is due ───────────────────
          section(
              label: 'Schedule',
              icon: Icons.event_note_outlined,
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_mixedShifts) ...[
                _MixedShiftChooser(
                  onPick: (shift) => setState(() {
                    _suggestFromShift(shift);
                    _mixedShifts = false;
                  }),
                  onCustom: () => setState(() => _mixedShifts = false),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _ScheduleField(
                start: _startsAt,
                due: _deadline,
                resolving: _resolvingShift,
                onPickStart: _pickStart,
                onPickDue: _pickDue,
                onClearStart: () => setState(() {
                  _startsAt = null;
                  _scheduleCustom = true;
                }),
                onClearDue: () => setState(() {
                  _deadline = null;
                  _scheduleCustom = true;
                }),
                sourceLabel: _scheduleSourceLabel,
                custom: _scheduleCustom && _scheduleSource != null,
                onReset: _scheduleSource == null ? null : _resetToSource,
                warning: _scheduleWarning,
                error: _scheduleError,
              ),
            ],
          )),

          // ── Review: how it's prioritised and whether it repeats ─────────
          section(
              label: 'Review',
              icon: Icons.fact_check_outlined,
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

          // ── Attachments: "what good looks like" ─────────────────────────
          section(
            label: 'Attachments',
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

