import 'package:cloud_firestore/cloud_firestore.dart';

enum BudgetKind {
  /// Resets every period. "What we may spend this month."
  monthly,

  /// Accumulates toward a target. "What we are putting aside."
  saving;

  static BudgetKind parse(String? raw) => BudgetKind.values.firstWhere(
        (k) => k.name == raw,
        orElse: () => BudgetKind.monthly,
      );
}

/// A pot of money with exactly one person responsible for it.
///
/// A monthly budget is scoped to [period]; a saving budget carries across
/// periods and has [period] == null.
class Budget {
  const Budget({
    required this.id,
    required this.name,
    required this.kind,
    required this.amount,
    required this.controllerId,
    required this.period,
    required this.targetDate,
    required this.note,
    required this.archived,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String name;
  final BudgetKind kind;

  /// Monthly: the spending ceiling. Saving: the target to reach.
  final double amount;

  /// The member who may create and edit this budget's categories.
  final String controllerId;

  /// `YYYY-MM`, or null for saving budgets.
  final String? period;
  final DateTime? targetDate;
  final String note;
  final bool archived;
  final String createdBy;
  final DateTime? createdAt;

  bool get isSaving => kind == BudgetKind.saving;

  factory Budget.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Budget(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Budget',
      kind: BudgetKind.parse(data['kind'] as String?),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      controllerId: (data['controllerId'] as String?) ?? '',
      period: data['period'] as String?,
      targetDate: (data['targetDate'] as Timestamp?)?.toDate(),
      note: (data['note'] as String?) ?? '',
      archived: (data['archived'] as bool?) ?? false,
      createdBy: (data['createdBy'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kind.name,
        'amount': amount,
        'controllerId': controllerId,
        'period': period,
        'targetDate': targetDate == null ? null : Timestamp.fromDate(targetDate!),
        'note': note,
        'archived': archived,
        'createdBy': createdBy,
      };

  Budget copyWith({
    String? name,
    BudgetKind? kind,
    double? amount,
    String? controllerId,
    String? period,
    DateTime? targetDate,
    String? note,
    bool? archived,
  }) =>
      Budget(
        id: id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        amount: amount ?? this.amount,
        controllerId: controllerId ?? this.controllerId,
        period: period ?? this.period,
        targetDate: targetDate ?? this.targetDate,
        note: note ?? this.note,
        archived: archived ?? this.archived,
        createdBy: createdBy,
        createdAt: createdAt,
      );
}
