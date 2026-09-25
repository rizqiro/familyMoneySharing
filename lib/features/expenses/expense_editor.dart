import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format/failure.dart';
import '../../core/format/money.dart';
import '../../core/format/money_input.dart';
import '../../core/format/period.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../models/budget.dart';
import '../../models/expense.dart';
import '../../models/spend_category.dart';
import '../../state/providers.dart';
import '../money/request_money_sheet.dart';

/// Opens the add/edit sheet.
///
/// An entry may only be filed against a budget the person controls. Both
/// members still SEE every entry - the ledger is shared - but the money has to
/// come out of a pot that is yours. To spend from your partner's, ask them to
/// move some across (see [showRequestMoneySheet]).
///
/// =============================================================================
/// SPENDING AND INCOME ARE THE SAME SHEET
/// =============================================================================
/// Both are an amount, a budget, a category, a date and a note. The only
/// difference is the direction, so it is a two-way switch at the top rather
/// than a second screen that would duplicate all five fields.
///
/// On a saving pot the switch starts on income, because the usual thing you do
/// with a pot is put money in. On a monthly budget it starts on spending, for
/// the same reason the other way round.
Future<void> showExpenseEditor(
  BuildContext context, {
  Expense? existing,
  String? budgetId,
  String? categoryId,
  EntryKind? kind,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ExpenseEditor(
      existing: existing,
      initialBudgetId: budgetId,
      initialCategoryId: categoryId,
      initialKind: kind,
    ),
  );
}

class ExpenseEditor extends ConsumerStatefulWidget {
  const ExpenseEditor({
    super.key,
    this.existing,
    this.initialBudgetId,
    this.initialCategoryId,
    this.initialKind,
  });

  final Expense? existing;
  final String? initialBudgetId;
  final String? initialCategoryId;
  final EntryKind? initialKind;

  @override
  ConsumerState<ExpenseEditor> createState() => _ExpenseEditorState();
}

