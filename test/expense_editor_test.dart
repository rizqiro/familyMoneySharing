import 'package:family_money_sharing/core/format/money.dart';
import 'package:family_money_sharing/core/format/period.dart';
import 'package:family_money_sharing/core/i18n/app_language.dart';
import 'package:family_money_sharing/core/i18n/app_text.dart';
import 'package:family_money_sharing/core/theme/app_colors.dart';
import 'package:family_money_sharing/core/theme/app_theme.dart';
import 'package:family_money_sharing/features/expenses/expense_editor.dart';
import 'package:family_money_sharing/models/budget.dart';
import 'package:family_money_sharing/models/household.dart';
import 'package:family_money_sharing/state/period_summary.dart';
import 'package:family_money_sharing/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The add-entry sheet, driven the way a person drives it.
///
/// These check the two things a person notices immediately and no unit test
/// would catch: that the sheet's submit button agrees with the direction
/// switch above it, and that the amount field is genuinely numeric once it is
/// wired into a real widget rather than tested as a class on its own.
void main() {
  const me = 'me';

  const household = Household(
    id: 'h1',
    name: 'Home',
    memberIds: [me],
    members: {},
    currencyCode: 'IDR',
    monthStartDay: 1,
    activeInviteCode: null,
    createdBy: me,
    createdAt: null,
  );

  Budget budget(String id, {bool saving = false}) => Budget(
        id: id,
        name: saving ? 'Holiday pot' : 'Living cost',
        kind: saving ? BudgetKind.saving : BudgetKind.monthly,
        amount: 8000000,
        controllerId: me,
        period: saving ? null : '2026-09',
        targetDate: null,
        note: '',
        archived: false,
        createdBy: me,
        createdAt: null,
      );

  Future<void> pump(WidgetTester tester, {bool saving = false}) async {
    final summary = PeriodSummary.build(
      period: const Period(2026, 9),
      household: household,
      viewerUid: me,
      budgets: [budget('b1'), if (saving) budget('pot', saving: true)],
      categories: const [],
      periodExpenses: const [],
      savingExpenses: const [],
      approvedTransfers: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          textProvider.overrideWithValue(const AppText(AppLanguage.english)),
          moneyProvider.overrideWithValue(Money('IDR')),
          currentUidProvider.overrideWithValue(me),
          householdProvider.overrideWith((ref) => Stream.value(household)),
          categoriesProvider.overrideWith((ref) => Stream.value(const [])),
          summaryProvider.overrideWithValue(summary),
          dateLocaleProvider.overrideWithValue('en_US'),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ExpenseEditor()),
        ),
      ),
    );
    await tester.pump();
  }

  /// The big submit button at the bottom.
  FilledButton submitButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton).last);

  testWidgets('the submit button follows the direction switch', (tester) async {
    await pump(tester);

    // Starts on spending: accent-coloured, and says so.
    expect(find.text('Add expense'), findsOneWidget);
    expect(
      submitButton(tester).style?.backgroundColor?.resolve({}),
      AppColors.light.accent,
    );

    // Tap "In" at the top of the sheet.
    await tester.tap(find.text('In'));
    await tester.pump();

    // This is the reported bug: the button used to stay red and keep saying
    // "Add expense" while the sheet was set to income.
    expect(find.text('Add income'), findsOneWidget);
    expect(find.text('Add expense'), findsNothing);
    expect(
      submitButton(tester).style?.backgroundColor?.resolve({}),
      AppColors.light.positive,
    );
  });

  testWidgets('the sheet title follows it too', (tester) async {
    await pump(tester);
    expect(find.text('New expense'), findsOneWidget);

    await tester.tap(find.text('In'));
    await tester.pump();

    expect(find.text('New income'), findsOneWidget);
    expect(find.text('New expense'), findsNothing);
  });

  testWidgets('a saving pot opens on income', (tester) async {
    await pump(tester, saving: true);

    // Putting money into a pot is the usual thing you do with one, so picking
    // the pot flips the default rather than making you correct it every time.
    await tester.tap(find.text('Holiday pot'));
    await tester.pump();

    expect(find.text('Add income'), findsOneWidget);
  });

  testWidgets('the amount field takes digits and refuses letters',
      (tester) async {
    await pump(tester);

    final amount = find.byType(TextField).first;

    await tester.enterText(amount, '1250000');
    await tester.pump();
    // Grouped as you type, so the number of zeros is countable at a glance.
    expect(find.text('1.250.000'), findsOneWidget);

    await tester.enterText(amount, 'abc');
    await tester.pump();
    // Rejected outright: the field keeps what it had rather than blanking.
    expect(find.text('1.250.000'), findsOneWidget);
  });
}
