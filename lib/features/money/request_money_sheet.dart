import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../models/budget.dart';
import '../../models/money_request.dart';
import '../../models/spend_category.dart';
import '../../state/period_summary.dart';
import '../../state/providers.dart';

/// Opens the "ask my partner for money" sheet.
///
/// A top-level function rather than a method, so any screen can call
/// `showRequestMoneySheet(context)` without importing the widget class itself.
///
/// `showModalBottomSheet` is Flutter's built-in sliding panel. `isScrollControlled:
/// true` lets it grow past half the screen, which it needs to once the keyboard
/// is up.
Future<void> showRequestMoneySheet(
  BuildContext context, {
  BudgetView? fromBudget,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => RequestMoneySheet(initialFrom: fromBudget),
  );
}

/// Asks the controller of another budget to move some of it across.
///
/// Nothing is transferred here. Sending creates a pending [MoneyRequest]; the
/// money only moves once the other person approves, and even then it moves by
/// arithmetic rather than by editing either budget. See [MoneyRequest].
///
/// `ConsumerStatefulWidget` = a widget that BOTH keeps local state (what you
/// have typed so far) and reads providers. Plain `StatefulWidget` cannot reach
/// Riverpod; plain `ConsumerWidget` cannot keep state.
class RequestMoneySheet extends ConsumerStatefulWidget {
  const RequestMoneySheet({super.key, this.initialFrom});

  final BudgetView? initialFrom;

  @override
  ConsumerState<RequestMoneySheet> createState() => _RequestMoneySheetState();
}

class _RequestMoneySheetState extends ConsumerState<RequestMoneySheet> {
  /// Controllers own the text in a field and let us read it on submit. They
  /// hold native resources, so each one must be disposed - see [dispose].
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _newBudgetName = TextEditingController();

