import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';

class VerificationScreen extends StatefulWidget {
  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late User _user;
  bool _isEmailVerified = false;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser!;
    _isEmailVerified = _user.emailVerified;
    _checkEmailVerification();
  }

  Future<void> _checkEmailVerification() async {
    if (_user.emailVerified) {
      // Redirect to login screen if email is verified
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
      return;
    }

    // Periodically check email verification status
    while (!_isEmailVerified) {
      await Future.delayed(Duration(seconds: 3));
      await _user.reload();
      _user = _auth.currentUser!;
      setState(() {
        _isEmailVerified = _user.emailVerified;
      });

      if (_isEmailVerified) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    try {
      await _user.sendEmailVerification();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification email sent.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resend verification email: ${e.toString()}')),
      );
    }
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
                child: Image.asset('assets/email.png'),
              ),
              SizedBox(height: 20),
              // Verification Title
              Text(
                'Verify Your Email',
                style: TextStyle(
                  fontFamily: 'Jost',
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF494949),
                ),
              ),
              SizedBox(height: 20),
              // Verification Message
              Text(
                'An email verification was sent to ${_user.email}. Please check your inbox and verify your email address.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Jost',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF494949),
                ),
              ),
              SizedBox(height: 40),
              // Resend Button
              ElevatedButton(
                onPressed: _resendVerificationEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFFDE59),
                ),
                child: Text(
                  'Resend Verification Email',
                  style: TextStyle(fontFamily: 'Jost'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
