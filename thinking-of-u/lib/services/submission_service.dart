import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/match_model.dart';
import '../models/submission_model.dart';
import '../utils/crypto_utils.dart';

/// Service for managing daily "thinking of u" submissions.
///
/// Firestore structure:
/// - `users/{submitterHash}/submissions/{targetHash}` — submission docs
/// - `matches/{dateKey}/{matchId}` — match docs (written by Cloud Functions)
///
/// [dateKey] is formatted as "YYYY-MM-DD" in UTC.
class SubmissionService {
  final FirebaseFirestore _db;

  SubmissionService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _submissionsForUser(
    String submitterHash,
  ) =>
      _db
          .doc(userDocPath(submitterHash))
          .collection('submissions');

  static String userDocPath(String submitterHash) =>
      'users/$submitterHash';

  static String submissionDocPath(String submitterHash, String targetHash) =>
      '${userDocPath(submitterHash)}/submissions/$targetHash';

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
      final snapshot = await _submissionsForUser(submitterHash)
          .where('dateKey', isEqualTo: dateKey)
          .orderBy('submittedAt', descending: true)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return _toSubmissionModel(submitterHash, dateKey, snapshot.docs);
    } catch (e) {
      debugPrint('Error fetching submission: $e');
      return null;
    }
  }

  /// Stream today's submission for real-time updates.
  Stream<SubmissionModel?> watchTodaysSubmission(String submitterHash) {
    final dateKey = currentDateKey();
    return _submissionsForUser(submitterHash)
        .where('dateKey', isEqualTo: dateKey)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return _toSubmissionModel(submitterHash, dateKey, snapshot.docs);
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
    final submissions = await _submissionsForUser(submitterHash)
        .where('dateKey', isEqualTo: dateKey)
        .get();

    final existingTargets = submissions.docs.map((doc) => doc.id).toSet();

    if (existingTargets.length >= maxTargets) {
      throw Exception('You\'ve reached your daily limit of $maxTargets sends.');
    }

    if (existingTargets.contains(targetHash)) {
      throw Exception('You\'re already thinking of this person today!');
    }

    final now = DateTime.now().toUtc();
    await _db.doc(submissionDocPath(submitterHash, targetHash)).set({
      'dateKey': dateKey,
      'submittedAt': Timestamp.fromDate(now),
    });

    existingTargets.add(targetHash);
    return SubmissionModel(
      submitterHash: submitterHash,
      dateKey: dateKey,
      targetHashes: existingTargets.toList(),
      submittedAt: now,
    );
  }

  /// Remove a target from today's submission (undo).
  Future<SubmissionModel> removeTarget({
    required String submitterHash,
    required String targetHash,
  }) async {
    final dateKey = currentDateKey();
    final ref = _db.doc(submissionDocPath(submitterHash, targetHash));
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      throw Exception('No submission found for today.');
    }

    final submissionDateKey = snapshot.data()?['dateKey'] as String? ?? '';
    if (submissionDateKey != dateKey) {
      throw Exception('No submission found for today.');
    }

    await ref.delete();
    return (await getTodaysSubmission(submitterHash)) ??
        SubmissionModel(
          submitterHash: submitterHash,
          dateKey: dateKey,
          targetHashes: const [],
          submittedAt: DateTime.now().toUtc(),
        );
  }

  SubmissionModel _toSubmissionModel(
    String submitterHash,
    String dateKey,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) {
      return SubmissionModel(
        submitterHash: submitterHash,
        dateKey: dateKey,
        targetHashes: const [],
        submittedAt: DateTime.now().toUtc(),
      );
    }

    final targetHashes = docs.map((doc) => doc.id).toList();
    final submittedAt = (docs.first.data()['submittedAt'] as Timestamp?)
            ?.toDate()
            .toUtc() ??
        DateTime.now().toUtc();
    return SubmissionModel(
      submitterHash: submitterHash,
      dateKey: dateKey,
      targetHashes: targetHashes,
      submittedAt: submittedAt,
    );
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
