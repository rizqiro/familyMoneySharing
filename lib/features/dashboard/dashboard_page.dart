import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/money.dart';
import '../../core/i18n/app_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/budget_tile.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/meter.dart';
import '../../core/widgets/period_switcher.dart';
import '../../core/widgets/range_pills.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/spend_chart.dart';
import '../../state/chart_series.dart';
import '../../state/period_summary.dart';
import '../../state/providers.dart';
import '../budgets/budget_detail_page.dart';
import '../budgets/budget_editor.dart';
import '../expenses/expense_editor.dart';
import '../expenses/expense_tile.dart';
import '../money/request_money_sheet.dart';
import '../pairing/invite_page.dart';
import '../settings/settings_page.dart';
import 'widgets/category_bars.dart';
import 'widgets/spend_split.dart';

/// The Overview tab.
///
/// =============================================================================
/// READING ORDER, AND WHY IT IS THIS WAY
/// =============================================================================
/// The page is ordered by what you can act on, most actionable first:
///
///   1. THE CHART           - how the budget you control is doing, right now,
///                             at whichever of the three ranges you picked.
///   2. YOUR BUDGETS        - the only money you may actually spend.
///   3. ACCUMULATED BUDGET  - the household total. Context, not an action.
///   4. THEIR BUDGETS       - visible, with a way to ask rather than a way in.
///   5. Split and ledger    - history.
///
/// The household total used to be the hero, which was the wrong emphasis: it
/// includes money controlled by the other person, so the biggest number on the
/// screen was partly money you could not touch.
///
/// =============================================================================
/// HOW A FLUTTER SCREEN IS BUILT
/// =============================================================================
/// Everything visible is a Widget, nested in a tree. `build` returns a fresh
/// description of the screen; Flutter compares it with the previous one and
/// changes only what differs, so rebuilding often is cheap and normal.
///
/// `ConsumerWidget` is Riverpod's version of a stateless widget: same thing plus
/// a `ref` for reading providers.
///
/// Every piece of text comes from `t('some.key')` rather than being written
/// here, so the screen works in all five languages. See `core/i18n/app_text.dart`.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
    final household = ref.watch(householdProvider).valueOrNull;
    final summary = ref.watch(summaryProvider);
    final money = ref.watch(moneyProvider);
    final loading = ref.watch(summaryLoadingProvider);
    final partner = ref.watch(partnerProvider);

    if (household == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final partnerName = partner?.displayName.trim().split(' ').first ??
        t('common.partner');

    return Scaffold(
      body: SafeArea(
        // The bottom edge is left unpadded because the nav bar and floating
        // button already sit there; the list adds its own bottom padding.
        bottom: false,
        child: RefreshIndicator(
          // Firestore streams keep themselves current, so this is not strictly
          // needed. It is here because people reach for pull-to-refresh, and
          // its absence reads as the app being stuck.
          onRefresh: () async => ref.invalidate(periodExpensesProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              Insets.md,
              Insets.page,
              120,
            ),
            children: [
              _Header(householdName: household.name),
              const SizedBox(height: Insets.lg),

              if (!household.isPaired) ...[
                const _PairBanner(),
                const SizedBox(height: Insets.lg),
              ],

              // ------------------------------ 1. the filter and the chart
              const RangePills(),
              const SizedBox(height: Insets.lg),
              _ChartBlock(summary: summary),
              const SizedBox(height: Insets.xl),

              // ----------------------------------------------- 2. yours
              SectionHeader(title: t('dashboard.your_budgets')),
              if (summary.hasNothingToSpend && !loading)
                const _NothingToSpendCard()
              else
                _BudgetStrip(summary: summary),
              const SizedBox(height: Insets.xl),

              // -------------------------------------- 3. household total
              SectionHeader(title: t('dashboard.accumulated')),
              _AccumulatedCard(summary: summary),
              const SizedBox(height: Insets.xl),

              // ---------------------------------------------- 4. theirs
              if (summary.theirBudgets.isNotEmpty) ...[
                SectionHeader(
                  title: t('dashboard.their_budgets', {'name': partnerName}),
                ),
                for (final view in summary.theirBudgets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: _TheirBudgetCard(view: view),
                  ),
                const SizedBox(height: Insets.xl),
              ],

              // ------------------------------------- 5. split & ledger
              if (household.isPaired) ...[
                SectionHeader(title: t('dashboard.who_spent')),
                SoftCard(
                  child: SpendSplit(
                    household: household,
                    spendByMember: summary.spendByMember,
                    money: money,
                    youLabel: t('common.you'),
                    viewerUid: summary.viewerUid,
                    emptyLabel: t('ledger.empty'),
                  ),
                ),
                const SizedBox(height: Insets.xl),
              ],

              if (summary.categoriesBySpend.any((c) => c.spent > 0)) ...[
                SectionHeader(title: t('dashboard.where_went')),
                SoftCard(
                  child: CategoryBars(
                    categories: summary.categoriesBySpend,
                    money: money,
                    otherLabel: t('dashboard.other', {
                      'count': '${(summary.categoriesBySpend.where((c) => c.spent > 0).length - 6).clamp(0, 999)}',
                    }),
                  ),
                ),
                const SizedBox(height: Insets.xl),
              ],

              if (summary.expenses.isNotEmpty) ...[
                SectionHeader(title: t('dashboard.latest')),
                SoftCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final expense in summary.expenses.take(5))
                        ExpenseTile(
                          expense: expense,
                          // Every entry is visible, but only the controller of
                          // its budget may correct it - so rows that are not
                          // yours simply do not respond to a tap.
                          onTap: summary.spendable.any(
                            (b) => b.budget.id == expense.budgetId,
                          )
                              ? () => showExpenseEditor(
                                    context,
                                    existing: expense,
                                  )
                              : null,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.md),
                Center(
                  child: Text(
                    t.plural(
                      summary.expenses.length,
                      'dashboard.entries_one',
                      'dashboard.entries_many',
                    ),
                    style: text.bodySmall?.copyWith(color: colors.inkMuted),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Household name, month pager, and the avatar that opens Settings.
class _Header extends ConsumerWidget {
  const _Header({required this.householdName});

  final String householdName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
    final profile = ref.watch(profileProvider).valueOrNull;

    return Row(
      children: [
        // `Expanded` tells the Row to give this child whatever width is left
        // after the fixed-size children. Without it, a long household name
        // would overflow and Flutter would paint the yellow-and-black stripes.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                householdName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleLarge,
              ),
              const SizedBox(height: 2),
              Text(
                t('dashboard.subtitle'),
                style: text.bodySmall?.copyWith(color: colors.inkMuted),
              ),
            ],
          ),
        ),
        const PeriodSwitcher(),
        const SizedBox(width: Insets.sm),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
          ),
          child: MemberAvatar(initial: profile?.initial ?? '?'),
        ),
      ],
    );
  }
}

