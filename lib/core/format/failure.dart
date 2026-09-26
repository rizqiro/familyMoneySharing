import 'package:firebase_auth/firebase_auth.dart';

import '../../data/auth_repository.dart';
import '../../data/household_repository.dart';
import '../i18n/app_text.dart';

/// Turns whatever was thrown into a sentence a person can act on.
///
/// =============================================================================
/// WHY THIS EXISTS
/// =============================================================================
/// Every `catch` in the app used to do `setState(() => _error = '$e')`, which
/// puts this on screen:
///
///     [cloud_firestore/permission-denied] The caller does not have permission
///     to execute the specified operation.
///
/// That is a perfectly good message - for whoever wrote the security rules. For
/// anybody else it names no cause and suggests no next step, and it is in
/// English however the app is set.
///
/// So: the code is mapped to a translated sentence, and the raw text is kept
/// on the end in brackets so a bug report still carries the detail. Both, not
/// either.
///
/// =============================================================================
/// WHERE THESE CODES COME FROM
/// =============================================================================
/// [FirebaseException] is the base class for every Firebase error, and its
/// `code` is a short stable string. Firestore's are the gRPC status names
/// (`permission-denied`, `unavailable`, `not-found`); Firebase Auth's are its
/// own (`wrong-password`, `email-already-in-use`).
///
/// `permission-denied` in particular has two quite different causes, and the
/// message says both because the app cannot tell them apart from here:
///
///   1. the security rules have not been deployed, so the collection being
///      written has no rule at all and Firestore denies by default; or
///   2. the rules ARE deployed and correctly said no - you tried to touch
///      something that is not yours.
String describeFailure(Object error, AppText t) {
  // The repositories already translate the errors they understand into their
  // own failure types with a written-out message. Those win: they know more
  // about what was being attempted than this function can.
  if (error is AuthFailure) return error.message;
  if (error is HouseholdFailure) return error.message;

  if (error is FirebaseAuthException) {
    return _withDetail(t, _authKey(error.code), error.code);
  }

  if (error is FirebaseException) {
    return _withDetail(t, _firestoreKey(error.code), error.code);
  }

  // Something that is not a Firebase error at all - a parsing bug, a null. No
  // point guessing; show it as it is.
  return '$error';
}

/// The sentence, with the raw code in brackets after it.
///
/// Keeping the code visible costs one line and saves an afternoon: "it says
/// permission denied" is a bug report, "something went wrong" is not.
String _withDetail(AppText t, String key, String code) => '${t(key)} ($code)';

String _firestoreKey(String code) => switch (code) {
      // The user-facing sentence stays short on purpose. When this shows up
      // during development the usual cause is that firebase/firestore.rules
      // has not been published to the Firebase Console yet - but that is a
      // sentence for the developer, not for someone trying to log groceries.
      // The raw code is appended by [_withDetail], which is enough to tell the
      // two cases apart in a bug report.
      'permission-denied' => 'error.permission_denied',
      // The device is offline, or Firestore could not be reached. Writes are
      // queued locally and will go out on their own, which is worth saying so
      // nobody retypes the whole form.
      'unavailable' || 'deadline-exceeded' => 'error.offline',
      'unauthenticated' => 'error.signed_out',
      'not-found' => 'error.not_found',
      'already-exists' => 'error.already_exists',
      // Firestore's way of saying a query needs a composite index that does not
      // exist yet. The console link is in the raw message.
      'failed-precondition' => 'error.needs_index',
      'resource-exhausted' => 'error.quota',
      _ => 'error.unknown',
    };

String _authKey(String code) => switch (code) {
      'network-request-failed' => 'error.offline',
      'email-already-in-use' => 'error.email_taken',
      'invalid-email' => 'error.email_invalid',
      'weak-password' => 'error.password_weak',
      'wrong-password' ||
      'invalid-credential' ||
      'user-not-found' =>
        'error.credentials',
      'too-many-requests' => 'error.too_many',
      _ => 'error.unknown',
    };
