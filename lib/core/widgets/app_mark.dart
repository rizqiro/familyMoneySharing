import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The app's mark: one roof, two people under it.
///
/// =============================================================================
/// WHY THIS IS DRAWN AND NOT AN IMAGE ASSET
/// =============================================================================
/// It is three shapes. As a PNG it would be four density variants in the
/// bundle, fixed in colour and fuzzy at any size nobody exported. Drawn, it is
/// sharp at every size, takes its colours from the theme, and stays in step
/// with the launcher icon because both come from the same numbers.
///
/// Those numbers are the ones in `android/app/src/main/res/mipmap-*`, drawn in
/// a 1024-unit square: the roof runs from (206,536) up to (512,306) and down to
/// (818,536), and the two dots sit at (416,702) and (608,702). Change them here
/// and the launcher icon no longer matches - the generator that produced the
/// icon files holds its own copy.
class AppMark extends StatelessWidget {
  const AppMark({
    super.key,
    this.size = 96,
    this.roofColor,
    this.dotColor,
    this.accentDotColor,
  });

  final double size;

  /// Defaults suit the accent ground the splash and the icon both use: a cream
  /// roof with one cream dot and one butter dot.
  final Color? roofColor;
  final Color? dotColor;
  final Color? accentDotColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MarkPainter(
          roof: roofColor ?? colors.page,
          dot: dotColor ?? colors.page,
          accentDot: accentDotColor ?? const Color(0xFFF2C14E),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({
    required this.roof,
    required this.dot,
    required this.accentDot,
  });

  final Color roof;
  final Color dot;
  final Color accentDot;

  /// The design space. Every coordinate below is in these units and scaled to
  /// whatever size the widget was given.
  static const _src = 1024.0;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / _src;
    Offset p(double x, double y) => Offset(x * k, y * k);

    // Round caps and joins, so the roof's corners match the icon's exactly.
    canvas.drawPath(
      Path()
        ..moveTo(206 * k, 536 * k)
        ..lineTo(512 * k, 306 * k)
        ..lineTo(818 * k, 536 * k),
      Paint()
        ..color = roof
        ..style = PaintingStyle.stroke
        ..strokeWidth = 94 * k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(p(416, 702), 76 * k, Paint()..color = dot);
    canvas.drawCircle(p(608, 702), 76 * k, Paint()..color = accentDot);
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.roof != roof || old.dot != dot || old.accentDot != accentDot;
}
