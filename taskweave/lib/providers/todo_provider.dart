import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/todo_list.dart';
import '../models/todo_item.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class TodoProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final AuthService _authService;
  final NotificationService _notificationService;

  List<TodoList> _lists = [];
  final Map<String, List<TodoItem>> _todos = {};
  String? _selectedListId;
  bool _isLoading = false;
  String? _error;

  StreamSubscription<List<TodoList>>? _listsSubscription;
  final Map<String, StreamSubscription<List<TodoItem>>> _todoSubscriptions = {};

  static const _uuid = Uuid();

  TodoProvider({
    required FirestoreService firestoreService,
    required AuthService authService,
    required NotificationService notificationService,
  })  : _firestoreService = firestoreService,
        _authService = authService,
        _notificationService = notificationService;

  List<TodoList> get lists => List.unmodifiable(_lists);
  String? get selectedListId => _selectedListId;
  bool get isLoading => _isLoading;
  String? get error => _error;

  TodoList? get selectedList =>
      _selectedListId != null
          ? _lists.where((l) => l.id == _selectedListId).firstOrNull
          : null;

  List<TodoItem> getTodosForList(String listId) =>
      List.unmodifiable(_todos[listId] ?? []);

  List<TodoItem> get currentListTodos =>
      _selectedListId != null ? getTodosForList(_selectedListId!) : [];

  List<TodoItem> get openTodos =>
      currentListTodos.where((t) => !t.isCompleted).toList();

  List<TodoItem> get completedTodos =>
      currentListTodos.where((t) => t.isCompleted).toList();

  List<TodoItem> get overdueTodos =>
      currentListTodos.where((t) => t.isOverdue).toList();

  void initializeForUser(String userId) {
    _listsSubscription?.cancel();
    _listsSubscription =
        _firestoreService.getUserLists(userId).listen((lists) {
      _lists = lists;
      if (_selectedListId == null && lists.isNotEmpty) {
        _selectedListId = lists.first.id;
      }
      // Subscribe to todos for each list
      for (final list in lists) {
        _subscribeToListTodos(list.id);
      }
      notifyListeners();
    }, onError: (e) {
      _error = 'Failed to load lists: $e';
      notifyListeners();
    });
  }

  void _subscribeToListTodos(String listId) {
    if (_todoSubscriptions.containsKey(listId)) return;

    _todoSubscriptions[listId] =
        _firestoreService.getListTodos(listId).listen((todos) {
      _todos[listId] = todos;
      notifyListeners();
    }, onError: (e) {
      debugPrint('Error loading todos for list $listId: $e');
    });
  }

  void selectList(String listId) {
    _selectedListId = listId;
    notifyListeners();
  }

  Future<TodoList?> createList({
    required String name,
    String? description,
    String? color,
    String? emoji,
  }) async {
    final userId = _authService.currentUserId;
    if (userId == null) return null;

    _setLoading(true);
    try {
      final list = TodoList(
        id: _uuid.v4(),
        name: name,
        description: description,
        ownerId: userId,
        memberIds: [],
        createdAt: DateTime.now(),
        color: color,
        emoji: emoji,
      );
      await _firestoreService.createList(list);
      _setLoading(false);
      return list;
    } catch (e) {
      _error = 'Failed to create list: $e';
      _setLoading(false);
      return null;
    }
  }

  Future<bool> updateList(TodoList updatedList) async {
    try {
      await _firestoreService.updateList(updatedList);
      return true;
    } catch (e) {
      _error = 'Failed to update list: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteList(String listId) async {
    try {
      await _firestoreService.deleteList(listId);
      _todoSubscriptions[listId]?.cancel();
      _todoSubscriptions.remove(listId);
      _todos.remove(listId);
      if (_selectedListId == listId) {
        _selectedListId = _lists.isNotEmpty ? _lists.first.id : null;
      }
      return true;
    } catch (e) {
      _error = 'Failed to delete list: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> inviteMember(String listId, String email) async {
    try {
      await _firestoreService.inviteMemberByEmail(listId, email);
      return true;
    } catch (e) {
      _error = 'Failed to send invite: $e';
      notifyListeners();
      return false;
    }
  }

  Future<TodoItem?> createTodo({
    required String title,
    String? description,
    DateTime? deadline,
    DateTime? reminderAt,
    TodoPriority priority = TodoPriority.medium,
    List<String> tags = const [],
    String? suggestedFromMessageId,
  }) async {
    final userId = _authService.currentUserId;
    final listId = _selectedListId;
    if (userId == null || listId == null) return null;

    _setLoading(true);
    try {
      final todo = TodoItem(
        id: _uuid.v4(),
        title: title,
        description: description,
        createdAt: DateTime.now(),
        deadline: deadline,
        reminderAt: reminderAt,
        priority: priority,
        status: TodoStatus.open,
        createdBy: userId,
        listId: listId,
        tags: tags,
        hasReminder: reminderAt != null,
        suggestedFromMessageId: suggestedFromMessageId,
      );

      await _firestoreService.createTodo(todo);

      if (todo.hasReminder && todo.reminderAt != null) {
        await _notificationService.scheduleReminder(todo);
      }

      _setLoading(false);
      return todo;
    } catch (e) {
      _error = 'Failed to create todo: $e';
      _setLoading(false);
      return null;
    }
  }

  Future<bool> updateTodo(TodoItem updatedTodo) async {
    try {
      await _firestoreService.updateTodo(updatedTodo);

      // Reschedule reminder if changed
      await _notificationService.cancelReminder(updatedTodo.id);
      if (updatedTodo.hasReminder && updatedTodo.reminderAt != null) {
        await _notificationService.scheduleReminder(updatedTodo);
      }

      return true;
    } catch (e) {
      _error = 'Failed to update todo: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleTodo(TodoItem todo) async {
    final newStatus = todo.isCompleted ? TodoStatus.open : TodoStatus.completed;
    try {
      await _firestoreService.toggleTodoStatus(todo.id, newStatus);
      if (newStatus == TodoStatus.completed) {
        await _notificationService.cancelReminder(todo.id);
      }
      return true;
    } catch (e) {
      _error = 'Failed to toggle todo: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTodo(TodoItem todo) async {
    try {
      await _firestoreService.deleteTodo(todo.id);
      await _notificationService.cancelReminder(todo.id);
      return true;
    } catch (e) {
      _error = 'Failed to delete todo: $e';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _listsSubscription?.cancel();
    for (final sub in _todoSubscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }
}
