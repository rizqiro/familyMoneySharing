import '../core/format/period.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../models/household.dart';
import '../models/money_request.dart';
import '../models/spend_category.dart';

/// Everything the app shows about one month, worked out in one place.
///
/// ---------------------------------------------------------------------------
/// WHY A SEPARATE FILE JUST FOR ARITHMETIC
/// ---------------------------------------------------------------------------
/// Firestore gives us four flat lists: budgets, categories, expenses, money
/// requests. No screen wants that. The dashboard wants "how much is left in the
/// budget I control"; a budget card wants "how much of this category is spent".
///
/// If each screen did its own adding up, two screens would eventually disagree
/// - one would forget to subtract transfers, or count saving pots twice - and
/// you would have a bug that only shows on one tab. So the raw lists are turned
/// into this object once, and every screen reads from it.
///
/// Nothing here touches Firestore or Flutter. That means you can reason about
/// it - and test it - without a database or a screen.

/// One category with its spending resolved.
class CategoryView {
  const CategoryView({required this.category, required this.spent});

  final SpendCategory category;
  final double spent;

  double get allocated => category.countableAmount;
  double get remaining => allocated - spent;
  bool get isOver => allocated > 0 && spent > allocated;

  /// 0..1, for the progress bar.
  ///
  /// `.clamp` keeps it inside the range so a bar can never draw past its track.
  /// Going over budget is reported by [isOver] instead - a bar that overflows
  /// its container just looks like a rendering bug.
  double get progress {
    if (allocated <= 0) return spent > 0 ? 1 : 0;
    return (spent / allocated).clamp(0.0, 1.0);
  }
}

/// One budget with its categories, spending and transfers resolved.
class BudgetView {
  const BudgetView({
    required this.budget,
    required this.categories,
    required this.spent,
    required this.uncategorisedSpend,
    required this.transferredIn,
    required this.transferredOut,
  });

  final Budget budget;
  final List<CategoryView> categories;
  final double spent;

  /// Spending filed against this budget but under no category - what is left
  /// behind when a category is deleted. The expenses survive; their label does
  /// not.
  final double uncategorisedSpend;

  /// Money granted to this budget by an approved request.
  final double transferredIn;

  /// Money granted away from this budget to the other member.
  final double transferredOut;

  /// What may actually be spent this month.
  ///
  /// THIS is where an approved money request takes effect. Neither budget
  /// document was edited when the request was approved - the adjustment happens
  /// here, every time the month is recalculated. See [MoneyRequest] for why.
  ///
  /// Clamped at zero so a budget that granted away more than it held cannot go
  /// negative and break every percentage below.
  double get planned =>
      (budget.amount + transferredIn - transferredOut).clamp(0.0, double.infinity);

  /// The budget as its controller set it, before transfers. Shown alongside
  /// [planned] when they differ, so a changed figure is explainable.
  double get baseAmount => budget.amount;

  bool get hasTransfers => transferredIn > 0 || transferredOut > 0;

  /// The total carved into categories.
  ///
  /// `fold` walks the list carrying a running value: start at 0.0, and for each
  /// category add its allocation. It is Dart's version of "sum these up".
  double get allocated => categories.fold(0.0, (sum, c) => sum + c.allocated);

  /// Budget money not yet assigned to any category.
  double get unallocated => (planned - allocated).clamp(0.0, double.infinity);

  double get remaining => planned - spent;
  bool get isOver => planned > 0 && spent > planned;

  /// The categories add up to more than the budget holds - a planning mistake
  /// worth surfacing before it becomes an overspend.
  bool get isOverAllocated => planned > 0 && allocated > planned;

  /// How many allocations are still waiting on the other member.
  int get pendingCount => categories.where((c) => c.category.isPending).length;

  double get progress {
    if (planned <= 0) return spent > 0 ? 1 : 0;
    return (spent / planned).clamp(0.0, 1.0);
  }

  bool isControlledBy(String? uid) => uid != null && budget.controllerId == uid;
}

/// The whole month: both members' budgets, the shared ledger, the totals.
class PeriodSummary {
  const PeriodSummary({
    required this.period,
    required this.monthStartDay,
    required this.viewerUid,
    required this.monthly,
    required this.savings,
    required this.expenses,
    required this.spendByMember,
  });

  final Period period;
  final int monthStartDay;

  /// Who is looking. Lets this object answer "mine" versus "theirs" without
  /// every screen having to pass the uid around again.
  final String? viewerUid;

  final List<BudgetView> monthly;
  final List<BudgetView> savings;

  /// The month's ledger, newest first. Both members', always - shared visibility
  /// is the point of the app.
  final List<Expense> expenses;

  /// uid -> total spent this month.
  final Map<String, double> spendByMember;

  /// A blank summary, used while the household is still loading.
  ///
  /// `const` here means Dart builds this exactly once at compile time and hands
  /// out the same instance forever, rather than allocating a new one per build.
  static const empty = PeriodSummary(
    period: Period(2000, 1),
    monthStartDay: 1,
    viewerUid: null,
    monthly: [],
    savings: [],
    expenses: [],
    spendByMember: {},
  );

  bool get isEmpty => monthly.isEmpty && savings.isEmpty;

  // --------------------------------------------------------------- mine

