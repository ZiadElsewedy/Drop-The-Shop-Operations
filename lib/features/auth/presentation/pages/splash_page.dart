import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/drop_logo.dart';

/// The cold-start visual surface.
///
/// Bootstrap is intentionally owned by the composition root (`LaunchApp` in
/// `main.dart`), not this page. Keeping this widget presentation-only lets the
/// Firebase/session work and the Lottie playback run independently, with the
/// parent acting as the two-condition rendezvous.
class SplashPage extends StatefulWidget {
  const SplashPage({
    required this.onAnimationComplete,
    required this.isBootstrapping,
    this.bootstrapError,
    this.onRetry,
    super.key,
  });

  final VoidCallback onAnimationComplete;
  final bool isBootstrapping;
  final Object? bootstrapError;
  final VoidCallback? onRetry;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _animationReported = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  void _play(LottieComposition composition) {
    if (_controller.isAnimating || _animationReported) return;
    _controller
      ..duration = composition.duration
      ..forward().whenComplete(_reportAnimationComplete);
  }

  void _reportAnimationComplete() {
    if (!mounted || _animationReported) return;
    _animationReported = true;
    widget.onAnimationComplete();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animationDone = _animationReported;
    final showError = animationDone && widget.bootstrapError != null;
    final showWaiting =
        animationDone &&
        widget.bootstrapError == null &&
        widget.isBootstrapping;

    return Scaffold(
      backgroundColor: Colors.black,
      body: ColoredBox(
        color: Colors.black,
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: RepaintBoundary(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: FractionallySizedBox(
                      widthFactor: 0.86,
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Semantics(
                          label: 'DROP Operations',
                          image: true,
                          child: LottieBuilder(
                            // This export contains 102 embedded 720×405 WebP
                            // image assets (not lightweight vector paths). Load
                            // the JSON off the UI isolate and decode the images
                            // at a bounded size to avoid a ~113 MiB cold-start
                            // decoded-image footprint.
                            lottie: _LaunchAssetLottie('assets/0704.json'),
                            controller: _controller,
                            fit: BoxFit.contain,
                            repeat: false,
                            animate: false,
                            onLoaded: _play,
                            errorBuilder: (context, error, stackTrace) {
                              // A malformed/missing launch asset must never
                              // deadlock startup. Keep the brand visible and
                              // release the animation side of the gate.
                              WidgetsBinding.instance.addPostFrameCallback(
                                (_) => _reportAnimationComplete(),
                              );
                              return const Center(child: DropLogo(height: 88));
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: showError
                        ? _StartupError(
                            key: const ValueKey('startup-error'),
                            onRetry: widget.onRetry,
                          )
                        : showWaiting
                        ? const _WaitingIndicator(
                            key: ValueKey('startup-waiting'),
                          )
                        : const SizedBox.shrink(key: ValueKey('startup-idle')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asset provider that keeps the supplied Lottie intact while bounding its
/// embedded raster-frame decode size. `AssetLottie` otherwise resolves data URI
/// images at their full 720×405 source dimensions before playback begins.
class _LaunchAssetLottie extends AssetLottie {
  // The explicit forward keeps the private provider's fixed loading policy
  // visible at the call site.
  // ignore: use_super_parameters
  _LaunchAssetLottie(String assetName)
      : super(assetName, backgroundLoading: true);

  static const _decodedWidth = 480;

  @override
  ImageProvider<Object>? getImageProvider(LottieImageAsset lottieImage) {
    final provider = super.getImageProvider(lottieImage);
    return provider == null
        ? null
        : ResizeImage(provider, width: _decodedWidth, allowUpscaling: false);
  }
}

class _WaitingIndicator extends StatelessWidget {
  const _WaitingIndicator({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(
      strokeWidth: 1.5,
      color: AppColors.textSecondary,
    ),
  );
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry, super.key});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'DROP could not start. Check your connection and try again.',
        textAlign: TextAlign.center,
        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: onRetry,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(96, 44),
        ),
        child: const Text('Try again'),
      ),
    ],
  );
}
