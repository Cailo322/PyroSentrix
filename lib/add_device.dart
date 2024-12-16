import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'custom_app_bar.dart';

class AddDeviceScreen extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _checkUser(BuildContext context) {
    User? user = _auth.currentUser;
    if (user == null) {
      // If no user is logged in, redirect to the login screen
      Navigator.pushReplacementNamed(context, '/LoginScreen');
    }
  }

  @override
  Widget build(BuildContext context) {
    _checkUser(context); // Check if the user is logged in

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(), // Use your CustomAppBar here
      endDrawer: CustomDrawer(), // Use your CustomDrawer here
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: Image.asset('assets/flashlogo.png'),
              ),
              SizedBox(height: 20),
              Text(
                'Add Device',
                style: TextStyle(
                  fontFamily: 'Jost', // Set the font family to Jost
                  fontSize: 24,
                  fontWeight: FontWeight.w900, // Increased boldness for title
                  color: Color(0xFF494949),
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Register your PyroSentrix device by\nits device code or through scanning\nthe QR code.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Jost', // Set the font family to Jost
                  fontSize: 16,
                  fontWeight: FontWeight.normal, // Regular weight for subtitle
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Text(
                      'Input Device Code',
                      style: TextStyle(
                        fontFamily: 'Jost', // Set the font family to Jost
                        fontSize: 18,
                        fontWeight: FontWeight.w600, // Semi-bold for section title
                        color: Color(0xFF494949),
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'SN876725',
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'or',
                      style: TextStyle(
                        fontFamily: 'Jost', // Set the font family to Jost
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: 20),
                    Column(
                      children: [
                        Text(
                          'Scan QR Code',
                          style: TextStyle(
                            fontFamily: 'Jost', // Set the font family to Jost
                            fontSize: 18,
                            fontWeight: FontWeight.w600, // Semi-bold for section title
                            color: Color(0xFF494949),
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          width: 100,
                          height: 100,
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Image.asset('assets/qrlogo.png'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/MonitorScreen');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFFDE59),
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'DONE',
                  style: TextStyle(
                    fontFamily: 'Jost', // Set the font family to Jost
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
