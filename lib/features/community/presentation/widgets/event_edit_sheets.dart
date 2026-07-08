import 'package:flutter/material.dart';
import 'package:drop/core/enums/event_phase.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/community/domain/entities/event_sections.dart';
import 'package:drop/features/community/presentation/cubit/event_workspace_cubit.dart';

/// All the bottom-sheet editors for the event workspace, isolated so the
/// workspace screen stays about layout. Each opens a compact, keyboard-safe sheet
/// and drives one [EventWorkspaceCubit] mutation. Monochrome, premium, minimal —
/// one thing per sheet.
class EventEditSheets {
  EventEditSheets._();

  static Future<void> addMilestone(
          BuildContext context, EventWorkspaceCubit cubit) =>
      _open(context, _AddMilestoneSheet(cubit));

  static Future<void> addTask(
          BuildContext context, EventWorkspaceCubit cubit) =>
      _open(context, _AddTaskSheet(cubit));

  static Future<void> addTeam(
          BuildContext context, EventWorkspaceCubit cubit) =>
      _open(context, _AddTeamSheet(cubit));

  static Future<void> addInventory(
          BuildContext context, EventWorkspaceCubit cubit) =>
      _open(context, _AddInventorySheet(cubit));

  static Future<void> addLogistics(
          BuildContext context, EventWorkspaceCubit cubit) =>
      _open(context, _AddLogisticsSheet(cubit));

  static Future<void> addBudget(
          BuildContext context, EventWorkspaceCubit cubit) =>
      _open(context, _AddBudgetSheet(cubit));

  static Future<void> announce(
          BuildContext context, EventWorkspaceCubit cubit) =>
      _open(context, _AnnounceSheet(cubit));

  static Future<void> setActual(
          BuildContext context, EventWorkspaceCubit cubit, EventBudgetLine line) =>
      _open(context, _SetActualSheet(cubit, line));

  static Future<void> editDetails(
          BuildContext context, EventWorkspaceCubit cubit, current) =>
      _open(context, _EditDetailsSheet(cubit, current));

  static Future<void> editOutcome(BuildContext context,
          EventWorkspaceCubit cubit, EventOutcome? current) =>
      _open(context, _OutcomeSheet(cubit, current));

  static Future<void> _open(BuildContext context, Widget child) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => child,
      );
}

/// Shared sheet chrome: grabber, title, and keyboard-safe scroll body.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.darkBorder)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.md,
        bottom: AppSpacing.xl + inset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: AppTypography.h2),
          const SizedBox(height: AppSpacing.lg),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The full-width primary save button, disabled until [enabled].
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

TextField _field(
  TextEditingController c, {
  required String hint,
  int maxLines = 1,
  TextInputType? keyboardType,
  TextCapitalization capitalization = TextCapitalization.sentences,
  ValueChanged<String>? onChanged,
}) =>
    TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      onChanged: onChanged,
      style: AppTypography.body.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(hintText: hint),
    );

Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.md),
      child: Text(text.toUpperCase(),
          style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600)),
    );

// ─── Milestone ──────────────────────────────────────────────────────────
class _AddMilestoneSheet extends StatefulWidget {
  const _AddMilestoneSheet(this.cubit);
  final EventWorkspaceCubit cubit;
  @override
  State<_AddMilestoneSheet> createState() => _AddMilestoneSheetState();
}

class _AddMilestoneSheetState extends State<_AddMilestoneSheet> {
  final _c = TextEditingController();
  EventPhase _phase = EventPhase.planning;
  DateTime? _due;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Add milestone',
      children: [
        _field(_c, hint: 'e.g. Confirm venue booking', onChanged: (_) => setState(() {})),
        _label('Phase'),
        _ChipRow<EventPhase>(
          values: EventPhase.values,
          selected: _phase,
          labelOf: (p) => p.label,
          onSelect: (p) => setState(() => _phase = p),
        ),
        _label('Due date'),
        _DatePickRow(date: _due, onPick: (d) => setState(() => _due = d)),
        const SizedBox(height: AppSpacing.xl),
        _SaveButton(
          label: 'Add milestone',
          onPressed: _c.text.trim().isEmpty
              ? null
              : () {
                  widget.cubit.addMilestone(_c.text, phase: _phase, dueAt: _due);
                  Navigator.of(context).pop();
                },
        ),
      ],
    );
  }
}

