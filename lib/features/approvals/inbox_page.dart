import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_text.dart';
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
    final t = ref.watch(textProvider);
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
      appBar: AppBar(title: Text(t('inbox.title'))),
      body: SafeArea(
        top: false,
        child: nothingWaiting
            ? EmptyState(
                icon: Icons.check_circle_outline,
                title: t('inbox.empty'),
                message: household != null && !household.isPaired
                    ? t('inbox.empty_unpaired')
                    : t('inbox.empty_blurb'),
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
                    SectionHeader(title: t('inbox.waiting_on_you')),
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
                    SectionHeader(title: t('inbox.waiting_on_partner')),
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
                    t('inbox.note'),
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
      final reason = await _askReason(context, ref.read(textProvider));
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
        final t = ref.read(textProvider);
        showToast(
          context,
          t(approved ? 'inbox.money_moved' : 'inbox.declined'),
        );
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
                  request.reason.isEmpty
                      ? t('inbox.money_request')
                      : request.reason,
                  style: text.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(
            t('inbox.asking_for', {
              'name': request.requestedByName.split(' ').first,
              'from': request.fromBudgetName,
              'to': request.toBudgetName,
            }),
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
                        ? t('inbox.more_than_you_have')
                        : t('inbox.leaves',
                            {'amount': money.compact(afterwards)},),
                    color: tooMuch ? colors.negative : colors.inkSecondary,
                    filled: tooMuch,
                  ),
              ],
            ),
          ),

          if (tooMuch) ...[
            const SizedBox(height: Insets.md),
            Text(
              t('inbox.would_go_over', {'budget': request.fromBudgetName}),
              style: text.bodySmall?.copyWith(color: colors.negative),
            ),
          ],

          const SizedBox(height: Insets.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _decide(false),
                  child: Text(t('common.decline')),
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
                      : Text(t('inbox.send_money')),
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
      final reason = await _askReason(context, ref.read(textProvider));
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
        final t = ref.read(textProvider);
        showToast(
          context,
          t(approved ? 'inbox.confirmed' : 'inbox.declined'),
        );
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
                    label: t('inbox.vs_before',
                        {'amount': money.signed(delta)},),
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
                  child: Text(t('common.decline')),
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
                      : Text(t('common.confirm')),
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
    final t = ref.watch(textProvider);
    final money = ref.watch(moneyProvider);
    final household = ref.watch(householdProvider).valueOrNull;

    final partnerName =
        household?.displayNameOf(request.requestedFor).split(' ').first ??
            t('common.partner');

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
                  request.reason.isEmpty
                      ? t('inbox.money_request')
                      : request.reason,
                  style: text.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  t('inbox.waiting_from', {
                    'amount': money.format(request.amount),
                    'budget': request.fromBudgetName,
                    'name': partnerName,
                  }),
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
            child: Text(t('inbox.withdraw')),
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
    final t = ref.watch(textProvider);
    final money = ref.watch(moneyProvider);
    final household = ref.watch(householdProvider).valueOrNull;

    final partnerName =
        household?.displayNameOf(approval.requestedFor).split(' ').first ??
            t('common.partner');

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
                  t('inbox.waiting_amount', {
                    'amount': money.format(approval.amount),
                    'name': partnerName,
                  }),
                  style: text.bodySmall?.copyWith(color: colors.inkSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  t('inbox.editing_replaces'),
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
Future<String?> _askReason(BuildContext context, AppText t) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(t('inbox.decline_title')),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: t('inbox.decline_hint')),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('common.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(t('common.decline')),
        ),
      ],
    ),
  );
}
