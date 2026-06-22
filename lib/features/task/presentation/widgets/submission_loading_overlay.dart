import 'package:flutter/material.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/task/presentation/submission_progress.dart';

/// The single, state-driven submission overlay (Phase 10 refinement). Rendered
/// by the Task Details screen in a Stack whenever `TaskState.isSubmitting` — it
/// fills the screen, **absorbs all input**, and shows the live stage, a real
/// progress bar, the percentage, and transferred / total MB. Because it's driven
/// by cubit state (not a dialog), exactly one ever exists and it survives
/// rebuilds / navigation.
class SubmissionLoadingOverlay extends StatelessWidget {
  const SubmissionLoadingOverlay({super.key, required this.progress});

  final SubmissionProgress progress;

  @override
  Widget build(BuildContext context) {
    final uploading = progress.stage == SubmissionStage.uploading;
    final currentIdx = SubmissionStage.values.indexOf(progress.stage);
    return AbsorbPointer(
      child: Container(
        color: Colors.black.withAlpha(175),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceElevated,
              borderRadius: AppRadius.xlAll,
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Submitting task', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.lg),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: uploading ? progress.fraction : null,
                    minHeight: 6,
                    backgroundColor: AppColors.darkBg,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Text(
                      uploading && progress.percent != null
                          ? '${progress.percent}%'
                          : progress.stage.label,
                      style: AppTypography.label
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    if (progress.sizeLabel != null)
                      Text(progress.sizeLabel!,
                          style: AppTypography.caption),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final stage in SubmissionStage.values)
                  _StageRow(
                    label: stage.label,
                    state: () {
                      final idx = SubmissionStage.values.indexOf(stage);
                      if (idx < currentIdx) return _StageState.done;
                      if (idx == currentIdx) return _StageState.active;
                      return _StageState.pending;
                    }(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _StageState { done, active, pending }

class _StageRow extends StatelessWidget {
  const _StageRow({required this.label, required this.state});
  final String label;
  final _StageState state;

  @override
  Widget build(BuildContext context) {
    final active = state == _StageState.active;
    final done = state == _StageState.done;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: switch (state) {
              _StageState.active => const CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
              _StageState.done => const Icon(Icons.check_circle_rounded,
                  size: 18, color: AppColors.textPrimary),
              _StageState.pending => const Icon(Icons.circle_outlined,
                  size: 16, color: AppColors.textTertiary),
            },
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: AppTypography.body.copyWith(
              color: (active || done)
                  ? AppColors.textPrimary
                  : AppColors.textTertiary,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
