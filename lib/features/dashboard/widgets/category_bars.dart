import 'package:flutter/material.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../state/period_summary.dart';

/// Where the month's money went, ranked.
///
/// Ranked bars rather than a donut: the question is "which is biggest and by
/// how much", which is a length comparison. One hue throughout - the category
/// name is the identity, so colour has no job here beyond being the mark.
class CategoryBars extends StatelessWidget {
  const CategoryBars({
    super.key,
    required this.categories,
    required this.money,
    this.maxRows = 6,
  });

  final List<CategoryView> categories;
  final Money money;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    final spent = categories.where((c) => c.spent > 0).toList();
    if (spent.isEmpty) return const SizedBox.shrink();

    final shown = spent.take(maxRows).toList();
    final rest = spent.skip(maxRows).toList();
    final otherTotal = rest.fold(0.0, (sum, c) => sum + c.spent);

    // The scale is set by the largest bar, so the longest row always fills the
    // track and the rest are read against it.
    final peak = [
      ...shown.map((c) => c.spent),
      otherTotal,
    ].fold(0.0, (a, b) => a > b ? a : b);

    Widget row(String label, String emoji, double value, bool isOther) {
      final fraction = peak <= 0 ? 0.0 : (value / peak).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.only(bottom: Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      color: isOther ? colors.inkSecondary : colors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Text(
                  money.format(value),
                  style: text.bodyMedium?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors.track,
                      borderRadius: BorderRadius.circular(Radii.bar),
                    ),
                  ),
                  Container(
                    height: 6,
                    width: (constraints.maxWidth * fraction)
                        .clamp(fraction > 0 ? 6.0 : 0.0, constraints.maxWidth),
                    decoration: BoxDecoration(
                      color: isOther
                          ? colors.inkMuted
                          : colors.series1,
                      borderRadius: BorderRadius.circular(Radii.bar),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in shown)
          row(c.category.name, c.category.emoji, c.spent, false),
        if (rest.isNotEmpty)
          row('Other (${rest.length})', '…', otherTotal, true),
      ],
    );
  }
}
