import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/money.dart';
import '../../core/i18n/app_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/meter.dart';
import '../../core/widgets/period_switcher.dart';
import '../../core/widgets/soft_card.dart';
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
///   1. YOUR BUDGETS        - the only money you may actually spend. The hero.
///   2. ACCUMULATED BUDGET  - the household total. Context, not an action.
///   3. THEIR BUDGETS       - visible, with a way to ask rather than a way in.
///   4. Charts and ledger   - history.
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

              // ----------------------------------------------- 1. yours
              SectionHeader(title: t('dashboard.your_budgets')),
              if (summary.hasNothingToSpend && !loading)
                const _NothingToSpendCard()
              else ...[
                // The first budget gets the hero treatment; the rest are
                // compact rows. One big number beats several medium ones.
                for (var i = 0; i < summary.myMonthly.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: i == 0
                        ? _MyBudgetHero(
                            view: summary.myMonthly[i],
                            summary: summary,
                          )
                        : _BudgetRow(view: summary.myMonthly[i]),
                  ),
                for (final view in summary.mySavings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: _BudgetRow(view: view, saving: true),
                  ),
              ],
              const SizedBox(height: Insets.xl),

              // -------------------------------------- 2. household total
              SectionHeader(title: t('dashboard.accumulated')),
              _AccumulatedCard(summary: summary),
              const SizedBox(height: Insets.xl),

              // ---------------------------------------------- 3. theirs
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

              // ------------------------------------- 4. charts & ledger
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

/// The hero: the budget you control and can actually spend from.
class _MyBudgetHero extends ConsumerWidget {
  const _MyBudgetHero({required this.view, required this.summary});

  final BudgetView view;
  final PeriodSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
    final money = ref.watch(moneyProvider);
    final over = view.isOver;

    return SoftCard(
      padding: const EdgeInsets.all(Insets.xl),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BudgetDetailPage(budgetId: view.budget.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
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
                      t('dashboard.you_control'),
                      style:
                          text.bodySmall?.copyWith(color: colors.inkSecondary),
                    ),
                  ],
                ),
              ),
              if (view.pendingCount > 0)
                Tag(
                  label: t('dashboard.to_confirm',
                      {'count': '${view.pendingCount}'}),
                  icon: Icons.schedule,
                  color: colors.warning,
                  filled: true,
                ),
            ],
          ),
          const SizedBox(height: Insets.lg),

          Text(
            over
                ? t('dashboard.over_budget_by')
                : t('dashboard.left_to_spend'),
            style: text.labelSmall?.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: 6),
          Text(
            money.format(view.remaining.abs()),
            style: text.displayLarge?.copyWith(
              color: over ? colors.negative : colors.ink,
            ),
          ),
          const SizedBox(height: Insets.lg),

          Meter(
            progress: view.progress,
            // The pace tick only means something in a month still running.
            paceMarker:
                summary.period.isCurrent ? summary.periodProgress : null,
            isOver: over,
            height: 10,
          ),
          const SizedBox(height: Insets.md),

          Row(
            children: [
              Expanded(
                child: Text(
                  t('dashboard.spent_of', {
                    'spent': money.format(view.spent),
                    'planned': money.format(view.planned),
                  }),
                  style: text.bodySmall?.copyWith(color: colors.inkSecondary),
                ),
              ),
              if (summary.period.isCurrent && view.planned > 0)
                Text(
                  summary.isAheadOfPace
                      ? t('dashboard.ahead_of_pace')
                      : t('dashboard.per_day_left', {
                          'amount': money.compact(
                            summary.dailyAllowanceFor(view.remaining),
                          ),
                        }),
                  style: text.bodySmall?.copyWith(
                    color: summary.isAheadOfPace
                        ? colors.warning
                        : colors.inkSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),

          // Only shown when a transfer actually happened, so the figure above
          // never silently disagrees with what the controller typed in.
          if (view.hasTransfers) ...[
            const SizedBox(height: Insets.md),
            _TransferNote(view: view),
          ],
        ],
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

/// A compact row for a second or third budget of your own.
class _BudgetRow extends ConsumerWidget {
  const _BudgetRow({required this.view, this.saving = false});

  final BudgetView view;
  final bool saving;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  view.budget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium,
                ),
              ),
              if (view.pendingCount > 0) ...[
                Tag(
                  label: t('dashboard.to_confirm',
                      {'count': '${view.pendingCount}'}),
                  icon: Icons.schedule,
                  color: colors.warning,
                  filled: true,
                ),
                const SizedBox(width: Insets.sm),
              ],
              Text(
                money.format(view.spent),
                style: text.titleMedium?.copyWith(
                  color: view.isOver ? colors.negative : colors.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Meter(
            progress: view.progress,
            isOver: view.isOver,
            color: saving ? colors.positive : null,
          ),
          const SizedBox(height: Insets.sm),
          Text(
            saving
                ? t('dashboard.target_of',
                    {'amount': money.format(view.planned)})
                : _summaryLine(t, money, view),
            style: text.bodySmall?.copyWith(color: colors.inkSecondary),
          ),
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
