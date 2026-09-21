import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/expense.dart';
import 'firestore_refs.dart';

class ExpenseRepository {
  ExpenseRepository(this.db, this._refs);

  final FirebaseFirestore db;
  final FirestoreRefs _refs;

  /// The whole household's ledger for one period - both members, always.
  Stream<List<Expense>> watchForPeriod(String householdId, String period) {
    return _refs
        .expenses(householdId)
        .where('period', isEqualTo: period)
        .orderBy('spentAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Expense.fromDoc).toList());
  }

  /// All-time entries for several budgets at once - how a saving pot's running
  /// total is read. Saving pots are not period-scoped, so this is what gives
  /// them a running total.
  Stream<List<Expense>> watchForBudgets(
    String householdId,
    List<String> budgetIds,
  ) {
    if (budgetIds.isEmpty) return Stream.value(const []);
    return _refs
        .expenses(householdId)
        .where('budgetId', whereIn: budgetIds.take(30).toList())
        .snapshots()
        .map(
          (snap) => snap.docs.map(Expense.fromDoc).toList()
            ..sort((a, b) => b.spentAt.compareTo(a.spentAt)),
        );
  }

  Future<String> add(String householdId, Expense expense) async {
    final ref = _refs.expenses(householdId).doc();
    await ref.set({
      ...expense.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> update(String householdId, Expense expense) {
    return _refs.expense(householdId, expense.id).update({
      ...expense.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String householdId, String expenseId) =>
      _refs.expense(householdId, expenseId).delete();
}
