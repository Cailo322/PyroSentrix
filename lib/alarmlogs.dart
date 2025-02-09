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
  Set<String> processedAlarmIds = {}; // To track processed alarm IDs

  @override
  void initState() {
    super.initState();
    _listenToLatestSensorData();
    _fetchAlarmHistory(); // Fetch historical alarms when the screen loads
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
        String alarmId = latestDoc.id; // Use document ID to track the alarm
        if (processedAlarmIds.contains(alarmId)) return; // Prevent duplicates

        alarmCount++;
        var alarmData = {
          'id': 'Alarm $alarmCount',
          'timestamp': data['timestamp'],
          'values': data,
        };

        // Save alarm data to Firestore
        await FirebaseFirestore.instance.collection('AlarmLogs').add(alarmData);

        // Update the list of alarms in the UI
        setState(() {
          alarmLogs.insert(0, alarmData); // Add the new alarm to the top of the list
        });

        // Track the alarm ID to avoid re-logging
        processedAlarmIds.add(alarmId);
      }
    });
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
        .collection('AlarmLogs')
        .where('product_code', isEqualTo: widget.productCode) // Filter by productCode
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Alarm Log')),
      body: ListView.builder(
        itemCount: alarmLogs.length,
        itemBuilder: (context, index) {
          var alarm = alarmLogs[index];
          return Card(
            child: ListTile(
              title: Text(alarm['id']),
              subtitle: Text("Timestamp: ${alarm['timestamp']}"),
              onTap: () => _showSensorValues(context, alarm),
            ),
          );
        },
      ),
    );
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