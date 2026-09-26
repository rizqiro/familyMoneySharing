import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/failure.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/auth_repository.dart';
import '../../state/providers.dart';

/// Sign in and sign up, in one screen.
///
/// One screen rather than two because the fields are nearly identical - sign-up
/// adds a name - and a toggle is less friction than a second route.
///
/// Uses `Form` plus `TextFormField`: each field carries its own `validator`, and
/// `_formKey.currentState!.validate()` runs them all and shows any errors in
/// place. Firebase errors are turned into readable sentences by `AuthRepository`
/// before they reach here.
enum _Mode { signIn, signUp }

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  bool get _isSignUp => _mode == _Mode.signUp;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final auth = ref.read(authRepositoryProvider);
      // The device's language seeds a brand-new profile, so the app is already
      // in the right language before anyone visits Settings.
      final language = ref.read(deviceLanguageProvider);
      if (_isSignUp) {
        await auth.signUp(
          name: _name.text,
          email: _email.text,
          password: _password.text,
          language: language,
        );
      } else {
        await auth.signIn(
          email: _email.text,
          password: _password.text,
          language: language,
        );
      }
      // The auth gate swaps the screen out; nothing to navigate here.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Signs in with Google. Backing out of the Google sheet is not an error.
  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle(
            language: ref.read(deviceLanguageProvider),
          );
      // The auth gate swaps the screen out on success; a cancellation just
      // leaves this page as it was, with no message. Somebody who changed
      // their mind does not need telling.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _error = describeFailure(e, ref.read(textProvider)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(
          () => _error = ref.read(textProvider)('auth.reset_need_email'),);
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (mounted) {
        showToast(
          context,
          ref.read(textProvider)('auth.reset_sent', {'email': email}),
        );
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.page,
                vertical: Insets.xxl,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: Insets.xl),
                    Text(t('auth.app_name'), style: text.displayMedium),
                    const SizedBox(height: Insets.sm),
                    Text(
                      _isSignUp ? t('auth.tagline') : t('auth.welcome_back'),
                      style: text.bodyLarge?.copyWith(
                        color: colors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: Insets.xxl),

                    if (_isSignUp) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: t('auth.name_hint'),
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? t('auth.err_name')
                            : null,
                      ),
                      const SizedBox(height: Insets.md),
                    ],

                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration:
                          InputDecoration(hintText: t('auth.email_hint')),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return t('auth.err_email_empty');
                        if (!value.contains('@') || !value.contains('.')) {
                          return t('auth.err_email_invalid');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: Insets.md),

                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: t('auth.password_hint'),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: colors.inkMuted,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        final value = v ?? '';
                        if (value.isEmpty) return t('auth.err_password_empty');
                        if (_isSignUp && value.length < 6) {
                          return t('auth.err_password_short');
                        }
                        return null;
                      },
                    ),

                    if (!_isSignUp)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : _resetPassword,
                          child: Text(t('auth.forgot_password')),
                        ),
                      ),

                    if (_error != null) ...[
                      const SizedBox(height: Insets.md),
                      ErrorNote(message: _error!),
                    ],

                    const SizedBox(height: Insets.xl),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isSignUp
                              ? t('auth.create_account')
                              : t('auth.sign_in'),),
                    ),
                    const SizedBox(height: Insets.lg),

                    // Kept below the email form rather than above it. Google is
                    // the faster path, but putting it first on a screen that is
                    // mostly a form reads as the form being the afterthought.
                    _OrDivider(label: t('auth.or')),
                    const SizedBox(height: Insets.lg),
                    _GoogleButton(
                      label: t('auth.continue_google'),
                      onPressed: _busy ? null : _google,
                    ),
                    const SizedBox(height: Insets.lg),

                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _mode =
                                    _isSignUp ? _Mode.signIn : _Mode.signUp;
                                _error = null;
                              }),
                      child: Text(
                        _isSignUp
                            ? t('auth.have_account')
                            : t('auth.no_account'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A hairline with a word in the middle.
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(child: Divider(color: colors.hairline)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.inkMuted),
          ),
        ),
        Expanded(child: Divider(color: colors.hairline)),
      ],
    );
  }
}

/// The "Continue with Google" button.
///
/// =============================================================================
/// WHY THE MARK IS DRAWN BY HAND
/// =============================================================================
/// Google's branding rules are specific about their logo's colours and
/// proportions, and shipping a PNG means four densities in the asset bundle
/// for one 18px mark. The four arcs below are the real geometry, inline, and
/// they scale to any size without a blurry edge.
///
/// A white button with a hairline is the neutral treatment Google's guidance
/// permits, and it sits better with this app's palette than their blue one.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: colors.surface,
        foregroundColor: colors.ink,
        side: BorderSide(color: colors.hairline),
        minimumSize: const Size.fromHeight(54),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _GoogleMark(size: 19),
          const SizedBox(width: Insets.md),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  // Google's four brand colours, in the order the arcs run.
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.22;
    // Inset by half the stroke so the ring's outer edge lands on the box.
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Four arcs, in radians. 0 is three o'clock and angles run clockwise.
    void arc(double startDeg, double sweepDeg, Color color) {
      canvas.drawArc(
        rect,
        startDeg * 3.1415926535 / 180,
        sweepDeg * 3.1415926535 / 180,
        false,
        paint..color = color,
      );
    }

    arc(-20, -70, _blue); // upper right
    arc(-90, -80, _red); // upper left
    arc(-170, -80, _yellow); // lower left
    arc(105, 70, _green); // lower right

    // The bar through the middle of the G, in blue.
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.52,
        size.height * 0.40,
        size.width * 0.45,
        stroke * 0.95,
      ),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(_GoogleMarkPainter oldDelegate) => false;
}
