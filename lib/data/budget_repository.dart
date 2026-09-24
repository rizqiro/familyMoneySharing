import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/budget.dart';
import '../models/spend_category.dart';
import 'firestore_refs.dart';

/// Every query and write for budgets.
///
/// A budget is a pot of money with exactly one controller. Monthly budgets are
/// scoped to a month; saving pots carry across months and use the sentinel
/// `periodKey` of "saving" so one query picks up both kinds at once.
///
/// Note [delete]: removing a budget also removes its categories, its expenses
/// and its approvals. Firestore has no cascade, so the sweep is done here by
/// hand in a batch - without it the ledger would keep rows pointing at a budget
/// that no longer exists.
class BudgetRepository {
  BudgetRepository(this.db, this._refs);

  final FirebaseFirestore db;
  final FirestoreRefs _refs;

  /// Saving budgets are not scoped to a month, so they carry this sentinel in
  /// `periodKey` and are picked up by every period's query.
  static const savingKey = 'saving';

  static String periodKeyFor(Budget budget) =>
      budget.isSaving ? savingKey : (budget.period ?? '');

  /// Monthly budgets for [period] plus every saving budget, in one query.
  Stream<List<Budget>> watchForPeriod(String householdId, String period) {
    return _refs
        .budgets(householdId)
        .where('periodKey', whereIn: [period, savingKey])
        .snapshots()
        .map((snap) {
          final budgets = snap.docs
              .map(Budget.fromDoc)
              .where((b) => !b.archived)
              .toList()
            ..sort(_byKindThenName);
          return budgets;
        });
  }

  /// Creates a budget, optionally with a set of empty categories already in it.
  ///
  /// [seedCategories] is how a saving pot arrives with Education / Emergency
  /// fund / Other already set up. They are created with an allocation of zero
  /// and already approved, deliberately:
  ///
  ///   * zero, because seeding them with money would be inventing a plan
  ///     nobody agreed to; and
  ///   * approved, because asking your partner to confirm an allocation of
  ///     nothing is a notification that says nothing.
  ///
  /// The names are passed in rather than written here because they have to be
  /// in the household's language, and a repository has no business knowing
  /// which language that is.
  ///
  /// Everything goes in one batch, so a pot can never exist with only some of
  /// its categories.
  Future<String> create(
    String householdId,
    Budget budget, {
    List<(String, String)> seedCategories = const [],
  }) async {
    final ref = _refs.budgets(householdId).doc();

    final batch = db.batch();
    batch.set(ref, {
      ...budget.toJson(),
      'periodKey': periodKeyFor(budget),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (final (emoji, name) in seedCategories) {
      batch.set(_refs.categories(householdId).doc(), {
        'budgetId': ref.id,
        'name': name,
        'emoji': emoji,
        'allocated': 0.0,
        'status': 'approved',
        'createdBy': budget.createdBy,
        'confirmedBy': '',
        'decisionNote': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'decidedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    return ref.id;
  }

  Future<void> update(String householdId, Budget budget) {
    return _refs.budget(householdId, budget.id).update({
      ...budget.toJson(),
      'periodKey': periodKeyFor(budget),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Removes the budget together with everything filed under it. Without this
  /// the ledger would keep rows pointing at a budget that no longer exists.
  Future<void> delete(String householdId, String budgetId) async {
    final categories = await _refs
        .categories(householdId)
        .where('budgetId', isEqualTo: budgetId)
        .get();
    final expenses = await _refs
        .expenses(householdId)
        .where('budgetId', isEqualTo: budgetId)
        .get();
    final approvals = await _refs
        .approvals(householdId)
        .where('budgetId', isEqualTo: budgetId)
        .get();

    final batch = db.batch();
    for (final doc in [
      ...categories.docs,
      ...expenses.docs,
      ...approvals.docs,
    ]) {
      batch.delete(doc.reference);
    }
    batch.delete(_refs.budget(householdId, budgetId));
    await batch.commit();
  }

  /// Copies [from]'s monthly budgets and their confirmed categories into
  /// [to], so a new month opens with last month's plan instead of nothing.
  ///
  /// Only budgets [actorUid] controls are copied - creating a category needs
  /// control of its budget, so each member rolls over their own.
  ///
  /// Copied categories start confirmed: both members already agreed to these
  /// amounts, and re-confirming an unchanged plan every month is noise.
  Future<int> rollover({
    required String householdId,
    required String from,
    required String to,
    required String actorUid,
  }) async {
    final existing = await _refs
        .budgets(householdId)
        .where('periodKey', isEqualTo: to)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return 0;

    final source = await _refs
        .budgets(householdId)
        .where('periodKey', isEqualTo: from)
        .get();
    final sourceBudgets = source.docs
        .map(Budget.fromDoc)
        .where((b) => !b.archived && b.controllerId == actorUid)
        .toList();
    if (sourceBudgets.isEmpty) return 0;

    final categories = await _refs
        .categories(householdId)
        .where('budgetId', whereIn: sourceBudgets.map((b) => b.id).toList())
        .get();

    final batch = db.batch();
    for (final budget in sourceBudgets) {
      final newRef = _refs.budgets(householdId).doc();
      batch.set(newRef, {
        ...budget.copyWith(period: to).toJson(),
        'periodKey': to,
        'createdBy': actorUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'rolledOverFrom': budget.id,
      });

      final children = categories.docs
          .map(SpendCategory.fromDoc)
          .where((c) => c.budgetId == budget.id && c.isApproved);

      for (final category in children) {
        batch.set(_refs.categories(householdId).doc(), {
          ...category.toJson(),
          'budgetId': newRef.id,
          'status': AllocationStatus.approved.name,
          'createdBy': actorUid,
          'decidedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
    return sourceBudgets.length;
  }

  static int _byKindThenName(Budget a, Budget b) {
    if (a.kind != b.kind) return a.isSaving ? 1 : -1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
}
