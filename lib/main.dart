import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TodoApp());
}

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://94.74.86.174:8080/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  static Future<Response> login(String username, String password) async {
    try {
      return await _dio.post('/login', data: {
        'username': username,
        'password': password,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  static Future<Response> register(String username, String email, String password) async {
    try {
      return await _dio.post('/register', data: {
        'username': username,
        'email': email,
        'password': password,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  static Future<Response> getTodos(String token) async {
    try {
      return await _dio.get('/todos', options: Options(headers: {'Authorization': 'Bearer $token'}));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  static Future<Response> createTodo(String token, String title) async {
    try {
      return await _dio.post('/todos', data: {'title': title}, options: Options(headers: {'Authorization': 'Bearer $token'}));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  static Future<Response> updateTodo(String token, int todoId, bool isCompleted) async {
    try {
      return await _dio.put('/todos/$todoId',
          data: {'isCompleted': isCompleted}, options: Options(headers: {'Authorization': 'Bearer $token'}));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  static Future<Response> deleteTodo(String token, int todoId) async {
    try {
      return await _dio.delete('/todos/$todoId', options: Options(headers: {'Authorization': 'Bearer $token'}));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  static String _handleError(DioException error) {
    String errorMessage = 'An unexpected error occurred';

    if (error.response != null) {
      if (error.response!.data != null && error.response!.data is Map) {
        errorMessage = error.response!.data['message'] ?? errorMessage;
      } else {
        errorMessage = error.response!.statusMessage ?? errorMessage;
      }
    } else if (error.type == DioExceptionType.connectionTimeout) {
      errorMessage = 'Connection timeout';
    } else if (error.type == DioExceptionType.receiveTimeout) {
      errorMessage = 'Receive timeout';
    } else if (error.type == DioExceptionType.sendTimeout) {
      errorMessage = 'Send timeout';
    }

    return errorMessage;
  }
}

class AuthService {
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  AuthWrapperState createState() => AuthWrapperState();
}

class AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final token = await AuthService.getToken();
    setState(() {
      _token = token;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _token != null ? TodoListScreen(token: _token!) : const AuthScreen();
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  AuthScreenState createState() => AuthScreenState();
}

class AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  String _username = '';
  String _email = '';
  String _password = '';
  String _error = '';

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      _error = '';
    });
  }

  Future<void> _submitForm() async {
    debugPrint('submitForm $_username $_email, $_password $_isLogin');
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    try {
      Response response;
      Response registerResponse;
      if (_isLogin) {
        // Login
        response = await ApiService.login(_username, _password);
        await AuthService.saveToken(response.data['data']['token']);
      } else {
        // Register
        registerResponse = await ApiService.register(_username, _email, _password);
        if (registerResponse.statusCode == 200) {
          response = await ApiService.login(_username, _password);
        } else {
          throw Exception('Registration failed. Please try again.');
        }
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TodoListScreen(token: response.data['data']['token']),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Login' : 'Register'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isLogin ? 'Welcome Back' : 'Create an Account',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    return null;
                  },
                  onSaved: (value) => _username = value!.trim(),
                ),
                if (!_isLogin) const SizedBox(height: 10),
                if (!_isLogin)
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty || !value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                    onSaved: (value) => _email = value!.trim(),
                  ),
                const SizedBox(height: 10),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty || value.length < 6) {
                      return 'Password must be at least 6 characters long';
                    }
                    return null;
                  },
                  onSaved: (value) => _password = value!.trim(),
                ),
                const SizedBox(height: 20),
                if (_error.isNotEmpty)
                  Text(
                    _error,
                    style: const TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: Text(_isLogin ? 'Login' : 'Register'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _toggleAuthMode,
                  child: Text(
                    _isLogin ? 'Create new account' : 'Already have an account? Login',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Todo {
  final int id;
  final String title;
  final bool isCompleted;

  Todo({
    required this.id,
    required this.title,
    required this.isCompleted,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'],
      title: json['title'],
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}

class TodoListScreen extends StatefulWidget {
  final String token;

  const TodoListScreen({super.key, required this.token});

  @override
  TodoListScreenState createState() => TodoListScreenState();
}

class TodoListScreenState extends State<TodoListScreen> {
  List<Todo> _todos = [];
  final TextEditingController _todoController = TextEditingController();
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchTodos();
  }

  Future<void> _fetchTodos() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      final response = await ApiService.getTodos(widget.token);

      setState(() {
        _todos = (response.data as List).map((todo) => Todo.fromJson(todo)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addTodo() async {
    if (_todoController.text.isNotEmpty) {
      try {
        await ApiService.createTodo(widget.token, _todoController.text);
        _todoController.clear();
        await _fetchTodos();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _toggleTodo(Todo todo) async {
    try {
      await ApiService.updateTodo(widget.token, todo.id, !todo.isCompleted);
      await _fetchTodos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _deleteTodo(int todoId) async {
    try {
      await ApiService.deleteTodo(widget.token, todoId);
      await _fetchTodos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _logout() async {
    await AuthService.removeToken();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _todoController,
                    decoration: const InputDecoration(
                      hintText: 'Enter a new todo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _addTodo,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error.isNotEmpty)
            Expanded(
              child: Center(
                child: Text(
                  _error,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _todos.length,
                itemBuilder: (context, index) {
                  Todo todo = _todos[index];
                  return ListTile(
                    title: Text(
                      todo.title,
                      style: TextStyle(
                        decoration: todo.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                      ),
                    ),
                    leading: Checkbox(
                      value: todo.isCompleted,
                      onChanged: (_) => _toggleTodo(todo),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteTodo(todo.id),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
