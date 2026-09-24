import 'package:family_money_sharing/core/format/period.dart';
import 'package:family_money_sharing/models/budget.dart';
import 'package:family_money_sharing/models/expense.dart';
import 'package:family_money_sharing/models/household.dart';
import 'package:family_money_sharing/models/money_request.dart';
import 'package:family_money_sharing/models/spend_category.dart';
import 'package:family_money_sharing/state/period_summary.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the month's arithmetic.
///
/// =============================================================================
/// WHY THIS FILE MATTERS MORE THAN THE REST
/// =============================================================================
/// Everything on every screen is a getter on this object. A mistake here is not
/// a wrong pixel, it is a wrong number about somebody's money - and a wrong
/// number looks exactly like a right one.
///
/// It is also pure Dart, so these run in milliseconds and fail for exactly one
/// reason: the rules about money changed.
void main() {
  const me = 'me';
  const them = 'them';

  const household = Household(
    id: 'h1',
    name: 'Home',
    memberIds: [me, them],
    members: {},
    currencyCode: 'IDR',
    monthStartDay: 1,
    activeInviteCode: null,
    createdBy: me,
    createdAt: null,
  );

  /// A past month, so nothing here depends on what today happens to be.
  const period = Period(2025, 9);

  Budget budget(
    String id, {
    double amount = 1000,
    String controller = me,
    bool saving = false,
  }) =>
      Budget(
        id: id,
        name: id,
        kind: saving ? BudgetKind.saving : BudgetKind.monthly,
        amount: amount,
        controllerId: controller,
        period: saving ? null : '2025-09',
        targetDate: null,
        note: '',
        archived: false,
        createdBy: controller,
        createdAt: null,
      );

  SpendCategory category(String id, String budgetId, double allocated) =>
      SpendCategory(
        id: id,
        budgetId: budgetId,
        name: id,
        emoji: '\u{1F6D2}',
        allocated: allocated,
        status: AllocationStatus.approved,
        createdBy: me,
        confirmedBy: them,
        decidedAt: null,
        decisionNote: '',
        createdAt: null,
        updatedAt: null,
      );

  Expense entry(
    String id, {
    required String budgetId,
    required double amount,
    String categoryId = '',
    String by = me,
    EntryKind? kind,
  }) =>
      Expense(
        id: id,
        budgetId: budgetId,
        categoryId: categoryId,
        amount: amount,
        note: '',
        spentBy: by,
        spentAt: DateTime(2025, 9, 10),
        period: '2025-09',
        createdAt: null,
        kind: kind,
      );

  MoneyRequest transfer({
    required String from,
    required String to,
    required double amount,
    AllocationStatus status = AllocationStatus.approved,
    String fromCategoryId = '',
  }) =>
      MoneyRequest(
        id: 'r-$from-$to-${amount.toInt()}',
        fromBudgetId: from,
        fromBudgetName: from,
        toBudgetId: to,
        toBudgetName: to,
        fromCategoryId: fromCategoryId,
        fromCategoryName: fromCategoryId,
        amount: amount,
        reason: 'petrol',
        period: '2025-09',
        requestedBy: me,
        requestedByName: 'Me',
        requestedFor: them,
        status: status,
        decisionNote: '',
        createdAt: null,
        decidedAt: null,
      );

  PeriodSummary summarise({
    List<Budget> budgets = const [],
    List<SpendCategory> categories = const [],
    List<Expense> entries = const [],
    List<Expense> savingEntries = const [],
    List<MoneyRequest> transfers = const [],
  }) =>
      PeriodSummary.build(
        period: period,
        household: household,
        viewerUid: me,
        budgets: budgets,
        categories: categories,
        periodExpenses: entries,
        savingExpenses: savingEntries,
        approvedTransfers:
            transfers.where((t) => t.isApproved).toList(),
        allTransfers: transfers,
      );

  group('income on a monthly budget', () {
    test('raises what is available without changing what was planned', () {
      final s = summarise(
        budgets: [budget('b1', amount: 1000)],
        entries: [
          entry('e1', budgetId: 'b1', amount: 300),
          entry('e2', budgetId: 'b1', amount: 500, kind: EntryKind.income),
        ],
      );
      final b = s.monthly.first;

      // Planned is what was budgeted; income is money that turned up on top.
      expect(b.planned, 1000);
      expect(b.income, 500);
      expect(b.available, 1500);
      expect(b.spent, 300);
      expect(b.remaining, 1200);
      expect(b.isOver, isFalse);
    });

    test('an entry with no direction is spending on a monthly budget', () {
      // Every row written before income existed, on a budget that is not a
      // saving pot, was an expense.
      final s = summarise(
        budgets: [budget('b1', amount: 1000)],
        entries: [entry('e1', budgetId: 'b1', amount: 400)],
      );

      expect(s.monthly.first.spent, 400);
      expect(s.monthly.first.income, 0);
    });

    test('income is nobody\'s share of the spending', () {
      final s = summarise(
        budgets: [budget('b1'), budget('b2', controller: them)],
        entries: [
          entry('e1', budgetId: 'b1', amount: 300),
          entry('e2', budgetId: 'b1', amount: 900, kind: EntryKind.income),
          entry('e3', budgetId: 'b2', amount: 200, by: them),
        ],
      );

      // The who-spent-what split would be nonsense otherwise: a payday would
      // show as one partner spending a fortune.
      expect(s.spendByMember[me], 300);
      expect(s.spendByMember[them], 200);
    });
  });

  group('saving pots', () {
    test('what is in the pot is what went in less what came back out', () {
      final s = summarise(
        budgets: [budget('pot', amount: 10000, saving: true)],
        entries: [
          entry('i1', budgetId: 'pot', amount: 2000, kind: EntryKind.income),
          entry('i2', budgetId: 'pot', amount: 500, kind: EntryKind.income),
          entry('w1', budgetId: 'pot', amount: 300, kind: EntryKind.spending),
        ],
      );
      final pot = s.savings.first;

      expect(pot.income, 2500);
      expect(pot.spending, 300);
      expect(pot.spent, 2200); // the meter reads the net
      expect(pot.planned, 10000); // the target
      expect(pot.remaining, 7800);

      // A pot cannot be "over": passing the target is the good outcome.
      expect(pot.isOver, isFalse);
    });

    test('an old entry with no direction is read as money paid IN', () {
      // This is the migration, and it is the whole reason `kind` is nullable.
      // Before income existed, the only way to add to a pot was to file an
      // expense against it. Reading those as withdrawals would turn every
      // household's savings negative overnight.
      final s = summarise(
        budgets: [budget('pot', amount: 10000, saving: true)],
        entries: [entry('old', budgetId: 'pot', amount: 2000)],
      );

      expect(s.savings.first.spent, 2000);
      expect(s.savings.first.income, 2000);
      expect(s.savings.first.spending, 0);
    });

    test('paying into a pot is not spending', () {
      final s = summarise(
        budgets: [budget('pot', amount: 10000, saving: true)],
        entries: [
          entry('i1', budgetId: 'pot', amount: 2000, kind: EntryKind.income),
        ],
      );

      expect(s.spendByMember[me], isNull);
      expect(s.savedThisPeriod, 2000);
    });
  });

  group('allocation cannot exceed the budget', () {
    test('headroom leaves out the category being edited', () {
      final s = summarise(
        budgets: [budget('b1', amount: 1000)],
        categories: [
          category('c1', 'b1', 300),
          category('c2', 'b1', 200),
        ],
      );
      final b = s.monthly.first;

      expect(b.allocated, 500);
      expect(b.unallocated, 500);

      // Editing c1: its own 300 is not competition for itself, so the cap is
      // 1000 - 200 rather than 1000 - 500. Without this you could never raise
      // a category above what was already free.
      expect(b.headroomExcluding('c1'), 800);
      expect(b.headroomExcluding('c2'), 700);
      expect(b.headroomExcluding(null), 500);
    });

    test('income raises the ceiling on what may be allocated', () {
      final s = summarise(
        budgets: [budget('b1', amount: 1000)],
        categories: [category('c1', 'b1', 1000)],
        entries: [
          entry('i1', budgetId: 'b1', amount: 400, kind: EntryKind.income),
        ],
      );

      // Money that actually arrived is money you may plan with.
      expect(s.monthly.first.headroomExcluding(null), 400);
      expect(s.monthly.first.isOverAllocated, isFalse);
    });

    test('spending past a category is still allowed', () {
      // The cap is on the PLAN. What actually happened is recorded whatever it
      // was - a budget that refuses to record an overspend is just wrong.
      final s = summarise(
        budgets: [budget('b1', amount: 1000)],
        categories: [category('c1', 'b1', 300)],
        entries: [
          entry('e1', budgetId: 'b1', amount: 500, categoryId: 'c1'),
        ],
      );
      final c = s.monthly.first.categories.first;

      expect(c.spent, 500);
      expect(c.allocated, 300);
      expect(c.isOver, isTrue);
      expect(c.remaining, -200);
    });
  });

  group('transfers', () {
    test('out of the slack: the budget shrinks, categories do not', () {
      final s = summarise(
        budgets: [budget('b1', amount: 1000), budget('b2')],
        categories: [category('c1', 'b1', 300)],
        transfers: [transfer(from: 'b1', to: 'b2', amount: 200)],
      );
      final b = s.monthly.firstWhere((v) => v.budget.id == 'b1');

      expect(b.planned, 800);
      expect(b.categories.first.allocated, 300);
      expect(b.unallocated, 500);
    });

    test('out of a category: that category shrinks, not its spending', () {
      final s = summarise(
        budgets: [budget('b1', amount: 1000), budget('b2')],
        categories: [category('c1', 'b1', 300)],
        transfers: [
          transfer(from: 'b1', to: 'b2', amount: 200, fromCategoryId: 'c1'),
        ],
      );
      final c = s.monthly.firstWhere((v) => v.budget.id == 'b1').categories.first;

      // The money left the category; it was not spent from it. Counting it as
      // spending would make the category look overspent and the budget fine,
      // which is exactly backwards.
      expect(c.allocated, 100);
      expect(c.spent, 0);
      expect(c.isOver, isFalse);
    });

    test('a fully carved budget stays consistent after granting from a category',
        () {
      // The bug this was written for: granting money out of a budget with
      // nothing unallocated used to leave the categories adding up to more
      // than the budget held.
      final s = summarise(
        budgets: [budget('b1', amount: 1000), budget('b2')],
        categories: [
          category('c1', 'b1', 600),
          category('c2', 'b1', 400),
        ],
        transfers: [
          transfer(from: 'b1', to: 'b2', amount: 250, fromCategoryId: 'c1'),
        ],
      );
      final b = s.monthly.firstWhere((v) => v.budget.id == 'b1');

      expect(b.planned, 750);
      expect(b.allocated, 750); // 350 + 400
      expect(b.isOverAllocated, isFalse);
      expect(b.unallocated, 0);
    });

    test('only approved transfers move money, but history keeps the rest', () {
      final s = summarise(
        budgets: [budget('b1', amount: 1000), budget('b2')],
        transfers: [
          transfer(from: 'b1', to: 'b2', amount: 200),
          transfer(
            from: 'b1',
            to: 'b2',
            amount: 999,
            status: AllocationStatus.rejected,
          ),
        ],
      );

      expect(s.monthly.firstWhere((v) => v.budget.id == 'b1').planned, 800);

      // A refusal is part of the record - it is the answer to "why didn't it
      // arrive?" - so it stays in the history.
      expect(s.transfers.length, 2);
      expect(s.transfersFor('b1').length, 2);
    });
  });

  test('a budget that granted away more than it held cannot go negative', () {
    final s = summarise(
      budgets: [budget('b1', amount: 100), budget('b2')],
      transfers: [transfer(from: 'b1', to: 'b2', amount: 500)],
    );

    // Clamped, because a negative plan makes every percentage below it
    // meaningless.
    expect(s.monthly.firstWhere((v) => v.budget.id == 'b1').planned, 0);
  });
}
