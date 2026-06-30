import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';

/// The shared premium surface for every DROP card — a subtle elevated→surface
/// gradient, a hairline border, soft depth shadow and a large radius. Dashboard
/// cards, action tiles and metric cards all build on this so the whole app
/// shares **one** "glass" treatment instead of re-declaring the same
/// [BoxDecoration] everywhere (the spec's "extract repeated cards" requirement).
///
/// - Pass [onTap] for built-in press-scale + hover-border feedback.
/// - Pass [highlight] (with optional [accent]) to draw an accent border so the
///   card reads as "act on this" (e.g. a metric that needs attention).
class GlassContainer extends StatefulWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.borderRadius = AppRadius.cardAll,
    this.highlight = false,
    this.accent,
    this.elevated = true,
    this.glow,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  /// Draw an accent border (uses [accent], default [AppColors.warning]) to flag
  /// that the card needs attention.
  final bool highlight;
  final Color? accent;

  /// Paint the soft depth shadow (default). Set false for a flat inset tile.
  final bool elevated;

  /// Optional **subtle semantic glow** — a soft tinted halo + faint border tint
  /// in this colour (e.g. a task status: emerald / amber / red). Null = the
  /// default monochrome surface. The premium card system ([AppGlassCard]) maps a
  /// status to this; the app otherwise stays strictly monochrome.
  final Color? glow;

  @override
  State<GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<GlassContainer> {
  bool _pressed = false;
  bool _hovered = false;

  void _setPressed(bool v) {
    if (widget.onTap != null && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent ?? AppColors.warning;
    final glow = widget.glow;
    final borderColor = widget.highlight
        ? accent.withAlpha(140)
        : glow != null
            ? glow.withAlpha(90) // faint semantic border tint
            : (_hovered ? AppColors.textTertiary : AppColors.darkBorder);

    final shadows = <BoxShadow>[
      if (widget.elevated)
        BoxShadow(
          color: AppColors.black.withAlpha(40),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      // Subtle coloured halo for a status card — soft, never neon.
      if (glow != null)
        BoxShadow(
          color: glow.withAlpha(48),
          blurRadius: 24,
          spreadRadius: -4,
          offset: const Offset(0, 4),
        ),
    ];

    final card = AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: widget.padding,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.darkSurfaceElevated, AppColors.darkSurface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: widget.borderRadius,
          border: Border.all(color: borderColor),
          boxShadow: shadows.isEmpty ? null : shadows,
        ),
        child: widget.child,
      ),
    );

    if (widget.onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: card,
      ),
    );
  }
}
