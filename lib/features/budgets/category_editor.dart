import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/failure.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../models/budget.dart';
import '../../models/spend_category.dart';
import '../../state/period_summary.dart';
import '../../state/providers.dart';

/// Create or edit a category inside a budget. Only the budget's controller
/// reaches this sheet; the other member confirms the result from their inbox.
///
/// =============================================================================
/// THE ONE HARD LIMIT: CATEGORIES CANNOT ADD UP TO MORE THAN THE BUDGET
/// =============================================================================
/// Carving a budget into categories is planning, and a plan that allocates more
/// money than exists is not a plan. So the amount here is capped at whatever is
/// left unallocated, and the sheet says what that figure is before you start
/// typing rather than rejecting you afterwards.
///
/// SPENDING more than a category holds is a different matter and stays
/// allowed. Real life overshoots; the budget's job is to tell you by how much,
/// not to refuse to record it. The limit is on the plan, never on what
/// actually happened.
Future<void> showCategoryEditor(
  BuildContext context, {
  required Budget budget,
  SpendCategory? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => CategoryEditor(budget: budget, existing: existing),
  );
}

class CategoryEditor extends ConsumerStatefulWidget {
  const CategoryEditor({super.key, required this.budget, this.existing});

  final Budget budget;
  final SpendCategory? existing;

