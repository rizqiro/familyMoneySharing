import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/i18n/app_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/period_switcher.dart';
import '../../core/widgets/soft_card.dart';
import '../../models/expense.dart';
import '../../state/providers.dart';
import 'expense_editor.dart';
import 'expense_tile.dart';

/// Every expense in the household for the selected month - both members, one
/// list. This is the "all spending is visible to each other" surface.
class LedgerPage extends ConsumerStatefulWidget {
  const LedgerPage({super.key});

  @override
  ConsumerState<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends ConsumerState<LedgerPage> {
  /// null = everyone.
  String? _filterUid;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final household = ref.watch(householdProvider).valueOrNull;
    final summary = ref.watch(summaryProvider);
    final t = ref.watch(textProvider);
    final locale = ref.watch(dateLocaleProvider);
    final money = ref.watch(moneyProvider);
    final uid = ref.watch(currentUidProvider);

    if (household == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final expenses = _filterUid == null
        ? summary.expenses
        : summary.expenses.where((e) => e.spentBy == _filterUid).toList();

    // Everyone sees every entry, but only the controller of a budget may
    // correct what was filed against it. A Set is used rather than a list
    // because this is looked up once per row and Set membership is constant
    // time.
    final editableBudgetIds =
        summary.spendable.map((b) => b.budget.id).toSet();
    // Spending and income are totalled apart. Netting them would produce a
    // single figure that is neither "what we spent" nor "what came in", and
    // answers no question anybody has.
    final savingIds = ref
        .watch(summaryProvider)
        .savings
        .map((v) => v.budget.id)
        .toSet();
    bool isIncome(Expense e) =>
        e.kindIn(saving: savingIds.contains(e.budgetId)) == EntryKind.income;

    final total = expenses
        .where((e) => !isIncome(e))
        .fold(0.0, (sum, e) => sum + e.amount);
    final incomeTotal = expenses
        .where(isIncome)
        .fold(0.0, (sum, e) => sum + e.amount);
    final grouped = _groupByDay(expenses);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('ledger.title')),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: Insets.page),
            child: Center(child: PeriodSwitcher()),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (household.isPaired)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.page,
                  0,
                  Insets.page,
                  Insets.md,
                ),
                child: Row(
                  children: [
                    _FilterChip(
                      label: t('ledger.everyone'),
                      selected: _filterUid == null,
                      onTap: () => setState(() => _filterUid = null),
                    ),
                    const SizedBox(width: Insets.sm),
                    for (final id in household.memberIds)
                      Padding(
                        padding: const EdgeInsets.only(right: Insets.sm),
                        child: _FilterChip(
                          label: id == uid
                              ? t('common.you')
                              : household.displayNameOf(id).split(' ').first,
                          selected: _filterUid == id,
                          onTap: () => setState(() => _filterUid = id),
                        ),
                      ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.page),
              child: Row(
                children: [
                  Text(
                    t.plural(expenses.length, 'ledger.entries_one',
                        'ledger.entries_many',),
                    style: text.bodySmall?.copyWith(color: colors.inkMuted),
                  ),
                  const Spacer(),
                  if (incomeTotal > 0) ...[
                    Text(
                      '+ ${money.format(incomeTotal)}',
                      style: text.bodyMedium?.copyWith(
                        color: colors.positive,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                  ],
                  Text(
                    money.format(total),
                    style: text.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.md),

            Expanded(
              child: expenses.isEmpty
                  ? EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: t('ledger.empty'),
                      message: t('ledger.empty_blurb'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        Insets.page,
                        0,
                        Insets.page,
                        120,
                      ),
                      itemCount: grouped.length,
                      itemBuilder: (context, index) {
                        final day = grouped[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: Insets.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: Insets.sm,
                                  left: Insets.xs,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      _dayLabel(day.$1, t, locale),
                                      style: text.labelSmall?.copyWith(
                                        color: colors.inkMuted,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      money.format(
                                        day.$2
                                            .where((e) => !isIncome(e))
                                            .fold(
                                          0.0,
                                          (sum, e) => sum + e.amount,
                                        ),
                                      ),
                                      style: text.labelSmall?.copyWith(
                                        color: colors.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SoftCard(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  children: [
                                    for (var i = 0; i < day.$2.length; i++) ...[
                                      if (i > 0)
                                        Divider(
                                          height: 1,
                                          indent: 64,
                                          color: colors.hairline,
                                        ),
                                      ExpenseTile(
                                        expense: day.$2[i],
                                        showDate: false,
                                        onTap: editableBudgetIds
                                                .contains(day.$2[i].budgetId)
                                            ? () => showExpenseEditor(
                                                  context,
                                                  existing: day.$2[i],
                                                )
                                            : null,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// "TODAY", "YESTERDAY", or the date - in the chosen language.
  ///
  /// `t` and `locale` are passed in because this is `static`: it belongs to the
  /// class rather than to an instance, so it cannot reach `ref` itself.
  static String _dayLabel(DateTime day, AppText t, String locale) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return t('ledger.today');
    if (diff == 1) return t('ledger.yesterday');
    return DateFormat.MMMEd(locale).format(day).toUpperCase();
  }

  static List<(DateTime, List<Expense>)> _groupByDay(List<Expense> expenses) {
    final buckets = <DateTime, List<Expense>>{};
    for (final e in expenses) {
      final day = DateTime(e.spentAt.year, e.spentAt.month, e.spentAt.day);
      buckets.putIfAbsent(day, () => []).add(e);
    }
    final days = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final day in days) (day, buckets[day]!)];
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.ink : colors.surfaceSunken,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? colors.onAccent : colors.inkSecondary,
              ),
        ),
      ),
    );
  }
}
