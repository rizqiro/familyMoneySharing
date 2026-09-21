import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_card.dart';
import '../../state/providers.dart';
import '../pairing/invite_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final profile = ref.watch(profileProvider).valueOrNull;
    final household = ref.watch(householdProvider).valueOrNull;
    final partner = ref.watch(partnerProvider);

    if (profile == null || household == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Insets.page,
            Insets.md,
            Insets.page,
            Insets.xxl,
          ),
          children: [
            SoftCard(
              child: Row(
                children: [
                  MemberAvatar(initial: profile.initial, size: 44),
                  const SizedBox(width: Insets.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.displayName, style: text.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          profile.email,
                          style: text.bodySmall
                              ?.copyWith(color: colors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _editName(context, ref, profile.uid,
                        profile.displayName,),
                    child: const Text('Edit'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.xl),

            const SectionHeader(title: 'Partner'),
            if (partner == null)
              SoftCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const InvitePage()),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_add_alt, size: 20, color: colors.ink),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Text('Invite your partner',
                          style: text.bodyLarge,),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: colors.inkMuted,
                    ),
                  ],
                ),
              )
            else
              SoftCard(
                child: Row(
                  children: [
                    MemberAvatar(initial: partner.initial, size: 36),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(partner.displayName, style: text.bodyLarge),
                          const SizedBox(height: 2),
                          Text(
                            partner.email,
                            style: text.bodySmall
                                ?.copyWith(color: colors.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    Tag(
                      label: 'Connected',
                      icon: Icons.link,
                      color: colors.positive,
                      filled: true,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: Insets.xl),

            const SectionHeader(title: 'Household'),
            GroupedCard(
              children: [
                ListTile(
                  title: const Text('Name'),
                  subtitle: Text(household.name),
                  trailing: Icon(Icons.chevron_right, color: colors.inkMuted),
                  onTap: () => _editHouseholdName(context, ref, household.id,
                      household.name,),
                ),
                ListTile(
                  title: const Text('Currency'),
                  subtitle: Text(household.currencyCode),
                  trailing: Icon(Icons.chevron_right, color: colors.inkMuted),
                  onTap: () =>
                      _pickCurrency(context, ref, household.id,
                          household.currencyCode,),
                ),
                ListTile(
                  title: const Text('Month starts on'),
                  subtitle: Text(
                    household.monthStartDay == 1
                        ? 'The 1st (calendar month)'
                        : 'Day ${household.monthStartDay}',
                  ),
                  trailing: Icon(Icons.chevron_right, color: colors.inkMuted),
                  onTap: () => _pickStartDay(context, ref, household.id,
                      household.monthStartDay,),
                ),
              ],
            ),
            const SizedBox(height: Insets.xl),

            const SectionHeader(title: 'Account'),
            GroupedCard(
              children: [
                ListTile(
                  title: const Text('Sign out'),
                  leading: Icon(Icons.logout, color: colors.inkSecondary),
                  onTap: () => ref.read(authRepositoryProvider).signOut(),
                ),
                ListTile(
                  title: Text(
                    'Leave household',
                    style: TextStyle(color: colors.negative),
                  ),
                  leading: Icon(Icons.link_off, color: colors.negative),
                  onTap: () => _confirmLeave(context, ref, household.id,
                      profile.uid,),
                ),
              ],
            ),
            const SizedBox(height: Insets.xl),

            Center(
              child: Text(
                'Family Money',
                style: text.bodySmall?.copyWith(color: colors.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String current,
  ) async {
    final value = await _promptText(
      context,
      title: 'Your name',
      initial: current,
    );
    if (value == null || value.trim().isEmpty) return;
    await ref.read(authRepositoryProvider).updateDisplayName(uid, value);
  }

  Future<void> _editHouseholdName(
    BuildContext context,
    WidgetRef ref,
    String householdId,
    String current,
  ) async {
    final value = await _promptText(
      context,
      title: 'Household name',
      initial: current,
    );
    if (value == null || value.trim().isEmpty) return;
    await ref
        .read(householdRepositoryProvider)
        .updateSettings(householdId: householdId, name: value);
  }

  Future<void> _pickCurrency(
    BuildContext context,
    WidgetRef ref,
    String householdId,
    String current,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final option in CurrencyOption.all)
              ListTile(
                title: Text('${option.symbol}  ${option.code}'),
                trailing: option.code == current
                    ? const Icon(Icons.check, size: 18)
                    : null,
                onTap: () => Navigator.of(context).pop(option.code),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await ref
        .read(householdRepositoryProvider)
        .updateSettings(householdId: householdId, currencyCode: picked);
  }

  Future<void> _pickStartDay(
    BuildContext context,
    WidgetRef ref,
    String householdId,
    int current,
  ) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: Insets.md),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                0,
                Insets.page,
                Insets.md,
              ),
              child: Text(
                'If you budget from payday rather than the 1st, set that day '
                'here. Expenses land in the right month automatically.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            // 28 is the last day every month is guaranteed to have.
            for (var day = 1; day <= 28; day++)
              ListTile(
                dense: true,
                title: Text(day == 1 ? '1st (calendar month)' : 'Day $day'),
                trailing:
                    day == current ? const Icon(Icons.check, size: 18) : null,
                onTap: () => Navigator.of(context).pop(day),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await ref
        .read(householdRepositoryProvider)
        .updateSettings(householdId: householdId, monthStartDay: picked);
  }

  Future<void> _confirmLeave(
    BuildContext context,
    WidgetRef ref,
    String householdId,
    String uid,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this household?'),
        content: const Text(
          'You stop seeing the shared budgets and ledger. Everything stays '
          'with your partner, and you can be invited back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.negative,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref
        .read(householdRepositoryProvider)
        .leave(householdId: householdId, uid: uid);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<String?> _promptText(
    BuildContext context, {
    required String title,
    required String initial,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
