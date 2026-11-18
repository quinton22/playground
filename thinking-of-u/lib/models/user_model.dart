import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents a registered user in the app.
/// 
/// The user is identified by the SHA-256 hash of their phone number.
/// Phone numbers are NEVER stored in plaintext in Firestore.
class UserModel extends Equatable {
  /// The SHA-256 hash of the user's E.164 phone number.
  /// This is the Firestore document ID.
  final String phoneHash;

  /// The user's display name (first name only).
  final String displayName;

  /// Firebase Cloud Messaging token for push notifications.
  final String? fcmToken;

  /// Number of "thinking of u" sends remaining today.
  final int dailySendsRemaining;

  /// Maximum number of "thinking of u" sends per day for this user.
  /// Default is [FeatureFlags.defaultDailyLimit], increased by purchases.
  final int dailyLimit;

  /// Number of extension days the user has purchased.
  /// Each extension delays the daily reset by 24 hours if unreciprocated.
  final int extensionDaysRemaining;

  /// Total matches the user has had (for streaks / history).
  final int totalMatches;

  /// Current streak of consecutive days with at least one match.
  final int currentStreak;

  /// Longest streak ever.
  final int longestStreak;

  /// When the user first registered.
  final DateTime createdAt;

  /// When the user's daily sends will next reset.
  final DateTime nextResetAt;

  const UserModel({
    required this.phoneHash,
    required this.displayName,
    this.fcmToken,
    required this.dailySendsRemaining,
    required this.dailyLimit,
    required this.extensionDaysRemaining,
    required this.totalMatches,
    required this.currentStreak,
    required this.longestStreak,
    required this.createdAt,
    required this.nextResetAt,
  });

  factory UserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return UserModel(
      phoneHash: doc.id,
      displayName: data['displayName'] as String? ?? 'Friend',
      fcmToken: data['fcmToken'] as String?,
      dailySendsRemaining: (data['dailySendsRemaining'] as num?)?.toInt() ?? 3,
      dailyLimit: (data['dailyLimit'] as num?)?.toInt() ?? 3,
      extensionDaysRemaining:
          (data['extensionDaysRemaining'] as num?)?.toInt() ?? 0,
      totalMatches: (data['totalMatches'] as num?)?.toInt() ?? 0,
      currentStreak: (data['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (data['longestStreak'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      nextResetAt:
          (data['nextResetAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'fcmToken': fcmToken,
      'dailySendsRemaining': dailySendsRemaining,
      'dailyLimit': dailyLimit,
      'extensionDaysRemaining': extensionDaysRemaining,
      'totalMatches': totalMatches,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'createdAt': Timestamp.fromDate(createdAt),
      'nextResetAt': Timestamp.fromDate(nextResetAt),
    };
  }

  UserModel copyWith({
    String? phoneHash,
    String? displayName,
    String? fcmToken,
    int? dailySendsRemaining,
    int? dailyLimit,
    int? extensionDaysRemaining,
    int? totalMatches,
    int? currentStreak,
    int? longestStreak,
    DateTime? createdAt,
    DateTime? nextResetAt,
  }) {
    return UserModel(
      phoneHash: phoneHash ?? this.phoneHash,
      displayName: displayName ?? this.displayName,
      fcmToken: fcmToken ?? this.fcmToken,
      dailySendsRemaining: dailySendsRemaining ?? this.dailySendsRemaining,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      extensionDaysRemaining:
          extensionDaysRemaining ?? this.extensionDaysRemaining,
      totalMatches: totalMatches ?? this.totalMatches,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      createdAt: createdAt ?? this.createdAt,
      nextResetAt: nextResetAt ?? this.nextResetAt,
    );
  }

  @override
  List<Object?> get props => [
        phoneHash,
        displayName,
        fcmToken,
        dailySendsRemaining,
        dailyLimit,
        extensionDaysRemaining,
        totalMatches,
        currentStreak,
        longestStreak,
        createdAt,
        nextResetAt,
      ];
}
