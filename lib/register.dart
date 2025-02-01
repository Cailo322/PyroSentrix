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

//HAHAHAHA

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

  final String googleApiKey = 'AIzaSyD21izdTx2qn4vPFcFzkSDB5xhdWxtoXuM';

  String? _emailError;
  String? _passwordError;

  List<String> _passwordRequirements = [
    "At least 8 characters",
    "At least 1 special character",
    "At least 1 capital letter",
  ];
  Map<String, bool> _passwordStatus = {
    "At least 8 characters": false,
    "At least 1 special character": false,
    "At least 1 capital letter": false,
  };

  void _updatePasswordStatus(String password) {
    setState(() {
      _passwordStatus["At least 8 characters"] = password.length >= 8;
      _passwordStatus["At least 1 special character"] =
          RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
      _passwordStatus["At least 1 capital letter"] =
          RegExp(r'[A-Z]').hasMatch(password);
    });
  }

  Future<void> _getCurrentLocation() async {
    PermissionStatus permission = await Permission.location.request();

    if (permission.isGranted) {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      print('Current Position: Lat: ${position.latitude}, Lon: ${position.longitude}');
      await _getAddressFromCoordinates(position.latitude, position.longitude);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permission is required to use this feature')),
      );
    }
  }

  Future<void> _getAddressFromCoordinates(double latitude, double longitude) async {
    final String url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 'OK') {
          String address = data['results'][0]['formatted_address'];
          setState(() {
            _addressController.text = address;
          });
          print('Address: $address');
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
      setState(() {
        _passwordError = "Password does not match.";
      });
      return;
    } else {
      setState(() {
        _passwordError = null;
      });
    }

    if (!_isValidEmail(_emailController.text.trim())) {
      setState(() {
        _emailError = "Please enter a valid email address.";
      });
      return;
    } else {
      setState(() {
        _emailError = null;
      });
    }

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await userCredential.user!.updateDisplayName(_nameController.text.trim());
      await userCredential.user!.sendEmailVerification();

      final fireStations = await ApiService().fetchFireStations(_addressController.text.trim());

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'fire_stations': fireStations,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration successful! Please verify your email before logging in.')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => VerificationScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: ${e.toString()}')),
      );
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
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
              SizedBox(
                width: 150,
                height: 150,
                child: Image.asset('assets/flashlogo.png'),
              ),
              SizedBox(height: 20),
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
              Container(
                height: 3,
                width: 20,
                decoration: BoxDecoration(
                  color: Color(0xFF494949),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              SizedBox(height: 20),
              _buildTextInput('Enter Name', _nameController),
              SizedBox(height: 20),
              _buildEmailInput(),
              SizedBox(height: 20),
              _buildPasswordInput('Enter Password', _passwordController, showRequirements: true),
              SizedBox(height: 20),
              _buildPasswordInput('Confirm Password', _confirmPasswordController, error: _passwordError, showRequirements: false),
              SizedBox(height: 20),
              _buildTextInput('Enter Address', _addressController),
              SizedBox(height: 10),
              GestureDetector(
                onTap: _getCurrentLocation,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/location.png',
                      height: 20,
                      width: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Use my current location as my address",
                      style: TextStyle(
                        color: Color(0xFF8B8B8B),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 40),
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
                        decoration: TextDecoration.underline,
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
              color: _emailError != null ? Colors.orange[50] : Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: _emailError != null ? Colors.orange : Colors.transparent,
                width: 2,
              ),
            ),
            child: TextField(
              controller: _emailController,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
          if (_emailError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Image.asset(
                    'assets/warning2.png', // Add the warning icon
                    height: 16,
                    width: 16,
                  ),
                  SizedBox(width: 8), // Add some space between the icon and the text
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

  Widget _buildPasswordInput(String labelText, TextEditingController controller, {String? error, bool showRequirements = false}) {
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
              color: error != null ? Colors.orange[50] : Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: error != null ? Colors.orange : Colors.transparent,
                width: 2,
              ),
            ),
            child: TextField(
              controller: controller,
              obscureText: true,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
              ),
              onChanged: (value) {
                if (showRequirements) {
                  _updatePasswordStatus(value);
                }
              },
            ),
          ),
          if (showRequirements) ...[
            SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _passwordRequirements.map((requirement) {
                return Row(
                  children: [
                    Icon(
                      _passwordStatus[requirement] == true
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: _passwordStatus[requirement] == true
                          ? Colors.green
                          : Colors.red,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      requirement,
                      style: TextStyle(
                        color: _passwordStatus[requirement] == true
                            ? Colors.green
                            : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Text(
                    error,
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