  String? _fromBudgetId;
  String? _toBudgetId;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // initState runs once when the widget is first created. Good place for
    // starting values; it must not read providers that might change.
    _fromBudgetId = widget.initialFrom?.budget.id;
  }

  @override
  void dispose() {
    // Forgetting these is the most common memory leak in a Flutter app.
    _amount.dispose();
    _reason.dispose();
    _newBudgetName.dispose();
    super.dispose();
  }

  /// Validates, optionally creates a destination budget, then sends.
  ///
  /// `async`/`await` here reads top to bottom but does not block the UI: at each
  /// `await` the function pauses and Flutter carries on drawing frames.
  Future<void> _send({
    required List<BudgetView> theirBudgets,
    required List<BudgetView> myBudgets,
  }) async {
    final householdId = ref.read(householdIdProvider);
    final profile = ref.read(profileProvider).valueOrNull;
    final household = ref.read(householdProvider).valueOrNull;
    if (householdId == null || profile == null || household == null) return;

    final source = _findBudget(theirBudgets, _fromBudgetId);
    if (source == null) {
      setState(() => _error = ref.read(textProvider)('request.err_source'));
      return;
    }

    final amount = Money.parseInput(_amount.text, household.currencyCode);
    if (amount == null || amount <= 0) {
      setState(() => _error = ref.read(textProvider)('request.err_amount'));
      return;
    }
    if (amount > source.remaining) {
      setState(
        () => _error = ref.read(textProvider)('request.err_too_much', {
          'amount': ref.read(moneyProvider).format(source.remaining),
          'budget': source.budget.name,
        }),
      );
      return;
    }

    // The destination has to be a budget the requester controls - that is what
    // keeps "you never spend from someone else's budget" true after the
    // transfer. Someone with no budget yet names one here and it is created
    // first.
    final needsNewBudget = myBudgets.isEmpty;
    if (needsNewBudget && _newBudgetName.text.trim().isEmpty) {
      setState(() => _error = ref.read(textProvider)('request.err_name'));
      return;
    }
    if (!needsNewBudget && _toBudgetId == null) {
      setState(
          () => _error = ref.read(textProvider)('request.err_destination'),);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final period = ref.read(selectedPeriodProvider);
      var destinationId = _toBudgetId;
      var destinationName = _findBudget(myBudgets, _toBudgetId)?.budget.name;

      if (needsNewBudget) {
        destinationName = _newBudgetName.text.trim();
        // Starts at zero: the approved transfer is what gives it money. Creating
        // a budget is always allowed - it is spending from someone else's that
        // is not.
        destinationId = await ref.read(budgetRepositoryProvider).create(
              householdId,
              Budget(
                id: '',
                name: destinationName,
                kind: BudgetKind.monthly,
                amount: 0,
                controllerId: profile.uid,
                period: period.key,
                targetDate: null,
                note: '',
                archived: false,
                createdBy: profile.uid,
                createdAt: null,
              ),
            );
      }

      await ref.read(moneyRequestRepositoryProvider).send(
            householdId,
            MoneyRequest(
              id: '',
              fromBudgetId: source.budget.id,
              fromBudgetName: source.budget.name,
              toBudgetId: destinationId!,
              toBudgetName: destinationName ?? 'your budget',
              amount: amount,
              reason: _reason.text.trim(),
              period: period.key,
              requestedBy: profile.uid,
              requestedByName: profile.displayName,
              requestedFor: source.budget.controllerId,
              status: AllocationStatus.pending,
              decisionNote: '',
              createdAt: null,
              decidedAt: null,
            ),
          );

      // `mounted` guards against the sheet having been closed while awaiting.
      // Touching context after that throws.
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(
        context,
        ref.read(textProvider)('request.sent_to', {
          'name': household
              .displayNameOf(source.budget.controllerId)
              .split(' ')
              .first,
        }),
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      // `finally` runs whether or not something threw, so the button can never
      // stay stuck in its loading state.
      if (mounted) setState(() => _busy = false);
    }
  }

  static BudgetView? _findBudget(List<BudgetView> budgets, String? id) {
    if (id == null) return null;
    final matches = budgets.where((b) => b.budget.id == id).toList();
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
    final money = ref.watch(moneyProvider);
    final summary = ref.watch(summaryProvider);
    final partner = ref.watch(partnerProvider);

    final theirBudgets =
        summary.theirMonthly.where((b) => !b.budget.isSaving).toList();
    final myBudgets = summary.myMonthly;
    final selectedSource = _findBudget(theirBudgets, _fromBudgetId);
    final partnerName =
        partner?.displayName.split(' ').first ?? t('common.partner');

    if (theirBudgets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Insets.page),
        child: EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          compact: true,
          title: t('request.none_title'),
          message: partner == null
              ? t('request.none_unpaired')
              : t('request.none_blurb', {'name': partnerName}),
        ),
      );
    }

    return Padding(
      // viewInsets is the space the keyboard takes. Adding it as bottom padding
      // lifts the sheet clear of the keyboard instead of hiding behind it.
      padding: EdgeInsets.only(
        left: Insets.page,
        right: Insets.page,
        top: Insets.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Insets.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t('request.title'), style: text.titleLarge),
            const SizedBox(height: Insets.xs),
            Text(
              t('request.subtitle', {'name': partnerName}),
              style: text.bodySmall?.copyWith(color: colors.inkSecondary),
            ),
            const SizedBox(height: Insets.lg),

            Text(t('request.from'), style: text.labelSmall),
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (final budget in theirBudgets)
                  ChoiceChip(
                    label: Text(budget.budget.name),
                    selected: _fromBudgetId == budget.budget.id,
                    onSelected: (_) =>
                        setState(() => _fromBudgetId = budget.budget.id),
                  ),
              ],
            ),
            if (selectedSource != null) ...[
              const SizedBox(height: Insets.sm),
              Text(
                t('request.left_in', {
                  'amount': money.format(selectedSource.remaining),
                  'budget': selectedSource.budget.name,
                }),
                style: text.bodySmall?.copyWith(color: colors.inkSecondary),
              ),
            ],
            const SizedBox(height: Insets.lg),

            Text(t('request.amount'), style: text.labelSmall),
            const SizedBox(height: Insets.sm),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: text.displayMedium,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: text.displayMedium?.copyWith(color: colors.inkMuted),
                prefixText: '${money.symbol} ',
                prefixStyle: text.titleMedium?.copyWith(color: colors.inkMuted),
              ),
            ),
            const SizedBox(height: Insets.lg),

            Text(t('request.what_for'), style: text.labelSmall),
            const SizedBox(height: Insets.sm),
            TextField(
              controller: _reason,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  InputDecoration(hintText: t('request.what_for_hint')),
            ),
            const SizedBox(height: Insets.lg),

            Text(t('request.lands_in'), style: text.labelSmall),
            const SizedBox(height: Insets.sm),
            if (myBudgets.isEmpty) ...[
              TextField(
                controller: _newBudgetName,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    InputDecoration(hintText: t('request.name_budget_hint')),
              ),
              const SizedBox(height: Insets.sm),
              Text(
                t('request.creates_budget'),
                style: text.bodySmall?.copyWith(color: colors.inkSecondary),
              ),
            ] else
              Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.sm,
                children: [
                  for (final budget in myBudgets)
                    ChoiceChip(
                      label: Text(budget.budget.name),
                      selected: _toBudgetId == budget.budget.id,
                      onSelected: (_) =>
                          setState(() => _toBudgetId = budget.budget.id),
                    ),
                ],
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
                  Icon(
                    Icons.mark_email_unread_outlined,
                    size: 17,
                    color: colors.inkSecondary,
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      t('request.partner_confirms', {'name': partnerName}),
                      style:
                          text.bodySmall?.copyWith(color: colors.inkSecondary),
                    ),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: Insets.lg),
              ErrorNote(message: _error!),
            ],

            const SizedBox(height: Insets.xl),
            FilledButton(
              // A null callback is how Flutter disables a button - it also
              // greys it out automatically, no extra styling needed.
              onPressed: _busy
                  ? null
                  : () => _send(
                        theirBudgets: theirBudgets,
                        myBudgets: myBudgets,
                      ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t('request.send')),
            ),
          ],
        ),
      ),
    );
  }
}
