import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/feature_flags.dart';
import '../models/user_model.dart';
import '../utils/crypto_utils.dart';

/// Service for managing user profiles in Firestore.
///
/// The Firestore path for users is: `users/{phoneHash}`
/// where `phoneHash` is the SHA-256 hash of the user's E.164 phone number.
class UserService {
  final FirebaseFirestore _db;

  UserService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Get a user document by their phone hash.
  Future<UserModel?> getUserByHash(String phoneHash) async {
    try {
      final doc = await _users.doc(phoneHash).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>);
    } catch (e) {
      debugPrint('Error fetching user: $e');
      return null;
    }
  }

  /// Get a user document by their phone number (hashes it internally).
  Future<UserModel?> getUserByPhone(String phoneNumber) async {
    final hash = CryptoUtils.hashPhoneNumber(phoneNumber);
    return getUserByHash(hash);
  }

  /// Stream a user document by phone hash (real-time updates).
  Stream<UserModel?> watchUser(String phoneHash) {
    return _users.doc(phoneHash).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>);
    });
  }

  /// Create or update a user profile.
  ///
  /// [phoneHash] is the SHA-256 hash of the user's phone number.
  Future<UserModel> createOrUpdateUser({
    required String phoneHash,
    required String displayName,
    String? fcmToken,
  }) async {
    final now = DateTime.now().toUtc();
    final nextResetAt = _nextMidnightUtc(now);

    final existingUser = await getUserByHash(phoneHash);

    if (existingUser != null) {
      // Update existing user
      final updates = <String, dynamic>{
        'displayName': displayName,
        if (fcmToken != null) 'fcmToken': fcmToken,
      };
      await _users.doc(phoneHash).update(updates);
      return existingUser.copyWith(
        displayName: displayName,
        fcmToken: fcmToken ?? existingUser.fcmToken,
      );
    } else {
      // Create new user
      final newUser = UserModel(
        phoneHash: phoneHash,
        displayName: displayName,
        fcmToken: fcmToken,
        dailySendsRemaining: FeatureFlags.defaultDailyLimit,
        dailyLimit: FeatureFlags.defaultDailyLimit,
        extensionDaysRemaining: 0,
        totalMatches: 0,
        currentStreak: 0,
        longestStreak: 0,
        createdAt: now,
        nextResetAt: nextResetAt,
      );
      await _users.doc(phoneHash).set(newUser.toFirestore());
      return newUser;
    }
  }

  /// Update the user's FCM token.
  Future<void> updateFcmToken(String phoneHash, String token) async {
    await _users.doc(phoneHash).update({'fcmToken': token});
  }

  /// Decrement the user's remaining daily sends by 1.
  /// Returns the updated remaining count, or throws if already at 0.
  Future<int> decrementDailySends(String phoneHash) async {
    final result = await _db.runTransaction((transaction) async {
      final ref = _users.doc(phoneHash);
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw Exception('User not found');

      final remaining =
          (snapshot.data()?['dailySendsRemaining'] as num?)?.toInt() ?? 0;
      if (remaining <= 0) {
        throw Exception('No daily sends remaining');
      }

      transaction.update(ref, {'dailySendsRemaining': remaining - 1});
      return remaining - 1;
    });
    return result;
  }

  /// Increment the user's daily limit (from a purchase).
  /// Caps at [FeatureFlags.maxDailyLimit].
  Future<void> increaseDailyLimit(String phoneHash, int amount) async {
    await _db.runTransaction((transaction) async {
      final ref = _users.doc(phoneHash);
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw Exception('User not found');

      final currentLimit =
          (snapshot.data()?['dailyLimit'] as num?)?.toInt() ??
              FeatureFlags.defaultDailyLimit;
      final currentRemaining =
          (snapshot.data()?['dailySendsRemaining'] as num?)?.toInt() ?? 0;

      final newLimit =
          (currentLimit + amount).clamp(0, FeatureFlags.maxDailyLimit);
      final addedAmount = newLimit - currentLimit;
      final newRemaining = currentRemaining + addedAmount;

      transaction.update(ref, {
        'dailyLimit': newLimit,
        'dailySendsRemaining': newRemaining,
      });
    });
  }

  /// Add extension days to a user's account (from a purchase).
  Future<void> addExtensionDays(String phoneHash, int days) async {
    await _db.runTransaction((transaction) async {
      final ref = _users.doc(phoneHash);
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw Exception('User not found');

      final current =
          (snapshot.data()?['extensionDaysRemaining'] as num?)?.toInt() ?? 0;
      final newValue =
          (current + days).clamp(0, FeatureFlags.maxExtensionDays);
      transaction.update(ref, {'extensionDaysRemaining': newValue});
    });
  }

  /// Check if the display name of a given phone hash is accessible.
  /// Used to preview a target's name before submitting.
  /// Returns null if the user is not registered.
  Future<String?> getDisplayName(String phoneHash) async {
    final user = await getUserByHash(phoneHash);
    return user?.displayName;
  }

  /// Calculate the next midnight UTC time (daily reset time).
  static DateTime _nextMidnightUtc(DateTime now) {
    final utc = now.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day + 1);
  }
}
