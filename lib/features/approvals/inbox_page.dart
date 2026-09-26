import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/format/failure.dart';
import '../../core/format/money.dart';
import '../../models/approval.dart';
import '../../models/household.dart';
import '../../models/money_request.dart';
import '../../state/period_summary.dart';
import '../../state/providers.dart';
import '../money/transfer_history.dart';

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

    // Every decided request this month, both directions. Kept out of the
    // "nothing waiting" test on purpose: an empty inbox with a month of history
    // under it is not an empty screen.
    final history = ref
        .watch(summaryProvider)
        .transfers
        .where((r) => !r.isPending)
        .toList();

    final eraseAsked = household?.hasEraseRequest ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(t('inbox.title'))),
      body: SafeArea(
        top: false,
        child: nothingWaiting && history.isEmpty && !eraseAsked
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
                  // Top of the list whatever else is waiting: somebody has
                  // left and is asking for the shared records to go too. It is
                  // the only irreversible thing on this screen.
                  if (household != null && household.hasEraseRequest) ...[
                    _EraseRequestCard(household: household),
                    const SizedBox(height: Insets.xl),
                  ],
                  if (nothingWaiting)
                    EmptyState(
                      icon: Icons.check_circle_outline,
                      compact: true,
                      title: t('inbox.empty'),
                      message: t('inbox.empty_blurb'),
                    ),
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
                  if (history.isNotEmpty) ...[
                    const SizedBox(height: Insets.xl),
                    SectionHeader(title: t('history.title')),
                    TransferHistory(requests: history),
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

    // =========================================================================
    // WHERE THE MONEY COMES FROM
    // =========================================================================
    // A budget with money still unallocated can grant a request out of that
    // slack and nothing else changes. A budget whose every rupiah is already
    // carved into categories cannot: granting it anyway would leave the
    // categories adding up to more than the budget holds - the exact state the
    // category editor refuses to create.
    //
    // So when the slack is too small, the approver names the category it comes
    // out of, and that category's allocation shrinks by the amount.
    var fromCategoryId = '';
    var fromCategoryName = '';
    if (approved) {
      final source = _sourceView();
      final short = source != null && source.unallocated < widget.request.amount;
      if (short) {
        final picked = await _askSourceCategory(source);
        if (picked == null) return;
        fromCategoryId = picked.category.id;
        fromCategoryName = picked.category.name;
      }
    }

    setState(() => _busy = true);
    try {
      await ref.read(moneyRequestRepositoryProvider).decide(
            householdId: householdId,
            request: widget.request,
            approved: approved,
            note: note,
            fromCategoryId: fromCategoryId,
            fromCategoryName: fromCategoryName,
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

  /// The source budget as the month sees it, or null if it has gone.
  BudgetView? _sourceView() {
    final matches = ref
        .read(summaryProvider)
        .monthly
        .where((b) => b.budget.id == widget.request.fromBudgetId);
    return matches.isEmpty ? null : matches.first;
  }

  /// Asks which category to take the money out of.
  ///
  /// Categories that do not hold enough are listed but cannot be chosen -
  /// hiding them would leave you staring at a short list wondering where the
  /// rest went, and the amount each one holds is exactly what you need to see
  /// to make the choice.
  Future<CategoryView?> _askSourceCategory(BudgetView source) async {
    final t = ref.read(textProvider);
    final money = ref.read(moneyProvider);
    final amount = widget.request.amount;
    final candidates =
        source.categories.where((c) => c.allocated > 0).toList();

    if (candidates.isEmpty) {
      showToast(context, t('inbox.no_categories_to_take_from'));
      return null;
    }

    return showModalBottomSheet<CategoryView>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.page),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('inbox.take_from_title'),
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: Insets.xs),
              Text(
                t('inbox.take_from_blurb', {
                  'amount': money.format(amount),
                  'budget': source.budget.name,
                }),
                style: Theme.of(sheetContext)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: sheetContext.colors.inkSecondary),
              ),
              const SizedBox(height: Insets.lg),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final c in candidates)
                        _SourceCategoryRow(
                          view: c,
                          money: money,
                          enough: c.allocated >= amount,
                          shortfallLabel: t('inbox.only_has', {
                            'amount': money.format(c.allocated),
                          }),
                          onTap: () =>
                              Navigator.of(sheetContext).pop(c),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Insets.md),
              OutlinedButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(t('common.cancel')),
              ),
            ],
          ),
        ),
      ),
    );
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

    // Nothing spare means the money has to come out of a named category, and
    // the sheet will ask which one.
    final needsCategory =
        sources.isNotEmpty && sources.first.unallocated < request.amount;

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

          // Said before the button rather than after it, so agreeing does not
          // spring an unexpected second question.
          if (!tooMuch && needsCategory) ...[
            const SizedBox(height: Insets.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.call_split, size: 15, color: colors.inkSecondary),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    t('inbox.all_allocated', {
                      'budget': request.fromBudgetName,
                    }),
                    style:
                        text.bodySmall?.copyWith(color: colors.inkSecondary),
                  ),
                ),
              ],
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

