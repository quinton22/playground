import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents a mutual match between two users.
/// 
/// Stored in Firestore under:
///   `matches/{dateKey}/{matchId}`
/// 
/// A match is created by the Cloud Function when user A thinks of user B
/// AND user B thinks of user A on the same day.
class MatchModel extends Equatable {
  /// Unique match ID (Firestore document ID).
  final String matchId;

  /// Date key when the match occurred (YYYY-MM-DD UTC).
  final String dateKey;

  /// SHA-256 hash of the first user's phone number.
  final String user1Hash;

  /// SHA-256 hash of the second user's phone number.
  final String user2Hash;

  /// Display name of user1 (stored for notification purposes).
  final String user1DisplayName;

  /// Display name of user2 (stored for notification purposes).
  final String user2DisplayName;

  /// When the match was detected.
  final DateTime matchedAt;

  /// Whether notifications have been sent for this match.
  final bool notificationsSent;

  const MatchModel({
    required this.matchId,
    required this.dateKey,
    required this.user1Hash,
    required this.user2Hash,
    required this.user1DisplayName,
    required this.user2DisplayName,
    required this.matchedAt,
    required this.notificationsSent,
  });

  factory MatchModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String dateKey,
  ) {
    final data = doc.data()!;
    return MatchModel(
      matchId: doc.id,
      dateKey: dateKey,
      user1Hash: data['user1Hash'] as String? ?? '',
      user2Hash: data['user2Hash'] as String? ?? '',
      user1DisplayName: data['user1DisplayName'] as String? ?? 'Someone',
      user2DisplayName: data['user2DisplayName'] as String? ?? 'Someone',
      matchedAt:
          (data['matchedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notificationsSent: data['notificationsSent'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user1Hash': user1Hash,
      'user2Hash': user2Hash,
      'user1DisplayName': user1DisplayName,
      'user2DisplayName': user2DisplayName,
      'matchedAt': Timestamp.fromDate(matchedAt),
      'notificationsSent': notificationsSent,
    };
  }

  /// Returns the other user's display name given the current user's hash.
  String otherDisplayName(String myHash) {
    if (myHash == user1Hash) return user2DisplayName;
    return user1DisplayName;
  }

  @override
  List<Object?> get props => [
        matchId,
        dateKey,
        user1Hash,
        user2Hash,
        user1DisplayName,
        user2DisplayName,
        matchedAt,
        notificationsSent,
      ];
}

/// Represents a purchase record.
class PurchaseRecord extends Equatable {
  final String purchaseId;
  final String userHash;
  final PurchaseType type;
  final int quantity;
  final DateTime purchasedAt;
  final String productId;

  const PurchaseRecord({
    required this.purchaseId,
    required this.userHash,
    required this.type,
    required this.quantity,
    required this.purchasedAt,
    required this.productId,
  });

  factory PurchaseRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return PurchaseRecord(
      purchaseId: doc.id,
      userHash: data['userHash'] as String? ?? '',
      type: PurchaseType.values.firstWhere(
        (e) => e.name == (data['type'] as String? ?? 'extraSends'),
        orElse: () => PurchaseType.extraSends,
      ),
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      purchasedAt:
          (data['purchasedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      productId: data['productId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userHash': userHash,
      'type': type.name,
      'quantity': quantity,
      'purchasedAt': Timestamp.fromDate(purchasedAt),
      'productId': productId,
    };
  }

  @override
  List<Object?> get props =>
      [purchaseId, userHash, type, quantity, purchasedAt, productId];
}

enum PurchaseType {
  /// Purchase additional "thinking of u" sends for today.
  extraSends,

  /// Purchase a time extension (delays reset if unreciprocated).
  extensionDays,
}
