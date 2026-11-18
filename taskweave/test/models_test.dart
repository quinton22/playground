import 'package:flutter_test/flutter_test.dart';
import 'package:taskweave/models/todo_item.dart';
import 'package:taskweave/models/todo_list.dart';
import 'package:taskweave/models/sms_message.dart';

void main() {
  group('TodoItem', () {
    late DateTime now;
    late DateTime past;
    late DateTime future;

    setUp(() {
      now = DateTime.now();
      past = now.subtract(const Duration(hours: 1));
      future = now.add(const Duration(hours: 1));
    });

    test('isCompleted returns true when status is completed', () {
      final todo = _buildTodo(status: TodoStatus.completed);
      expect(todo.isCompleted, isTrue);
    });

    test('isCompleted returns false when status is open', () {
      final todo = _buildTodo(status: TodoStatus.open);
      expect(todo.isCompleted, isFalse);
    });

    test('isOverdue returns true when deadline is in past and not completed', () {
      final todo = _buildTodo(deadline: past, status: TodoStatus.open);
      expect(todo.isOverdue, isTrue);
    });

    test('isOverdue returns false when deadline is in future', () {
      final todo = _buildTodo(deadline: future, status: TodoStatus.open);
      expect(todo.isOverdue, isFalse);
    });

    test('isOverdue returns false when completed even if deadline is past', () {
      final todo = _buildTodo(deadline: past, status: TodoStatus.completed);
      expect(todo.isOverdue, isFalse);
    });

    test('isOverdue returns false when no deadline', () {
      final todo = _buildTodo(deadline: null, status: TodoStatus.open);
      expect(todo.isOverdue, isFalse);
    });

    test('hasDeadline returns true when deadline is set', () {
      final todo = _buildTodo(deadline: future);
      expect(todo.hasDeadline, isTrue);
    });

    test('hasDeadline returns false when no deadline', () {
      final todo = _buildTodo(deadline: null);
      expect(todo.hasDeadline, isFalse);
    });

    test('copyWith updates specified fields', () {
      final todo = _buildTodo(title: 'Original');
      final updated = todo.copyWith(title: 'Updated', priority: TodoPriority.high);

      expect(updated.title, equals('Updated'));
      expect(updated.priority, equals(TodoPriority.high));
      expect(updated.id, equals(todo.id)); // unchanged
      expect(updated.createdBy, equals(todo.createdBy)); // unchanged
    });

    test('toMap and fromMap round-trip preserves all fields', () {
      final original = TodoItem(
        id: 'test-id',
        title: 'Test Todo',
        description: 'A description',
        createdAt: DateTime(2024, 1, 15, 10, 0),
        deadline: DateTime(2024, 2, 1, 23, 59),
        reminderAt: DateTime(2024, 2, 1, 9, 0),
        priority: TodoPriority.high,
        status: TodoStatus.inProgress,
        createdBy: 'user-123',
        listId: 'list-456',
        tags: ['work', 'urgent'],
        hasReminder: true,
        suggestedFromMessageId: 'msg-789',
      );

      final map = original.toMap();
      final restored = TodoItem.fromMap(map);

      expect(restored.id, equals(original.id));
      expect(restored.title, equals(original.title));
      expect(restored.description, equals(original.description));
      expect(restored.priority, equals(original.priority));
      expect(restored.status, equals(original.status));
      expect(restored.createdBy, equals(original.createdBy));
      expect(restored.listId, equals(original.listId));
      expect(restored.tags, equals(original.tags));
      expect(restored.hasReminder, equals(original.hasReminder));
      expect(restored.suggestedFromMessageId,
          equals(original.suggestedFromMessageId));
    });
  });

  group('TodoList', () {
    test('isOwner returns true for owner', () {
      final list = _buildList(ownerId: 'user-1');
      expect(list.isOwner('user-1'), isTrue);
    });

    test('isOwner returns false for non-owner', () {
      final list = _buildList(ownerId: 'user-1');
      expect(list.isOwner('user-2'), isFalse);
    });

    test('isMember returns true for owner', () {
      final list = _buildList(ownerId: 'user-1', memberIds: []);
      expect(list.isMember('user-1'), isTrue);
    });

    test('isMember returns true for listed member', () {
      final list = _buildList(ownerId: 'user-1', memberIds: ['user-2']);
      expect(list.isMember('user-2'), isTrue);
    });

    test('isMember returns false for non-member', () {
      final list = _buildList(ownerId: 'user-1', memberIds: ['user-2']);
      expect(list.isMember('user-3'), isFalse);
    });

    test('copyWith updates specified fields', () {
      final list = _buildList(name: 'Original');
      final updated = list.copyWith(name: 'Updated');

      expect(updated.name, equals('Updated'));
      expect(updated.id, equals(list.id));
      expect(updated.ownerId, equals(list.ownerId));
    });
  });

  group('SmsMessage', () {
    test('copyWith preserves unchanged fields', () {
      final original = SmsMessage(
        id: '1',
        sender: 'Mom',
        body: 'Pick up milk',
        receivedAt: DateTime(2024, 1, 10),
        processed: false,
      );

      final updated = original.copyWith(processed: true);
      expect(updated.processed, isTrue);
      expect(updated.id, equals(original.id));
      expect(updated.body, equals(original.body));
    });
  });

  group('TodoSuggestion', () {
    test('confidence defaults to 0.5', () {
      final suggestion = TodoSuggestion(
        suggestedTitle: 'Buy milk',
        sourceMessageId: 'msg-1',
        sourceMessageSnippet: 'Pick up milk tomorrow',
      );
      expect(suggestion.confidence, equals(0.5));
    });

    test('suggestedDeadline is optional', () {
      final suggestion = TodoSuggestion(
        suggestedTitle: 'Call doctor',
        sourceMessageId: 'msg-2',
        sourceMessageSnippet: 'remember to call the doctor',
      );
      expect(suggestion.suggestedDeadline, isNull);
    });
  });
}

TodoItem _buildTodo({
  String? title,
  DateTime? deadline,
  TodoStatus? status,
  TodoPriority? priority,
}) {
  return TodoItem(
    id: 'test-id',
    title: title ?? 'Test Todo',
    createdAt: DateTime(2024, 1, 1),
    deadline: deadline,
    priority: priority ?? TodoPriority.medium,
    status: status ?? TodoStatus.open,
    createdBy: 'user-1',
    listId: 'list-1',
  );
}

TodoList _buildList({
  String? name,
  String? ownerId,
  List<String>? memberIds,
}) {
  return TodoList(
    id: 'list-1',
    name: name ?? 'My List',
    ownerId: ownerId ?? 'user-1',
    memberIds: memberIds ?? [],
    createdAt: DateTime(2024, 1, 1),
  );
}
