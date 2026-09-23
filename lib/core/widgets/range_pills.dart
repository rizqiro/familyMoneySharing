import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/chart_series.dart';
import '../../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Day / Month / Year, as one connected pill.
///
/// =============================================================================
/// WHY NOT A SegmentedButton
/// =============================================================================
/// Material's own `SegmentedButton` would do the job, but it insists on a
/// check-mark on the selected segment and an outline around the group, both of
/// which fight the flat look. Three `Expanded` buttons in a rounded container
/// is less code than overriding all that.
///
/// `Expanded` inside a `Row` means "share the leftover width equally", so the
/// three segments stay the same width whatever language the labels are in -
/// "Bulanan" and "Yearly" are different lengths, and a pill that resizes as you
/// tap through it feels broken.
///
/// The selection lives in [chartRangeProvider] rather than in this widget, so
/// the chart below reads the same value without anything being passed down.
class RangePills extends ConsumerWidget {
  const RangePills({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final t = ref.watch(textProvider);
    final selected = ref.watch(chartRangeProvider);

    return Container(
      padding: const EdgeInsets.all(Insets.xs),
      decoration: BoxDecoration(
        color: colors.track,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        children: [
          for (final range in ChartRange.values)
            Expanded(
              child: _Segment(
                label: t(range.labelKey),
                selected: range == selected,
                onTap: () =>
                    ref.read(chartRangeProvider.notifier).select(range),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Semantics(
      // Spoken as "selected" / "not selected" rather than as a plain button, so
      // the pill behaves like the radio group it really is.
      selected: selected,
      button: true,
      child: Material(
        color: selected ? colors.accent : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Container(
            // 44 is the smallest comfortable touch target. Anything under it
            // gets missed, especially one-handed.
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(
                color: selected ? colors.onAccent : colors.inkSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
