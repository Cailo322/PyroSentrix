import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_app_bar.dart';
import 'add_device.dart';
import 'login.dart';
import 'monitor.dart';
import 'dart:async';
import 'device_provider.dart';
import 'notification_service.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({Key? key}) : super(key: key);

  @override
  _DevicesScreenState createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, String> _deviceNames = {};
  bool isNavigating = false;
  Set<String> _alertedDevices = {};
  StreamSubscription<Set<String>>? _alertSubscription;
  late AnimationController _blinkController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _loadDeviceNames();
    _checkUser();
    _setupAlertListener();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: Colors.red[300],
      end: Colors.grey[300],
    ).animate(_blinkController);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _alertSubscription?.cancel();
    super.dispose();
  }

  void _setupAlertListener() {
    final notificationService = Provider.of<NotificationService>(context, listen: false);
    _alertSubscription = notificationService.alertedDevices.listen((alerts) {
      if (mounted) {
        setState(() {
          _alertedDevices = alerts;
        });
      }
    });
  }

  Stream<DocumentSnapshot> _getDeviceStatusStream(String productCode) {
    return _firestore
        .collection('DeviceStatus')
        .doc(productCode)
        .snapshots();
  }

  Stream<DocumentSnapshot> _getHushStatusStream(String productCode) {
    return _firestore
        .collection('BooleanConditions')
        .doc('Alarm')
        .snapshots();
  }

  Future<void> _loadDeviceNames() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      prefs.getKeys().forEach((key) {
        if (key.startsWith('device_name_')) {
          String productCode = key.replaceFirst('device_name_', '');
          _deviceNames[productCode] = prefs.getString(key) ?? 'Device';
        }
      });
    });
  }

  Future<void> _saveDeviceName(String productCode, String deviceName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_name_$productCode', deviceName);
    setState(() {
      _deviceNames[productCode] = deviceName;
    });
  }

  void _checkUser() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      User? user = _auth.currentUser;
      if (user == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final deviceProvider = Provider.of<DeviceProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        selectedProductCode: deviceProvider.selectedProductCode,
      ),
      endDrawer: CustomDrawer(
        selectedProductCode: deviceProvider.selectedProductCode,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _firestore
              .collection('ProductActivation')
              .where('user_email', isEqualTo: _auth.currentUser?.email)
              .get();
          setState(() {});
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('ProductActivation')
              .where('shared_users', arrayContains: _auth.currentUser?.email)
              .snapshots(),
          builder: (context, sharedSnapshot) {
            if (sharedSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (sharedSnapshot.hasError) {
              return Center(child: Text('Error loading shared devices'));
            }

            return StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('ProductActivation')
                  .where('user_email', isEqualTo: _auth.currentUser?.email)
                  .snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (userSnapshot.hasError) {
                  return Center(child: Text('Error loading user devices'));
                }

                Map<String, DocumentSnapshot> uniqueDevices = {};
                if (userSnapshot.hasData) {
                  for (var doc in userSnapshot.data!.docs) {
                    String productId = doc['product_code'];
                    if (!uniqueDevices.containsKey(productId)) {
                      uniqueDevices[productId] = doc;
                    }
                  }
                }
                if (sharedSnapshot.hasData) {
                  for (var doc in sharedSnapshot.data!.docs) {
                    String productId = doc['product_code'];
                    if (!uniqueDevices.containsKey(productId)) {
                      uniqueDevices[productId] = doc;
                    }
                  }
                }

                return ListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          SizedBox(
                            width: 190,
                            height: 190,
                            child: Image.asset('assets/official-logo.png'),
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Devices',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 4),
                          Container(
                            width: 20,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Color(0xFF494949),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Your devices will be displayed here.\nAdd a new Iot device by tapping the add icon.',
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
    bool isAdmin = doc['user_email'] == _auth.currentUser?.email;
    bool hasAlert = _alertedDevices.contains(productId);

    return GestureDetector(
      onTap: () {
        if (isNavigating) return;
        isNavigating = true;

        deviceProvider.setSelectedProductCode(productId);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MonitorScreen(productCode: productId),
          ),
        ).then((_) {
          isNavigating = false;
        });
      },
      child: AnimatedBuilder(
        animation: _blinkController,
        builder: (context, child) {
          return StreamBuilder<DocumentSnapshot>(
            stream: _getDeviceStatusStream(productId),
            builder: (context, statusSnapshot) {
              bool isOnline = statusSnapshot.hasData
                  ? statusSnapshot.data!.exists
                  ? statusSnapshot.data!['online'] ?? false
                  : false
                  : false;

              return StreamBuilder<DocumentSnapshot>(
                stream: _getHushStatusStream(productId),
                builder: (context, hushSnapshot) {
                  bool isHushed = hushSnapshot.hasData
                      ? hushSnapshot.data!.exists
                      ? hushSnapshot.data!['isHushed'] ?? false
                      : false
                      : false;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Card(
                        margin: EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        color: hasAlert
                            ? _colorAnimation.value
                            : (isOnline ? Colors.green[50] : Colors.grey[300]),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (hasAlert)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Image.asset(
                                        'assets/devicewarning.png',
                                        width: 24,
                                        height: 24,
                                      ),
                                    ),
                                  GestureDetector(
                                    onTap: () => _editDeviceName(context, productId),
                                    child: Text(
                                      deviceName,
                                      style: TextStyle(
                                        fontFamily: 'Jost',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                        color: hasAlert ? Colors.red[900] : Colors.black,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        isOnline ? Icons.circle : Icons.circle_outlined,
                                        color: isOnline ? Colors.green : Colors.grey,
                                        size: 12,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        isOnline ? 'Online' : 'Offline',
                                        style: TextStyle(
                                          color: isOnline ? Colors.green : Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Spacer(),
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert, color: hasAlert ? Colors.red[900] : Colors.black),
                                    color: Colors.white,
                                    onSelected: (value) {
                                      if (value == 'details') {
                                        _showDeviceDetails(context, doc);
                                      } else if (value == 'delete') {
                                        _deleteDevice(context, doc);
                                      } else if (value == 'add_people') {
                                        _addPeople(context, doc);
                                      } else if (value == 'view_shared') {
                                        _showSharedUsers(context, doc);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'details',
                                        child: Text('Details', style: TextStyle(color: Colors.black)),
                                      ),
                                      if (isAdmin) ...[
                                        PopupMenuItem(
                                          value: 'add_people',
                                          child: Text('Add People', style: TextStyle(color: Colors.black)),
                                        ),
                                        PopupMenuItem(
                                          value: 'view_shared',
                                          child: Text('Shared Users', style: TextStyle(color: Colors.black)),
                                        ),
                                      ],
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
                      if (isHushed)
                        Positioned(
                          top: -8,
                          right: -8,
                          child: Image.asset(
                            'assets/silent.png',
                            width: 32,
                            height: 32,
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editDeviceName(BuildContext context, String productId) async {
    TextEditingController controller = TextEditingController(
      text: _deviceNames[productId] ?? 'Device',
    );

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
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  await _saveDeviceName(productId, controller.text);
                }
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
              Text('Added By: ${doc['user_email']}'),
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

  Future<void> _deleteDevice(BuildContext context, DocumentSnapshot doc) async {
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
      if (mounted) {
        setState(() {
          _deviceNames.remove(doc['product_code']);
        });
      }
    }
  }

  Future<void> _addPeople(BuildContext context, DocumentSnapshot doc) async {
    TextEditingController controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add People'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Enter user email',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  await _firestore.collection('ProductActivation').doc(doc.id).update({
                    'shared_users': FieldValue.arrayUnion([controller.text])
                  });
                }
                Navigator.of(context).pop();
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSharedUsers(BuildContext context, DocumentSnapshot doc) async {
    final sharedUsers = List<String>.from(doc['shared_users'] ?? []);
    if (sharedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No shared users for this device')),
      );
      return;
    }

    final usersSnapshot = await _firestore.collection('users')
        .where('email', whereIn: sharedUsers)
        .get();

    final userMap = { for (var doc in usersSnapshot.docs) doc['email'] : doc['name'] };

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Shared Users', style: TextStyle(fontFamily: 'Jost')),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sharedUsers.length,
              itemBuilder: (context, index) {
                final email = sharedUsers[index];
                final name = userMap[email] ?? email;

                return Card(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(Icons.person),
                      backgroundColor: Colors.grey[200],
                    ),
                    title: Text(name, style: TextStyle(fontFamily: 'Jost')),
                    subtitle: Text(email, style: TextStyle(fontFamily: 'Inter')),
                    trailing: IconButton(
                      icon: Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () async {
                        await _removeSharedUser(doc.id, email);
                        Navigator.of(context).pop();
                        _showSharedUsers(context, doc);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close', style: TextStyle(fontFamily: 'Jost')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeSharedUser(String docId, String email) async {
    await _firestore.collection('ProductActivation').doc(docId).update({
      'shared_users': FieldValue.arrayRemove([email])
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('User removed successfully')),
    );
  }
}