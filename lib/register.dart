import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'verification.dart';
import 'login.dart';
import 'api_service.dart';

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
  List<dynamic> _placePredictions = [];
  Timer? _debounce;

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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

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
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enable location services')),
      );
      return;
    }

    PermissionStatus permission = await Permission.location.request();
    if (permission.isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ).timeout(Duration(seconds: 15));

        print('Precise Position: Lat: ${position.latitude}, Lon: ${position.longitude}');
        await _getAddressFromCoordinates(position.latitude, position.longitude);
      } on TimeoutException {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Getting precise location took too long')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: ${e.toString()}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permission is required')),
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
            _placePredictions = [];
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

  void _onAddressChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    _debounce = Timer(Duration(milliseconds: 500), () {
      if (value.isNotEmpty) {
        _getPlacePredictions(value);
      } else {
        setState(() {
          _placePredictions = [];
        });
      }
    });
  }

  Future<void> _getPlacePredictions(String input) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$googleApiKey&components=country:ph';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _placePredictions = data['predictions'];
          });
        }
      }
    } catch (e) {
      print('Error fetching place predictions: $e');
    }
  }

  void _selectPrediction(String description) {
    setState(() {
      _addressController.text = description;
      _placePredictions = [];
      FocusScope.of(context).unfocus();
    });
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
            top: 100,
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
          // Register Form
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 200,
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(65),
                        topRight: Radius.circular(65),
                      ),
                    ),
                    margin: EdgeInsets.zero,
                    color: Colors.white,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 24.0,
                          right: 24.0,
                          top: 24.0,
                          bottom: 10.0,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Register',
                              style: TextStyle(
                                fontFamily: 'Jost',
                                fontSize: 35,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF494949),
                              ),
                            ),
                            SizedBox(height: 10),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 50),
                              child: Text(
                                'Create an account to get real-time fire alerts and ensure safety.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Jost',
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                            SizedBox(height: 30),
                            _buildTextInput('Enter Name', _nameController),
                            SizedBox(height: 10),
                            _buildEmailInput(),
                            SizedBox(height: 10),
                            _buildPasswordInput('Enter Password', _passwordController, showRequirements: true),
                            SizedBox(height: 20),
                            _buildPasswordInput('Confirm Password', _confirmPasswordController, error: _passwordError, showRequirements: false),
                            SizedBox(height: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 300, // Fixed width to prevent shifting
                                  child: _buildTextInput('Enter Address', _addressController, onChanged: _onAddressChanged),
                                ),
                                if (_placePredictions.isNotEmpty)
                                  Container(
                                    width: 300, // Same width as the input field
                                    margin: EdgeInsets.only(top: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 5,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: _placePredictions.length > 3 ? 3 : _placePredictions.length,
                                      itemBuilder: (context, index) {
                                        return ListTile(
                                          title: Text(
                                            _placePredictions[index]['description'],
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          onTap: () => _selectPrediction(
                                              _placePredictions[index]['description']),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
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
                            SizedBox(height: 25),
                            ElevatedButton(
                              onPressed: _registerUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                padding: EdgeInsets.symmetric(horizontal: 70, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'DONE',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an existing account?',
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
                                      MaterialPageRoute(builder: (context) => LoginScreen()),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.only(left: 5),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Sign In Here',
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
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput(String hintText, TextEditingController controller, {Function(String)? onChanged}) {
    return Container(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 50,
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
                hintText: hintText,
                hintStyle: TextStyle(
                  fontFamily: 'Jost',
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              onChanged: onChanged,
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
          Container(
            height: 50,
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
                hintText: 'Enter Email',
                hintStyle: TextStyle(
                  fontFamily: 'Jost',
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
          ),
          if (_emailError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Image.asset(
                    'assets/warning2.png',
                    height: 16,
                    width: 16,
                  ),
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

  Widget _buildPasswordInput(String hintText, TextEditingController controller, {String? error, bool showRequirements = false}) {
    return Container(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 50,
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
                hintText: hintText,
                hintStyle: TextStyle(
                  fontFamily: 'Jost',
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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