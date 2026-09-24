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

/// One category with its money resolved.
class CategoryView {
  const CategoryView({
    required this.category,
    required this.spending,
    required this.income,
    required this.transferredOut,
    required this.saving,
  });

  final SpendCategory category;

  /// Raw totals for this category, kept apart rather than netted off, because
  /// "spent 500, took 200 back" and "spent 300" are different stories.
  final double spending;
  final double income;

  /// Money granted away out of this category by an approved request.
  ///
  /// Subtracted from the allocation rather than added to the spending: the
  /// money never was spent here, it left the category entirely. Treating it as
  /// spending would make the category look overspent and the budget look fine,
  /// which is exactly backwards.
  final double transferredOut;

  /// Whether the parent budget is a saving pot, which flips what "used" means.
  final bool saving;

  /// What this category may use, after anything granted away.
  double get allocated =>
      (category.countableAmount - transferredOut).clamp(0.0, double.infinity);

  /// The figure the category's bar measures: money out for a monthly budget,
  /// money in for a saving pot.
  double get spent => saving ? income - spending : spending;

  double get remaining => allocated - spent;

  /// Going over a category's allocation is allowed - the restriction is on
  /// PLANNING more than the budget holds, not on what actually happens. This
  /// is how that overspend is surfaced.
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

/// One budget with its categories, money and transfers resolved.
class BudgetView {
  const BudgetView({
    required this.budget,
    required this.categories,
    required this.spending,
    required this.income,
    required this.uncategorisedSpend,
    required this.transferredIn,
    required this.transferredOut,
  });

  final Budget budget;
  final List<CategoryView> categories;

  /// Money that left this budget, and money that arrived in it, as raw totals.
  ///
  /// For a monthly budget: what you spent, and any extra money paid into it.
  /// For a saving pot: what you took out, and what you put in.
  final double spending;
  final double income;

  /// Spending filed against this budget but under no category - what is left
  /// behind when a category is deleted. The entries survive; their label does
  /// not.
  final double uncategorisedSpend;

  /// Money granted to this budget by an approved request.
  final double transferredIn;

  /// Money granted away from this budget to the other member.
  final double transferredOut;

  bool get isSaving => budget.isSaving;

  /// What was planned: the budget as set, plus and minus approved transfers.
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

  /// The money actually available.
  ///
  /// For a monthly budget, income raises the ceiling: money paid in is money
  /// you may now spend. For a saving pot the ceiling is the target, which
  /// income moves you TOWARD rather than raising.
  double get available => isSaving ? planned : planned + income;

  /// The figure this budget's meter measures.
  ///
  /// Monthly: what has gone out. Saving: what is in the pot, which is what has
  /// been paid in less anything taken back out.
  double get spent => isSaving ? income - spending : spending;

  /// The total carved into categories, after anything granted away out of one.
  ///
  /// `fold` walks the list carrying a running value: start at 0.0, and for each
  /// category add its allocation. It is Dart's version of "sum these up".
  double get allocated => categories.fold(0.0, (sum, c) => sum + c.allocated);

  /// Budget money not yet assigned to any category. This is the slack a money
  /// request is granted out of before any category has to be touched.
  double get unallocated => (available - allocated).clamp(0.0, double.infinity);

  /// How much may still be allocated, ignoring one category.
  ///
  /// The category editor asks this when checking a new amount: "if this
  /// category did not exist, how much of the budget would be unspoken for?"
  /// Passing the id of the category being edited is what lets you raise it from
  /// 300k to 400k without its own 300k counting against the headroom.
  double headroomExcluding(String? categoryId) {
    final others = categories
        .where((c) => c.category.id != categoryId)
        .fold(0.0, (sum, c) => sum + c.allocated);
    return (available - others).clamp(0.0, double.infinity);
  }

  double get remaining => available - spent;

  /// A saving pot cannot be "over" - passing the target is the good outcome.
  bool get isOver => !isSaving && available > 0 && spent > available;

  /// The categories add up to more than the budget holds.
  ///
  /// Creating that state is blocked in the category editor, but it can still
  /// arise afterwards: granting money away, or lowering the budget, shrinks
  /// what is available underneath allocations that were fine when they were
  /// made. So it is still worth surfacing.
  bool get isOverAllocated => available > 0 && allocated > available;

  /// How many allocations are still waiting on the other member.
  int get pendingCount => categories.where((c) => c.category.isPending).length;

