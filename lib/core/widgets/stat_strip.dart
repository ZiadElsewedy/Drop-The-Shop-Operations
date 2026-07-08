import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/glass_container.dart';

/// One cell in a [StatStrip] — a label + a glanceable value, optionally tinted.
class Stat {
  const Stat({required this.label, required this.value, this.tone});

  final String label;
  final String value;

  /// Optional semantic tint for the value (null = monochrome white).
  final Color? tone;
}

/// **StatStrip** — a calm, single-surface row of small facts (DROP Design System
/// V2). The lightweight "here's today" layer: a few `value / label` stats inside
/// one quiet [GlassContainer], no charts. The small sibling of a metric-card
/// grid, for the supporting numbers that inform without demanding action.
///
/// Reusable anywhere a compact fact row is needed (a dashboard "Today" line, a
/// branch health summary, a detail header). Responsive: a single divided row
/// when it fits, a two-column wrap when it doesn't — so it never overflows on a
/// phone or under large text.
class StatStrip extends StatelessWidget {
  const StatStrip({super.key, required this.stats});

  final List<Stat> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();
    return GlassContainer(
      elevated: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Enough room for every stat side-by-side? Otherwise wrap to 2-up.
          final fitsOneRow = constraints.maxWidth >= stats.length * 118;
          return fitsOneRow ? _row(stats) : _grid(stats);
        },
      ),
    );
  }

  Widget _cell(Stat s, {TextAlign align = TextAlign.start}) {
    final cross = align == TextAlign.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: cross,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          s.value,
          textAlign: align,
          style: AppTypography.h3.copyWith(
            color: s.tone ?? AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          s.label,
          textAlign: align,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  /// A single row with hairline dividers between cells.
  Widget _row(List<Stat> stats) {
    final children = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      if (i > 0) {
        children.add(
          Container(
            width: 1,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            color: AppColors.darkBorder,
          ),
        );
      }
      children.add(Expanded(child: _cell(stats[i])));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: children);
  }

  /// A two-column wrap for narrow widths (no vertical dividers).
  Widget _grid(List<Stat> stats) {
    return Column(
      children: [
        for (var i = 0; i < stats.length; i += 2) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _cell(stats[i])),
              const SizedBox(width: AppSpacing.md),
              if (i + 1 < stats.length)
                Expanded(child: _cell(stats[i + 1]))
              else
                const Spacer(),
            ],
          ),
        ],
      ],
    );
  }
}
