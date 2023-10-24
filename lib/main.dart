import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(TodoApp());

class TodoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Todo App'),
        ),
        body: TodoScreen(),
      ),
    );
  }
}

class Todo {
  String task;
  bool isDone;

  Todo(this.task, {this.isDone = false});

  Map<String, dynamic> toJson() {
    return {
      'task': task,
      'isDone': isDone,
    };
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      json['task'],
      isDone: json['isDone'],
    );
  }
}

abstract class TodoEvent {}

class AddTodoEvent extends TodoEvent {
  String task;

  AddTodoEvent({required this.task});
}

class RemoveTodoEvent extends TodoEvent {
  int index;

  RemoveTodoEvent({required this.index});
}

class SetTodoStateEvent extends TodoEvent {
  int index;
  bool isDone;

  SetTodoStateEvent({required this.index, required this.isDone});
}

class TodoBloc {
  // List<Todo> todos = [];
  late List<Todo> todos;

  final todoEventController = StreamController<TodoEvent>();
  final todoStateController = StreamController<List<Todo>>();

  TodoBloc() {
    _initializeTodos();
    todoEventController.stream.listen(_handleEvent);
  }

  void _initializeTodos() async {
    todos = await _getTodosFromPrefs();
    todoStateController.add(todos);
  }

  Future<void> _saveTodosToPrefs(List<Todo> todos) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> todoStrings =
        todos.map((todo) => jsonEncode(todo.toJson())).toList();
    await prefs.setStringList('todos', todoStrings);
  }

  Future<List<Todo>> _getTodosFromPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String>? todoStrings = prefs.getStringList('todos');
    if (todoStrings == null) return [];

    return todoStrings
        .map((todoJson) => Todo.fromJson(jsonDecode(todoJson)))
        .toList();
  }

  dispose() {
    todoEventController.close();
    todoStateController.close();
  }

  void _handleEvent(TodoEvent event) {
    if (event is AddTodoEvent) {
      String task = event.task;
      todos.add(Todo(task, isDone: false));
    } else if (event is RemoveTodoEvent) {
      todos.removeAt(event.index);
    } else if (event is SetTodoStateEvent) {
      todos[event.index].isDone = event.isDone;
    }
    _saveTodosToPrefs(todos);
    todoStateController.sink.add(todos);
  }
}

class TodoScreen extends StatefulWidget {
  @override
  _TodoScreenState createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  TodoBloc todoBloc = TodoBloc();

  final TextEditingController _textEditingController = TextEditingController();

  void _addTodo() {
    String task = _textEditingController.text;
    if (task.isNotEmpty) {
      todoBloc.todoEventController.add(AddTodoEvent(task: task));
    }
    _textEditingController.clear();
  }

  void _removeTodo(int index) {
    todoBloc.todoEventController.add(RemoveTodoEvent(index: index));
  }

  void _toggleTodoStatus(int index, bool isDone) {
    todoBloc.todoEventController
        .add(SetTodoStateEvent(index: index, isDone: isDone));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Todo>>(
        stream: todoBloc.todoStateController.stream,
        builder: (context, snapshot) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: ListView.builder(
                    itemCount: snapshot.data?.length ?? 0,
                    itemBuilder: (context, index) {
                      final todo = snapshot.data![index];
                      return ListTile(
                        leading: Checkbox(
                          value: todo.isDone,
                          onChanged: (bool? value) {
                            _toggleTodoStatus(index, value ?? false);
                          },
                        ),
                        title: Text(
                          todo.task,
                          style: TextStyle(
                            decoration: todo.isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _removeTodo(index);
                          },
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _textEditingController,
                          decoration: const InputDecoration(
                            hintText: 'Enter a todo',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addTodo,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        });
  }
}
