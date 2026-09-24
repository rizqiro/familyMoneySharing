import 'package:cloud_firestore/cloud_firestore.dart';

/// Which way the money went.
///
/// =============================================================================
/// WHY ONE COLLECTION AND NOT TWO
/// =============================================================================
/// Income could have been its own collection. It is not, because almost
/// everything about the two is identical - they belong to a budget, they may
/// belong to a category, they are filed by one member, they appear in the same
/// ledger, they are read by the same queries. Two collections would mean two of
/// every query, two security rules, and a ledger screen that merges them by
/// hand.
///
/// So there is one collection with a direction on each row. The direction is
/// the ONLY thing that differs, and it is one field.
enum EntryKind {
  /// Money leaving. An expense against a monthly budget, or a withdrawal from
  /// a saving pot.
  spending,

  /// Money arriving. Extra money added to a monthly budget, or a contribution
  /// paid into a saving pot.
  income;

  static EntryKind? parse(String? raw) {
    if (raw == null) return null;
    for (final kind in EntryKind.values) {
      if (kind.name == raw) return kind;
    }
    return null;
  }
}

/// One entry in the shared ledger. Visible to both members, always.
///
/// `period` is denormalised so the month's ledger is a single indexed query
/// rather than a range scan the client has to re-bucket.
class Expense {
  const Expense({
    required this.id,
    required this.budgetId,
    required this.categoryId,
    required this.amount,
    required this.note,
    required this.spentBy,
    required this.spentAt,
    required this.period,
    required this.createdAt,
    this.kind,
  });

  final String id;
  final String budgetId;
  final String categoryId;
  final double amount;
  final String note;
  final String spentBy;
  final DateTime spentAt;
  final String period;
  final DateTime? createdAt;

  /// Which way the money went - or null for an entry written before the app
  /// knew about income.
  ///
  /// =============================================================================
  /// WHY THIS IS NULLABLE AND NOT JUST "spending"
  /// =============================================================================
  /// Defaulting a missing value to [EntryKind.spending] would be wrong for
  /// saving pots. Before income existed, the only way to put money INTO a pot
  /// was to file it as an expense against it - so on a saving budget, an entry
  /// with no `kind` means a contribution, not a withdrawal.
  ///
  /// Reading it as null here keeps that ambiguity intact, and
  /// `PeriodSummary.build` resolves it with the one extra fact it has and this
  /// model does not: whether the budget is a saving pot. Every entry written
  /// from now on sets the field, so this only ever applies to old rows.
  final EntryKind? kind;

  /// The direction, resolved. Pass whether the budget this belongs to is a
  /// saving pot; see the note on [kind].
  EntryKind kindIn({required bool saving}) =>
      kind ?? (saving ? EntryKind.income : EntryKind.spending);

  bool get isIncome => kind == EntryKind.income;

  factory Expense.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Expense(
      id: doc.id,
      budgetId: (data['budgetId'] as String?) ?? '',
      categoryId: (data['categoryId'] as String?) ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      note: (data['note'] as String?) ?? '',
      spentBy: (data['spentBy'] as String?) ?? '',
      spentAt: (data['spentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      period: (data['period'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      kind: EntryKind.parse(data['kind'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'budgetId': budgetId,
        'categoryId': categoryId,
        'amount': amount,
        'note': note,
        'spentBy': spentBy,
        'spentAt': Timestamp.fromDate(spentAt),
        'period': period,
        // Always written, even though it is nullable on the way in: only rows
        // from before this feature existed are allowed to be missing it.
        'kind': (kind ?? EntryKind.spending).name,
      };

  Expense copyWith({
    String? budgetId,
    String? categoryId,
    double? amount,
    String? note,
    DateTime? spentAt,
    String? period,
    EntryKind? kind,
  }) =>
      Expense(
        id: id,
        budgetId: budgetId ?? this.budgetId,
        categoryId: categoryId ?? this.categoryId,
        amount: amount ?? this.amount,
        note: note ?? this.note,
        spentBy: spentBy,
        spentAt: spentAt ?? this.spentAt,
        period: period ?? this.period,
        createdAt: createdAt,
        kind: kind ?? this.kind,
      );
}
