import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format/money.dart';
import '../../core/format/period.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../models/budget.dart';
import '../../models/expense.dart';
import '../../models/spend_category.dart';
import '../../state/providers.dart';

/// Opens the add/edit sheet. Both members can file against any budget - the
/// ledger is shared, so nothing here is gated on who controls the budget.
Future<void> showExpenseEditor(
  BuildContext context, {
  Expense? existing,
  String? budgetId,
  String? categoryId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ExpenseEditor(
      existing: existing,
      initialBudgetId: budgetId,
      initialCategoryId: categoryId,
    ),
  );
}

class ExpenseEditor extends ConsumerStatefulWidget {
  const ExpenseEditor({
    super.key,
    this.existing,
    this.initialBudgetId,
    this.initialCategoryId,
  });

  final Expense? existing;
  final String? initialBudgetId;
  final String? initialCategoryId;

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
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  List<Budget> get _budgets =>
      ref.watch(budgetsProvider).valueOrNull ?? const [];

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
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    if (_budgetId == null) {
      setState(() => _error = 'Pick which budget this comes out of.');
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
          ),
        );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
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
        title: const Text('Delete this expense?'),
        content: const Text(
          'It disappears for both of you and the totals go back down.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.negative,
            ),
            child: const Text('Delete'),
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
                    _isEdit ? 'Edit expense' : 'New expense',
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
            const SizedBox(height: Insets.lg),

            // The amount is the point of the sheet, so it gets the big field.
            TextField(
              controller: _amount,
              autofocus: !_isEdit,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: text.displayMedium,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: text.displayMedium?.copyWith(color: colors.inkMuted),
                prefixText: '${money.symbol} ',
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
                title: 'No budget to file this under',
                message: 'Create a budget for this month first.',
              )
            else ...[
              Text('BUDGET', style: text.labelSmall),
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
                      }),
                    ),
                ],
              ),
              const SizedBox(height: Insets.lg),

              if (categories.isNotEmpty) ...[
                Text('CATEGORY', style: text.labelSmall),
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
              decoration: const InputDecoration(
                hintText: 'What was it for? (optional)',
              ),
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
              label: Text(DateFormat.yMMMMd().format(_date)),
            ),

            if (_error != null) ...[
              const SizedBox(height: Insets.lg),
              ErrorNote(message: _error!),
            ],

            const SizedBox(height: Insets.xl),
            FilledButton(
              onPressed: _busy || budgets.isEmpty ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Save changes' : 'Add expense'),
            ),
          ],
        ),
      ),
    );
  }
}
