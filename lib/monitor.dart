import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'custom_app_bar.dart';
import 'call.dart';
import 'notification_service.dart'; // Import the NotificationService
import 'package:flutter/foundation.dart';

class MonitorScreen extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService(); // Instance of NotificationService
  bool _isDialogOpen = false;
  List<String> _lastDisplayedWarnings = [];
  Set<String> _acknowledgedAlerts = {}; // Track acknowledged alerts

  MonitorScreen() {
    _notificationService.initialize(); // Initialize notification service
  }

  @override
  Widget build(BuildContext context) {
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
            stream: _firestore.collection('SensorData').orderBy('timestamp', descending: true).limit(1).snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> sensorSnapshot) {
              if (sensorSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!sensorSnapshot.hasData || sensorSnapshot.data!.docs.isEmpty) {
                return Center(child: Text('No sensor data available.'));
              }

              var sensorData = sensorSnapshot.data!.docs.first.data() as Map<String, dynamic>;

              // Check each sensor and build a list of warning messages if any threshold is exceeded
              List<String> allExceededWarnings = checkThresholds(sensorData, thresholdData);
              List<String> exceededWarningsForDialog = allExceededWarnings
                  .where((warning) => !_acknowledgedAlerts.contains(warning))
                  .toList(); // Warnings that haven't been acknowledged, for dialog

              // Determine the icon and message for the bottom section based on the sensor data
              String bottomText = "";
              String bottomIcon = 'assets/default.png';

              if (allExceededWarnings.isEmpty) {
                bottomText = "All sensors are in normal level.";
                bottomIcon = 'assets/normal.png';
              } else {
                List<String> cautionSensors = [];
                List<String> fireSensors = [];

                for (var warning in allExceededWarnings) {
                  if (warning.contains('nearing') || warning.contains('Caution')) {
                    cautionSensors.add(warning.split(' ')[0]);
                  } else if (warning.contains('above the safe threshold') ||
                      warning.contains('dangerously high') ||
                      warning.contains('unsafe level') ||
                      warning.contains('fire risk') ||
                      warning.contains('critically low') ||
                      warning.contains('poor')) {
                    fireSensors.add(warning.split(' ')[0]);
                  }
                }

                if (fireSensors.isNotEmpty) {
                  bottomText = "FIRE DETECTED! Please call your fire station immediately!";
                  bottomIcon = 'assets/warning.png';
                } else if (cautionSensors.isNotEmpty) {
                  String sensorList = _formatSensorList(cautionSensors);
                  bottomText = "CAUTION! $sensorList close to reaching abnormal levels. Please inspect your area immediately.";
                  bottomIcon = 'assets/caution.png';
                }
              }

              // Show the alert dialog if new warnings exist
              if (exceededWarningsForDialog.isNotEmpty && !_isDialogOpen) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _isDialogOpen = true;

                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset('assets/warningpop.png', width: 48, height: 48),
                            SizedBox(height: 10),
                            Text(
                              exceededWarningsForDialog.join("\n"),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0xFF414141),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            onPressed: () {
                              // Acknowledge alerts when HUSH is pressed
                              _acknowledgedAlerts.addAll(exceededWarningsForDialog);
                              _notificationService.stopAlarmSound();
                              _isDialogOpen = false;
                              Navigator.of(context).pop();
                            },
                            child: Text('HUSH', style: TextStyle(color: Colors.white)),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            onPressed: () {
                              // Acknowledge alerts when CALL FIRESTATION is pressed
                              _acknowledgedAlerts.addAll(exceededWarningsForDialog);
                              _notificationService.stopAlarmSound();
                              _isDialogOpen = false;
                              Navigator.of(context).pop();
                              Navigator.push(context, MaterialPageRoute(builder: (context) => CallHelpScreen()));
                            },
                            child: Text('CALL FIRESTATION', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      );
                    },
                  ).then((_) {
                    _isDialogOpen = false; // Ensure the flag is reset when the dialog is closed
                  });
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
                                  width: 150,
                                  height: 150,
                                  child: Image.asset('assets/flashlogo.png'),
                                ),
                                SizedBox(height: 20),
                                Text(
                                  'Sensor Display',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF494949),
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                SizedBox(height: 1),
                                Container(
                                  height: 4,  // Height of the underline
                                  width: 33,  // Width of the underline
                                  decoration: BoxDecoration(
                                    color: Color(0xFF494949), // Color of the underline
                                    borderRadius: BorderRadius.circular(5), // Rounded corners for the underline
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Monitor your sensors here',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black,
                                    fontFamily: 'Jost',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),
                          GridView.count(
                            shrinkWrap: true,
                            crossAxisCount: 2,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                            childAspectRatio: 0.8,
                            physics: NeverScrollableScrollPhysics(),
                            children: [
                              SensorCard(
                                title: 'HUMIDITY',
                                status: determineStatus(sensorData['humidity_dht22'], thresholdData['humidity_threshold'], 'humidity'),
                                value: '${sensorData['humidity_dht22']}%',
                                statusColor: determineStatusColor(sensorData['humidity_dht22'], thresholdData['humidity_threshold'], 'humidity'),
                                valueColor: determineStatusColor(sensorData['humidity_dht22'], thresholdData['humidity_threshold'], 'humidity'),
                              ),
                              SensorCard(
                                title: 'TEMP.1',
                                status: determineStatus(sensorData['temperature_dht22'], thresholdData['temp_threshold'], 'temperature'),
                                value: '${sensorData['temperature_dht22']}°C',
                                statusColor: determineStatusColor(sensorData['temperature_dht22'], thresholdData['temp_threshold'], 'temperature'),
                                valueColor: determineStatusColor(sensorData['temperature_dht22'], thresholdData['temp_threshold'], 'temperature'),
                              ),
                              SensorCard(
                                title: 'CO',
                                status: determineStatus(sensorData['carbon_monoxide'], thresholdData['co_threshold'], 'co'),
                                value: '${sensorData['carbon_monoxide']} ppm',
                                statusColor: determineStatusColor(sensorData['carbon_monoxide'], thresholdData['co_threshold'], 'co'),
                                valueColor: determineStatusColor(sensorData['carbon_monoxide'], thresholdData['co_threshold'], 'co'),
                              ),
                              SensorCard(
                                title: 'SMOKE',
                                status: determineStatus(sensorData['smoke_level'], thresholdData['smoke_threshold'], 'smoke'),
                                value: '${sensorData['smoke_level']}%',
                                statusColor: determineStatusColor(sensorData['smoke_level'], thresholdData['smoke_threshold'], 'smoke'),
                                valueColor: determineStatusColor(sensorData['smoke_level'], thresholdData['smoke_threshold'], 'smoke'),
                              ),
                              SensorCard(
                                title: 'TEMP.2',
                                status: determineStatus(sensorData['temperature_mlx90614'], thresholdData['temp_threshold'], 'temperature'),
                                value: '${sensorData['temperature_mlx90614']}°C',
                                statusColor: determineStatusColor(sensorData['temperature_mlx90614'], thresholdData['temp_threshold'], 'temperature'),
                                valueColor: determineStatusColor(sensorData['temperature_mlx90614'], thresholdData['temp_threshold'], 'temperature'),
                              ),
                              SensorCard(
                                title: 'INDOOR AIR QUALITY',
                                status: determineStatus(sensorData['indoor_air_quality'], thresholdData['iaq_threshold'], 'iaq'),
                                value: '${sensorData['indoor_air_quality']} AQI',
                                statusColor: determineStatusColor(sensorData['indoor_air_quality'], thresholdData['iaq_threshold'], 'iaq'),
                                valueColor: determineStatusColor(sensorData['indoor_air_quality'], thresholdData['iaq_threshold'], 'iaq'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Display the bottom text and icon
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(bottomIcon, width: 60, height: 60),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                if (bottomText.contains("FIRE DETECTED!"))
                                  TextSpan(
                                    text: "FIRE DETECTED! ",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.red,
                                      fontFamily: 'Jost',
                                    ),
                                  ),
                                if (bottomText.contains("CAUTION!"))
                                  TextSpan(
                                    text: "CAUTION! ",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFFFF7020),
                                      fontFamily: 'Jost',
                                    ),
                                  ),
                                TextSpan(
                                  text: bottomText.replaceFirst(
                                      RegExp(r'^(FIRE DETECTED!|CAUTION!) '), ""),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF414141),
                                    fontFamily: 'Jost',
                                    height: 1.3, // Adjusted line spacing
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.left, // Align text to the center for better readability
                            softWrap: true, // Ensure the text wraps to the next line
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
      warnings.add('Humidity levels are critically low and unsafe.');
    } else if (
    sensorData['humidity_dht22'] < thresholdData['humidity_threshold'] * 1.25
    ) {
      warnings.add('Humidity levels are nearing the unsafe threshold.');
    }

    if (sensorData['temperature_dht22'] > thresholdData['temp_threshold']) {
      warnings.add('Temperature (DHT22) is elevated.');
    } else if (sensorData['temperature_dht22'] > thresholdData['temp_threshold'] * 0.75) {
      warnings.add('Temperature (DHT22) is nearing unsafe levels.');
    }

    if (sensorData['carbon_monoxide'] > thresholdData['co_threshold']) {
      warnings.add('Carbon monoxide levels are dangerously high.');
    } else if (sensorData['carbon_monoxide'] > thresholdData['co_threshold'] * 0.75) {
      warnings.add('Carbon monoxide levels are nearing the safe threshold.');
    }

    if (sensorData['smoke_level'] > thresholdData['smoke_threshold']) {
      warnings.add('Smoke levels are high. Possible fire risk.');
    } else if (sensorData['smoke_level'] > thresholdData['smoke_threshold'] * 0.75) {
      warnings.add('Smoke levels are nearing the safe threshold.');
    }

    if (sensorData['temperature_mlx90614'] > thresholdData['temp_threshold']) {
      warnings.add('Temperature (MLX90614) detected an unsafe level.');
    } else if (sensorData['temperature_mlx90614'] > thresholdData['temp_threshold'] * 0.75) {
      warnings.add('Temperature (MLX90614) is nearing unsafe levels.');
    }

    if (sensorData['indoor_air_quality'] > thresholdData['iaq_threshold']) {
      warnings.add('Indoor air quality is poor. Ventilation is recommended.');
    } else if (sensorData['indoor_air_quality'] > thresholdData['iaq_threshold'] * 0.75) {
      warnings.add('Indoor air quality is nearing poor levels.');
    }

    return warnings; // Empty if no thresholds are exceeded
  }


  String determineStatus(dynamic value, dynamic threshold, String sensorType) {
    if (sensorType == 'humidity') {
      if (value < threshold) return 'Abnormal'; // Humidity too low
      if (value < threshold * 1.25) return 'Caution'; // Humidity nearing low threshold
      return 'Normal'; // Humidity is normal
    } else {
      if (value > threshold) return 'Abnormal'; // Sensor exceeds the safe threshold
      if (value > threshold * 0.75) return 'Caution'; // Sensor nearing the threshold
      return 'Normal'; // Sensor is in a safe range
    }
  }

  Color determineStatusColor(dynamic value, dynamic threshold, String sensorType) {
    if (sensorType == 'humidity') {
      if (value < threshold) return Color(0xFFF20606); // Red for Abnormal (low humidity)
      if (value < threshold * 1.25) return Color(0xFFFF7020); // Orange for Caution (nearing low humidity)
      return Color(0xFF039F00); // Green for Normal humidity
    } else {
      if (value > threshold) return Color(0xFFF20606); // Red for Abnormal (high value for other sensors)
      if (value > threshold * 0.75) return Color(0xFFFF7020); // Orange for Caution (nearing high threshold)
      return Color(0xFF039F00); // Green for Normal
    }
  }

  String _formatSensorList(List<String> sensors) {
    Map<String, String> sensorDescriptions = {
      'HUMIDITY': 'Humidity',
      'TEMP.1': 'Temperature (DHT22)',
      'Carbon': 'Carbon Monoxide',
      'SMOKE': 'Smoke Level',
      'TEMP.2': 'Temperature (MLX90614)',
      'Indoor': 'Indoor Air Quality',
    };

    // Map sensor codes to descriptions
    List<String> fullSensorNames = sensors.map((s) => sensorDescriptions[s] ?? s).toList();

    // Determine if we need 'is' or 'are'
    String verb = fullSensorNames.length == 1 ? "is" : "are";

    // Format the list with proper grammar
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

  SensorCard({
    required this.title,
    required this.status,
    required this.value,
    required this.statusColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2), // Shadow color
            spreadRadius: 2, // How much the shadow spreads
            blurRadius: 5, // How blurred the shadow is
            offset: Offset(0, 4), // Shadow position (x, y)
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none, // Important to allow the icon to overflow
        children: [
          // Card Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF494949),
                  fontFamily: 'Jost',
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Status Level:',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF494949),
                  fontFamily: 'Jost',
                ),
              ),
              SizedBox(height: 5),
              Text(
                status,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                  fontFamily: 'Jost',
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Value:',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF494949),
                  fontFamily: 'Jost',
                ),
              ),
              SizedBox(height: 5),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                  fontFamily: 'Jost',
                ),
              ),
            ],
          ),
          // Add the warning icon outside the top-right corner of the card
          if (status == 'Abnormal')
            Positioned(
              top: -15, // Adjusted position to be outside the card but visible
              right: -15, // Adjusted position to be outside the card but visible
              child: Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: 35, // Icon size adjusted for better visibility
              ),
            ),
        ],
      ),
    );
  }
}
