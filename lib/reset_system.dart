import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'custom_app_bar.dart'; // Import your custom app bar here

class ResetSystemScreen extends StatefulWidget {
  const ResetSystemScreen({Key? key}) : super(key: key);

  @override
  _ResetSystemScreenState createState() => _ResetSystemScreenState();
}

class _ResetSystemScreenState extends State<ResetSystemScreen> {
  final NotificationService _notificationService = NotificationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Device> _devices = [];
  String? _selectedProductCode;
  Map<String, String> _deviceNames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeviceNames().then((_) => _fetchDevices());
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

  Future<void> _fetchDevices() async {
    final userEmail = _auth.currentUser?.email;
    if (userEmail == null) return;

    try {
      final userSnapshot = await _firestore
          .collection('ProductActivation')
          .where('user_email', isEqualTo: userEmail)
          .get();

      final sharedSnapshot = await _firestore
          .collection('ProductActivation')
          .where('shared_users', arrayContains: userEmail)
          .get();

      final uniqueDevices = <String, Device>{};
      for (var doc in [...userSnapshot.docs, ...sharedSnapshot.docs]) {
        final productCode = doc['product_code'] as String;
        uniqueDevices[productCode] = Device(
          productCode: productCode,
          name: _deviceNames[productCode] ?? 'Device',
        );
      }

      setState(() {
        _devices = uniqueDevices.values.toList();
        if (_devices.isNotEmpty) {
          _selectedProductCode = _devices.first.productCode;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching devices: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _hushAlarm() async {
    try {
      await _firestore
          .collection('BooleanConditions')
          .doc('Alarm')
          .update({'isHushed': true});

      _notificationService.stopAlarmSound();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alarm hushed successfully')),
      );
    } catch (e) {
      print('Error hushing alarm: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to hush alarm')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(), // Use the updated custom app bar
      endDrawer: CustomDrawer(), // Add the custom drawer here
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 150),
                  child: CircularProgressIndicator(),
                )
              else if (_devices.isEmpty)
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 50, bottom: 30),
                      child: Image.asset('assets/nodevice.png', width: 200, height: 200),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20), // Left and right padding
                      child: Text(
                        "You don't have any IoT devices connected to your account.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontFamily: 'Inter'),
                      ),
                    ),
                    SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20), // Left and right padding
                      child: Text(
                        "Please add a device or ask your household admin with an IoT device to share access with you.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey, fontFamily: 'Inter'),
                      ),
                    ),
                  ],
                )
              else ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 20),
                    child: Image.asset('assets/reset.png', width: 150, height: 150),
                  ),
                  Center( // Add this block for your description text
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'The device control screen allows users to silence both the device alarm and mobile alarm, while the Reset feature restores normal operation for both the mobile application and the device.',
                        style: TextStyle(color: Colors.black, fontSize: 17, fontFamily: 'Inter', fontWeight: FontWeight.w100),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            'Select your device',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DropdownButton<String>(
                            value: _selectedProductCode,
                            hint: Text('Select Device'),
                            isExpanded: true,
                            underline: Container(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedProductCode = newValue;
                              });
                            },
                            items: _devices.map<DropdownMenuItem<String>>((Device device) {
                              return DropdownMenuItem<String>(
                                value: device.productCode,
                                child: Text(
                                  device.name,
                                  style: TextStyle(fontSize: 16),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _hushAlarm,
                        child: Text(
                          'HUSH',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                      SizedBox(width: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _selectedProductCode == null
                            ? null
                            : () => _showCountdownDialog(context),
                        child: Text(
                          'RESET',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }

  void _showCountdownDialog(BuildContext context) {
    int countdown = 5;
    Timer? timer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            timer = Timer.periodic(Duration(seconds: 1), (Timer t) async {
              if (countdown > 0) {
                setState(() => countdown--);
              } else {
                t.cancel();
                Navigator.of(context).pop();
                await _performResetActions();
                if (Platform.isAndroid) {
                  SystemNavigator.pop();
                }
              }
            });

            return AlertDialog(
              title: Text("Resetting System"),
              content: Text("The application and fire alarm will reset in $countdown seconds."),
              actions: [
                TextButton(
                  onPressed: () {
                    timer?.cancel();
                    Navigator.of(context).pop();
                  },
                  child: Text("CANCEL"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performResetActions() async {
    if (_selectedProductCode == null) return;

    try {
      // Reset notifications
      _notificationService.acknowledgeAlerts();

      // Reset isHushed status
      DocumentReference alarmRef = _firestore.collection('BooleanConditions').doc('Alarm');
      DocumentSnapshot docSnapshot = await alarmRef.get();
      if (docSnapshot.exists && docSnapshot.get('isHushed')) {
        await alarmRef.update({'isHushed': false});
      }

      // Reset alarm logs
      var alarmLogs = await _firestore
          .collection('SensorData')
          .doc('AlarmLogs')
          .collection(_selectedProductCode!)
          .get();

      for (var doc in alarmLogs.docs) {
        await doc.reference.update({'logged': false});
      }

      // Reset alarm status for the selected device
      await _firestore
          .collection('AlarmStatus')
          .doc(_selectedProductCode)
          .update({'AlarmLogged': false});

      // Reset dialog status for the selected device
      await _firestore
          .collection('DialogStatus')
          .doc(_selectedProductCode)
          .update({'Dialogpop': false});

      // Reset notification status for the selected device
      await _firestore
          .collection('NotifStatus')
          .doc(_selectedProductCode)
          .update({'notif': false});

      print("Reset completed for $_selectedProductCode");
    } catch (e) {
      print("Error during reset: $e");
    }
  }
}

class Device {
  final String productCode;
  final String name;

  Device({required this.productCode, required this.name});
}