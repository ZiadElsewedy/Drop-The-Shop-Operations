import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';

/// Shared, centered empty-state placeholder for any list/section.
///
/// Wrapped in an always-scrollable view so it can be a [RefreshIndicator] child
/// (pull-to-refresh still works on an empty list). [title] and [action] are
/// optional — with both null this renders exactly like the original
/// `TaskEmptyState` (icon + message), which now delegates here.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.action,
  });

  final IconData icon;
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
                  Icon(icon, size: 48, color: AppColors.textTertiary),
                  const SizedBox(height: AppSpacing.lg),
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
