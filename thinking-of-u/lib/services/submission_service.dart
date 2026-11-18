import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/match_model.dart';
import '../models/submission_model.dart';
import '../utils/crypto_utils.dart';

/// Service for managing daily "thinking of u" submissions.
///
/// Firestore structure:
/// - `daily_submissions/{dateKey}/{submitterHash}` — submission docs
/// - `matches/{dateKey}/{matchId}` — match docs (written by Cloud Functions)
///
/// [dateKey] is formatted as "YYYY-MM-DD" in UTC.
class SubmissionService {
  final FirebaseFirestore _db;

  SubmissionService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// Get the current UTC date key (YYYY-MM-DD).
  static String currentDateKey() {
    final now = DateTime.now().toUtc();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// Get or create today's submission for the given user.
  Future<SubmissionModel?> getTodaysSubmission(String submitterHash) async {
    final dateKey = currentDateKey();
    try {
      final doc = await _db
          .collection('daily_submissions')
          .doc(dateKey)
          .collection('submissions')
          .doc(submitterHash)
          .get();

      if (!doc.exists) return null;
      return SubmissionModel.fromFirestore(
        doc as DocumentSnapshot<Map<String, dynamic>>,
        submitterHash,
        dateKey,
      );
    } catch (e) {
      debugPrint('Error fetching submission: $e');
      return null;
    }
  }

  /// Stream today's submission for real-time updates.
  Stream<SubmissionModel?> watchTodaysSubmission(String submitterHash) {
    final dateKey = currentDateKey();
    return _db
        .collection('daily_submissions')
        .doc(dateKey)
        .collection('submissions')
        .doc(submitterHash)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return SubmissionModel.fromFirestore(
        doc as DocumentSnapshot<Map<String, dynamic>>,
        submitterHash,
        dateKey,
      );
    });
  }

  /// Add a target phone number to today's submission.
  ///
  /// [submitterHash] — the hash of the sender's phone number.
  /// [targetPhone] — the raw phone number of the person to think of
  ///   (this method hashes it internally).
  /// [maxTargets] — maximum number of targets allowed (from user's dailyLimit).
  ///
  /// Returns the updated [SubmissionModel].
  /// Throws if already at max targets, or if the user is adding themselves.
  Future<SubmissionModel> addTarget({
    required String submitterHash,
    required String targetPhone,
    required int maxTargets,
  }) async {
    final targetHash = CryptoUtils.hashPhoneNumber(targetPhone);

    if (targetHash == submitterHash) {
      throw Exception('You cannot send a "thinking of u" to yourself!');
    }

    final dateKey = currentDateKey();
    final ref = _db
        .collection('daily_submissions')
        .doc(dateKey)
        .collection('submissions')
        .doc(submitterHash);

    return await _db.runTransaction<SubmissionModel>((transaction) async {
      final snapshot = await transaction.get(ref);

      List<String> existingTargets = [];
      if (snapshot.exists) {
        existingTargets =
            List<String>.from(snapshot.data()?['targetHashes'] as List? ?? []);
      }

      if (existingTargets.length >= maxTargets) {
        throw Exception(
            'You\'ve reached your daily limit of $maxTargets sends.');
      }

      if (existingTargets.contains(targetHash)) {
        throw Exception('You\'re already thinking of this person today!');
      }

      existingTargets.add(targetHash);
      final now = DateTime.now().toUtc();

      final updatedData = {
        'targetHashes': existingTargets,
        'submittedAt': Timestamp.fromDate(now),
        'count': existingTargets.length,
      };

      if (snapshot.exists) {
        transaction.update(ref, updatedData);
      } else {
        transaction.set(ref, updatedData);
      }

      return SubmissionModel(
        submitterHash: submitterHash,
        dateKey: dateKey,
        targetHashes: existingTargets,
        submittedAt: now,
      );
    });
  }

  /// Remove a target from today's submission (undo).
  Future<SubmissionModel> removeTarget({
    required String submitterHash,
    required String targetHash,
  }) async {
    final dateKey = currentDateKey();
    final ref = _db
        .collection('daily_submissions')
        .doc(dateKey)
        .collection('submissions')
        .doc(submitterHash);

    return await _db.runTransaction<SubmissionModel>((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw Exception('No submission found for today.');
      }

      final targets =
          List<String>.from(snapshot.data()?['targetHashes'] as List? ?? []);
      targets.remove(targetHash);

      final now = DateTime.now().toUtc();
      transaction.update(ref, {
        'targetHashes': targets,
        'submittedAt': Timestamp.fromDate(now),
        'count': targets.length,
      });

      return SubmissionModel(
        submitterHash: submitterHash,
        dateKey: dateKey,
        targetHashes: targets,
        submittedAt: now,
      );
    });
  }

  /// Get all matches for a user across all dates.
  Future<List<MatchModel>> getMatchHistory(
    String userHash, {
    int limit = 30,
  }) async {
    try {
      final results = <MatchModel>[];

      // Query matches where user is user1
      final q1 = await _db
          .collectionGroup('match_records')
          .where('user1Hash', isEqualTo: userHash)
          .orderBy('matchedAt', descending: true)
          .limit(limit)
          .get();

      // Query matches where user is user2
      final q2 = await _db
          .collectionGroup('match_records')
          .where('user2Hash', isEqualTo: userHash)
          .orderBy('matchedAt', descending: true)
          .limit(limit)
          .get();

      for (final doc in [...q1.docs, ...q2.docs]) {
        final dateKey = doc.reference.parent.parent?.id ?? '';
        results.add(MatchModel.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>,
          dateKey,
        ));
      }

      // Sort combined results
      results.sort((a, b) => b.matchedAt.compareTo(a.matchedAt));
      return results.take(limit).toList();
    } catch (e) {
      debugPrint('Error fetching match history: $e');
      return [];
    }
  }

  /// Stream today's matches for a user (real-time).
  Stream<List<MatchModel>> watchTodaysMatches(String userHash) {
    final dateKey = currentDateKey();

    // Listen to matches collection for today where user is involved
    return _db
        .collection('matches')
        .doc(dateKey)
        .collection('match_records')
        .where('participants', arrayContains: userHash)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return MatchModel.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>,
          dateKey,
        );
      }).toList();
    });
  }
}
