import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../state/chart_series.dart';
import '../format/money.dart';
import '../theme/app_colors.dart';

/// The charts, drawn by hand.
///
/// =============================================================================
/// WHY CustomPainter AND NOT A CHART PACKAGE
/// =============================================================================
/// A charting package would be a hundred lines less code and a thousand lines
/// more dependency - and the first thing you would do is fight its defaults:
/// its own colours, its own tooltips, a card and a legend you did not ask for.
/// These charts are three shapes and a dashed line. Drawing them directly is
/// less code than configuring someone else's.
///
/// =============================================================================
/// HOW CustomPainter WORKS
/// =============================================================================
/// `CustomPaint` is a widget that hands you a blank [Canvas] the size of the
/// space it was given. You implement [CustomPainter.paint] and draw: lines,
/// paths, rounded rectangles, text. Two things to know:
///
///   * The canvas's origin (0, 0) is the TOP-LEFT, and y grows DOWNWARDS. So a
///     bigger amount of money is a SMALLER y. Every `_y(...)` helper below
///     subtracts from the bottom edge for exactly that reason.
///   * [CustomPainter.shouldRepaint] is asked on every rebuild. Return false
///     and Flutter reuses the pixels it already has, which is why scrolling the
///     dashboard does not re-draw the chart thirty times a second.
///
/// Text is the one thing you cannot draw directly. A [TextPainter] lays the
/// text out first (which is also how you find out how wide it is, needed for
/// the call-out pill) and then paints it.
///
/// =============================================================================
/// THE SHAPE OF THE PAGE AROUND IT
/// =============================================================================
/// These charts are drawn full-bleed: the page has a 20px gutter, and the chart
/// spills back out through it so the drawing runs edge to edge. Wrap one in
/// [FullBleed] below to get that - Flutter has no negative margins, and that
/// widget explains what it does instead.
///
/// Nothing here knows about Riverpod or Firestore. It takes a [SpendSeries]
/// (see `state/chart_series.dart`) and paints it.

/// Lets a child spill out through the page's horizontal padding.
///
/// =============================================================================
/// WHY THIS IS NOT JUST A NEGATIVE MARGIN
/// =============================================================================
/// In CSS you would write `margin: 0 -20px` and be done. Flutter refuses:
/// `Padding` asserts that its insets are non-negative, and `Container`'s margin
/// is a `Padding` underneath, so there is no negative-margin escape hatch.
///
/// [OverflowBox] is the supported way. It takes the space its parent gave it
/// but hands the CHILD different constraints - here, the full screen width -
/// and lets the child paint outside its slot. The child ends up centred and
/// hanging 20px over each side, which is exactly the page gutter.
///
/// It needs an explicit [height] because an OverflowBox sizes itself to the
/// largest thing its own constraints allow, and inside a scrolling list the
/// height allowed is infinite.
class FullBleed extends StatelessWidget {
  const FullBleed({super.key, required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // `MediaQuery.sizeOf` reads just the size and rebuilds only when the size
    // changes - cheaper than `MediaQuery.of(context).size`, which subscribes to
    // every media change including the keyboard opening.
    final width = MediaQuery.sizeOf(context).width;

    return SizedBox(
      height: height,
      child: OverflowBox(
        minWidth: width,
        maxWidth: width,
        minHeight: height,
        maxHeight: height,
        child: child,
      ),
    );
  }
}

/// Picks the right drawing for the series' range and paints it.
class SpendChart extends StatelessWidget {
  const SpendChart({
    super.key,
    required this.series,
    required this.money,
    required this.semanticLabel,
    this.height = 212,
    this.referenceLabel,
    this.calloutLabel,
    this.showPaceLine = false,
  });

  final SpendSeries series;
  final Money money;

  /// Read out by a screen reader in place of the drawing. A chart with no
  /// spoken equivalent is invisible to anyone using one.
  final String semanticLabel;

  final double height;

  /// Sits at the right-hand end of the dashed line: "Budget Rp 8 jt".
  final String? referenceLabel;

  /// The dark pill above today's dot, usually the amount spent so far.
  final String? calloutLabel;

