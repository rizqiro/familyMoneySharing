import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/period.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/meter.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/spend_chart.dart';
import '../../models/expense.dart';
import '../../models/household.dart';
import '../../models/spend_category.dart';
import '../../state/chart_series.dart';
import '../../state/period_summary.dart';
import '../../state/providers.dart';
import '../expenses/expense_editor.dart';
import '../expenses/expense_tile.dart';
import '../money/transfer_history.dart';
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
            _SpentSection(
              view: view,
              household: household,
              isController: isController,
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

            if (summary.transfersFor(budgetId).any((r) => !r.isPending)) ...[
              const SizedBox(height: Insets.xl),
              SectionHeader(title: t('history.on_this_budget')),
              TransferHistory(
                requests: summary.transfersFor(budgetId),
                budgetId: budgetId,
                limit: 5,
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

/// The top of a budget: what has been spent, drawn three ways.
///
/// =============================================================================
/// WHY A BURN-UP AND NOT A PIE
/// =============================================================================
/// A pie chart answers "what share of the budget is gone". You already know
/// that - the meter says it in one bar. What you actually want to know standing
/// in a shop on the 22nd is "am I going to make it", and that is a question
/// about RATE, which a pie cannot show at all.
///
/// So the chart is a burn-up with three lines:
///
///   * solid red    - what you have actually spent, day by day, adding up;
///   * dashed grey  - the pace that would land exactly on budget on the last
///                    day. Your line sitting above it means you are spending
///                    faster than the month is passing;
///   * dotted red   - where today's pace lands if nothing changes.
///
/// Where the dotted line crosses the budget, the overshoot is shaded, and the
/// warning underneath names the daily figure that would fix it. That last
/// sentence is the only thing on the screen anyone can act on.
class _SpentSection extends ConsumerWidget {
  const _SpentSection({
    required this.view,
    required this.household,
    required this.isController,
  });

  final BudgetView view;
  final Household household;
  final bool isController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
    final money = ref.watch(moneyProvider);
    final summary = ref.watch(summaryProvider);
    final series = ref.watch(budgetSeriesProvider(view.budget.id));
    final saving = view.budget.isSaving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          saving ? t('detail.put_aside') : t('detail.spent'),
          style: text.labelSmall?.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: Insets.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                money.format(view.spent),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.displayMedium?.copyWith(
                  color: view.isOver ? colors.accentDeep : colors.ink,
                ),
              ),
            ),
            const SizedBox(width: Insets.md),
            Text(
              t(saving ? 'detail.of_target' : 'detail.of_planned',
                  {'amount': money.format(view.planned)},),
              style: text.bodyMedium?.copyWith(color: colors.inkSecondary),
            ),
          ],
        ),
        const SizedBox(height: Insets.lg),

        // A saving pot is filling up, not draining, so the pace line and the
        // projection mean nothing there - it gets the plain meter instead.
        if (saving)
          Meter(
            progress: view.progress,
            height: 10,
            color: colors.positive,
          )
        else ...[
          FullBleed(
            height: 200,
            child: SpendChart(
              series: series,
              money: money,
              height: 200,
              showPaceLine: true,
              semanticLabel: t('chart.a11y', {
                'range': t(ChartRange.month.labelKey),
                'spent': money.format(series.spent),
                'budget': money.format(series.reference),
              }),
              referenceLabel: t('chart.budget_of',
                  {'amount': money.compact(series.reference)},),
              calloutLabel:
                  series.spent > 0 ? money.format(series.spent) : null,
            ),
          ),
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: Insets.lg,
            runSpacing: Insets.sm,
            children: [
              ChartLegendKey(
                label: t('chart.legend_spent'),
                color: colors.series1,
              ),
              ChartLegendKey(
                label: t('chart.legend_pace'),
                color: colors.inkMuted,
                dashed: true,
              ),
              ChartLegendKey(
                label: t('chart.legend_projection'),
                color: colors.series1,
                dashed: true,
                opacity: 0.6,
              ),
            ],
          ),
          if (series.projectedOverspend > 0) ...[
            const SizedBox(height: Insets.lg),
            _PaceWarning(
              series: series,
              period: summary.period,
              monthStartDay: summary.monthStartDay,
            ),
          ],
        ],

        const SizedBox(height: Insets.xl),
        Row(
          children: [
            Expanded(
              child: Stat(
                label: saving ? t('detail.target') : t('detail.planned'),
                value: money.format(view.planned),
              ),
            ),
            Expanded(
              child: Stat(
                label: view.isOver ? t('detail.over_by') : t('detail.left'),
                value: money.format(view.remaining.abs()),
                tone: view.isOver ? colors.accentDeep : null,
              ),
            ),
            Expanded(
              child: Stat(
                // On a saving pot the third figure is what has been taken back
                // out, which is the one number the meter cannot show: a pot at
                // 2 jt looks the same whether nothing was withdrawn or a lot
                // was paid in and half taken back.
                label: saving ? t('detail.taken_out') : t('detail.unallocated'),
                value: money.format(
                  saving ? view.spending : view.unallocated,
                ),
              ),
            ),
          ],
        ),

        if (!saving && view.income > 0) ...[
          const SizedBox(height: Insets.lg),
          Row(
            children: [
              Icon(Icons.arrow_downward, size: 15, color: colors.positive),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  t('detail.income_added', {
                    'amount': money.format(view.income),
                  }),
                  style: text.bodySmall?.copyWith(color: colors.inkSecondary),
                ),
              ),
            ],
          ),
        ],

        if (isController) ...[
          const SizedBox(height: Insets.lg),
          // Recording money straight from the budget it belongs to, rather
          // than from the global add button and then picking the budget again.
          // For a saving pot this is the whole point: paying in is income, and
          // it used to be reachable only by filing a fake expense.
          Row(
            children: [
              Expanded(
                child: _RecordButton(
                  label: t(saving
                      ? 'detail.record_deposit'
                      : 'detail.record_income',),
                  icon: Icons.arrow_downward,
                  tone: colors.positive,
                  onTap: () => showExpenseEditor(
                    context,
                    budgetId: view.budget.id,
                    kind: EntryKind.income,
                  ),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: _RecordButton(
                  label: t(saving
                      ? 'detail.record_withdrawal'
                      : 'detail.record_spending',),
                  icon: Icons.arrow_outward,
                  tone: colors.accent,
                  onTap: () => showExpenseEditor(
                    context,
                    budgetId: view.budget.id,
                    kind: EntryKind.spending,
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: Insets.lg),
        Row(
          children: [
            MemberAvatar(
              initial:
                  household.member(view.budget.controllerId)?.initial ?? '?',
              size: 24,
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                isController
                    ? t('detail.you_control_here')
                    : t('detail.controls_here', {
                        'name':
                            household.displayNameOf(view.budget.controllerId),
                      }),
                style: text.bodySmall?.copyWith(color: colors.inkSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.xl),
        _WhereItStands(view: view),
      ],
    );
  }
}

/// "Keep going at this rate and you land Rp 382.000 over. Drop to Rp 65.000 a
/// day and you land on it."
///
/// Two numbers: the damage, and the fix. A warning with only the first is just
/// bad news.
class _PaceWarning extends ConsumerWidget {
  const _PaceWarning({
    required this.series,
    required this.period,
    required this.monthStartDay,
  });

  final SpendSeries series;
  final Period period;
  final int monthStartDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final t = ref.watch(textProvider);
    final money = ref.watch(moneyProvider);
    final fix = series.dailyAllowanceLeft(period, monthStartDay);

    return Container(
      padding: const EdgeInsets.all(Insets.md + 2),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(Radii.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 17,
            color: colors.onAccentSoft,
          ),
          const SizedBox(width: Insets.sm + 1),
          Expanded(
            child: Text(
              '${t('chart.projection_over', {
                    'amount': money.format(series.projected),
                    'over': money.format(series.projectedOverspend),
                  })} ${fix > 0 ? t('chart.fix_daily', {'amount': money.format(fix)}) : t('chart.fix_stop')}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.onAccentSoft),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the budget's money physically is right now.
///
/// One bar in three parts, because "Rp 520.000 left" hides a real difference:
/// money already spent is gone, money sitting in a category is spoken for, and
/// money not yet carved up is the only part you can freely move.
class _WhereItStands extends ConsumerWidget {
  const _WhereItStands({required this.view});

  final BudgetView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
    final money = ref.watch(moneyProvider);

    final spent = view.spent;
    final categorised = view.categories.fold(0.0, (sum, c) => sum + c.spent);
    // What the categories still hold: allocated to them, not yet spent from
    // them. Clamped because a category can be overspent, which would otherwise
    // make this negative and the bar draw backwards.
    final reserved =
        (view.allocated - categorised).clamp(0.0, double.infinity);
    final free = view.unallocated;
    final total = spent + reserved + free;
    if (total <= 0) return const SizedBox.shrink();

    return SoftCard(
      padding: const EdgeInsets.all(Insets.lg + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('detail.where_it_stands'),
            style: text.labelSmall?.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: Insets.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 26,
              // `Flex` weights, not pixels: each part takes a share of the row
              // proportional to its amount, so the bar always fills the width
              // whatever the figures are. The `.round()` is because flex
              // factors have to be whole numbers; 1000 keeps enough precision
              // that a 0.1% slice is still a pixel.
              child: Row(
                children: [
                  for (final part in [
                    (spent, colors.series1),
                    (reserved, colors.tintFor(view.budget.id).badge),
                    (free, colors.track),
                  ])
                    if (part.$1 > 0)
                      Expanded(
                        flex: (part.$1 / total * 1000).round().clamp(1, 1000),
                        child: Container(
                          margin: const EdgeInsets.only(right: 2),
                          color: part.$2,
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.md),
          _StandRow(
            color: colors.series1,
            label: t('detail.already_spent'),
            value: money.format(spent),
          ),
          _StandRow(
            color: colors.tintFor(view.budget.id).badge,
            label: t('detail.in_categories'),
            value: money.format(reserved),
          ),
          _StandRow(
            color: colors.track,
            label: t('detail.not_carved_up'),
            value: money.format(free),
          ),
        ],
      ),
    );
  }
}

class _StandRow extends StatelessWidget {
  const _StandRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: Insets.sm),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: context.colors.hairline),
            ),
          ),
          const SizedBox(width: Insets.sm),
          Expanded(child: Text(label, style: text.bodyMedium)),
          Text(
            value,
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
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

/// One of the two "record something" buttons on a budget.
///
/// An outlined button with the tone carried by the icon and the border rather
/// than a fill: two filled buttons side by side would both shout, and neither
/// of these is the primary action on the screen.
class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.label,
    required this.icon,
    required this.tone,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17, color: tone),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        // The theme's default is a full-width 54px button; these two share a
        // row, so they shrink to their labels.
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: Insets.md),
        side: BorderSide(color: tone.withValues(alpha: 0.4)),
        textStyle: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}
