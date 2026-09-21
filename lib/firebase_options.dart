import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Which Firebase project the app talks to.
///
/// Two ways to fill this in, and they produce the same result:
///
/// 1. `flutterfire configure` overwrites this whole file. Preferred when the
///    CLI cooperates.
/// 2. Paste the five values below by hand. Everything is in the Firebase
///    console under **Project settings** (the gear next to "Project Overview")
///    → **General**:
///      - `_projectId`          "Project ID"
///      - `_messagingSenderId`  "Project number"
///      - `_apiKey`             "Web API key"
///      - `_androidAppId`       Your apps → the Android app → "App ID"
///      - `_iosAppId`           Your apps → the iOS app → "App ID"
///
///    If no app is listed under "Your apps", add one there first. The Android
///    package name must match `applicationId` in `android/app/build.gradle`.
///
/// These are public identifiers, not secrets - access is controlled by the
/// Firestore rules in `firebase/firestore.rules`.
///
/// Passing options explicitly like this means Auth and Firestore need neither
/// `google-services.json` nor the Google Services Gradle plugin.
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static const _projectId = 'PASTE_PROJECT_ID';
  static const _messagingSenderId = 'PASTE_PROJECT_NUMBER';
  static const _apiKey = 'PASTE_WEB_API_KEY';
  static const _androidAppId = 'PASTE_ANDROID_APP_ID';

  // Only needed if you build for iOS.
  static const _iosAppId = 'PASTE_IOS_APP_ID';
  static const _iosBundleId = 'PASTE_IOS_BUNDLE_ID';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web is not set up. Run `flutterfire configure` and include web, or '
        'build for Android or iOS.',
      );
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _android,
      TargetPlatform.iOS => _ios,
      _ => throw UnsupportedError(
          '${defaultTargetPlatform.name} is not set up. Run '
          '`flutterfire configure` to add it.',
        ),
    };
  }

  static FirebaseOptions get _android {
    _require({
      'Project ID': _projectId,
      'Project number': _messagingSenderId,
      'Web API key': _apiKey,
      'Android App ID': _androidAppId,
    });

    return const FirebaseOptions(
      apiKey: _apiKey,
      appId: _androidAppId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
    );
  }

  static FirebaseOptions get _ios {
    _require({
      'Project ID': _projectId,
      'Project number': _messagingSenderId,
      'Web API key': _apiKey,
      'iOS App ID': _iosAppId,
      'iOS bundle ID': _iosBundleId,
    });

    return const FirebaseOptions(
      apiKey: _apiKey,
      appId: _iosAppId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      iosBundleId: _iosBundleId,
    );
  }

  /// Names the fields still holding their placeholder, so the setup screen
  /// says what is missing instead of "not configured".
  static void _require(Map<String, String> fields) {
    final missing = fields.entries
        .where((e) => e.value.startsWith('PASTE_'))
        .map((e) => e.key)
        .toList();
    if (missing.isEmpty) return;

    throw UnsupportedError(
      'Firebase is not configured yet.\n\n'
      'Still to fill in, in lib/firebase_options.dart:\n'
      '  • ${missing.join('\n  • ')}\n\n'
      'Find them in the Firebase console under Project settings → '
      'General.\n'
      'Or run: flutter pub global run flutterfire_cli:flutterfire configure\n\n'
      'Full walkthrough: docs/FIREBASE_SETUP.md',
    );
  }
}
