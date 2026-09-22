import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/money_request.dart';
import '../models/spend_category.dart';
import 'firestore_refs.dart';

/// All reads and writes for money requests.
///
/// ---------------------------------------------------------------------------
/// WHAT A "REPOSITORY" IS HERE
/// ---------------------------------------------------------------------------
/// A plain Dart class that owns every query for one collection. Screens never
/// talk to Firestore directly; they call a repository. Two reasons:
///
///   1. Every query for money requests lives in one file, so when a query needs
///      a database index you know exactly where to look.
///   2. Screens stay about layout. A widget that also builds queries becomes
///      very hard to change later.
///
/// ---------------------------------------------------------------------------
/// STREAMS VS FUTURES
/// ---------------------------------------------------------------------------
/// `Future<T>` = one value, later ("fetch this once").
/// `Stream<T>`  = many values over time ("tell me whenever this changes").
///
/// `.snapshots()` returns a Stream, which is why this app feels live: when your
/// partner approves a request on their phone, Firestore pushes the new document
/// to yours, the Stream emits, and the widgets listening to it rebuild. Nobody
/// writes refresh logic.
class MoneyRequestRepository {
  MoneyRequestRepository(this.db, this._refs);

  final FirebaseFirestore db;

  /// Holds the collection paths. The leading underscore makes it private to
  /// this file - that is Dart's only privacy marker, there is no `private`
  /// keyword.
  final FirestoreRefs _refs;

  /// Approved transfers for one month.
  ///
  /// `PeriodSummary` reads this to move money between budgets when it adds the
  /// month up. Only approved ones count: a pending request has not moved
  /// anything yet, and a declined one never will.
  Stream<List<MoneyRequest>> watchApprovedForPeriod(
    String householdId,
    String period,
  ) {
    return _refs
        .moneyRequests(householdId)
        .where('period', isEqualTo: period)
        .where('status', isEqualTo: AllocationStatus.approved.name)
        .snapshots()
        // `.map` converts each emission of the stream. Here every Firestore
        // snapshot (a bag of raw documents) becomes a tidy List<MoneyRequest>,
        // so nothing above this line ever sees Firestore types.
        .map((snap) => snap.docs.map(MoneyRequest.fromDoc).toList());
  }

  /// Requests waiting for [uid] to decide - their inbox.
  Stream<List<MoneyRequest>> watchInbox(String householdId, String uid) {
    return _refs
        .moneyRequests(householdId)
        .where('requestedFor', isEqualTo: uid)
        .where('status', isEqualTo: AllocationStatus.pending.name)
        .snapshots()
        .map(
          (snap) => snap.docs.map(MoneyRequest.fromDoc).toList()
            // Sorting here rather than with Firestore's `orderBy` keeps this
            // query on simple indexes. Fine for a handful of rows; for
            // thousands you would sort in the database instead.
            ..sort(_newestFirst),
        );
  }

  /// Requests [uid] has sent and not heard back on.
  Stream<List<MoneyRequest>> watchOutbox(String householdId, String uid) {
    return _refs
        .moneyRequests(householdId)
        .where('requestedBy', isEqualTo: uid)
        .where('status', isEqualTo: AllocationStatus.pending.name)
        .snapshots()
        .map(
          (snap) => snap.docs.map(MoneyRequest.fromDoc).toList()
            ..sort(_newestFirst),
        );
  }

  /// Sends a request. Returns the new document's id.
  ///
  /// `.doc()` with no argument does not touch the network - it generates a
  /// random id locally, so the id is known before the write is sent.
  Future<String> send(String householdId, MoneyRequest request) async {
    final ref = _refs.moneyRequests(householdId).doc();
    await ref.set({
      // The spread operator `...` copies every entry of the map returned by
      // toJson() into this new map, so the two lines below sit alongside them.
      ...request.toJson(),
      // Resolved by Firestore's clock on write, not by this phone's.
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Records the source controller's decision.
  ///
  /// Only three fields change; the security rules enforce exactly that, so a
  /// buggy or modified client cannot also rewrite the amount while approving.
  Future<void> decide({
    required String householdId,
    required MoneyRequest request,
    required bool approved,
    String note = '',
  }) {
    return _refs.moneyRequest(householdId, request.id).update({
      'status':
          (approved ? AllocationStatus.approved : AllocationStatus.rejected)
              .name,
      'decisionNote': note.trim(),
      'decidedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Withdraws a request that has not been answered yet.
  ///
  /// Safe to delete outright, unlike a category's approval: a money request
  /// stands alone, so removing it leaves nothing half-finished behind.
  Future<void> withdraw(String householdId, String requestId) =>
      _refs.moneyRequest(householdId, requestId).delete();

  /// Sort comparator: newest first.
  ///
  /// `createdAt` is null for the moment between the local write and the
  /// server's timestamp coming back, so nulls fall back to the epoch.
  static int _newestFirst(MoneyRequest a, MoneyRequest b) =>
      (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
}
