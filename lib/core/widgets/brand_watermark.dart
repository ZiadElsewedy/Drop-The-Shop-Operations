import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/widgets/drop_logo.dart';
import 'package:drop/core/widgets/drop_wordmark.dart';

/// Overlays a **barely-there** DROP wordmark in the corner of a premium hero —
/// a quiet brand presence, never decoration (§9b Wave 3, "selective header
/// branding"). Opacity is capped low (0.02–0.05); the mark is non-interactive
/// and clipped to the content bounds, so it can't obscure text or break layout.
///
/// Wrap a hero's content `Column`, typically inside the card surface:
/// `GlassContainer(child: BrandWatermark(child: ...))`. Strictly monochrome.
class BrandWatermark extends StatelessWidget {
  const BrandWatermark({
    super.key,
    required this.child,
    this.opacity = 0.04,
    this.fontSize = 88,
    this.assetLogo = false,
    this.assetHeight = 92,
  }) : assert(opacity <= 0.05, 'Keep the watermark subtle (≤ 0.05).');

  final Widget child;
  final double opacity;
  final double fontSize;

  /// Uses the real `assets/drop_logo.png` artwork instead of the typographic
  /// [DropWordmark]. Opt-in so established hero compositions do not change.
  final bool assetLogo;
  final double assetHeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        child,
        Positioned(
          right: -6,
          bottom: -10,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: assetLogo
                  ? DropLogo(
                      height: assetHeight,
                      color: AppColors.textPrimary,
                    )
                  : DropWordmark(
                      fontSize: fontSize,
                      color: AppColors.textPrimary,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