class _ExpenseEditorState extends ConsumerState<ExpenseEditor> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : _initialAmountText(widget.existing!.amount),
  );
  late final TextEditingController _note =
      TextEditingController(text: widget.existing?.note ?? '');

  String? _budgetId;
  String? _categoryId;
  late EntryKind _kind;

  /// Set once the direction has been chosen by hand, which stops a later
  /// budget change from overriding it.
  bool _kindTouched = false;
  late DateTime _date = widget.existing?.spentAt ?? DateTime.now();
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  String _initialAmountText(double amount) {
    final code =
        ref.read(householdProvider).valueOrNull?.currencyCode ?? 'IDR';
    return Money(code).plain(amount);
  }

  @override
  void initState() {
    super.initState();
    _budgetId = widget.existing?.budgetId ?? widget.initialBudgetId;
    _categoryId = widget.existing?.categoryId.isNotEmpty == true
        ? widget.existing!.categoryId
        : widget.initialCategoryId;

    // An existing entry keeps its own direction, resolved through the saving
    // rule for rows written before income existed. A new one follows whatever
    // the caller asked for, or the budget's usual direction.
    final existing = widget.existing;
    _kind = existing != null
        ? existing.kindIn(saving: _isSavingBudget(existing.budgetId))
        : (widget.initialKind ??
            (_isSavingBudget(_budgetId)
                ? EntryKind.income
                : EntryKind.spending));
  }

  /// Is this budget a saving pot? Read rather than watched: it is only needed
  /// while working out a default in initState.
  bool _isSavingBudget(String? budgetId) {
    if (budgetId == null) return false;
    final summary = ref.read(summaryProvider);
    return summary.savings.any((v) => v.budget.id == budgetId);
  }

  bool get _isIncome => _kind == EntryKind.income;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Only budgets this person controls.
  ///
  /// This is where "you cannot spend someone else's budget" is enforced in the
  /// UI: a budget you do not control never appears as an option, so the rule
  /// shows up as an absence rather than as an error after the fact.
  ///
  /// The security rules enforce the same thing server-side. Both matter: the UI
  /// so the app is honest about what you can do, the rules so a modified client
  /// cannot do it anyway.
  List<Budget> get _budgets => ref
      .watch(summaryProvider)
      .spendable
      .map((view) => view.budget)
      .toList();

  List<SpendCategory> _categoriesFor(String? budgetId) {
    if (budgetId == null) return const [];
    return (ref.watch(categoriesProvider).valueOrNull ?? const [])
        .where((c) => c.budgetId == budgetId && !c.isRejected)
        .toList();
  }

  Future<void> _save() async {
    final householdId = ref.read(householdIdProvider);
    final uid = ref.read(currentUidProvider);
    final household = ref.read(householdProvider).valueOrNull;
    if (householdId == null || uid == null || household == null) return;

    final amount = Money.parseInput(_amount.text, household.currencyCode);
    if (amount == null || amount <= 0) {
      setState(() => _error = ref.read(textProvider)('expense.err_amount'));
      return;
    }
    if (_budgetId == null) {
      setState(() => _error = ref.read(textProvider)('expense.err_budget'));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final repo = ref.read(expenseRepositoryProvider);
      final period =
          Period.of(_date, monthStartDay: household.monthStartDay).key;

      if (_isEdit) {
        await repo.update(
          householdId,
          widget.existing!.copyWith(
            budgetId: _budgetId,
            categoryId: _categoryId ?? '',
            amount: amount,
            note: _note.text,
            spentAt: _date,
            period: period,
            kind: _kind,
          ),
        );
      } else {
        await repo.add(
          householdId,
          Expense(
            id: '',
            budgetId: _budgetId!,
            categoryId: _categoryId ?? '',
            amount: amount,
            note: _note.text,
            spentBy: uid,
            spentAt: _date,
            period: period,
            createdAt: null,
            kind: _kind,
          ),
        );
      }

      if (mounted) Navigator.of(context).pop();
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

  Future<void> _delete() async {
    final householdId = ref.read(householdIdProvider);
    if (householdId == null || !_isEdit) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ref.read(textProvider)('expense.delete_title')),
        content: Text(ref.read(textProvider)('expense.delete_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(ref.read(textProvider)('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.negative,
            ),
            child: Text(ref.read(textProvider)('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref
        .read(expenseRepositoryProvider)
        .delete(householdId, widget.existing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
    final locale = ref.watch(dateLocaleProvider);
    final money = ref.watch(moneyProvider);
    final budgets = _budgets;
    final categories = _categoriesFor(_budgetId);

    return Padding(
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEdit
                        ? t(_isIncome ? 'expense.edit_income' : 'expense.edit')
                        : t(_isIncome ? 'expense.new_income' : 'expense.new'),
                    style: text.titleLarge,
                  ),
                ),
                if (_isEdit)
                  IconButton(
                    onPressed: _busy ? null : _delete,
                    icon: Icon(Icons.delete_outline, color: colors.negative),
                  ),
              ],
            ),
            const SizedBox(height: Insets.md),

            // Which way the money is going. Above the amount rather than below
            // it, because it changes what the amount MEANS - reading the
            // figure first and the direction second is how you misfile one.
            _DirectionSwitch(
              kind: _kind,
              onChanged: (kind) => setState(() {
                _kind = kind;
                _kindTouched = true;
              }),
            ),
            const SizedBox(height: Insets.lg),

            // The amount is the point of the sheet, so it gets the big field.
            TextField(
              controller: _amount,
              autofocus: !_isEdit,
              keyboardType: TextInputType.numberWithOptions(
                decimal: money.decimals > 0,
              ),
              inputFormatters: moneyInputFormatters(money),
              textAlign: TextAlign.center,
              style: text.displayMedium,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: text.displayMedium?.copyWith(color: colors.inkMuted),
                // A sign in front of the figure, so the direction is visible
                // while you are looking at the number rather than only at the
                // switch above.
                prefixText: '${_isIncome ? '+' : '\u2212'} ${money.symbol} ',
                prefixStyle: text.titleMedium?.copyWith(
                  color: colors.inkMuted,
                ),
              ),
            ),
            const SizedBox(height: Insets.lg),

            if (budgets.isEmpty)
              EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                compact: true,
                title: t('expense.nothing_yours'),
                message: t('expense.nothing_yours_blurb'),
                actionLabel: t('dashboard.request_money'),
                onAction: () {
                  // Close this sheet before opening the next, so the two do not
                  // stack on top of each other.
                  Navigator.of(context).pop();
                  showRequestMoneySheet(context);
                },
              )
            else ...[
              Text(t('expense.budget'), style: text.labelSmall),
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.sm,
                children: [
                  for (final budget in budgets)
                    ChoiceChip(
                      label: Text(budget.name),
                      selected: _budgetId == budget.id,
                      onSelected: (_) => setState(() {
                        _budgetId = budget.id;
                        _categoryId = null;
                        // Switching to a saving pot flips the default
                        // direction, unless you already chose one yourself.
                        if (!_isEdit && !_kindTouched) {
                          _kind = _isSavingBudget(budget.id)
                              ? EntryKind.income
                              : EntryKind.spending;
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: Insets.lg),

              if (categories.isNotEmpty) ...[
                Text(t('expense.category'), style: text.labelSmall),
                const SizedBox(height: Insets.sm),
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.sm,
                  children: [
                    for (final category in categories)
                      ChoiceChip(
                        label: Text('${category.emoji} ${category.name}'),
                        selected: _categoryId == category.id,
                        onSelected: (_) => setState(
                          () => _categoryId =
                              _categoryId == category.id ? null : category.id,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Insets.lg),
              ],
            ],

            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: t('expense.note_hint')),
            ),
            const SizedBox(height: Insets.md),

            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(DateTime.now().year - 3),
                  lastDate: DateTime(DateTime.now().year + 3),
                );
                if (picked != null) setState(() => _date = picked);
              },
              icon: const Icon(Icons.calendar_today_outlined, size: 17),
              label: Text(DateFormat.yMMMMd(locale).format(_date)),
            ),

            if (_error != null) ...[
              const SizedBox(height: Insets.lg),
              ErrorNote(message: _error!),
            ],

            const SizedBox(height: Insets.xl),
            // The button follows the switch at the top: green and "Add income"
            // for money in, accent and "Add expense" for money out. A button
            // that stays red and says "Add expense" while the sheet is set to
            // income is telling you the opposite of what it will do.
            FilledButton(
              onPressed: _busy || budgets.isEmpty ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _isIncome ? colors.positive : colors.accent,
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
                  : Text(
                      _isEdit
                          ? t('common.save_changes')
                          : t(_isIncome ? 'expense.add_income' : 'expense.add'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Spending or income, as one two-way switch.
///
/// The selected half is filled - red for money out, green for money in - and
/// the unselected half is plain. Colour alone would not be enough (red and
/// green are the classic pair to confuse), so each half also carries an arrow
/// pointing the way the money goes, and its own word.
class _DirectionSwitch extends ConsumerWidget {
  const _DirectionSwitch({required this.kind, required this.onChanged});

  final EntryKind kind;
  final ValueChanged<EntryKind> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final t = ref.watch(textProvider);

    return Container(
      padding: const EdgeInsets.all(Insets.xs),
      decoration: BoxDecoration(
        color: colors.track,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Half(
              label: t('expense.kind_spending'),
              icon: Icons.arrow_outward,
              selected: kind == EntryKind.spending,
              fill: colors.accent,
              onTap: () => onChanged(EntryKind.spending),
            ),
          ),
          Expanded(
            child: _Half(
              label: t('expense.kind_income'),
              icon: Icons.arrow_downward,
              selected: kind == EntryKind.income,
              fill: colors.positive,
              onTap: () => onChanged(EntryKind.income),
            ),
          ),
        ],
      ),
    );
  }
}

class _Half extends StatelessWidget {
  const _Half({
    required this.label,
    required this.icon,
    required this.selected,
    required this.fill,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = selected ? Colors.white : colors.inkSecondary;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? fill : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: tone),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tone,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
