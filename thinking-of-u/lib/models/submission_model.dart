import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents a user's daily "thinking of u" submission.
///
/// Stored in Firestore under:
///   `users/{submitterHash}/submissions/{targetHash}`
///
/// Where `dateKey` is formatted as "YYYY-MM-DD" in UTC.
/// All phone references are stored as SHA-256 hashes.
class SubmissionModel extends Equatable {
  /// SHA-256 hash of the submitter's phone number.
  final String submitterHash;

  /// Date key for this submission (YYYY-MM-DD UTC).
  final String dateKey;

  /// List of SHA-256 hashed phone numbers the user is thinking of.
  /// Maximum length is [UserModel.dailyLimit].
  final List<String> targetHashes;

  /// When this submission was last updated.
  final DateTime submittedAt;

  const SubmissionModel({
    required this.submitterHash,
    required this.dateKey,
    required this.targetHashes,
    required this.submittedAt,
  });

  factory SubmissionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String submitterHash,
    String dateKey,
  ) {
    final data = doc.data()!;
    return SubmissionModel(
      submitterHash: submitterHash,
      dateKey: dateKey,
      targetHashes: [doc.id],
      submittedAt:
          (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'dateKey': dateKey,
      'submittedAt': Timestamp.fromDate(submittedAt),
    };
  }

  SubmissionModel copyWith({
    String? submitterHash,
    String? dateKey,
    List<String>? targetHashes,
    DateTime? submittedAt,
  }) {
    return SubmissionModel(
      submitterHash: submitterHash ?? this.submitterHash,
      dateKey: dateKey ?? this.dateKey,
      targetHashes: targetHashes ?? this.targetHashes,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }

  bool get isEmpty => targetHashes.isEmpty;
  bool get isFull => targetHashes.length >= 3; // overridden at service level

  @override
  List<Object?> get props => [submitterHash, dateKey, targetHashes, submittedAt];
}
