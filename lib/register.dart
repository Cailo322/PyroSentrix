import 'dart:convert'; // Import for JSON decoding
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http; // Import the http package
import 'verification.dart'; // Import the VerificationScreen
import 'login.dart';
import 'api_service.dart'; // Import the ApiService

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Your Google API key for Geocoding (Make sure to store it securely, do not expose in production)
  final String googleApiKey = 'AIzaSyD21izdTx2qn4vPFcFzkSDB5xhdWxtoXuM';

  // Function to request location permission and fetch current address
  Future<void> _getCurrentLocation() async {
    // Request location permission
    PermissionStatus permission = await Permission.location.request();

    if (permission.isGranted) {
      // Get current location
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      // Log position to verify lat/lon
      print('Current Position: Lat: ${position.latitude}, Lon: ${position.longitude}');

      // Call Google Geocoding API to convert lat/lon to address
      await _getAddressFromCoordinates(position.latitude, position.longitude);
    } else {
      // If permission is denied, show a message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permission is required to use this feature')),
      );
    }
  }

  // Function to get address from latitude and longitude using Google Geocoding API
  Future<void> _getAddressFromCoordinates(double latitude, double longitude) async {
    final String url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$googleApiKey';

    // Send HTTP request to the Google Geocoding API
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // Parse the response
        Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 'OK') {
          // Extract the formatted address from the response
          String address = data['results'][0]['formatted_address'];

          // Update the address field with the human-readable address
          setState(() {
            _addressController.text = address;
          });

          print('Address: $address'); // Log the result for debugging
        } else {
          setState(() {
            _addressController.text = "Address not found";
          });
          print('Error in Geocoding: ${data['status']}');
        }
      } else {
        setState(() {
          _addressController.text = "Failed to fetch address";
        });
        print('Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        _addressController.text = "Error fetching address";
      });
    }
  }

  void _registerUser() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      // Show error if passwords do not match
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    try {
      // Create user with email and password
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Update display name
      await userCredential.user!.updateDisplayName(_nameController.text.trim());

      // Send email verification
      await userCredential.user!.sendEmailVerification();

      // Fetch fire stations based on user address
      final fireStations = await ApiService().fetchFireStations(_addressController.text.trim());

      // Store user information in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'fire_stations': fireStations, // Include fire stations with contact info
      });

      // Show message to check email for verification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration successful! Please verify your email before logging in.')),
      );

      // Navigate to verification screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => VerificationScreen()),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: ${e.toString()}')),
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
                child: Image.asset('assets/flashlogo.png'),
              ),
              SizedBox(height: 20),
              // Register Title (No shadow applied here)
              Text(
                'Register',
                style: TextStyle(
                  fontFamily: 'Jost',
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF494949),
                ),
              ),
              SizedBox(height: 5),
              // Underline with Rounded Edges for Register Title
              Container(
                height: 3,
                width: 20,
                decoration: BoxDecoration(
                  color: Color(0xFF494949),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              SizedBox(height: 20),
              // Name Input
              _buildTextInput('Enter Name', _nameController),
              SizedBox(height: 20),
              // Email Input
              _buildTextInput('Enter Email', _emailController),
              SizedBox(height: 20),
              // Password Input
              _buildPasswordInput('Enter Password', _passwordController),
              SizedBox(height: 20),
              // Confirm Password Input
              _buildPasswordInput('Confirm Password', _confirmPasswordController),
              SizedBox(height: 20),
              // Address Input
              _buildTextInput('Enter Address', _addressController),
              SizedBox(height: 10),
              // Use Current Location Text
              GestureDetector(
                onTap: _getCurrentLocation,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/location.png', // Location icon on the left
                      height: 20,
                      width: 20,
                    ),
                    SizedBox(width: 8), // Spacing between the icon and text
                    Text(
                      "Use my current location as my address",
                      style: TextStyle(
                        color: Color(0xFF8B8B8B), // Text color
                        fontSize: 14, // Smaller font size
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline, // Underline the text
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 40),
              // Done Button
              ElevatedButton(
                onPressed: _registerUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFFDE59),
                ),
                child: Text(
                  'DONE',
                  style: TextStyle(fontFamily: 'Jost', fontWeight: FontWeight.w900),
                ),
              ),
              SizedBox(height: 20),
              // Login Redirect Text
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
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
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                      );
                    },
                    child: Text(
                      'Log in',
                      style: TextStyle(
                        fontFamily: 'Jost',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
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

  // Helper method to build text input fields with box shadow
  Widget _buildTextInput(String labelText, TextEditingController controller) {
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
              color: Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(5),
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

  // Helper method to build password input fields with box shadow
  Widget _buildPasswordInput(String labelText, TextEditingController controller) {
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
              color: Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(5),
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
              obscureText: true,
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
