import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/enums/template_repeat_mode.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/metric_pill.dart';
import 'package:drop/features/auth/presentation/widgets/app_button.dart';
import 'package:drop/features/auth/presentation/widgets/app_text_field.dart';
import 'package:drop/features/task/domain/entities/checklist_item.dart';
import 'package:drop/features/task/domain/entities/recurring_task_template_entity.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/widgets/task_action_sheets.dart';

/// Branch-scoped Automation Center for recurring shift-task templates.
/// Supports create, pause/resume, delete, operational metadata, and navigation
/// to the last generated task while reusing the existing sheet entrypoint and
/// recurring-task workflow.
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
  if (action?.taskId != null && context.mounted) {
    await context.push<void>(RouteNames.taskDetail(action!.taskId!));
  } else if (action?.shouldAdd == true && context.mounted) {
    await showSheet<bool>(
      context,
      _RecurringShiftTaskForm(cubit: cubit, branchId: branchId),
    );
  }
}

class _RecurringManageAction {
  const _RecurringManageAction._({this.shouldAdd = false, this.taskId});

  static const add = _RecurringManageAction._(shouldAdd: true);

  factory _RecurringManageAction.openTask(String taskId) =>
      _RecurringManageAction._(taskId: taskId);

  final bool shouldAdd;
  final String? taskId;
}

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
      if (mounted) _reload();
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
      if (mounted) _reload();
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(context, 'Could not delete the recurring task.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _add() => Navigator.of(context).pop(_RecurringManageAction.add);

  void _openTask(String taskId) =>
      Navigator.of(context).pop(_RecurringManageAction.openTask(taskId));

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AutomationCenterHeader(),
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
            if (snap.hasError) {
              return _AutomationLoadFailure(onRetry: _busy ? null : _reload);
            }
            return _AutomationCenterBody(
              templates: snap.data ?? const [],
              busy: _busy,
              onAdd: _add,
              onToggle: _toggleActive,
              onDelete: _delete,
              onOpenTask: _openTask,
            );
          },
        ),
      ],
    );
  }
}

class _AutomationCenterHeader extends StatelessWidget {
  const _AutomationCenterHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Automation Center', style: AppTypography.h3),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Manage recurring shift routines for this branch.',
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AutomationCenterBody extends StatelessWidget {
  const _AutomationCenterBody({
    required this.templates,
    required this.busy,
    required this.onAdd,
    required this.onToggle,
    required this.onDelete,
    required this.onOpenTask,
  });

  final List<RecurringTaskTemplateEntity> templates;
  final bool busy;
  final VoidCallback onAdd;
  final ValueChanged<RecurringTaskTemplateEntity> onToggle;
  final ValueChanged<RecurringTaskTemplateEntity> onDelete;
  final ValueChanged<String> onOpenTask;

  @override
  Widget build(BuildContext context) {
    final isEmpty = templates.isEmpty;
    final maxListHeight = (MediaQuery.sizeOf(context).height * 0.58).clamp(
      300.0,
      560.0,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isEmpty)
          const _AutomationEmptyState()
        else ...[
          _AutomationSummary(templates: templates),
          const SizedBox(height: AppSpacing.lg),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxListHeight),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: templates.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final template = templates[index];
                return _AutomationCard(
                  template: template,
                  busy: busy,
                  onToggle: () => onToggle(template),
                  onDelete: () => onDelete(template),
                  onOpenTask: template.lastGeneratedTaskId == null
                      ? null
                      : () => onOpenTask(template.lastGeneratedTaskId!),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Create Automation',
          icon: const Icon(
            Icons.add_rounded,
            size: 20,
            color: AppColors.textDark,
          ),
          onPressed: busy ? null : onAdd,
        ),
      ],
    );
  }
}

class _AutomationSummary extends StatelessWidget {
  const _AutomationSummary({required this.templates});

  final List<RecurringTaskTemplateEntity> templates;

  @override
  Widget build(BuildContext context) {
    final active = templates.where((template) => template.active).length;
    final paused = templates.length - active;
    final nextRuns =
        templates
            .where((template) => template.active && template.nextRunAt != null)
            .map((template) => template.nextRunAt!)
            .toList()
          ..sort();
    final nextLabel = nextRuns.isEmpty
        ? 'Not scheduled'
        : _nextAutomationLabel(nextRuns.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            MetricPill(
              value: '$active',
              label: 'Active',
              icon: Icons.play_circle_outline_rounded,
            ),
            MetricPill(
              value: '$paused',
              label: 'Paused',
              icon: Icons.pause_circle_outline_rounded,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _NextAutomationSummary(value: nextLabel),
      ],
    );
  }
}

