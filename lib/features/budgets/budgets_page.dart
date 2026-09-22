
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
import 'budget_detail_page.dart';
import 'budget_editor.dart';

/// Every budget for the selected month, both members'.
///
/// The Overview tab leads with what you control; this tab is the full list,
/// each card labelled with whose it is. An empty month offers to copy last
/// month's plan across - without that, every month starts from nothing, which
/// is the fastest way to make someone stop using a budgeting app.
class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(textProvider);
    final summary = ref.watch(summaryProvider);
    final loading = ref.watch(summaryLoadingProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('budgets.title')),
        actions: [
          const Center(child: PeriodSwitcher()),
          IconButton(
            tooltip: t('budgets.new_budget'),
            icon: const Icon(Icons.add),
            onPressed: () => showBudgetEditor(context),
          ),
          const SizedBox(width: Insets.sm),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Insets.page,
            0,
            Insets.page,
            120,
          ),
          children: [
            if (summary.isEmpty && !loading)
              _EmptyMonth(summary: summary)
            else ...[
              if (summary.monthly.isNotEmpty) ...[
                SectionHeader(title: t('budgets.this_month')),
                for (final view in summary.monthly)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: _BudgetCard(view: view),
                  ),
                const SizedBox(height: Insets.xl),
              ],
              if (summary.savings.isNotEmpty) ...[
                SectionHeader(title: t('budgets.saving_pots')),
                for (final view in summary.savings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: _BudgetCard(view: view, saving: true),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// An empty month usually means last month's plan just needs copying over.
class _EmptyMonth extends ConsumerStatefulWidget {
  const _EmptyMonth({required this.summary});

  final PeriodSummary summary;

  @override
  ConsumerState<_EmptyMonth> createState() => _EmptyMonthState();
}

class _EmptyMonthState extends ConsumerState<_EmptyMonth> {
  bool _busy = false;

  Future<void> _rollover() async {
    final householdId = ref.read(householdIdProvider);
    final uid = ref.read(currentUidProvider);
    if (householdId == null || uid == null) return;

    setState(() => _busy = true);
    try {
      final period = ref.read(selectedPeriodProvider);
      final copied = await ref.read(budgetRepositoryProvider).rollover(
            householdId: householdId,
            from: period.previous().key,
            to: period.key,
            actorUid: uid,
          );
      if (!mounted) return;
      final t = ref.read(textProvider);
      final locale = ref.read(dateLocaleProvider);
      showToast(
        context,
        copied == 0
            ? t('budgets.nothing_to_copy',
                {'month': period.previous().label(locale)})
            : t.plural(copied, 'budgets.copied_one', 'budgets.copied_many'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(textProvider);
    final locale = ref.watch(dateLocaleProvider);
    final period = ref.watch(selectedPeriodProvider);

    return Column(
      children: [
        EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: t('budgets.none_title', {'month': period.label(locale)}),
          message: t('budgets.none_blurb'),
          actionLabel: t('budgets.create'),
          onAction: () => showBudgetEditor(context),
        ),
        const SizedBox(height: Insets.sm),
        TextButton(
          onPressed: _busy ? null : _rollover,
          child: Text(t('budgets.copy_from',
              {'month': period.previous().label(locale)},),),
        ),
      ],
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  const _BudgetCard({required this.view, this.saving = false});

  final BudgetView view;
  final bool saving;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
    final money = ref.watch(moneyProvider);
    final household = ref.watch(householdProvider).valueOrNull;
    final uid = ref.watch(currentUidProvider);

    final controller = view.budget.controllerId == uid
        ? t('budgets.you_control')
        : t('budgets.partner_controls', {
            'name': household?.displayNameOf(view.budget.controllerId) ??
                t('common.partner'),
          });

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
                      controller,
                      style: text.bodySmall?.copyWith(color: colors.inkMuted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money.format(view.spent),
                    style: text.titleMedium?.copyWith(
                      color: view.isOver ? colors.negative : colors.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    '${t('common.of')} ${money.format(view.planned)}',
                    style: text.bodySmall?.copyWith(color: colors.inkMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Meter(
            progress: view.progress,
            isOver: view.isOver,
            color: saving ? colors.positive : null,
          ),
          const SizedBox(height: Insets.md),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              Tag(
                label: t.plural(view.categories.length,
                    'budgets.categories_one', 'budgets.categories_many',),
              ),
              if (view.pendingCount > 0)
                Tag(
                  label: t('budgets.awaiting',
                      {'count': '${view.pendingCount}'},),
                  icon: Icons.schedule,
                  color: colors.warning,
                  filled: true,
                ),
              if (view.isOverAllocated)
                Tag(
                  label: t('budgets.over_allocated'),
                  icon: Icons.warning_amber_rounded,
                  color: colors.negative,
                  filled: true,
                ),
              if (!view.isOverAllocated && view.unallocated > 0)
                Tag(
                  label: t('budgets.unallocated',
                      {'amount': money.compact(view.unallocated)},),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