// ─── Task ───────────────────────────────────────────────────────────────
class _AddTaskSheet extends StatefulWidget {
  const _AddTaskSheet(this.cubit);
  final EventWorkspaceCubit cubit;
  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _title = TextEditingController();
  final _owner = TextEditingController();
  TaskPriority _priority = TaskPriority.normal;
  DateTime? _due;

  @override
  void dispose() {
    _title.dispose();
    _owner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Add task',
      children: [
        _field(_title, hint: 'What needs doing?', onChanged: (_) => setState(() {})),
        _label('Priority'),
        _ChipRow<TaskPriority>(
          values: TaskPriority.values,
          selected: _priority,
          labelOf: (p) => _priorityLabel(p),
          onSelect: (p) => setState(() => _priority = p),
        ),
        _label('Owner (optional)'),
        _field(_owner, hint: 'Who owns it?', capitalization: TextCapitalization.words),
        _label('Due date'),
        _DatePickRow(date: _due, onPick: (d) => setState(() => _due = d)),
        const SizedBox(height: AppSpacing.xl),
        _SaveButton(
          label: 'Add task',
          onPressed: _title.text.trim().isEmpty
              ? null
              : () {
                  final owner = _owner.text.trim();
                  widget.cubit.addTask(
                    _title.text,
                    priority: _priority,
                    ownerName: owner.isEmpty ? null : owner,
                    dueAt: _due,
                  );
                  Navigator.of(context).pop();
                },
        ),
      ],
    );
  }
}

// ─── Team ───────────────────────────────────────────────────────────────
class _AddTeamSheet extends StatefulWidget {
  const _AddTeamSheet(this.cubit);
  final EventWorkspaceCubit cubit;
  @override
  State<_AddTeamSheet> createState() => _AddTeamSheetState();
}

class _AddTeamSheetState extends State<_AddTeamSheet> {
  final _name = TextEditingController();
  final _role = TextEditingController();
  final _dept = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _dept.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Assign someone',
      children: [
        _label('Name'),
        _field(_name, hint: 'Team member', capitalization: TextCapitalization.words, onChanged: (_) => setState(() {})),
        _label('Responsibility'),
        _field(_role, hint: 'e.g. Setup Lead, Floor Host'),
        _label('Department (optional)'),
        _field(_dept, hint: 'e.g. Visual, Retail, Marketing'),
        const SizedBox(height: AppSpacing.xl),
        _SaveButton(
          label: 'Add to team',
          onPressed: _name.text.trim().isEmpty
              ? null
              : () {
                  final dept = _dept.text.trim();
                  widget.cubit.addTeamMember(
                    _name.text,
                    role: _role.text,
                    department: dept.isEmpty ? null : dept,
                  );
                  Navigator.of(context).pop();
                },
        ),
      ],
    );
  }
}

// ─── Inventory ──────────────────────────────────────────────────────────
class _AddInventorySheet extends StatefulWidget {
  const _AddInventorySheet(this.cubit);
  final EventWorkspaceCubit cubit;
  @override
  State<_AddInventorySheet> createState() => _AddInventorySheetState();
}

class _AddInventorySheetState extends State<_AddInventorySheet> {
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _qty = TextEditingController(text: '1');

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Add item',
      children: [
        _label('Item'),
        _field(_name, hint: 'e.g. Product rack, Uniforms, Banner', onChanged: (_) => setState(() {})),
        _label('Category (optional)'),
        _field(_category, hint: 'e.g. Product, Decor, Marketing'),
        _label('Quantity'),
        _field(_qty, hint: '1', keyboardType: TextInputType.number, capitalization: TextCapitalization.none),
        const SizedBox(height: AppSpacing.xl),
        _SaveButton(
          label: 'Add item',
          onPressed: _name.text.trim().isEmpty
              ? null
              : () {
                  widget.cubit.addInventory(
                    _name.text,
                    category: _category.text,
                    quantity: int.tryParse(_qty.text.trim()) ?? 1,
                  );
                  Navigator.of(context).pop();
                },
        ),
      ],
    );
  }
}

