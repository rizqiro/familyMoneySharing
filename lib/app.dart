import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/common.dart';
import 'features/auth/sign_in_page.dart';
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
      home: const _Gate(),
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
      loading: () => const _Splash(),
      error: (error, _) => _Fatal(message: '$error'),
      data: (user) {
        if (user == null) return const SignInPage();

        final profile = ref.watch(profileProvider);
        return profile.when(
          loading: () => const _Splash(),
          error: (error, _) => _Fatal(message: '$error'),
          data: (appUser) {
            if (appUser == null) return const _Splash();
            if (!appUser.hasHousehold) return const WelcomePage();

            // The profile can point at a household that is gone - a join that
            // failed part-way, or the other member removing this one. Treat a
            // missing household as having none rather than spinning forever.
            return ref.watch(householdProvider).when(
                  loading: () => const _Splash(),
                  error: (error, _) => _Fatal(message: '$error'),
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

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _Fatal extends ConsumerWidget {
  const _Fatal({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  title: 'Could not reach your data',
                  message: message,
                  actionLabel: 'Sign out',
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
