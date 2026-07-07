import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/auth/presentation/widgets/app_text_field.dart';
import 'package:drop/features/task/domain/work_types/work_field_spec.dart';
import 'package:drop/features/task/domain/work_types/work_type_definition.dart';
import 'package:drop/features/task/domain/work_types/work_type_registry.dart';
import 'package:drop/features/task/presentation/work_type_presenter.dart';

/// The **work-type selector** at the top of the create form. Picks the kind of
/// work (which regenerates the dynamic fields below). Locked to a single
/// read-only chip in edit mode — a task's fundamental kind never changes
/// mid-life (same stance as the assignment-type selector).
class WorkTypePicker extends StatelessWidget {
  const WorkTypePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final registry = WorkTypeRegistry.instance;
    final selected = registry.byId(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.category_outlined,
                size: 16, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            Text('Work type', style: AppTypography.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (enabled)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final def in registry.all)
                _TypeChip(
                  icon: WorkTypePresenter.iconFor(def.id),
                  label: def.label,
                  selected: def.id == value,
                  onTap: () => onChanged(def.id),
                ),
            ],
          )
        else
          _TypeChip(
            icon: WorkTypePresenter.iconFor(selected.id),
            label: selected.label,
            selected: true,
            onTap: () {},
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(selected.blurb,
            style: AppTypography.caption
                .copyWith(color: AppColors.textTertiary)),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.primary : AppColors.darkSurfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.darkBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color:
                    selected ? AppColors.onPrimary : AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: selected ? AppColors.onPrimary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders the dynamic fields a [WorkTypeDefinition] declares, driven purely by
/// its [WorkFieldSpec]s — the create screen never hardcodes a type's inputs.
/// Owns its own controllers (rebuilt when the type changes) and reports the full
/// value map up via [onChanged]. `errors` (keyed by field key) highlights
/// setup-validation failures inline.
class DynamicWorkForm extends StatefulWidget {
  const DynamicWorkForm({
    super.key,
    required this.definition,
    required this.onChanged,
    this.fields,
    this.initialData = const {},
    this.errors = const {},
  });

  final WorkTypeDefinition definition;

  /// The exact fields to render — defaults to the type's setup fields on the
  /// create form; the details screen passes [WorkTypeDefinition.completionFields].
  final List<WorkFieldSpec>? fields;

  final Map<String, dynamic> initialData;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final Map<String, String> errors;

  List<WorkFieldSpec> get resolvedFields => fields ?? definition.setupFields;

  @override
  State<DynamicWorkForm> createState() => _DynamicWorkFormState();
}

class _DynamicWorkFormState extends State<DynamicWorkForm> {
  late Map<String, dynamic> _data;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _seed();
  }

  @override
  void didUpdateWidget(covariant DynamicWorkForm old) {
    super.didUpdateWidget(old);
    // A new work type = a new field set. Rebuild controllers from the (reset)
    // initialData the parent hands down.
    if (old.definition.id != widget.definition.id) {
      _disposeControllers();
      _seed();
    }
  }

  void _seed() {
    _data = {...widget.initialData};
    for (final f in widget.resolvedFields) {
      if (_usesController(f.kind)) {
        _controllers[f.key] =
            TextEditingController(text: _display(_data[f.key]));
      }
    }
  }

  void _disposeControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  bool _usesController(WorkFieldKind kind) =>
      kind == WorkFieldKind.text ||
      kind == WorkFieldKind.multiline ||
      kind == WorkFieldKind.number ||
      kind == WorkFieldKind.integer ||
      kind == WorkFieldKind.currency;

  static String _display(dynamic v) => v == null ? '' : '$v';

  void _set(String key, dynamic value) {
    setState(() {
      if (value == null) {
        _data.remove(key);
      } else {
        _data[key] = value;
      }
    });
    widget.onChanged(Map<String, dynamic>.of(_data));
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.resolvedFields;
    if (fields.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final f in fields)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _field(f),
          ),
      ],
    );
  }

  Widget _field(WorkFieldSpec f) {
    final control = switch (f.kind) {
      WorkFieldKind.text || WorkFieldKind.multiline => _textField(f),
      WorkFieldKind.number ||
      WorkFieldKind.integer ||
      WorkFieldKind.currency =>
        _numberField(f),
      WorkFieldKind.date => _dateField(f),
      WorkFieldKind.time => _timeField(f),
      WorkFieldKind.toggle => _toggleField(f),
      WorkFieldKind.select => _selectField(f),
    };
    final err = widget.errors[f.key];
    if (err == null) return control;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        control,
        const SizedBox(height: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: Text(err,
              style:
                  AppTypography.caption.copyWith(color: AppColors.error)),
        ),
      ],
    );
  }

  String _label(WorkFieldSpec f) =>
      f.required ? f.label : '${f.label} (optional)';

  Widget _textField(WorkFieldSpec f) {
    final multiline = f.kind == WorkFieldKind.multiline;
    return AppTextField(
      controller: _controllers[f.key]!,
      label: _label(f),
      hint: f.hint,
      prefixIcon: WorkTypePresenter.iconForField(f.kind),
      maxLines: multiline ? 4 : 1,
      minLines: multiline ? 2 : 1,
      keyboardType:
          multiline ? TextInputType.multiline : TextInputType.text,
      textInputAction:
          multiline ? TextInputAction.newline : TextInputAction.next,
      onChanged: (s) => _set(f.key, s.isEmpty ? null : s),
    );
  }

  Widget _numberField(WorkFieldSpec f) {
    final isInteger = f.kind == WorkFieldKind.integer;
    return AppTextField(
      controller: _controllers[f.key]!,
      label: _label(f),
      hint: f.hint,
      prefixIcon: WorkTypePresenter.iconForField(f.kind),
      keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
      inputFormatters: [
        if (isInteger)
          FilteringTextInputFormatter.digitsOnly
        else
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      onChanged: (s) {
        final num? v = isInteger ? int.tryParse(s) : num.tryParse(s);
        _set(f.key, v);
      },
    );
  }

  Widget _dateField(WorkFieldSpec f) {
    final value = _data[f.key];
    final dt = value is DateTime ? value : null;
    return _pickerBox(
      icon: WorkTypePresenter.iconForField(f.kind),
      text: dt == null ? _label(f) : '${f.label}: ${_dateLabel(dt)}',
      placeholder: dt == null,
      onClear: dt == null ? null : () => _set(f.key, null),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: dt ?? now,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 3),
        );
        if (picked != null) _set(f.key, picked);
      },
    );
  }

  Widget _timeField(WorkFieldSpec f) {
    final value = _data[f.key];
    final dt = value is DateTime ? value : null;
    return _pickerBox(
      icon: WorkTypePresenter.iconForField(f.kind),
      text: dt == null ? _label(f) : '${f.label}: ${_timeLabel(dt)}',
      placeholder: dt == null,
      onClear: dt == null ? null : () => _set(f.key, null),
      onTap: () async {
        final now = TimeOfDay.now();
        final picked = await showTimePicker(
          context: context,
          initialTime: dt == null ? now : TimeOfDay.fromDateTime(dt),
        );
        if (picked != null) {
          final d = DateTime.now();
          _set(f.key, DateTime(d.year, d.month, d.day, picked.hour, picked.minute));
        }
      },
    );
  }

  Widget _toggleField(WorkFieldSpec f) {
    final on = _data[f.key] == true;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Icon(WorkTypePresenter.iconForField(f.kind),
              size: 20, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(f.label, style: AppTypography.body)),
          Switch(
            value: on,
            onChanged: (v) => _set(f.key, v),
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _selectField(WorkFieldSpec f) {
    final selected = _data[f.key];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_label(f), style: AppTypography.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final opt in f.options)
              _TypeChip(
                icon: Icons.check_rounded,
                label: opt.label,
                selected: selected == opt.value,
                onTap: () => _set(
                    f.key, selected == opt.value ? null : opt.value),
              ),
          ],
        ),
      ],
    );
  }

  Widget _pickerBox({
    required IconData icon,
    required String text,
    required bool placeholder,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
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
            Icon(icon, size: 20, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                text,
                style: AppTypography.body.copyWith(
                  color: placeholder
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textTertiary),
              ),
          ],
        ),
      ),
    );
  }

  static String _dateLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _timeLabel(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
