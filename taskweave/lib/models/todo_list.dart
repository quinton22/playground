import 'package:cloud_firestore/cloud_firestore.dart';

class TodoList {
  final String id;
  final String name;
  final String? description;
  final String ownerId;
  final List<String> memberIds;
  final List<String> pendingInvites;
  final DateTime createdAt;
  final String? color;
  final String? emoji;

  TodoList({
    required this.id,
    required this.name,
    this.description,
    required this.ownerId,
    this.memberIds = const [],
    this.pendingInvites = const [],
    required this.createdAt,
    this.color,
    this.emoji,
  });

  bool isOwner(String userId) => ownerId == userId;

  bool isMember(String userId) =>
      memberIds.contains(userId) || ownerId == userId;

  TodoList copyWith({
    String? id,
    String? name,
    String? description,
    String? ownerId,
    List<String>? memberIds,
    List<String>? pendingInvites,
    DateTime? createdAt,
    String? color,
    String? emoji,
  }) {
    return TodoList(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      memberIds: memberIds ?? this.memberIds,
      pendingInvites: pendingInvites ?? this.pendingInvites,
      createdAt: createdAt ?? this.createdAt,
      color: color ?? this.color,
      emoji: emoji ?? this.emoji,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'pendingInvites': pendingInvites,
      'createdAt': Timestamp.fromDate(createdAt),
      'color': color,
      'emoji': emoji,
    };
  }

  factory TodoList.fromMap(Map<String, dynamic> map) {
    return TodoList(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      ownerId: map['ownerId'] as String,
      memberIds: List<String>.from(map['memberIds'] ?? []),
      pendingInvites: List<String>.from(map['pendingInvites'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      color: map['color'] as String?,
      emoji: map['emoji'] as String?,
    );
  }

  factory TodoList.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TodoList.fromMap(data);
  }
}
