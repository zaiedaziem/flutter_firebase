import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_firebase/models/todo.dart';

const String TODO_COLLECTION_REF =
    "todos"; // Constant to hold the name of the Firestore collection

class DatabaseService {
  final _firestore = FirebaseFirestore
      .instance; // Instance of Firestore to interact with the Firebase Firestore database

  late final CollectionReference<Todo> _todosRef;

  DatabaseService() {
    // Constructor to initialize the DatabaseService
    // Initialize the _todosRef variable with a reference to the 'todos' collection
    // and set up automatic conversion between Firestore documents and Todo objects
    _todosRef = _firestore.collection(TODO_COLLECTION_REF).withConverter<Todo>(
          // fromFirestore: This function is used to convert Firestore documents into Todo objects
          fromFirestore: (snapshot, _) => Todo.fromJson(snapshot
              .data()!), // Convert Firestore document snapshot to Todo using fromJson method

          // toFirestore: This function is used to convert Todo objects back into Firestore document format
          toFirestore: (todo, _) =>
              todo.toJson(), // Convert Todo object to a map using toJson method
        );
  }

  Stream<QuerySnapshot> getTodos() {
    return _todosRef.snapshots();
  }

  void addTodo(Todo todo) async {
    _todosRef.add(todo);
  }

  void updateTodo(String todoId, Todo todo) {
    _todosRef.doc(todoId).update(todo.toJson());
  }

  void deleteTodo(String todoId) {
    _todosRef.doc(todoId).delete();
  }
}
