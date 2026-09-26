import 'package:family_money_sharing/core/format/money.dart';
import 'package:family_money_sharing/core/format/period.dart';
import 'package:family_money_sharing/core/i18n/app_language.dart';
import 'package:family_money_sharing/core/i18n/app_text.dart';
import 'package:family_money_sharing/core/theme/app_theme.dart';
import 'package:family_money_sharing/features/budgets/budget_detail_page.dart';
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

/// Renders the budget detail page for a monthly budget and for a saving pot,
/// with data shaped like a household that has actually been using the app for a
/// few weeks. The goldens are here to be LOOKED at, not to lock the design
/// down; run with `--update-goldens` and open the PNGs.
void main() {
  initializeDateFormatting();


  const me = 'me';
  const her = 'her';

  const household = Household(
    id: 'h1',
    name: 'Rumah Rizqi',
    memberIds: [me, her],
    members: {
      me: HouseholdMember(uid: me, displayName: 'Rizqi', email: 'r@x.com'),
      her: HouseholdMember(uid: her, displayName: 'Nadia', email: 'n@x.com'),
    },
    currencyCode: 'IDR',
    monthStartDay: 1,
    activeInviteCode: null,
    createdBy: me,
    createdAt: null,
  );

  final now = DateTime(2026, 9, 18);

  Budget budget({required bool saving}) => Budget(
        id: saving ? 'pot' : 'b1',
        name: saving ? 'Tabungan sekolah' : 'Biaya hidup',
        kind: saving ? BudgetKind.saving : BudgetKind.monthly,
        amount: saving ? 20000000 : 8000000,
        controllerId: me,
        period: saving ? null : '2026-09',
        targetDate: saving ? DateTime(2027, 6, 1) : null,
        note: '',
        archived: false,
        createdBy: me,
        createdAt: null,
      );

  SpendCategory cat(String id, String name, String emoji, double amount,
          {String budgetId = 'b1',}) =>
      SpendCategory(
        id: id,
        budgetId: budgetId,
        name: name,
        emoji: emoji,
        allocated: amount,
        status: AllocationStatus.approved,
        createdBy: me,
        confirmedBy: her,
        decidedAt: now,
        decisionNote: '',
        createdAt: now,
        updatedAt: now,
      );

  Expense entry(
    String id,
    String categoryId,
    double amount,
    String note, {
    String budgetId = 'b1',
    EntryKind? kind,
    int day = 12,
  }) =>
      Expense(
        id: id,
        budgetId: budgetId,
        categoryId: categoryId,
        amount: amount,
        note: note,
        spentBy: me,
        spentAt: DateTime(2026, 9, day),
        period: '2026-09',
        createdAt: DateTime(2026, 9, day),
        kind: kind,
      );

  Future<List<Object>> shoot(
    WidgetTester tester,
    String name, {
    required bool saving,
    double width = 400,
  }) async {
    tester.view.physicalSize = Size(width, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final monthlyCats = [
      cat('c1', 'Makan', '🍜', 3000000),
      cat('c2', 'Transport', '🛵', 1200000),
      cat('c3', 'Listrik & air', '💡', 900000),
    ];
    // A saving pot's categories: the three seeded ones.
    final savingCats = [
      cat('s1', 'Pendidikan', '🎓', 12000000, budgetId: 'pot'),
      cat('s2', 'Dana darurat', '🏥', 6000000, budgetId: 'pot'),
      cat('s3', 'Lainnya', '📦', 2000000, budgetId: 'pot'),
    ];

    final monthlyEntries = [
      entry('e1', 'c1', 1850000, 'Belanja bulanan', day: 4),
      entry('e2', 'c1', 420000, 'Warung', day: 11),
      entry('e3', 'c2', 700000, 'Bensin', day: 9),
      entry('e4', 'c3', 940000, 'Token listrik', day: 15),
      entry('e5', '', 150000, 'Parkir', day: 16),
    ];
    // Deposits into the pot, plus one withdrawal taken back out.
    final savingEntries = [
      entry('p1', 's1', 4000000, 'Setoran Juli',
          budgetId: 'pot', kind: EntryKind.income, day: 3,),
      entry('p2', 's1', 2500000, 'Setoran Agustus',
          budgetId: 'pot', kind: EntryKind.income, day: 10,),
      entry('p3', 's2', 3000000, 'Setoran darurat',
          budgetId: 'pot', kind: EntryKind.income, day: 12,),
      entry('p4', 's2', 800000, 'Ambil buat berobat',
          budgetId: 'pot', kind: EntryKind.spending, day: 17,),
      // An old row from before the app knew about income: null kind on a pot
      // must read as a deposit.
      entry('p5', 's3', 500000, 'Setoran lama', budgetId: 'pot', day: 6),
    ];

    final summary = PeriodSummary.build(
      period: const Period(2026, 9),
      household: household,
      viewerUid: me,
      budgets: [budget(saving: false), budget(saving: true)],
      categories: [...monthlyCats, ...savingCats],
      periodExpenses: monthlyEntries,
      savingExpenses: savingEntries,
      approvedTransfers: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          textProvider.overrideWithValue(const AppText(AppLanguage.indonesian)),
          moneyProvider.overrideWithValue(Money('IDR')),
          currentUidProvider.overrideWithValue(me),
          householdProvider.overrideWith((ref) => Stream.value(household)),
          householdIdProvider.overrideWithValue('h1'),
          categoriesProvider.overrideWith(
            (ref) => Stream.value([...monthlyCats, ...savingCats]),
          ),
          summaryProvider.overrideWithValue(summary),
          dateLocaleProvider.overrideWithValue('id_ID'),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: BudgetDetailPage(budgetId: saving ? 'pot' : 'b1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Drain layout errors rather than letting the first one fail the test, so
    // the golden still gets written and every complaint is reported at once.
    final problems = <Object>[];
    for (var e = tester.takeException(); e != null; e = tester.takeException()) {
      problems.add(e);
    }

    // Every string the page actually shows, in tree order.
    debugPrint('===== $name =====');
    for (final w in tester.widgetList<Text>(find.byType(Text))) {
      final v = w.data ?? w.textSpan?.toPlainText() ?? '';
      if (v.trim().isNotEmpty) debugPrint('  | $v');
    }
    debugPrint('===== end $name =====');

    // Write the PNG only under `--update-goldens`, never compare. Fonts
    // rasterise differently on Linux, macOS and Windows, so a committed golden
    // would fail on whichever machine did not write it. These images are for
    // looking at, so writing them is the whole job:
    //
    //   flutter test test/budget_detail_render_test.dart --update-goldens
    if (autoUpdateGoldenFiles) {
      await expectLater(
        find.byType(BudgetDetailPage),
        matchesGoldenFile('render/$name.png'),
      );
    }
    return problems;
  }

  testWidgets('monthly budget detail', (tester) async {
    final problems = await shoot(tester, 'monthly', saving: false);
    for (final p in problems) {
      debugPrint('MONTHLY 400px: $p');
    }
  });

  testWidgets('saving pot detail', (tester) async {
    final problems = await shoot(tester, 'saving', saving: true);
    for (final p in problems) {
      debugPrint('SAVING 400px: $p');
    }
  });

  for (final w in [360.0, 390.0, 412.0]) {
    testWidgets('widths: monthly at $w', (tester) async {
      final problems = await shoot(tester, 'w_monthly_$w', saving: false, width: w);
      for (final p in problems) {
        debugPrint('MONTHLY ${w}dp: $p');
      }
    });
    testWidgets('widths: saving at $w', (tester) async {
      final problems = await shoot(tester, 'w_saving_$w', saving: true, width: w);
      for (final p in problems) {
        debugPrint('SAVING ${w}dp: $p');
      }
    });
  }
}
