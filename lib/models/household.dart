import 'package:cloud_firestore/cloud_firestore.dart';

/// A member's display data, denormalised onto the household so every screen
/// can label "who spent this" without a second read per row.
class HouseholdMember {
  const HouseholdMember({
    required this.uid,
    required this.displayName,
    required this.email,
  });

  final String uid;
  final String displayName;
  final String email;

  String get initial =>
      displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();

  factory HouseholdMember.fromJson(String uid, Map<String, dynamic> json) {
    return HouseholdMember(
      uid: uid,
      displayName: (json['displayName'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'email': email,
      };
}

/// The shared space. Everything else in Firestore lives underneath one of
/// these, and membership is the single access-control check.
class Household {
  const Household({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.members,
    required this.currencyCode,
    required this.monthStartDay,
    required this.activeInviteCode,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String name;
  final List<String> memberIds;
  final Map<String, HouseholdMember> members;
  final String currencyCode;

  /// Day of month the budgeting period rolls over. 1 = calendar month.
  final int monthStartDay;

  /// The one live pairing code, or null. Kept here so minting a replacement
  /// never has to query the invites collection.
  final String? activeInviteCode;
  final String createdBy;
  final DateTime? createdAt;

  bool get isPaired => memberIds.length > 1;

  HouseholdMember? member(String uid) => members[uid];

  String displayNameOf(String uid) =>
      members[uid]?.displayName.trim().isNotEmpty == true
          ? members[uid]!.displayName
          : 'Someone';

  /// The other person in a two-person household, if there is one.
  HouseholdMember? partnerOf(String uid) {
    for (final id in memberIds) {
      if (id != uid) return members[id];
    }
    return null;
  }

  factory Household.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final rawMembers = (data['members'] as Map<String, dynamic>?) ?? const {};
    return Household(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Our household',
      memberIds: List<String>.from(
        (data['memberIds'] as List<dynamic>?) ?? const [],
      ),
      members: rawMembers.map(
        (uid, value) => MapEntry(
          uid,
          HouseholdMember.fromJson(uid, Map<String, dynamic>.from(value as Map)),
        ),
      ),
      currencyCode: (data['currencyCode'] as String?) ?? 'IDR',
      monthStartDay: (data['monthStartDay'] as num?)?.toInt() ?? 1,
      activeInviteCode: data['activeInviteCode'] as String?,
      createdBy: (data['createdBy'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
