import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'devices.dart';
import 'register.dart';

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
  String? _emailError;
  String? _passwordError;
  bool _passwordVisible = false;

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

  bool _validateForm() {
    bool isValid = true;

    // Email validation
    if (_emailController.text
        .trim()
        .isEmpty) {
      setState(() {
        _emailError = "Please enter your email";
      });
      isValid = false;
    } else if (!_isValidEmail(_emailController.text.trim())) {
      setState(() {
        _emailError = "Please enter a valid email";
      });
      isValid = false;
    } else {
      setState(() {
        _emailError = null;
      });
    }

    // Password validation
    if (_passwordController.text.isEmpty) {
      setState(() {
        _passwordError = "Please enter your password";
      });
      isValid = false;
    } else {
      setState(() {
        _passwordError = null;
      });
    }

    return isValid;
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }

  void _loginUser(BuildContext context) async {
    if (!_validateForm()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

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
          SnackBar(
            content: Text('Please verify your email to log in.'),
            backgroundColor: Colors.orange,
          ),
        );
        await _auth.signOut();
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Try again later';
          break;
        default:
          errorMessage = 'Login failed. Please try again';
      }

      setState(() {
        if (e.code == 'wrong-password') {
          _passwordError = errorMessage;
        } else {
          _emailError = errorMessage;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred'),
          backgroundColor: Colors.red,
        ),
      );
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
                image: AssetImage('assets/bg-2.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // PYROSENTRIX Text and Additional Text
          Positioned(
            top: 170,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  Text(
                    'PYROSENTRIX',
                    style: TextStyle(
                      fontSize: 45,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Jost',
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Stay Alert',
                    style: TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.w200,
                      fontFamily: 'Inter',
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Login Form
          Column(
            children: [
              Spacer(),
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(65),
                    topRight: Radius.circular(65),
                  ),
                ),
                margin: EdgeInsets.zero,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 24.0,
                    right: 24.0,
                    top: 24.0,
                    bottom: 40.0,
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
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 50),
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
                      _buildEmailInput(),
                      SizedBox(height: 20),
                      _buildPasswordInput(),
                      SizedBox(height: 1),
                      Container(
                        width: 300,
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
                      _isLoading
                          ? CircularProgressIndicator()
                          : ElevatedButton(
                        onPressed: () => _loginUser(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFFFF6200),
                          padding: EdgeInsets.symmetric(
                              horizontal: 70, vertical: 10),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
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
                                MaterialPageRoute(
                                    builder: (context) => RegisterScreen()),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.only(left: 5),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  Widget _buildEmailInput() {
    return Container(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter Email',
            style: TextStyle(
              fontFamily: 'Jost',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF494949),
            ),
          ),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: _emailError != null ? Colors.orange[50] : Color(
                  0xFFDDDDDD),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: _emailError != null ? Colors.orange : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _emailController,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
              ),
              onChanged: (value) {
                if (_emailError != null && value.isNotEmpty) {
                  setState(() {
                    _emailError = null;
                  });
                }
              },
            ),
          ),
          if (_emailError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Text(
                    _emailError!,
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPasswordInput() {
    return Container(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter Password',
            style: TextStyle(
              fontFamily: 'Jost',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF494949),
            ),
          ),
          SizedBox(height: 8),
          Container(
            height: 50, // Fixed height for consistent alignment
            decoration: BoxDecoration(
              color: _passwordError != null ? Colors.orange[50] : Color(
                  0xFFDDDDDD),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: _passwordError != null ? Colors.orange : Colors
                    .transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _passwordController,
              obscureText: !_passwordVisible,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 10, vertical: 15), // Adjusted vertical padding
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _passwordVisible = !_passwordVisible;
                    });
                  },
                ),
              ),
              onChanged: (value) {
                if (_passwordError != null && value.isNotEmpty) {
                  setState(() {
                    _passwordError = null;
                  });
                }
              },
            ),
          ),
          if (_passwordError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Text(
                    _passwordError!,
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}