  @override
  ConsumerState<CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends ConsumerState<CategoryEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : Money(
            ref.read(householdProvider).valueOrNull?.currencyCode ?? 'IDR',
          ).plain(widget.existing!.allocated),
  );

  late String _emoji = widget.existing?.emoji ?? '\u{1F6D2}';
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  /// This budget as the month sees it - allocations, transfers and all.
  ///
  /// Null while the summary is still loading, in which case the cap is not
  /// applied: better to let a category through and show the over-allocation
  /// warning afterwards than to block on data that has not arrived.
  BudgetView? _budgetView() {
    final all = ref.read(summaryProvider);
    final matches = [...all.monthly, ...all.savings]
        .where((v) => v.budget.id == widget.budget.id);
    return matches.isEmpty ? null : matches.first;
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
    final profile = ref.read(profileProvider).valueOrNull;
    if (householdId == null || household == null || profile == null) return;

    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(
          () => _error = ref.read(textProvider)('category_editor.err_name'),);
      return;
    }

    final amount = Money.parseInput(_amount.text, household.currencyCode);
    if (amount == null || amount <= 0) {
      setState(
          () => _error = ref.read(textProvider)('category_editor.err_amount'),);
      return;
    }

    // The cap. `headroomExcluding` leaves out the category being edited, so
    // raising one from 300k to 400k is measured against the other categories
    // rather than against itself.
    final view = _budgetView();
    if (view != null) {
      final headroom = view.headroomExcluding(widget.existing?.id);
      if (amount > headroom) {
        final money = ref.read(moneyProvider);
        setState(
          () => _error = ref.read(textProvider)('category_editor.err_over', {
            'over': money.format(amount - headroom),
            'headroom': money.format(headroom),
            'budget': widget.budget.name,
          }),
        );
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final repo = ref.read(categoryRepositoryProvider);
      final partnerUid = household.partnerOf(profile.uid)?.uid;

      if (_isEdit) {
        await repo.update(
          householdId: householdId,
          existing: widget.existing!,
          budgetName: widget.budget.name,
          name: name,
          emoji: _emoji,
          allocated: amount,
          editedBy: profile.uid,
          editedByName: profile.displayName,
          partnerUid: partnerUid,
        );
      } else {
        await repo.create(
          householdId: householdId,
          budgetId: widget.budget.id,
          budgetName: widget.budget.name,
          name: name,
          emoji: _emoji,
          allocated: amount,
          createdBy: profile.uid,
          createdByName: profile.displayName,
          partnerUid: partnerUid,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      if (partnerUid != null) {
        showToast(
          context,
          ref.read(textProvider)('category_editor.sent_to', {
            'name': household.displayNameOf(partnerUid).split(' ').first,
          }),
        );
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
    final money = ref.watch(moneyProvider);
    final partner = ref.watch(partnerProvider);

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
              _isEdit ? t('category_editor.edit') : t('category_editor.new'),
              style: text.titleLarge,
            ),
            const SizedBox(height: Insets.xs),
            Text(
              t('category_editor.in_budget', {'budget': widget.budget.name}),
              style: text.bodySmall?.copyWith(color: colors.inkSecondary),
            ),
            const SizedBox(height: Insets.lg),

            Row(
              children: [
                _EmojiButton(
                  emoji: _emoji,
                  onPick: (value) => setState(() => _emoji = value),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: TextField(
                    controller: _name,
                    autofocus: !_isEdit,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: t('category_editor.name_hint'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),

            // Tapping a suggestion fills both the icon and the name.
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (final (emoji, label) in SpendCategory.suggestions)
                  ActionChip(
                    label: Text('$emoji $label'),
                    onPressed: () => setState(() {
                      _emoji = emoji;
                      _name.text = label;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: Insets.lg),

            Text(t('category_editor.allocation'), style: text.labelSmall),
            const SizedBox(height: Insets.sm),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '0',
                prefixText: '${money.symbol} ',
              ),
              // Rebuilds the line below on every keystroke, so the headroom
              // counts down as you type instead of only being checked on save.
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Insets.sm),
            _Headroom(budget: widget.budget, existingId: widget.existing?.id),

            if (partner != null) ...[
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
                        t('category_editor.will_ask', {
                          'name': partner.displayName.split(' ').first,
                        }),
                        style: text.bodySmall
                            ?.copyWith(color: colors.inkSecondary),
                      ),
                    ),
                  ],
                ),
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
                  : Text(
                      partner == null
                          ? (_isEdit
                              ? t('common.save_changes')
                              : t('category_editor.add'))
                          : (_isEdit
                              ? t('category_editor.save_and_ask')
                              : t('category_editor.send')),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  const _EmojiButton({required this.emoji, required this.onPick});

  final String emoji;
  final ValueChanged<String> onPick;

  static const _palette = [
    '\u{1F6D2}', '\u{1F374}', '\u{1F3E0}', '\u{1F697}', '\u{1F48A}',
    '\u{1F455}', '\u{1F3AC}', '\u{1F4DA}', '\u{1F381}', '\u{1F43E}',
    '\u{1F9F9}', '\u{2708}', '\u{26FD}', '\u{1F4F1}', '\u{1F4A1}',
    '\u{1F3E5}', '\u{1F393}', '\u{1F4B0}', '\u{1F3CB}', '\u{2615}',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.field),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => Padding(
            padding: const EdgeInsets.all(Insets.page),
            child: Wrap(
              spacing: Insets.md,
              runSpacing: Insets.md,
              alignment: WrapAlignment.center,
              children: [
                for (final option in _palette)
                  InkWell(
                    onTap: () => Navigator.of(context).pop(option),
                    child: Padding(
                      padding: const EdgeInsets.all(Insets.sm),
                      child: Text(
                        option,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        width: 54,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: BorderRadius.circular(Radii.field),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}

/// "Rp 600.000 of Rp 8.000.000 still unallocated."
///
/// A live figure rather than an error after the fact. Someone who can see the
/// headroom while typing does not hit the cap; someone who only finds out on
/// save has to work out what to change.
class _Headroom extends ConsumerWidget {
  const _Headroom({required this.budget, required this.existingId});

  final Budget budget;

  /// The category being edited, left out of the sum - its own allocation is
  /// not competition for itself.
  final String? existingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final t = ref.watch(textProvider);
    final money = ref.watch(moneyProvider);
    final summary = ref.watch(summaryProvider);

    final matches = [...summary.monthly, ...summary.savings]
        .where((v) => v.budget.id == budget.id);
    if (matches.isEmpty) return const SizedBox.shrink();

    final view = matches.first;
    final headroom = view.headroomExcluding(existingId);
    final none = headroom <= 0;

    return Row(
      children: [
        Icon(
          none ? Icons.error_outline : Icons.pie_chart_outline,
          size: 15,
          color: none ? colors.accentDeep : colors.inkMuted,
        ),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: Text(
            none
                ? t('category_editor.none_left')
                : t('category_editor.headroom', {
                    'amount': money.format(headroom),
                    'total': money.format(view.available),
                  }),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: none ? colors.accentDeep : colors.inkMuted,
                ),
          ),
        ),
      ],
    );
  }
}
