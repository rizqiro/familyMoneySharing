
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

class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(summaryProvider);
    final loading = ref.watch(summaryLoadingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          const Center(child: PeriodSwitcher()),
          IconButton(
            tooltip: 'New budget',
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
                const SectionHeader(title: 'This month'),
                for (final view in summary.monthly)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: _BudgetCard(view: view),
                  ),
                const SizedBox(height: Insets.xl),
              ],
              if (summary.savings.isNotEmpty) ...[
                const SectionHeader(title: 'Saving pots'),
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
      showToast(
        context,
        copied == 0
            ? 'Nothing of yours to copy from ${period.previous().label()}.'
            : 'Copied $copied ${copied == 1 ? 'budget' : 'budgets'}.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(selectedPeriodProvider);

    return Column(
      children: [
        EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'No budgets for ${period.label()}',
          message:
              'Decide what you plan to spend, split it into categories, and '
              'both of you can start logging against it.',
          actionLabel: 'Create a budget',
          onAction: () => showBudgetEditor(context),
        ),
        const SizedBox(height: Insets.sm),
        TextButton(
          onPressed: _busy ? null : _rollover,
          child: Text('Copy from ${period.previous().label()}'),
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
    final money = ref.watch(moneyProvider);
    final household = ref.watch(householdProvider).valueOrNull;
    final uid = ref.watch(currentUidProvider);

    final controller = view.budget.controllerId == uid
        ? 'You control this'
        : '${household?.displayNameOf(view.budget.controllerId) ?? 'Partner'} '
            'controls this';

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
                    'of ${money.format(view.planned)}',
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
                label: '${view.categories.length} '
                    '${view.categories.length == 1 ? 'category' : 'categories'}',
              ),
              if (view.pendingCount > 0)
                Tag(
                  label: '${view.pendingCount} awaiting confirmation',
                  icon: Icons.schedule,
                  color: colors.warning,
                  filled: true,
                ),
              if (view.isOverAllocated)
                Tag(
                  label: 'Allocated over plan',
                  icon: Icons.warning_amber_rounded,
                  color: colors.negative,
                  filled: true,
                ),
              if (!view.isOverAllocated && view.unallocated > 0)
                Tag(label: '${money.compact(view.unallocated)} unallocated'),
            ],
          ),
        ],
      ),
    );
  }
}
