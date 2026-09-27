import 'package:family_money_sharing/core/format/money.dart';
import 'package:family_money_sharing/core/format/period.dart';
import 'package:family_money_sharing/core/i18n/app_language.dart';
import 'package:family_money_sharing/core/i18n/app_text.dart';
import 'package:family_money_sharing/core/theme/app_theme.dart';
import 'package:family_money_sharing/features/expenses/expense_editor.dart';
import 'package:family_money_sharing/models/budget.dart';
import 'package:family_money_sharing/models/expense.dart';
import 'package:family_money_sharing/models/household.dart';
import 'package:family_money_sharing/models/spend_category.dart';
import 'package:family_money_sharing/state/period_summary.dart';
import 'package:family_money_sharing/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// A savings balance is money that exists, and money that exists is never
/// negative.
///
/// A monthly budget is the opposite: going over it is allowed, and saying so is
/// the point of the whole screen. So these check both that a pot is floored and
/// that flooring it did not quietly floor the monthly case too.
void main() {
  initializeDateFormatting();

  const me = 'me';

  const household = Household(
    id: 'h1',
    name: 'Home',
    memberIds: [me],
    members: {me: HouseholdMember(uid: me, displayName: 'Rizqi', email: 'r@x')},
    currencyCode: 'IDR',
    monthStartDay: 1,
    activeInviteCode: null,
    createdBy: me,
    createdAt: null,
  );

  Budget pot() => const Budget(
        id: 'pot',
        name: 'Tabungan sekolah',
        kind: BudgetKind.saving,
        amount: 20000000,
        controllerId: me,
        period: null,
        targetDate: null,
        note: '',
        archived: false,
        createdBy: me,
        createdAt: null,
      );

  Budget monthly() => const Budget(
        id: 'b1',
        name: 'Biaya hidup',
        kind: BudgetKind.monthly,
        amount: 5000000,
        controllerId: me,
        period: '2026-09',
        targetDate: null,
        note: '',
        archived: false,
        createdBy: me,
        createdAt: null,
      );

  SpendCategory cat(String id, String budgetId, String name, double amount) =>
      SpendCategory(
        id: id,
        budgetId: budgetId,
        name: name,
        emoji: '🎓',
        allocated: amount,
        status: AllocationStatus.approved,
        createdBy: me,
        confirmedBy: me,
        decidedAt: null,
        decisionNote: '',
        createdAt: null,
        updatedAt: null,
      );

  Expense entry(
    String id,
    String budgetId,
    String categoryId,
    double amount, {
    EntryKind? kind,
  }) =>
      Expense(
        id: id,
        budgetId: budgetId,
        categoryId: categoryId,
        amount: amount,
        note: '',
        spentBy: me,
        spentAt: DateTime(2026, 9, 10),
        period: '2026-09',
        createdAt: DateTime(2026, 9, 10),
        kind: kind,
      );

  PeriodSummary summaryOf({
    List<Budget> budgets = const [],
    List<SpendCategory> categories = const [],
    List<Expense> periodExpenses = const [],
    List<Expense> savingExpenses = const [],
  }) =>
      PeriodSummary.build(
        period: const Period(2026, 9),
        household: household,
        viewerUid: me,
        budgets: budgets,
        categories: categories,
        periodExpenses: periodExpenses,
        savingExpenses: savingExpenses,
        approvedTransfers: const [],
      );

  group('a pot is floored at zero', () {
    test('a category that was over-withdrawn reads as empty, not negative', () {
      // Legacy data: this could be written before the editor refused it.
      final summary = summaryOf(
        budgets: [pot()],
        categories: [cat('s1', 'pot', 'Pendidikan', 12000000)],
        savingExpenses: [
          entry('a', 'pot', 's1', 1000000, kind: EntryKind.income),
          entry('b', 'pot', 's1', 2500000, kind: EntryKind.spending),
        ],
      );

      final view = summary.savings.single;
      expect(view.categories.single.spent, 0);
      expect(view.spent, 0);

      // And the bar cannot draw backwards off the left edge.
      expect(view.categories.single.progress, greaterThanOrEqualTo(0));
    });

    test('a monthly budget is still allowed to go over', () {
      final summary = summaryOf(
        budgets: [monthly()],
        categories: [cat('c1', 'b1', 'Makan', 1000000)],
        periodExpenses: [entry('a', 'b1', 'c1', 1800000)],
      );

      final view = summary.monthly.single;
      expect(view.categories.single.spent, 1800000);
      expect(view.categories.single.isOver, isTrue);
    });
  });

  group('the breakdown adds up', () {
    test('what is in categories plus what is not equals the balance', () {
      final summary = summaryOf(
        budgets: [pot()],
        categories: [
          cat('s1', 'pot', 'Pendidikan', 12000000),
          cat('s2', 'pot', 'Dana darurat', 6000000),
        ],
        savingExpenses: [
          entry('a', 'pot', 's1', 4000000, kind: EntryKind.income),
          entry('b', 'pot', 's2', 3000000, kind: EntryKind.income),
          entry('c', 'pot', 's2', 800000, kind: EntryKind.spending),
          // No category named: this is the third row of the card.
          entry('d', 'pot', '', 1500000, kind: EntryKind.income),
        ],
      );

      final view = summary.savings.single;
      expect(view.spent, 7700000);
      expect(view.savedInCategories, 6200000);
      expect(view.savedUnassigned, 1500000);
      expect(view.savedInCategories + view.savedUnassigned, view.spent);
    });

    test('an empty pot has nothing anywhere', () {
      final view = summaryOf(budgets: [pot()]).savings.single;
      expect(view.spent, 0);
      expect(view.savedInCategories, 0);
      expect(view.savedUnassigned, 0);
    });
  });

  group('the editor refuses to take out more than is there', () {
    Future<void> pump(
      WidgetTester tester, {
      String? categoryId,
      Expense? existing,
    }) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final categories = [
        cat('s1', 'pot', 'Pendidikan', 12000000),
        cat('s2', 'pot', 'Dana darurat', 6000000),
      ];
      final entries = [
        entry('a', 'pot', 's1', 4000000, kind: EntryKind.income),
        entry('b', 'pot', 's2', 3000000, kind: EntryKind.income),
        entry('d', 'pot', '', 1500000, kind: EntryKind.income),
        if (existing != null) existing,
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            textProvider.overrideWithValue(const AppText(AppLanguage.english)),
            moneyProvider.overrideWithValue(Money('IDR')),
            currentUidProvider.overrideWithValue(me),
            householdIdProvider.overrideWithValue('h1'),
            householdProvider.overrideWith((ref) => Stream.value(household)),
            categoriesProvider.overrideWith((ref) => Stream.value(categories)),
            summaryProvider.overrideWithValue(
              summaryOf(
                budgets: [pot()],
                categories: categories,
                savingExpenses: entries,
              ),
            ),
            dateLocaleProvider.overrideWithValue('en_US'),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: ExpenseEditor(
                existing: existing,
                initialBudgetId: 'pot',
                initialCategoryId: categoryId,
                initialKind: EntryKind.spending,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the ceiling is shown before you type, not after', (t) async {
      await pump(t, categoryId: 's2');
      // Dana darurat holds 3.000.000, so that is what may come out of it.
      expect(find.text('Rp 3.000.000 available'), findsOneWidget);
    });

    testWidgets('with no category it is the unassigned balance', (t) async {
      await pump(t);
      // 1.500.000 was paid in without naming a category; the rest belongs to
      // the categories holding it.
      expect(find.text('Rp 1.500.000 available'), findsOneWidget);
    });

    testWidgets('too much is refused and says what is there', (t) async {
      await pump(t, categoryId: 's2');

      await t.enterText(find.byType(TextField).first, '4000000');
      await t.pumpAndSettle();
      await t.tap(find.text('Add expense'));
      await t.pumpAndSettle();
      expect(find.text('Dana darurat only has Rp 3.000.000.'), findsOneWidget);
    });

    testWidgets('editing a withdrawal downwards is not refused as too big',
        (t) async {
      // The entry being edited is itself part of the balance, so its own
      // amount has to be handed back before the check, or lowering it would be
      // refused for exceeding a total it is inside.
      await pump(
        t,
        categoryId: 's2',
        existing: entry('w', 'pot', 's2', 2000000, kind: EntryKind.spending),
      );

      // 3.000.000 in, 2.000.000 already out, so 1.000.000 is left - plus the
      // 2.000.000 this entry is holding, which it may keep or give back.
      expect(find.text('Rp 3.000.000 available'), findsOneWidget);
    });

    testWidgets('paying in is never blocked', (t) async {
      await pump(t, categoryId: 's2');
      await t.tap(find.text('In'));
      await t.pump();

      // The ceiling only applies to money coming out.
      expect(find.textContaining('available'), findsNothing);
    });
  });
}
