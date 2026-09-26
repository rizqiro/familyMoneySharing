import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/period_summary.dart';
import '../../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The tinted budget cards.
///
/// =============================================================================
/// WHAT THE TINT MEANS, AND WHAT IT DOES NOT
/// =============================================================================
/// Each budget is washed in one of five warm tints. The tint carries NO meaning
/// on its own - butter is not "safe" and rose is not "danger". It is an
/// identity: a budget keeps the same colour forever, so after a week you find
/// "the peach one" without reading its name.
///
/// That works only if the colour is stable, so it is derived from the budget's
/// id by [AppColors.tintFor] rather than from its position in a list. Two
/// phones showing the same household show the same colours, and adding a budget
/// never reshuffles the others.
///
/// The things that DO carry meaning are kept separate from the tint:
///
///   * the meter fill - accent when the budget is yours, grey when it is your
///     partner's, green for a saving pot;
///   * the amount - accent-deep once you are over.
///
/// Text on a tinted card is the ordinary ink. The five fills are picked light
/// enough (dark enough in dark mode) that it clears 4.5:1 on every one.

/// A budget icon, chosen stably from the budget id, the same way the tint is.
///
/// Saving pots always get the piggy bank - that one IS meaningful, because a
/// pot you are filling behaves differently from a budget you are emptying.
IconData budgetIcon(String id, {required bool saving}) {
  if (saving) return Icons.savings_outlined;
  const icons = [
    Icons.shopping_cart_outlined,
    Icons.home_outlined,
    Icons.restaurant_outlined,
    Icons.directions_car_outlined,
    Icons.bolt_outlined,
  ];
  if (id.isEmpty) return icons.first;
  var sum = 0;
  for (final unit in id.codeUnits) {
    sum += unit;
  }
  return icons[sum % icons.length];
}

/// The small card in the Overview's horizontal strip.
///
/// Fixed width so the strip scrolls with a consistent rhythm and the next card
/// peeks in from the right edge - the cheapest possible hint that there is more
/// to swipe to.
class BudgetMiniCard extends ConsumerWidget {
  const BudgetMiniCard({
    super.key,
    required this.view,
    required this.onTap,
    this.width = 158,
  });

  final BudgetView view;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
    final money = ref.watch(moneyProvider);
    final uid = ref.watch(currentUidProvider);

    final tint = colors.tintFor(view.budget.id);
    final saving = view.budget.isSaving;
    final mine = view.isControlledBy(uid);

    return SizedBox(
      width: width,
      child: Material(
        color: tint.fill,
        borderRadius: BorderRadius.circular(Radii.tile),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Badge(tint: tint, icon: budgetIcon(view.budget.id, saving: saving)),
                // The gap is doing layout work: it pushes the figure to the
                // bottom of a fixed-height card so every card in the strip
                // lines its numbers up on the same row.
                const SizedBox(height: Insets.xl),
                Text(
                  money.format(view.spent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleLarge?.copyWith(
                    fontSize: 19,
                    color: view.isOver ? colors.accentDeep : colors.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  view.budget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 1),
                Text(
                  saving
                      ? t('dashboard.target_of',
                          {'amount': money.compact(view.planned)},)
                      : '${t('common.of')} ${money.format(view.available)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall
                      ?.copyWith(fontSize: 11, color: colors.inkSecondary),
                ),
                const SizedBox(height: Insets.sm),
                _TintedMeter(
                  progress: view.progress,
                  fill: saving
                      ? colors.positive
                      : (mine ? colors.accent : colors.inkMuted),
                  height: 5,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The full-width card in the Budgets tab.
class BudgetTile extends ConsumerWidget {
  const BudgetTile({
    super.key,
    required this.view,
    required this.onTap,
    this.trailing = const [],
  });

  final BudgetView view;
  final VoidCallback onTap;

  /// Extra chips along the bottom - "5 categories", "1 waiting", "too fast".
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
    final money = ref.watch(moneyProvider);
    final uid = ref.watch(currentUidProvider);
    final household = ref.watch(householdProvider).valueOrNull;

    final tint = colors.tintFor(view.budget.id);
    final saving = view.budget.isSaving;
    final mine = view.isControlledBy(uid);
    final controller = mine
        ? t('budgets.you_control')
        : t('budgets.partner_controls', {
            'name': household?.displayNameOf(view.budget.controllerId, unknown: t('common.someone')) ??
                t('common.partner'),
          });

    return Material(
      color: tint.fill,
      borderRadius: BorderRadius.circular(Radii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Badge(
                    tint: tint,
                    icon: budgetIcon(view.budget.id, saving: saving),
                    size: 38,
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          view.budget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(fontSize: 17),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          controller,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall
                              ?.copyWith(color: colors.inkSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        money.format(view.spent),
                        style: text.titleMedium?.copyWith(
                          fontSize: 17,
                          color: view.isOver
                              ? colors.accentDeep
                              : (saving ? colors.positive : colors.ink),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        saving
                            ? t('dashboard.target_of',
                                {'amount': money.compact(view.planned)},)
                            : '${t('common.of')} ${money.format(view.available)}',
                        style: text.bodySmall?.copyWith(
                          fontSize: 12,
                          color: colors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Insets.lg),
              _TintedMeter(
                progress: view.progress,
                fill: saving
                    ? colors.positive
                    : (mine ? colors.accent : colors.inkMuted),
              ),
              if (trailing.isNotEmpty) ...[
                const SizedBox(height: Insets.md),
                // `Wrap` is a Row that moves onto a second line instead of
                // overflowing, which matters once a chip's text is translated
                // into a longer language.
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.sm,
                  children: trailing,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A chip that sits on a tinted card.
///
/// Translucent white rather than a solid colour, so one chip style works on all
/// five tints without five variants of it.
class TintChip extends StatelessWidget {
  const TintChip({
    super.key,
    required this.label,
    this.emphasis = false,
  });

  final String label;

  /// Fills with the accent instead - for the one chip on a card that is a
  /// warning rather than a fact.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: emphasis
            ? colors.accent
            : colors.surface.withValues(alpha: colors.isDark ? 0.10 : 0.72),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: emphasis ? colors.onAccent : colors.ink,
              fontWeight: emphasis ? FontWeight.w500 : FontWeight.w400,
            ),
      ),
    );
  }
}

/// The solid dot carrying the budget's icon.
class _Badge extends StatelessWidget {
  const _Badge({required this.tint, required this.icon, this.size = 32});

  final BudgetTint tint;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tint.badge, shape: BoxShape.circle),
      // White on the badge colours rather than ink: the badges are the most
      // saturated thing in the palette and ink on them muddies.
      child: Icon(icon, size: size * 0.5, color: Colors.white),
    );
  }
}

/// A meter drawn for a tinted background.
///
/// The app's usual [Meter] draws its track in the theme's track colour, which
/// disappears on a tint. This one uses a translucent ink wash, so the track is
/// always a shade of whatever it is sitting on.
class _TintedMeter extends StatelessWidget {
  const _TintedMeter({
    required this.progress,
    required this.fill,
    this.height = 8,
  });

  final double progress;
  final Color fill;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final value = progress.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Stack(
        children: [
          Container(
            height: height,
            color: colors.ink.withValues(alpha: colors.isDark ? 0.22 : 0.10),
          ),
          // `FractionallySizedBox` sizes itself to a fraction of its parent, so
          // the fill follows the card's width without a LayoutBuilder.
          FractionallySizedBox(
            widthFactor: value,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
