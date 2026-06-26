import 'package:flutter/material.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/drop_logo.dart';

/// The auth-flow brand lockup: the DROP mark + the "DROP Operations System"
/// tagline. Used on the Login screen so the auth brand header lives in **one**
/// place (no per-page logo duplication). Strictly monochrome.
class DropAuthMark extends StatelessWidget {
  const DropAuthMark({super.key, this.logoHeight = 52});

  final double logoHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropLogo(height: logoHeight),
        const SizedBox(height: AppSpacing.md),
        Text(
          'DROP OPERATIONS SYSTEM',
          style: AppTypography.caption.copyWith(
            letterSpacing: 2.0,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
