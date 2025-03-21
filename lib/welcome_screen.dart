import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pyrosentrixapp/register.dart';
import 'register.dart'; // Import the RegisterScreen
import 'login.dart';

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

  void _navigateToRegister() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(Duration(seconds: 2)); // Simulate a delay

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/bg.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/Logo_NN.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
                Text(
                  'PYROSENTRIX!',
                  style: TextStyle(
                    fontFamily: 'Jost',
                    fontSize: 45,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white, // Adjust text color if needed
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.2), // Shadow color
                        offset: Offset(1, 1), // Shadow offset (x, y)
                        blurRadius: 30, // Blur radius
                      ),
                    ],
                  ),
                ),
                Text(
                  'Stay Alert',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 35,
                    fontWeight: FontWeight.w100,
                    letterSpacing: 0.5,
                    color: Colors.white.withOpacity(0.6), // Adjust text color if needed
                      shadows: [
                        Shadow(
                        color: Colors.black.withOpacity(0.2), // Shadow color
                        offset: Offset(1, 1), // Shadow offset (x, y)
                        blurRadius: 30, // Blur radius
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 200),
                Text(
                  'Stay Alert, Stay Safe.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 30,
                    fontWeight: FontWeight.w100,
                    letterSpacing: 0.5,
                    color: Colors.white, // Adjust text color if needed
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.2), // Shadow color
                        offset: Offset(1, 1), // Shadow offset (x, y)
                        blurRadius: 30, // Blur radius
                      ),
                    ],
                  ),
                ),
                SizedBox(height:10),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 40), // Add horizontal margin
                  alignment: Alignment.center, // Center the text
                  child: Text(
                    'Welcome to PyroSentrix! Stay safe with our smart fire detection system—monitor, detect, and receive real-time alerts anytime, anywhere.',
                    textAlign: TextAlign.center, // Center-align the text content
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w100,
                      letterSpacing: 0.5,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),
                SizedBox(height: 35),
                ElevatedButton(
                  onPressed: _isLoading ? null : _navigateToRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF6200),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 90, vertical: 15),
                  ),
                  child: Text(
                    'Get Started',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center, // Center the children horizontally
                  crossAxisAlignment: CrossAxisAlignment.center, // Align children vertically
                  children: [
                    Text(
                      'Already have an account?',
                      style: TextStyle(
                        fontFamily: 'Jost',
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => LoginScreen()),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.only(left: 5), // Remove default padding
                        minimumSize: Size.zero, // Remove minimum size constraints
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduce tap target size
                      ),
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          fontFamily: 'Jost',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
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
        ],
      ),
    );
  }
}