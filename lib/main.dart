import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'core/i18n/app_language.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'state/providers.dart';

/// Everything that has to happen before the first frame.
///
/// `main` is the very first Dart the app runs. It is `async` because both the
/// date data and Firebase need awaiting, and `runApp` must not be called until
/// they are ready.
Future<void> main() async {
  // Wires up the Flutter engine. Required before touching any plugin - without
  // it, Firebase.initializeApp throws.
  WidgetsFlutterBinding.ensureInitialized();

  // intl compiles in only en_US date data; every other locale - even plain
  // 'en' - throws LocaleDataException until this has run. With no argument it
  // loads them all, which is a few hundred KB and saves worrying about which.
  await initializeDateFormatting();

  // A sensible default for anyone who has not chosen a language yet. Each
  // signed-in user's own choice overrides this - see `languageProvider`.
  final deviceLanguage = AppLanguage.fromDeviceTag(
    WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
  );

  // Dates are formatted with an explicit locale everywhere (see
  // `dateLocaleProvider`), so this global is only a backstop for any call that
  // forgets to pass one.
  Intl.defaultLocale = Intl.verifiedLocale(
    deviceLanguage.intlLocale,
    DateFormat.localeExists,
    onFailure: (_) => 'en_US',
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    // The most common first-run state is "not configured yet". Say so plainly
    // rather than crashing on a red screen.
    runApp(SetupRequiredApp(message: '$error'));
    return;
  }

  runApp(
    // ProviderScope is where Riverpod keeps every provider's value. It has to
    // sit above anything that reads one, so it wraps the whole app.
    //
    // `overrides` swaps a provider's value for this run. Here it feeds in the
    // device's language, which main() knows and the provider cannot work out
    // for itself.
    ProviderScope(
      overrides: [
        deviceLanguageProvider.overrideWithValue(deviceLanguage),
      ],
      child: const FamilyMoneyApp(),
    ),
  );
}

/// Shown when Firebase could not be initialised at all.
class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Insets.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.settings_outlined, size: 32),
                  const SizedBox(height: Insets.lg),
                  Text(
                    'One setup step left',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: Insets.sm),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