/// One row in the "which category does this come out of?" sheet.
///
/// A category that cannot cover the amount is shown greyed with what it does
/// hold, rather than hidden. Hiding it would raise the question the row
/// answers: "where did Groceries go?"
class _SourceCategoryRow extends StatelessWidget {
  const _SourceCategoryRow({
    required this.view,
    required this.money,
    required this.enough,
    required this.shortfallLabel,
    required this.onTap,
  });

  final CategoryView view;
  final Money money;
  final bool enough;
  final String shortfallLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Opacity(
      opacity: enough ? 1 : 0.45,
      child: ListTile(
        // A null onTap is what makes a ListTile unselectable, and it greys the
        // ripple too - no need to fake a disabled state.
        onTap: enough ? onTap : null,
        contentPadding: EdgeInsets.zero,
        leading: Text(
          view.category.emoji,
          style: const TextStyle(fontSize: 20),
        ),
        title: Text(view.category.name, style: text.bodyLarge),
        subtitle: Text(
          enough
              ? money.format(view.allocated)
              : shortfallLabel,
          style: text.bodySmall?.copyWith(color: colors.inkSecondary),
        ),
        trailing: enough
            ? Icon(Icons.chevron_right, size: 20, color: colors.inkMuted)
            : null,
      ),
    );
  }
}

/// "Your partner deleted their account and asked for everything to go."
///
/// =============================================================================
/// WHY THIS IS A CHOICE AND NOT A NOTIFICATION
/// =============================================================================
/// The person who left has already gone; their account no longer exists. What
/// is left is a household full of budgets and a year of ledger entries that
/// belong to both of them - and now, in practice, only to whoever is reading
/// this.
///
/// Honouring the request destroys that. Refusing keeps it. Neither is obviously
/// right, which is exactly why the app must not pick: it is the last thing the
/// two of them will decide together, and the one still here gets the say.
///
/// Refusing is the safe default and the left-hand button. Erasing is styled as
/// the destructive action it is, and asks once more.
class _EraseRequestCard extends ConsumerStatefulWidget {
  const _EraseRequestCard({required this.household});

  final Household household;

  @override
  ConsumerState<_EraseRequestCard> createState() => _EraseRequestCardState();
}

class _EraseRequestCardState extends ConsumerState<_EraseRequestCard> {
  bool _busy = false;

  Future<void> _decide(bool erase) async {
    final t = ref.read(textProvider);
    final repo = ref.read(householdRepositoryProvider);
    final id = widget.household.id;

    if (erase) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t('erase.confirm_title')),
          content: Text(t('erase.confirm_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t('common.cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.accentDeep,
              ),
              child: Text(t('erase.confirm_cta')),
            ),
          ],
        ),
      );
      if (sure != true) return;
    }

    setState(() => _busy = true);
    try {
      if (erase) {
        await repo.confirmErase(id);
        // Everything they shared is gone, including the household this screen
        // was reading from. The auth gate drops them back to the welcome
        // screen on the next frame.
      } else {
        await repo.declineErase(id);
        if (mounted) showToast(context, t('erase.kept'));
      }
    } catch (e) {
      if (mounted) {
        showToast(context, describeFailure(e, ref.read(textProvider)));
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

    final who = widget.household.eraseRequestedByName.isEmpty
        ? t('common.partner')
        : widget.household.eraseRequestedByName.split(' ').first;

    return SoftCard(
      color: colors.accentSoft,
      border: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.delete_forever_outlined,
                size: 20,
                color: colors.onAccentSoft,
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  t('erase.title', {'name': who}),
                  style: text.titleMedium
                      ?.copyWith(color: colors.onAccentSoft),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(
            t('erase.body', {'name': who}),
            style: text.bodyMedium
                ?.copyWith(color: colors.onAccentSoft, height: 1.45),
          ),
          const SizedBox(height: Insets.lg),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _decide(false),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.ink,
                    minimumSize: const Size(0, 46),
                  ),
                  child: Text(t('erase.keep')),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _decide(true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.onAccentSoft,
                    side: BorderSide(color: colors.onAccentSoft),
                    minimumSize: const Size(0, 46),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(t('erase.erase')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
