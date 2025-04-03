import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ApiService _apiService = ApiService();
  final String googleApiKey = 'AIzaSyD21izdTx2qn4vPFcFzkSDB5xhdWxtoXuM';

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  bool _isLoading = true;
  bool _showDetails = false;
  bool _updatingFireStations = false;
  bool _isEditingName = false;
  bool _isEditingAddress = false;
  List<dynamic> _placePredictions = [];
  Timer? _debounce;
  List<dynamic> _fireStations = [];
  List<Device> _userDevices = [];
  bool _loadingDevices = false;
  Map<String, String> _deviceNames = {};
  String? _currentUserEmail;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _currentUserEmail = _auth.currentUser?.email;
    _fetchUserData();
    _loadDeviceNames().then((_) => _fetchUserDevices());
  }

  Future<void> _loadDeviceNames() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      prefs.getKeys().forEach((key) {
        if (key.startsWith('device_name_')) {
          String productCode = key.replaceFirst('device_name_', '');
          _deviceNames[productCode] = prefs.getString(key) ?? 'Device';
        }
      });
    });
  }

  Future<void> _fetchUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          setState(() {
            _nameController.text = userDoc['name'] ?? '';
            _addressController.text = userDoc['address'] ?? '';
            _fireStations = userDoc['fire_stations'] ?? [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      _showError('Failed to fetch user data');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUserDevices() async {
    try {
      setState(() => _loadingDevices = true);
      if (_currentUserEmail == null) return;

      final userSnapshot = await _firestore
          .collection('ProductActivation')
          .where('user_email', isEqualTo: _currentUserEmail)
          .get();

      final sharedSnapshot = await _firestore
          .collection('ProductActivation')
          .where('shared_users', arrayContains: _currentUserEmail)
          .get();

      final uniqueDevices = <String, Device>{};

      for (var doc in userSnapshot.docs) {
        final productCode = doc['product_code'] as String;
        uniqueDevices[productCode] = Device(
          productCode: productCode,
          name: _deviceNames[productCode] ?? 'Device ${productCode.substring(0, 4)}',
          isShared: false,
        );
      }

      for (var doc in sharedSnapshot.docs) {
        final productCode = doc['product_code'] as String;
        if (!uniqueDevices.containsKey(productCode)) {
          uniqueDevices[productCode] = Device(
            productCode: productCode,
            name: _deviceNames[productCode] ?? 'Device ${productCode.substring(0, 4)}',
            isShared: true,
          );
        }
      }

      setState(() {
        _userDevices = uniqueDevices.values.toList();
        _loadingDevices = false;
      });
    } catch (e) {
      _showError('Failed to load devices');
      setState(() => _loadingDevices = false);
    }
  }

  Future<void> _updateUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        setState(() => _updatingFireStations = true);

        final newAddress = _addressController.text.trim();
        final oldAddress = (await _firestore.collection('users').doc(user.uid).get())['address'] ?? '';

        await _firestore.collection('users').doc(user.uid).update({
          'name': _nameController.text.trim(),
          'address': newAddress,
        });

        if (newAddress.toLowerCase() != oldAddress.toLowerCase()) {
          try {
            final stations = await _apiService.fetchFireStations(newAddress);
            await _firestore.collection('users').doc(user.uid).update({
              'fire_stations': stations,
            });
            setState(() => _fireStations = stations);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Profile and fire stations updated successfully!')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Profile updated but fire station update failed'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profile updated successfully!')),
          );
        }

        setState(() {
          _isEditingName = false;
          _isEditingAddress = false;
          _updatingFireStations = false;
        });
      }
    } catch (e) {
      setState(() => _updatingFireStations = false);
      _showError('Failed to update profile: ${e.toString()}');
    }
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
        ).timeout(Duration(seconds: 15));

        await _getAddressFromCoordinates(position.latitude, position.longitude);
      } on TimeoutException catch (_) {
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
        } else {
          setState(() {
            _addressController.text = "Address not found";
          });
        }
      } else {
        setState(() {
          _addressController.text = "Failed to fetch address";
        });
      }
    } catch (e) {
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Profile', style: TextStyle(fontFamily: 'Jost', color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.deepOrange,
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
                SizedBox(height: 10),
                Text(
                  _nameController.text,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Inter',
                  ),
                ),
                Text(
                  _currentUserEmail ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontFamily: 'Arimo',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 80.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSectionButton(
                  'Your Details',
                  isActive: _showDetails,
                  onTap: () => setState(() => _showDetails = true),
                ),
                _buildSectionButton(
                  'Your Devices (${_userDevices.length})',
                  isActive: !_showDetails,
                  onTap: () => setState(() => _showDetails = false),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Divider(color: Colors.grey[200], thickness: 2),
          SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: _showDetails ? _buildDetailsSection() : _buildDevicesSection(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionButton(String text, {required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Color(0xFFFFDE59) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.black : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 5),
            child: Text(
              'PERSONAL INFORMATION',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.grey[600],
                letterSpacing: 1.5,
              ),
            ),
          ),
          SizedBox(height: 5),
          _buildEditableField(
            label: 'Name',
            controller: _nameController,
            isEditing: _isEditingName,
            onEditPressed: () {
              setState(() {
                _isEditingName = true;
                _isEditingAddress = false;
              });
            },
          ),
          SizedBox(height: 20),
          Divider(color: Colors.grey[200], thickness: 1),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Address',
                    style: TextStyle(
                      fontFamily: 'Jost',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  if (!_isEditingAddress)
                    IconButton(
                      icon: Icon(Icons.edit, size: 20, color: Colors.grey[600]),
                      onPressed: () {
                        setState(() {
                          _isEditingAddress = true;
                          _isEditingName = false;
                        });
                      },
                    ),
                ],
              ),
              SizedBox(height: 0),
              _isEditingAddress
                  ? Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: Colors.deepOrange,
                        width: 1,
                      ),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: TextField(
                      controller: _addressController,
                      enabled: true,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                      ),
                      style: TextStyle(fontFamily: 'Jost'),
                      onChanged: _onAddressChanged,
                    ),
                  ),
                  if (_placePredictions.isNotEmpty)
                    Container(
                      width: double.infinity,
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
                          "Use my current location",
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
                ],
              )
                  : Padding(
                padding: const EdgeInsets.only(left: 2.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _addressController.text.isNotEmpty ? _addressController.text : 'Not provided',
                    style: TextStyle(
                      fontFamily: 'Jost',
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Divider(color: Colors.grey[200], thickness: 1),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'NEAREST FIRE STATIONS',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.grey[600],
                letterSpacing: 1.5,
              ),
            ),
          ),
          SizedBox(height: 10),
          if (_updatingFireStations)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text(
                    'Updating fire stations...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          else if (_fireStations.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'No fire stations found for your address',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _fireStations.map((station) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0, top: 2.0),
                      child: Image.asset(
                        'assets/fire-station.png',
                        width: 24,
                        height: 24,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            station['name'] ?? 'Fire Station',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${station['distance_km']} km away',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          if (_isEditingName || _isEditingAddress)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton(
                onPressed: _updateUserData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFFDE59),
                  minimumSize: Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                child: Text(
                  'SAVE CHANGES',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onEditPressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Jost',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            if (!isEditing)
              IconButton(
                icon: Icon(Icons.edit, size: 20, color: Colors.grey[600]),
                onPressed: onEditPressed,
              ),
          ],
        ),
        SizedBox(height: 0),
        isEditing
            ? Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: Colors.deepOrange,
              width: 1,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: TextField(
            controller: controller,
            enabled: true,
            decoration: InputDecoration(
              border: InputBorder.none,
            ),
            style: TextStyle(fontFamily: 'Jost'),
          ),
        )
            : Padding(
          padding: const EdgeInsets.only(left: 2.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              controller.text.isNotEmpty ? controller.text : 'Not provided',
              style: TextStyle(
                fontFamily: 'Jost',
                fontSize: 16,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDevicesSection() {
    if (_loadingDevices) {
      return Center(child: CircularProgressIndicator());
    }

    if (_userDevices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 110.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Image.asset('assets/nodevice.png', width: 150, height: 150),
            SizedBox(height: 20),
            Text(
              "No devices found",
              style: TextStyle(fontSize: 18, fontFamily: 'Inter'),
            ),
            SizedBox(height: 10),
            Text(
              "Add a device or ask to be shared access",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _userDevices.length,
      itemBuilder: (context, index) {
        final device = _userDevices[index];
        return Card(
          margin: EdgeInsets.symmetric(vertical: 8),
          elevation: 2,
          color: Colors.orange[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Image.asset(
                  'assets/PyroSentrix-Alarm.png',
                  width: 30,
                  height: 30,
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            device.name,
                            style: TextStyle(
                              fontFamily: 'Jost',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (device.isShared)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Shared',
                                  style: TextStyle(
                                    color: Colors.blue[800],
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ID: ${device.productCode}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class Device {
  final String productCode;
  final String name;
  final bool isShared;

  Device({
    required this.productCode,
    required this.name,
    required this.isShared,
  });
}