class _NextAutomationSummary extends StatelessWidget {
  const _NextAutomationSummary({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next automation check',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AutomationEmptyState extends StatelessWidget {
  const _AutomationEmptyState();

  @override
  Widget build(BuildContext context) {
    return const GlassContainer(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          children: [
            Icon(
              Icons.auto_awesome_motion_rounded,
              size: 28,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'Automate repetitive branch tasks.',
              style: AppTypography.labelLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Recurring routines automatically create shift tasks for your team.',
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AutomationLoadFailure extends StatelessWidget {
  const _AutomationLoadFailure({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text(
              'Automation details could not be loaded.',
              style: AppTypography.bodySmall,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _AutomationCard extends StatelessWidget {
  const _AutomationCard({
    required this.template,
    required this.busy,
    required this.onToggle,
    required this.onDelete,
    this.onOpenTask,
  });

  final RecurringTaskTemplateEntity template;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onOpenTask;

  @override
  Widget build(BuildContext context) {
    final nextCheck = template.active
        ? _nextAutomationLabel(template.nextRunAt)
        : 'Paused • no publish scheduled';
    return GlassContainer(
      key: ValueKey('automation-card-${template.id}'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.title,
                      style: AppTypography.labelLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _AutomationStatusChip(template: template),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Semantics(
                label: template.active
                    ? 'Pause ${template.title}'
                    : 'Activate ${template.title}',
                child: Switch(
                  key: ValueKey('automation-toggle-${template.id}'),
                  value: template.active,
                  onChanged: busy ? null : (_) => onToggle(),
                  activeTrackColor: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _AutomationDetailsGrid(
            schedule: _repeatLabel(template),
            shift: '${template.shift.label} shift',
            nextCheck: nextCheck,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AutomationDetail(
            icon: Icons.access_time_rounded,
            label: 'Shift window',
            value: '${template.shift.label} shift hours',
            detail: 'Exact start and end are not available yet.',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _MissedPolicyNote(),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, color: AppColors.darkBorder),
          const SizedBox(height: AppSpacing.lg),
          _LastOutcome(template: template),
          if (template.lastGeneratedTaskId != null) ...[
            const SizedBox(height: AppSpacing.md),
            _LastGeneratedTaskLink(
              key: ValueKey('automation-last-task-${template.id}'),
              title: template.title,
              meta: _lastGeneratedTaskMeta(template),
              onTap: onOpenTask,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: ValueKey('automation-delete-${template.id}'),
              onPressed: busy ? null : onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 17),
              label: const Text('Delete'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textTertiary,
                textStyle: AppTypography.caption,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutomationStatusChip extends StatelessWidget {
  const _AutomationStatusChip({required this.template});

  final RecurringTaskTemplateEntity template;

  @override
  Widget build(BuildContext context) {
    final failed =
        template.failureCount > 0 ||
        template.lastStatus?.toLowerCase() == 'failed';
    final (label, icon, color) = !template.active
        ? ('Paused', Icons.pause_rounded, AppColors.textSecondary)
        : failed
        ? ('Error', Icons.error_outline_rounded, AppColors.error)
        : ('Active', Icons.circle_rounded, AppColors.success);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: color.withAlpha(72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AutomationDetailsGrid extends StatelessWidget {
  const _AutomationDetailsGrid({
    required this.schedule,
    required this.shift,
    required this.nextCheck,
  });

  final String schedule;
  final String shift;
  final String nextCheck;

  @override
  Widget build(BuildContext context) {
    final scheduleCard = _AutomationDetail(
      icon: Icons.event_repeat_rounded,
      label: 'Schedule',
      value: schedule,
      detail: shift,
    );
    final nextCard = _AutomationDetail(
      icon: Icons.schedule_send_rounded,
      label: 'Next automation check',
      value: nextCheck,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 500) {
          return Column(
            children: [
              scheduleCard,
              const SizedBox(height: AppSpacing.sm),
              nextCard,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: scheduleCard),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: nextCard),
          ],
        );
      },
    );
  }
}

class _AutomationDetail extends StatelessWidget {
  const _AutomationDetail({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(detail!, style: AppTypography.caption),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissedPolicyNote extends StatelessWidget {
  const _MissedPolicyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: AppRadius.mdAll,
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.textTertiary,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Missed policy · Not enabled',
                  style: AppTypography.labelSmall,
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'Generated tasks stay open after the shift until someone handles them.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LastOutcome extends StatelessWidget {
  const _LastOutcome({required this.template});

  final RecurringTaskTemplateEntity template;

  @override
  Widget build(BuildContext context) {
    final status = template.lastStatus?.toLowerCase();
    final failed = template.failureCount > 0 || status == 'failed';
    final String outcome;
    final String detail;
    final IconData icon;
    final Color color;

    if (failed) {
      outcome = 'Last generation failed';
      detail = template.failureCount > 1
          ? '${template.failureCount} consecutive failures'
          : _lastRunLabel(template.lastRunAt);
      icon = Icons.error_outline_rounded;
      color = AppColors.error;
    } else if (template.lastRunAt == null && status == null) {
      outcome = 'Never run';
      detail = 'No generation outcome yet';
      icon = Icons.hourglass_empty_rounded;
      color = AppColors.textTertiary;
    } else if (status == 'skipped') {
      outcome = 'Already generated';
      detail =
          'No duplicate task was created • ${_lastRunLabel(template.lastRunAt)}';
      icon = Icons.task_alt_rounded;
      color = AppColors.textSecondary;
    } else if (status == 'completed') {
      outcome = template.lastGeneratedTaskId == null
          ? 'Generation completed'
          : 'Generated successfully';
      detail = _lastRunLabel(template.lastRunAt);
      icon = Icons.check_circle_outline_rounded;
      color = AppColors.textSecondary;
    } else {
      outcome = 'Run recorded';
      detail = _lastRunLabel(template.lastRunAt);
      icon = Icons.history_rounded;
      color = AppColors.textSecondary;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withAlpha(24),
            borderRadius: AppRadius.smAll,
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LAST OUTCOME',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                outcome,
                style: AppTypography.labelSmall.copyWith(color: color),
              ),
              const SizedBox(height: 2),
              Text(detail, style: AppTypography.caption),
            ],
          ),
        ),
      ],
    );
  }
}

class _LastGeneratedTaskLink extends StatelessWidget {
  const _LastGeneratedTaskLink({
    super.key,
    required this.title,
    required this.meta,
    required this.onTap,
  });

  final String title;
  final String meta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.darkBg,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(
                Icons.task_alt_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Last task', style: AppTypography.caption),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: AppTypography.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Tap to open',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _weekdayLabels = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String _repeatLabel(RecurringTaskTemplateEntity template) =>
    switch (template.repeat) {
      TemplateRepeatMode.once => 'Once',
      TemplateRepeatMode.daily => 'Daily',
      TemplateRepeatMode.weekly =>
        'Every ${_weekdayLabels[(template.weekday - 1).clamp(0, 6)]}',
    };

String _nextAutomationLabel(DateTime? raw, {DateTime? now}) {
  if (raw == null) return 'Not scheduled yet';
  return AppDateFormatter.relativeDayTime(raw, now: now);
}

String _lastRunLabel(DateTime? raw) => raw == null
    ? 'No run time available'
    : AppDateFormatter.relative(raw.toLocal());

String _lastTaskDateLabel(DateTime? raw, {DateTime? now}) {
  if (raw == null) return 'Generation time unavailable';
  final value = raw.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(value.year, value.month, value.day);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return AppDateFormatter.dayMonth(value);
}

String _lastGeneratedTaskMeta(RecurringTaskTemplateEntity template) {
  final status = template.lastStatus?.toLowerCase();
  final failed = template.failureCount > 0 || status == 'failed';
  if (failed || status == 'skipped') return 'Previous generated task';
  return _lastTaskDateLabel(template.lastRunAt);
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
          const SheetTitle('New Automation'),
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
          const Row(
            children: [
              Icon(
                Icons.checklist_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: AppSpacing.sm),
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
            Text(
              _error!,
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Create Automation',
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
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Step description',
                  hintStyle: AppTypography.body.copyWith(
                    color: AppColors.textTertiary,
                  ),
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
              color: row.isRequired
                  ? AppColors.primary
                  : AppColors.textTertiary,
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: () => _removeItem(row),
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
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
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textTertiary,
          ),
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
