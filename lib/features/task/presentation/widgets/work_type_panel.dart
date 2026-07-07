import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/auth/presentation/widgets/app_button.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/work_types/definitions/inspection_work_type.dart';
import 'package:drop/features/task/domain/work_types/task_work_x.dart';
import 'package:drop/features/task/domain/work_types/work_field_spec.dart';
import 'package:drop/features/task/domain/work_types/work_review.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/widgets/dynamic_work_form.dart';

/// The **adaptive** section of the task details screen — everything specific to
/// the task's work type, driven entirely by its `WorkTypeDefinition`. The screen
/// injects one of these and never branches on the type: this panel asks the
/// definition for its fields, milestones, inspection points, summary and review
/// disposition.
///
/// Renders (only the parts a given type has):
///  * a one-line **summary / metric** (+ a manager "auto-approvable" hint),
///  * **setup details** the creator captured (read-only),
///  * **inspection points** (pass/warning/fail per checklist point),
///  * **completion capture** (the employee's fields — counted qty, amount spent),
///  * the **milestone spine** (a transfer's dispatch → receive handshake).
class WorkTypePanel extends StatelessWidget {
  const WorkTypePanel({
    super.key,
    required this.task,
    required this.cubit,
    required this.interactive,
    this.showReviewHint = false,
  });

  final TaskEntity task;
  final TaskCubit cubit;

  /// The executing employee, with the task still open for work (`started`).
  final bool interactive;

  /// A manager/admin is viewing — surface the review disposition.
  final bool showReviewHint;

  /// Whether this task's type has anything type-specific to show at all (a
  /// general task does not — the panel then renders nothing, so it looks exactly
  /// as tasks do today).
  static bool hasContentFor(TaskEntity task) {
    final def = task.workDefinition;
    return def.fields.isNotEmpty ||
        def.timeline.isNotEmpty ||
        def.usesChecklistAsPoints;
  }

  @override
  Widget build(BuildContext context) {
    if (!hasContentFor(task)) return const SizedBox.shrink();
    final def = task.workDefinition;
    final ctx = task.workContext;
    final setup = def.setupFields
        .where((f) => task.data[f.key] != null)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary / metric headline.
        Row(
          children: [
            Expanded(
              child: Text(def.summarize(ctx, title: task.title),
                  style: AppTypography.body
                      .copyWith(color: AppColors.textPrimary)),
            ),
            if (showReviewHint &&
                task.status.index >= 1 &&
                def.reviewDisposition(ctx) == ReviewDisposition.fastTrack)
              const _FastTrackChip(),
          ],
        ),

        if (setup.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _KeyValues(fields: setup, data: task.data),
        ],

        if (def.usesChecklistAsPoints) ...[
          const SizedBox(height: AppSpacing.lg),
          _InspectionPoints(
            task: task,
            cubit: cubit,
            interactive: interactive,
          ),
        ],

        if (def.completionFields.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          if (interactive)
            _CompletionCapture(task: task, cubit: cubit)
          else
            _RecordedCompletion(task: task),
        ],

        if (def.timeline.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _MilestoneSpine(task: task, cubit: cubit, interactive: interactive),
        ],
      ],
    );
  }
}

class _FastTrackChip extends StatelessWidget {
  const _FastTrackChip();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded,
                size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text('Auto-approvable',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
}

/// Read-only label:value list for captured fields.
class _KeyValues extends StatelessWidget {
  const _KeyValues({required this.fields, required this.data});
  final List<WorkFieldSpec> fields;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final f in fields)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(f.label,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiary)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(formatWorkValue(data[f.key]),
                      style: AppTypography.body
                          .copyWith(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RecordedCompletion extends StatelessWidget {
  const _RecordedCompletion({required this.task});
  final TaskEntity task;
  @override
  Widget build(BuildContext context) {
    final fields = task.workDefinition.completionFields
        .where((f) => task.data[f.key] != null)
        .toList(growable: false);
    if (fields.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubLabel('Recorded'),
        const SizedBox(height: AppSpacing.sm),
        _KeyValues(fields: fields, data: task.data),
      ],
    );
  }
}

/// The employee's completion-field editor (buffered → Save), reusing the same
/// dynamic form as the create screen.
class _CompletionCapture extends StatefulWidget {
  const _CompletionCapture({required this.task, required this.cubit});
  final TaskEntity task;
  final TaskCubit cubit;
  @override
  State<_CompletionCapture> createState() => _CompletionCaptureState();
}

class _CompletionCaptureState extends State<_CompletionCapture> {
  late Map<String, dynamic> _buffer = {...widget.task.data};

  @override
  Widget build(BuildContext context) {
    final def = widget.task.workDefinition;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubLabel('Record'),
        const SizedBox(height: AppSpacing.sm),
        DynamicWorkForm(
          definition: def,
          fields: def.completionFields,
          initialData: widget.task.data,
          onChanged: (data) => _buffer = data,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: AppButton(
            label: 'Save',
            variant: AppButtonVariant.secondary,
            onPressed: () {
              final patch = <String, dynamic>{
                for (final f in def.completionFields) f.key: _buffer[f.key],
              };
              widget.cubit.updateWorkData(widget.task, patch);
            },
          ),
        ),
      ],
    );
  }
}

