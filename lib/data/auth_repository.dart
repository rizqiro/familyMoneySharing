import 'package:firebase_auth/firebase_auth.dart';

import '../core/i18n/app_language.dart';
import '../models/app_user.dart';
import 'firestore_refs.dart';

/// Raised for anything the user should read as a sentence rather than a code.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository(this._auth, this._refs);

  final FirebaseAuth _auth;
  final FirestoreRefs _refs;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// The signed-in user's profile document, live. Emits null while signed out.
  Stream<AppUser?> watchProfile(String uid) =>
      _refs.user(uid).snapshots().map((doc) {
        if (!doc.exists) return null;
        return AppUser.fromDoc(doc);
      });

  /// Creates the account and its profile document.
  ///
  /// [language] is whatever the app guessed from the phone at startup, so a
  /// brand-new account already reads in the right language before the user has
  /// been anywhere near Settings.
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
    required AppLanguage language,
  }) async {
    final credential = await _guard(
      () => _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );

    final user = credential.user!;
    final displayName = name.trim();
    await user.updateDisplayName(displayName);

    final profile = AppUser(
      uid: user.uid,
      displayName: displayName,
      email: user.email ?? email.trim(),
      householdId: null,
      language: language,
      createdAt: null,
    );
    await _refs.user(user.uid).set(profile.toCreateJson());
    return profile;
  }

  Future<void> signIn({
    required String email,
    required String password,
    required AppLanguage language,
  }) async {
    final credential = await _guard(
      () => _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );

    // A profile can be missing if sign-up was interrupted after the auth
    // account was created but before the document was written.
    final user = credential.user!;
    final doc = await _refs.user(user.uid).get();
    if (!doc.exists) {
      await _refs.user(user.uid).set(
            AppUser(
              uid: user.uid,
              displayName: user.displayName ?? '',
              email: user.email ?? email.trim(),
              householdId: null,
              language: language,
              createdAt: null,
            ).toCreateJson(),
          );
    }
  }

  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  /// Saves the interface language on the user's own profile.
  ///
  /// Writing it to Firestore rather than to the phone means the choice follows
  /// the person to a new device, and each partner keeps their own.
  Future<void> setLanguage(String uid, AppLanguage language) =>
      _refs.user(uid).update({'language': language.code});

  Future<void> signOut() => _auth.signOut();

  Future<void> updateDisplayName(String uid, String name) async {
    final trimmed = name.trim();
    await _auth.currentUser?.updateDisplayName(trimmed);
    await _refs.user(uid).update({'displayName': trimmed});

    // The household denormalises the name for the ledger labels.
    final profile = AppUser.fromDoc(await _refs.user(uid).get());
    if (profile.hasHousehold) {
      await _refs.household(profile.householdId!).update({
        'members.$uid.displayName': trimmed,
      });
    }
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    } on FirebaseException catch (e) {
      throw AuthFailure(e.message ?? 'Something went wrong. Try again.');
    }
  }

  String _messageFor(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'That email address does not look right.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Email or password is incorrect.',
        'email-already-in-use' =>
          'There is already an account with that email. Sign in instead.',
        'weak-password' => 'Use a password of at least 6 characters.',
        'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
        'network-request-failed' =>
          'No connection. Check your network and try again.',
        'operation-not-allowed' =>
          'Email sign-in is not enabled for this Firebase project yet.',
        _ => e.message ?? 'Could not complete that. Try again.',
      };
}
