import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Month pager. Stepping past the current month is allowed - planning ahead is
/// a normal thing to do - but the label says so.
class PeriodSwitcher extends ConsumerWidget {
  const PeriodSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final period = ref.watch(selectedPeriodProvider);
    final controller = ref.read(selectedPeriodProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Step(icon: Icons.chevron_left, onTap: controller.previous),
          GestureDetector(
            onTap: period.isCurrent ? null : controller.today,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
              child: Text(
                period.label(),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
          _Step(icon: Icons.chevron_right, onTap: controller.next),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: context.colors.inkSecondary),
      ),
    );
  }
}
