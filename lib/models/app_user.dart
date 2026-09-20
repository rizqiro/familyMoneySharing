import 'package:cloud_firestore/cloud_firestore.dart';

/// A signed-in person. `householdId` is null until they create or join one.
class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.householdId,
    required this.createdAt,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? householdId;
  final DateTime? createdAt;

  bool get hasHousehold => householdId != null && householdId!.isNotEmpty;

  /// First grapheme of the name, for the avatar chip.
  String get initial =>
      displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return AppUser(
      uid: doc.id,
      displayName: (data['displayName'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      householdId: data['householdId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateJson() => {
        'displayName': displayName,
        'email': email,
        'householdId': householdId,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