/// Shown until the second member joins.
class _PairBanner extends ConsumerWidget {
  const _PairBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);

    return SoftCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const InvitePage()),
      ),
      color: colors.surfaceSunken,
      child: Row(
        children: [
          Icon(Icons.qr_code_2, size: 22, color: colors.ink),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('dashboard.connect'), style: text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  t('dashboard.connect_blurb'),
                  style: text.bodySmall?.copyWith(color: colors.inkSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 20, color: colors.inkMuted),
        ],
      ),
    );
  }
}

/// The headline figure, the chart, and the sentence that says what it means.
///
/// =============================================================================
/// WHY THE HEADLINE IS *YOUR* BUDGET AND NOT THE HOUSEHOLD TOTAL
/// =============================================================================
/// The household total includes money your partner controls, which you may look
/// at but not spend. Making it the biggest number on the screen would answer a
/// question nobody asks. The number here is what you personally have left.
///
/// The chart below it changes SHAPE with the filter rather than just its range,
/// because each range asks something different - see [ChartRange].
class _ChartBlock extends ConsumerWidget {
  const _ChartBlock({required this.summary});

  final PeriodSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
    final money = ref.watch(moneyProvider);
    final range = ref.watch(chartRangeProvider);
    final series = ref.watch(dashboardSeriesProvider);
    final focus = ref.watch(focusBudgetProvider);

    final over = focus?.isOver ?? summary.isOver;
    final headline = (focus?.remaining ?? summary.remaining).abs();
    final name = focus?.budget.name;

