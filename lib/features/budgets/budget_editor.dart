import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format/failure.dart';
import '../../core/format/money.dart';
import '../../core/format/money_input.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../models/budget.dart';
import '../../models/spend_category.dart';
import '../../state/providers.dart';

/// Create or edit a budget, including who controls it.
Future<String?> showBudgetEditor(
  BuildContext context, {
  Budget? existing,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => BudgetEditor(existing: existing),
  );
}

class BudgetEditor extends ConsumerStatefulWidget {
  const BudgetEditor({super.key, this.existing});

  final Budget? existing;

  @override
  ConsumerState<BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends ConsumerState<BudgetEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : Money(
            ref.read(householdProvider).valueOrNull?.currencyCode ?? 'IDR',
          ).plain(widget.existing!.amount),
  );

  late BudgetKind _kind = widget.existing?.kind ?? BudgetKind.monthly;
  String? _controllerId;
  DateTime? _targetDate;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _controllerId = widget.existing?.controllerId;
    _targetDate = widget.existing?.targetDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final householdId = ref.read(householdIdProvider);
    final household = ref.read(householdProvider).valueOrNull;
    final uid = ref.read(currentUidProvider);
    if (householdId == null || household == null || uid == null) return;

    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = ref.read(textProvider)('budget_editor.err_name'));
      return;
    }

    final amount = Money.parseInput(_amount.text, household.currencyCode);
    if (amount == null || amount <= 0) {
      setState(
          () => _error = ref.read(textProvider)('budget_editor.err_amount'),);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final repo = ref.read(budgetRepositoryProvider);
      final period = ref.read(selectedPeriodProvider);

      if (_isEdit) {
        await repo.update(
          householdId,
          widget.existing!.copyWith(
            name: name,
            kind: _kind,
            amount: amount,
            controllerId: _controllerId ?? uid,
            targetDate: _targetDate,
          ),
        );
        if (mounted) Navigator.of(context).pop(widget.existing!.id);
      } else {
        final id = await repo.create(
          householdId,
          Budget(
            id: '',
            name: name,
            kind: _kind,
            amount: amount,
            controllerId: _controllerId ?? uid,
            period: _kind == BudgetKind.saving ? null : period.key,
            targetDate: _targetDate,
            note: '',
            archived: false,
            createdBy: uid,
            createdAt: null,
          ),
          // A new saving pot arrives with the three categories almost every
          // pot needs, at zero each. Naming a pot and then staring at an empty
          // one is the moment people give up; three sensible headings is a
          // better start than a blank page.
          //
          // The names go through `t` here because a repository has no business
          // knowing which language the household reads.
          seedCategories: _kind == BudgetKind.saving
              ? SpendCategory.savingSeeds(ref.read(textProvider))
              : const [],
        );
        if (mounted) Navigator.of(context).pop(id);
      }
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final t = ref.watch(textProvider);
    final locale = ref.watch(dateLocaleProvider);
    final money = ref.watch(moneyProvider);
    final household = ref.watch(householdProvider).valueOrNull;
    final uid = ref.watch(currentUidProvider);
    final period = ref.watch(selectedPeriodProvider);

    final controllerId = _controllerId ?? uid;

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
            Text(
              _isEdit ? t('budget_editor.edit') : t('budget_editor.new'),
              style: text.titleLarge,
            ),
            const SizedBox(height: Insets.lg),

            TextField(
              controller: _name,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: t('budget_editor.name_hint'),
              ),
            ),
            const SizedBox(height: Insets.lg),

            Text(t('budget_editor.type'), style: text.labelSmall),
            const SizedBox(height: Insets.sm),
            SegmentedButton<BudgetKind>(
              segments: [
                ButtonSegment(
                  value: BudgetKind.monthly,
                  label: Text(t('budget_editor.monthly')),
                  icon: const Icon(Icons.calendar_month_outlined, size: 16),
                ),
                ButtonSegment(
                  value: BudgetKind.saving,
                  label: Text(t('budget_editor.saving')),
                  icon: const Icon(Icons.savings_outlined, size: 16),
                ),
              ],
              selected: {_kind},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              _kind == BudgetKind.monthly
                  ? t('budget_editor.monthly_blurb',
                      {'month': period.label(locale)},)
                  : t('budget_editor.saving_blurb'),
              style: text.bodySmall?.copyWith(color: colors.inkSecondary),
            ),
            const SizedBox(height: Insets.lg),

            Text(
              _kind == BudgetKind.monthly
                  ? t('budget_editor.amount')
                  : t('budget_editor.target'),
              style: text.labelSmall,
            ),
            const SizedBox(height: Insets.sm),
            TextField(
              controller: _amount,
              // The keyboard hint is a convenience - some Android keypads show
              // letters anyway, and pasting skips the keyboard entirely. The
              // formatter below is what actually keeps this field numeric.
              keyboardType: TextInputType.numberWithOptions(
                decimal: money.decimals > 0,
              ),
              inputFormatters: moneyInputFormatters(money),
              decoration: InputDecoration(
                hintText: '0',
                prefixText: '${money.symbol} ',
              ),
            ),

            if (_kind == BudgetKind.saving) ...[
              const SizedBox(height: Insets.md),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _targetDate ??
                        DateTime.now().add(const Duration(days: 180)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(DateTime.now().year + 10),
                  );
                  if (picked != null) setState(() => _targetDate = picked);
                },
                icon: const Icon(Icons.flag_outlined, size: 17),
                label: Text(
                  _targetDate == null
                      ? t('budget_editor.add_target_date')
                      : t('budget_editor.by_date', {
                          'date': DateFormat.yMMMd(locale).format(_targetDate!),
                        }),
                ),
              ),
            ],

            if (household != null && household.isPaired) ...[
              const SizedBox(height: Insets.lg),
              Text(t('budget_editor.who_controls'), style: text.labelSmall),
              const SizedBox(height: Insets.xs),
              Text(
                t('budget_editor.who_controls_blurb'),
                style: text.bodySmall?.copyWith(color: colors.inkSecondary),
              ),
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: Insets.sm,
                children: [
                  for (final id in household.memberIds)
                    ChoiceChip(
                      avatar: MemberAvatar(
                        initial: household.member(id)?.initial ?? '?',
                        size: 20,
                      ),
                      label: Text(
                        id == uid
                            ? t('common.you')
                            : household.displayNameOf(id, unknown: t('common.someone')),
                      ),
                      selected: controllerId == id,
                      onSelected: (_) => setState(() => _controllerId = id),
                    ),
                ],
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: Insets.lg),
              ErrorNote(message: _error!),
            ],

            const SizedBox(height: Insets.xl),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit
                      ? t('common.save_changes')
                      : t('budgets.create'),),
            ),
          ],
        ),
      ),
    );
  }
}
