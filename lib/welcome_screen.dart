import 'package:flutter/material.dart';
import 'login.dart'; // Import the RegisterScreen

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome to Pyrosentrix!',
              style: TextStyle(
                fontFamily: 'Jost', // Set the font family to Jost
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()), // Navigate to RegisterScreen
                );
              },
              child: Text('Get Started', style: TextStyle(fontFamily: 'Jost')), // Set the font family for button text
            ),
          ],
        ),
      ),
    );
  }
}
