import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // intl ships only en_US date data compiled in; every other locale - even
  // plain 'en' - throws LocaleDataException until this has run.
  await initializeDateFormatting();
  Intl.defaultLocale = Intl.verifiedLocale(
    WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
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

  runApp(const ProviderScope(child: FamilyMoneyApp()));
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
