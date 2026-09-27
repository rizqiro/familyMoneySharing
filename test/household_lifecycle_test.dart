import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_money_sharing/data/firestore_refs.dart';
import 'package:family_money_sharing/data/household_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// What is left in Firestore when a household connection ends.
///
/// =============================================================================
/// THE TRAP THESE EXIST TO PREVENT
/// =============================================================================
/// Every rule in firestore.rules is written in terms of membership. A household
/// with `memberIds: []` matches nobody: `isMember()` is false, `soleMember()`
/// is false, so it cannot be read, written or deleted by ANY account,
/// including the person who created it. It is not hidden, it is stranded -
/// still stored, still billed, still holding a couple's financial history,
/// with no one left who is permitted to remove it.
///
/// `firebase/rules_test/` proves the trap against the real rules engine. These
/// prove the app never walks into it.
void main() {
  const me = 'me';
  const her = 'her';
  const hid = 'h1';

  late FakeFirebaseFirestore db;
  late HouseholdRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = HouseholdRepository(db, FirestoreRefs(db));
  });

  Future<void> seed({required List<String> members}) async {
    await db.collection('households').doc(hid).set({
      'name': 'Home',
      'memberIds': members,
      'members': {
        for (final m in members)
          m: {'uid': m, 'displayName': m, 'email': '$m@x.com'},
      },
      'currencyCode': 'IDR',
      'monthStartDay': 1,
      'createdBy': members.isEmpty ? me : members.first,
    });
    for (final m in members) {
      await db.collection('users').doc(m).set({'householdId': hid});
    }
    await db.collection('households').doc(hid).collection('budgets').doc('b1')
        .set({'name': 'Biaya hidup', 'controllerId': members.first});
    await db.collection('households').doc(hid).collection('expenses').doc('e1')
        .set({'budgetId': 'b1', 'amount': 50000});
  }

  Future<int> count(String sub) async => (await db
          .collection('households')
          .doc(hid)
          .collection(sub)
          .get())
      .docs
      .length;

  Future<bool> householdExists() async =>
      (await db.collection('households').doc(hid).get()).exists;

  group('leaving', () {
    test('with a partner left behind, the records stay with them', () async {
      await seed(members: [me, her]);

      await repo.leave(householdId: hid, uid: me);

      expect(await householdExists(), isTrue);
      expect(await count('budgets'), 1);
      expect(await count('expenses'), 1);

      final left = await db.collection('households').doc(hid).get();
      expect(left.data()!['memberIds'], [her]);
      expect((left.data()!['members'] as Map).containsKey(me), isFalse);

      // And the leaver is unlinked.
      final profile = await db.collection('users').doc(me).get();
      expect(profile.data()!['householdId'], isNull);
    });

    test('as the last one out, the place is erased rather than stranded',
        () async {
      await seed(members: [me]);

      await repo.leave(householdId: hid, uid: me);

      // This is the whole point. Before, memberIds became [] and everything
      // below stayed forever, reachable by nobody.
      expect(await householdExists(), isFalse);
      expect(await count('budgets'), 0);
      expect(await count('expenses'), 0);

      final profile = await db.collection('users').doc(me).get();
      expect(profile.data()!['householdId'], isNull);
    });

    test('nothing is ever left with an empty member list', () async {
      await seed(members: [me]);
      await repo.leave(householdId: hid, uid: me);

      final all = await db.collection('households').get();
      for (final h in all.docs) {
        expect(
          h.data()['memberIds'],
          isNotEmpty,
          reason: 'a household nobody is in can never be deleted again',
        );
      }
    });
  });

  group('isLastMember', () {
    test('true when alone, false when paired', () async {
      await seed(members: [me]);
      expect(await repo.isLastMember(hid, me), isTrue);

      await db.collection('households').doc(hid).update({
        'memberIds': [me, her],
      });
      expect(await repo.isLastMember(hid, me), isFalse);
    });

    test('false for a household that is not there', () async {
      expect(await repo.isLastMember('nope', me), isFalse);
    });
  });

  group('erasing', () {
    test('it takes the invite codes with it', () async {
      await seed(members: [me]);
      await db.collection('households').doc(hid).update({
        'activeInviteCode': 'LIVE1234',
        'joinedVia': 'USED5678',
      });
      await db.collection('invites').doc('LIVE1234').set({
        'householdId': hid,
        'createdBy': me,
      });
      await db.collection('invites').doc('USED5678').set({
        'householdId': hid,
        'createdBy': me,
        'acceptedBy': her,
      });

      await repo.eraseEverything(hid);

      // Invites are a top-level collection, so nothing about deleting the
      // household reached them. They used to outlive it, each still naming
      // the household and who made it.
      expect((await db.collection('invites').get()).docs, isEmpty);
    });

    test('a household with nothing in it still goes', () async {
      await db.collection('households').doc(hid).set({
        'name': 'Home',
        'memberIds': [me],
        'members': <String, Object?>{},
        'currencyCode': 'IDR',
        'monthStartDay': 1,
        'createdBy': me,
      });

      await repo.eraseEverything(hid);
      expect(await householdExists(), isFalse);
    });
  });
}
