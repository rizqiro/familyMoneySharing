import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

/// A short-lived pairing token. The document id *is* the code, so scanning the
/// QR is a single direct read rather than a query.
///
/// The code is a bearer credential: anyone holding it can join the household,
/// which is why it is random, single-use and expires.
class Invite {
  const Invite({
    required this.code,
    required this.householdId,
    required this.householdName,
    required this.createdBy,
    required this.createdByName,
    required this.expiresAt,
    required this.acceptedBy,
    required this.createdAt,
  });

  final String code;
  final String householdId;
  final String householdName;
  final String createdBy;
  final String createdByName;
  final DateTime expiresAt;
  final String? acceptedBy;
  final DateTime? createdAt;

  static const validity = Duration(hours: 24);

  /// Crockford-style alphabet: no O/0, I/1, U - so a code read aloud or typed
  /// by hand cannot land on the wrong document.
  static const _alphabet = '23456789ABCDEFGHJKLMNPQRSTVWXYZ';

  static String generateCode({int length = 8}) {
    final rng = Random.secure();
    return List.generate(
      length,
      (_) => _alphabet[rng.nextInt(_alphabet.length)],
    ).join();
  }

  /// Payload encoded into the QR image. The scanner also accepts a bare code,
  /// so a code typed by hand and a code scanned take the same path.
  String get qrPayload => 'familymoney://join?code=$code';

  static String? codeFromScan(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    final fromQuery = uri?.queryParameters['code'];
    final candidate = (fromQuery ?? trimmed).toUpperCase();

    final cleaned = candidate.replaceAll(RegExp('[^A-Z0-9]'), '');
    if (cleaned.length < 6 || cleaned.length > 12) return null;
    return cleaned;
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isUsed => acceptedBy != null;
  bool get isUsable => !isExpired && !isUsed;

  factory Invite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Invite(
      code: doc.id,
      householdId: (data['householdId'] as String?) ?? '',
      householdName: (data['householdName'] as String?) ?? 'their household',
      createdBy: (data['createdBy'] as String?) ?? '',
      createdByName: (data['createdByName'] as String?) ?? 'Someone',
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      acceptedBy: data['acceptedBy'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'householdId': householdId,
        'householdName': householdName,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'acceptedBy': acceptedBy,
      };
}
