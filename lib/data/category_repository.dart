import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/approval.dart';
import '../models/spend_category.dart';
import 'firestore_refs.dart';

class CategoryRepository {
  CategoryRepository(this.db, this._refs);

  final FirebaseFirestore db;
  final FirestoreRefs _refs;

  Stream<List<SpendCategory>> watchForBudgets(
    String householdId,
    List<String> budgetIds,
  ) {
    if (budgetIds.isEmpty) return Stream.value(const []);

    // `whereIn` caps at 30 values; a household never has that many live
    // budgets in one period, and the extras would be off-screen anyway.
    final ids = budgetIds.take(30).toList();
    return _refs
        .categories(householdId)
        .where('budgetId', whereIn: ids)
        .snapshots()
        .map(
          (snap) => snap.docs.map(SpendCategory.fromDoc).toList()
            ..sort((a, b) => b.allocated.compareTo(a.allocated)),
        );
  }

  /// Creates the category and, when there is a partner, the confirmation
  /// request in the same batch - the allocation and the ask can't diverge.
  Future<String> create({
    required String householdId,
    required String budgetId,
    required String budgetName,
    required String name,
    required String emoji,
    required double allocated,
    required String createdBy,
    required String createdByName,
    required String? partnerUid,
  }) async {
    final solo = partnerUid == null || partnerUid.isEmpty;
    final categoryRef = _refs.categories(householdId).doc();

    final batch = db.batch();
    batch.set(categoryRef, {
      'budgetId': budgetId,
      'name': name.trim(),
      'emoji': emoji,
      'allocated': allocated,
      'status':
          solo ? AllocationStatus.approved.name : AllocationStatus.pending.name,
      'createdBy': createdBy,
      'confirmedBy': partnerUid ?? '',
      'decisionNote': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (solo) 'decidedAt': FieldValue.serverTimestamp(),
    });

    if (!solo) {
      batch.set(_refs.approvals(householdId).doc(), {
        ...Approval(
          id: '',
          kind: ApprovalKind.categoryAllocation,
          budgetId: budgetId,
          categoryId: categoryRef.id,
          title: '$emoji ${name.trim()}',
          summary: '$createdByName allocated a new category in $budgetName.',
          amount: allocated,
          previousAmount: null,
          requestedBy: createdBy,
          requestedFor: partnerUid,
          status: AllocationStatus.pending,
          decisionNote: '',
          createdAt: null,
          decidedAt: null,
        ).toJson(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    return categoryRef.id;
  }

  /// Editing the amount re-opens confirmation; renaming or restyling does not.
  Future<void> update({
    required String householdId,
    required SpendCategory existing,
    required String budgetName,
    required String name,
    required String emoji,
    required double allocated,
    required String editedBy,
    required String editedByName,
    required String? partnerUid,
  }) async {
    final amountChanged = allocated != existing.allocated;
    final solo = partnerUid == null || partnerUid.isEmpty;
    final needsReconfirm = amountChanged && !solo;

    final batch = db.batch();
    batch.update(_refs.category(householdId, existing.id), {
      'name': name.trim(),
      'emoji': emoji,
      'allocated': allocated,
      'updatedAt': FieldValue.serverTimestamp(),
      if (needsReconfirm) ...{
        'status': AllocationStatus.pending.name,
        'confirmedBy': partnerUid,
        'decisionNote': '',
        'decidedAt': null,
      },
    });

    if (needsReconfirm) {
      // Supersede any request still sitting in the inbox for this category.
      final outstanding = await _refs
          .approvals(householdId)
          .where('categoryId', isEqualTo: existing.id)
          .where('status', isEqualTo: AllocationStatus.pending.name)
          .get();
      for (final doc in outstanding.docs) {
        batch.delete(doc.reference);
      }

      batch.set(_refs.approvals(householdId).doc(), {
        ...Approval(
          id: '',
          kind: ApprovalKind.allocationChange,
          budgetId: existing.budgetId,
          categoryId: existing.id,
          title: '$emoji ${name.trim()}',
          summary: '$editedByName changed this allocation in $budgetName.',
          amount: allocated,
          previousAmount: existing.allocated,
          requestedBy: editedBy,
          requestedFor: partnerUid,
          status: AllocationStatus.pending,
          decisionNote: '',
          createdAt: null,
          decidedAt: null,
        ).toJson(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Removes the category but keeps its spending: expenses are detached rather
  /// than deleted, so the ledger and the month's total stay honest.
  Future<void> delete({
    required String householdId,
    required String categoryId,
  }) async {
    final expenses = await _refs
        .expenses(householdId)
        .where('categoryId', isEqualTo: categoryId)
        .get();
    final approvals = await _refs
        .approvals(householdId)
        .where('categoryId', isEqualTo: categoryId)
        .get();

    final batch = db.batch();
    for (final doc in expenses.docs) {
      batch.update(doc.reference, {'categoryId': ''});
    }
    for (final doc in approvals.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_refs.category(householdId, categoryId));
    await batch.commit();
  }
}
