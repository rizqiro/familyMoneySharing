import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/format/failure.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_card.dart';
import '../../data/household_repository.dart';
import '../../models/invite.dart';
import '../../state/providers.dart';

/// Scan the partner's QR code, or type the code by hand.
class JoinPage extends ConsumerStatefulWidget {
  const JoinPage({super.key});

  @override
  ConsumerState<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends ConsumerState<JoinPage> {
  final _code = TextEditingController();
  MobileScannerController? _scanner;

  bool _busy = false;
  bool _scanning = false;
  String? _error;

  /// Camera scanning is only wired up where mobile_scanner has a platform
  /// implementation; elsewhere the typed code is the whole flow.
  bool get _cameraSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void dispose() {
    _code.dispose();
    _scanner?.dispose();
    super.dispose();
  }

  void _startScanning() {
    setState(() {
      _scanning = true;
      _error = null;
      _scanner = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
      );
    });
  }

  void _stopScanning() {
    _scanner?.dispose();
    setState(() {
      _scanner = null;
      _scanning = false;
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;

    await _redeem(raw);
  }

  Future<void> _redeem(String raw) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final repo = ref.read(householdRepositoryProvider);
      final invite = await repo.lookupInvite(raw);
      final profile = ref.read(profileProvider).valueOrNull;
      if (profile == null) throw const HouseholdFailure('Not signed in.');

      final confirmed = await _confirm(invite);
      if (confirmed != true) {
        setState(() => _busy = false);
        return;
      }

      await repo.acceptInvite(invite: invite, joiner: profile);
      if (!mounted) return;

      _stopScanning();
      // The auth gate rebuilds into the shell once the profile updates; this
      // just clears the pairing stack behind it.
      Navigator.of(context).popUntil((route) => route.isFirst);
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

  Future<bool?> _confirm(Invite invite) {
    final t = ref.read(textProvider);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('join.confirm_title')),
        content: Text(t('join.confirm_body', {
          'name': invite.createdByName,
          'household': invite.householdName,
        }),),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t('join.cta_short')),
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

    return Scaffold(
      appBar: AppBar(title: Text(t('join.title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Insets.page),
          children: [
            if (_cameraSupported) ...[
              SoftCard(
                padding: EdgeInsets.zero,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _scanning && _scanner != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            MobileScanner(
                              controller: _scanner!,
                              onDetect: _onDetect,
                              errorBuilder: (context, error, _) => _ScanError(
                                message: error.errorDetails?.message ??
                                    t('join.camera_unavailable'),
                                template:
                                    t('join.still_type', {'message': '@'}),
                              ),
                            ),
                            const _ScannerFrame(),
                          ],
                        )
                      : _ScannerIdle(onStart: _startScanning),
                ),
              ),
              if (_scanning)
                Padding(
                  padding: const EdgeInsets.only(top: Insets.sm),
                  child: TextButton(
                    onPressed: _stopScanning,
                    child: Text(t('join.stop_camera')),
                  ),
                ),
              const SizedBox(height: Insets.xl),
              Row(
                children: [
                  Expanded(child: Divider(color: colors.hairline)),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: Insets.md),
                    child: Text(
                      t('join.or'),
                      style: text.labelSmall?.copyWith(color: colors.inkMuted),
                    ),
                  ),
                  Expanded(child: Divider(color: colors.hairline)),
                ],
              ),
              const SizedBox(height: Insets.xl),
            ],

            Text(t('join.enter_code'), style: text.titleMedium),
            const SizedBox(height: Insets.sm),
            Text(
              t('join.enter_code_blurb'),
              style: text.bodySmall?.copyWith(color: colors.inkSecondary),
            ),
            const SizedBox(height: Insets.lg),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              style: const TextStyle(
                fontSize: 22,
                letterSpacing: 6,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(hintText: 'ABCD2345'),
              onSubmitted: _redeem,
            ),

            if (_error != null) ...[
              const SizedBox(height: Insets.lg),
              ErrorNote(message: _error!),
            ],

            const SizedBox(height: Insets.xl),
            FilledButton(
              onPressed: _busy ? null : () => _redeem(_code.text),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t('join.cta')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerIdle extends ConsumerWidget {
  const _ScannerIdle({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return InkWell(
      onTap: onStart,
      child: Container(
        color: colors.surfaceSunken,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 34, color: colors.inkMuted),
            const SizedBox(height: Insets.md),
            Text(
              ref.watch(textProvider)('join.tap_to_scan'),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colors.inkSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanError extends StatelessWidget {
  const _ScanError({required this.message, required this.template});

  final String message;

  /// The surrounding sentence, with `@` marking where [message] goes. Passed
  /// in already translated because this widget cannot reach providers.
  final String template;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.surfaceSunken,
      padding: const EdgeInsets.all(Insets.lg),
      alignment: Alignment.center,
      child: Text(
        template.replaceAll('@', message),
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: context.colors.inkSecondary),
      ),
    );
  }
}

/// Corner brackets over the camera preview - the only decoration on it.
class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.66,
          heightFactor: 0.66,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2),
              borderRadius: BorderRadius.circular(Radii.card),
            ),
          ),
        ),
      ),
    );
  }
}
