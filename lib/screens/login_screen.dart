import 'package:flutter/material.dart';
import '../services/user_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final TextEditingController _usernameController = TextEditingController();
    final TextEditingController _passwordController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            ElevatedButton(
              onPressed: () {
                // Validate login credentials
                String username = _usernameController.text;
                String password = _passwordController.text;
                try {
                  User user = users.firstWhere((user) => user.username == username && user.password == password, orElse: () => throw Exception('User not found'));
                  // Redirect based on role
                  if (user.role == 'Teacher') {
                    Navigator.pushReplacementNamed(context, '/teacher'); // Assume teacher route exists
                  } else {
                    Navigator.pushReplacementNamed(context, '/student'); // Assume student route exists
                  }
                } catch (e) {
                  // Show error message
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid credentials!')));
                }
              },
              child: const Text('Login'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/register');
              },
              child: const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}
