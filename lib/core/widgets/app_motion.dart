import 'package:flutter/material.dart';

/// Tasteful, performance-conscious motion primitives used across the app
/// (Phase 9). Deliberately minimal — a single controller per widget, short
/// durations, standard easing — so list scrolling stays smooth and nothing
/// feels like a "demo". Reuse these instead of hand-rolling animations.

/// Fades + lifts a widget in on first build. Used for card / list-item
/// appearance. Pass a [delay] (see [staggerDelay]) for a gentle stagger.
class EntranceFade extends StatefulWidget {
  const EntranceFade({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 14,
    this.duration = const Duration(milliseconds: 320),
  });

  final Widget child;
  final Duration delay;

  /// Vertical travel (px) the child rises through as it fades in.
  final double offset;
  final Duration duration;

  @override
  State<EntranceFade> createState() => _EntranceFadeState();
}

class _EntranceFadeState extends State<EntranceFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _curve =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _curve.value) * widget.offset),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// A capped per-index delay for staggering list entrances. Capped so a long
/// list never waits seconds for the last item.
Duration staggerDelay(int index) =>
    Duration(milliseconds: (index * 45).clamp(0, 270));
