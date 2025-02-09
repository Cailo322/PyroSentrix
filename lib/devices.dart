import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // Add this import for state management
import 'custom_app_bar.dart';
import 'add_device.dart';
import 'login.dart';
import 'monitor.dart';
import 'device_provider.dart'; // Import the DeviceProvider from device_provider.dart

class DevicesScreen extends StatefulWidget {
  @override
  _DevicesScreenState createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, String> _deviceNames = {};

  void _checkUser(BuildContext context) {
    User? user = _auth.currentUser;
    if (user == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _checkUser(context);

    // Access the DeviceProvider
    final deviceProvider = Provider.of<DeviceProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        selectedProductCode: deviceProvider.selectedProductCode, // Pass the selected product code
      ),
      endDrawer: CustomDrawer(
        selectedProductCode: deviceProvider.selectedProductCode, // Pass the selected product code
      ),
      body: RefreshIndicator(
        onRefresh: () async {
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

            Map<String, DocumentSnapshot> uniqueDevices = {};
            if (snapshot.hasData) {
              for (var doc in snapshot.data!.docs) {
                String productId = doc['product_code'];
                if (!uniqueDevices.containsKey(productId)) {
                  uniqueDevices[productId] = doc;
                }
              }
            }

            int deviceNumber = 1;
            for (var doc in uniqueDevices.values) {
              String productId = doc['product_code'];
              if (!_deviceNames.containsKey(productId)) {
                _deviceNames[productId] = 'Device $deviceNumber';
                deviceNumber++;
              }
            }

            return ListView(
              padding: EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: Image.asset('assets/flashlogo.png'),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Devices',
                        style: TextStyle(
                          fontFamily: 'Jost',
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 10),
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
                      if (uniqueDevices.isEmpty)
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
                ),
                ...uniqueDevices.values.map((doc) {
                  return _buildDeviceCard(context, doc, deviceProvider);
                }).toList(),
              ],
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
        backgroundColor: Colors.grey[300],
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, DocumentSnapshot doc, DeviceProvider deviceProvider) {
    String productId = doc['product_code'];
    String deviceName = _deviceNames[productId] ?? 'Device';

    return GestureDetector(
      onTap: () {
        // Update the selected product code in the provider
        deviceProvider.setSelectedProductCode(productId);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MonitorScreen(productCode: productId),
          ),
        );
      },
      child: Card(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 250,
                    ),
                    child: InkWell(
                      onTap: () {
                        _editDeviceName(context, doc['product_code']);
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