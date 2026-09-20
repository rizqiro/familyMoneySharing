import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_card.dart';
import '../../models/approval.dart';
import '../../state/providers.dart';

/// Where budget allocations get confirmed. Nothing in a shared plan changes
/// silently: the other member either agrees here or says why not.
class InboxPage extends ConsumerWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final inbox = ref.watch(inboxProvider).valueOrNull ?? const [];
    final outbox = ref.watch(outboxProvider).valueOrNull ?? const [];
    final household = ref.watch(householdProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: SafeArea(
        top: false,
        child: inbox.isEmpty && outbox.isEmpty
            ? EmptyState(
                icon: Icons.check_circle_outline,
                title: 'Nothing to confirm',
                message: household != null && !household.isPaired
                    ? 'Once your partner joins, budget allocations you make '
                        'will come here for them to confirm.'
                    : 'When either of you allocates part of a budget, it '
                        'lands here for the other to agree to.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  Insets.page,
                  Insets.md,
                  Insets.page,
                  120,
                ),
                children: [
                  if (inbox.isNotEmpty) ...[
                    const SectionHeader(title: 'Waiting on you'),
                    for (final approval in inbox)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.sm),
                        child: _RequestCard(approval: approval),
                      ),
                    const SizedBox(height: Insets.xl),
                  ],
                  if (outbox.isNotEmpty) ...[
                    const SectionHeader(title: 'Waiting on your partner'),
                    for (final approval in outbox)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.sm),
                        child: _SentCard(approval: approval),
                      ),
                  ],
                  const SizedBox(height: Insets.lg),
                  Text(
                    'Pending allocations still count toward the plan, so the '
                    'numbers reflect what you intend while you sort it out.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.inkMuted),
                  ),
                ],
              ),
      ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({required this.approval});

  final Approval approval;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _busy = false;

  Future<void> _decide(bool approved) async {
    final householdId = ref.read(householdIdProvider);
    if (householdId == null) return;

    var note = '';
    if (!approved) {
      final reason = await _askReason();
      if (reason == null) return;
      note = reason;
    }

    setState(() => _busy = true);
    try {
      await ref.read(approvalRepositoryProvider).decide(
            householdId: householdId,
            approval: widget.approval,
            approved: approved,
            note: note,
          );
      if (mounted) {
        showToast(context, approved ? 'Confirmed' : 'Declined');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline this allocation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Say why (optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final money = ref.watch(moneyProvider);
    final household = ref.watch(householdProvider).valueOrNull;
    final approval = widget.approval;

    final asker = household?.displayNameOf(approval.requestedBy) ?? 'Partner';
    final delta = approval.previousAmount == null
        ? null
        : approval.amount - approval.previousAmount!;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MemberAvatar(
                initial: household
                        ?.member(approval.requestedBy)
                        ?.initial ??
                    asker[0],
                size: 30,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(approval.title, style: text.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(
            approval.summary,
            style: text.bodyMedium?.copyWith(color: colors.inkSecondary),
          ),
          const SizedBox(height: Insets.lg),

          Container(
            padding: const EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: BorderRadius.circular(Radii.field),
            ),
            child: Row(
              children: [
                Text(
                  money.format(approval.amount),
                  style: text.headlineSmall,
                ),
                const Spacer(),
                if (delta != null && delta != 0)
                  Tag(
                    label: '${money.signed(delta)} vs before',
                    color: delta > 0 ? colors.warning : colors.positive,
                    filled: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _decide(false),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _decide(true),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SentCard extends ConsumerWidget {
  const _SentCard({required this.approval});

  final Approval approval;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final money = ref.watch(moneyProvider);
    final household = ref.watch(householdProvider).valueOrNull;

    final partnerName =
        household?.displayNameOf(approval.requestedFor).split(' ').first ??
            'your partner';

    return SoftCard(
      color: colors.surfaceSunken,
      child: Row(
        children: [
          Icon(Icons.schedule, size: 18, color: colors.warning),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(approval.title, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${money.format(approval.amount)} · waiting on '
                  '$partnerName',
                  style: text.bodySmall?.copyWith(color: colors.inkSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Editing the category replaces this request.',
                  style: text.bodySmall?.copyWith(color: colors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
