import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import 'login_screen.dart';

class StudentRegistrationScreen extends StatefulWidget {
  @override
  _StudentRegistrationScreenState createState() =>
      _StudentRegistrationScreenState();
}

class _StudentRegistrationScreenState extends State<StudentRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();

  String name = '';
  String rollNumber = '';
  String email = '';
  String password = '';
  String confirmPassword = '';
  String? error;

  void _registerStudent() async {
    if (_formKey.currentState!.validate()) {
      if (password != confirmPassword) {
        setState(() => error = "Passwords do not match");
        return;
      }

      final user = User(
        name: name,
        email: email,
        password: password,
        role: "student",
        rollNumber: rollNumber,
        subject: null,
      );

      final result = await _userService.registerUser(user);
      if (result == null) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => LoginScreen()));
      } else {
        setState(() => error = result);
      }
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white),
      prefixIcon: Icon(icon, color: Color(0xFF7C4DFF)),
      filled: true,
      fillColor: Colors.black,
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF7C4DFF)),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text("Student Registration",
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),
              const Center(
                child: Icon(Icons.school, size: 80, color: Color(0xFF7C4DFF)),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  "Create Student Account",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              TextFormField(
                decoration: _inputDecoration("Name", Icons.person),
                style: const TextStyle(color: Colors.white),
                onChanged: (val) => name = val,
                validator: (val) => val!.isEmpty ? "Enter name" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: _inputDecoration("Roll Number", Icons.badge),
                style: const TextStyle(color: Colors.white),
                onChanged: (val) => rollNumber = val,
                validator: (val) => val!.isEmpty ? "Enter roll number" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: _inputDecoration("Email", Icons.email),
                style: const TextStyle(color: Colors.white),
                onChanged: (val) => email = val,
                validator: (val) => val!.isEmpty ? "Enter email" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: _inputDecoration("Password", Icons.lock),
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                onChanged: (val) => password = val,
                validator: (val) =>
                    val!.length < 6 ? "Minimum 6 characters" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration:
                    _inputDecoration("Confirm Password", Icons.lock_outline),
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                onChanged: (val) => confirmPassword = val,
                validator: (val) =>
                    val!.isEmpty ? "Confirm your password" : null,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _registerStudent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Sign Up",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
