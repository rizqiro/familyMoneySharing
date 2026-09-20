import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A spend-against-plan bar.
///
/// The fill is anchored to the left with rounded data-ends; a pace marker
/// shows how far through the month we are, so "60% spent" can be read against
/// "we are 40% through the month" without a second chart.
class Meter extends StatelessWidget {
  const Meter({
    super.key,
    required this.progress,
    this.paceMarker,
    this.isOver = false,
    this.height = 8,
    this.color,
  });

  /// 0..1. Values above 1 are clamped - overspend is signalled by [isOver].
  final double progress;

  /// 0..1 position of the "today" tick, or null to omit it.
  final double? paceMarker;
  final bool isOver;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fill = color ?? (isOver ? colors.negative : colors.ink);
    final value = progress.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: colors.track,
                  borderRadius: BorderRadius.circular(Radii.bar),
                ),
              ),
              if (value > 0)
                Container(
                  width: (width * value).clamp(height, width),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(Radii.bar),
                  ),
                ),
              if (paceMarker != null)
                Positioned(
                  left: (width * paceMarker!.clamp(0.0, 1.0) - 1)
                      .clamp(0.0, width - 2),
                  top: -3,
                  bottom: -3,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      // A 2px surface gap keeps the marker legible where it
                      // sits on top of the fill.
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(1),
                      border: Border.all(color: colors.inkMuted, width: 0.5),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