// ─── Logistics ──────────────────────────────────────────────────────────
class _AddLogisticsSheet extends StatefulWidget {
  const _AddLogisticsSheet(this.cubit);
  final EventWorkspaceCubit cubit;
  @override
  State<_AddLogisticsSheet> createState() => _AddLogisticsSheetState();
}

class _AddLogisticsSheetState extends State<_AddLogisticsSheet> {
  final _title = TextEditingController();
  final _detail = TextEditingController();
  final _vendor = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    _vendor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Add logistics',
      children: [
        _label('What'),
        _field(_title, hint: 'e.g. Transport, Security, Power, Internet', onChanged: (_) => setState(() {})),
        _label('Detail (optional)'),
        _field(_detail, hint: 'Notes'),
        _label('Vendor (optional)'),
        _field(_vendor, hint: 'Supplier / contact', capitalization: TextCapitalization.words),
        const SizedBox(height: AppSpacing.xl),
        _SaveButton(
          label: 'Add logistics',
          onPressed: _title.text.trim().isEmpty
              ? null
              : () {
                  final detail = _detail.text.trim();
                  final vendor = _vendor.text.trim();
                  widget.cubit.addLogistics(
                    _title.text,
                    detail: detail.isEmpty ? null : detail,
                    vendor: vendor.isEmpty ? null : vendor,
                  );
                  Navigator.of(context).pop();
                },
        ),
      ],
    );
  }
}

// ─── Budget ─────────────────────────────────────────────────────────────
class _AddBudgetSheet extends StatefulWidget {
  const _AddBudgetSheet(this.cubit);
  final EventWorkspaceCubit cubit;
  @override
  State<_AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends State<_AddBudgetSheet> {
  final _lineLabel = TextEditingController();
  final _est = TextEditingController();
  final _category = TextEditingController();

  @override
  void dispose() {
    _lineLabel.dispose();
    _est.dispose();
    _category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Add budget line',
      children: [
        _label('Line'),
        _field(_lineLabel,
            hint: 'e.g. Catering, Print, Staff',
            onChanged: (_) => setState(() {})),
        _label('Estimated cost'),
        _field(_est,
            hint: '0',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            capitalization: TextCapitalization.none,
            onChanged: (_) => setState(() {})),
        _label('Category (optional)'),
        _field(_category, hint: 'e.g. Marketing, Operations'),
        const SizedBox(height: AppSpacing.xl),
        _SaveButton(
          label: 'Add line',
          onPressed: _lineLabel.text.trim().isEmpty
              ? null
              : () {
                  final cat = _category.text.trim();
                  widget.cubit.addBudgetLine(
                    _lineLabel.text,
                    estimated: double.tryParse(_est.text.trim()) ?? 0,
                    category: cat.isEmpty ? null : cat,
                  );
                  Navigator.of(context).pop();
                },
        ),
      ],
    );
  }
}

// ─── Set actual (budget) ────────────────────────────────────────────────
class _SetActualSheet extends StatefulWidget {
  const _SetActualSheet(this.cubit, this.line);
  final EventWorkspaceCubit cubit;
  final EventBudgetLine line;
  @override
  State<_SetActualSheet> createState() => _SetActualSheetState();
}

