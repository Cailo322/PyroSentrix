import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'custom_app_bar.dart'; // Import the custom app bar and drawer
import 'add_device.dart';
import 'login.dart'; // Import the login screen to handle logout

class DevicesScreen extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _checkUser(BuildContext context) {
    User? user = _auth.currentUser;
    if (user == null) {
      // If no user is logged in, redirect to the login screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _checkUser(context); // Check if the user is logged in

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(), // Use the custom app bar
      endDrawer: CustomDrawer(), // Use the custom drawer
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            SizedBox(
              width: 150,
              height: 150,
              child: Image.asset('assets/flashlogo.png'),
            ),
            SizedBox(height: 20),
            // Title
            Text(
              'Devices',
              style: TextStyle(
                fontFamily: 'Jost', // Set the font family to Jost
                fontSize: 24,
                fontWeight: FontWeight.w900, // Increased boldness for title
                color: Colors.black,
              ),
            ),
            SizedBox(height: 10),
            // Subtitle
            Text(
              'Your devices will be displayed here.\nAdd a new flame sensor by tapping the add icon.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Jost', // Set the font family to Jost
                fontSize: 16,
                fontWeight: FontWeight.normal, // Regular weight for subtitle
                color: Colors.black,
              ),
            ),
            SizedBox(height: 20),
            // Placeholder for no devices
            Text(
              'No Devices Added Yet',
              style: TextStyle(
                fontFamily: 'Jost', // Set the font family to Jost
                fontSize: 16,
                fontWeight: FontWeight.w600, // Semi-bold for grayish text
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddDeviceScreen()),
          );
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.grey,
      ),
    );
  }
}
