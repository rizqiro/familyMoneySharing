import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/meter.dart';
import '../../core/widgets/soft_card.dart';
import '../../models/spend_category.dart';
import '../../state/period_summary.dart';
import '../../state/providers.dart';
import '../expenses/expense_editor.dart';
import '../expenses/expense_tile.dart';
import 'budget_editor.dart';
import 'category_editor.dart';

class BudgetDetailPage extends ConsumerWidget {
  const BudgetDetailPage({super.key, required this.budgetId});

  final String budgetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final summary = ref.watch(summaryProvider);
    final money = ref.watch(moneyProvider);
    final household = ref.watch(householdProvider).valueOrNull;
    final uid = ref.watch(currentUidProvider);

    final matches = [...summary.monthly, ...summary.savings]
        .where((v) => v.budget.id == budgetId)
        .toList();
    final view = matches.isEmpty ? null : matches.first;

    if (view == null || household == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.search_off,
          title: 'Budget not found',
          message: 'It may have been deleted, or it belongs to another month.',
        ),
      );
    }

    final isController = view.budget.controllerId == uid;
    final controllerName = isController
        ? 'You'
        : household.displayNameOf(view.budget.controllerId);

    final expenses = summary.expenses
        .where((e) => e.budgetId == budgetId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(view.budget.name),
        actions: [
          if (isController)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz),
              onSelected: (value) async {
                if (value == 'edit') {
                  await showBudgetEditor(context, existing: view.budget);
                } else if (value == 'delete') {
                  await _confirmDelete(context, ref, view);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit budget')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete budget',
                    style: TextStyle(color: colors.negative),
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: isController
          ? FloatingActionButton.extended(
              onPressed: () =>
                  showCategoryEditor(context, budget: view.budget),
              backgroundColor: colors.accent,
              foregroundColor: colors.onAccent,
              elevation: 0,
              highlightElevation: 0,
              icon: const Icon(Icons.add),
              label: const Text('Category'),
            )
          : null,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Insets.page,
            Insets.md,
            Insets.page,
            120,
          ),
          children: [
            SoftCard(
              padding: const EdgeInsets.all(Insets.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    view.budget.isSaving ? 'PUT ASIDE' : 'SPENT',
                    style: text.labelSmall?.copyWith(color: colors.inkMuted),
                  ),
                  const SizedBox(height: Insets.sm),
                  Text(
                    money.format(view.spent),
                    style: text.displayMedium?.copyWith(
                      color: view.isOver ? colors.negative : colors.ink,
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  Meter(
                    progress: view.progress,
                    isOver: view.isOver,
                    height: 10,
                    color: view.budget.isSaving ? colors.positive : null,
                  ),
                  const SizedBox(height: Insets.lg),
                  Row(
                    children: [
                      Expanded(
                        child: Stat(
                          label: view.budget.isSaving ? 'Target' : 'Planned',
                          value: money.format(view.planned),
                        ),
                      ),
                      Expanded(
                        child: Stat(
                          label: view.isOver ? 'Over by' : 'Left',
                          value: money.format(view.remaining.abs()),
                          tone: view.isOver ? colors.negative : null,
                        ),
                      ),
                      Expanded(
                        child: Stat(
                          label: 'Unallocated',
                          value: money.format(view.unallocated),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.lg),
                  Row(
                    children: [
                      MemberAvatar(
                        initial: household
                                .member(view.budget.controllerId)
                                ?.initial ??
                            '?',
                        size: 24,
                      ),
                      const SizedBox(width: Insets.sm),
                      Text(
                        '$controllerName ${isController ? 'control' : 'controls'} '
                        'the categories here',
                        style: text.bodySmall
                            ?.copyWith(color: colors.inkSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.xl),

            if (view.isOverAllocated)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.lg),
                child: ErrorNote(
                  message:
                      'Categories add up to ${money.format(view.allocated)}, '
                      'which is more than the '
                      '${money.format(view.planned)} plan.',
                ),
              ),

            SectionHeader(
              title: 'Categories',
              action: isController ? 'Add' : null,
              onAction: () => showCategoryEditor(context, budget: view.budget),
            ),

            if (view.categories.isEmpty)
              EmptyState(
                icon: Icons.category_outlined,
                compact: true,
                title: 'No categories yet',
                message: isController
                    ? 'Split this budget so you both know what the money is '
                        'meant for.'
                    : '$controllerName has not split this budget yet.',
                actionLabel: isController ? 'Add a category' : null,
                onAction: isController
                    ? () => showCategoryEditor(context, budget: view.budget)
                    : null,
              )
            else
              for (final category in view.categories)
                Padding(
                  padding: const EdgeInsets.only(bottom: Insets.sm),
                  child: _CategoryCard(
                    view: category,
                    canEdit: isController,
                    onEdit: () => showCategoryEditor(
                      context,
                      budget: view.budget,
                      existing: category.category,
                    ),
                    onAddExpense: () => showExpenseEditor(
                      context,
                      budgetId: view.budget.id,
                      categoryId: category.category.id,
                    ),
                    onDelete: () =>
                        _confirmDeleteCategory(context, ref, category),
                  ),
                ),

            if (view.uncategorisedSpend > 0) ...[
              const SizedBox(height: Insets.sm),
              SoftCard(
                color: colors.surfaceSunken,
                child: Row(
                  children: [
                    Icon(Icons.help_outline, size: 18, color: colors.inkMuted),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Text(
                        'Uncategorised spending',
                        style: text.bodyMedium,
                      ),
                    ),
                    Text(
                      money.format(view.uncategorisedSpend),
                      style: text.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: Insets.xl),
            SectionHeader(title: 'Activity (${expenses.length})'),
            if (expenses.isEmpty)
              EmptyState(
                icon: Icons.receipt_long_outlined,
                compact: true,
                title: 'Nothing spent from this budget yet',
                message: 'Entries you both add show up here.',
              )
            else
              SoftCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < expenses.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 64,
                          color: colors.hairline,
                        ),
                      ExpenseTile(
                        expense: expenses[i],
                        onTap: () => showExpenseEditor(
                          context,
                          existing: expenses[i],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    BudgetView view,
  ) async {
    final householdId = ref.read(householdIdProvider);
    if (householdId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${view.budget.name}?'),
        content: const Text(
          'Its categories and every expense filed under it are deleted too, '
          'for both of you. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.negative,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref
        .read(budgetRepositoryProvider)
        .delete(householdId, view.budget.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDeleteCategory(
    BuildContext context,
    WidgetRef ref,
    CategoryView view,
  ) async {
    final householdId = ref.read(householdIdProvider);
    if (householdId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${view.category.name}?'),
        content: Text(
          view.spent > 0
              ? 'The expenses stay in the ledger but stop being categorised.'
              : 'Nothing has been spent from it yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.negative,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(categoryRepositoryProvider).delete(
          householdId: householdId,
          categoryId: view.category.id,
        );
  }
}

class _CategoryCard extends ConsumerWidget {
  const _CategoryCard({
    required this.view,
    required this.canEdit,
    required this.onEdit,
    required this.onAddExpense,
    required this.onDelete,
  });

  final CategoryView view;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onAddExpense;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final money = ref.watch(moneyProvider);
    final category = view.category;

    final (statusColor, statusIcon) = switch (category.status) {
      AllocationStatus.pending => (colors.warning, Icons.schedule),
      AllocationStatus.approved => (colors.positive, Icons.check_circle),
      AllocationStatus.rejected => (colors.negative, Icons.cancel_outlined),
    };

    return SoftCard(
      onTap: canEdit ? onEdit : onAddExpense,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  category.emoji,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${money.format(view.spent)} of '
                      '${money.format(view.allocated)}',
                      style:
                          text.bodySmall?.copyWith(color: colors.inkSecondary),
                    ),
                  ],
                ),
              ),
              if (canEdit)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 19,
                    color: colors.inkMuted,
                  ),
                  onPressed: onDelete,
                )
              else
                Text(
                  money.format(view.remaining.abs()),
                  style: text.bodyMedium?.copyWith(
                    color: view.isOver ? colors.negative : colors.inkSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Meter(
            progress: view.progress,
            isOver: view.isOver,
            color: category.isRejected ? colors.inkMuted : null,
          ),
          if (!category.isApproved) ...[
            const SizedBox(height: Insets.md),
            Tag(
              label: category.status.label,
              icon: statusIcon,
              color: statusColor,
              filled: true,
            ),
          ],
        ],
      ),
    );
  }
}
