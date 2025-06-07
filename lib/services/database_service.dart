import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/todo.dart';

const String TODO_COLLECTION_REF = "todos";

class DatabaseService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  late final CollectionReference _todosRef;

  DatabaseService() {
    _todosRef = _firestore.collection(TODO_COLLECTION_REF).withConverter<Todo>(
          fromFirestore: (snapshot, _) => Todo.fromJson(snapshot.data()!),
          toFirestore: (todo, _) => todo.toJson(),
        );
  }

  // Get current user's ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // Get todos for the current user only
  Stream<QuerySnapshot> getTodos() {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    return _todosRef
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('updatedOn', descending: true)
        .snapshots();
  }

  // Add todo for the current user
  void addTodo(Todo todo) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Add userId to the todo before saving
    Map<String, dynamic> todoData = todo.toJson();
    todoData['userId'] = _currentUserId;

    await _firestore.collection(TODO_COLLECTION_REF).add({
      ...todoData,
      'userId': _currentUserId,
    });
  }

  // Update todo (only if it belongs to current user)
  // Update todo (only if it belongs to current user)
Future<void> updateTodo(String todoId, Todo todo) async {
  if (_currentUserId == null) {
    throw Exception('User not authenticated');
  }

  // Verify ownership
  final docRef = _firestore.collection(TODO_COLLECTION_REF).doc(todoId);
  final snapshot = await docRef.get();
  if (!snapshot.exists) return;

  final data = snapshot.data() as Map<String, dynamic>;
  if (data['userId'] != _currentUserId) {
    throw Exception(
      'Unauthorized: Cannot update todo that belongs to another user'
    );
  }

  // Prepare new data
  final updated = {
    ...todo.toJson(),
    'userId': _currentUserId,
  };

  // Write raw map
  await docRef.update(updated);
}

// Delete todo (only if it belongs to current user)
Future<void> deleteTodo(String todoId) async {
  if (_currentUserId == null) {
    throw Exception('User not authenticated');
  }

  // Verify ownership
  final docRef = _firestore.collection(TODO_COLLECTION_REF).doc(todoId);
  final snapshot = await docRef.get();
  if (!snapshot.exists) return;

  final data = snapshot.data() as Map<String, dynamic>;
  if (data['userId'] != _currentUserId) {
    throw Exception(
      'Unauthorized: Cannot delete todo that belongs to another user'
    );
  }

  // Perform delete
  await docRef.delete();
}


  // Delete all todos for the current user (useful for account deletion)
  Future<void> deleteAllUserTodos() async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    QuerySnapshot todos =
        await _todosRef.where('userId', isEqualTo: _currentUserId).get();

    WriteBatch batch = _firestore.batch();
    for (DocumentSnapshot doc in todos.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
