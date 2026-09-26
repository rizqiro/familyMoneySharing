import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/failure.dart';
import '../../core/i18n/app_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_card.dart';
import '../../state/providers.dart';

/// Erasing your account.
///
/// =============================================================================
/// WHY THIS IS A SCREEN AND NOT A DIALOG
/// =============================================================================
/// A dialog is for a decision you have already made. This one has consequences
/// most people have not thought through - that a partner may lose shared
/// records, that nothing comes back - and a dialog that has to explain all that
/// is a dialog nobody reads.
///
/// So it is a page: room to say what happens, in what order, and to ask for a
/// deliberate confirmation rather than a reflex tap.
///
/// =============================================================================
/// WHAT IS UNILATERAL AND WHAT IS NOT
/// =============================================================================
/// **Your account is always yours to delete.** No approval, no waiting, no
/// partner's permission. That is an app-store requirement, but it matters for a
/// better reason: someone leaving a relationship that has gone wrong is exactly
/// the person who most needs this button to work, and requiring their partner
/// to agree would hand the other person a veto over their leaving.
///
/// **The shared records are not yours alone to destroy.** The budgets and the
/// ledger are your partner's history too, possibly the only copy of it. So
/// erasing those is a REQUEST, left behind for whoever remains to accept or
/// refuse - see `Household.eraseRequestedBy`.
class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  final _confirm = TextEditingController();
  bool _alsoEraseShared = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  /// The word that has to be typed out.
  ///
  /// Typing beats a checkbox here. A checkbox can be ticked without reading;
  /// copying a word out takes just long enough to notice you are doing it.
  String _word(AppText t) => t('delete.confirm_word');

  Future<void> _delete() async {
    final t = ref.read(textProvider);

    // Checked first, before anything is looked up. A mistyped word should
    // always get an answer - if the profile has not loaded yet, falling
    // through to a silent return would look like a dead button.
    if (_confirm.text.trim().toUpperCase() != _word(t).toUpperCase()) {
      setState(() => _error = t('delete.err_word', {'word': _word(t)}));
      return;
    }

    // `.future` rather than `.valueOrNull`, and this matters: nothing on this
    // page WATCHES the profile, so reading it here is the first anybody has
    // asked for it. A plain read would come back still-loading and the button
    // would do nothing at all - a dead control with no explanation, on the one
    // screen where that is least acceptable.
    final profile = await ref.read(profileProvider.future);
    final household = await ref.read(householdProvider.future);
    if (profile == null) {
      setState(() => _error = t('error.unknown'));
      return;
    }
    if (!mounted) return;

    final sure = await _lastChance(t);
    if (sure != true) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Household first, account second. The other order signs you out
      // half-way through and the rules then refuse everything that is left.
      if (household != null) {
        await ref.read(householdRepositoryProvider).departForDeletion(
              householdId: household.id,
              uid: profile.uid,
              displayName: profile.displayName,
              askToEraseShared: _alsoEraseShared,
            );
      }
      await ref.read(authRepositoryProvider).deleteAccount();
      // Signing out is what the auth gate reacts to; there is no screen left
      // to navigate back to.
    } catch (e) {
      if (mounted) {
        setState(() => _error = describeFailure(e, ref.read(textProvider)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _lastChance(AppText t) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('delete.final_title')),
        content: Text(t('delete.final_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('delete.keep_account')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.accentDeep,
            ),
            child: Text(t('delete.confirm_cta')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
    final household = ref.watch(householdProvider).valueOrNull;
    final partner = ref.watch(partnerProvider);
    final partnerName = partner?.displayName.split(' ').first;

    return Scaffold(
      appBar: AppBar(title: Text(t('delete.title'))),
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
            // ------------------------------------------------- the pause
            //
            // Deliberately the first thing on the page, before any of the
            // mechanics. Most people who reach this screen in a shared
            // household are not here because of the app.
            _TalkFirstCard(partnerName: partnerName),
            const SizedBox(height: Insets.xl),

            SectionHeader(title: t('delete.what_happens')),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Point(text: t('delete.point_profile')),
                  _Point(text: t('delete.point_signin')),
                  if (partnerName == null)
                    _Point(text: t('delete.point_solo'), emphasis: true)
                  else ...[
                    _Point(
                      text: t('delete.point_leave', {'name': partnerName}),
                    ),
                    _Point(
                      text: t('delete.point_partner_keeps',
                          {'name': partnerName},),
                    ),
                  ],
                  _Point(text: t('delete.point_forever'), emphasis: true),
                ],
              ),
            ),

            // -------------------------------------- the two-party request
            if (partnerName != null && household != null) ...[
              const SizedBox(height: Insets.xl),
              SectionHeader(title: t('delete.shared_title')),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('delete.shared_blurb', {'name': partnerName}),
                      style:
                          text.bodyMedium?.copyWith(color: colors.inkSecondary),
                    ),
                    const SizedBox(height: Insets.md),
                    // A switch rather than a second button: it is a modifier on
                    // the thing you are already doing, not another action.
                    SwitchListTile.adaptive(
                      value: _alsoEraseShared,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _alsoEraseShared = v),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        t('delete.ask_erase', {'name': partnerName}),
                        style: text.bodyMedium,
                      ),
                      subtitle: Text(
                        t('delete.ask_erase_note', {'name': partnerName}),
                        style:
                            text.bodySmall?.copyWith(color: colors.inkMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ------------------------------------------------- confirming
            const SizedBox(height: Insets.xl),
            SectionHeader(title: t('delete.confirm_title')),
            Text(
              t('delete.confirm_blurb', {'word': _word(t)}),
              style: text.bodyMedium?.copyWith(color: colors.inkSecondary),
            ),
            const SizedBox(height: Insets.md),
            TextField(
              controller: _confirm,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: _word(t)),
            ),

            if (_error != null) ...[
              const SizedBox(height: Insets.lg),
              ErrorNote(message: _error!),
            ],

            const SizedBox(height: Insets.xl),
            FilledButton(
              onPressed: _busy ? null : _delete,
              style: FilledButton.styleFrom(
                backgroundColor: colors.accentDeep,
                foregroundColor: Colors.white,
              ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(t('delete.cta')),
            ),
            const SizedBox(height: Insets.md),
            OutlinedButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text(t('delete.keep_account')),
            ),
          ],
        ),
      ),
    );
  }
}

/// The message asking someone to talk before they delete.
///
/// Written to be read by a person having a bad week, so: no lecture, no
/// assumption about what is wrong, and an exit that is not the app's business.
/// It says its piece once and gets out of the way - the delete button below
/// still works exactly as it did.
class _TalkFirstCard extends ConsumerWidget {
  const _TalkFirstCard({required this.partnerName});

  final String? partnerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);

    // Nobody to fall out with, so the message would be noise.
    final name = partnerName;
    if (name == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.favorite_outline,
                size: 18,
                color: colors.inkSecondary,
              ),
              const SizedBox(width: Insets.sm),
              Text(t('delete.talk_title'), style: text.titleMedium),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(
            t('delete.talk_body', {'name': name}),
            style: text.bodyMedium?.copyWith(
              color: colors.inkSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.text, this.emphasis = false});

  final String text;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            emphasis ? Icons.warning_amber_rounded : Icons.remove,
            size: 16,
            color: emphasis ? colors.accentDeep : colors.inkMuted,
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: emphasis ? colors.accentDeep : colors.ink,
                    fontWeight: emphasis ? FontWeight.w500 : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
