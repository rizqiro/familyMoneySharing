import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/soft_card.dart';
import '../../models/money_request.dart';
import '../../models/spend_category.dart';
import '../../state/providers.dart';

/// What happened to the money you asked for, and to the money you were asked
/// for.
///
/// =============================================================================
/// WHY REFUSALS ARE IN HERE TOO
/// =============================================================================
/// A history that only shows the money that moved answers the wrong question.
/// "Did I ever ask for that?" and "why didn't it arrive?" are the things people
/// actually come looking for, and both are answered by a row that says *no*,
/// with the reason the other person typed.
///
/// So every decided request is listed, in both directions and with all three
/// outcomes. Requests still waiting are deliberately left out: they are already
/// on the Inbox screen as cards with buttons, and listing them twice would make
/// the same item look like two.
class TransferHistory extends ConsumerWidget {
  const TransferHistory({
    super.key,
    required this.requests,
    this.budgetId,
    this.limit,
  });

  final List<MoneyRequest> requests;

  /// When set, each row is described from this budget's point of view: money
  /// that left it, or money that arrived in it.
  final String? budgetId;

  /// Show at most this many. The budget screen shows a handful; the history
  /// screen shows the lot.
  final int? limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    // Decided only - see the note above.
    final decided = requests.where((r) => !r.isPending).toList();
    if (decided.isEmpty) return const SizedBox.shrink();

    final shown = limit == null ? decided : decided.take(limit!).toList();

    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 60, color: colors.hairline),
            _TransferRow(request: shown[i], budgetId: budgetId),
          ],
        ],
      ),
    );
  }
}

class _TransferRow extends ConsumerWidget {
  const _TransferRow({required this.request, required this.budgetId});

  final MoneyRequest request;
  final String? budgetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
    final money = ref.watch(moneyProvider);
    final uid = ref.watch(currentUidProvider);
    final locale = ref.watch(dateLocaleProvider);

    // Which way this row runs, from the point of view of whoever is reading.
    //
    // On a budget screen that is decided by the budget: money left it or
    // arrived in it. Everywhere else it is decided by the person: you asked, or
    // you were asked.
    final incoming = budgetId != null
        ? request.toBudgetId == budgetId
        : request.wasAskedBy(uid);

    final approved = request.isApproved;

    // The other party: whoever gave it when the money arrived here, whoever
    // got it when the money left.
    final partner = incoming ? request.requestedFor : request.requestedBy;

    // On a budget screen you can be looking at a row whose other party is
    // yourself - your partner's budget paying into yours. "Gave it to You"
    // is what that row means; "Gave it to Rizqi" about your own money is not.
    final partnerName = partner == uid
        ? t('common.you')
        : (ref
                .watch(householdProvider)
                .valueOrNull
                ?.displayNameOf(partner)
                .split(' ')
                .first ??
            t('common.partner'));

    final title = switch ((incoming, approved)) {
      (true, true) => t('history.received_from', {'name': partnerName}),
      (true, false) => t('history.refused_by', {'name': partnerName}),
      (false, true) => t('history.gave_to', {'name': partnerName}),
      (false, false) => t('history.you_refused', {'name': partnerName}),
    };

    // A rejected transfer moved nothing, so its amount is greyed rather than
    // coloured: the figure is what was asked for, not what changed hands.
    final tone = !approved
        ? colors.inkMuted
        : (incoming ? colors.positive : colors.ink);

    final detail = [
      if (request.reason.isNotEmpty) request.reason,
      // Which category it came out of, when the approver had to name one. This
      // is the line that explains why a category shrank.
      if (approved && request.hasSourceCategory)
        t('history.out_of', {'category': request.fromCategoryName}),
      if (!approved && request.decisionNote.isNotEmpty) request.decisionNote,
      if (request.decidedAt != null)
        DateFormat.MMMd(locale).format(request.decidedAt!),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.md,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: approved
                  ? (incoming ? colors.positive : colors.accent)
                      .withValues(alpha: 0.12)
                  : colors.surfaceSunken,
              shape: BoxShape.circle,
            ),
            child: Icon(
              // The arrow says the direction and the cross says it never
              // happened, so neither reading depends on the colour.
              !approved
                  ? Icons.close
                  : (incoming ? Icons.south_west : Icons.north_east),
              size: 16,
              color: approved
                  ? (incoming ? colors.positive : colors.accent)
                  : colors.inkMuted,
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyLarge,
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        text.bodySmall?.copyWith(color: colors.inkSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money.format(request.amount),
                style: text.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: tone,
                  // A refused amount is struck through: it is the clearest way
                  // to say "this number did not happen" without a second line.
                  decoration: approved ? null : TextDecoration.lineThrough,
                ),
              ),
              if (!approved)
                Text(
                  t(AllocationStatus.rejected.labelKey),
                  style: text.bodySmall?.copyWith(color: colors.inkMuted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
