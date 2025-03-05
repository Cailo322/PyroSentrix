import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'login.dart'; // Import the LoginScreen

class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToLogin() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(Duration(seconds: 2)); // Simulate a delay

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

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
                fontFamily: 'Jost',
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 20),
            Image.asset(
              'assets/official-logo.png',
              width: 180,
              height: 180,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isLoading ? null : _navigateToLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFFDE59),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'GET STARTED',
                style: TextStyle(
                  fontFamily: 'Jost',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                  color: Colors.grey[800],
                ),
              ),
            ),
            if (_isLoading) ...[
              SizedBox(height: 20),
              SizedBox(
                width: 50,
                height: 50,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _controller.value * 6.3,
                      child: Stack(
                        alignment: Alignment.center,
                        children: List.generate(12, (index) {
                          final angle = index * (6.3 / 12);
                          return Transform(
                            transform: Matrix4.identity()
                              ..translate(20.0 * math.cos(angle), 20.0 * math.sin(angle)),
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.orange.withOpacity((index + 1) / 12),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}