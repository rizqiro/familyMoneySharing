import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../pairing/invite_page.dart';
import '../settings/settings_page.dart';
import 'widgets/category_bars.dart';
import 'widgets/spend_split.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final household = ref.watch(householdProvider).valueOrNull;
    final summary = ref.watch(summaryProvider);
    final money = ref.watch(moneyProvider);
    final loading = ref.watch(summaryLoadingProvider);

    if (household == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          // Firestore streams keep themselves current; the gesture is here
          // because people reach for it, and it gives a clear "it is live".
          onRefresh: () async =>
              ref.invalidate(periodExpensesProvider),
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

              _HeroCard(summary: summary, loading: loading),
              const SizedBox(height: Insets.xl),

              if (household.isPaired) ...[
                const SectionHeader(title: 'Who spent what'),
                SoftCard(
                  child: SpendSplit(
                    household: household,
                    spendByMember: summary.spendByMember,
                    money: money,
                  ),
                ),
                const SizedBox(height: Insets.xl),
              ],

              if (summary.categoriesBySpend.any((c) => c.spent > 0)) ...[
                const SectionHeader(title: 'Where it went'),
                SoftCard(
                  child: CategoryBars(
                    categories: summary.categoriesBySpend,
                    money: money,
                  ),
                ),
                const SizedBox(height: Insets.xl),
              ],

              if (summary.monthly.isNotEmpty) ...[
                const SectionHeader(title: 'Budgets'),
                for (final view in summary.monthly)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: _BudgetRow(view: view),
                  ),
                const SizedBox(height: Insets.lg),
              ],

              if (summary.savings.isNotEmpty) ...[
                const SectionHeader(title: 'Saving'),
                for (final view in summary.savings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: _BudgetRow(view: view, saving: true),
                  ),
                const SizedBox(height: Insets.lg),
              ],

              if (summary.isEmpty && !loading)
                EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'No budgets for this month yet',
                  message:
                      'Set what you plan to spend, split it into categories, '
                      'and every expense will land in the right place.',
                  actionLabel: 'Create a budget',
                  onAction: () => showBudgetEditor(context),
                ),

              if (summary.expenses.isNotEmpty) ...[
                const SizedBox(height: Insets.sm),
                const SectionHeader(title: 'Latest'),
                SoftCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final expense in summary.expenses.take(5))
                        ExpenseTile(
                          expense: expense,
                          onTap: () => showExpenseEditor(
                            context,
                            existing: expense,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.md),
                Center(
                  child: Text(
                    '${summary.expenses.length} '
                    '${summary.expenses.length == 1 ? 'entry' : 'entries'} '
                    'this month',
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

class _Header extends ConsumerWidget {
  const _Header({required this.householdName});

  final String householdName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final profile = ref.watch(profileProvider).valueOrNull;

    return Row(
      children: [
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
                'Shared overview',
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

class _PairBanner extends StatelessWidget {
  const _PairBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

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
                Text('Connect your partner', style: text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Show them a QR code so you both see the same numbers.',
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

/// The one figure the app exists to answer: how much is left.
class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.summary, required this.loading});

  final PeriodSummary summary;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final money = ref.watch(moneyProvider);

    final remaining = summary.remaining;
    final over = summary.isOver;

    return SoftCard(
      padding: const EdgeInsets.all(Insets.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            over ? 'OVER BUDGET BY' : 'LEFT TO SPEND',
            style: text.labelSmall?.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: Insets.sm),
          if (loading && summary.isEmpty)
            Container(
              height: 44,
              width: 200,
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                borderRadius: BorderRadius.circular(Radii.field),
              ),
            )
          else
            Text(
              money.format(remaining.abs()),
              style: text.displayLarge?.copyWith(
                color: over ? colors.negative : colors.ink,
              ),
            ),
          const SizedBox(height: Insets.lg),

          Meter(
            progress: summary.progress,
            paceMarker: summary.period.isCurrent ? summary.periodProgress : null,
            isOver: over,
            height: 10,
          ),
          const SizedBox(height: Insets.md),

          Row(
            children: [
              Expanded(
                child: Text(
                  '${money.format(summary.spent)} of '
                  '${money.format(summary.planned)}',
                  style: text.bodySmall?.copyWith(color: colors.inkSecondary),
                ),
              ),
              if (summary.period.isCurrent && summary.planned > 0)
                Text(
                  summary.isAheadOfPace
                      ? 'Ahead of pace'
                      : '${money.compact(summary.dailyAllowance)}/day left',
                  style: text.bodySmall?.copyWith(
                    color: summary.isAheadOfPace
                        ? colors.warning
                        : colors.inkSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),

          if (summary.savedThisPeriod > 0) ...[
            const SizedBox(height: Insets.lg),
            Divider(color: colors.hairline, height: 1),
            const SizedBox(height: Insets.lg),
            Row(
              children: [
                Icon(Icons.savings_outlined, size: 16, color: colors.positive),
                const SizedBox(width: Insets.sm),
                Text(
                  'Put aside this month',
                  style: text.bodyMedium?.copyWith(color: colors.inkSecondary),
                ),
                const Spacer(),
                Text(
                  money.format(summary.savedThisPeriod),
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
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

class _BudgetRow extends ConsumerWidget {
  const _BudgetRow({required this.view, this.saving = false});

  final BudgetView view;
  final bool saving;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final money = ref.watch(moneyProvider);
    final household = ref.watch(householdProvider).valueOrNull;
    final uid = ref.watch(currentUidProvider);

    final controllerName = household == null
        ? ''
        : (view.budget.controllerId == uid
            ? 'You'
            : household.displayNameOf(view.budget.controllerId));

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
                  label: '${view.pendingCount} to confirm',
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
          Row(
            children: [
              Expanded(
                child: Text(
                  saving
                      ? 'Target ${money.format(view.planned)}'
                      : '${money.format(view.remaining.abs())} '
                          '${view.isOver ? 'over' : 'left'} of '
                          '${money.format(view.planned)}',
                  style: text.bodySmall?.copyWith(color: colors.inkSecondary),
                ),
              ),
              Text(
                '$controllerName controls',
                style: text.bodySmall?.copyWith(color: colors.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
