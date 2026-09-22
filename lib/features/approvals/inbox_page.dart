import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_card.dart';
import '../../models/approval.dart';
import '../../models/money_request.dart';
import '../../state/providers.dart';

/// Where decisions get made. Two kinds of item land here:
///
///   * **Category allocations** - the budget's controller carved it up, and the
///     other member confirms the split before it counts as agreed.
///   * **Money requests** - the other member wants some of a budget you
///     control moved to one of theirs.
///
/// Both are shown together because to the person reading them they are the same
/// job: something is waiting on you. They stay separate collections underneath
/// because the fields and the rules differ - see `FirestoreRefs.moneyRequests`.
class InboxPage extends ConsumerWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final household = ref.watch(householdProvider).valueOrNull;

    // `?? const []` turns "still loading" into "nothing yet", so the page can
    // render immediately instead of flashing a spinner for a few hundred ms.
    final approvals = ref.watch(inboxProvider).valueOrNull ?? const [];
    final moneyIn = ref.watch(moneyInboxProvider).valueOrNull ?? const [];
    final sentApprovals = ref.watch(outboxProvider).valueOrNull ?? const [];
    final sentMoney = ref.watch(moneyOutboxProvider).valueOrNull ?? const [];

    final nothingWaiting = approvals.isEmpty &&
        moneyIn.isEmpty &&
        sentApprovals.isEmpty &&
        sentMoney.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: SafeArea(
        top: false,
        child: nothingWaiting
            ? EmptyState(
                icon: Icons.check_circle_outline,
                title: 'Nothing to confirm',
                message: household != null && !household.isPaired
                    ? 'Once your partner joins, budget allocations and money '
                        'requests will come here.'
                    : 'Allocations to agree to, and requests to move money, '
                        'both land here.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  Insets.page,
                  Insets.md,
                  Insets.page,
                  120,
                ),
                children: [
                  if (moneyIn.isNotEmpty || approvals.isNotEmpty) ...[
                    const SectionHeader(title: 'Waiting on you'),
                    // Money first: it is blocking someone from spending, which
                    // is more urgent than agreeing to a plan.
                    for (final request in moneyIn)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.sm),
                        child: _MoneyRequestCard(request: request),
                      ),
                    for (final approval in approvals)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.sm),
                        child: _AllocationCard(approval: approval),
                      ),
                    const SizedBox(height: Insets.xl),
                  ],
                  if (sentMoney.isNotEmpty || sentApprovals.isNotEmpty) ...[
                    const SectionHeader(title: 'Waiting on your partner'),
                    for (final request in sentMoney)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.sm),
                        child: _SentMoneyCard(request: request),
                      ),
                    for (final approval in sentApprovals)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.sm),
                        child: _SentAllocationCard(approval: approval),
                      ),
                  ],
                  const SizedBox(height: Insets.lg),
                  Text(
                    'Pending allocations still count toward the plan, so the '
                    'numbers reflect what you intend while you sort it out. '
                    'Money only moves once a request is approved.',
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

/// "Your partner wants Rp X out of a budget you control."
///
/// Approving flips this request's status. It does NOT edit either budget - the
/// transfer is applied when the month is added up, in `PeriodSummary.build`.
class _MoneyRequestCard extends ConsumerStatefulWidget {
  const _MoneyRequestCard({required this.request});

  final MoneyRequest request;

  @override
  ConsumerState<_MoneyRequestCard> createState() => _MoneyRequestCardState();
}

class _MoneyRequestCardState extends ConsumerState<_MoneyRequestCard> {
  bool _busy = false;

  Future<void> _decide(bool approved) async {
    final householdId = ref.read(householdIdProvider);
    if (householdId == null) return;

    var note = '';
    if (!approved) {
      final reason = await _askReason(context);
      // null means the dialog was dismissed rather than confirmed, so nothing
      // should happen at all.
      if (reason == null) return;
      note = reason;
    }

    setState(() => _busy = true);
    try {
      await ref.read(moneyRequestRepositoryProvider).decide(
            householdId: householdId,
            request: widget.request,
            approved: approved,
            note: note,
          );
      if (mounted) {
        showToast(context, approved ? 'Money moved' : 'Declined');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final money = ref.watch(moneyProvider);
    final summary = ref.watch(summaryProvider);
    final request = widget.request;

    // What the source budget has left, so the decision can be made without
    // leaving the screen to go and look.
    final sources = summary.monthly
        .where((b) => b.budget.id == request.fromBudgetId)
        .toList();
    final remaining = sources.isEmpty ? null : sources.first.remaining;
    final afterwards = remaining == null ? null : remaining - request.amount;
    final tooMuch = afterwards != null && afterwards < 0;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MemberAvatar(
                initial: request.requestedByName.isEmpty
                    ? '?'
                    : request.requestedByName[0].toUpperCase(),
                size: 30,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  request.reason.isEmpty ? 'Money request' : request.reason,
                  style: text.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(
            '${request.requestedByName.split(' ').first} is asking for money '
            'out of ${request.fromBudgetName}, into ${request.toBudgetName}.',
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
                Expanded(
                  child: Text(
                    money.format(request.amount),
                    style: text.headlineSmall,
                  ),
                ),
                if (afterwards != null)
                  Tag(
                    label: tooMuch
                        ? 'More than you have'
                        : 'Leaves ${money.compact(afterwards)}',
                    color: tooMuch ? colors.negative : colors.inkSecondary,
                    filled: tooMuch,
                  ),
              ],
            ),
          ),

          if (tooMuch) ...[
            const SizedBox(height: Insets.md),
            Text(
              'Approving would put ${request.fromBudgetName} over budget.',
              style: text.bodySmall?.copyWith(color: colors.negative),
            ),
          ],

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
                      : const Text('Send money'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Your partner split a budget this way - do you agree?"
class _AllocationCard extends ConsumerStatefulWidget {
  const _AllocationCard({required this.approval});

  final Approval approval;

  @override
  ConsumerState<_AllocationCard> createState() => _AllocationCardState();
}

class _AllocationCardState extends ConsumerState<_AllocationCard> {
  bool _busy = false;

  Future<void> _decide(bool approved) async {
    final householdId = ref.read(householdIdProvider);
    if (householdId == null) return;

    var note = '';
    if (!approved) {
      final reason = await _askReason(context);
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final money = ref.watch(moneyProvider);
    final household = ref.watch(householdProvider).valueOrNull;
    final approval = widget.approval;

    final asker = household?.displayNameOf(approval.requestedBy) ?? 'Partner';

    // Only set when an already-agreed allocation was changed, so the card can
    // show what moved rather than just the new figure.
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
                initial: household?.member(approval.requestedBy)?.initial ??
                    asker[0],
                size: 30,
              ),
              const SizedBox(width: Insets.md),
              Expanded(child: Text(approval.title, style: text.titleMedium)),
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
                Expanded(
                  child: Text(
                    money.format(approval.amount),
                    style: text.headlineSmall,
                  ),
                ),
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

/// A money request you sent, still unanswered. Withdrawable, because unlike a
/// category allocation it leaves nothing half-finished behind.
class _SentMoneyCard extends ConsumerWidget {
  const _SentMoneyCard({required this.request});

  final MoneyRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final money = ref.watch(moneyProvider);
    final household = ref.watch(householdProvider).valueOrNull;

    final partnerName =
        household?.displayNameOf(request.requestedFor).split(' ').first ??
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
                Text(
                  request.reason.isEmpty ? 'Money request' : request.reason,
                  style: text.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${money.format(request.amount)} from '
                  '${request.fromBudgetName} · waiting on $partnerName',
                  style: text.bodySmall?.copyWith(color: colors.inkSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              final householdId = ref.read(householdIdProvider);
              if (householdId == null) return;
              ref
                  .read(moneyRequestRepositoryProvider)
                  .withdraw(householdId, request.id);
            },
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
  }
}

/// An allocation you sent, still unanswered.
///
/// No withdraw button: deleting the request would leave its category stuck
/// pending forever with nothing to resolve it. Editing the category supersedes
/// the old request instead - see `CategoryRepository.update`.
class _SentAllocationCard extends ConsumerWidget {
  const _SentAllocationCard({required this.approval});

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

/// Shared "why not?" prompt.
///
/// Returns the typed reason, or null if the dialog was dismissed. That
/// distinction matters: empty string means "declined without saying why",
/// null means "changed my mind about declining".
Future<String?> _askReason(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Decline'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Say why (optional)'),
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
