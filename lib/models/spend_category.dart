import 'package:cloud_firestore/cloud_firestore.dart';

/// Where a category sits in the two-party confirmation flow.
enum AllocationStatus {
  /// Waiting on the other member to confirm the allocation.
  pending,
  approved,
  rejected;

  static AllocationStatus parse(String? raw) =>
      AllocationStatus.values.firstWhere(
        (s) => s.name == raw,
        orElse: () => AllocationStatus.pending,
      );

  String get label => switch (this) {
        AllocationStatus.pending => 'Awaiting confirmation',
        AllocationStatus.approved => 'Confirmed',
        AllocationStatus.rejected => 'Declined',
      };
}

/// A slice of a budget - "Groceries: 2.000.000 of the 8.000.000 monthly".
///
/// The budget's controller creates it; the other member confirms the amount
/// before it counts toward the plan.
class SpendCategory {
  const SpendCategory({
    required this.id,
    required this.budgetId,
    required this.name,
    required this.emoji,
    required this.allocated,
    required this.status,
    required this.createdBy,
    required this.confirmedBy,
    required this.decidedAt,
    required this.decisionNote,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String budgetId;
  final String name;
  final String emoji;
  final double allocated;
  final AllocationStatus status;
  final String createdBy;

  /// The member asked to confirm - always the one who did not create it.
  final String confirmedBy;
  final DateTime? decidedAt;
  final String decisionNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPending => status == AllocationStatus.pending;
  bool get isApproved => status == AllocationStatus.approved;
  bool get isRejected => status == AllocationStatus.rejected;

  /// Rejected allocations never count against the plan; pending ones do, so
  /// the plan reflects intent while confirmation is outstanding.
  double get countableAmount => isRejected ? 0 : allocated;

  factory SpendCategory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return SpendCategory(
      id: doc.id,
      budgetId: (data['budgetId'] as String?) ?? '',
      name: (data['name'] as String?) ?? 'Category',
      emoji: (data['emoji'] as String?) ?? '\u{1F4B3}',
      allocated: (data['allocated'] as num?)?.toDouble() ?? 0,
      status: AllocationStatus.parse(data['status'] as String?),
      createdBy: (data['createdBy'] as String?) ?? '',
      confirmedBy: (data['confirmedBy'] as String?) ?? '',
      decidedAt: (data['decidedAt'] as Timestamp?)?.toDate(),
      decisionNote: (data['decisionNote'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'budgetId': budgetId,
        'name': name,
        'emoji': emoji,
        'allocated': allocated,
        'status': status.name,
        'createdBy': createdBy,
        'confirmedBy': confirmedBy,
        'decisionNote': decisionNote,
      };

  /// A short, neutral set of starting categories offered on an empty budget.
  static const suggestions = <(String, String)>[
    ('\u{1F6D2}', 'Groceries'),
    ('\u{1F374}', 'Eating out'),
    ('\u{1F3E0}', 'Rent & bills'),
    ('\u{1F697}', 'Transport'),
    ('\u{1F48A}', 'Health'),
    ('\u{1F455}', 'Shopping'),
    ('\u{1F3AC}', 'Fun'),
    ('\u{1F4DA}', 'Learning'),
    ('\u{1F381}', 'Gifts'),
    ('\u{1F43E}', 'Pets'),
    ('\u{1F9F9}', 'Household'),
    ('\u{2708}', 'Travel'),
  ];
}