    // The per-day chip only means anything for a month still running, and only
    // when there is something left to spread over the days remaining.
    final showAllowance =
        range == ChartRange.month && summary.period.isCurrent && !over;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    money.format(headline),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.displayMedium?.copyWith(
                      color: over ? colors.accentDeep : colors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _headlineCaption(t, name: name, over: over),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: colors.inkSecondary),
                  ),
                ],
              ),
            ),
            if (showAllowance) ...[
              const SizedBox(width: Insets.md),
              Tag(
                label: t('dashboard.per_day_left', {
                  'amount': money.compact(
                    summary.dailyAllowanceFor(focus?.remaining ?? summary.remaining),
                  ),
                }),
                color: colors.accentDeep,
                filled: true,
              ),
            ],
          ],
        ),
        const SizedBox(height: Insets.lg),

        // Full-bleed: the drawing spills back out through the page gutter so it
        // reads as the page's own picture rather than one more card in a stack.
        FullBleed(
          height: 212,
          child: SpendChart(
            series: series,
            money: money,
            height: 212,
            semanticLabel: _semanticLabel(t, money, series, range),
            referenceLabel: range == ChartRange.day
                // The daily allowance line sits low in the plot, where a label
                // would land on top of the bars. The caption underneath says it
                // instead.
                ? null
                : t('chart.budget_of',
                    {'amount': money.compact(series.reference)},),
            calloutLabel: range == ChartRange.month && series.spent > 0
                ? money.format(series.spent)
                : null,
          ),
        ),

        _ChartCaption(series: series, range: range, summary: summary),

        if (focus != null && focus.hasTransfers) ...[
          const SizedBox(height: Insets.md),
          _TransferNote(view: focus),
        ],
      ],
    );
  }

  String _headlineCaption(AppText t, {String? name, required bool over}) {
    if (name == null) {
      return t(over ? 'chart.over_household' : 'chart.left_household');
    }
    return t(over ? 'chart.over_in' : 'chart.left_in', {'name': name});
  }

  /// What a screen reader says in place of the drawing.
  ///
  /// A chart is a picture of numbers; this is the same numbers as a sentence.
  /// Without it the most important thing on the screen is silent.
  String _semanticLabel(
    AppText t,
    Money money,
    SpendSeries series,
    ChartRange range,
  ) {
    return t('chart.a11y', {
      'range': t(range.labelKey),
      'spent': money.format(series.spent),
      'budget': money.format(series.reference),
    });
  }
}

/// The sentence under the chart.
///
/// Every range gets one, and each says the thing the drawing cannot: what the
/// projection lands on, how many days ran hot, what the year adds up to. A
/// chart without a sentence makes you do the reading.
class _ChartCaption extends ConsumerWidget {
  const _ChartCaption({
    required this.series,
    required this.range,
    required this.summary,
  });

  final SpendSeries series;
  final ChartRange range;
  final PeriodSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final t = ref.watch(textProvider);
    final money = ref.watch(moneyProvider);

    final (icon, tone, message) = switch (range) {
      ChartRange.month => _monthCaption(t, money, colors),
      ChartRange.day => (
          Icons.straighten,
          colors.inkSecondary,
          _dayCaption(t, money),
        ),
      ChartRange.year => (
          Icons.calendar_today_outlined,
          colors.inkSecondary,
          t('chart.year_note', {
            'amount': money.format(series.spent),
            'year': '${summary.period.year}',
          }),
        ),
    };

    if (message.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: Insets.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: tone),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.inkSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// "Keep going at this rate and you finish at X" - with the tone flipping to
  /// a warning when X is over the budget.
  (IconData, Color, String) _monthCaption(
    AppText t,
    Money money,
    AppColors colors,
  ) {
    if (series.projected <= 0) {
      return (Icons.schedule, colors.inkSecondary, t('chart.projection_none'));
    }
    if (series.projectedOverspend > 0) {
      return (
        Icons.warning_amber_rounded,
        colors.accentDeep,
        t('chart.projection_over', {
          'amount': money.format(series.projected),
          'over': money.format(series.projectedOverspend),
        }),
      );
    }
    return (
      Icons.check,
      colors.positive,
      t('chart.projection_ok', {
        'amount': money.format(series.projected),
        'left': money.format(series.reference - series.projected),
      }),
    );
  }

