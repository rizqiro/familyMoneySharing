import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../models/budget.dart';
import '../../models/spend_category.dart';
import '../../state/providers.dart';

/// Create or edit a category inside a budget. Only the budget's controller
/// reaches this sheet; the other member confirms the result from their inbox.
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
      if (mounted) setState(() => _error = '$e');
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
            ),

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
