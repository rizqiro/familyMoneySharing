import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/household.dart';
import '../models/invite.dart';
import 'firestore_refs.dart';

class HouseholdFailure implements Exception {
  const HouseholdFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Households, and the pairing handshake that joins two accounts.
///
/// The interesting part is [acceptInvite]. The joiner is not a member yet, so
/// membership cannot be the permission check - possession of a live invite code
/// is. The code travels in the write itself (`joinedVia`) and the security
/// rules read it back to verify. That is also why the household document is
/// deliberately NOT read there: only members may read one.
class HouseholdRepository {
  HouseholdRepository(this.db, this._refs);

  final FirebaseFirestore db;
  final FirestoreRefs _refs;

  /// Two people. The confirmation flow ("notify the other party") only has a
  /// well-defined counterparty while a household is a pair.
  static const maxMembers = 2;

  Stream<Household?> watch(String householdId) =>
      _refs.household(householdId).snapshots().map(
            (doc) => doc.exists ? Household.fromDoc(doc) : null,
          );

  /// Creates the user's own space. Called once, right after sign-up.
  Future<String> create({
    required AppUser user,
    required String name,
    String currencyCode = 'IDR',
    int monthStartDay = 1,
  }) async {
    final ref = _refs.households.doc();
    final batch = db.batch();

    batch.set(ref, {
      'name': name.trim().isEmpty ? 'Our household' : name.trim(),
      'memberIds': [user.uid],
      'members': {
        user.uid: HouseholdMember(
          uid: user.uid,
          displayName: user.displayName,
          email: user.email,
        ).toJson(),
      },
      'currencyCode': currencyCode,
      'monthStartDay': monthStartDay,
      'activeInviteCode': null,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_refs.user(user.uid), {'householdId': ref.id});

    await batch.commit();
    return ref.id;
  }

  /// Mints a single-use code for the partner to scan or type.
  ///
  /// Any previous unused code for this household is revoked first, so only one
  /// live code exists at a time.
  Future<Invite> createInvite({
    required Household household,
    required AppUser inviter,
  }) async {
    if (household.memberIds.length >= maxMembers) {
      throw const HouseholdFailure(
        'This household already has two members.',
      );
    }

    final invite = Invite(
      code: Invite.generateCode(),
      householdId: household.id,
      householdName: household.name,
      createdBy: inviter.uid,
      createdByName: inviter.displayName,
      expiresAt: DateTime.now().add(Invite.validity),
      acceptedBy: null,
      createdAt: null,
    );

    final batch = db.batch();
    // The household points at its one live code, so replacing it never needs
    // a query across the invites collection.
    if (household.activeInviteCode != null) {
      batch.delete(_refs.invite(household.activeInviteCode!));
    }
    batch.set(_refs.invite(invite.code), {
      ...invite.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_refs.household(household.id), {
      'activeInviteCode': invite.code,
    });

    await batch.commit();
    return invite;
  }

  Future<Invite> lookupInvite(String rawCode) async {
    final code = Invite.codeFromScan(rawCode);
    if (code == null) {
      throw const HouseholdFailure('That does not look like an invite code.');
    }

    final doc = await _refs.invite(code).get();
    if (!doc.exists) {
      throw const HouseholdFailure(
        'No invite with that code. Ask for a fresh one.',
      );
    }

    final invite = Invite.fromDoc(doc);
    if (invite.isUsed) {
      throw const HouseholdFailure('That invite has already been used.');
    }
    if (invite.isExpired) {
      throw const HouseholdFailure(
        'That invite has expired. Ask your partner for a new code.',
      );
    }
    return invite;
  }

  /// Joins [invite]'s household and leaves the user's own empty one behind.
  Future<void> acceptInvite({
    required Invite invite,
    required AppUser joiner,
  }) async {
    if (joiner.householdId == invite.householdId) return;
    if (invite.createdBy == joiner.uid) {
      throw const HouseholdFailure('That is your own invite code.');
    }

    // Done before the join, while the user still has permission to touch it.
    final previous = joiner.householdId;
    if (previous != null && previous.isNotEmpty) {
      await _discardIfAbandoned(previous, joiner.uid);
    }

    // The household is deliberately not read here: only members may read one,
    // and the joiner is not a member yet. Everything the write needs comes from
    // the invite, and the rules re-check it against the stored document.
    try {
      await _claim(invite: invite, joiner: joiner);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const HouseholdFailure(
          'That invite was refused. It may have just been used, expired, or '
          'the household may already have two members. Ask for a fresh code.',
        );
      }
      rethrow;
    }
  }

  Future<void> _claim({
    required Invite invite,
    required AppUser joiner,
  }) {
    return db.runTransaction((tx) async {
      final inviteSnap = await tx.get(_refs.invite(invite.code));
      if (!inviteSnap.exists) {
        throw const HouseholdFailure('That invite no longer exists.');
      }

      final fresh = Invite.fromDoc(inviteSnap);
      if (!fresh.isUsable) {
        throw const HouseholdFailure(
          'That invite is no longer valid. Ask for a new code.',
        );
      }

      // Written out in full rather than with arrayUnion, so the rules can check
      // the resulting membership directly. An invite only exists while the
      // household has one member, so the pair is always inviter + joiner.
      tx.update(_refs.household(fresh.householdId), {
        'memberIds': [fresh.createdBy, joiner.uid],
        'members.${joiner.uid}': HouseholdMember(
          uid: joiner.uid,
          displayName: joiner.displayName,
          email: joiner.email,
        ).toJson(),
        // The security rules read this back to verify the joiner really holds
        // a live invite for this household - they are not a member yet, so
        // membership cannot be the check here.
        'joinedVia': invite.code,
        'activeInviteCode': null,
      });
      tx.update(_refs.user(joiner.uid), {'householdId': fresh.householdId});
      tx.update(_refs.invite(invite.code), {
        'acceptedBy': joiner.uid,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Unlinks the two accounts. Shared history stays with the household so the
  /// remaining member keeps their records.
  Future<void> leave({
    required String householdId,
    required String uid,
  }) async {
    final batch = db.batch();
    batch.update(_refs.household(householdId), {
      'memberIds': FieldValue.arrayRemove([uid]),
      'members.$uid': FieldValue.delete(),
    });
    batch.update(_refs.user(uid), {'householdId': null});
    await batch.commit();
  }

  /// Leaves the household as part of deleting an account.
  ///
  /// =============================================================================
  /// WHO KEEPS THE SHARED RECORDS
  /// =============================================================================
  /// Three cases, and the difference between them is the whole feature:
  ///
  ///   * **Alone in the household** - everything goes with you. Nobody else is
  ///     losing anything, so there is nothing to ask about.
  ///   * **A partner remains, and you asked for a clean break** - you leave,
  ///     and a request is left behind for them to agree to. They decide.
  ///   * **A partner remains and you did not ask** - you leave, they keep the
  ///     budgets and the ledger. Those are their records too.
  ///
  /// Your own entries stay in the shared ledger in the last two cases, under
  /// the name the household already had a copy of. Deleting them would silently
  /// rewrite your partner's spending history for months they have already
  /// closed - and their budget totals would stop matching what they lived
  /// through.
  Future<void> departForDeletion({
    required String householdId,
    required String uid,
    required String displayName,
    required bool askToEraseShared,
  }) async {
    final snap = await _refs.household(householdId).get();
    if (!snap.exists) return;

    final household = Household.fromDoc(snap);
    final alone = household.memberIds.length <= 1;

    if (alone) {
      await eraseEverything(householdId);
      return;
    }

    final batch = db.batch();
    batch.update(_refs.household(householdId), {
      'memberIds': FieldValue.arrayRemove([uid]),
      'members.$uid': FieldValue.delete(),
      if (askToEraseShared) ...{
        'eraseRequestedBy': uid,
        'eraseRequestedByName': displayName,
      },
    });
    await batch.commit();
  }

  /// Records that the person left behind wants the shared records gone too.
  Future<void> confirmErase(String householdId) => eraseEverything(householdId);

  /// Keeps everything and clears the request.
  Future<void> declineErase(String householdId) =>
      _refs.household(householdId).update({
        'eraseRequestedBy': '',
        'eraseRequestedByName': '',
      });

  /// Deletes the household and every document filed under it.
  ///
  /// =============================================================================
  /// WHY THIS IS DONE BY HAND
  /// =============================================================================
  /// Firestore has no cascade. Deleting the household document would leave the
  /// budgets, categories, entries, approvals and money requests sitting there
  /// forever - invisible to the app, still on the bill, and still holding
  /// somebody's financial history. "Delete my data" has to mean it.
  ///
  /// Batches cap at 500 operations, so this commits in chunks rather than one
  /// go: a household with a couple of years of entries will exceed that.
  ///
  /// Not transactional. If it fails halfway the household is left partly
  /// erased, which is recoverable by running it again - and is much better than
  /// the alternative of not deleting anything.
  Future<void> eraseEverything(String householdId) async {
    final collections = [
      _refs.expenses(householdId),
      _refs.categories(householdId),
      _refs.budgets(householdId),
      _refs.approvals(householdId),
      _refs.moneyRequests(householdId),
    ];

    for (final collection in collections) {
      // Paged, so a long ledger does not have to fit in memory at once.
      while (true) {
        final page = await collection.limit(300).get();
        if (page.docs.isEmpty) break;

        final batch = db.batch();
        for (final doc in page.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        if (page.docs.length < 300) break;
      }
    }

    await _refs.household(householdId).delete();
  }

  Future<void> updateSettings({
    required String householdId,
    String? name,
    String? currencyCode,
    int? monthStartDay,
  }) {
    return _refs.household(householdId).update({
      if (name != null) 'name': name.trim(),
      if (currencyCode != null) 'currencyCode': currencyCode,
      if (monthStartDay != null) 'monthStartDay': monthStartDay,
    });
  }

  /// Deletes the user's old household only when nothing would be lost: they
  /// were alone in it and it holds no budgets or expenses.
  Future<void> _discardIfAbandoned(String householdId, String uid) async {
    final snap = await _refs.household(householdId).get();
    if (!snap.exists) return;

    final household = Household.fromDoc(snap);
    final soloOwner =
        household.memberIds.length == 1 && household.memberIds.first == uid;

    if (!soloOwner) {
      await leave(householdId: householdId, uid: uid);
      return;
    }

    final budgets = await _refs.budgets(householdId).limit(1).get();
    final expenses = await _refs.expenses(householdId).limit(1).get();
    if (budgets.docs.isEmpty && expenses.docs.isEmpty) {
      await _refs.household(householdId).delete();
    }
  }
}