  /// "The daily allowance is X, and N days went over it."
  ///
  /// The count is what turns the dashed line from decoration into a finding.
  String _dayCaption(AppText t, Money money) {
    if (series.reference <= 0) return '';
    final over = series.points.where((p) => p.value > series.reference).length;
    if (over == 0) {
      return t('chart.daily_note_none',
          {'amount': money.compact(series.reference)},);
    }
    return t.plural(
      over,
      'chart.daily_note_one',
      'chart.daily_note_many',
      {'amount': money.compact(series.reference)},
    );
  }
}

/// The horizontal strip of tinted budget cards.
///
/// Full-bleed and horizontally scrolling, so the card at the right edge is cut
/// off rather than fitted - which is the clearest possible sign that the strip
/// scrolls. A row that fits exactly looks like the whole list.
class _BudgetStrip extends ConsumerWidget {
  const _BudgetStrip({required this.summary});

  final PeriodSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = [...summary.myMonthly, ...summary.mySavings];

    return FullBleed(
      height: 178,
      child: ListView(
        scrollDirection: Axis.horizontal,
        // The padding rebuilds the page gutter inside the full-bleed band, so
        // the first card lines up with the text above it.
        padding: const EdgeInsets.symmetric(horizontal: Insets.page),
        children: [
          for (final view in mine) ...[
            BudgetMiniCard(
              view: view,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BudgetDetailPage(budgetId: view.budget.id),
                ),
              ),
            ),
            const SizedBox(width: Insets.md),
          ],
          const _AddBudgetCard(),
        ],
      ),
    );
  }
}

/// The last card in the strip: start another budget.
///
/// Deliberately untinted - a sunken grey slot rather than a sixth colour, so it
/// reads as an empty space waiting to be filled instead of as one more budget.
class _AddBudgetCard extends ConsumerWidget {
  const _AddBudgetCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final t = ref.watch(textProvider);

    return SizedBox(
      width: 130,
      child: Material(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(Radii.tile),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showBudgetEditor(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 22, color: colors.inkSecondary),
              const SizedBox(height: Insets.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                child: Text(
                  t('budgets.new_budget'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.inkSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Explains a budget total that differs from what its controller set.
class _TransferNote extends ConsumerWidget {
  const _TransferNote({required this.view});

  final BudgetView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final t = ref.watch(textProvider);
    final money = ref.watch(moneyProvider);
    final net = view.transferredIn - view.transferredOut;
    final gained = net > 0;

    return Row(
      children: [
        Icon(
          gained ? Icons.south_west : Icons.north_east,
          size: 14,
          color: gained ? colors.positive : colors.inkSecondary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            t(gained ? 'dashboard.moved_in' : 'dashboard.moved_out', {
              'amount': money.format(net.abs()),
              'base': money.format(view.baseAmount),
            }),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.inkSecondary),
          ),
        ),
      ],
    );
  }
}

/// The state the ownership rule creates: you control nothing, so there is
/// nothing to spend from.
class _NothingToSpendCard extends ConsumerWidget {
  const _NothingToSpendCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
    final partner = ref.watch(partnerProvider);
    final partnerName = partner?.displayName.split(' ').first;

    return SoftCard(
      padding: const EdgeInsets.all(Insets.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 22,
                color: colors.inkMuted,
              ),
            ),
          ),
          const SizedBox(height: Insets.lg),
          Text(
            t('dashboard.no_budget_title'),
            textAlign: TextAlign.center,
            style: text.titleMedium,
          ),
          const SizedBox(height: Insets.xs),
          Text(
            partnerName == null
                ? t('dashboard.no_budget_blurb_solo')
                : t('dashboard.no_budget_blurb', {'name': partnerName}),
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: colors.inkSecondary),
          ),
          const SizedBox(height: Insets.xl),
          if (partnerName != null) ...[
            FilledButton(
              onPressed: () => showRequestMoneySheet(context),
              child: Text(
                t('dashboard.request_from', {'name': partnerName}),
              ),
            ),
            const SizedBox(height: Insets.md),
          ],
          OutlinedButton(
            onPressed: () => showBudgetEditor(context),
            child: Text(t('dashboard.create_my_budget')),
          ),
        ],
      ),
    );
  }
}

/// The household total. Demoted from hero to supporting card, and split so it
/// is clear how much of it is actually yours.
class _AccumulatedCard extends ConsumerWidget {
  const _AccumulatedCard({required this.summary});