  /// Draws the diagonal "ideal pace" line - the path that would land exactly on
  /// budget on the last day. Used on the budget detail screen, where there is
  /// room to explain it in a legend; left off the dashboard, where a third line
  /// would be noise.
  final bool showPaceLine;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (series.isEmpty) {
      return SizedBox(height: height);
    }

    final painter = switch (series.range) {
      ChartRange.month => _BurnUpPainter(
          series: series,
          money: money,
          colors: colors,
          referenceLabel: referenceLabel,
          calloutLabel: calloutLabel,
          showPaceLine: showPaceLine,
        ),
      ChartRange.day || ChartRange.year => _BarsPainter(
          series: series,
          money: money,
          colors: colors,
          referenceLabel: referenceLabel,
        ),
    };

    return Semantics(
      label: semanticLabel,
      // The drawing carries no text of its own that a screen reader could read,
      // so it is marked as an image with the label above standing in for it.
      image: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: painter),
      ),
    );
  }
}

// =============================================================================
// Shared drawing helpers
// =============================================================================

/// Where the plot sits inside the canvas.
///
/// The left inset matches the page gutter so the data lines up with the text
/// above it, even though the gridlines themselves run right off both edges.
const _plotLeft = 20.0;
const _plotRight = 18.0;
const _plotTop = 34.0;
const _axisHeight = 34.0;

/// Draws a dashed straight line.
///
/// Flutter can dash a path only with a shader trick, so for straight lines it
/// is simpler to walk from one end to the other laying down short segments.
void _dashedLine(
  Canvas canvas,
  Offset from,
  Offset to,
  Paint paint, {
  double dash = 5,
  double gap = 4,
}) {
  final total = (to - from).distance;
  if (total <= 0) return;
  // A unit vector: the direction from `from` to `to`, with length 1. Multiplying
  // it by a distance gives the point that far along the line.
  final step = (to - from) / total;
  var travelled = 0.0;
  while (travelled < total) {
    final end = (travelled + dash).clamp(0.0, total);
    canvas.drawLine(from + step * travelled, from + step * end, paint);
    travelled += dash + gap;
  }
}

