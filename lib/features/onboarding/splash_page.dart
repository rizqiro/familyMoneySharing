import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_mark.dart';
import '../../core/theme/app_theme.dart';
import '../../state/providers.dart';

/// The opening screen.
///
/// =============================================================================
/// WHAT A SPLASH SCREEN IS ACTUALLY FOR
/// =============================================================================
/// Not branding. It covers a gap you cannot remove: between the app's first
/// frame and the moment Firebase has answered "is anyone signed in, and what is
/// in their household". On a cold start over a slow connection that is a second
/// or two of having nothing true to show.
///
/// The alternative is a spinner on a blank page, which reads as a stall. A
/// screen that says the app's name and what it is for reads as a start.
///
/// It inverts the palette - solid accent, white mark - for one practical
/// reason: the native launch screen (the one the operating system paints before
/// any Dart has run) is a flat colour, and matching it means the app opens on
/// colour rather than flashing white first. That colour is set in
/// `android/app/src/main/res/values/colors.xml`; keep the two in step.
///
/// For the same reason this page uses [AppColors.light] explicitly rather than
/// the current theme. A dark-mode device would otherwise draw the native screen
/// in the light accent and then repaint it a shade lighter a frame later, which
/// reads as a flicker.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Deliberately the light palette in both modes - see the note above.
    const colors = AppColors.light;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);

    return Scaffold(
      backgroundColor: colors.accent,
      // The status bar's clock and battery are dark by default. On a
      // near-black-on-red screen they vanish, so they are forced light for as
      // long as this page is on top.
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Stack(
          children: [
            // Two oversized circles bled off opposite corners. They are the
            // same hue a shade lighter and a shade darker, so the background
            // has some depth without becoming a gradient.
            Positioned(
              top: -90,
              right: -70,
              child: _Blob(size: 260, color: Colors.white.withValues(alpha: 0.08)),
            ),
            Positioned(
              bottom: -120,
              left: -80,
              child: _Blob(size: 300, color: Colors.black.withValues(alpha: 0.07)),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Insets.xxl + 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    // The launcher icon's own mark, on the same ground, at the
                    // same proportions. Opening the app should look like the
                    // icon growing rather than like a second piece of artwork.
                    const AppMark(size: 104),
                    const SizedBox(height: Insets.xl + 4),
                    Text(
                      t('auth.app_name'),
                      style: text.displayMedium?.copyWith(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(
                        t('auth.tagline'),
                        style: text.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const _Progress(),
                    const SizedBox(height: Insets.lg),
                    Text(
                      t('splash.preparing'),
                      style: text.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// A short bar that fills and repeats.
///
/// Deliberately not a percentage of anything - it cannot be, since nobody knows
/// how long Firebase will take. It is a sign of life, which is all a progress
/// indicator has to be when the duration is unknown.
class _Progress extends StatefulWidget {
  const _Progress();

  @override
  State<_Progress> createState() => _ProgressState();
}

/// =============================================================================
/// ANIMATION IN FLUTTER, THE SHORT VERSION
/// =============================================================================
/// An [AnimationController] produces a number that changes over time, usually
/// 0 to 1. It needs a `vsync` - a hook into the screen's refresh - so it stops
/// burning frames when the app is in the background. [SingleTickerProviderStateMixin]
/// is what supplies that, hence `with` on the class below.
///
/// `AnimatedBuilder` rebuilds only what is inside it on each tick, so the rest
/// of the page is not rebuilt sixty times a second.
///
/// Anything with a controller must have a [dispose] that closes it, or the
/// animation keeps running after the screen is gone.
class _ProgressState extends State<_Progress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(2),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // `Curves.easeInOut` bends the straight 0-to-1 ramp so the bar
            // starts gently, speeds up and settles - a linear one looks
            // mechanical.
            final t = Curves.easeInOut.transform(_controller.value);
            return Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.25 + t * 0.6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Holds the splash on screen for a minimum time, then gets out of the way.
///
/// =============================================================================
/// WHY A MINIMUM DURATION
/// =============================================================================
/// On a warm start Firebase answers in 80ms, and a splash that appears for 80ms
/// is worse than none: it is a flash of red the eye reads as a glitch. So the
/// screen is held for [minimum] whatever happens, and released only once BOTH
/// that timer and the real loading are done.
///
/// [Timer] comes from `dart:async`. It has to be cancelled in [dispose] -
/// otherwise it fires on a widget that no longer exists and Flutter throws.
class SplashGate extends StatefulWidget {
  const SplashGate({
    super.key,
    required this.child,
    this.minimum = const Duration(milliseconds: 1400),
  });

  final Widget child;
  final Duration minimum;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _elapsed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.minimum, () {
      // `mounted` is false once the widget has been removed from the tree.
      // Calling setState then is an error, and this is the classic place to
      // hit it: the user signed out while the timer was still running.
      if (mounted) setState(() => _elapsed = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _elapsed ? widget.child : const SplashPage();
  }
}
