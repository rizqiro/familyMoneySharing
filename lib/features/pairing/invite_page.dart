import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_card.dart';
import '../../data/household_repository.dart';
import '../../models/invite.dart';
import '../../state/providers.dart';

/// Shows the code the partner scans. Closes itself the moment they join.
class InvitePage extends ConsumerStatefulWidget {
  const InvitePage({super.key});

  @override
  ConsumerState<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends ConsumerState<InvitePage> {
  Invite? _invite;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _mint());
  }

  Future<void> _mint() async {
    final household = ref.read(householdProvider).valueOrNull;
    final profile = ref.read(profileProvider).valueOrNull;
    if (household == null || profile == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final invite = await ref
          .read(householdRepositoryProvider)
          .createInvite(household: household, inviter: profile);
      if (mounted) setState(() => _invite = invite);
    } on HouseholdFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final invite = _invite;

    // Once the partner is in the household, this screen has done its job.
    ref.listen(householdProvider, (previous, next) {
      final household = next.valueOrNull;
      if (household != null && household.isPaired && mounted) {
        Navigator.of(context).maybePop();
        showToast(context, 'You are connected.');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite your partner'),
        actions: [
          if (invite != null)
            IconButton(
              tooltip: 'New code',
              icon: const Icon(Icons.refresh),
              onPressed: _busy ? null : _mint,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Insets.page),
          children: [
            Text(
              'Have them open Family Money, choose "Join my partner", and '
              'point their camera at this.',
              style: text.bodyMedium?.copyWith(color: colors.inkSecondary),
            ),
            const SizedBox(height: Insets.xl),

            if (_busy && invite == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Insets.xxl),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_error != null)
              ErrorNote(message: _error!, onRetry: _mint)
            else if (invite != null) ...[
              Center(
                child: SoftCard(
                  padding: const EdgeInsets.all(Insets.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The QR keeps a white quiet zone in both themes -
                      // scanners need the light-on-dark contrast preserved.
                      Container(
                        padding: const EdgeInsets.all(Insets.md),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(Radii.field),
                        ),
                        child: QrImageView(
                          data: invite.qrPayload,
                          version: QrVersions.auto,
                          size: 212,
                          gapless: true,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF0B0B0B),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF0B0B0B),
                          ),
                        ),
                      ),
                      const SizedBox(height: Insets.xl),
                      Text(
                        'OR TYPE THIS CODE',
                        style:
                            text.labelSmall?.copyWith(color: colors.inkMuted),
                      ),
                      const SizedBox(height: Insets.sm),
                      SelectableText(
                        invite.code,
                        style: text.headlineSmall?.copyWith(letterSpacing: 6),
                      ),
                      const SizedBox(height: Insets.md),
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: invite.code),
                          );
                          if (context.mounted) {
                            showToast(context, 'Code copied');
                          }
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy code'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Insets.xl),
              Row(
                children: [
                  Icon(Icons.schedule, size: 15, color: colors.inkMuted),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      'Single use, and it expires in 24 hours. Anyone with the '
                      'code can join, so share it directly.',
                      style:
                          text.bodySmall?.copyWith(color: colors.inkSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
