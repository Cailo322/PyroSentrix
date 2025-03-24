import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class TrendLinePainter extends CustomPainter {
  final List<FlSpot> trendLine;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final Color color;

  TrendLinePainter({
    required this.trendLine,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (trendLine.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Convert FlSpot points to Offset points
    final startX = trendLine.first.x;
    final startY = trendLine.first.y;
    final endX = trendLine.last.x;
    final endY = trendLine.last.y;

    // Map the points to the canvas coordinates
    final startPoint = Offset(
      (startX - minX) / (maxX - minX) * size.width,
      size.height - (startY - minY) / (maxY - minY) * size.height,
    );
    final endPoint = Offset(
      (endX - minX) / (maxX - minX) * size.width,
      size.height - (endY - minY) / (maxY - minY) * size.height,
    );

    // Draw the trend line
    canvas.drawLine(startPoint, endPoint, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late List<SensorData> _sensorData = [];
  String? _selectedProductCode;
  List<Device> _devices = [];
  StreamSubscription<QuerySnapshot>? _sensorDataSubscription;
  String _selectedTimeRange = 'Current';
  Set<String> _selectedSensors = {
    'temperaturedht22',
    'temperaturemlx90614',
    'humidity',
    'carbonmonoxide',
    'indoorairquality',
    'smokelevel',
  };
  bool _showLegend = true;

  final List<String> _timeRanges = [
    'Current',
    '10 minutes',
    '1 hour',
    '8 hours',
    '1 day',
    '1 week',
    '1 month',
  ];

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  @override
  void dispose() {
    _sensorDataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchDevices() async {
    final firestore = FirebaseFirestore.instance;
    final userEmail = FirebaseAuth.instance.currentUser?.email;

    if (userEmail == null) return;

    try {
      final userSnapshot = await firestore
          .collection('ProductActivation')
          .where('user_email', isEqualTo: userEmail)
          .get();

      final sharedSnapshot = await firestore
          .collection('ProductActivation')
          .where('shared_users', arrayContains: userEmail)
          .get();

      final uniqueDevices = <String, Device>{};
      for (var doc in userSnapshot.docs) {
        final productCode = doc['product_code'];
        uniqueDevices[productCode] = Device(
          productCode: productCode,
          name: 'Device $productCode',
        );
      }
      for (var doc in sharedSnapshot.docs) {
        final productCode = doc['product_code'];
        if (!uniqueDevices.containsKey(productCode)) {
          uniqueDevices[productCode] = Device(
            productCode: productCode,
            name: 'Device $productCode',
          );
        }
      }

      setState(() {
        _devices = uniqueDevices.values.toList();
      });
    } catch (e) {
      print('Error fetching devices: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch devices: $e')),
      );
    }
  }

  void _startSensorDataListener() {
    _sensorDataSubscription?.cancel();

    if (_selectedProductCode == null || !mounted) return;

    final firestore = FirebaseFirestore.instance;

    if (_selectedTimeRange == 'Current') {
      _sensorDataSubscription = firestore
          .collection('SensorData')
          .doc('FireAlarm')
          .collection(_selectedProductCode!)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots()
          .listen((querySnapshot) {
        if (mounted) {
          setState(() {
            _sensorData = querySnapshot.docs.map((doc) {
              final data = doc.data();
              final utcTimestamp = DateTime.parse(data['timestamp']);
              final adjustedTimestamp = utcTimestamp.subtract(Duration(hours: 8));
              return SensorData(
                timestamp: adjustedTimestamp,
                carbonMonoxide: data['carbon_monoxide'].toDouble(),
                humidity: data['humidity_dht22'].toDouble(),
                indoorAirQuality: data['indoor_air_quality'].toDouble(),
                smokeLevel: data['smoke_level'].toDouble(),
                temperatureDHT22: data['temperature_dht22'].toDouble(),
                temperatureMLX90614: data['temperature_mlx90614'].toDouble(),
              );
            }).toList();
          });
        }
      }, onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to listen to data: $error')),
          );
        }
      });
    } else {
      DateTime now = DateTime.now();
      DateTime startTime;

      switch (_selectedTimeRange) {
        case '10 minutes':
          startTime = now.subtract(Duration(minutes: 10));
          break;
        case '1 hour':
          startTime = now.subtract(Duration(hours: 1));
          break;
        case '8 hours':
          startTime = now.subtract(Duration(hours: 8));
          break;
        case '1 day':
          startTime = now.subtract(Duration(days: 1));
          break;
        case '1 week':
          startTime = now.subtract(Duration(days: 7));
          break;
        case '1 month':
          startTime = now.subtract(Duration(days: 30));
          break;
        default:
          startTime = now.subtract(Duration(minutes: 10));
      }

      _sensorDataSubscription = firestore
          .collection('SensorData')
          .doc('FireAlarm')
          .collection(_selectedProductCode!)
          .where('timestamp', isGreaterThanOrEqualTo: startTime.toIso8601String())
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((querySnapshot) {
        if (mounted) {
          setState(() {
            _sensorData = _aggregateData(querySnapshot.docs.map((doc) {
              final data = doc.data();
              final utcTimestamp = DateTime.parse(data['timestamp']);
              final adjustedTimestamp = utcTimestamp.subtract(Duration(hours: 8));
              return SensorData(
                timestamp: adjustedTimestamp,
                carbonMonoxide: data['carbon_monoxide'].toDouble(),
                humidity: data['humidity_dht22'].toDouble(),
                indoorAirQuality: data['indoor_air_quality'].toDouble(),
                smokeLevel: data['smoke_level'].toDouble(),
                temperatureDHT22: data['temperature_dht22'].toDouble(),
                temperatureMLX90614: data['temperature_mlx90614'].toDouble(),
              );
            }).toList());
          });
        }
      }, onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to listen to data: $error')),
          );
        }
      });
    }
  }

  List<SensorData> _aggregateData(List<SensorData> data) {
    if (_selectedTimeRange == 'Current' || _selectedTimeRange == '10 minutes') {
      return data;
    }

    final Map<String, List<SensorData>> groupedData = {};
    final List<SensorData> aggregatedData = [];

    for (var sensorData in data) {
      String key;
      if (_selectedTimeRange == '1 hour') {
        final minute = sensorData.timestamp.minute ~/ 5 * 5;
        key = '${sensorData.timestamp.hour}:${minute.toString().padLeft(2, '0')}';
      } else if (_selectedTimeRange == '8 hours') {
        key = '${sensorData.timestamp.hour}';
      } else if (_selectedTimeRange == '1 day') {
        key = '${sensorData.timestamp.day}-${sensorData.timestamp.hour ~/ 4 * 4}';
      } else if (_selectedTimeRange == '1 week') {
        key = '${sensorData.timestamp.weekday}';
      } else if (_selectedTimeRange == '1 month') {
        key = '${sensorData.timestamp.day}';
      } else {
        key = '${sensorData.timestamp.hour}';
      }

      if (!groupedData.containsKey(key)) {
        groupedData[key] = [];
      }
      groupedData[key]!.add(sensorData);
    }

    groupedData.forEach((key, value) {
      final avgCarbonMonoxide = _roundToTwoDecimalPlaces(value.map((e) => e.carbonMonoxide).reduce((a, b) => a + b) / value.length);
      final avgHumidity = _roundToTwoDecimalPlaces(value.map((e) => e.humidity).reduce((a, b) => a + b) / value.length);
      final avgIndoorAirQuality = _roundToTwoDecimalPlaces(value.map((e) => e.indoorAirQuality).reduce((a, b) => a + b) / value.length);
      final avgSmokeLevel = _roundToTwoDecimalPlaces(value.map((e) => e.smokeLevel).reduce((a, b) => a + b) / value.length);
      final avgTemperatureDHT22 = _roundToTwoDecimalPlaces(value.map((e) => e.temperatureDHT22).reduce((a, b) => a + b) / value.length);
      final avgTemperatureMLX90614 = _roundToTwoDecimalPlaces(value.map((e) => e.temperatureMLX90614).reduce((a, b) => a + b) / value.length);

      aggregatedData.add(SensorData(
        timestamp: value.first.timestamp,
        carbonMonoxide: avgCarbonMonoxide,
        humidity: avgHumidity,
        indoorAirQuality: avgIndoorAirQuality,
        smokeLevel: avgSmokeLevel,
        temperatureDHT22: avgTemperatureDHT22,
        temperatureMLX90614: avgTemperatureMLX90614,
      ));
    });

    return aggregatedData;
  }

  double _roundToTwoDecimalPlaces(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  double _calculateAverageTemperature(List<SensorData> data) {
    if (data.isEmpty) return 0.0;

    double totalTemperature = 0.0;
    int count = 0;

    for (var sensorData in data) {
      if (_selectedSensors.contains('temperaturedht22')) {
        totalTemperature += sensorData.temperatureDHT22;
        count++;
      }
      if (_selectedSensors.contains('temperaturemlx90614')) {
        totalTemperature += sensorData.temperatureMLX90614;
        count++;
      }
    }

    return count == 0 ? 0.0 : totalTemperature / count;
  }

  double _calculateAverageHumidity(List<SensorData> data) {
    if (data.isEmpty || !_selectedSensors.contains('humidity')) return 0.0;

    double totalHumidity = data.map((e) => e.humidity).reduce((a, b) => a + b);
    return totalHumidity / data.length;
  }

  double _calculateAverageIndoorAirQuality(List<SensorData> data) {
    if (data.isEmpty || !_selectedSensors.contains('indoorairquality')) return 0.0;

    double totalIAQ = data.map((e) => e.indoorAirQuality).reduce((a, b) => a + b);
    return totalIAQ / data.length;
  }

  double _calculateAverageCarbonMonoxide(List<SensorData> data) {
    if (data.isEmpty || !_selectedSensors.contains('carbonmonoxide')) return 0.0;

    double totalCO = data.map((e) => e.carbonMonoxide).reduce((a, b) => a + b);
    return totalCO / data.length;
  }

  double _calculateAverageSmokeLevel(List<SensorData> data) {
    if (data.isEmpty || !_selectedSensors.contains('smokelevel')) return 0.0;

    double totalSmoke = data.map((e) => e.smokeLevel).reduce((a, b) => a + b);
    return totalSmoke / data.length;
  }

  Widget _buildInsightsSection() {
    final averageTemperature = _calculateAverageTemperature(_sensorData);
    final averageHumidity = _calculateAverageHumidity(_sensorData);
    final averageIndoorAirQuality = _calculateAverageIndoorAirQuality(_sensorData);
    final averageCarbonMonoxide = _calculateAverageCarbonMonoxide(_sensorData);
    final averageSmokeLevel = _calculateAverageSmokeLevel(_sensorData);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insights',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Average Temperature: ${averageTemperature.toStringAsFixed(2)}°C',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Average Humidity: ${averageHumidity.toStringAsFixed(2)}%',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Average Indoor Air Quality: ${averageIndoorAirQuality.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Average Carbon Monoxide: ${averageCarbonMonoxide.toStringAsFixed(2)} ppm',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Average Smoke Level: ${averageSmokeLevel.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScatterPlot() {
    if (_sensorData.isEmpty || !_selectedSensors.contains('temperaturedht22') || !_selectedSensors.contains('humidity')) {
      return Center(
        child: Text(
          'No data available for scatter plot.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.black,
          ),
        ),
      );
    }

    // Prepare data for the scatter plot
    final List<ScatterSpot> spots = _sensorData.map((data) {
      return ScatterSpot(
        data.temperatureDHT22, // X-axis: Temperature
        data.humidity, // Y-axis: Humidity
      );
    }).toList();

    // Calculate min and max values for axes
    final minTemp = _sensorData.map((e) => e.temperatureDHT22).reduce((a, b) => a < b ? a : b);
    final maxTemp = _sensorData.map((e) => e.temperatureDHT22).reduce((a, b) => a > b ? a : b);
    final minHumidity = _sensorData.map((e) => e.humidity).reduce((a, b) => a < b ? a : b);
    final maxHumidity = _sensorData.map((e) => e.humidity).reduce((a, b) => a > b ? a : b);

    // Calculate intervals for axes
    final tempInterval = _calculateInterval(minTemp, maxTemp);
    final humidityInterval = _calculateInterval(minHumidity, maxHumidity);

    // Calculate the trend line (linear regression)
    final trendLine = _calculateTrendLine(spots);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9), // Outer container background color
        borderRadius: BorderRadius.circular(10), // Rounded corners
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Temperature vs Humidity',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16.0), // Inner container padding
            decoration: BoxDecoration(
              color: Colors.white, // Inner container background color
              borderRadius: BorderRadius.circular(10), // Rounded corners
            ),
            child: SizedBox(
              height: 200, // Fixed height for the scatter plot
              child: Stack(
                children: [
                  // Scatter Chart
                  ScatterChart(
                    ScatterChartData(
                      scatterSpots: spots,
                      minX: minTemp,
                      maxX: maxTemp,
                      minY: minHumidity,
                      maxY: maxHumidity,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawHorizontalLine: true,
                        drawVerticalLine: true,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.withOpacity(0.5),
                          strokeWidth: 1,
                        ),
                        getDrawingVerticalLine: (value) => FlLine(
                          color: Colors.grey.withOpacity(0.5),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30, // Space for y-axis labels
                            interval: humidityInterval, // Use calculated interval
                            getTitlesWidget: (value, meta) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0), // Add spacing to the right of y-axis labels
                                child: Text(
                                  value.toStringAsFixed(1), // Round to 1 decimal place
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.black,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30, // Space for x-axis labels
                            interval: tempInterval, // Use calculated interval
                            getTitlesWidget: (value, meta) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0), // Add spacing above x-axis labels
                                child: Text(
                                  value.toStringAsFixed(1), // Round to 1 decimal place
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.black,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      scatterTouchData: ScatterTouchData(
                        enabled: true,
                        touchTooltipData: ScatterTouchTooltipData(
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipItems: (ScatterSpot spot) {
                            return ScatterTooltipItem(
                              'Temp: ${spot.x.toStringAsFixed(2)}°C\nHumidity: ${spot.y.toStringAsFixed(2)}%',
                              textStyle: TextStyle(color: Colors.white),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  // Trend Line Overlay
                  CustomPaint(
                    size: Size(double.infinity, 200), // Match the size of the scatter plot
                    painter: TrendLinePainter(
                      trendLine: trendLine,
                      minX: minTemp,
                      maxX: maxTemp,
                      minY: minHumidity,
                      maxY: maxHumidity,
                      color: Colors.red, // Trend line color
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

// Helper method to calculate intervals for axes
  double _calculateInterval(double min, double max) {
    final range = max - min;
    if (range <= 0) return 1.0; // Default interval if range is invalid

    // Calculate a reasonable interval based on the range
    if (range <= 1) return 0.2; // Small range, use smaller intervals
    if (range <= 5) return 1.0; // Medium range, use intervals of 1
    return (range / 5).ceilToDouble(); // Larger range, divide into 5 intervals
  }


  List<FlSpot> _calculateTrendLine(List<FlSpot> spots) {
    if (spots.isEmpty) return [];

    // Calculate the mean of x and y values
    final meanX = spots.map((spot) => spot.x).reduce((a, b) => a + b) / spots.length;
    final meanY = spots.map((spot) => spot.y).reduce((a, b) => a + b) / spots.length;

    // Calculate the slope (m) and intercept (b) for the trend line: y = mx + b
    double numerator = 0;
    double denominator = 0;

    for (final spot in spots) {
      numerator += (spot.x - meanX) * (spot.y - meanY);
      denominator += (spot.x - meanX) * (spot.x - meanX);
    }

    final slope = numerator / denominator;
    final intercept = meanY - slope * meanX;

    // Calculate the start and end points for the trend line
    final startX = spots.map((spot) => spot.x).reduce((a, b) => a < b ? a : b); // Min x
    final endX = spots.map((spot) => spot.x).reduce((a, b) => a > b ? a : b); // Max x

    final startY = slope * startX + intercept;
    final endY = slope * endX + intercept;

    // Return the trend line as two points (start and end)
    return [
      FlSpot(startX, startY),
      FlSpot(endX, endY),
    ];
  }

  Widget _buildSensorChecklistDropdown() {
    final sensorMap = {
      'Temperature (DHT22)': 'temperaturedht22',
      'Temperature (MLX90614)': 'temperaturemlx90614',
      'Humidity': 'humidity',
      'Carbon Monoxide': 'carbonmonoxide',
      'Indoor Air Quality': 'indoorairquality',
      'Smoke': 'smokelevel',
    };

    return PopupMenuButton<String>(
      icon: Icon(Icons.filter_list),
      itemBuilder: (context) {
        return sensorMap.entries.map((entry) {
          final displayName = entry.key;
          final sensorKey = entry.value;

          return PopupMenuItem<String>(
            child: StatefulBuilder(
              builder: (context, setState) {
                return CheckboxListTile(
                  title: Text(displayName),
                  value: _selectedSensors.contains(sensorKey),
                  onChanged: (value) {
                    if (value == true) {
                      _selectedSensors.add(sensorKey);
                    } else {
                      _selectedSensors.remove(sensorKey);
                    }
                    setState(() {});
                    this.setState(() {});
                  },
                );
              },
            ),
          );
        }).toList();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Analytics'),
      ),
      body: Stack( // Use a Stack to overlay the sticky dropdown filters
        children: [
          // Scrollable Content
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, // Allow the Column to expand as needed
              children: [
                // Logo and Title Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Image.asset(
                        'assets/official-logo.png',
                        height: 100,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 35),
                          const Text(
                            'Analytics',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF494949),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 25,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFF494949),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Chart Container
                Container(
                  height: MediaQuery.of(context).size.height * 0.5,
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9D9D9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      // Subtitle and Sensor Checklist Dropdown
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SENSOR ANALYTICS REPORTS',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          _buildSensorChecklistDropdown(),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Chart
                      Expanded(
                        child: _selectedProductCode == null
                            ? const Center(child: Text('Please select a device'))
                            : _sensorData.isEmpty
                            ? const Center(child: CircularProgressIndicator())
                            : _buildChart(),
                      ),
                    ],
                  ),
                ),

                // Insights Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: _buildInsightsSection(),
                ),

                // Scatter Plot Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: _buildScatterPlot(),
                ),

                // Add extra space at the bottom to ensure the dropdown filters don't overlap content
                SizedBox(height: 100), // Adjust this height as needed
              ],
            ),
          ),

          // Sticky Dropdown Filters at the Bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5), // Shadow at the top of the container
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Time Range Dropdown
                  Container(
                    width: MediaQuery.of(context).size.width * 0.33,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9D9D9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: DropdownButton<String>(
                      value: _selectedTimeRange,
                      hint: const Text(
                        'Select time range',
                        style: TextStyle(fontSize: 10),
                      ),
                      isExpanded: true,
                      underline: Container(),
                      items: _timeRanges.map((range) {
                        return DropdownMenuItem<String>(
                          value: range,
                          child: Text(
                            range,
                            style: TextStyle(fontSize: 10),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedTimeRange = value!;
                          _sensorData = [];
                        });
                        _startSensorDataListener();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Device Dropdown
                  Container(
                    width: MediaQuery.of(context).size.width * 0.33,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9D9D9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: DropdownButton<String>(
                      value: _selectedProductCode,
                      hint: const Text(
                        'Select a device',
                        style: TextStyle(fontSize: 10),
                      ),
                      isExpanded: true,
                      underline: Container(),
                      items: _devices.map((device) {
                        return DropdownMenuItem<String>(
                          value: device.productCode,
                          child: Text(
                            device.name,
                            style: TextStyle(fontSize: 10),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProductCode = value;
                          _sensorData = [];
                        });
                        _startSensorDataListener();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final minX = _sensorData.last.timestamp.millisecondsSinceEpoch.toDouble();
    final maxX = _sensorData.first.timestamp.millisecondsSinceEpoch.toDouble();

    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var data in _sensorData) {
      if (_selectedSensors.contains('temperaturedht22')) {
        minY = minY > data.temperatureDHT22 ? data.temperatureDHT22 : minY;
        maxY = maxY < data.temperatureDHT22 ? data.temperatureDHT22 : maxY;
      }
      if (_selectedSensors.contains('temperaturemlx90614')) {
        minY = minY > data.temperatureMLX90614 ? data.temperatureMLX90614 : minY;
        maxY = maxY < data.temperatureMLX90614 ? data.temperatureMLX90614 : maxY;
      }
      if (_selectedSensors.contains('humidity')) {
        minY = minY > data.humidity ? data.humidity : minY;
        maxY = maxY < data.humidity ? data.humidity : maxY;
      }
      if (_selectedSensors.contains('carbonmonoxide')) {
        minY = minY > data.carbonMonoxide ? data.carbonMonoxide : minY;
        maxY = maxY < data.carbonMonoxide ? data.carbonMonoxide : maxY;
      }
      if (_selectedSensors.contains('indoorairquality')) {
        minY = minY > data.indoorAirQuality ? data.indoorAirQuality : minY;
        maxY = maxY < data.indoorAirQuality ? data.indoorAirQuality : maxY;
      }
      if (_selectedSensors.contains('smokelevel')) {
        minY = minY > data.smokeLevel ? data.smokeLevel : minY;
        maxY = maxY < data.smokeLevel ? data.smokeLevel : maxY;
      }
    }

    final padding = (maxY - minY) * 0.1;
    minY = minY - padding;
    maxY = maxY + padding;

    if (minY < 0 && maxY > 0) {
      minY = 0;
    }

    double range = maxY - minY;
    double interval = (range / 5).ceilToDouble();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (_showLegend)
            Container(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildLegend(),
            ),
          Expanded(
            child: LineChart(
              LineChartData(
                backgroundColor: Colors.white,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  drawHorizontalLine: true,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.5),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        return Text(value.toInt().toString());
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                        switch (_selectedTimeRange) {
                          case 'Current':
                            if (date.second == 0) {
                              return Text('${date.hour}:${date.minute.toString().padLeft(2, '0')}');
                            }
                            break;
                          case '10 minutes':
                            if (date.second == 0) {
                              return Text('${date.hour}:${date.minute.toString().padLeft(2, '0')}');
                            }
                            break;
                          case '1 hour':
                            if (date.minute % 10 == 0) {
                              return Text('${date.hour}:${date.minute.toString().padLeft(2, '0')}');
                            }
                            break;
                          case '8 hours':
                            if (date.hour % 2 == 0) {
                              return Text('${date.hour}:00');
                            }
                            break;
                          case '1 day':
                            if (date.hour % 4 == 0) {
                              return Text('${date.hour}:00');
                            }
                            break;
                          case '1 week':
                            if (date.weekday == 1 && date.hour == 0) {
                              return Text('Mon ${date.day}');
                            }
                            break;
                          case '1 month':
                            if (date.day == 1 && date.hour == 0) {
                              return Text('${date.month}/${date.day}');
                            }
                            break;
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                lineBarsData: _getLineBarsData(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<LineChartBarData> _getLineBarsData() {
    final sensorColorMap = {
      'temperaturedht22': Colors.blue,
      'temperaturemlx90614': Colors.red,
      'humidity': Colors.green,
      'carbonmonoxide': Colors.orange,
      'indoorairquality': Colors.purple,
      'smokelevel': Colors.brown,
    };

    List<LineChartBarData> lines = [];

    if (_selectedSensors.contains('temperaturedht22')) {
      lines.add(LineChartBarData(
        spots: _sensorData.map((data) {
          return FlSpot(
            data.timestamp.millisecondsSinceEpoch.toDouble(),
            data.temperatureDHT22,
          );
        }).toList(),
        isCurved: true,
        color: sensorColorMap['temperaturedht22'],
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    if (_selectedSensors.contains('temperaturemlx90614')) {
      lines.add(LineChartBarData(
        spots: _sensorData.map((data) {
          return FlSpot(
            data.timestamp.millisecondsSinceEpoch.toDouble(),
            data.temperatureMLX90614,
          );
        }).toList(),
        isCurved: true,
        color: sensorColorMap['temperaturemlx90614'],
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    if (_selectedSensors.contains('humidity')) {
      lines.add(LineChartBarData(
        spots: _sensorData.map((data) {
          return FlSpot(
            data.timestamp.millisecondsSinceEpoch.toDouble(),
            data.humidity,
          );
        }).toList(),
        isCurved: true,
        color: sensorColorMap['humidity'],
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    if (_selectedSensors.contains('carbonmonoxide')) {
      lines.add(LineChartBarData(
        spots: _sensorData.map((data) {
          return FlSpot(
            data.timestamp.millisecondsSinceEpoch.toDouble(),
            data.carbonMonoxide,
          );
        }).toList(),
        isCurved: true,
        color: sensorColorMap['carbonmonoxide'],
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    if (_selectedSensors.contains('indoorairquality')) {
      lines.add(LineChartBarData(
        spots: _sensorData.map((data) {
          return FlSpot(
            data.timestamp.millisecondsSinceEpoch.toDouble(),
            data.indoorAirQuality,
          );
        }).toList(),
        isCurved: true,
        color: sensorColorMap['indoorairquality'],
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    if (_selectedSensors.contains('smokelevel')) {
      lines.add(LineChartBarData(
        spots: _sensorData.map((data) {
          return FlSpot(
            data.timestamp.millisecondsSinceEpoch.toDouble(),
            data.smokeLevel,
          );
        }).toList(),
        isCurved: true,
        color: sensorColorMap['smokelevel'],
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    return lines;
  }

  Widget _buildLegend() {
    final sensorColorMap = {
      'temperaturedht22': Colors.blue,
      'temperaturemlx90614': Colors.red,
      'humidity': Colors.green,
      'carbonmonoxide': Colors.orange,
      'indoorairquality': Colors.purple,
      'smokelevel': Colors.brown,
    };

    final sensorLabelMap = {
      'temperaturedht22': 'Temp1',
      'temperaturemlx90614': 'Temp2',
      'humidity': 'Humidity',
      'indoorairquality': 'IAQ',
      'carbonmonoxide': 'CO',
      'smokelevel': 'Smoke',
    };

    final List<Widget> legendItems = [];

    _selectedSensors.forEach((sensorKey) {
      if (sensorColorMap.containsKey(sensorKey)) {
        legendItems.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sensorColorMap[sensorKey],
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  sensorLabelMap[sensorKey] ?? sensorKey,
                  style: TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        );
      }
    });

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: legendItems,
    );
  }
}

class SensorData {
  final DateTime timestamp;
  final double carbonMonoxide;
  final double humidity;
  final double indoorAirQuality;
  final double smokeLevel;
  final double temperatureDHT22;
  final double temperatureMLX90614;

  SensorData({
    required this.timestamp,
    required this.carbonMonoxide,
    required this.humidity,
    required this.indoorAirQuality,
    required this.smokeLevel,
    required this.temperatureDHT22,
    required this.temperatureMLX90614,
  });
}

class Device {
  final String productCode;
  final String name;

  Device({required this.productCode, required this.name});
}