class _SetActualSheetState extends State<_SetActualSheet> {
  late final TextEditingController _c =
      TextEditingController(text: widget.line.actual?.toStringAsFixed(0) ?? '');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Actual — ${widget.line.label}',
      children: [
        _field(_c,
            hint: 'Actual amount spent',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            capitalization: TextCapitalization.none),
        const SizedBox(height: AppSpacing.xl),
        _SaveButton(
          label: 'Save',
          onPressed: () {
            final v = double.tryParse(_c.text.trim());
            widget.cubit.setBudgetActual(widget.line.id, v);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

// ─── Announcement ───────────────────────────────────────────────────────
class _AnnounceSheet extends StatefulWidget {
  const _AnnounceSheet(this.cubit);
  final EventWorkspaceCubit cubit;
  @override
  State<_AnnounceSheet> createState() => _AnnounceSheetState();
}

class _AnnounceSheetState extends State<_AnnounceSheet> {
  final _c = TextEditingController();
  bool _important = false;
  bool _pinned = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Post an update',
      children: [
        _field(_c,
            hint: 'Share an update with the team…',
            maxLines: 4,
            onChanged: (_) => setState(() {})),
        const SizedBox(height: AppSpacing.md),
        _ToggleRow(
          label: 'Mark important',
          value: _important,
          onChanged: (v) => setState(() => _important = v),
        ),
        _ToggleRow(
          label: 'Pin to top',
          value: _pinned,
          onChanged: (v) => setState(() => _pinned = v),
        ),
        const SizedBox(height: AppSpacing.xl),
        _SaveButton(
          label: 'Post update',
          onPressed: _c.text.trim().isEmpty
              ? null
              : () {
                  widget.cubit.postAnnouncement(_c.text,
                      important: _important, pinned: _pinned);
                  Navigator.of(context).pop();
                },
        ),
      ],
    );
  }
}

// ─── Edit details ───────────────────────────────────────────────────────
class _EditDetailsSheet extends StatefulWidget {
  const _EditDetailsSheet(this.cubit, this.current);
  final EventWorkspaceCubit cubit;
  final dynamic current; // EventEntity
  @override
  State<_EditDetailsSheet> createState() => _EditDetailsSheetState();
}

class _EditDetailsSheetState extends State<_EditDetailsSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.current.title as String);
  late final TextEditingController _desc =
      TextEditingController(text: widget.current.description as String);
  late final TextEditingController _loc =
      TextEditingController(text: (widget.current.location as String?) ?? '');
  late final TextEditingController _att = TextEditingController(
      text: (widget.current.expectedAttendance as int?)?.toString() ?? '');
  late DateTime? _start = widget.current.startAt as DateTime?;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _loc.dispose();
    _att.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Edit details',
      children: [
        _label('Title'),
        _field(_title, hint: 'Event title', capitalization: TextCapitalization.words, onChanged: (_) => setState(() {})),
        _label('Description'),
        _field(_desc, hint: 'What is this event?', maxLines: 3),
        _label('Location'),
        _field(_loc, hint: 'Venue / address'),
        _label('Date'),
        _DatePickRow(date: _start, onPick: (d) => setState(() => _start = d), withTime: true),
        _label('Expected attendance'),
        _field(_att, hint: 'e.g. 150', keyboardType: TextInputType.number, capitalization: TextCapitalization.none),
        const SizedBox(height: AppSpacing.xl),
        _SaveButton(
          label: 'Save details',
          onPressed: _title.text.trim().isEmpty
              ? null
              : () {
                  widget.cubit.updateDetails(
                    title: _title.text.trim(),
                    description: _desc.text.trim(),
                    location: _loc.text.trim(),
                    startAt: _start,
                    expectedAttendance: int.tryParse(_att.text.trim()),
                  );
                  Navigator.of(context).pop();
                },
        ),
      ],
    );
  }
}

// ─── Outcome (after event) ──────────────────────────────────────────────
class _OutcomeSheet extends StatefulWidget {
  const _OutcomeSheet(this.cubit, this.current);
  final EventWorkspaceCubit cubit;
  final EventOutcome? current;
  @override
  State<_OutcomeSheet> createState() => _OutcomeSheetState();
}

class _OutcomeSheetState extends State<_OutcomeSheet> {
  late final _revenue = TextEditingController(
      text: widget.current?.revenue?.toStringAsFixed(0) ?? '');
  late final _visitors =
      TextEditingController(text: widget.current?.visitors?.toString() ?? '');
  late final _sold = TextEditingController(
      text: widget.current?.productsSold?.toString() ?? '');
  late final _summary =
      TextEditingController(text: widget.current?.summary ?? '');
  late final _wins =
      TextEditingController(text: (widget.current?.wins ?? []).join('\n'));
  late final _lessons =
      TextEditingController(text: (widget.current?.lessons ?? []).join('\n'));
  late final _recs = TextEditingController(
      text: (widget.current?.recommendations ?? []).join('\n'));

