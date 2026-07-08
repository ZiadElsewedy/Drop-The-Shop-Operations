import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/features/community/domain/event_readiness.dart';
import 'package:drop/features/community/presentation/event_format.dart';
import 'package:drop/features/community/presentation/widgets/preparation_ring.dart';

/// The **intelligence** chapter — a readiness score plus the ranked insights the
/// engine surfaced (blockers to clear, warnings to weigh, wins to celebrate).
/// This is what makes the workspace feel like it's thinking with you, not just
/// storing your data.
class ReadinessPanel extends StatelessWidget {
  const ReadinessPanel({super.key, required this.readiness});

  final EventReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final top = readiness.topInsight;
    final glow = top == null ? null : EventFormat.insightColor(top.level);
    final scoreColor = EventFormat.scoreColor(readiness.score);

    return GlassContainer(
      glow: glow,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PreparationRing(
                progress: readiness.score / 100,
                size: 74,
                stroke: 7,
                color: scoreColor,
                centerBuilder: (_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${readiness.score}',
                        style: AppTypography.h3.copyWith(
                            fontSize: 22, fontWeight: FontWeight.w700)),
                    Text('score',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textTertiary)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Readiness',
                        style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(readiness.headline, style: AppTypography.h3),
                    const SizedBox(height: 4),
                    Text(
                      _summaryLine(readiness),
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (readiness.insights.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const Divider(height: 1, color: AppColors.darkBorder),
            const SizedBox(height: AppSpacing.sm),
            for (final i in readiness.insights) _InsightRow(insight: i),
          ],
        ],
      ),
    );
  }

  static String _summaryLine(EventReadiness r) {
    final parts = <String>[];
    if (r.blockers.isNotEmpty) {
      parts.add(
          '${r.blockers.length} blocker${r.blockers.length == 1 ? '' : 's'}');
    }
    if (r.warnings.isNotEmpty) {
      parts.add(
          '${r.warnings.length} to review');
    }
    if (parts.isEmpty) {
      return r.wins.isNotEmpty
          ? 'Everything essential is in place.'
          : 'Nothing flagged yet.';
    }
    return parts.join(' · ');
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.insight});
  final EventInsight insight;

  @override
  Widget build(BuildContext context) {
    final color = EventFormat.insightColor(insight.level);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withAlpha(28),
              borderRadius: AppRadius.smAll,
              border: Border.all(color: color.withAlpha(70)),
            ),
            child: Icon(EventFormat.insightIcon(insight.level),
                size: 15, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title,
                    style: AppTypography.label.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(insight.detail, style: AppTypography.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
