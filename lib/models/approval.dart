import 'package:cloud_firestore/cloud_firestore.dart';

import 'spend_category.dart';

enum ApprovalKind {
  /// A new category and its allocation need the other member's sign-off.
  categoryAllocation,

  /// An already-confirmed allocation was changed and needs re-confirming.
  allocationChange,

  /// The budget's ceiling, name or controller changed - informational, but
  /// still routed through the inbox so nothing moves silently.
  budgetChange;

  static ApprovalKind parse(String? raw) => ApprovalKind.values.firstWhere(
        (k) => k.name == raw,
        orElse: () => ApprovalKind.categoryAllocation,
      );
}

/// An item in the other member's inbox.
///
/// Approvals mirror the decision rather than owning it: confirming one writes
/// the new status onto the category in the same batch, so the two can never
/// disagree.
class Approval {
  const Approval({
    required this.id,
    required this.kind,
    required this.budgetId,
    required this.categoryId,
    required this.title,
    required this.summary,
    required this.amount,
    required this.previousAmount,
    required this.requestedBy,
    required this.requestedFor,
    required this.status,
    required this.decisionNote,
    required this.createdAt,
    required this.decidedAt,
  });

  final String id;
  final ApprovalKind kind;
  final String budgetId;
  final String? categoryId;
  final String title;
  final String summary;
  final double amount;

  /// Set on [ApprovalKind.allocationChange] so the inbox can show the delta.
  final double? previousAmount;
  final String requestedBy;
  final String requestedFor;
  final AllocationStatus status;
  final String decisionNote;
  final DateTime? createdAt;
  final DateTime? decidedAt;

  factory Approval.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Approval(
      id: doc.id,
      kind: ApprovalKind.parse(data['kind'] as String?),
      budgetId: (data['budgetId'] as String?) ?? '',
      categoryId: data['categoryId'] as String?,
      title: (data['title'] as String?) ?? '',
      summary: (data['summary'] as String?) ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      previousAmount: (data['previousAmount'] as num?)?.toDouble(),
      requestedBy: (data['requestedBy'] as String?) ?? '',
      requestedFor: (data['requestedFor'] as String?) ?? '',
      status: AllocationStatus.parse(data['status'] as String?),
      decisionNote: (data['decisionNote'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      decidedAt: (data['decidedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'budgetId': budgetId,
        'categoryId': categoryId,
        'title': title,
        'summary': summary,
        'amount': amount,
        'previousAmount': previousAmount,
        'requestedBy': requestedBy,
        'requestedFor': requestedFor,
        'status': status.name,
        'decisionNote': decisionNote,
      };
}
