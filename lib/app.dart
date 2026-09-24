import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/format/failure.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/common.dart';
import 'features/auth/sign_in_page.dart';
import 'features/onboarding/splash_page.dart';
import 'features/onboarding/welcome_page.dart';
import 'features/shell/home_shell.dart';
import 'state/providers.dart';

class FamilyMoneyApp extends StatelessWidget {
  const FamilyMoneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Money',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      // The splash holds the first frame for a beat, so a cold start opens on
      // the app's own colour instead of a white flash and a spinner. Once it
      // steps aside, _Gate decides which of the three real states we are in.
      home: const SplashGate(child: _Gate()),
    );
  }
}

/// Decides which of the three top-level states the app is in: signed out,
/// signed in without a household, or ready.
class _Gate extends ConsumerWidget {
  const _Gate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return auth.when(
      loading: () => const SplashPage(),
      error: (error, _) => _Fatal(error: error),
      data: (user) {
        if (user == null) return const SignInPage();

        final profile = ref.watch(profileProvider);
        return profile.when(
          loading: () => const SplashPage(),
          error: (error, _) => _Fatal(error: error),
          data: (appUser) {
            if (appUser == null) return const SplashPage();
            if (!appUser.hasHousehold) return const WelcomePage();

            // The profile can point at a household that is gone - a join that
            // failed part-way, or the other member removing this one. Treat a
            // missing household as having none rather than spinning forever.
            return ref.watch(householdProvider).when(
                  loading: () => const SplashPage(),
                  error: (error, _) => _Fatal(error: error),
                  data: (household) => household == null
                      ? const WelcomePage()
                      : const HomeShell(),
                );
          },
        );
      },
    );
  }
}

class _Fatal extends ConsumerWidget {
  const _Fatal({required this.error});

  /// The raw thrown object rather than a string, so the message can be built
  /// in the language the app is currently set to - which is not known until
  /// this widget builds.
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(textProvider);
    final message = describeFailure(error, t);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.xl),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: t('app.cannot_reach'),
                  message: message,
                  actionLabel: t('auth.sign_out'),
                  onAction: () =>
                      ref.read(authRepositoryProvider).signOut(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
