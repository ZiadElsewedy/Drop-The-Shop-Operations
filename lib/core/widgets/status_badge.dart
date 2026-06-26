import 'package:flutter/material.dart';
import 'package:fbro/core/enums/swap_status.dart';
import 'package:fbro/core/enums/task_status.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_typography.dart';

/// Small tinted status pill — one component for every Pending / Approved /
/// Rejected / Completed / Active … indicator. Background + border are tinted in
/// the status colour (the look the task card already used).
///
/// Use a typed factory (`StatusBadge.task(...)`, `.swap(...)`, `.active(...)`) so
/// the colour + label mapping lives in exactly one place, or the default
/// constructor for an ad-hoc label/colour.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  factory StatusBadge.task(TaskStatus status) =>
      StatusBadge(label: _taskLabel(status), color: _taskColor(status));

  factory StatusBadge.swap(SwapStatus status) =>
      StatusBadge(label: _swapLabel(status), color: _swapColor(status));

  factory StatusBadge.active(bool isActive) => StatusBadge(
        label: isActive ? 'Active' : 'Inactive',
        color: isActive ? AppColors.success : AppColors.error,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(label, style: AppTypography.caption.copyWith(color: color)),
    );
  }
}

/// The single source for a task status' semantic colour — reused by
/// [StatusBadge.task] and the premium card glow ([AppGlassCard]) so the mapping
/// lives in exactly one place.
Color taskStatusColor(TaskStatus s) => _taskColor(s);

Color _taskColor(TaskStatus s) {
  switch (s) {
    case TaskStatus.pending:
      return AppColors.textTertiary;
    case TaskStatus.started:
    case TaskStatus.waitingReview:
      return AppColors.warning;
    case TaskStatus.completed:
      return AppColors.primary;
    case TaskStatus.approved:
      return AppColors.success;
    case TaskStatus.rejected:
      return AppColors.error;
  }
}

String _taskLabel(TaskStatus s) {
  switch (s) {
    case TaskStatus.pending:
      return 'Pending';
    case TaskStatus.started:
      return 'Started';
    case TaskStatus.completed:
      return 'Completed';
    case TaskStatus.waitingReview:
      return 'Waiting Review';
    case TaskStatus.approved:
      return 'Approved';
    case TaskStatus.rejected:
      return 'Rejected';
  }
}

Color _swapColor(SwapStatus s) {
  switch (s) {
    case SwapStatus.pending:
    case SwapStatus.employeeApproved:
      return AppColors.warning; // pending stages = amber
    case SwapStatus.managerApproved:
      return AppColors.success; // approved = emerald
    case SwapStatus.rejected:
      return AppColors.error; // rejected = red
    case SwapStatus.cancelled:
      return AppColors.textTertiary; // cancelled = neutral grey
  }
}

String _swapLabel(SwapStatus s) {
  switch (s) {
    case SwapStatus.pending:
      return 'Pending';
    case SwapStatus.employeeApproved:
      return 'Coworker approved';
    case SwapStatus.managerApproved:
      return 'Approved';
    case SwapStatus.rejected:
      return 'Rejected';
    case SwapStatus.cancelled:
      return 'Cancelled';
  }
}
