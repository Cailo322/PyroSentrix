import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting

class AlarmLogScreen extends StatefulWidget {
  final String productCode; // Accept productCode
  const AlarmLogScreen({Key? key, required this.productCode}) : super(key: key);

  @override
  _AlarmLogScreenState createState() => _AlarmLogScreenState();
}

class _AlarmLogScreenState extends State<AlarmLogScreen> {
  List<Map<String, dynamic>> alarmLogs = [];
  List<Map<String, dynamic>> filteredAlarmLogs = [];
  int alarmCount = 0;
  String? selectedMonth;
  String? selectedYear;

  final List<String> months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  final List<String> years = [
    '2023',
    '2024',
    '2025'
  ]; // Add more years as needed

  @override
  void initState() {
    super.initState();
    _listenToLatestSensorData();
    _fetchAlarmHistory(); // Fetch historical alarms when the screen loads
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Ensure the entire screen background is white
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    // Align logo to the top
                    children: <Widget>[
                      Image.asset('assets/official-logo.png', height: 100),
                      SizedBox(width: 15),
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        // Adjust text lower
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
                  // Full-width line
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
                            builder: (context) =>
                                AlertDialog(
                                  // Adjust the width of the dialog
                                  backgroundColor: Colors.white,
                                  insetPadding: EdgeInsets.symmetric(
                                      horizontal: 20.0),
                                  // Horizontal padding for the dialog
                                  contentPadding: EdgeInsets.all(16.0),
                                  // Padding inside the dialog
                                  content: Container(
                                    width: 120,
                                    // Set a fixed width for the content
                                    height: 180,
                                    // Set a fixed height for the content
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      // Make the column take up only as much space as needed
                                      children: [
                                        Image.asset(
                                          'assets/question-mark.png',
                                          // Path to your image
                                          width: 40,
                                          // Set the width of the image
                                          height: 40, // Set the height of the image
                                        ),
                                        SizedBox(height: 16),
                                        // Add some space between the image and the text
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
                                            borderRadius: BorderRadius.circular(
                                                2),
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
                          // Adjust the opacity (0.0 = fully transparent, 1.0 = fully opaque)
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                        items: months.map<DropdownMenuItem<String>>((
                            String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            selectedMonth = null;
                            selectedYear = null;
                            filteredAlarmLogs = alarmLogs; // Show all alarms
                          });
                        },
                        child: Text('Show All'),
                      ),
                      DropdownButton<String>(
                        value: selectedYear,
                        hint: Text('Select Year'),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedYear = newValue;
                            _filterAlarms();
                          });
                        },
                        items: years.map<DropdownMenuItem<String>>((
                            String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
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
                    color: Colors.grey[300], // Changed to light grey
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(alarm['id']),
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

  // Filter alarms based on selected month and year
  void _filterAlarms() {
    setState(() {
      if (selectedMonth == null && selectedYear == null) {
        // If no filters are selected, show all alarms
        filteredAlarmLogs = alarmLogs;
      } else {
        // Filter alarms based on selected month and year
        filteredAlarmLogs = alarmLogs.where((alarm) {
          DateTime dateTime;
          try {
            dateTime = DateTime.parse(alarm['timestamp'])
                .toLocal(); // Convert to local time
          } catch (e) {
            print("Error parsing timestamp: ${alarm['timestamp']}");
            return false; // Skip this alarm if the timestamp is invalid
          }

          int month = dateTime.month; // Month as an integer (1-12)
          int year = dateTime.year; // Year as an integer (e.g., 2025)

          // Convert the selected month to its corresponding integer value
          int selectedMonthInt = selectedMonth != null ? months.indexOf(
              selectedMonth!) + 1 : -1;
          int selectedYearInt = selectedYear != null
              ? int.parse(selectedYear!)
              : -1;

          // Debugging logs
          print("Alarm Timestamp: ${dateTime.toString()}");
          print("Alarm Month: $month, Alarm Year: $year");
          print(
              "Selected Month: $selectedMonthInt, Selected Year: $selectedYearInt");

          // Compare with selected month and year
          bool matchesMonth = selectedMonth == null ||
              month == selectedMonthInt;
          bool matchesYear = selectedYear == null || year == selectedYearInt;

          return matchesMonth && matchesYear;
        }).toList();
      }

      // Debugging log to check the filtered alarms
      print("Filtered Alarms: ${filteredAlarmLogs.length}");
    });
  }

  // Format timestamp to "March 7, 2025" format
  String _formatTimestamp(String timestamp) {
    if (timestamp.isEmpty) return "No timestamp";

    try {
      // Parse the string timestamp into a DateTime object
      DateTime dateTime = DateTime.parse(timestamp)
          .toLocal(); // Convert to local time
      final DateFormat formatter = DateFormat(
          'MMMM d, yyyy'); // Format like "March 7, 2025"
      return formatter.format(dateTime);
    } catch (e) {
      return "Invalid timestamp format";
    }
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
      var thresholdDoc = await FirebaseFirestore.instance.collection(
          'Threshold').doc('Proxy').get();
      if (!thresholdDoc.exists) return;

      var thresholds = thresholdDoc.data()!;

      // Check if any sensor exceeds the threshold
      if (_exceedsThreshold(data, thresholds)) {
        // Check the AlarmStatus collection to see if an alarm has already been logged
        var alarmStatusDoc = await FirebaseFirestore.instance
            .collection('AlarmStatus')
            .doc(widget.productCode)
            .get();

        if (!alarmStatusDoc.exists || alarmStatusDoc['AlarmLogged'] == false) {
          // Log the alarm only if AlarmLogged is false
          String sensorDataDocId = latestDoc
              .id; // Use the sensor data document ID as a unique key

          // Add a 1-second delay to ensure we get the latest image
          await Future.delayed(Duration(seconds: 1));

          // Fetch the latest image URL from the Firestore collection
          String? imageUrl = await _fetchLatestImageUrl();

          alarmCount++;
          var alarmData = {
            'id': 'Alarm $alarmCount',
            'timestamp': data['timestamp'],
            'values': data,
            'sensorDataDocId': sensorDataDocId,
            // Store the sensor data document ID
            'imageUrl': imageUrl,
            // Store the image URL
            'logged': true,
            // Mark this alarm as logged
          };

          // Save alarm data to Firestore under SensorData > AlarmLogs > {productCode}
          await FirebaseFirestore.instance
              .collection('SensorData')
              .doc('AlarmLogs')
              .collection(
              widget.productCode) // Use productCode as the collection name
              .add(alarmData);

          // Update the AlarmStatus collection to mark the alarm as logged
          await FirebaseFirestore.instance
              .collection('AlarmStatus')
              .doc(widget.productCode)
              .set({'AlarmLogged': true}, SetOptions(merge: true));

          // Update the list of alarms in the UI
          setState(() {
            alarmLogs.insert(
                0, alarmData); // Add the new alarm to the top of the list
            _filterAlarms();
          });
        }
      }
    });
  }

  // Fetch the latest image URL from Firestore
  Future<String?> _fetchLatestImageUrl() async {
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection(
          widget.productCode) // Use the productCode as the collection name
          .orderBy(
          'timestamp', descending: true) // Order by timestamp (latest first)
          .limit(1) // Get only the latest document
          .get();

      if (snapshot.docs.isNotEmpty) {
        var latestDoc = snapshot.docs.first;
        return latestDoc['imageUrl']; // Return the image URL
      }
    } catch (e) {
      print('Error fetching image URL: $e');
    }
    return null; // Return null if no image URL is found
  }

