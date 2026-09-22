
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';


import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/expense.dart';
import '../../state/providers.dart';

/// One ledger row: what it was, who paid, how much.
class ExpenseTile extends ConsumerWidget {
  const ExpenseTile({
    super.key,
    required this.expense,
    this.onTap,
    this.showDate = true,
  });

  final Expense expense;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
    final locale = ref.watch(dateLocaleProvider);
    final money = ref.watch(moneyProvider);
    final household = ref.watch(householdProvider).valueOrNull;
    final uid = ref.watch(currentUidProvider);

    final category = ref.watch(categoryLookupProvider)[expense.categoryId];
    final budget = ref.watch(budgetLookupProvider)[expense.budgetId];

    final title = expense.note.trim().isNotEmpty
        ? expense.note.trim()
        : (category?.name ?? budget?.name ?? t('expense.new'));

    final spender = expense.spentBy == uid
        ? t('common.you')
        : (household?.displayNameOf(expense.spentBy) ??
            t('common.partner'));

    final subtitle = [
      spender,
      if (category != null) category.name,
      if (showDate) DateFormat.MMMd(locale).format(expense.spentAt),
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                shape: BoxShape.circle,
              ),
              child: Text(
                category?.emoji ?? '\u{1F4B3}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: colors.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            Text(
              money.format(expense.amount),
              style: text.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