  double get progress {
    if (available <= 0) return spent > 0 ? 1 : 0;
    return (spent / available).clamp(0.0, 1.0);
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
    required this.transfers,
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

  /// uid -> total spent this month. Income is left out: money arriving is not
  /// somebody's share of the spending.
  final Map<String, double> spendByMember;

  /// Every money request decided or still open this month, newest first.
  ///
  /// The history screen reads this. Requests are kept on the summary rather
  /// than fetched separately because the same list is already needed to work
  /// the transfers into the figures above - one stream, two uses.
  final List<MoneyRequest> transfers;

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
    transfers: [],
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

  /// Money paid into the monthly budgets this period. Not counted as planned:
  /// it is money that turned up, not money anybody budgeted for.
  double get income => monthly.fold(0.0, (sum, b) => sum + b.income);

  /// What the household may still spend, income included.
  double get available => monthly.fold(0.0, (sum, b) => sum + b.available);

  double get remaining => available - spent;
  bool get isOver => available > 0 && spent > available;

  /// The net movement into saving pots this period: paid in, less taken out.
  double get savedThisPeriod => savings.fold(0.0, (sum, b) => sum + b.spent);

  double get progress {
    if (available <= 0) return spent > 0 ? 1 : 0;
    return (spent / available).clamp(0.0, 1.0);
  }

  /// Transfers the viewer asked for, and transfers the viewer was asked for.
  /// Both directions, every outcome - the history screen shows the lot.
  List<MoneyRequest> get transfersAsked =>
      transfers.where((r) => r.requestedBy == viewerUid).toList();

  List<MoneyRequest> get transfersAskedOfMe =>
      transfers.where((r) => r.requestedFor == viewerUid).toList();

  /// Transfers that touched one budget, either way.
  ///
  /// Refused ones are included: "I asked and was told no" is part of a
  /// budget's story, and leaving it out is how a budget looks like nothing
  /// ever happened.
  List<MoneyRequest> transfersFor(String budgetId) => transfers
      .where((r) => r.fromBudgetId == budgetId || r.toBudgetId == budgetId)
      .toList();

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
  /// The shape of the work is: make the lookup maps in a single pass over the
  /// entries, then build each budget's view by reading from those maps. That
  /// keeps it linear - one pass over the entries, one over the budgets -
  /// rather than re-scanning every entry for every budget.
  static PeriodSummary build({
    required Period period,
    required Household household,
    required String? viewerUid,
    required List<Budget> budgets,
    required List<SpendCategory> categories,
    required List<Expense> periodExpenses,
    required List<Expense> savingExpenses,
    required List<MoneyRequest> approvedTransfers,
    List<MoneyRequest> allTransfers = const [],
  }) {
    // Which budgets are saving pots. Needed before anything is tallied,
    // because it decides how an entry with no direction on it is read - see
    // `Expense.kind`.
    final savingIds = budgets.where((b) => b.isSaving).map((b) => b.id).toSet();

    // Two maps per level - one for money out, one for money in - rather than
    // one map of a record. Two adds are cheaper to read than a pair that has
    // to be unpacked at every use.
    final spendingByCategory = <String, double>{};
    final incomeByCategory = <String, double>{};
    final spendingByBudget = <String, double>{};
    final incomeByBudget = <String, double>{};
    final spendByMember = <String, double>{};

    /// Adds one entry into the maps.
    ///
    /// `update` takes the existing value and returns the new one; `ifAbsent`
    /// supplies the starting value the first time a key is seen. It saves
    /// writing "if the key is missing, put 0, then add".
    void tally(Expense e, {required bool countTowardMembers}) {
      final saving = savingIds.contains(e.budgetId);
      final income = e.kindIn(saving: saving) == EntryKind.income;

      final byBudget = income ? incomeByBudget : spendingByBudget;
      byBudget.update(e.budgetId, (v) => v + e.amount, ifAbsent: () => e.amount);

      if (e.categoryId.isNotEmpty) {
        final byCategory = income ? incomeByCategory : spendingByCategory;
        byCategory.update(
          e.categoryId,
          (v) => v + e.amount,
          ifAbsent: () => e.amount,
        );
      }

      // Money arriving is nobody's share of the spending, so it stays out of
      // the who-spent-what split however it was filed.
      if (countTowardMembers && !income) {
        spendByMember.update(
          e.spentBy,
          (v) => v + e.amount,
          ifAbsent: () => e.amount,
        );
      }
    }

    for (final e in periodExpenses) {
      // Putting money into savings is not "spending", so it stays out of the
      // who-spent-what split. Otherwise a big transfer to savings would look
      // like one partner overspending wildly.
      tally(e, countTowardMembers: !savingIds.contains(e.budgetId));
    }

    // Saving pots show a running total across every month, so their entries
    // come from a second, unfiltered read. Entries already counted above are
    // skipped - double counting here would inflate the pot.
    final seen = periodExpenses.map((e) => e.id).toSet();
    for (final e in savingExpenses) {
      if (seen.contains(e.id)) continue;
      tally(e, countTowardMembers: false);
    }

    // Approved transfers, totalled per budget and per category. This is the
    // money-request feature's entire effect on the numbers.
    final transferredIn = <String, double>{};
    final transferredOut = <String, double>{};
    final transferredOutOfCategory = <String, double>{};
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
      // Only when the approver named one. Otherwise it came out of the
      // budget's unallocated slack and no category is any the poorer.
      if (t.hasSourceCategory) {
        transferredOutOfCategory.update(
          t.fromCategoryId,
          (v) => v + t.amount,
          ifAbsent: () => t.amount,
        );
      }
    }

    BudgetView viewFor(Budget budget) {
      final saving = budget.isSaving;

      final children = categories
          .where((c) => c.budgetId == budget.id)
          .map(
            (c) => CategoryView(
              category: c,
              spending: spendingByCategory[c.id] ?? 0,
              income: incomeByCategory[c.id] ?? 0,
              transferredOut: transferredOutOfCategory[c.id] ?? 0,
              saving: saving,
            ),
          )
          .toList()
        ..sort((a, b) => b.allocated.compareTo(a.allocated));

      final spending = spendingByBudget[budget.id] ?? 0;
      final categorised = children.fold(0.0, (sum, c) => sum + c.spending);

      return BudgetView(
        budget: budget,
        categories: children,
        spending: spending,
        income: incomeByBudget[budget.id] ?? 0,
        uncategorisedSpend:
            (spending - categorised).clamp(0.0, double.infinity),
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
      // Falls back to the approved ones when the full history has not been
      // passed, so a caller that only cares about the figures need not fetch
      // it twice.
      transfers: allTransfers.isEmpty ? approvedTransfers : allTransfers,
    );
  }
}
