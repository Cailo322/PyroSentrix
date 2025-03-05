import 'package:flutter/material.dart';
import 'dart:async';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  double _opacity = 0.0; // Initial opacity

  @override
  void initState() {
    super.initState();

    // Start fade-in animation
    Future.delayed(Duration(milliseconds: 500), () {
      setState(() {
        _opacity = 1.0;
      });
    });

    // Start fade-out animation before navigation
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        _opacity = 0.0;
      });
    });

    // Navigate to home after fade-out completes
    Timer(Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => WelcomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedOpacity(
          duration: Duration(seconds: 1), // Adjust timing for smooth effect
          opacity: _opacity,
          child: Image.asset(
            'assets/official-logo.png',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