/// Lays out one run of text and paints it.
///
/// [align] is where the given [at] point sits relative to the text: -1 means
/// `at` is the text's left edge, 0 its centre, 1 its right edge. That saves
/// every caller doing its own width arithmetic.
void _label(
  Canvas canvas,
  String text,
  Offset at, {
  required Color color,
  double size = 10.5,
  FontWeight weight = FontWeight.w400,
  double align = -1,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: weight,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final dx = switch (align) {
    < 0 => at.dx,
    > 0 => at.dx - painter.width,
    _ => at.dx - painter.width / 2,
  };
  painter.paint(canvas, Offset(dx, at.dy));
}

/// Thins axis labels down to roughly [wanted] of them, always keeping the first
/// and last.
///
/// Without this, fourteen day numbers collide into a grey smear on a narrow
/// phone. Returns the indices to draw.
Set<int> _labelIndices(int count, {int wanted = 5}) {
  if (count <= wanted) {
    return {for (var i = 0; i < count; i++) i};
  }
  final step = (count - 1) / (wanted - 1);
  return {
    for (var i = 0; i < wanted; i++) (i * step).round().clamp(0, count - 1),
  };
}

// =============================================================================
// The cumulative line - "will I make it to the end of the month?"
// =============================================================================

class _BurnUpPainter extends CustomPainter {
  _BurnUpPainter({
    required this.series,
    required this.money,
    required this.colors,
    required this.referenceLabel,
    required this.calloutLabel,
    required this.showPaceLine,
  });

  final SpendSeries series;
  final Money money;
  final AppColors colors;
  final String? referenceLabel;
  final String? calloutLabel;
  final bool showPaceLine;

  @override
  void paint(Canvas canvas, Size size) {
    final points = series.points;
    if (points.isEmpty) return;

    final bottom = size.height - _axisHeight;
    final right = size.width - _plotRight;
    // A tenth of headroom above the tallest thing, so a line that lands exactly
    // on the ceiling is not drawn flush against the top edge.
    final top = series.maxValue * 1.1;

    double y(double value) =>
        bottom - (value / top) * (bottom - _plotTop);

    // The month is laid out over the days it *will* have, not the days it has
    // had, so the line stops part-way across and the empty space to the right
    // is itself information: that is how much month is left.
    final totalSlots = series.range == ChartRange.month
        ? _slotsForMonth()
        : points.length;
    double x(int index) => totalSlots <= 1
        ? _plotLeft
        : _plotLeft + (right - _plotLeft) * (index / (totalSlots - 1));

    final hairline = Paint()
      ..color = colors.hairline
      ..strokeWidth = 1;

    // ------------------------------------------------- gridlines (full bleed)
    canvas.drawLine(Offset(0, y(0)), Offset(size.width, y(0)), hairline);
    if (series.reference > 0) {
      final half = y(series.reference / 2);
      canvas.drawLine(Offset(0, half), Offset(size.width, half), hairline);
      _label(
        canvas,
        money.compact(series.reference / 2),
        Offset(_plotLeft, half - 14),
        color: colors.inkMuted,
      );
    }

    // ------------------------------------------------------ today's band
    if (series.todayIndex >= 0) {
      final cx = x(series.todayIndex);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(cx - 12, _plotTop - 4, cx + 12, y(0)),
          const Radius.circular(6),
        ),
        Paint()..color = colors.accent.withValues(alpha: 0.06),
      );
    }

    // ------------------------------------------------ the budget ceiling
    if (series.reference > 0) {
      final ceiling = y(series.reference);
      _dashedLine(
        canvas,
        Offset(0, ceiling),
        Offset(size.width, ceiling),
        Paint()
          ..color = colors.inkMuted
          ..strokeWidth = 1.5,
      );
      if (referenceLabel != null) {
        _label(
          canvas,
          referenceLabel!,
          Offset(right, ceiling - 15),
          color: colors.inkMuted,
          size: 11,
          align: 1,
        );
      }
      _label(
        canvas,
        money.compact(series.reference),
        Offset(_plotLeft, ceiling - 14),
        color: colors.inkMuted,
      );
    }

    // ------------------------------------------------------ the ideal pace
    //
    // A straight line from nothing on day one to the whole budget on the last
    // day. Where your own line sits relative to this one IS the judgement: above
    // it means you are spending faster than the month is passing.
    if (showPaceLine && series.reference > 0) {
      _dashedLine(
        canvas,
        Offset(_plotLeft, y(0)),
        Offset(right, y(series.reference)),
        Paint()
          ..color = colors.inkMuted
          ..strokeWidth = 1.5,
      );
    }

    // ------------------------------------------------- the spending itself
    final vertices = [
      for (var i = 0; i < points.length; i++)
        Offset(x(i), y(points[i].value)),
    ];

    // The filled area is the same shape closed back down to the baseline. It
    // carries no extra information - it is there to make the line read as
    // "accumulating" rather than as a temperature.
    final area = Path()..moveTo(vertices.first.dx, y(0));
    for (final v in vertices) {
      area.lineTo(v.dx, v.dy);
    }
    area
      ..lineTo(vertices.last.dx, y(0))
      ..close();
    canvas.drawPath(
      area,
      Paint()..color = colors.series1.withValues(alpha: 0.10),
    );

    final line = Path()..moveTo(vertices.first.dx, vertices.first.dy);
    for (final v in vertices.skip(1)) {
      line.lineTo(v.dx, v.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = colors.series1
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // ------------------------------------------------------- the projection
    if (series.projected > 0) {
      final end = Offset(right, y(series.projected));
      _dashedLine(
        canvas,
        vertices.last,
        end,
        Paint()
          ..color = colors.series1.withValues(alpha: 0.55)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
        dash: 3,
        gap: 5,
      );

      // Shade the part of the projection that is above the budget. The area of
      // that wedge is the overspend - the one thing on the chart you would want
      // to reach in and pull back down.
      if (series.projectedOverspend > 0) {
        final ceiling = y(series.reference);
        final crossing = _crossing(vertices.last, end, ceiling);
        if (crossing != null) {
          canvas.drawPath(
            Path()
              ..moveTo(crossing, ceiling)
              ..lineTo(end.dx, end.dy)
              ..lineTo(end.dx, ceiling)
              ..close(),
            Paint()..color = colors.series1.withValues(alpha: 0.22),
          );
        }
      }
    }

    // --------------------------------------------------------- today's dot
    if (series.todayIndex >= 0) {
      final dot = vertices.last;
      // The halo is the page colour, not white: it has to punch a hole in the
      // shaded area underneath, and white would show as a bright ring.
      canvas.drawCircle(dot, 8, Paint()..color = colors.page);
      canvas.drawCircle(dot, 5, Paint()..color = colors.series1);

      if (calloutLabel != null) {
        // 34 above the dot, but never above the top of the canvas - late in a
        // heavy month the line is high enough that the pill would be cut off.
        final above = (dot.dy - 34).clamp(14.0, size.height);
        _pill(canvas, calloutLabel!, Offset(dot.dx, above), size);
      }
    }

    // -------------------------------------------------------- the day axis
    final show = _labelIndices(points.length, wanted: 5);
    for (final i in show) {
      final isToday = i == series.todayIndex;
      _label(
        canvas,
        points[i].label,
        Offset(x(i), bottom + 18),
        color: isToday ? colors.accentDeep : colors.inkMuted,
        weight: isToday ? FontWeight.w600 : FontWeight.w400,
        // The first label hangs off its point to the right and the last to
        // the left, so neither runs off the edge of the screen.
        align: i == 0 ? -1 : (i == totalSlots - 1 ? 1 : 0),
      );
    }
    // The last day of the month, sitting at the right-hand edge even though no
    // line reaches it yet. Without it the axis would stop at today and the
    // empty space would look like a rendering bug rather than "month to go".
    if (totalSlots > points.length) {
      _label(
        canvas,
        '$totalSlots',
        Offset(right, bottom + 18),
        color: colors.inkMuted,
        align: 1,
      );
    }
  }

  /// How many day-slots the month gets. One per point, unless the projection
  /// says the month runs longer than the days spent so far.
  int _slotsForMonth() {
    if (series.projected <= 0 || series.spent <= 0) return series.points.length;
    // spent/projected is the fraction of the month elapsed; dividing the days
    // so far by it gives the days in total. Rounded, then floored at the points
    // we already have so the line can never run off the right-hand edge.
    final estimate = (series.points.length * series.projected / series.spent)
        .round();
    return estimate < series.points.length ? series.points.length : estimate;
  }

  /// The x where the segment from [a] to [b] crosses the horizontal line at
  /// [lineY], or null when it never does.
  double? _crossing(Offset a, Offset b, double lineY) {
    if ((a.dy - lineY) * (b.dy - lineY) > 0) return null; // same side of it
    if (a.dy == b.dy) return null;
    // How far along the segment the crossing is, 0 at `a` and 1 at `b`.
    final t = (lineY - a.dy) / (b.dy - a.dy);
    return a.dx + (b.dx - a.dx) * t;
  }

  /// The dark rounded label above today's dot.
  void _pill(Canvas canvas, String text, Offset centre, Size bounds) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: colors.page,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final width = painter.width + 24;
    // Nudged back inside the canvas when the dot is near an edge, so a pill at
    // the end of the month is not half off-screen.
    final dx = centre.dx.clamp(width / 2 + 4, bounds.width - width / 2 - 4);
    final rect = Rect.fromCenter(
      center: Offset(dx, centre.dy),
      width: width,
      height: 24,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()..color = colors.ink,
    );
    painter.paint(
      canvas,
      Offset(rect.center.dx - painter.width / 2, rect.center.dy - 6),
    );
  }

  @override
  bool shouldRepaint(_BurnUpPainter old) =>
      old.series != series ||
      old.colors != colors ||
      old.calloutLabel != calloutLabel ||
      old.referenceLabel != referenceLabel ||
      old.showPaceLine != showPaceLine;
}

