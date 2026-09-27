import 'dart:async';

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
            // Signed in, with no profile document behind it. Two ways to get
            // here: a sign-up whose profile write has not landed yet, which
            // resolves itself in a moment; or an account whose document was
            // deleted while the sign-in survived, which never resolves at all.
            // This used to return SplashPage for both, so the second case sat
            // on a spinner forever, through restarts, with nothing to tap.
            if (appUser == null) return const NoProfileScreen();
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

/// Signed in with nothing behind it.
///
/// Public, unlike the other screens in this file, so a test can hold it
/// directly: the bug it exists to prevent is a timing one, and driving it
/// through [_Gate] would mean faking a Firebase `User`.
///
/// Waits out the honest case - a profile document that is still being written
/// during sign-up - and then offers the only thing that helps if it never
/// arrives: a way back to the sign-in page. Anything is better than a spinner
/// that cannot end, which is what deleting an account used to leave behind.
class NoProfileScreen extends StatefulWidget {
  const NoProfileScreen({super.key});

  @override
  State<NoProfileScreen> createState() => _NoProfileState();
}

class _NoProfileState extends State<NoProfileScreen> {
  /// Long enough for a sign-up's profile write to land on a slow connection,
  /// short enough that nobody decides the app is broken and closes it.
  static const _grace = Duration(seconds: 5);

  bool _waited = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_grace, () {
      if (mounted) setState(() => _waited = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_waited) return const SplashPage();
    return Consumer(
      builder: (context, ref, _) {
        final t = ref.watch(textProvider);
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Insets.xl),
              child: Center(
                child: EmptyState(
                  icon: Icons.person_off_outlined,
                  title: t('app.no_profile_title'),
                  message: t('app.no_profile_body'),
                  actionLabel: t('auth.sign_in'),
                  onAction: () =>
                      ref.read(authRepositoryProvider).signOut(),
                ),
              ),
            ),
          ),
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
