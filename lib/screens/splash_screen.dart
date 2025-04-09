import 'package:flutter/material.dart';
import 'login_screen.dart'; // Adjust path if needed

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school,
              size: 100,
              color: Color(0xFF7C4DFF),
            ),
            SizedBox(height: 20),
            Text(
              'EduShare',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7C4DFF),
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Share your screen seamlessly',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF7C4DFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
