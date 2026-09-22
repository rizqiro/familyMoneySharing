import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/approval.dart';
import '../models/spend_category.dart';
import 'firestore_refs.dart';

/// The inbox side of category allocations.
///
/// An approval mirrors a decision rather than owning it: [decide] writes the
/// new status onto the approval AND onto its category in one batch, so the two
/// can never disagree. There is deliberately no "withdraw" - deleting a request
/// would strand its category as pending forever, with nothing left to resolve
/// it. Editing the category supersedes the request instead.
class ApprovalRepository {
  ApprovalRepository(this.db, this._refs);

  final FirebaseFirestore db;
  final FirestoreRefs _refs;

  /// What [uid] has been asked to confirm.
  Stream<List<Approval>> watchInbox(String householdId, String uid) {
    return _refs
        .approvals(householdId)
        .where('requestedFor', isEqualTo: uid)
        .where('status', isEqualTo: AllocationStatus.pending.name)
        .snapshots()
        .map(
          (snap) => snap.docs.map(Approval.fromDoc).toList()
            ..sort(
              (a, b) => (b.createdAt ?? DateTime(0))
                  .compareTo(a.createdAt ?? DateTime(0)),
            ),
        );
  }

  /// What [uid] has asked for and not heard back on.
  Stream<List<Approval>> watchOutbox(String householdId, String uid) {
    return _refs
        .approvals(householdId)
        .where('requestedBy', isEqualTo: uid)
        .where('status', isEqualTo: AllocationStatus.pending.name)
        .snapshots()
        .map(
          (snap) => snap.docs.map(Approval.fromDoc).toList()
            ..sort(
              (a, b) => (b.createdAt ?? DateTime(0))
                  .compareTo(a.createdAt ?? DateTime(0)),
            ),
        );
  }

  /// Writes the decision onto the approval and its category together, so the
  /// inbox item and the allocation always agree.
  Future<void> decide({
    required String householdId,
    required Approval approval,
    required bool approved,
    String note = '',
  }) async {
    final status =
        approved ? AllocationStatus.approved : AllocationStatus.rejected;
    final now = FieldValue.serverTimestamp();

    final batch = db.batch();
    batch.update(_refs.approval(householdId, approval.id), {
      'status': status.name,
      'decisionNote': note.trim(),
      'decidedAt': now,
    });

    if (approval.categoryId != null && approval.categoryId!.isNotEmpty) {
      batch.update(_refs.category(householdId, approval.categoryId!), {
        'status': status.name,
        'decisionNote': note.trim(),
        'decidedAt': now,
      });
    }

    await batch.commit();
  }
}
