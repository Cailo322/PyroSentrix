import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart'; // For saving login state
import 'devices.dart'; // Import your Devices screen
import 'register.dart'; // Import your Register screen

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String? _emailErrorMessage;
  String? _passwordErrorMessage;

  @override
  void initState() {
    super.initState();
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      User? user = _auth.currentUser;
      if (user != null) {
        await _updateFcmToken(user.uid, newToken);
      }
    });
  }

  void _loginUser(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _emailErrorMessage = null;
      _passwordErrorMessage = null;
    });

    // Validate email and password
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _emailErrorMessage = "Please enter your email.";
      });
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (_passwordController.text.trim().isEmpty) {
      setState(() {
        _passwordErrorMessage = "Please enter your password.";
      });
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null && userCredential.user!.emailVerified) {
        String? fcmToken = await FirebaseMessaging.instance.getToken();

        if (fcmToken != null) {
          await _updateFcmToken(userCredential.user!.uid, fcmToken);
        }

        // Save login state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DevicesScreen()),
        );
      } else if (!userCredential.user!.emailVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please verify your email to log in.')),
        );
        await _auth.signOut();
      }
    } on FirebaseAuthException {
      String message = 'Invalid Credentials'; // Unified error message
      setState(() {
        _emailErrorMessage = message; // Display the message
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateFcmToken(String userId, String token) async {
    await _firestore.collection("users").doc(userId).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/bg-2.png'), // Path to your background image
                fit: BoxFit.cover, // Ensures the image covers the entire screen
              ),
            ),
          ),

          // PYROSENTRIX Text and Additional Text
          Positioned(
            top: 170, // Adjust this value to position the text vertically
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  Text(
                    'PYROSENTRIX',
                    style: TextStyle(
                      fontSize: 45, // Adjust the font size as needed
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Jost',
                      color: Colors.white, // Adjust the color as needed
                    ),
                  ),
                  SizedBox(height: 3), // Space between the two texts
                  Text(
                    'Stay Alert', // Add your new text
                    style: TextStyle(
                      fontSize: 35, // Adjust the font size as needed
                      fontWeight: FontWeight.w200,
                      fontFamily: 'Inter',
                      color: Colors.white.withOpacity(0.8), // Adjust the color as needed
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Login Form
          Column(
            children: [
              Spacer(), // Pushes the card to the bottom
              Card(
                elevation: 5, // Adds a shadow to the card
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(65),
                    topRight: Radius.circular(65),
                  ), // Rounded corners only at the top
                ),
                margin: EdgeInsets.zero, // Remove default margin
                color: Colors.white, // White background for the card
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 24.0,
                    right: 24.0,
                    top: 24.0,
                    bottom: 40.0, // Added bottom padding to create space
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Sign In',
                        style: TextStyle(
                          fontFamily: 'Jost',
                          fontSize: 35,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 10),
                      // Subtitle
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 50), // Add horizontal margin
                        child: Text(
                          'Stay connected to your fire alarm system—sign in to monitor alerts in real time',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'Jost',
                              fontSize: 14,
                              color: Colors.grey[600]),
                        ),
                      ),

                      SizedBox(height: 30),
                      // Email Input
                      _buildTextInput('Enter Email', _emailController, errorMessage: _emailErrorMessage),
                      if (_emailErrorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                          child: Row(
                            children: [
                              Image.asset('assets/warning2.png', width: 20, height: 20),
                              SizedBox(width: 8),
                              Text(
                                _emailErrorMessage!,
                                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: 20),
                      // Password Input
                      _buildTextInput('Enter Password', _passwordController, obscureText: true, errorMessage: _passwordErrorMessage),
                      if (_passwordErrorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                          child: Row(
                            children: [
                              Image.asset('assets/warning2.png', width: 20, height: 20),
                              SizedBox(width: 8),
                              Text(
                                _passwordErrorMessage!,
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: 1),
                      // Forget Password
                      Container(
                        width: 300, // Same width as the input fields
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              // Add forget password functionality
                            },
                            child: Text(
                              'Forget my password?',
                              style: TextStyle(
                                  fontFamily: 'Jost',
                                  fontSize: 14,
                                  color: Colors.orange[900]),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 15),
                      // Login Button or Loading Indicator
                      _isLoading
                          ? CircularProgressIndicator()
                          : ElevatedButton(
                        onPressed: () {
                          _loginUser(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFFFF6200),
                          padding: EdgeInsets.symmetric(horizontal: 70, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Sign In',
                          style: TextStyle(
                              fontFamily: 'Jost',
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white),
                        ),
                      ),
                      SizedBox(height: 10),
                      // Register Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center, // Center the children horizontally
                        crossAxisAlignment: CrossAxisAlignment.center, // Align children vertically
                        children: [
                          Text(
                            'No Account Yet?',
                            style: TextStyle(
                              fontFamily: 'Jost',
                              fontSize: 16,
                              color: Colors.deepOrange,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => RegisterScreen()),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.only(left: 5), // Remove default padding
                              minimumSize: Size.zero, // Remove minimum size constraints
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduce tap target size
                            ),
                            child: Text(
                              'Register Here',
                              style: TextStyle(
                                fontFamily: 'Jost',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  // Helper method to build text input fields with drop shadow
  Widget _buildTextInput(String labelText, TextEditingController controller, {bool obscureText = false, String? errorMessage}) {
    return Container(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelText,
            style: TextStyle(
              fontFamily: 'Jost',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF494949),
              shadows: [
                Shadow(
                  blurRadius: 3,
                  color: Colors.black.withOpacity(0.2),
                  offset: Offset(1, 1),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: errorMessage != null ? Color(0xFFFFF2D5) : Color(0xFFDDDDDD), // Lighter orange if error
              borderRadius: BorderRadius.circular(5),
              border: errorMessage != null ? Border.all(color: Colors.orange, width: 2) : Border.all(color: Colors.transparent),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}