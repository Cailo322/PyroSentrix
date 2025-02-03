import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'devices.dart';
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
    } on FirebaseAuthException catch (e) {
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
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              SizedBox(
                width: 150,
                height: 150,
                child: Image.asset('assets/flashlogo.png'),
              ),
              SizedBox(height: 20),
              // Login Title with Underline
              Text(
                'Login',
                style: TextStyle(
                  fontFamily: 'Jost',
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF494949),
                ),
              ),
              SizedBox(height: 5),
              // Underline with Rounded Edges
              Container(
                height: 3,
                width: 20,
                decoration: BoxDecoration(
                  color: Color(0xFF494949), // Same color as the text
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              SizedBox(height: 20),
              // Email Input
              _buildTextInput('Enter Email', _emailController, errorMessage: _emailErrorMessage),
              if (_emailErrorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(left: 40.0, top: 8.0), // Adjusted padding
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
                  padding: const EdgeInsets.only(left: 40.0, top: 8.0), // Adjusted padding
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
              SizedBox(height: 40),
              // Login Button or Loading Indicator
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: () {
                  _loginUser(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFFDE59),
                ),
                child: Text(
                  'LOGIN',
                  style: TextStyle(fontFamily: 'Jost', fontWeight: FontWeight.w900),
                ),
              ),
              SizedBox(height: 20),
              // Register Section
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account?",
                    style: TextStyle(
                      fontFamily: 'Jost',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF494949),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => RegisterScreen()),
                      );
                    },
                    child: Text(
                      'Register',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline, // Underline the text
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
