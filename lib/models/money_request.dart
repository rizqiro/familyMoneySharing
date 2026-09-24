import 'package:cloud_firestore/cloud_firestore.dart';

import 'spend_category.dart';

/// One person asking the other to move money between two budgets.
///
/// ---------------------------------------------------------------------------
/// WHY THIS EXISTS
/// ---------------------------------------------------------------------------
/// Only a budget's controller may spend from it. That rule is what keeps the
/// ledger honest, but on its own it leaves you stuck: if your partner holds all
/// the money, you have no way to buy anything. This is the way out - you ask,
/// they decide.
///
/// ---------------------------------------------------------------------------
/// HOW THE TRANSFER WORKS (important, and slightly surprising)
/// ---------------------------------------------------------------------------
/// Approving a request does NOT rewrite either budget's `amount` field. It only
/// flips this document's `status` to `approved`.
///
/// The transfer is then applied when the app adds up the month, in
/// `PeriodSummary.build`: the source budget's usable total goes down by
/// [amount] and the destination's goes up by the same. Think of it as an entry
/// in a ledger rather than two edits.
///
/// The reason is permissions. In Firestore, a budget may only be edited by the
/// person who controls it (see `firebase/firestore.rules`). The approver
/// controls the SOURCE budget but not the DESTINATION, so a design that edited
/// both would need one of them to write to a document they are not allowed to
/// touch. Keeping the transfer as a record that both sides read sidesteps that
/// entirely - each person only ever writes what is theirs.
///
/// ---------------------------------------------------------------------------
/// DART NOTE
/// ---------------------------------------------------------------------------
/// Every field is `final`, so an instance can never change after it is built.
/// To represent a change you create a new object. This is the normal style in
/// Flutter: widgets rebuild from fresh data rather than mutating it in place,
/// which makes it much harder for two parts of the screen to disagree.
class MoneyRequest {
  const MoneyRequest({
    required this.id,
    required this.fromBudgetId,
    required this.fromBudgetName,
    required this.toBudgetId,
    required this.toBudgetName,
    this.fromCategoryId = '',
    this.fromCategoryName = '',
    required this.amount,
    required this.reason,
    required this.period,
    required this.requestedBy,
    required this.requestedByName,
    required this.requestedFor,
    required this.status,
    required this.decisionNote,
    required this.createdAt,
    required this.decidedAt,
  });

  /// The Firestore document id. Empty for an object not saved yet.
  final String id;

  /// The budget the money comes out of - controlled by [requestedFor].
  final String fromBudgetId;

  /// Budget names are copied in ("denormalised") so the inbox can render a
  /// request without a second read per row. The cost is that a renamed budget
  /// leaves an old name on old requests, which is fine for a historical record.
  final String fromBudgetName;

  /// The budget the money lands in - controlled by [requestedBy].
  final String toBudgetId;
  final String toBudgetName;

  /// Which category of the source budget the money was taken out of, chosen by
  /// the approver - or empty when it came out of the budget's unallocated
  /// slack.
  ///
  /// =============================================================================
  /// WHY THE APPROVER PICKS A CATEGORY AND NOT THE ASKER
  /// =============================================================================
  /// The asker has no business deciding which of someone else's categories
  /// gets raided - they may not even agree it is the right one. But somebody
  /// has to decide, because a budget with every rupiah already carved into
  /// categories has nothing spare: granting the request out of thin air would
  /// quietly leave the categories adding up to more than the budget holds.
  ///
  /// So the choice is made at the moment of approval, by the one person who
  /// knows what the budget is for. It is only demanded when the slack is too
  /// small; with money still unallocated, that is where it comes from and
  /// these stay empty.
  final String fromCategoryId;
  final String fromCategoryName;

  final double amount;

  /// Free text: "school shoes", "petrol this week".
  final String reason;

  /// `YYYY-MM`. Both budgets belong to this month, so the whole month's
  /// transfers can be fetched with one query.
  final String period;

  final String requestedBy;
  final String requestedByName;

  /// The person who decides: the controller of [fromBudgetId].
  final String requestedFor;

  /// Reused from categories so both kinds of inbox item share one vocabulary.
  final AllocationStatus status;
  final String decisionNote;
  final DateTime? createdAt;
  final DateTime? decidedAt;

  bool get isPending => status == AllocationStatus.pending;
  bool get isApproved => status == AllocationStatus.approved;
  bool get isRejected => status == AllocationStatus.rejected;

  /// True when the approver named a category to take the money from.
  bool get hasSourceCategory => fromCategoryId.isNotEmpty;

  /// Was this request made by [uid]?
  bool wasAskedBy(String? uid) => uid != null && requestedBy == uid;

  /// Builds an instance from a Firestore document.
  ///
  /// `factory` means this constructor may do work before returning, rather than
  /// just assigning fields. Every read is defensive - `as String?` then `?? ''`
  /// - because a document written by an older version of the app may be missing
  /// a field, and a null landing in a non-nullable field crashes the app.
  factory MoneyRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return MoneyRequest(
      id: doc.id,
      fromBudgetId: (data['fromBudgetId'] as String?) ?? '',
      fromBudgetName: (data['fromBudgetName'] as String?) ?? 'their budget',
      toBudgetId: (data['toBudgetId'] as String?) ?? '',
      toBudgetName: (data['toBudgetName'] as String?) ?? 'your budget',
      fromCategoryId: (data['fromCategoryId'] as String?) ?? '',
      fromCategoryName: (data['fromCategoryName'] as String?) ?? '',
      // Firestore returns whole numbers as int and decimals as double. `num` is
      // the shared supertype of both, so this reads either without crashing.
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      reason: (data['reason'] as String?) ?? '',
      period: (data['period'] as String?) ?? '',
      requestedBy: (data['requestedBy'] as String?) ?? '',
      requestedByName: (data['requestedByName'] as String?) ?? 'Partner',
      requestedFor: (data['requestedFor'] as String?) ?? '',
      status: AllocationStatus.parse(data['status'] as String?),
      decisionNote: (data['decisionNote'] as String?) ?? '',
      // Firestore has its own Timestamp type; convert to Dart's DateTime so the
      // rest of the app never has to know about it.
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      decidedAt: (data['decidedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// The shape written back to Firestore.
  ///
  /// `id` is deliberately absent: it is the document's name, not a field inside
  /// it. `createdAt` is also absent - the repository adds it as a server
  /// timestamp so the time comes from Google's clock, not from a phone whose
  /// clock might be wrong.
  Map<String, dynamic> toJson() => {
        'fromBudgetId': fromBudgetId,
        'fromBudgetName': fromBudgetName,
        'toBudgetId': toBudgetId,
        'toBudgetName': toBudgetName,
        'amount': amount,
        'reason': reason,
        'period': period,
        'requestedBy': requestedBy,
        'requestedByName': requestedByName,
        'requestedFor': requestedFor,
        'status': status.name,
        'decisionNote': decisionNote,
      };
}
