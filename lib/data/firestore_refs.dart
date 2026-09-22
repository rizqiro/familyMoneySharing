import 'package:cloud_firestore/cloud_firestore.dart';

typedef Json = Map<String, dynamic>;
typedef JsonDoc = DocumentReference<Json>;
typedef JsonCollection = CollectionReference<Json>;
typedef JsonQuery = Query<Json>;

/// Every path in one place, so the security rules and the client agree on the
/// shape of the database.
///
/// Household-scoped data is nested under the household document: membership is
/// then the only check a rule has to make.
class FirestoreRefs {
  const FirestoreRefs(this.db);

  final FirebaseFirestore db;

  JsonCollection get users => db.collection('users');

  JsonDoc user(String uid) => users.doc(uid);

  JsonCollection get households => db.collection('households');

  JsonDoc household(String householdId) => households.doc(householdId);

  JsonCollection budgets(String householdId) =>
      household(householdId).collection('budgets');

  JsonDoc budget(String householdId, String budgetId) =>
      budgets(householdId).doc(budgetId);

  JsonCollection categories(String householdId) =>
      household(householdId).collection('categories');

  JsonDoc category(String householdId, String categoryId) =>
      categories(householdId).doc(categoryId);

  JsonCollection expenses(String householdId) =>
      household(householdId).collection('expenses');

  JsonDoc expense(String householdId, String expenseId) =>
      expenses(householdId).doc(expenseId);

  JsonCollection approvals(String householdId) =>
      household(householdId).collection('approvals');

  JsonDoc approval(String householdId, String approvalId) =>
      approvals(householdId).doc(approvalId);

  /// Asks to move money from one member's budget to the other's.
  ///
  /// Kept apart from `approvals` (which is about category allocations) because
  /// the two answer different questions and carry different fields. One
  /// collection holding both would mean every read filtering on a "kind" field
  /// and half the properties being null.
  JsonCollection moneyRequests(String householdId) =>
      household(householdId).collection('moneyRequests');

  JsonDoc moneyRequest(String householdId, String requestId) =>
      moneyRequests(householdId).doc(requestId);

  /// Top-level: an invitee must be able to read the code *before* they are a
  /// member of anything.
  JsonCollection get invites => db.collection('invites');

  JsonDoc invite(String code) => invites.doc(code);
}
