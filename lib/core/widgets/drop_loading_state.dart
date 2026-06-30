import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/drop_logo.dart';

/// **DropLoadingState** — a **branded** full-area loading moment: the DROP mark
/// with a slow, calm opacity-pulse (the brand "breathing") and an optional
/// message. For whole-screen / whole-section waits where a logo reads better
/// than a bare spinner.
///
/// Use list **skeletons** for content placeholders; reach for this on a
/// full-screen gate (a route loader, a first paint). Strictly monochrome.
class DropLoadingState extends StatefulWidget {
  const DropLoadingState({super.key, this.message, this.logoHeight = 44});

  final String? message;
  final double logoHeight;

  @override
  State<DropLoadingState> createState() => _DropLoadingStateState();
}

class _DropLoadingStateState extends State<DropLoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<double> _pulse =
      Tween<double>(begin: 0.35, end: 1.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _pulse,
            child: DropLogo(height: widget.logoHeight),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              widget.message!,
              style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
