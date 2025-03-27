import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

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
      });
    } catch (e) {
      print('Error fetching devices: $e');
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
      appBar: AppBar(
        backgroundColor: Colors.grey[300],
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 150, bottom: 20),
                child: Image.asset('assets/reset.png', width: 150, height: 150),
              ),

              if (_devices.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Container(
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
                ),
              ],

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