import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';

/// The DROP brand logo — the wordmark artwork at `assets/drop_logo.png`.
///
/// The PNG is a transparent-background outline, so it's tinted to [color]
/// (white on the dark UI by default) via [BlendMode.srcIn] to stay crisp on the
/// near-black background. Size it with [height]; the width follows the artwork's
/// aspect ratio. Used app-wide: splash/loading, login, register, pending-approval.
class DropLogo extends StatelessWidget {
  final double height;
  final Color? color;

  const DropLogo({super.key, this.height = 80, this.color});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/drop_logo.png',
      height: height,
      fit: BoxFit.contain,
      color: color ?? AppColors.textPrimary,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.medium,
    );
  }
}
