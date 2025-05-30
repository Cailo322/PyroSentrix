import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'custom_app_bar.dart';
import 'call.dart';
import 'notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MonitorScreen extends StatefulWidget {
  final String productCode;

  MonitorScreen({required this.productCode});

  @override
  _MonitorScreenState createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  bool _isDialogOpen = false;
  List<String> _lastDisplayedWarnings = [];
  Set<String> _acknowledgedAlerts = {};
  String _deviceName = 'Device';
  OverlayEntry? _matrixOverlayEntry;

  @override
  void initState() {
    super.initState();
    _notificationService.initialize();
    _loadDeviceName();
  }

  Future<void> _loadDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceNameKey = 'device_name_${widget.productCode}';
    setState(() {
      _deviceName = prefs.getString(deviceNameKey) ?? 'Device';
    });
  }

  Future<Map<String, dynamic>?> fetchLatestImage() async {
    try {
      await Future.delayed(Duration(seconds: 3));
      QuerySnapshot querySnapshot = await _firestore
          .collection(widget.productCode)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data() as Map<String, dynamic>;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching latest image: $e');
      }
    }
    return null;
  }

  Future<bool> _shouldShowDialog() async {
    try {
      DocumentSnapshot dialogStatusDoc = await _firestore
          .collection('DialogStatus')
          .doc(widget.productCode)
          .get();
      if (dialogStatusDoc.exists) {
        return !(dialogStatusDoc.data() as Map<String, dynamic>)['Dialogpop'];
      } else {
        await _firestore.collection('DialogStatus').doc(widget.productCode).set({'Dialogpop': false});
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking DialogStatus: $e');
      }
      return true;
    }
  }

  Future<void> _updateDialogStatus(bool status) async {
    try {
      await _firestore
          .collection('DialogStatus')
          .doc(widget.productCode)
          .update({'Dialogpop': status});
    } catch (e) {
      if (kDebugMode) {
        print('Error updating DialogStatus: $e');
      }
    }
  }

  void _toggleMatrixOverlay() {
    if (_matrixOverlayEntry == null) {
      _matrixOverlayEntry = OverlayEntry(
        builder: (context) => GestureDetector(
          onTap: () => _toggleMatrixOverlay(),
          child: Material(
            color: Colors.black.withOpacity(0.85),
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  padding: EdgeInsets.all(40),
                  child: Image.asset(
                    'assets/matrix.png',
                    width: MediaQuery.of(context).size.width * 0.8,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      Overlay.of(context).insert(_matrixOverlayEntry!);
    } else {
      _matrixOverlayEntry?.remove();
      _matrixOverlayEntry = null;
    }
  }

  @override
  void dispose() {
    _matrixOverlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    final isSmallScreen = screenWidth < 360 || textScaleFactor > 1.3;
    final isLargeScreen = screenWidth > 600 && textScaleFactor <= 1.3;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(),
      endDrawer: CustomDrawer(),
      body: FutureBuilder<DocumentSnapshot>(
        future: _firestore.collection('Threshold').doc('Proxy').get(),
        builder: (context, thresholdSnapshot) {
          if (!thresholdSnapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          var thresholdData = thresholdSnapshot.data!.data() as Map<String, dynamic>;

          return StreamBuilder(
            stream: _firestore
                .collection('SensorData')
                .doc('FireAlarm')
                .collection(widget.productCode)
                .orderBy('timestamp', descending: true)
                .limit(1)
                .snapshots(),
            builder: (context, sensorSnapshot) {
              if (sensorSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!sensorSnapshot.hasData || sensorSnapshot.data!.docs.isEmpty) {
                return Center(child: Text('No sensor data available.'));
              }

              var sensorData = sensorSnapshot.data!.docs.first.data();
              List<String> allExceededWarnings = checkThresholds(sensorData, thresholdData);
              List<String> exceededWarningsForDialog = allExceededWarnings
                  .where((warning) => !_acknowledgedAlerts.contains(warning))
                  .toList();

              List<String> cautionSensors = [];
              if (sensorData['humidity_dht22'] < thresholdData['humidity_threshold'] * 1.25) {
                cautionSensors.add('HUMIDITY');
              }
              if (sensorData['temperature_dht22'] > thresholdData['temp_threshold'] * 0.75) {
                cautionSensors.add('TEMP.1');
              }
              if (sensorData['carbon_monoxide'] > thresholdData['co_threshold'] * 0.75) {
                cautionSensors.add('CO');
              }
              if (sensorData['smoke_level'] > thresholdData['smoke_threshold'] * 0.75) {
                cautionSensors.add('SMOKE');
              }
              if (sensorData['temperature_mlx90614'] > thresholdData['temp_threshold'] * 0.75) {
                cautionSensors.add('TEMP.2');
              }
              if (sensorData['indoor_air_quality'] > thresholdData['iaq_threshold'] * 0.75) {
                cautionSensors.add('AIR QUALITY');
              }

              String bottomText = "All sensors are in normal level.";
              String bottomIcon = 'assets/normal.png';

              if (allExceededWarnings.isNotEmpty) {
                bottomText = "FIRE DETECTED! Please call your fire station immediately!";
                bottomIcon = 'assets/warning.png';
              } else if (cautionSensors.isNotEmpty) {
                String sensorList = _formatSensorList(cautionSensors);
                bottomText = "CAUTION! $sensorList close to reaching critical levels. Please inspect your area immediately.";
                bottomIcon = 'assets/caution.png';
              }

              if (exceededWarningsForDialog.isNotEmpty && !_isDialogOpen) {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  bool shouldShowDialog = await _shouldShowDialog();
                  if (shouldShowDialog) {
                    _isDialogOpen = true;
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return Dialog(
                          backgroundColor: Colors.white,
                          insetPadding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 100),
                            child: Container(
                              padding: EdgeInsets.zero,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(height: 20),
                                  Image.asset(
                                    'assets/warningpop_with-shadow.png',
                                    width: 60,
                                    height: 60,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'WARNING',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'Jura',
                                        color: Colors.red[900]),
                                  ),
                                  SizedBox(height: 5),
                                  Padding(
                                    padding: EdgeInsets.all(5),
                                    child: Text(
                                      exceededWarningsForDialog.join("\n"),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF414141),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  FutureBuilder<Map<String, dynamic>?>(
                                    future: fetchLatestImage(),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return Container(
                                          width: 200,
                                          height: 150,
                                          child: Center(child: CircularProgressIndicator()),
                                        );
                                      } else if (snapshot.hasData && snapshot.data != null) {
                                        return Image.network(
                                          snapshot.data!['imageUrl'],
                                          width: 200,
                                          height: 150,
                                          fit: BoxFit.cover,
                                        );
                                      } else {
                                        return Image.asset('assets/About-pic1.jpg',
                                            width: 120, height: 120);
                                      }
                                    },
                                  ),
                                  SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton(
                                          style: TextButton.styleFrom(
                                            backgroundColor: Colors.red[900],
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                            minimumSize: Size(double.infinity, 48),
                                            padding: EdgeInsets.zero,
                                          ),
                                          onPressed: () async {
                                            try {
                                              await FirebaseFirestore.instance
                                                  .collection('BooleanConditions')
                                                  .doc('Alarm')
                                                  .update({'isHushed': true});
                                              _acknowledgedAlerts.addAll(exceededWarningsForDialog);
                                              _notificationService.stopAlarmSound();
                                              _isDialogOpen = false;
                                              Navigator.of(context).pop();
                                            } catch (e) {
                                              print('Error updating Firestore: $e');
                                            }
                                          },
                                          child: Text(
                                            'HUSH',
                                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 2,
                                        color: Colors.white,
                                      ),
                                      // In the dialog builder part of your code, replace the TextButton for CALL FIRESTATION with this:
                                      Expanded(
                                        child: TextButton(
                                          style: TextButton.styleFrom(
                                            backgroundColor: Colors.red[900],
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                            minimumSize: Size(double.infinity, 48),
                                            padding: EdgeInsets.zero,
                                          ),
                                          onPressed: () async {
                                            _acknowledgedAlerts.addAll(exceededWarningsForDialog);
                                            _notificationService.stopAlarmSound();
                                            _isDialogOpen = false;
                                            Navigator.of(context).pop();
                                            Navigator.push(context, MaterialPageRoute(builder: (context) => CallHelpScreen()));
                                          },
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 4.0),
                                              child: Text(
                                                'CALL FIRESTATION',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w900
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ).then((_) {
                      _isDialogOpen = false;
                    });
                    Future.delayed(Duration(seconds: 9), () {
                      _updateDialogStatus(true);
                    });
                  }
                });
              } else if (exceededWarningsForDialog.isEmpty) {
                _lastDisplayedWarnings.clear();
              }

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 160,
                                  height: 160,
                                  child: Image.asset('assets/official-logo.png'),
                                ),
                                SizedBox(height: 35),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$_deviceName Display',
                                      style: TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF494949),
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _toggleMatrixOverlay(),
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
                                SizedBox(height: 3),
                                Container(
                                  height: 4,
                                  width: 33,
                                  decoration: BoxDecoration(
                                    color: Color(0xFF494949),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                                SizedBox(height: 20),
                                Text(
                                  'Monitor your sensors here',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.black,
                                    fontFamily: 'Jost',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 30),
                          Padding(
                            padding: EdgeInsets.only(bottom: 20.0),
                            child: GridView.count(
                              shrinkWrap: true,
                              crossAxisCount: isLargeScreen ? 3 : 2,
                              crossAxisSpacing: isSmallScreen ? 10 : 20,
                              mainAxisSpacing: isSmallScreen ? 10 : 20,
                              childAspectRatio: isSmallScreen ? 0.9 : 1,
                              physics: NeverScrollableScrollPhysics(),
                              children: [
                                SensorCard(
                                  title: 'HUMIDITY',
                                  status: determineStatus(sensorData['humidity_dht22'], thresholdData['humidity_threshold'], 'humidity'),
                                  value: '${sensorData['humidity_dht22']}%',
                                  statusColor: determineStatusColor(sensorData['humidity_dht22'], thresholdData['humidity_threshold'], 'humidity'),
                                  valueColor: determineStatusColor(sensorData['humidity_dht22'], thresholdData['humidity_threshold'], 'humidity'),
                                  isSmallScreen: isSmallScreen,
                                ),
                                SensorCard(
                                  title: 'TEMP.1',
                                  status: determineStatus(sensorData['temperature_dht22'], thresholdData['temp_threshold'], 'temperature'),
                                  value: '${sensorData['temperature_dht22']}°C',
                                  statusColor: determineStatusColor(sensorData['temperature_dht22'], thresholdData['temp_threshold'], 'temperature'),
                                  valueColor: determineStatusColor(sensorData['temperature_dht22'], thresholdData['temp_threshold'], 'temperature'),
                                  isSmallScreen: isSmallScreen,
                                ),
                                SensorCard(
                                  title: 'CO',
                                  status: determineStatus(sensorData['carbon_monoxide'], thresholdData['co_threshold'], 'co'),
                                  value: '${sensorData['carbon_monoxide']}ppm',
                                  statusColor: determineStatusColor(sensorData['carbon_monoxide'], thresholdData['co_threshold'], 'co'),
                                  valueColor: determineStatusColor(sensorData['carbon_monoxide'], thresholdData['co_threshold'], 'co'),
                                  isSmallScreen: isSmallScreen,
                                ),
                                SensorCard(
                                  title: 'SMOKE',
                                  status: determineStatus(sensorData['smoke_level'], thresholdData['smoke_threshold'], 'smoke'),
                                  value: '${sensorData['smoke_level']}µg/m³',
                                  statusColor: determineStatusColor(sensorData['smoke_level'], thresholdData['smoke_threshold'], 'smoke'),
                                  valueColor: determineStatusColor(sensorData['smoke_level'], thresholdData['smoke_threshold'], 'smoke'),
                                  isSmallScreen: isSmallScreen,
                                ),
                                SensorCard(
                                  title: 'TEMP.2',
                                  status: determineStatus(sensorData['temperature_mlx90614'], thresholdData['temp_threshold'], 'temperature'),
                                  value: '${sensorData['temperature_mlx90614']}°C',
                                  statusColor: determineStatusColor(sensorData['temperature_mlx90614'], thresholdData['temp_threshold'], 'temperature'),
                                  valueColor: determineStatusColor(sensorData['temperature_mlx90614'], thresholdData['temp_threshold'], 'temperature'),
                                  isSmallScreen: isSmallScreen,
                                ),
                                SensorCard(
                                  title: 'AIR QUALITY',
                                  status: determineStatus(sensorData['indoor_air_quality'], thresholdData['iaq_threshold'], 'iaq'),
                                  value: '${sensorData['indoor_air_quality']} AQI',
                                  statusColor: determineStatusColor(sensorData['indoor_air_quality'], thresholdData['iaq_threshold'], 'iaq'),
                                  valueColor: determineStatusColor(sensorData['indoor_air_quality'], thresholdData['iaq_threshold'], 'iaq'),
                                  isSmallScreen: isSmallScreen,
                                  titleStyle: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF494949),
                                    fontFamily: 'Arimo',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(9.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(bottomIcon, width: 60, height: 60),
                        SizedBox(width: 5),
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                if (bottomText.contains("FIRE DETECTED!"))
                                  TextSpan(
                                    text: "FIRE DETECTED! ",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: Colors.red,
                                      fontFamily: 'Arimo',
                                    ),
                                  ),
                                if (bottomText.contains("CAUTION!"))
                                  TextSpan(
                                    text: "CAUTION! ",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: Color(0xFFFF7020),
                                      fontFamily: 'Arimo',
                                    ),
                                  ),
                                TextSpan(
                                  text: bottomText.replaceFirst(
                                      RegExp(r'^(FIRE DETECTED!|CAUTION!) '), ""),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[700],
                                    fontFamily: 'Arimo',
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.left,
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<String> checkThresholds(Map<String, dynamic> sensorData, Map<String, dynamic> thresholdData) {
    List<String> warnings = [];

    if (sensorData['humidity_dht22'] < thresholdData['humidity_threshold']) {
      warnings.add('Humidity levels are dangerously low. This increases fire risk and may impact air quality.');
    }

    if (sensorData['temperature_dht22'] > thresholdData['temp_threshold']) {
      warnings.add('Temperature (DHT22) has exceeded safe limits. Potential fire risk, take immediate action.');
    }

    if (sensorData['carbon_monoxide'] > thresholdData['co_threshold']) {
      warnings.add('Carbon monoxide levels are dangerously high. Potential fire risk, take immediate action.');
    }

    if (sensorData['smoke_level'] > thresholdData['smoke_threshold']) {
      warnings.add('High smoke levels detected. Potential fire risk, take immediate action.');
    }

    if (sensorData['temperature_mlx90614'] > thresholdData['temp_threshold']) {
      warnings.add('Temperature (MLX90614) has exceeded safe limits. Potential fire risk, take immediate action.');
    }

    if (sensorData['indoor_air_quality'] > thresholdData['iaq_threshold']) {
      warnings.add('Indoor air quality is poor. Potential fire risk, take immediate action.');
    }

    return warnings;
  }

  String determineStatus(dynamic value, dynamic threshold, String sensorType) {
    if (sensorType == 'humidity') {
      if (value < threshold) return 'Critical';
      if (value < threshold * 1.25) return 'Caution';
      return 'Normal';
    } else {
      if (value > threshold) return 'Critical';
      if (value > threshold * 0.75) return 'Caution';
      return 'Normal';
    }
  }

  Color determineStatusColor(dynamic value, dynamic threshold, String sensorType) {
    if (sensorType == 'humidity') {
      if (value < threshold) return Color(0xFFF20606);
      if (value < threshold * 1.25) return Color(0xFFFF7020);
      return Color(0xFF039F00);
    } else {
      if (value > threshold) return Color(0xFFF20606);
      if (value > threshold * 0.75) return Color(0xFFFF7020);
      return Color(0xFF039F00);
    }
  }

  String _formatSensorList(List<String> sensors) {
    Map<String, String> sensorDescriptions = {
      'HUMIDITY': 'Humidity',
      'TEMP.1': 'Temperature (DHT22)',
      'Carbon': 'Carbon Monoxide',
      'SMOKE': 'Smoke Level',
      'TEMP.2': 'Temperature (MLX90614)',
      'Air Quality': 'Air Quality',
    };

    List<String> fullSensorNames = sensors.map((s) => sensorDescriptions[s] ?? s).toList();
    String verb = fullSensorNames.length == 1 ? "is" : "are";

    if (fullSensorNames.length == 1) {
      return "${fullSensorNames.first} $verb";
    }
    return "${fullSensorNames.take(fullSensorNames.length - 1).join(', ')} and ${fullSensorNames.last} $verb";
  }
}

class SensorCard extends StatelessWidget {
  final String title;
  final String status;
  final String value;
  final Color statusColor;
  final Color valueColor;
  final TextStyle? titleStyle;
  final bool isSmallScreen;

  const SensorCard({
    required this.title,
    required this.status,
    required this.value,
    required this.statusColor,
    required this.valueColor,
    this.titleStyle,
    required this.isSmallScreen,
  });

  void _showSensorInfoDialog(BuildContext context) {
    String sensorInfo = '';
    switch (title) {
      case 'HUMIDITY':
        sensorInfo = 'Measures air moisture. Low humidity can indicate heat and dryness, while high humidity may lead to mold growth.';
        break;
      case 'TEMP.1':
      case 'TEMP.2':
        sensorInfo = 'Checks the temperature around you. If it gets too hot, there might be a fire risk.If it rises too high, it may indicate a fire risk. The higher the Celsius value, the hotter the environment ';
        break;
      case 'CO':
        sensorInfo = 'Detects carbon monoxide (CO), an invisible, odorless, and hazardous gas commonly produced by incomplete combustion. Measured in parts per million (PPM), higher levels indicate increased danger.';
        break;
      case 'SMOKE':
        sensorInfo = 'Detects PM2.5 smoke particles, which are fine airborne particles that can indicate potential fire hazards. Elevated smoke levels may pose both fire and health risks. Measured in micrograms per cubic meter (µg/m³).';
        break;
      case 'AIR QUALITY':
        sensorInfo = 'Measures general gases in the air, including VOCs, smoke, and carbon dioxide (CO₂), indicating overall air quality and pollutant levels. A higher index signifies poorer air quality.';
        break;
      default:
        sensorInfo = 'No specific information available for this sensor.';
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isSmall = MediaQuery.of(context).size.width < 360 ||
            MediaQuery.of(context).textScaleFactor > 1.3;

        return AlertDialog(
          backgroundColor: Colors.white,
          content: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/person.png',
                  width: isSmall ? 70 : 90,
                  height: isSmall ? 70 : 90,
                ),
                SizedBox(width: isSmall ? 5 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: isSmall ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: isSmall ? 2 : 4),
                      Text(
                        'Sensor Information',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                          fontSize: isSmall ? 12 : 14,
                        ),
                      ),
                      SizedBox(height: isSmall ? 4 : 8),
                      Text(
                        sensorInfo,
                        style: TextStyle(
                          fontSize: isSmall ? 12 : 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          contentPadding: EdgeInsets.fromLTRB(
            isSmall ? 12 : 16,
            isSmall ? 15 : 20,
            isSmall ? 12 : 16,
            isSmall ? 5 : 10,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    final isTextLarge = textScaleFactor > 1.3;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: double.infinity,
        minHeight: isSmallScreen ? 140 : 180,
      ),
      child: GestureDetector(
        onTap: () => _showSensorInfoDialog(context),
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 10.0 : 14.0),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 4,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: titleStyle ?? TextStyle(
                      fontSize: isSmallScreen
                          ? (isTextLarge ? 14 : 16)
                          : (isTextLarge ? 16 : 18),
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF494949),
                      fontFamily: 'Arimo',
                    ),
                  ),
                  SizedBox(height: 2),
                  Container(
                    width: 17,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Color(0xFFB9B9B9),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 4 : 8),
                  Text(
                    'Status Level:',
                    style: TextStyle(
                      fontSize: isSmallScreen
                          ? (isTextLarge ? 11 : 13)
                          : (isTextLarge ? 13 : 16),
                      color: Color(0xFF494949),
                      fontFamily: 'Jost',
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: isSmallScreen
                          ? (isTextLarge ? 12 : 14)
                          : (isTextLarge ? 14 : 18),
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      fontFamily: 'Arimo',
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 4 : 8),
                  Text(
                    'Value:',
                    style: TextStyle(
                      fontSize: isSmallScreen
                          ? (isTextLarge ? 11 : 13)
                          : (isTextLarge ? 13 : 16),
                      color: Color(0xFF494949),
                      fontFamily: 'Jost',
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: isSmallScreen
                          ? (isTextLarge ? 12 : 14)
                          : (isTextLarge ? 14 : 18),
                      fontWeight: FontWeight.bold,
                      color: valueColor,
                      fontFamily: 'Arimo',
                    ),
                  ),
                ],
              ),
              if (status == 'Critical')
                Positioned(
                  top: -4,
                  right: -4,
                  child: Icon(
                    Icons.warning_rounded,
                    color: Colors.red,
                    size: isSmallScreen ? 22 : 28,
                  ),
                ),
              if (title == 'HUMIDITY')
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Image.asset(
                    'assets/humidity.png',
                    width: isSmallScreen ? 22 : 28,
                    height: isSmallScreen ? 22 : 28,
                  ),
                ),
              if (title == 'TEMP.1' || title == 'TEMP.2')
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Image.asset(
                    'assets/temperature.png',
                    width: isSmallScreen ? 22 : 28,
                    height: isSmallScreen ? 22 : 28,
                  ),
                ),
              if (title == 'SMOKE')
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Image.asset(
                    'assets/smoke.png',
                    width: isSmallScreen ? 22 : 28,
                    height: isSmallScreen ? 22 : 28,
                  ),
                ),
              if (title == 'CO')
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Image.asset(
                    'assets/CO.png',
                    width: isSmallScreen ? 22 : 28,
                    height: isSmallScreen ? 22 : 28,
                  ),
                ),
              if (title == 'AIR QUALITY')
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Image.asset(
                    'assets/IAQ.png',
                    width: isSmallScreen ? 22 : 28,
                    height: isSmallScreen ? 22 : 28,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}