  // Check if any sensor exceeds the threshold
  bool _exceedsThreshold(Map<String, dynamic> data,
      Map<String, dynamic> thresholds) {
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
        .collection(
        widget.productCode) // Fetch logs for the specific productCode
        .orderBy('timestamp', descending: true)
        .get();

    setState(() {
      alarmLogs = snapshot.docs.map((doc) {
        var data = doc.data();
        return {
          'id': data['id'],
          'timestamp': data['timestamp'],
          'values': data['values'],
          'imageUrl': data['imageUrl'], // Include the image URL
        };
      }).toList();
      filteredAlarmLogs =
          alarmLogs; // Initialize filteredAlarmLogs with all alarms
    });
  }

  // Show detailed sensor values in a dialog when an alarm is tapped
  void _showSensorValues(BuildContext context,
      Map<String, dynamic> alarm) async {
    // Fetch the thresholds
    var thresholdDoc = await FirebaseFirestore.instance.collection('Threshold')
        .doc('Proxy')
        .get();
    if (!thresholdDoc.exists) return;

    var thresholds = thresholdDoc.data()!;

    // Format the timestamp
    String formattedTimestamp = _formatTimestamp(alarm['timestamp']);

    // Map sensor keys to readable names and units
    final Map<String, Map<String, String>> sensorDetails = {
      'humidity_dht22': {'name': 'Humidity', 'unit': '%'},
      'temperature_dht22': {'name': 'Temperature 1', 'unit': '°C'},
      'temperature_mlx90614': {'name': 'Temperature 2', 'unit': '°C'},
      'smoke_level': {'name': 'Smoke', 'unit': 'ppm'},
      'indoor_air_quality': {'name': 'Indoor Air Quality', 'unit': 'ppm'},
      'carbon_monoxide': {'name': 'Carbon Monoxide', 'unit': 'ppm'},
    };

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            backgroundColor: Colors.white, // Set the background color to white
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alarm['id'],
                  style: TextStyle(
                    fontSize: 25, // Set the font size
                    fontWeight: FontWeight.bold, // Set the font weight
                    color: Colors.black87, // Set the text color
                  ),
                ),
                SizedBox(height: 5),
                // Add a small gap between the title and timestamp
                Text(
                  "Timestamp: $formattedTimestamp", // Formatted timestamp
                  style: TextStyle(fontSize: 17), // Larger font size
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 10),
                // Add some space below the timestamp
                ...alarm['values'].entries.map<Widget>((entry) {
                  // Skip the 'timestamp' field in sensor values
                  if (entry.key == 'timestamp') return SizedBox.shrink();

                  // Get readable name and unit for the sensor
                  var sensorInfo = sensorDetails[entry.key] ??
                      {'name': entry.key, 'unit': ''};
                  String sensorName = sensorInfo['name']!;
                  String sensorUnit = sensorInfo['unit']!;

                  // Check if the sensor value exceeds the threshold
                  bool exceedsThreshold = _exceedsThresholdForSensor(
                      entry.key, entry.value, thresholds);

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    // Align sensor values to the right
                    children: [
                      Text(
                        "$sensorName:", // Sensor name
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: exceedsThreshold
                              ? FontWeight.bold
                              : FontWeight.bold, // Bold if exceeds threshold
                          color: exceedsThreshold ? Colors.red[700] : Colors
                              .black, // Keep the color black
                        ),
                      ),
                      Text(
                        "${entry.value} $sensorUnit", // Sensor value with unit
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: exceedsThreshold
                              ? FontWeight.bold
                              : FontWeight.normal, // Bold if exceeds threshold
                          color: exceedsThreshold ? Colors.red[700] : Colors
                              .black, // Highlight in red if exceeds threshold
                        ),
                      ),
                    ],
                  );
                }).toList(),
                SizedBox(height: 15),
                Divider(color: Colors.grey[300], thickness: 1),
                // Add a divider below the last sensor
                SizedBox(height: 5),
                Center(
                  child: Text(
                    "Image Captured:",
                    style: TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 16), // Larger font size
                  ),
                ),
                SizedBox(height: 10),
                if (alarm['imageUrl'] != null)
                  Image.network(alarm['imageUrl']),
                // Display the image if available
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context), child: Text("Close"))
            ],
          ),
    );
  }

// Helper method to check if a specific sensor value exceeds its threshold
  bool _exceedsThresholdForSensor(String sensorKey, dynamic sensorValue,
      Map<String, dynamic> thresholds) {
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
}

//THIS IS EDITED NA --RONI

