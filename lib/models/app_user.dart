import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/i18n/app_language.dart';

/// A signed-in person.
///
/// This is the private, per-person document. Anything shared between the two
/// members - budgets, expenses, the currency - lives on the household instead.
/// The split matters for permissions: `users/{uid}` is readable only by its
/// owner, so nothing here is visible to a partner.
///
/// [language] is per person on purpose. One of you may prefer Banjar while the
/// other reads Indonesian; the app is not the place to make that a joint
/// decision.
class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.householdId,
    required this.language,
    required this.createdAt,
  });

  final String uid;
  final String displayName;
  final String email;

  /// Null until they create or join a household.
  final String? householdId;

  /// Which language the interface is shown in, for this person only.
  final AppLanguage language;

  final DateTime? createdAt;

  bool get hasHousehold => householdId != null && householdId!.isNotEmpty;

  /// First letter of the name, for the avatar circle.
  String get initial =>
      displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return AppUser(
      uid: doc.id,
      displayName: (data['displayName'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      householdId: data['householdId'] as String?,
      // Accounts created before the language picker existed have no field
      // here, and `fromCode` turns that null into the default.
      language: AppLanguage.fromCode(data['language'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateJson() => {
        'displayName': displayName,
        'email': email,
        'householdId': householdId,
        'language': language.code,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