  final PeriodSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
    final money = ref.watch(moneyProvider);
    final partner = ref.watch(partnerProvider);
    final over = summary.isOver;

    return SoftCard(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            // A baseline row needs to know which script's baseline to use;
            // alphabetic is the right one for Latin text.
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                money.format(summary.remaining.abs()),
                style: text.displayMedium?.copyWith(
                  color: over ? colors.negative : colors.ink,
                ),
              ),
              const SizedBox(width: Insets.sm),
              Text(
                over ? t('common.over') : t('common.left'),
                style: text.bodySmall?.copyWith(color: colors.inkSecondary),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Meter(
            progress: summary.progress,
            paceMarker:
                summary.period.isCurrent ? summary.periodProgress : null,
            isOver: over,
          ),
          const SizedBox(height: Insets.md),
          Text(
            t(
              partner == null
                  ? 'dashboard.spent_of_solo'
                  : 'dashboard.spent_of_both',
              {
                'spent': money.format(summary.spent),
                'planned': money.format(summary.planned),
              },
            ),
            style: text.bodySmall?.copyWith(color: colors.inkSecondary),
          ),

          if (partner != null) ...[
            const SizedBox(height: Insets.lg),
            Divider(color: colors.hairline, height: 1),
            const SizedBox(height: Insets.lg),
            Row(
              children: [
                Expanded(
                  child: Stat(
                    label: t('dashboard.yours'),
                    value: money.format(summary.myRemaining),
                  ),
                ),
                Expanded(
                  child: Stat(
                    label: t('dashboard.theirs', {
                      'name': partner.displayName.split(' ').first,
                    }),
                    value: money.format(summary.theirRemaining),
                  ),
                ),
              ],
            ),
          ],

          if (summary.savedThisPeriod > 0) ...[
            const SizedBox(height: Insets.lg),
            Divider(color: colors.hairline, height: 1),
            const SizedBox(height: Insets.lg),
            Row(
              children: [
                Icon(Icons.savings_outlined, size: 16, color: colors.positive),
                const SizedBox(width: Insets.sm),
                Text(
                  t('dashboard.put_aside'),
                  style: text.bodyMedium?.copyWith(color: colors.inkSecondary),
                ),
                const Spacer(),
                Text(
                  money.format(summary.savedThisPeriod),
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    // Tabular figures keep digits the same width, so numbers in
                    // a column line up instead of jittering.
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A budget the other member controls: visible, with a way to ask rather than
/// a way in.
class _TheirBudgetCard extends ConsumerWidget {
  const _TheirBudgetCard({required this.view});

  final BudgetView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
    final money = ref.watch(moneyProvider);

    return SoftCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BudgetDetailPage(budgetId: view.budget.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                view.budget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                _summaryLine(t, money, view),
                style: text.bodySmall?.copyWith(color: colors.inkSecondary),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Meter(
            progress: view.progress,
            isOver: view.isOver,
            // Grey rather than ink: theirs is context, not something to act on.
            color: colors.inkMuted,
          ),
          if (!view.budget.isSaving) ...[
            const SizedBox(height: Insets.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    t('dashboard.see_not_spend'),
                    style:
                        text.bodySmall?.copyWith(color: colors.inkSecondary),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                OutlinedButton(
                  onPressed: () =>
                      showRequestMoneySheet(context, fromBudget: view),
                  style: OutlinedButton.styleFrom(
                    // The theme's default is a full-width 54px button; a button
                    // sharing a row needs to shrink to its label.
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.lg,
                      vertical: Insets.sm,
                    ),
                    textStyle: text.labelMedium,
                  ),
                  child: Text(t('dashboard.request_money')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "Rp 2.650.000 left of Rp 6.000.000", or the saving-pot equivalent.
///
/// A free function rather than a method because three different cards need the
/// same line, and none of them owns it.
String _summaryLine(AppText t, Money money, BudgetView view) {
  if (view.budget.isSaving) {
    return t('dashboard.saving_of', {
      'spent': money.format(view.spent),
      'planned': money.format(view.planned),
    });
  }
  return t(view.isOver ? 'dashboard.over_of' : 'dashboard.left_of', {
    'amount': money.format(view.remaining.abs()),
    'planned': money.format(view.planned),
  });
}
