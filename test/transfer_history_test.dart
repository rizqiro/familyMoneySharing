import 'package:family_money_sharing/core/format/money.dart';
import 'package:family_money_sharing/core/i18n/app_language.dart';
import 'package:family_money_sharing/core/i18n/app_text.dart';
import 'package:family_money_sharing/core/theme/app_theme.dart';
import 'package:family_money_sharing/models/household.dart';
import 'package:family_money_sharing/models/money_request.dart';
import 'package:family_money_sharing/models/spend_category.dart';
import 'package:family_money_sharing/features/money/transfer_history.dart';
import 'package:family_money_sharing/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Does a row of history say the right thing?
///
/// The labelling here has four cases - you asked and got it, you asked and were
/// refused, you were asked and gave, you were asked and refused - and they are
/// easy to wire up one off. A wrong one does not crash, it just quietly tells
/// somebody the opposite of what happened, which is the worst kind of bug in a
/// money app.
void main() {
  const me = 'me';
  const them = 'them';

  const household = Household(
    id: 'h1',
    name: 'Home',
    memberIds: [me, them],
    members: {
      me: HouseholdMember(
        uid: me,
        displayName: 'Rizqi',
        email: 'r@example.com',
      ),
      them: HouseholdMember(
        uid: them,
        displayName: 'Nadia Putri',
        email: 'n@example.com',
      ),
    },
    currencyCode: 'IDR',
    monthStartDay: 1,
    activeInviteCode: null,
    createdBy: me,
    createdAt: null,
  );

  MoneyRequest request({
    required String by,
    required String forWhom,
    required AllocationStatus status,
    String fromCategory = '',
    String note = '',
  }) =>
      MoneyRequest(
        id: 'r1',
        fromBudgetId: 'theirs',
        fromBudgetName: 'Living cost',
        toBudgetId: 'mine',
        toBudgetName: 'Pocket money',
        fromCategoryId: fromCategory,
        fromCategoryName: fromCategory,
        amount: 500000,
        reason: 'Bensin',
        period: '2025-09',
        requestedBy: by,
        requestedByName: by == me ? 'Me' : 'Nadia',
        requestedFor: forWhom,
        status: status,
        decisionNote: note,
        createdAt: null,
        decidedAt: DateTime(2025, 9, 20),
      );

  Future<void> pump(
    WidgetTester tester,
    List<MoneyRequest> requests, {
    String? budgetId,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          textProvider.overrideWithValue(const AppText(AppLanguage.english)),
          moneyProvider.overrideWithValue(Money('IDR')),
          currentUidProvider.overrideWithValue(me),
          householdProvider.overrideWith((ref) => Stream.value(household)),
          dateLocaleProvider.overrideWithValue('en_US'),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TransferHistory(requests: requests, budgetId: budgetId),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('money you asked for and got reads as received', (tester) async {
    await pump(tester, [
      request(by: me, forWhom: them, status: AllocationStatus.approved),
    ]);

    expect(find.text('Got it from Nadia'), findsOneWidget);
    expect(find.text('Rp 500.000'), findsOneWidget);
  });

  testWidgets('money you were asked for and gave reads as given',
      (tester) async {
    await pump(tester, [
      request(by: them, forWhom: me, status: AllocationStatus.approved),
    ]);

    expect(find.text('Gave it to Nadia'), findsOneWidget);
  });

  testWidgets('a refusal is shown, with the reason they gave', (tester) async {
    await pump(tester, [
      request(
        by: me,
        forWhom: them,
        status: AllocationStatus.rejected,
        note: 'not this month',
      ),
    ]);

    expect(find.text('Nadia said no'), findsOneWidget);
    expect(find.textContaining('not this month'), findsOneWidget);

    // The amount is struck through: it is what was asked for, not what moved.
    final amount = tester.widget<Text>(find.text('Rp 500.000'));
    expect(amount.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('the category it came out of is named', (tester) async {
    await pump(tester, [
      request(
        by: them,
        forWhom: me,
        status: AllocationStatus.approved,
        fromCategory: 'Groceries',
      ),
    ]);

    // This is the line that explains why a category suddenly holds less.
    expect(find.textContaining('out of Groceries'), findsOneWidget);
  });

  testWidgets('on a budget screen the direction follows the budget',
      (tester) async {
    // Same request, read from the SOURCE budget: money left here, even though
    // the person reading is the one who asked for it.
    await pump(
      tester,
      [request(by: me, forWhom: them, status: AllocationStatus.approved)],
      budgetId: 'theirs',
    );

    // Read from the source budget the money LEFT, so it is a gift out - and
    // the person it went to happens to be the one reading, hence "You".
    expect(find.text('Gave it to You'), findsOneWidget);
  });

  testWidgets('requests still waiting are left out', (tester) async {
    // They are already on the Inbox as cards with buttons; listing them here
    // too would make one item look like two.
    await pump(tester, [
      request(by: me, forWhom: them, status: AllocationStatus.pending),
    ]);

    expect(find.byType(Text), findsNothing);
  });
}
