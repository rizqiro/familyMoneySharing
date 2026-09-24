import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/failure.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_card.dart';
import '../../data/household_repository.dart';
import '../../state/providers.dart';
import '../pairing/join_page.dart';

/// Shown once: the user is signed in but belongs to no household yet.
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  bool _busy = false;
  String? _error;

  Future<void> _createHousehold() async {
    final profile = ref.read(profileProvider).valueOrNull;
    if (profile == null) return;

    final t = ref.read(textProvider);
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NewHouseholdSheet(
        defaultName: t('onboarding.default_name', {
          'name': profile.displayName.trim().split(' ').first,
        }),
      ),
    );
    if (result == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(householdRepositoryProvider).create(
            user: profile,
            name: result.$1,
            currencyCode: result.$2,
          );
    } on HouseholdFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        // Raw Firebase codes mean nothing to whoever is holding the phone.
        // See core/format/failure.dart.
        setState(() => _error = describeFailure(e, ref.read(textProvider)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
    final profile = ref.watch(profileProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Insets.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: Insets.xl),
                  Text(
                    t('onboarding.hi', {
                      'name': profile?.displayName.split(' ').first ?? '',
                    }).trim(),
                    style: text.displayMedium,
                  ),
                  const SizedBox(height: Insets.sm),
                  Text(
                    t('onboarding.blurb'),
                    style: text.bodyLarge?.copyWith(color: colors.inkSecondary),
                  ),
                  const SizedBox(height: Insets.xxl),

                  _ChoiceCard(
                    icon: Icons.add_home_outlined,
                    title: t('onboarding.start'),
                    message: t('onboarding.start_blurb'),
                    onTap: _busy ? null : _createHousehold,
                  ),
                  const SizedBox(height: Insets.md),
                  _ChoiceCard(
                    icon: Icons.qr_code_scanner,
                    title: t('onboarding.join'),
                    message: t('onboarding.join_blurb'),
                    onTap: _busy
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const JoinPage(),
                              ),
                            ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: Insets.lg),
                    ErrorNote(message: _error!),
                  ],

                  const SizedBox(height: Insets.xxl),
                  TextButton(
                    onPressed: () =>
                        ref.read(authRepositoryProvider).signOut(),
                    child: Text(t('auth.sign_out')),
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

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Insets.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: colors.ink),
          ),
          const SizedBox(width: Insets.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: text.bodySmall?.copyWith(color: colors.inkSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: colors.inkMuted, size: 20),
        ],
      ),
    );
  }
}

/// Collects the household name and currency before creating it.
class _NewHouseholdSheet extends ConsumerStatefulWidget {
  const _NewHouseholdSheet({required this.defaultName});

  final String defaultName;

  @override
  ConsumerState<_NewHouseholdSheet> createState() =>
      _NewHouseholdSheetState();
}

class _NewHouseholdSheetState extends ConsumerState<_NewHouseholdSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.defaultName);
  String _currency = CurrencyOption.idr.code;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: Insets.page,
        right: Insets.page,
        top: Insets.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Insets.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('onboarding.name_household'), style: text.titleLarge),
          const SizedBox(height: Insets.lg),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: t('onboarding.household_name_hint'),
            ),
          ),
          const SizedBox(height: Insets.lg),
          Text(t('onboarding.currency'), style: text.labelSmall),
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              for (final option in CurrencyOption.all)
                ChoiceChip(
                  label: Text('${option.symbol} ${option.code}'),
                  selected: _currency == option.code,
                  onSelected: (_) => setState(() => _currency = option.code),
                ),
            ],
          ),
          const SizedBox(height: Insets.xl),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              (_name.text.trim(), _currency),
            ),
            child: Text(t('onboarding.create')),
          ),
        ],
      ),
    );
  }
}