  @override
  void dispose() {
    _revenue.dispose();
    _visitors.dispose();
    _sold.dispose();
    _summary.dispose();
    _wins.dispose();
    _lessons.dispose();
    _recs.dispose();
    super.dispose();
  }

  List<String> _lines(TextEditingController c) => c.text
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'After the event',
      children: [
        Row(
          children: [
            Expanded(
                child: _field(_revenue,
                    hint: 'Revenue',
                    keyboardType: TextInputType.number,
                    capitalization: TextCapitalization.none)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
                child: _field(_visitors,
                    hint: 'Visitors',
                    keyboardType: TextInputType.number,
                    capitalization: TextCapitalization.none)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _field(_sold,
            hint: 'Products sold',
            keyboardType: TextInputType.number,
            capitalization: TextCapitalization.none),
        _label('Summary'),
        _field(_summary, hint: 'How did it go?', maxLines: 3),
        _label('Wins (one per line)'),
        _field(_wins, hint: 'What went well', maxLines: 3),
        _label('Lessons (one per line)'),
        _field(_lessons, hint: 'What we learned', maxLines: 3),
        _label('Recommendations (one per line)'),
        _field(_recs, hint: 'For next time', maxLines: 3),
        const SizedBox(height: AppSpacing.xl),
        _SaveButton(
          label: 'Save summary',
          onPressed: () {
            widget.cubit.saveOutcome(EventOutcome(
              revenue: double.tryParse(_revenue.text.trim()),
              visitors: int.tryParse(_visitors.text.trim()),
              productsSold: int.tryParse(_sold.text.trim()),
              summary: _summary.text.trim(),
              wins: _lines(_wins),
              lessons: _lines(_lessons),
              recommendations: _lines(_recs),
            ));
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

// ─── Small shared controls ──────────────────────────────────────────────
class _ChipRow<T> extends StatelessWidget {
  const _ChipRow({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final v in values)
          _Choice(
            label: labelOf(v),
            active: v == selected,
            onTap: () => onSelect(v),
          ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice(
      {required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.fullAll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.darkSurfaceElevated,
          borderRadius: AppRadius.fullAll,
          border: Border.all(
              color: active ? AppColors.primary : AppColors.darkBorder),
        ),
        child: Text(label,
            style: AppTypography.labelSmall.copyWith(
                color: active ? AppColors.onPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _DatePickRow extends StatelessWidget {
  const _DatePickRow(
      {required this.date, required this.onPick, this.withTime = false});
  final DateTime? date;
  final ValueChanged<DateTime?> onPick;
  final bool withTime;

  @override
  Widget build(BuildContext context) {
    final label = date == null
        ? 'No date'
        : '${date!.day}/${date!.month}/${date!.year}'
            '${withTime ? ' · ${_t(date!)}' : ''}';
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: date ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 3),
              );
              if (picked == null) return;
              var result = picked;
              if (withTime && context.mounted) {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(date ?? now),
                );
                if (time != null) {
                  result = DateTime(picked.year, picked.month, picked.day,
                      time.hour, time.minute);
                }
              }
              onPick(result);
            },
            borderRadius: AppRadius.mdAll,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.darkSurfaceElevated,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(label,
                      style: AppTypography.label
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ),
        if (date != null) ...[
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            onPressed: () => onPick(null),
            icon: const Icon(Icons.close_rounded,
                size: 18, color: AppColors.textTertiary),
          ),
        ],
      ],
    );
  }

  static String _t(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow(
      {required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTypography.label)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.onPrimary,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

String _priorityLabel(TaskPriority p) => switch (p) {
      TaskPriority.low => 'Low',
      TaskPriority.normal => 'Normal',
      TaskPriority.high => 'High',
    };
