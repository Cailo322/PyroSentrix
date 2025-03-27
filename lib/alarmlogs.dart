import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class AlarmLogScreen extends StatefulWidget {
  const AlarmLogScreen({Key? key}) : super(key: key);

  @override
  _AlarmLogScreenState createState() => _AlarmLogScreenState();
}

class _AlarmLogScreenState extends State<AlarmLogScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> alarmLogs = [];
  List<Map<String, dynamic>> filteredAlarmLogs = [];
  int alarmCount = 0;
  String? selectedMonth;
  String? selectedYear;
  String? _selectedProductCode;
  List<Device> _devices = [];
  StreamSubscription? _alarmSubscription;
  StreamSubscription? _sensorSubscription;
  Map<String, String> _deviceNames = {};

  final List<String> months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  final List<String> years = ['2023', '2024', '2025'];

  @override
  void initState() {
    super.initState();
    _loadDeviceNames().then((_) => _fetchDevices());
  }

  @override
  void dispose() {
    _alarmSubscription?.cancel();
    _sensorSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDeviceNames() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      prefs.getKeys().forEach((key) {
        if (key.startsWith('device_name_')) {
          String productCode = key.replaceFirst('device_name_', '');
          _deviceNames[productCode] = prefs.getString(key) ?? 'Device $productCode';
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
          name: _deviceNames[productCode] ?? 'Device $productCode',
        );
      }

      setState(() {
        _devices = uniqueDevices.values.toList();
        if (_devices.isNotEmpty) {
          _selectedProductCode = _devices.first.productCode;
          _fetchAlarmHistory();
          _listenToLatestSensorData();
        }
      });
    } catch (e) {
      print('Error fetching devices: $e');
    }
  }

  void _fetchAlarmHistory() {
    if (_selectedProductCode == null) return;

    _alarmSubscription?.cancel();
    _alarmSubscription = _firestore
        .collection('SensorData')
        .doc('AlarmLogs')
        .collection(_selectedProductCode!)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        alarmLogs = snapshot.docs.map((doc) {
          var data = doc.data();
          return {
            'id': data['id'],
            'timestamp': data['timestamp'],
            'values': data['values'],
            'imageUrl': data['imageUrl'],
          };
        }).toList();
        filteredAlarmLogs = alarmLogs;

        if (alarmLogs.isNotEmpty) {
          var lastAlarmId = alarmLogs.first['id'];
          if (lastAlarmId != null && lastAlarmId.startsWith('Alarm ')) {
            alarmCount = int.parse(lastAlarmId.split(' ')[1]);
          }
        }
      });
    });
  }

  void _listenToLatestSensorData() {
    if (_selectedProductCode == null) return;

    _sensorSubscription?.cancel();
    _sensorSubscription = _firestore
        .collection('SensorData')
        .doc('FireAlarm')
        .collection(_selectedProductCode!)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;

      var latestDoc = snapshot.docs.first;
      var data = latestDoc.data();
      var thresholdDoc = await _firestore.collection('Threshold').doc('Proxy').get();
      if (!thresholdDoc.exists) return;

      var thresholds = thresholdDoc.data()!;

      if (_exceedsThreshold(data, thresholds)) {
        var alarmStatusDoc = await _firestore
            .collection('AlarmStatus')
            .doc(_selectedProductCode)
            .get();

        if (!alarmStatusDoc.exists || alarmStatusDoc['AlarmLogged'] == false) {
          String sensorDataDocId = latestDoc.id;
          await Future.delayed(Duration(seconds: 1));
          String? imageUrl = await _fetchLatestImageUrl();

          alarmCount++;
          var alarmData = {
            'id': 'Alarm $alarmCount',
            'timestamp': data['timestamp'],
            'values': data,
            'sensorDataDocId': sensorDataDocId,
            'imageUrl': imageUrl,
            'logged': true,
          };

          await _firestore
              .collection('SensorData')
              .doc('AlarmLogs')
              .collection(_selectedProductCode!)
              .add(alarmData);

          await _firestore
              .collection('AlarmStatus')
              .doc(_selectedProductCode)
              .set({'AlarmLogged': true}, SetOptions(merge: true));

          setState(() {
            alarmLogs.insert(0, alarmData);
            _filterAlarms();
          });
        }
      }
    });
  }

  Future<String?> _fetchLatestImageUrl() async {
    if (_selectedProductCode == null) return null;

    try {
      var snapshot = await _firestore
          .collection(_selectedProductCode!)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first['imageUrl'];
      }
    } catch (e) {
      print('Error fetching image URL: $e');
    }
    return null;
  }

  Widget _buildDeviceDropdown() {
    return DropdownButton<String>(
      value: _selectedProductCode,
      hint: Text('Select Device', style: TextStyle(fontSize: 14)),
      onChanged: (String? newValue) {
        setState(() {
          _selectedProductCode = newValue;
          alarmLogs.clear();
          filteredAlarmLogs.clear();
          _fetchAlarmHistory();
          _listenToLatestSensorData();
        });
      },
      items: _devices.map<DropdownMenuItem<String>>((Device device) {
        return DropdownMenuItem<String>(
          value: device.productCode,
          child: Text(
            '${device.name} (${device.productCode})',
            style: TextStyle(fontSize: 14),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMonthYearLabel(String month, String year) {
    return Row(
      children: [
        Expanded(
          child: Divider(color: Colors.grey[400], thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            '$month $year',
            style: TextStyle(
              fontFamily: 'jura',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Divider(color: Colors.grey[400], thickness: 1),
        ),
      ],
    );
  }

  void _filterAlarms() {
    setState(() {
      if (selectedMonth == null && selectedYear == null) {
        filteredAlarmLogs = alarmLogs;
      } else {
        filteredAlarmLogs = alarmLogs.where((alarm) {
          DateTime dateTime;
          try {
            dateTime = DateTime.parse(alarm['timestamp']);
          } catch (e) {
            print("Error parsing timestamp: ${alarm['timestamp']}");
            return false;
          }

          int month = dateTime.month;
          int year = dateTime.year;

          int selectedMonthInt = selectedMonth != null ? months.indexOf(selectedMonth!) + 1 : -1;
          int selectedYearInt = selectedYear != null ? int.parse(selectedYear!) : -1;

          bool matchesMonth = selectedMonth == null || month == selectedMonthInt;
          bool matchesYear = selectedYear == null || year == selectedYearInt;

          return matchesMonth && matchesYear;
        }).toList();
      }
    });
  }

  String _formatTimestamp(String timestamp) {
    if (timestamp.isEmpty) return "No timestamp";

    try {
      DateTime dateTime = DateTime.parse(timestamp);
      final DateFormat dateFormatter = DateFormat('MMMM d, yyyy');
      final DateFormat timeFormatter = DateFormat('h:mm a');

      String formattedDate = dateFormatter.format(dateTime);
      String formattedTime = timeFormatter.format(dateTime);

      return "$formattedDate ($formattedTime)";
    } catch (e) {
      return "Invalid timestamp format";
    }
  }

  bool _exceedsThreshold(Map<String, dynamic> data, Map<String, dynamic> thresholds) {
    return (data['carbon_monoxide'] > thresholds['co_threshold'] ||
        data['humidity_dht22'] < thresholds['humidity_threshold'] ||
        data['indoor_air_quality'] > thresholds['iaq_threshold'] ||
        data['smoke_level'] > thresholds['smoke_threshold'] ||
        data['temperature_mlx90614'] > thresholds['temp_threshold'] ||
        data['temperature_dht22'] > thresholds['temp_threshold']);
  }

  void _showSensorValues(BuildContext context, Map<String, dynamic> alarm) async {
    var thresholdDoc = await _firestore.collection('Threshold').doc('Proxy').get();
    if (!thresholdDoc.exists) return;

    var thresholds = thresholdDoc.data()!;
    String formattedTimestamp = _formatTimestamp(alarm['timestamp']);

    final Map<String, Map<String, String>> sensorDetails = {
      'humidity_dht22': {'name': 'Humidity', 'unit': '%'},
      'temperature_dht22': {'name': 'Temperature 1', 'unit': '°C'},
      'temperature_mlx90614': {'name': 'Temperature 2', 'unit': '°C'},
      'smoke_level': {'name': 'Smoke', 'unit': 'µg/m³'},
      'indoor_air_quality': {'name': 'Air Quality', 'unit': 'AQI'},
      'carbon_monoxide': {'name': 'Carbon Monoxide', 'unit': 'ppm'},
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              alarm['id'],
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 5),
            Text(
              "Timestamp: $formattedTimestamp",
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  fontFamily: 'Arimo'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 5),
            ...alarm['values'].entries.map<Widget>((entry) {
              if (entry.key == 'timestamp') return SizedBox.shrink();

              var sensorInfo = sensorDetails[entry.key] ?? {'name': entry.key, 'unit': ''};
              String sensorName = sensorInfo['name']!;
              String sensorUnit = sensorInfo['unit']!;
              bool exceedsThreshold = _exceedsThresholdForSensor(entry.key, entry.value, thresholds);

              return Container(
                decoration: exceedsThreshold
                    ? BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: Colors.red[800]!,
                    width: 1.0,
                  ),
                )
                    : null,
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "$sensorName:",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: exceedsThreshold ? Colors.red[700] : Colors.black,
                      ),
                    ),
                    Text(
                      "${entry.value} $sensorUnit",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: exceedsThreshold ? Colors.red[700] : Colors.black,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  bool _exceedsThresholdForSensor(String sensorKey, dynamic sensorValue, Map<String, dynamic> thresholds) {
    switch (sensorKey) {
      case 'carbon_monoxide':
        return sensorValue > thresholds['co_threshold'];
      case 'humidity_dht22':
        return sensorValue < thresholds['humidity_threshold'];
      case 'indoor_air_quality':
        return sensorValue > thresholds['iaq_threshold'];
      case 'smoke_level':
        return sensorValue > thresholds['smoke_threshold'];
      case 'temperature_mlx90614':
        return sensorValue > thresholds['temp_threshold'];
      case 'temperature_dht22':
        return sensorValue > thresholds['temp_threshold'];
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Image.asset('assets/official-logo.png', height: 100),
                      SizedBox(width: 15),
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Alarm Logs',
                              style: TextStyle(
                                color: Color(0xFF494949),
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            SizedBox(height: 2),
                            Container(
                              width: 25,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Color(0xFF494949),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 15),
                  Divider(color: Colors.grey[200], thickness: 5),
                  SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Alarm Logs History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(width: 5),
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.white,
                              insetPadding: EdgeInsets.symmetric(horizontal: 20.0),
                              contentPadding: EdgeInsets.all(16.0),
                              content: Container(
                                width: 120,
                                height: 180,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset('assets/question-mark.png',
                                      width: 40,
                                      height: 40,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      "Alarm Logs History",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Container(
                                      width: 20,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: Color(0xFF494949),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    SizedBox(height: 13),
                                    Text(
                                      "This section allows you to review all previously triggered alarms, helping you stay informed about past incidents and potential issues",
                                      style: TextStyle(fontSize: 16),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        child: Opacity(
                          opacity: 0.6,
                          child: Image.asset(
                            'assets/info-icon.png',
                            width: 20,
                            height: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  _buildDeviceDropdown(),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          DropdownButton<String>(
                            value: selectedMonth,
                            hint: Text('Select Month'),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedMonth = newValue;
                                _filterAlarms();
                              });
                            },
                            items: months.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                          SizedBox(width: 10),
                          DropdownButton<String>(
                            value: selectedYear,
                            hint: Text('Select Year'),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedYear = newValue;
                                _filterAlarms();
                              });
                            },
                            items: years.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            selectedMonth = null;
                            selectedYear = null;
                            filteredAlarmLogs = alarmLogs;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow[600],
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Show All',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Arimo',
                              color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  if (selectedMonth != null && selectedYear != null)
                    _buildMonthYearLabel(selectedMonth!, selectedYear!),
                ],
              ),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: filteredAlarmLogs.isEmpty && selectedMonth == null &&
                    selectedYear == null
                    ? alarmLogs.length
                    : filteredAlarmLogs.length,
                itemBuilder: (context, index) {
                  var alarm = filteredAlarmLogs.isEmpty &&
                      selectedMonth == null && selectedYear == null
                      ? alarmLogs[index]
                      : filteredAlarmLogs[index];
                  return Card(
                    color: Colors.grey[300],
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(alarm['id'],
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800)),
                      subtitle: Text("Timestamp: ${_formatTimestamp(
                          alarm['timestamp'])}"),
                      onTap: () => _showSensorValues(context, alarm),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Device {
  final String productCode;
  final String name;

  Device({required this.productCode, required this.name});
}