import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/todo.dart';
import '../services/database_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _taskController = TextEditingController();

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: _appBar(),
      body: _buildUI(),
      floatingActionButton: _addTodoButton(),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.primary,
      title: const Text(
        "Todo",
        style: TextStyle(
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildUI() {
    return SafeArea(
      child: Column(
        children: [
          _messagesListView(),
        ],
      ),
    );
  }

  Widget _messagesListView() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.80,
      width: MediaQuery.of(context).size.width,
      child: StreamBuilder(
        stream: _databaseService.getTodos(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('StreamBuilder error: ${snapshot.error}');
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          List todos = snapshot.data?.docs ?? [];
          
          if (todos.isEmpty) {
            return const Center(
              child: Text("Add a todo!"),
            );
          }
          
          return ListView.builder(
            itemCount: todos.length,
            itemBuilder: (context, index) {
              try {
                Todo todo = todos[index].data();
                String todoId = todos[index].id;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 5, 
                    horizontal: 10
                  ),
                  child: ListTile(
                    tileColor: Theme.of(context).colorScheme.primaryContainer,
                    leading: Checkbox(
                      value: todo.isDone,
                      onChanged: (bool? value) {
                        if (value != null) {
                          _updateTodoStatus(todoId, todo, value);
                        }
                      },
                    ),
                    title: Text(
                      todo.task,
                      style: TextStyle(
                        decoration: todo.isDone 
                          ? TextDecoration.lineThrough 
                          : TextDecoration.none,
                        color: todo.isDone 
                          ? Colors.grey 
                          : null,
                      ),
                    ),
                    subtitle: Text(DateFormat("dd-MM-yyyy h:mm a")
                        .format(todo.updatedOn.toDate())),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteTodo(todoId),
                    ),
                  ),
                );
              } catch (e) {
                print('Error building todo item: $e');
                return ListTile(
                  title: Text('Error loading todo: $e'),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _addTodoButton() {
    return FloatingActionButton(
      onPressed: _showAddTodoDialog,
      child: const Icon(Icons.add),
    );
  }

  void _showAddTodoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Todo'),
          content: TextField(
            controller: _taskController,
            decoration: const InputDecoration(
              hintText: 'Enter task description',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            minLines: 1,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _taskController.clear();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_taskController.text.trim().isNotEmpty) {
                  _addTodo(_taskController.text.trim());
                  Navigator.of(context).pop();
                  _taskController.clear();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addTodo(String task) {
    Todo newTodo = Todo(
      task: task,
      isDone: false,
      createdOn: Timestamp.now(),
      updatedOn: Timestamp.now(),
    );
    _databaseService.addTodo(newTodo);
  }

  void _updateTodoStatus(String todoId, Todo todo, bool newStatus) {
    Todo updatedTodo = todo.copyWith(
      isDone: newStatus,
      updatedOn: Timestamp.now(),
    );
    _databaseService.updateTodo(todoId, updatedTodo);
  }

  void _deleteTodo(String todoId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Todo'),
          content: const Text('Are you sure you want to delete this todo?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _databaseService.deleteTodo(todoId);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}