// =============================================================================
// The bars - "which day leaked?" / "which month was heavy?"
// =============================================================================

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.series,
    required this.money,
    required this.colors,
    required this.referenceLabel,
  });

  final SpendSeries series;
  final Money money;
  final AppColors colors;
  final String? referenceLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final points = series.points;
    if (points.isEmpty) return;

    final bottom = size.height - _axisHeight;
    final right = size.width - _plotRight;
    final top = series.maxValue * 1.12;

    double y(double value) => bottom - (value / top) * (bottom - _plotTop);

    // Each bar gets an equal slot and sits centred in it, so the gaps between
    // bars stay even however many there are.
    final slot = (right - _plotLeft) / points.length;
    final barWidth = (slot * 0.68).clamp(6.0, 22.0);

    canvas.drawLine(
      Offset(0, bottom),
      Offset(size.width, bottom),
      Paint()
        ..color = colors.hairline
        ..strokeWidth = 1,
    );

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final centre = _plotLeft + slot * (i + 0.5);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          centre - barWidth / 2,
          point.isFuture ? bottom - 22 : y(point.value),
          centre + barWidth / 2,
          bottom,
        ),
        const Radius.circular(4),
      );

      if (point.isFuture) {
        // Hollow: a month that has not happened. Drawn at a fixed small height
        // so the row of them reads as a placeholder, not as twelve tiny months.
        canvas.drawRRect(
          rect,
          Paint()
            ..color = colors.hairline
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
        continue;
      }
      if (point.value <= 0) continue;

      canvas.drawRRect(
        rect,
        Paint()
          ..color = i == series.todayIndex && series.range == ChartRange.year
              // The month in progress is not finished, so it is dimmed: its bar
              // is going to keep growing and should not be compared like-for-
              // like against the completed ones beside it.
              ? colors.series1.withValues(alpha: 0.45)
              : colors.series1,
      );
    }

    // ------------------------------------------------- the reference line
    if (series.reference > 0) {
      final line = y(series.reference);
      _dashedLine(
        canvas,
        Offset(0, line),
        Offset(size.width, line),
        Paint()
          ..color = colors.inkMuted
          ..strokeWidth = 1.5,
      );
      if (referenceLabel != null) {
        _label(
          canvas,
          referenceLabel!,
          Offset(right, line - 15),
          color: colors.inkMuted,
          size: 11,
          align: 1,
        );
      }
    }

    // --------------------------------------------------------------- axis
    final show = _labelIndices(points.length, wanted: points.length > 12 ? 4 : 5);
    for (final i in show) {
      final isNow = i == series.todayIndex;
      _label(
        canvas,
        points[i].label,
        Offset(_plotLeft + slot * (i + 0.5), bottom + 18),
        color: isNow ? colors.accentDeep : colors.inkMuted,
        weight: isNow ? FontWeight.w600 : FontWeight.w400,
        size: series.range == ChartRange.year ? 10 : 10.5,
        align: 0,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.series != series ||
      old.colors != colors ||
      old.referenceLabel != referenceLabel;
}

/// A small dashed or solid swatch for a chart legend.
///
/// The legend is what makes three lines readable; without it the dotted red and
/// the dashed grey are just two kinds of "not the main line".
class ChartLegendKey extends StatelessWidget {
  const ChartLegendKey({
    super.key,
    required this.label,
    required this.color,
    this.dashed = false,
    this.opacity = 1,
  });

  final String label;
  final Color color;
  final bool dashed;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(16, 3),
          painter: _KeyPainter(
            color: color.withValues(alpha: opacity),
            dashed: dashed,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colors.inkSecondary, fontSize: 11.5),
        ),
      ],
    );
  }
}

class _KeyPainter extends CustomPainter {
  _KeyPainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = ui.StrokeCap.round;
    final from = Offset(0, size.height / 2);
    final to = Offset(size.width, size.height / 2);
    if (dashed) {
      _dashedLine(canvas, from, to, paint, dash: 4, gap: 3);
    } else {
      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(_KeyPainter old) =>
      old.color != color || old.dashed != dashed;
}
