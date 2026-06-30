import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/drop_logo.dart';

/// **DropEmptyState** — a **brand-led** empty state: a faded DROP mark instead
/// of a generic grey glyph, then the message + optional action. The branded
/// sibling of `AppEmptyState` (same centered, always-scrollable layout so it
/// works as a `RefreshIndicator` child), for the moments where the brand should
/// be felt — a fresh inbox, a cleared queue, a first-run list.
///
/// Use `AppEmptyState` for routine "nothing here" placeholders; reach for this
/// where the empty moment is a brand touchpoint. Strictly monochrome.
class DropEmptyState extends StatelessWidget {
  const DropEmptyState({
    super.key,
    required this.message,
    this.title,
    this.action,
  });

  final String message;
  final String? title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The brand mark, quietly faded — present, not loud.
                  Opacity(
                    opacity: 0.35,
                    child: DropLogo(height: 34, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (title != null) ...[
                    Text(title!,
                        style: AppTypography.h3, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Text(
                    message,
                    style: AppTypography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  if (action != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