/// Per-point pass/warning/fail marking for an inspection (points = the task's
/// checklist items; results live in `data['results']`).
class _InspectionPoints extends StatelessWidget {
  const _InspectionPoints({
    required this.task,
    required this.cubit,
    required this.interactive,
  });
  final TaskEntity task;
  final TaskCubit cubit;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    const def = InspectionWorkType();
    final ctx = task.workContext;
    if (task.checklist.isEmpty) {
      return Text('No inspection points yet.',
          style:
              AppTypography.caption.copyWith(color: AppColors.textTertiary));
    }
    final results =
        (task.data[InspectionWorkType.kResults] as Map?)?.cast<String, dynamic>() ??
            const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubLabel('Inspection points'),
        const SizedBox(height: AppSpacing.sm),
        for (final item in task.checklist)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: AppTypography.body),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final r in InspectionResult.values)
                      _ResultChip(
                        result: r,
                        selected: def.resultFor(ctx, item.id) == r,
                        onTap: interactive
                            ? () => _mark(results, item.id, r)
                            : null,
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _mark(Map<String, dynamic> current, String itemId, InspectionResult r) {
    final next = {...current};
    // Tapping the selected result again clears it.
    if (next[itemId] == r.value) {
      next.remove(itemId);
    } else {
      next[itemId] = r.value;
    }
    cubit.updateWorkData(task, {InspectionWorkType.kResults: next});
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({
    required this.result,
    required this.selected,
    required this.onTap,
  });
  final InspectionResult result;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Monochrome by default; only a failure carries the sanctioned attention
    // red (per the design system — colour for the destructive/attention case).
    final accent =
        result == InspectionResult.fail ? AppColors.error : AppColors.primary;
    final bg = selected ? accent : AppColors.darkSurfaceElevated;
    final fg = selected ? AppColors.onPrimary : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null && !selected ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected ? accent : AppColors.darkBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, size: 13, color: fg),
              const SizedBox(width: 4),
              Text(_label,
                  style: AppTypography.caption.copyWith(
                    color: fg,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.normal,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  IconData get _icon => switch (result) {
        InspectionResult.pass => Icons.check_rounded,
        InspectionResult.warning => Icons.warning_amber_rounded,
        InspectionResult.fail => Icons.close_rounded,
      };

  String get _label => switch (result) {
        InspectionResult.pass => 'Pass',
        InspectionResult.warning => 'Warn',
        InspectionResult.fail => 'Fail',
      };
}

/// The ordered milestone spine (e.g. Dispatched → Received). The employee logs
/// the next pending milestone; everyone sees what's done.
class _MilestoneSpine extends StatelessWidget {
  const _MilestoneSpine({
    required this.task,
    required this.cubit,
    required this.interactive,
  });
  final TaskEntity task;
  final TaskCubit cubit;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final def = task.workDefinition;
    final ctx = task.workContext;
    final timeline = def.timeline;
    final nextIndex = timeline.indexWhere((e) => !ctx.hasEvent(e.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubLabel('Progress'),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < timeline.length; i++)
          Builder(builder: (_) {
            final e = timeline[i];
            final done = ctx.hasEvent(e.id);
            final isNext = i == nextIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(
                    done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: done
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.label,
                            style: AppTypography.body.copyWith(
                              color: done
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            )),
                        if (e.actorHint != null)
                          Text(e.actorHint!,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textTertiary)),
                      ],
                    ),
                  ),
                  if (interactive && isNext)
                    GestureDetector(
                      onTap: () => cubit.logWorkEvent(task, eventId: e.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_task_rounded,
                                size: 14, color: AppColors.onPrimary),
                            const SizedBox(width: 5),
                            Text('Log',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.onPrimary,
                                  fontWeight: FontWeight.w700,
                                )),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _SubLabel extends StatelessWidget {
  const _SubLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: AppColors.textTertiary,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
        ),
      );
}

/// Presentation formatting for a captured `data` value (dates, money, bools).
String formatWorkValue(dynamic v) {
  if (v == null) return '—';
  if (v is bool) return v ? 'Yes' : 'No';
  if (v is DateTime) {
    return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
  }
  return '$v';
}
