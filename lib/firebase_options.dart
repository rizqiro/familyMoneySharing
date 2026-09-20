import 'package:firebase_core/firebase_core.dart';

/// PLACEHOLDER - replace by running `flutterfire configure` in the project
/// root. That command overwrites this file with the real options for your
/// Firebase project (see docs/FIREBASE_SETUP.md).
///
/// Until then [currentPlatform] throws, and the app shows a setup screen
/// instead of failing with a stack trace.
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase is not configured yet.\n\n'
      'Run `flutterfire configure` in the project root to generate\n'
      'lib/firebase_options.dart for your own Firebase project.\n\n'
      'Full walkthrough: docs/FIREBASE_SETUP.md',
    );
  }
}
