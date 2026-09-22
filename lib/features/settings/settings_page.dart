import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/money.dart';
import '../../core/i18n/app_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_card.dart';
import '../../state/providers.dart';
import '../pairing/invite_page.dart';

/// Everything adjustable, in three groups.
///
/// The grouping follows who a setting belongs to:
///
///   * **Partner / Household** - shared. Changing the currency changes it for
///     both of you, because the money is shared.
///   * **Preferences** - yours alone. Language lives here: one of you can read
///     the app in Banjar while the other reads Indonesian.
///   * **Account** - signing out and unlinking.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final household = ref.watch(householdProvider).valueOrNull;
    final partner = ref.watch(partnerProvider);
    final language = ref.watch(languageProvider);

    if (profile == null || household == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(t('settings.title'))),
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
                          style:
                              text.bodySmall?.copyWith(color: colors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _editName(
                      context,
                      ref,
                      profile.uid,
                      profile.displayName,
                    ),
                    child: Text(t('common.edit')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.xl),

            SectionHeader(title: t('settings.partner')),
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
                      child: Text(
                        t('settings.invite_partner'),
                        style: text.bodyLarge,
                      ),
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
                      label: t('settings.connected'),
                      icon: Icons.link,
                      color: colors.positive,
                      filled: true,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: Insets.xl),

            SectionHeader(title: t('settings.household')),
            GroupedCard(
              children: [
                ListTile(
                  title: Text(t('settings.name')),
                  subtitle: Text(household.name),
                  trailing: Icon(Icons.chevron_right, color: colors.inkMuted),
                  onTap: () => _editHouseholdName(
                    context,
                    ref,
                    household.id,
                    household.name,
                  ),
                ),
                ListTile(
                  title: Text(t('settings.currency')),
                  subtitle: Text(household.currencyCode),
                  trailing: Icon(Icons.chevron_right, color: colors.inkMuted),
                  onTap: () => _pickCurrency(
                    context,
                    ref,
                    household.id,
                    household.currencyCode,
                  ),
                ),
                ListTile(
                  title: Text(t('settings.month_starts')),
                  subtitle: Text(
                    household.monthStartDay == 1
                        ? t('settings.month_first')
                        : t('settings.month_day',
                            {'day': '${household.monthStartDay}'}),
                  ),
                  trailing: Icon(Icons.chevron_right, color: colors.inkMuted),
                  onTap: () => _pickStartDay(
                    context,
                    ref,
                    household.id,
                    household.monthStartDay,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.xl),

            // Yours alone, not the household's - hence its own section.
            SectionHeader(title: t('settings.preferences')),
            GroupedCard(
              children: [
                ListTile(
                  leading: Icon(Icons.translate, color: colors.inkSecondary),
                  title: Text(t('settings.language')),
                  subtitle: Text(language.endonym),
                  trailing: Icon(Icons.chevron_right, color: colors.inkMuted),
                  onTap: () => _pickLanguage(context, ref, profile.uid, language),
                ),
              ],
            ),
            const SizedBox(height: Insets.xl),

            SectionHeader(title: t('settings.account')),
            GroupedCard(
              children: [
                ListTile(
                  title: Text(t('auth.sign_out')),
                  leading: Icon(Icons.logout, color: colors.inkSecondary),
                  onTap: () => ref.read(authRepositoryProvider).signOut(),
                ),
                ListTile(
                  title: Text(
                    t('settings.leave'),
                    style: TextStyle(color: colors.negative),
                  ),
                  leading: Icon(Icons.link_off, color: colors.negative),
                  onTap: () => _confirmLeave(
                    context,
                    ref,
                    household.id,
                    profile.uid,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.xl),

            Center(
              child: Text(
                t('auth.app_name'),
                style: text.bodySmall?.copyWith(color: colors.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The language picker.
  ///
  /// Each row shows the language's own name first and the English name
  /// underneath, so someone who has accidentally switched to a language they
  /// cannot read can still find their way back.
  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    String uid,
    AppLanguage current,
  ) async {
    final colors = context.colors;

    final picked = await showModalBottomSheet<AppLanguage>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: Insets.sm),
          children: [
            for (final language in AppLanguage.values)
              ListTile(
                title: Text(language.endonym),
                subtitle: Text(language.englishName),
                trailing: language == current
                    ? Icon(Icons.check, size: 18, color: colors.ink)
                    : null,
                onTap: () => Navigator.of(context).pop(language),
              ),
          ],
        ),
      ),
    );

    // Nothing to do if the sheet was dismissed or the same one was tapped.
    if (picked == null || picked == current) return;

    // Writing to Firestore is all it takes: the profile stream emits, the
    // language provider recomputes, and every screen redraws in the new
    // language. Nothing here has to tell the UI to update.
    await ref.read(authRepositoryProvider).setLanguage(uid, picked);
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String current,
  ) async {
    final t = ref.read(textProvider);
    final value = await _promptText(
      context,
      title: t('settings.your_name'),
      initial: current,
      saveLabel: t('common.save'),
      cancelLabel: t('common.cancel'),
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
    final t = ref.read(textProvider);
    final value = await _promptText(
      context,
      title: t('settings.household_name'),
      initial: current,
      saveLabel: t('common.save'),
      cancelLabel: t('common.cancel'),
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
    final t = ref.read(textProvider);
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
                t('settings.month_blurb'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            // Stops at 28: it is the last day every month is guaranteed to
            // have, so a period can never land on a date that does not exist.
            for (var day = 1; day <= 28; day++)
              ListTile(
                dense: true,
                title: Text(
                  day == 1
                      ? t('settings.month_first')
                      : t('settings.month_day', {'day': '$day'}),
                ),
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
    final t = ref.read(textProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('settings.leave_title')),
        content: Text(t('settings.leave_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.negative,
            ),
            child: Text(t('settings.leave_cta')),
          ),
        ],
      ),
    );
    // `context.mounted` matters after an await: the user may have navigated
    // away while the dialog was open, and using a dead context throws.
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
    required String saveLabel,
    required String cancelLabel,
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
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(saveLabel),
          ),
        ],
      ),
    );
  }
}
