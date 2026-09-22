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

/// One budget: its categories, its spending, and who may change what.
///
/// The whole screen is gated on `isController`. The controller gets the edit
/// menu, the add-category button, and tappable rows. Everyone else gets the
/// same figures, read-only - they can see exactly where the money went, they
/// just cannot spend it or re-carve it.
class BudgetDetailPage extends ConsumerWidget {
  const BudgetDetailPage({super.key, required this.budgetId});

  final String budgetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
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
        body: EmptyState(
          icon: Icons.search_off,
          title: t('detail.not_found'),
          message: t('detail.not_found_blurb'),
        ),
      );
    }

    final isController = view.budget.controllerId == uid;
    final controllerName = isController
        ? t('common.you')
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
                PopupMenuItem(
                  value: 'edit',
                  child: Text(t('detail.edit_budget')),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    t('detail.delete_budget'),
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
              label: Text(t('common.add')),
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
                    view.budget.isSaving
                        ? t('detail.put_aside')
                        : t('detail.spent'),
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
                          label: view.budget.isSaving
                              ? t('detail.target')
                              : t('detail.planned'),
                          value: money.format(view.planned),
                        ),
                      ),
                      Expanded(
                        child: Stat(
                          label: view.isOver
                              ? t('detail.over_by')
                              : t('detail.left'),
                          value: money.format(view.remaining.abs()),
                          tone: view.isOver ? colors.negative : null,
                        ),
                      ),
                      Expanded(
                        child: Stat(
                          label: t('detail.unallocated'),
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
                        isController
                            ? t('detail.you_control_here')
                            : t('detail.controls_here',
                                {'name': controllerName},),
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
                      t('detail.over_allocated', {
                        'allocated': money.format(view.allocated),
                        'planned': money.format(view.planned),
                      }),
                ),
              ),

            SectionHeader(
              title: t('detail.categories'),
              action: isController ? t('common.add') : null,
              onAction: () => showCategoryEditor(context, budget: view.budget),
            ),

            if (view.categories.isEmpty)
              EmptyState(
                icon: Icons.category_outlined,
                compact: true,
                title: t('detail.no_categories'),
                message: isController
                    ? t('detail.no_categories_yours')
                    : t('detail.no_categories_theirs',
                        {'name': controllerName},),
                actionLabel:
                    isController ? t('detail.add_category') : null,
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
                        t('detail.uncategorised'),
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
            SectionHeader(
              title: t('detail.activity', {'count': '${expenses.length}'}),
            ),
            if (expenses.isEmpty)
              EmptyState(
                icon: Icons.receipt_long_outlined,
                compact: true,
                title: t('detail.nothing_spent'),
                message: isController
                    ? t('detail.nothing_spent_yours')
                    : t('detail.nothing_spent_theirs',
                        {'name': controllerName},),
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
                        // Only the controller may correct an entry filed
                        // against their budget, so for anyone else the row is
                        // read-only rather than a tap that would be refused.
                        onTap: isController
                            ? () => showExpenseEditor(
                                  context,
                                  existing: expenses[i],
                                )
                            : null,
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
    final t = ref.read(textProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('detail.delete_title', {'name': view.budget.name})),
        content: Text(t('detail.delete_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.negative,
            ),
            child: Text(t('common.delete')),
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
    final t = ref.read(textProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          t('detail.remove_category_title', {'name': view.category.name}),
        ),
        content: Text(
          view.spent > 0
              ? t('detail.remove_category_spent')
              : t('detail.remove_category_empty'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.negative,
            ),
            child: Text(t('common.remove')),
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
    required this.onDelete,
  });

  final CategoryView view;

  /// True only for the budget's controller. Everyone else gets a read-only
  /// card: they can see the allocation and what is left, but there is nothing
  /// here for them to act on, because they cannot spend from this budget.
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
    final money = ref.watch(moneyProvider);
    final category = view.category;

    // A record pattern: three values pulled out of one switch. Keeps the
    // colour, icon and wording for a status decided in a single place.
    final (statusColor, statusIcon, statusKey) = switch (category.status) {
      AllocationStatus.pending =>
        (colors.warning, Icons.schedule, 'status.pending'),
      AllocationStatus.approved =>
        (colors.positive, Icons.check_circle, 'status.approved'),
      AllocationStatus.rejected =>
        (colors.negative, Icons.cancel_outlined, 'status.rejected'),
    };

    return SoftCard(
      onTap: canEdit ? onEdit : null,
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
                      t('dashboard.spent_of', {
                        'spent': money.format(view.spent),
                        'planned': money.format(view.allocated),
                      }),
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
              label: t(statusKey),
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
