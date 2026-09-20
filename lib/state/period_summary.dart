import '../core/format/period.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../models/household.dart';
import '../models/spend_category.dart';

/// One category with its spending resolved.
class CategoryView {
  const CategoryView({
    required this.category,
    required this.spent,
  });

  final SpendCategory category;
  final double spent;

  double get allocated => category.countableAmount;
  double get remaining => allocated - spent;
  bool get isOver => allocated > 0 && spent > allocated;

  /// 0..1 for the meter; overspend is reported by [isOver], not by a bar that
  /// runs past its track.
  double get progress {
    if (allocated <= 0) return spent > 0 ? 1 : 0;
    return (spent / allocated).clamp(0.0, 1.0);
  }
}

/// A budget with its categories and spending resolved.
class BudgetView {
  const BudgetView({
    required this.budget,
    required this.categories,
    required this.spent,
    required this.uncategorisedSpend,
  });

  final Budget budget;
  final List<CategoryView> categories;
  final double spent;

  /// Spending filed against this budget but no longer under any category -
  /// left after a category is deleted.
  final double uncategorisedSpend;

  double get planned => budget.amount;
  double get allocated =>
      categories.fold(0.0, (sum, c) => sum + c.allocated);

  /// Budget money not yet carved into categories.
  double get unallocated => (planned - allocated).clamp(0.0, double.infinity);
  double get remaining => planned - spent;
  bool get isOver => planned > 0 && spent > planned;
  bool get isOverAllocated => planned > 0 && allocated > planned;

  int get pendingCount =>
      categories.where((c) => c.category.isPending).length;

  double get progress {
    if (planned <= 0) return spent > 0 ? 1 : 0;
    return (spent / planned).clamp(0.0, 1.0);
  }
}

/// Everything the dashboard needs for one period, computed in one place so the
/// hero figure, the meters and the charts can never disagree.
class PeriodSummary {
  const PeriodSummary({
    required this.period,
    required this.monthStartDay,
    required this.monthly,
    required this.savings,
    required this.expenses,
    required this.spendByMember,
  });

  final Period period;
  final int monthStartDay;
  final List<BudgetView> monthly;
  final List<BudgetView> savings;

  /// The period's ledger, newest first.
  final List<Expense> expenses;
  final Map<String, double> spendByMember;

  static const empty = PeriodSummary(
    period: Period(2000, 1),
    monthStartDay: 1,
    monthly: [],
    savings: [],
    expenses: [],
    spendByMember: {},
  );

  bool get isEmpty => monthly.isEmpty && savings.isEmpty;

  double get planned => monthly.fold(0.0, (sum, b) => sum + b.planned);
  double get spent => monthly.fold(0.0, (sum, b) => sum + b.spent);
  double get remaining => planned - spent;
  bool get isOver => planned > 0 && spent > planned;

  double get savedThisPeriod => savings.fold(0.0, (sum, b) => sum + b.spent);

  double get progress {
    if (planned <= 0) return spent > 0 ? 1 : 0;
    return (spent / planned).clamp(0.0, 1.0);
  }

  int get pendingCount =>
      [...monthly, ...savings].fold(0, (sum, b) => sum + b.pendingCount);

  /// How far through the month we are, 0..1 - the reference line the spend bar
  /// is read against.
  double get periodProgress {
    final total = period.lengthInDays(monthStartDay: monthStartDay);
    if (total <= 0) return 0;
    return (period.elapsedDays(monthStartDay: monthStartDay) / total)
        .clamp(0.0, 1.0);
  }

  /// Spending is ahead of the calendar by more than a tenth of the budget.
  bool get isAheadOfPace =>
      planned > 0 && period.isCurrent && progress - periodProgress > 0.1;

  double get dailyAllowance {
    final total = period.lengthInDays(monthStartDay: monthStartDay);
    final left = (total - period.elapsedDays(monthStartDay: monthStartDay))
        .clamp(1, total);
    if (remaining <= 0) return 0;
    return remaining / left;
  }

  /// Every category across every budget, biggest spend first - the source for
  /// the dashboard's ranked bars.
  List<CategoryView> get categoriesBySpend {
    final all = [
      for (final b in [...monthly, ...savings]) ...b.categories,
    ]..sort((a, b) => b.spent.compareTo(a.spent));
    return all;
  }

  /// Builds the whole view from raw collections.
  static PeriodSummary build({
    required Period period,
    required Household household,
    required List<Budget> budgets,
    required List<SpendCategory> categories,
    required List<Expense> periodExpenses,
    required List<Expense> savingExpenses,
  }) {
    final spendByCategory = <String, double>{};
    final spendByBudget = <String, double>{};
    final spendByMember = <String, double>{};

    void tally(Expense e, {required bool countTowardMembers}) {
      spendByBudget.update(
        e.budgetId,
        (v) => v + e.amount,
        ifAbsent: () => e.amount,
      );
      if (e.categoryId.isNotEmpty) {
        spendByCategory.update(
          e.categoryId,
          (v) => v + e.amount,
          ifAbsent: () => e.amount,
        );
      }
      if (countTowardMembers) {
        spendByMember.update(
          e.spentBy,
          (v) => v + e.amount,
          ifAbsent: () => e.amount,
        );
      }
    }

    final savingIds = budgets.where((b) => b.isSaving).map((b) => b.id).toSet();

    for (final e in periodExpenses) {
      tally(e, countTowardMembers: !savingIds.contains(e.budgetId));
    }
    // Saving pots accumulate across periods, so their totals come from a
    // separate all-time read and must not be double-counted here.
    for (final e in savingExpenses) {
      if (periodExpenses.any((p) => p.id == e.id)) continue;
      tally(e, countTowardMembers: false);
    }

    BudgetView viewFor(Budget budget) {
      final children = categories
          .where((c) => c.budgetId == budget.id)
          .map(
            (c) => CategoryView(
              category: c,
              spent: spendByCategory[c.id] ?? 0,
            ),
          )
          .toList()
        ..sort((a, b) => b.allocated.compareTo(a.allocated));

      final total = spendByBudget[budget.id] ?? 0;
      final categorised = children.fold(0.0, (sum, c) => sum + c.spent);

      return BudgetView(
        budget: budget,
        categories: children,
        spent: total,
        uncategorisedSpend: (total - categorised).clamp(0.0, double.infinity),
      );
    }

    return PeriodSummary(
      period: period,
      monthStartDay: household.monthStartDay,
      monthly: budgets.where((b) => !b.isSaving).map(viewFor).toList(),
      savings: budgets.where((b) => b.isSaving).map(viewFor).toList(),
      expenses: periodExpenses,
      spendByMember: spendByMember,
    );
  }
}
