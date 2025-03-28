import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  bool _isEditing = false;
  bool _isLoading = true;
  bool _showDetails = false;

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
        await _firestore.collection('users').doc(user.uid).update({
          'name': _nameController.text.trim(),
          'address': _addressController.text.trim(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated successfully!')),
        );
        setState(() => _isEditing = false);
      }
    } catch (e) {
      _showError('Failed to update profile');
    }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: TextStyle(fontFamily: 'Jost')),
        centerTitle: true,
        actions: [
          if (!_isEditing && _showDetails)
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Profile Header
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
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Jost',
                  ),
                ),
                Text(
                  _currentUserEmail ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          // Section Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
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

          // Content Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: _showDetails ? _buildDetailsSection() : _buildDevicesSection(),
            ),
          ),

          // Save Button
          if (_isEditing && _showDetails)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton(
                onPressed: _updateUserData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFFDE59),
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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

  Widget _buildSectionButton(String text, {required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Color(0xFFFFDE59) : Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
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
        children: [
          _buildEditableField(
            label: 'Name',
            controller: _nameController,
            isEditing: _isEditing,
          ),
          SizedBox(height: 20),
          _buildEditableField(
            label: 'Address',
            controller: _addressController,
            isEditing: _isEditing,
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesSection() {
    if (_loadingDevices) {
      return Center(child: CircularProgressIndicator());
    }

    if (_userDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(Icons.devices, size: 30, color: Colors.deepOrange),
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

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required bool isEditing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Jost',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: isEditing ? Colors.white : Colors.grey[200],
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: isEditing ? Colors.deepOrange : Colors.transparent,
              width: 1,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: TextField(
            controller: controller,
            enabled: isEditing,
            decoration: InputDecoration(
              border: InputBorder.none,
            ),
            style: TextStyle(fontFamily: 'Jost'),
          ),
        ),
      ],
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