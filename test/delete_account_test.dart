import 'package:family_money_sharing/core/format/money.dart';
import 'package:family_money_sharing/core/i18n/app_language.dart';
import 'package:family_money_sharing/core/i18n/app_text.dart';
import 'package:family_money_sharing/core/theme/app_theme.dart';
import 'package:family_money_sharing/features/settings/delete_account_page.dart';
import 'package:family_money_sharing/models/app_user.dart';
import 'package:family_money_sharing/models/household.dart';
import 'package:family_money_sharing/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The account-deletion screen.
///
/// =============================================================================
/// WHY THESE ARE THE TESTS THAT MATTER
/// =============================================================================
/// This screen has one irreversible button on it. The failure modes are not
/// crashes - they are a screen that deletes when it should have asked, or one
/// that tells somebody their partner will lose nothing when their partner will
/// lose a year of records.
///
/// So: does it say the right thing to a solo user versus a paired one, and does
/// the confirmation actually hold?
void main() {
  const me = 'me';
  const them = 'them';

  Household household({bool paired = false, String eraseBy = ''}) => Household(
        id: 'h1',
        name: 'Home',
        memberIds: paired ? const [me, them] : const [me],
        members: {
          me: const HouseholdMember(
            uid: me,
            displayName: 'Rizqi',
            email: 'r@example.com',
          ),
          if (paired)
            them: const HouseholdMember(
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
        eraseRequestedBy: eraseBy,
        eraseRequestedByName: eraseBy.isEmpty ? '' : 'Nadia',
      );

  Future<void> pump(WidgetTester tester, {required bool paired}) async {
    // A tall viewport so the whole page is laid out at once. A ListView does
    // not build children that are off-screen, so on a phone-sized surface the
    // confirmation field and the button below it would not exist to be tapped.
    tester.view.physicalSize = const Size(400, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final h = household(paired: paired);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          textProvider.overrideWithValue(const AppText(AppLanguage.english)),
          moneyProvider.overrideWithValue(Money('IDR')),
          currentUidProvider.overrideWithValue(me),
          householdProvider.overrideWith((ref) => Stream.value(h)),
          profileProvider.overrideWith(
            (ref) => Stream.value(
              const AppUser(
                uid: me,
                displayName: 'Rizqi',
                email: 'r@example.com',
                householdId: 'h1',
                language: AppLanguage.english,
                createdAt: null,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DeleteAccountPage(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('alone: it says everything goes, and does not mention a partner',
      (tester) async {
    await pump(tester, paired: false);

    expect(
      find.text('Every budget, entry and saving pot of yours goes with it.'),
      findsOneWidget,
    );
    // No partner means no relationship message and no shared-records section -
    // both would be talking about somebody who isn't there.
    expect(find.text('Before you do'), findsNothing);
    expect(find.text('The shared records'), findsNothing);
  });

  testWidgets('paired: it is honest that the partner keeps the records',
      (tester) async {
    await pump(tester, paired: true);

    expect(find.textContaining('You leave the household'), findsOneWidget);
    // The important one. Saying "all your data is erased" while your partner
    // keeps a year of shared entries would be a lie.
    expect(
      find.textContaining('keeps the shared budgets and ledger'),
      findsOneWidget,
    );
  });

  testWidgets('paired: the message asking them to talk first is shown',
      (tester) async {
    await pump(tester, paired: true);

    expect(find.text('Before you do'), findsOneWidget);
    expect(find.textContaining('Often it isn’t really about the money'),
        findsOneWidget,);

    // And it does not block anything: the delete button is right there.
    expect(find.text('Delete my account'), findsOneWidget);
  });

  testWidgets('erasing the shared records is opt-in, not the default',
      (tester) async {
    await pump(tester, paired: true);

    final toggle = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(toggle.value, isFalse);
    expect(find.textContaining('Nadia will be asked'), findsOneWidget);
  });

  testWidgets('it does not imply the person is banned for good',
      (tester) async {
    await pump(tester, paired: false);

    // Deleting a Firebase account frees the email, so signing up again works
    // - it just gets you a new, empty account. Saying only "you will not be
    // able to sign in again" reads as a permanent ban, which is wrong and
    // would put somebody off deleting when they are entitled to.
    expect(
      find.textContaining('You can sign up again with the same email'),
      findsOneWidget,
    );
    expect(find.textContaining('Nothing comes back'), findsOneWidget);
  });

  testWidgets('the wrong confirmation word stops it', (tester) async {
    await pump(tester, paired: true);

    await tester.enterText(find.byType(TextField).last, 'delete please');
    await tester.tap(find.text('Delete my account'));
    await tester.pump();

    // Refused before any dialog appears - nothing has been touched.
    expect(find.text('Type DELETE exactly to continue.'), findsOneWidget);
    expect(find.text('Delete your account?'), findsNothing);
  });

  testWidgets('the right word still asks once more before doing it',
      (tester) async {
    await pump(tester, paired: true);

    await tester.enterText(find.byType(TextField).last, 'DELETE');
    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();

    // Typing the word is not the deletion. One more deliberate confirmation.
    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.text('Cancel'), findsWidgets);
  });
}
