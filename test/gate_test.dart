import 'package:family_money_sharing/app.dart';
import 'package:family_money_sharing/core/i18n/app_language.dart';
import 'package:family_money_sharing/core/i18n/app_text.dart';
import 'package:family_money_sharing/core/theme/app_theme.dart';
import 'package:family_money_sharing/features/onboarding/splash_page.dart';
import 'package:family_money_sharing/models/app_user.dart';
import 'package:family_money_sharing/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The one state the app could not render.
///
/// Deleting an account erases the profile document and then the account. When
/// the second step failed - which Firebase makes the NORMAL outcome, since it
/// refuses a delete on a sign-in more than a few minutes old - what was left
/// behind was an account Firebase still considered signed in, with no profile
/// document to load. The gate answered that with a splash screen, so the app
/// sat on a spinner forever, survived restarts, and had nothing to tap.
///
/// These pin the escape hatch: it may wait, but it must not wait forever.
void main() {
  Future<void> pump(WidgetTester tester, {required AppUser? profile}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          textProvider.overrideWithValue(const AppText(AppLanguage.english)),
          profileProvider.overrideWith((ref) => Stream.value(profile)),
          householdProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const NoProfileScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('it waits first, because a fresh sign-up looks the same',
      (tester) async {
    await pump(tester, profile: null);

    // A sign-up's profile write has not landed yet. Offering "this account is
    // gone" here would be a lie, and a frightening one.
    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.text('This account is gone'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(SplashPage), findsOneWidget);
  });

  testWidgets('but it does not wait forever', (tester) async {
    await pump(tester, profile: null);

    await tester.pump(const Duration(seconds: 6));

    expect(find.byType(SplashPage), findsNothing);
    expect(find.text('This account is gone'), findsOneWidget);
    // And something to press. This is the whole point: the old screen had
    // nothing at all.
    expect(find.text('Sign in'), findsOneWidget);
  });
}
