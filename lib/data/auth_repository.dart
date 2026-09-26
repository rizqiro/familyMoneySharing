import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
    await _ensureProfile(
      credential.user!,
      fallbackName: _nameFromEmail(email),
      language: language,
    );
  }

  /// Signs in with a Google account, creating the profile on first use.
  ///
  /// =============================================================================
  /// HOW THIS FITS TOGETHER
  /// =============================================================================
  /// Two separate systems. `google_sign_in` talks to Google and comes back with
  /// an ID token proving who you are. Firebase Auth does not care where that
  /// token came from - it takes the token, verifies it with Google itself, and
  /// issues its own session. From that point on the rest of the app cannot tell
  /// how you signed in, which is the point: `authStateChanges` emits the same
  /// kind of `User` either way.
  ///
  /// The package changed shape in version 7: there is a single
  /// `GoogleSignIn.instance`, it must be `initialize`d once before use, and
  /// `authenticate()` throws on cancellation rather than returning null.
  ///
  /// Returns false when the person backed out of the Google sheet - which is
  /// not an error and must not be shown as one.
  Future<bool> signInWithGoogle({required AppLanguage language}) async {
    final google = GoogleSignIn.instance;

    // `initialize` is idempotent but does platform work, so it is done once and
    // remembered. Not in main() on purpose: someone who only ever uses email
    // should not pay for this at startup.
    if (!_googleReady) {
      await google.initialize();
      _googleReady = true;
    }

    // Web uses a Google-rendered button instead of an app-triggered flow, so
    // the button is hidden there rather than failing at the tap.
    if (!google.supportsAuthenticate()) {
      throw const AuthFailure(
        'Google sign-in is not available on this platform.',
      );
    }

    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      throw AuthFailure(e.description ?? 'Google sign-in did not complete.');
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      // Almost always one specific misconfiguration - see FIREBASE_SETUP.md.
      throw const AuthFailure(
        'Google did not return an ID token. On Android this usually means the '
        'SHA-1 fingerprint is missing from the Firebase project, or the web '
        'client ID is not set. See docs/FIREBASE_SETUP.md.',
      );
    }

    final credential = await _guard(
      () => _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      ),
    );

    final user = credential.user!;
    await _ensureProfile(
      user,
      // Google gives us a name; email/password sign-up asks for one. Falling
      // back to the email's local part beats an empty avatar and a blank
      // ledger row.
      fallbackName: account.displayName ?? _nameFromEmail(user.email),
      language: language,
    );
    return true;
  }

  bool _googleReady = false;

  static String _nameFromEmail(String? email) {
    if (email == null || !email.contains('@')) return '';
    return email.split('@').first;
  }

  /// Writes the profile document if it is not there yet.
  ///
  /// Needed on every sign-in path, not just sign-up: a Google account has never
  /// been here before on its first visit, and an interrupted email sign-up can
  /// leave an auth account with no profile behind it.
  Future<void> _ensureProfile(
    User user, {
    required String fallbackName,
    required AppLanguage language,
  }) async {
    final doc = await _refs.user(user.uid).get();
    if (doc.exists) return;

    final name = (user.displayName ?? '').trim().isNotEmpty
        ? user.displayName!.trim()
        : fallbackName.trim();

    if ((user.displayName ?? '').trim().isEmpty && name.isNotEmpty) {
      await user.updateDisplayName(name);
    }

    await _refs.user(user.uid).set(
          AppUser(
            uid: user.uid,
            displayName: name,
            email: user.email ?? '',
            householdId: null,
            language: language,
            createdAt: null,
          ).toCreateJson(),
        );
  }

  /// Erases the account: the profile document first, then the auth account.
  ///
  /// =============================================================================
  /// ORDER MATTERS, AND SO DOES WHAT IS *NOT* HERE
  /// =============================================================================
  /// The Firestore document goes first. Deleting the auth account first would
  /// sign you out mid-way, and the security rules would then refuse the
  /// document delete - leaving an orphaned profile nobody can ever remove.
  ///
  /// Leaving the household is NOT done here. That is
  /// `HouseholdRepository.departForDeletion`, because it is the piece with real
  /// decisions in it (who keeps the shared records), and this class has no
  /// business knowing about households.
  ///
  /// Firebase refuses to delete an account whose sign-in is more than a few
  /// minutes old. That is a deliberate protection, not a bug: it stops someone
  /// who picked up an unlocked phone from erasing the account. When it happens
  /// the caller is told to sign in again.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _refs.user(user.uid).delete();

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw const AuthFailure(
          'For your security, sign in again and then delete your account. '
          'It only takes a moment.',
        );
      }
      throw AuthFailure(_messageFor(e));
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
