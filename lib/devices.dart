import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'custom_app_bar.dart'; // Import the custom app bar and drawer
import 'add_device.dart';
import 'login.dart'; // Import the login screen to handle logout

class DevicesScreen extends StatefulWidget {
  @override
  _DevicesScreenState createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance
  final Map<String, String> _deviceNames = {}; // Local storage for device names

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
      body: RefreshIndicator(
        onRefresh: () async {
          // Force a refresh of the Firestore data
          await _firestore
              .collection('ProductActivation')
              .where('user_email', isEqualTo: _auth.currentUser?.email)
              .get();
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('ProductActivation')
              .where('user_email', isEqualTo: _auth.currentUser?.email)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error loading devices'));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
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
                        fontFamily: 'Jost',
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 10),
                    // Subtitle
                    Text(
                      'Your devices will be displayed here.\nAdd a new flame sensor by tapping the add icon.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Jost',
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 20),
                    // Placeholder for no devices
                    Text(
                      'No Devices Added Yet',
                      style: TextStyle(
                        fontFamily: 'Jost',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Group devices by product ID to ensure only one card per product ID
            Map<String, DocumentSnapshot> uniqueDevices = {};
            for (var doc in snapshot.data!.docs) {
              String productId = doc['product_code'];
              if (!uniqueDevices.containsKey(productId)) {
                uniqueDevices[productId] = doc;
              }
            }

            // Assign default names to devices if not already assigned
            int deviceNumber = 1;
            for (var doc in uniqueDevices.values) {
              String productId = doc['product_code'];
              if (!_deviceNames.containsKey(productId)) {
                _deviceNames[productId] = 'Device $deviceNumber';
                deviceNumber++;
              }
            }

            // Display the list of unique devices
            return ListView(
              padding: EdgeInsets.all(16),
              children: uniqueDevices.values.map((doc) {
                return _buildDeviceCard(context, doc); // Pass context here
              }).toList(),
            );
          },
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

  Widget _buildDeviceCard(BuildContext context, DocumentSnapshot doc) {
    String productId = doc['product_code'];
    String deviceName = _deviceNames[productId] ?? 'Device';

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device Name and Kebab Menu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Editable Device Name
                Expanded(
                  child: InkWell(
                    onTap: () {
                      _editDeviceName(context, productId);
                    },
                    child: Text(
                      deviceName,
                      style: TextStyle(
                        fontFamily: 'Jost',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                // Kebab Menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'details') {
                      _showDeviceDetails(context, doc);
                    } else if (value == 'delete') {
                      _deleteDevice(context, doc);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'details',
                      child: Text('Details'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _editDeviceName(BuildContext context, String productId) async {
    TextEditingController controller = TextEditingController(text: _deviceNames[productId]);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Device Name'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Enter device name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _deviceNames[productId] = controller.text;
                });
                Navigator.of(context).pop();
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDeviceDetails(BuildContext context, DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Device Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Product Code: ${doc['product_code']}'),
              SizedBox(height: 10),
              Text('MAC Address: ${doc['mac_address']}'),
              SizedBox(height: 10),
              Text('Activated on: ${doc['timestamp']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _deleteDevice(BuildContext context, DocumentSnapshot doc) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Device'),
          content: Text('Are you sure you want to delete this device?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      await _firestore.collection('ProductActivation').doc(doc.id).delete();
      setState(() {
        _deviceNames.remove(doc['product_code']);
      });
    }
  }
}