import 'package:flutter/material.dart';
import '../services/user_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _selectedRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration'),
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
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'Select Role'),
              items: <String>['Teacher', 'Student']
                  .map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedRole = newValue;
                });
              },
            ),
            ElevatedButton(
              onPressed: () {
                if (_selectedRole == null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a role.')));
                  return;
                }
                registerUser(_usernameController.text, _passwordController.text, _selectedRole!);
                Navigator.pop(context); // Navigate back to LoginScreen
              },
              child: const Text('Register'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Navigate back to LoginScreen
              },
              child: const Text('Back to Login'),
            ),
          ],
        ),
      ),
    );
  }
}
