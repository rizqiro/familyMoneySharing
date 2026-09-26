import 'package:family_money_sharing/core/format/failure.dart';
import 'package:family_money_sharing/core/i18n/app_language.dart';
import 'package:family_money_sharing/core/i18n/app_text.dart';
import 'package:family_money_sharing/data/auth_repository.dart';
import 'package:family_money_sharing/data/household_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the error messages people actually see.
///
/// These exist because the failure path is the one nobody exercises by hand.
/// You notice a broken happy path in a second; you notice a useless error
/// message only when somebody is already stuck.
void main() {
  const id = AppText(AppLanguage.indonesian);
  const en = AppText(AppLanguage.english);

  /// Firestore throws `FirebaseException` with `plugin: 'cloud_firestore'`.
  FirebaseException firestore(String code) =>
      FirebaseException(plugin: 'cloud_firestore', code: code);

  group('describeFailure', () {
    test('permission-denied says the plain thing and keeps the code', () {
      final message = describeFailure(firestore('permission-denied'), en);

      // Short, and about the person: the undeployed-rules explanation is a
      // developer's problem, so it lives in a comment in failure.dart, not on
      // the screen of someone trying to log groceries.
      expect(message, contains('permission'));
      expect(message, isNot(contains('firestore.rules')));
      expect(message, isNot(contains('Firebase')));

      // The code still rides along, so a screenshot is a usable bug report -
      // and still tells the undeployed-rules case apart from a real refusal.
      expect(message, contains('permission-denied'));
    });

    test('it speaks whichever language the app is set to', () {
      final message = describeFailure(firestore('permission-denied'), id);

      expect(message, contains('tidak punya izin'));
      expect(message, isNot(contains('permission for this')));
    });

    test('offline is not reported as a refusal', () {
      // These two get confused constantly: both stop the write, only one is
      // the user's fault, and only one is worth retyping the form over.
      final message = describeFailure(firestore('unavailable'), en);

      expect(message, contains('No connection'));
      expect(message, isNot(contains('permission')));
    });

    test('an unmapped code still gets a sentence and keeps the code', () {
      final message = describeFailure(firestore('aborted'), en);

      expect(message, contains('Something went wrong'));
      expect(message, contains('aborted'));
    });

    test('auth errors are mapped separately from Firestore ones', () {
      final message = describeFailure(
        FirebaseAuthException(code: 'email-already-in-use'),
        en,
      );

      expect(message, contains('already in use'));
    });

    test("a repository's own message wins, unchanged", () {
      // The repositories know what was being attempted; this function does not.
      // So when one has already written a sentence, it is passed straight
      // through rather than flattened into a generic code message.
      const failure = HouseholdFailure('That invite has already been used.');

      expect(describeFailure(failure, en), 'That invite has already been used.');
      expect(describeFailure(const AuthFailure('No.'), en), 'No.');
    });

    test('something that is not a Firebase error at all is shown as-is', () {
      expect(
        describeFailure(const FormatException('bad number'), en),
        contains('bad number'),
      );
    });
  });
}
