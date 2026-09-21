import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/auth_repository.dart';
import '../../state/providers.dart';

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
      if (_isSignUp) {
        await auth.signUp(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
      } else {
        await auth.signIn(email: _email.text, password: _password.text);
      }
      // The auth gate swaps the screen out; nothing to navigate here.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email first, then tap reset.');
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (mounted) showToast(context, 'Reset link sent to $email');
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

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
                    Text('Family Money', style: text.displayMedium),
                    const SizedBox(height: Insets.sm),
                    Text(
                      _isSignUp
                          ? 'One shared picture of where your money goes.'
                          : 'Welcome back.',
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
                        decoration: const InputDecoration(
                          hintText: 'Your name',
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Tell us what to call you'
                            : null,
                      ),
                      const SizedBox(height: Insets.md),
                    ],

                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(hintText: 'Email'),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return 'Enter your email';
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'That does not look like an email';
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
                        hintText: 'Password',
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
                        if (value.isEmpty) return 'Enter your password';
                        if (_isSignUp && value.length < 6) {
                          return 'Use at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    if (!_isSignUp)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : _resetPassword,
                          child: const Text('Forgot password'),
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
                          : Text(_isSignUp ? 'Create account' : 'Sign in'),
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
                            ? 'I already have an account'
                            : 'Create an account',
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
