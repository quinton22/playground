import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/todo_item.dart';
import '../models/todo_list.dart';

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // --- Todo Lists ---

  Stream<List<TodoList>> getUserLists(String userId) {
    return _firestore
        .collection('lists')
        .where(Filter.or(
          Filter('ownerId', isEqualTo: userId),
          Filter('memberIds', arrayContains: userId),
        ))
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TodoList.fromFirestore(doc))
            .toList());
  }

  Future<TodoList> createList(TodoList todoList) async {
    final docRef = _firestore.collection('lists').doc(todoList.id);
    await docRef.set(todoList.toMap());
    return todoList;
  }

  Future<void> updateList(TodoList todoList) async {
    await _firestore
        .collection('lists')
        .doc(todoList.id)
        .update(todoList.toMap());
  }

  Future<void> deleteList(String listId) async {
    final batch = _firestore.batch();

    // Delete all todos in this list
    final todos = await _firestore
        .collection('todos')
        .where('listId', isEqualTo: listId)
        .get();

    for (final doc in todos.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_firestore.collection('lists').doc(listId));
    await batch.commit();
  }

  Future<void> inviteMemberByEmail(
      String listId, String inviteeEmail) async {
    await _firestore.collection('lists').doc(listId).update({
      'pendingInvites': FieldValue.arrayUnion([inviteeEmail]),
    });
  }

  Future<void> acceptInvite(String listId, String userId, String email) async {
    final batch = _firestore.batch();
    final listRef = _firestore.collection('lists').doc(listId);
    batch.update(listRef, {
      'memberIds': FieldValue.arrayUnion([userId]),
      'pendingInvites': FieldValue.arrayRemove([email]),
    });
    await batch.commit();
  }

  Future<void> declineInvite(String listId, String email) async {
    await _firestore.collection('lists').doc(listId).update({
      'pendingInvites': FieldValue.arrayRemove([email]),
    });
  }

  Future<void> removeMember(String listId, String userId) async {
    await _firestore.collection('lists').doc(listId).update({
      'memberIds': FieldValue.arrayRemove([userId]),
    });
  }

  Stream<List<String>> getPendingInvites(String email) {
    return _firestore
        .collection('lists')
        .where('pendingInvites', arrayContains: email)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  Future<TodoList?> getList(String listId) async {
    final doc = await _firestore.collection('lists').doc(listId).get();
    if (!doc.exists) return null;
    return TodoList.fromFirestore(doc);
  }

  // --- Todo Items ---

  Stream<List<TodoItem>> getListTodos(String listId) {
    return _firestore
        .collection('todos')
        .where('listId', isEqualTo: listId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => TodoItem.fromFirestore(doc)).toList());
  }

  Future<TodoItem> createTodo(TodoItem todo) async {
    final docRef = _firestore.collection('todos').doc(todo.id);
    await docRef.set(todo.toMap());
    return todo;
  }

  Future<void> updateTodo(TodoItem todo) async {
    await _firestore
        .collection('todos')
        .doc(todo.id)
        .update(todo.toMap());
  }

  Future<void> deleteTodo(String todoId) async {
    await _firestore.collection('todos').doc(todoId).delete();
  }

  Future<void> toggleTodoStatus(String todoId, TodoStatus newStatus) async {
    await _firestore.collection('todos').doc(todoId).update({
      'status': newStatus.name,
    });
  }

  Future<List<TodoItem>> getTodosWithReminders(String userId) async {
    final snapshot = await _firestore
        .collection('todos')
        .where('createdBy', isEqualTo: userId)
        .where('hasReminder', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => TodoItem.fromFirestore(doc))
        .toList();
  }
}
