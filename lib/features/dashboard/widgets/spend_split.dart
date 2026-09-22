import 'package:flutter/material.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/household.dart';

/// Who spent what this month.
///
/// Two series, so both get a legend entry *and* a direct label - identity is
/// never left to colour alone. A 2px surface gap separates the segments.
class SpendSplit extends StatelessWidget {
  const SpendSplit({
    super.key,
    required this.household,
    required this.spendByMember,
    required this.money,
    required this.youLabel,
    required this.viewerUid,
    required this.emptyLabel,
  });

  final Household household;
  final Map<String, double> spendByMember;
  final Money money;

  /// What to call the viewer - "You" / "Kamu" / "Pian", depending on language.
  /// Passed in rather than looked up here so this widget stays a plain chart
  /// with no dependency on providers.
  final String youLabel;

  /// Who is looking, so their own row reads "You" rather than their name.
  final String? viewerUid;

  /// Shown instead of the chart when nothing has been spent yet.
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    final entries = household.memberIds
        .map((uid) => (uid, spendByMember[uid] ?? 0.0))
        .toList();
    final total = entries.fold(0.0, (sum, e) => sum + e.$2);
    if (total <= 0) {
      return Text(
        emptyLabel,
        style: text.bodyMedium?.copyWith(color: colors.inkSecondary),
      );
    }

    final ramp = colors.seriesRamp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 10,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final gap = entries.where((e) => e.$2 > 0).length > 1 ? 2.0 : 0.0;
              final usable = width - gap * (entries.length - 1);

              return Row(
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    SizedBox(
                      width: (usable * (entries[i].$2 / total))
                          .clamp(entries[i].$2 > 0 ? 4.0 : 0.0, usable),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: ramp[i % ramp.length],
                          borderRadius: BorderRadius.circular(Radii.bar),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: Insets.md),
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: ramp[i % ramp.length],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    entries[i].$1 == viewerUid
                        ? youLabel
                        : household.displayNameOf(entries[i].$1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium,
                  ),
                ),
                Text(
                  '${((entries[i].$2 / total) * 100).round()}%',
                  style: text.bodySmall?.copyWith(color: colors.inkMuted),
                ),
                const SizedBox(width: Insets.md),
                Text(
                  money.format(entries[i].$2),
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
