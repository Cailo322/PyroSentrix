import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AlarmLogScreen extends StatefulWidget {
  final String productCode; // Accept productCode

  const AlarmLogScreen({Key? key, required this.productCode}) : super(key: key);

  @override
  _AlarmLogScreenState createState() => _AlarmLogScreenState();
}

class _AlarmLogScreenState extends State<AlarmLogScreen> {
  List<Map<String, dynamic>> alarmLogs = [];
  int alarmCount = 0;

  @override
  void initState() {
    super.initState();
    _listenToLatestSensorData();
    _fetchAlarmHistory(); // Fetch historical alarms when the screen loads
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Ensure the entire screen background is white
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Container(
        color: Colors.white, // Explicitly setting the background color
        child: Column(
          children: [
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start, // Align logo to the top
                    children: <Widget>[
                      Image.asset('assets/official-logo.png', height: 100),
                      SizedBox(width: 15),
                      Padding(
                        padding: const EdgeInsets.only(top: 40), // Adjust text lower
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
                  Divider(color: Colors.grey[200], thickness: 5), // Full-width line
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
                              content: Text("This is where you can monitor the alarms"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text("Close"),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Opacity(
                          opacity: 0.5, // Adjust the opacity (0.0 = fully transparent, 1.0 = fully opaque)
                          child: Image.asset(
                            'assets/info-icon.png',
                            width: 20,
                            height: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: alarmLogs.length,
                itemBuilder: (context, index) {
                  var alarm = alarmLogs[index];
                  return Card(
                    color: Colors.grey[200], // Changed to light grey
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(alarm['id']),
                      subtitle: Text("Timestamp: ${alarm['timestamp']}"),
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

  // Listen to the latest document in SensorData > FireAlarm > (productCode) collection
  void _listenToLatestSensorData() {
    FirebaseFirestore.instance
        .collection('SensorData')
        .doc('FireAlarm')
        .collection(widget.productCode) // Use the productCode
        .orderBy('timestamp', descending: true)
        .limit(1) // Only get the latest document
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;

      var latestDoc = snapshot.docs.first;
      var data = latestDoc.data();
      var thresholdDoc = await FirebaseFirestore.instance.collection('Threshold').doc('Proxy').get();
      if (!thresholdDoc.exists) return;

      var thresholds = thresholdDoc.data()!;

      // Check if any sensor exceeds the threshold
      if (_exceedsThreshold(data, thresholds)) {
        String sensorDataDocId = latestDoc.id; // Use the sensor data document ID as a unique key

        // Check if an alarm log already exists for this sensor data document
        bool alarmExists = await _checkIfAlarmExists(sensorDataDocId);
        if (alarmExists) return; // Skip if an alarm log already exists

        alarmCount++;
        var alarmData = {
          'id': 'Alarm $alarmCount',
          'timestamp': data['timestamp'],
          'values': data,
          'sensorDataDocId': sensorDataDocId, // Store the sensor data document ID
        };

        // Save alarm data to Firestore under SensorData > AlarmLogs > {productCode}
        await FirebaseFirestore.instance
            .collection('SensorData')
            .doc('AlarmLogs')
            .collection(widget.productCode) // Use productCode as the collection name
            .add(alarmData);

        // Update the list of alarms in the UI
        setState(() {
          alarmLogs.insert(0, alarmData); // Add the new alarm to the top of the list
        });
      }
    });
  }

  // Check if an alarm log already exists for the given sensor data document ID
  Future<bool> _checkIfAlarmExists(String sensorDataDocId) async {
    var snapshot = await FirebaseFirestore.instance
        .collection('SensorData')
        .doc('AlarmLogs')
        .collection(widget.productCode)
        .where('sensorDataDocId', isEqualTo: sensorDataDocId)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty; // Return true if an alarm log exists
  }

  // Check if any sensor exceeds the threshold
  bool _exceedsThreshold(Map<String, dynamic> data, Map<String, dynamic> thresholds) {
    return (data['carbon_monoxide'] > thresholds['co_threshold'] ||
        data['humidity_dht22'] < thresholds['humidity_threshold'] ||
        data['indoor_air_quality'] > thresholds['iaq_threshold'] ||
        data['smoke_level'] > thresholds['smoke_threshold'] ||
        data['temperature_mlx90614'] > thresholds['temp_threshold'] ||
        data['temperature_dht22'] > thresholds['temp_threshold']);
  }

  // Fetch historical alarms from Firestore
  void _fetchAlarmHistory() async {
    var snapshot = await FirebaseFirestore.instance
        .collection('SensorData')
        .doc('AlarmLogs')
        .collection(widget.productCode) // Fetch logs for the specific productCode
        .orderBy('timestamp', descending: true)
        .get();

    setState(() {
      alarmLogs = snapshot.docs.map((doc) {
        var data = doc.data();
        return {
          'id': data['id'],
          'timestamp': data['timestamp'],
          'values': data['values'],
        };
      }).toList();
    });
  }

  // Show detailed sensor values in a dialog when an alarm is tapped
  void _showSensorValues(BuildContext context, Map<String, dynamic> alarm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(alarm['id']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: alarm['values'].entries.map<Widget>((entry) {
            return Text("${entry.key}: ${entry.value}");
          }).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Close"))
        ],
      ),
    );
  }
}