  /// The monthly budgets the viewer controls - the top of the overview, and the
  /// only budgets they may spend from.
  List<BudgetView> get myMonthly =>
      monthly.where((b) => b.isControlledBy(viewerUid)).toList();

  List<BudgetView> get mySavings =>
      savings.where((b) => b.isControlledBy(viewerUid)).toList();

  /// Every budget the viewer may file an expense against.
  List<BudgetView> get spendable => [...myMonthly, ...mySavings];

  /// True when the viewer controls nothing, so there is nothing to spend from.
  /// Drives the empty state and disables the add button.
  bool get hasNothingToSpend => spendable.isEmpty;

  /// What the viewer has left across their own monthly budgets.
  double get myRemaining =>
      myMonthly.fold(0.0, (sum, b) => sum + b.remaining);

  // -------------------------------------------------------------- theirs

  List<BudgetView> get theirMonthly =>
      monthly.where((b) => !b.isControlledBy(viewerUid)).toList();

  List<BudgetView> get theirSavings =>
      savings.where((b) => !b.isControlledBy(viewerUid)).toList();

  List<BudgetView> get theirBudgets => [...theirMonthly, ...theirSavings];

  double get theirRemaining =>
      theirMonthly.fold(0.0, (sum, b) => sum + b.remaining);

  // ------------------------------------------------------- the household

  /// Planned across both members - the "accumulated budget".
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

  /// How far through the month we are, 0..1.
  ///
  /// Drawn as a tick on the spend bar. Without it "60% spent" means nothing -
  /// it is fine on day 25 and alarming on day 5. The tick is what turns a bar
  /// into a judgement.
  double get periodProgress {
    final total = period.lengthInDays(monthStartDay: monthStartDay);
    if (total <= 0) return 0;
    return (period.elapsedDays(monthStartDay: monthStartDay) / total)
        .clamp(0.0, 1.0);
  }

  /// Spending has run more than a tenth of the budget ahead of the calendar.
  bool get isAheadOfPace =>
      planned > 0 && period.isCurrent && progress - periodProgress > 0.1;

  /// What is left, spread evenly over the days remaining.
  double dailyAllowanceFor(double left) {
    final total = period.lengthInDays(monthStartDay: monthStartDay);
    final daysLeft =
        (total - period.elapsedDays(monthStartDay: monthStartDay)).clamp(1, total);
    if (left <= 0) return 0;
    return left / daysLeft;
  }

  /// Every category across every budget, biggest spend first. The source for
  /// the dashboard's ranked bars.
  List<CategoryView> get categoriesBySpend {
    final all = [
      for (final b in [...monthly, ...savings]) ...b.categories,
    ]..sort((a, b) => b.spent.compareTo(a.spent));
    return all;
  }

  // --------------------------------------------------------------- build

  /// Turns the raw Firestore lists into the object above.
  ///
  /// The shape of the work is: make three lookup maps in a single pass over the
  /// expenses, then build each budget's view by reading from those maps. That
  /// keeps it linear - one pass over the expenses, one over the budgets -
  /// rather than re-scanning every expense for every budget.
  static PeriodSummary build({
    required Period period,
    required Household household,
    required String? viewerUid,
    required List<Budget> budgets,
    required List<SpendCategory> categories,
    required List<Expense> periodExpenses,
    required List<Expense> savingExpenses,
    required List<MoneyRequest> approvedTransfers,
  }) {
    // categoryId -> total spent. Same idea for the other two.
    final spendByCategory = <String, double>{};
    final spendByBudget = <String, double>{};
    final spendByMember = <String, double>{};

    /// Adds one expense into the three maps.
    ///
    /// `update` takes the existing value and returns the new one; `ifAbsent`
    /// supplies the starting value the first time a key is seen. It saves
    /// writing "if the key is missing, put 0, then add".
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
      // Putting money into savings is not "spending", so it stays out of the
      // who-spent-what split. Otherwise a big transfer to savings would look
      // like one partner overspending wildly.
      tally(e, countTowardMembers: !savingIds.contains(e.budgetId));
    }

    // Saving pots show a running total across every month, so their entries
    // come from a second, unfiltered read. Entries already counted above are
    // skipped - double counting here would inflate the pot.
    for (final e in savingExpenses) {
      if (periodExpenses.any((p) => p.id == e.id)) continue;
      tally(e, countTowardMembers: false);
    }

    // Approved transfers, totalled per budget. This is the money-request
    // feature's entire effect on the numbers.
    final transferredIn = <String, double>{};
    final transferredOut = <String, double>{};
    for (final t in approvedTransfers) {
      transferredOut.update(
        t.fromBudgetId,
        (v) => v + t.amount,
        ifAbsent: () => t.amount,
      );
      transferredIn.update(
        t.toBudgetId,
        (v) => v + t.amount,
        ifAbsent: () => t.amount,
      );
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
        transferredIn: transferredIn[budget.id] ?? 0,
        transferredOut: transferredOut[budget.id] ?? 0,
      );
    }

    return PeriodSummary(
      period: period,
      monthStartDay: household.monthStartDay,
      viewerUid: viewerUid,
      monthly: budgets.where((b) => !b.isSaving).map(viewFor).toList(),
      savings: budgets.where((b) => b.isSaving).map(viewFor).toList(),
      expenses: periodExpenses,
      spendByMember: spendByMember,
    );
  }
}
