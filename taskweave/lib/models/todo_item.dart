import 'package:cloud_firestore/cloud_firestore.dart';

enum TodoPriority { low, medium, high }

enum TodoStatus { open, inProgress, completed }

class TodoItem {
  final String id;
  final String title;
  final String? description;
  final DateTime createdAt;
  final DateTime? deadline;
  final DateTime? reminderAt;
  final TodoPriority priority;
  TodoStatus status;
  final String createdBy;
  final String listId;
  final List<String> tags;
  final bool hasReminder;
  final String? suggestedFromMessageId;

  TodoItem({
    required this.id,
    required this.title,
    this.description,
    required this.createdAt,
    this.deadline,
    this.reminderAt,
    this.priority = TodoPriority.medium,
    this.status = TodoStatus.open,
    required this.createdBy,
    required this.listId,
    this.tags = const [],
    this.hasReminder = false,
    this.suggestedFromMessageId,
  });

  bool get isCompleted => status == TodoStatus.completed;

  bool get isOverdue =>
      deadline != null &&
      deadline!.isBefore(DateTime.now()) &&
      !isCompleted;

  bool get hasDeadline => deadline != null;

  TodoItem copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? deadline,
    DateTime? reminderAt,
    TodoPriority? priority,
    TodoStatus? status,
    String? createdBy,
    String? listId,
    List<String>? tags,
    bool? hasReminder,
    String? suggestedFromMessageId,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      deadline: deadline ?? this.deadline,
      reminderAt: reminderAt ?? this.reminderAt,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      listId: listId ?? this.listId,
      tags: tags ?? this.tags,
      hasReminder: hasReminder ?? this.hasReminder,
      suggestedFromMessageId:
          suggestedFromMessageId ?? this.suggestedFromMessageId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'reminderAt':
          reminderAt != null ? Timestamp.fromDate(reminderAt!) : null,
      'priority': priority.name,
      'status': status.name,
      'createdBy': createdBy,
      'listId': listId,
      'tags': tags,
      'hasReminder': hasReminder,
      'suggestedFromMessageId': suggestedFromMessageId,
    };
  }

  factory TodoItem.fromMap(Map<String, dynamic> map) {
    return TodoItem(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      deadline: map['deadline'] != null
          ? (map['deadline'] as Timestamp).toDate()
          : null,
      reminderAt: map['reminderAt'] != null
          ? (map['reminderAt'] as Timestamp).toDate()
          : null,
      priority: TodoPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => TodoPriority.medium,
      ),
      status: TodoStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TodoStatus.open,
      ),
      createdBy: map['createdBy'] as String,
      listId: map['listId'] as String,
      tags: List<String>.from(map['tags'] ?? []),
      hasReminder: map['hasReminder'] as bool? ?? false,
      suggestedFromMessageId: map['suggestedFromMessageId'] as String?,
    );
  }

  factory TodoItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TodoItem.fromMap(data);
  }
}
