import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/expense.dart';
import 'firestore_refs.dart';

/// The shared ledger.
///
/// Both members read every entry - that is the point of the app. Writing is
/// narrower: an expense may only be filed against a budget you control, which
/// the security rules enforce.
///
/// `period` is stored on each expense rather than derived from its date, so a
/// month's ledger is one indexed query instead of a range scan the client has
/// to re-bucket. It also lets a household start its month on payday rather than
/// the 1st without any of this changing.
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

  /// Every entry in one calendar year - what the "Yearly" chart filter reads.
  ///
  /// `period` is a sortable `YYYY-MM` string, so a whole year is a range query
  /// on that one field: everything from `2026-01` to `2026-12` inclusive. A
  /// range filter on a single field needs no composite index, which is why the
  /// period is stored as text rather than as a number or a pair of fields.
  ///
  /// Sorting happens on the client. Firestore would demand a composite index to
  /// order by `spentAt` while filtering on `period`, and a year of one
  /// household's entries is a small enough list to sort in memory.
  Stream<List<Expense>> watchForYear(String householdId, int year) {
    return _refs
        .expenses(householdId)
        .where('period', isGreaterThanOrEqualTo: '$year-01')
        .where('period', isLessThanOrEqualTo: '$year-12')
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
