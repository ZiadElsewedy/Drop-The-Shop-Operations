import 'package:flutter/material.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';

/// Centered empty placeholder for a task list. Wrapped in a scrollable so it
/// still works as a [RefreshIndicator] child (pull-to-refresh on an empty list).
class TaskEmptyState extends StatelessWidget {
  const TaskEmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

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
                  Text(
                    message,
                    style: AppTypography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
