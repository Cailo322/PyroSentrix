import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:focus_detector/focus_detector.dart';
import 'dart:async';
import 'dart:io';
import 'custom_app_bar.dart';

class AlarmLogScreen extends StatefulWidget {
  const AlarmLogScreen({Key? key}) : super(key: key);

  @override
  _AlarmLogScreenState createState() => _AlarmLogScreenState();
}

class _AlarmLogScreenState extends State<AlarmLogScreen> {
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> alarmLogs = [];
  List<Map<String, dynamic>> filteredAlarmLogs = [];
  int alarmCount = 0;
  String? selectedYear;
  String? _selectedProductCode;
  List<Device> _devices = [];
  StreamSubscription? _alarmSubscription;
  StreamSubscription? _sensorSubscription;
  Map<String, String> _deviceNames = {};
  bool _isLoading = true;

  static const List<String> months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  final List<String> years = ['2023', '2024', '2025'];

  Map<String, bool> selectedMonths = {
    for (var month in months) month: false
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDeviceNames().then((_) => _fetchDevices());
      _refreshIndicatorKey.currentState?.show();
    });
  }

  @override
  void dispose() {
    _alarmSubscription?.cancel();
    _sensorSubscription?.cancel();
    super.dispose();
  }

  Future<bool> _checkAndRequestStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 29) {
        var status = await Permission.photos.status;
        if (!status.isGranted) {
          status = await Permission.photos.request();
        }
        return status.isGranted;
      } else {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        return status.isGranted;
      }
    } else if (Platform.isIOS) {
      var status = await Permission.photos.status;
      if (!status.isGranted) {
        status = await Permission.photos.request();
      }
      return status.isGranted;
    }
    return true;
  }

  Future<void> _downloadImage(BuildContext context, String imageUrl) async {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      final hasPermission = await _checkAndRequestStoragePermission();
      if (!hasPermission) {
        scaffold.showSnackBar(
          const SnackBar(content: Text('Storage permission required to download images')),
        );
        return;
      }

      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        scaffold.showSnackBar(
          const SnackBar(content: Text('Could not access storage directory')),
        );
        return;
      }

      final downloadDir = Directory('${directory.path}/Pyrosentrix');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final fileName = 'alarm_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${downloadDir.path}/$fileName';

      final taskId = await FlutterDownloader.enqueue(
        url: imageUrl,
        savedDir: downloadDir.path,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: true,
      );

      if (taskId != null) {
        try {
          final saved = await GallerySaver.saveImage(imageUrl, albumName: 'Pyrosentrix');
          if (saved == true) {
            scaffold.showSnackBar(
              const SnackBar(content: Text('Image saved to gallery and Pyrosentrix folder')),
            );
          } else {
            scaffold.showSnackBar(
              const SnackBar(content: Text('Image saved to Pyrosentrix folder only')),
            );
          }
        } catch (e) {
          scaffold.showSnackBar(
            SnackBar(content: Text('Saved to Pyrosentrix folder but gallery save failed: ${e.toString()}')),
          );
        }
      } else {
        scaffold.showSnackBar(
          const SnackBar(content: Text('Failed to start download')),
        );
      }
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(content: Text('Download failed: ${e.toString()}')),
      );
    }
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
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching devices: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAlarmHistory() async {
    if (_selectedProductCode == null) return;

    _alarmSubscription?.cancel();
    _alarmSubscription = _firestore
        .collection('SensorData')
        .doc('AlarmLogs')
        .collection(_selectedProductCode!)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) return;

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
          DateTime latestDate = DateTime.parse(alarmLogs.first['timestamp']);
          String latestMonth = months[latestDate.month - 1];
          String latestYear = latestDate.year.toString();

          selectedMonths = {for (var month in months) month: false};
          selectedMonths[latestMonth] = true;
          selectedYear = latestYear;

          var lastAlarmId = alarmLogs.first['id'];
          if (lastAlarmId != null && lastAlarmId.startsWith('Alarm ')) {
            alarmCount = int.parse(lastAlarmId.split(' ')[1]);
          }
        }
      });
    });
  }

  Future<void> _listenToLatestSensorData() async {
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
        var existingAlarm = await _firestore
            .collection('SensorData')
            .doc('AlarmLogs')
            .collection(_selectedProductCode!)
            .where('sensorDataDocId', isEqualTo: latestDoc.id)
            .limit(1)
            .get();

        if (existingAlarm.docs.isEmpty) {
          var alarmStatusDoc = await _firestore
              .collection('AlarmStatus')
              .doc(_selectedProductCode)
              .get();

          if (!alarmStatusDoc.exists || alarmStatusDoc['AlarmLogged'] == false) {
            String sensorDataDocId = latestDoc.id;
            await Future.delayed(Duration(seconds: 3));
            String? imageUrl = await _fetchLatestImageUrl();

            if (alarmLogs.isNotEmpty) {
              var lastAlarmId = alarmLogs.first['id'];
              if (lastAlarmId != null && lastAlarmId.startsWith('Alarm ')) {
                alarmCount = int.parse(lastAlarmId.split(' ')[1]);
              }
            }
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
      }
    });
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      alarmLogs.clear();
      filteredAlarmLogs.clear();
    });

    await Future.delayed(Duration(milliseconds: 500));

    if (_selectedProductCode != null) {
      await _fetchAlarmHistory();
      await _listenToLatestSensorData();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Widget _buildNoDeviceUI() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
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
          ),
          SizedBox(height: 15),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 19),
            child: Divider(color: Colors.grey[200], thickness: 5),
          ),
          SizedBox(height: 69),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/nodevice.png', width: 200, height: 200),
              SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  "You don't have any IoT devices connected to your account.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              ),
              SizedBox(height: 10),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  "Please add a device or ask your household admin to share access with you.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FocusDetector(
      onFocusGained: () {
        _refreshIndicatorKey.currentState?.show();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: CustomAppBar(),
        endDrawer: CustomDrawer(),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _devices.isEmpty
            ? RefreshIndicator(
          key: _refreshIndicatorKey,
          onRefresh: _refreshData,
          child: _buildNoDeviceUI(),
        )
            : RefreshIndicator(
          key: _refreshIndicatorKey,
          onRefresh: _refreshData,
          child: _buildAlarmLogsContent(),
        ),
      ),
    );
  }

  Widget _buildAlarmLogsContent() {
    int selectedMonthCount = selectedMonths.values.where((selected) => selected).length;
    String? singleSelectedMonth = selectedMonthCount == 1
        ? selectedMonths.entries.firstWhere((entry) => entry.value).key
        : null;

    bool noMonthsSelected = selectedMonthCount == 0;

    return Container(
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
                if (singleSelectedMonth != null && selectedYear != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Divider(color: Colors.grey[400], thickness: 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            '$singleSelectedMonth $selectedYear',
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
                    ),
                  )
                else if (noMonthsSelected && selectedYear != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Divider(color: Colors.grey[400], thickness: 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            selectedYear!,
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
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: filteredAlarmLogs.length,
              itemBuilder: (context, index) {
                var alarm = filteredAlarmLogs[index];
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
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9D9D9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: DropdownButton<String>(
                      value: _selectedProductCode,
                      hint: const Text(
                        'Select device',
                        style: TextStyle(fontSize: 10),
                      ),
                      isExpanded: true,
                      underline: Container(),
                      items: _devices.map((Device device) {
                        return DropdownMenuItem<String>(
                          value: device.productCode,
                          child: Text(
                            device.name,
                            style: TextStyle(fontSize: 10),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedProductCode = newValue;
                          alarmLogs.clear();
                          filteredAlarmLogs.clear();
                          _fetchAlarmHistory();
                          _listenToLatestSensorData();
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9D9D9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: PopupMenuButton<String>(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Select Month(s)',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      itemBuilder: (BuildContext context) {
                        return [
                          PopupMenuItem<String>(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Select All',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                    StatefulBuilder(
                                      builder: (BuildContext context, StateSetter setState) {
                                        bool allSelected = selectedMonths.values.every((val) => val);
                                        return Checkbox(
                                          value: allSelected,
                                          onChanged: (bool? value) {
                                            setState(() {
                                              for (var month in selectedMonths.keys) {
                                                selectedMonths[month] = value!;
                                              }
                                            });
                                            this.setState(() {
                                              _filterAlarms();
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                Divider(),
                              ],
                            ),
                          ),
                          ...selectedMonths.keys.map((String month) {
                            return PopupMenuItem<String>(
                              child: StatefulBuilder(
                                builder: (BuildContext context, StateSetter setState) {
                                  return CheckboxListTile(
                                    title: Text(
                                      month,
                                      style: TextStyle(fontSize: 10),
                                    ),
                                    value: selectedMonths[month],
                                    onChanged: (bool? value) {
                                      setState(() {
                                        selectedMonths[month] = value!;
                                      });
                                      this.setState(() {
                                        _filterAlarms();
                                      });
                                    },
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        ];
                      },
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9D9D9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: DropdownButton<String>(
                      value: selectedYear,
                      hint: const Text(
                        'Select year',
                        style: TextStyle(fontSize: 10),
                      ),
                      isExpanded: true,
                      underline: Container(),
                      items: years.map((year) {
                        return DropdownMenuItem<String>(
                          value: year,
                          child: Text(
                            year,
                            style: TextStyle(fontSize: 10),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedYear = value;
                          _filterAlarms();
                        });
                      },
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
        content: SingleChildScrollView(
          child: Column(
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

              if (alarm['imageUrl'] != null) ...[
                Divider(thickness: 1, color: Colors.grey),
                SizedBox(height: 10),
                Center(
                  child: Text(
                    "Image Captured",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _showFullScreenImage(context, alarm['imageUrl']),
                  child: Center(
                    child: Image.network(
                      alarm['imageUrl'],
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Text('Failed to load image');
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
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

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(10),
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                width: MediaQuery.of(context).size.width,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                children: [
                  FloatingActionButton(
                    heroTag: 'download_btn',
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: () async => await _downloadImage(context, imageUrl),
                    child: Icon(Icons.download, color: Colors.black),
                  ),
                  SizedBox(width: 10),
                  FloatingActionButton(
                    heroTag: 'close_btn',
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close, color: Colors.black),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  void _filterAlarms() {
    setState(() {
      if (selectedYear == null && !selectedMonths.containsValue(true)) {
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

          bool anyMonthSelected = selectedMonths.containsValue(true);
          bool matchesMonth = !anyMonthSelected;

          if (anyMonthSelected) {
            matchesMonth = selectedMonths[months[month - 1]] ?? false;
          }

          bool matchesYear = selectedYear == null || year == int.parse(selectedYear!);

          return matchesMonth && matchesYear;
        }).toList();
      }
    });
  }
}

class Device {
  final String productCode;
  final String name;

  Device({required this.productCode, required this.name});
}