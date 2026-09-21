import 'package:cloud_firestore/cloud_firestore.dart';

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
      };

  Expense copyWith({
    String? budgetId,
    String? categoryId,
    double? amount,
    String? note,
    DateTime? spentAt,
    String? period,
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
      );
}
