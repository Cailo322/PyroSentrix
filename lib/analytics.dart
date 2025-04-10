import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'custom_app_bar.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
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
  Map<String, String> _deviceNames = {};
  bool _isLoading = true;
  String _correlationX = 'temperaturedht22';
  String _correlationY = 'humidity';
  int _currentPage = 0;

  final List<String> _timeRanges = [
    'Current',
    '10 minutes',
    '1 hour',
    '8 hours',
    '1 day',
    '1 week',
    '1 month',
  ];

  final List<String> _allSensors = [
    'temperaturedht22',
    'temperaturemlx90614',
    'humidity',
    'carbonmonoxide',
    'indoorairquality',
    'smokelevel',
  ];

  final Map<String, String> _sensorLabels = {
    'temperaturedht22': 'Temp (DHT22)',
    'temperaturemlx90614': 'Temp (MLX)',
    'humidity': 'Humidity',
    'carbonmonoxide': 'CO',
    'indoorairquality': 'AQI',
    'smokelevel': 'Smoke',
  };

  final Map<String, IconData> _sensorIcons = {
    'temperaturedht22': Icons.thermostat,
    'temperaturemlx90614': Icons.thermostat,
    'humidity': Icons.water_drop,
    'carbonmonoxide': Icons.co2,
    'indoorairquality': Icons.air,
    'smokelevel': Icons.smoke_free,
  };

  @override
  void initState() {
    super.initState();
    _loadDeviceNames().then((_) => _fetchDevices());
  }

  @override
  void dispose() {
    _sensorDataSubscription?.cancel();
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
          name: _deviceNames[productCode] ?? 'Device $productCode',
        );
      }
      for (var doc in sharedSnapshot.docs) {
        final productCode = doc['product_code'];
        if (!uniqueDevices.containsKey(productCode)) {
          uniqueDevices[productCode] = Device(
            productCode: productCode,
            name: _deviceNames[productCode] ?? 'Device $productCode',
          );
        }
      }

      setState(() {
        _devices = uniqueDevices.values.toList();
        if (_devices.isNotEmpty) {
          _selectedProductCode = _devices.first.productCode;
          _startSensorDataListener();
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching devices: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch devices: $e')),
      );
    }
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
                        'Analytics',
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
                carbonMonoxide: (data['carbon_monoxide'] as num).toDouble(),
                humidity: (data['humidity_dht22'] as num).toDouble(),
                indoorAirQuality: (data['indoor_air_quality'] as num).toDouble(),
                smokeLevel: (data['smoke_level'] as num).toDouble(),
                temperatureDHT22: (data['temperature_dht22'] as num).toDouble(),
                temperatureMLX90614: (data['temperature_mlx90614'] as num).toDouble(),
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
                carbonMonoxide: (data['carbon_monoxide'] as num).toDouble(),
                humidity: (data['humidity_dht22'] as num).toDouble(),
                indoorAirQuality: (data['indoor_air_quality'] as num).toDouble(),
                smokeLevel: (data['smoke_level'] as num).toDouble(),
                temperatureDHT22: (data['temperature_dht22'] as num).toDouble(),
                temperatureMLX90614: (data['temperature_mlx90614'] as num).toDouble(),
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

  Widget _buildInsightsSection() {
    if (_sensorData.isEmpty) return Container();

    // Calculate statistics for each sensor
    final stats = <String, Map<String, dynamic>>{};

    if (_selectedSensors.contains('temperaturedht22')) {
      final values = _sensorData.map((d) => d.temperatureDHT22).toList();
      stats['temperaturedht22'] = _calculateStats(values, '°C');
    }

    if (_selectedSensors.contains('temperaturemlx90614')) {
      final values = _sensorData.map((d) => d.temperatureMLX90614).toList();
      stats['temperaturemlx90614'] = _calculateStats(values, '°C');
    }

    if (_selectedSensors.contains('humidity')) {
      final values = _sensorData.map((d) => d.humidity).toList();
      stats['humidity'] = _calculateStats(values, '%');
    }

    if (_selectedSensors.contains('carbonmonoxide')) {
      final values = _sensorData.map((d) => d.carbonMonoxide).toList();
      stats['carbonmonoxide'] = _calculateStats(values, 'ppm');
    }

    if (_selectedSensors.contains('indoorairquality')) {
      final values = _sensorData.map((d) => d.indoorAirQuality).toList();
      stats['indoorairquality'] = _calculateStats(values, 'AQI');
    }

    if (_selectedSensors.contains('smokelevel')) {
      final values = _sensorData.map((d) => d.smokeLevel).toList();
      stats['smokelevel'] = _calculateStats(values, 'SL');
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.black),
              SizedBox(width: 8),
              Text(
                'Detailed Statistics',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ...stats.entries.map((e) => _buildStatRow(e.key, e.value)).toList(),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateStats(List<double> values, String unit) {
    if (values.isEmpty) return {};

    values.sort();
    final sum = values.reduce((a, b) => a + b);
    final avg = sum / values.length;
    final min = values.first;
    final max = values.last;

    // Calculate standard deviation
    final squaredDiffs = values.map((v) => pow(v - avg, 2)).toList();
    final variance = squaredDiffs.reduce((a, b) => a + b) / values.length;
    final stdDev = sqrt(variance as num).toDouble();

    // Calculate percentiles
    final median = _percentile(values, 0.5);
    final p25 = _percentile(values, 0.25);
    final p75 = _percentile(values, 0.75);

    return {
      'unit': unit,
      'avg': avg.toStringAsFixed(2),
      'min': min.toStringAsFixed(2),
      'max': max.toStringAsFixed(2),
      'stdDev': stdDev.toStringAsFixed(2),
      'median': median.toStringAsFixed(2),
      'p25': p25.toStringAsFixed(2),
      'p75': p75.toStringAsFixed(2),
    };
  }

  double _percentile(List<double> sortedValues, double percentile) {
    final index = percentile * (sortedValues.length - 1);
    final lower = sortedValues[index.floor()];
    final upper = sortedValues[index.ceil()];
    return lower + (upper - lower) * (index - index.floor());
  }

  Widget _buildStatRow(String sensor, Map<String, dynamic> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_sensorIcons[sensor], size: 20),
            SizedBox(width: 8),
            Text(
              '${_sensorLabels[sensor] ?? sensor}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          'Average: ${stats['avg']}${stats['unit']} (Min: ${stats['min']}, Max: ${stats['max']})',
          style: TextStyle(fontSize: 12),
        ),
        Text(
          'Typical Range: ${stats['p25']}${stats['unit']} to ${stats['p75']}${stats['unit']}',
          style: TextStyle(fontSize: 12),
        ),
        Divider(height: 16, thickness: 1),
      ],
    );
  }

  Widget _buildThresholdIndicators() {
    final thresholds = {
      'temperaturedht22': {
        'safe': {'min': 20, 'max': 33},
        'caution': {'min': 42.75, 'max': 56},
        'critical': {'min': 57, 'max': double.infinity},
        'unit': '°C'
      },
      'temperaturemlx90614': {
        'safe': {'min': 20, 'max': 33},
        'caution': {'min': 42.75, 'max': 56},
        'critical': {'min': 57, 'max': double.infinity},
        'unit': '°C'
      },
      'humidity': {
        'safe': {'min': 40, 'max': 65},
        'caution': {'min': 29, 'max': 32.5},
        'critical': {'min': 0, 'max': 30},
        'unit': '%'
      },
      'carbonmonoxide': {
        'safe': {'min': 0, 'max': 8.7},
        'caution': {'min': 11.2, 'max': 14},
        'critical': {'min': 15, 'max': double.infinity},
        'unit': 'ppm'
      },
      'indoorairquality': {
        'safe': {'min': 1, 'max': 250},
        'caution': {'min': 262.5, 'max': 349},
        'critical': {'min': 350, 'max': double.infinity},
        'unit': 'AQI'
      },
      'smokelevel': {
        'safe': {'min': 0, 'max': 50},
        'caution': {'min': 68.25, 'max': 90},
        'critical': {'min': 90, 'max': double.infinity},
        'unit': 'SL'
      },
    };

    List<Widget> indicators = [];

    for (final sensor in _selectedSensors) {
      if (!thresholds.containsKey(sensor)) continue;

      final values = _getSensorValues(sensor);
      if (values.isEmpty) continue;

      final current = values.last;
      final config = thresholds[sensor]!;
      final unit = config['unit'] as String;

      String status = '';
      Color statusColor = Colors.green;

      // Properly cast nested maps to the correct type
      final criticalConfig = config['critical'] as Map<String, dynamic>?;
      final cautionConfig = config['caution'] as Map<String, dynamic>?;
      final safeConfig = config['safe'] as Map<String, dynamic>?;

      if (criticalConfig != null &&
          current >= (criticalConfig['min'] as num).toDouble() &&
          current <= (criticalConfig['max'] as num).toDouble()) {
        status = 'Critical';
        statusColor = Colors.red;
      } else if (cautionConfig != null &&
          current >= (cautionConfig['min'] as num).toDouble() &&
          current <= (cautionConfig['max'] as num).toDouble()) {
        status = 'Caution';
        statusColor = Colors.orange;
      } else if (safeConfig != null &&
          current >= (safeConfig['min'] as num).toDouble() &&
          current <= (safeConfig['max'] as num).toDouble()) {
        status = 'Safe';
        statusColor = Colors.green;
      }

      if (status.isNotEmpty) {
        indicators.add(
          Container(
            padding: EdgeInsets.all(8),
            margin: EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor),
            ),
            child: Row(
              children: [
                Icon(_sensorIcons[sensor], color: statusColor),
                SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_sensorLabels[sensor] ?? sensor}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      '$status: ${current.toStringAsFixed(1)}$unit',
                      style: TextStyle(color: statusColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    }

    return Container();
  }

  List<double> _getSensorValues(String sensor) {
    switch (sensor) {
      case 'temperaturedht22':
        return _sensorData.map((d) => d.temperatureDHT22).toList();
      case 'temperaturemlx90614':
        return _sensorData.map((d) => d.temperatureMLX90614).toList();
      case 'humidity':
        return _sensorData.map((d) => d.humidity).toList();
      case 'carbonmonoxide':
        return _sensorData.map((d) => d.carbonMonoxide).toList();
      case 'indoorairquality':
        return _sensorData.map((d) => d.indoorAirQuality).toList();
      case 'smokelevel':
        return _sensorData.map((d) => d.smokeLevel).toList();
      default:
        return [];
    }
  }

  List<FlSpot> _calculateTrendLine(List<FlSpot> spots) {
    if (spots.isEmpty) return [];

    // Simple linear regression to calculate trend line
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    final n = spots.length;

    for (final spot in spots) {
      sumX += spot.x;
      sumY += spot.y;
      sumXY += spot.x * spot.y;
      sumX2 += spot.x * spot.x;
    }

    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    final firstX = spots.first.x;
    final lastX = spots.last.x;

    return [
      FlSpot(firstX, slope * firstX + intercept),
      FlSpot(lastX, slope * lastX + intercept),
    ];
  }

  double _calculateInterval(double min, double max) {
    final range = max - min;
    if (range <= 0) return 1;

    // Calculate a nice interval based on the range
    final step = range / 5;
    final double magnitude = pow(10, (log(step) / ln10).floor()).toDouble();
    final residual = step / magnitude;

    double interval;
    if (residual > 5) {
      interval = 10 * magnitude;
    } else if (residual > 2) {
      interval = 5 * magnitude;
    } else if (residual > 1) {
      interval = 2 * magnitude;
    } else {
      interval = magnitude;
    }

    return interval;
  }

  Widget _buildCorrelationMatrix() {
    if (_sensorData.isEmpty) {
      return Center(
        child: Text(
          'No data available for correlation analysis.',
          style: TextStyle(fontSize: 12),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.scatter_plot, color: Colors.black),
              SizedBox(width: 8),
              Text(
                'Sensor Correlation Analysis',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              DropdownButton<String>(
                value: _correlationX,
                items: _allSensors.map((sensor) {
                  return DropdownMenuItem<String>(
                    value: sensor,
                    child: Text(_sensorLabels[sensor] ?? sensor),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _correlationX = value!;
                  });
                },
              ),
              Text('vs'),
              DropdownButton<String>(
                value: _correlationY,
                items: _allSensors.map((sensor) {
                  return DropdownMenuItem<String>(
                    value: sensor,
                    child: Text(_sensorLabels[sensor] ?? sensor),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _correlationY = value!;
                  });
                },
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            height: 250, // Increased height to prevent overflow
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: _buildScatterPlotForCorrelation(),
          ),
        ],
      ),
    );
  }

  double _calculateCorrelationCoefficient() {
    final xValues = _getSensorValues(_correlationX);
    final yValues = _getSensorValues(_correlationY);

    if (xValues.isEmpty || yValues.isEmpty || xValues.length != yValues.length) {
      return 0.0;
    }

    final n = xValues.length;
    double sumX = 0.0, sumY = 0.0, sumXY = 0.0;
    double sumX2 = 0.0, sumY2 = 0.0;

    for (int i = 0; i < n; i++) {
      sumX += xValues[i];
      sumY += yValues[i];
      sumXY += xValues[i] * yValues[i];
      sumX2 += xValues[i] * xValues[i];
      sumY2 += yValues[i] * yValues[i];
    }

    final numerator = sumXY - (sumX * sumY) / n;
    final denominator = sqrt((sumX2 - (sumX * sumX) / n) * (sumY2 - (sumY * sumY) / n));

    return denominator == 0 ? 0.0 : numerator / denominator;
  }

  Widget _buildScatterPlotForCorrelation() {
    final xValues = _getSensorValues(_correlationX);
    final yValues = _getSensorValues(_correlationY);

    if (xValues.isEmpty || yValues.isEmpty) {
      return Center(
        child: Text(
          'No data available for selected sensors.',
          style: TextStyle(fontSize: 12),
        ),
      );
    }

    final minX = xValues.reduce(min);
    final maxX = xValues.reduce(max);
    final minY = yValues.reduce(min);
    final maxY = yValues.reduce(max);

    final List<FlSpot> spots = [];
    for (int i = 0; i < xValues.length && i < yValues.length; i++) {
      spots.add(FlSpot(xValues[i], yValues[i]));
    }

    final trendLine = _calculateTrendLine(spots);

    return ScatterChart(
      ScatterChartData(
        scatterSpots: spots.map((spot) => ScatterSpot(spot.x, spot.y)).toList(),
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
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
            axisNameWidget: Text(
              _sensorLabels[_correlationY] ?? _correlationY,
              style: TextStyle(fontSize: 12),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: _calculateInterval(minY, maxY),
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: Text(
              _sensorLabels[_correlationX] ?? _correlationX,
              style: TextStyle(fontSize: 12),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: _calculateInterval(minX, maxX),
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(fontSize: 10),
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
                '${_sensorLabels[_correlationX]}: ${spot.x.toStringAsFixed(2)}\n'
                    '${_sensorLabels[_correlationY]}: ${spot.y.toStringAsFixed(2)}',
                textStyle: TextStyle(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }


  Widget _buildCurrentReadings() {
    if (_sensorData.isEmpty) {
      return Center(
        child: Text(
          'No data available for current readings.',
          style: TextStyle(fontSize: 12),
        ),
      );
    }

    final lastData = _sensorData.last;

    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sensors, color: Colors.black),
              SizedBox(width: 8),
              Text(
                'Current Sensor Readings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSingleGauge('Temperature 1 (DHT22)', lastData.temperatureDHT22, '°C', 0, 100),
                  _buildSingleGauge('Temperature 2 (MLX90614)', lastData.temperatureMLX90614, '°C', 0, 100),
                  _buildSingleGauge('Humidity', lastData.humidity, '%', 0, 100),
                ],
              ),
              SizedBox(height: 12), // Slightly more space between gauge rows
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSingleGauge('Carbon Monoxide', lastData.carbonMonoxide, 'ppm', 0, 30),
                  _buildSingleGauge('Air Quality (AQI)', lastData.indoorAirQuality, 'AQI', 0, 500),
                  _buildSingleGauge('Smoke', lastData.smokeLevel, 'µg/m³', 0, 200),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleGauge(String title, double value, String unit, double min, double max) {
    // Compact gauge group with minimal spacing between title and gauge
    return Container(
      width: 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title above the gauge with minimal spacing
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 2), // Minimal spacing between title and gauge
          // Gauge with no title (we're using our own title above)
          SizedBox(
            height: 90, // Fixed height for the gauge
            child: SfRadialGauge(
              axes: <RadialAxis>[
                RadialAxis(
                  minimum: min,
                  maximum: max,
                  startAngle: 130,
                  endAngle: 50,
                  radiusFactor: 0.9, // Make gauge slightly smaller
                  ranges: <GaugeRange>[
                    GaugeRange(startValue: min, endValue: max * 0.6, color: Colors.green[300]),
                    GaugeRange(startValue: max * 0.6, endValue: max * 0.8, color: Colors.yellow[400]),
                    GaugeRange(startValue: max * 0.8, endValue: max, color: Colors.orange[400]),
                  ],
                  pointers: <GaugePointer>[
                    NeedlePointer(
                      value: value,
                      needleLength: 0.6, // Shorter needle
                      needleStartWidth: 1, // Thinner at the base
                      needleEndWidth: 3, // Slightly wider at the tip but still narrow
                      knobStyle: KnobStyle(
                        knobRadius: 4, // Smaller knob
                        sizeUnit: GaugeSizeUnit.logicalPixel,
                      ),
                    ),
                  ],
                  annotations: <GaugeAnnotation>[
                    GaugeAnnotation(
                      widget: Text(
                        '${value.toStringAsFixed(1)}$unit',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      angle: 90,
                      positionFactor: 0.5,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      endDrawer: CustomDrawer(),
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _devices.isEmpty
          ? _buildNoDeviceUI()
          : Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                _buildThresholdIndicators(),
                SizedBox(height: 16),
                Container(
                  height: MediaQuery.of(context).size.height * 0.5,
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9D9D9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.show_chart, color: Colors.black),
                              SizedBox(width: 8),
                              Text(
                                'SENSOR ANALYTICS REPORTS',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          _buildSensorChecklistDropdown(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _sensorData.isEmpty || _selectedSensors.isEmpty
                            ? Center(
                          child: Text(
                            _selectedSensors.isEmpty
                                ? 'No sensors selected'
                                : 'Loading data...',
                            style: TextStyle(fontSize: 12),
                          ),
                        )
                            : _buildChart(),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                _buildCurrentReadings(),
                SizedBox(height: 16),
                _buildCorrelationMatrix(),
                SizedBox(height: 16),
                _buildInsightsSection(),
                SizedBox(height: 100),
              ],
            ),
          ),
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
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                        style: TextStyle(fontSize: 12),
                      ),
                      isExpanded: true,
                      underline: Container(),
                      items: _timeRanges.map((range) {
                        return DropdownMenuItem<String>(
                          value: range,
                          child: Text(
                            range,
                            style: TextStyle(fontSize: 12),
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
                        style: TextStyle(fontSize: 12),
                      ),
                      isExpanded: true,
                      underline: Container(),
                      items: _devices.map((device) {
                        return DropdownMenuItem<String>(
                          value: device.productCode,
                          child: Text(
                            device.name,
                            style: TextStyle(fontSize: 12),
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

  Widget _buildSensorChecklistDropdown() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.filter_list),
      itemBuilder: (context) {
        return _allSensors.map((sensorKey) {
          final displayName = _sensorLabels[sensorKey] ?? sensorKey;

          return PopupMenuItem<String>(
            child: StatefulBuilder(
              builder: (context, setState) {
                return CheckboxListTile(
                  title: Text(
                    displayName,
                    style: TextStyle(fontSize: 12),
                  ),
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

    // Handle case where all values are 0 (like for smoke and CO)
    if (minY == maxY) {
      if (minY == 0) {
        minY = -1;
        maxY = 1;
      } else {
        minY = minY - 1;
        maxY = maxY + 1;
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
                    axisNameWidget: Text(
                      'Sensor Values',
                      style: TextStyle(fontSize: 12),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: interval,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        String unit = '';
                        if (_selectedSensors.length == 1) {
                          if (_selectedSensors.contains('temperaturedht22') ||
                              _selectedSensors.contains('temperaturemlx90614')) {
                            unit = '°C';
                          } else if (_selectedSensors.contains('humidity')) {
                            unit = '%';
                          } else if (_selectedSensors.contains('carbonmonoxide')) {
                            unit = 'ppm';
                          }
                        }

                        return Text(
                          '${value.toInt()}$unit',
                          style: TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: Text(
                      'Time',
                      style: TextStyle(fontSize: 12),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                        switch (_selectedTimeRange) {
                          case 'Current':
                            if (date.second == 0) {
                              return Text(
                                '${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 10),
                              );
                            }
                            break;
                          case '10 minutes':
                            if (date.second == 0) {
                              return Text(
                                '${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 10),
                              );
                            }
                            break;
                          case '1 hour':
                            if (date.minute % 10 == 0) {
                              return Text(
                                '${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 10),
                              );
                            }
                            break;
                          case '8 hours':
                            if (date.hour % 2 == 0) {
                              return Text(
                                '${date.hour}:00',
                                style: TextStyle(fontSize: 10),
                              );
                            }
                            break;
                          case '1 day':
                            if (date.hour % 4 == 0) {
                              return Text(
                                '${date.hour}:00',
                                style: TextStyle(fontSize: 10),
                              );
                            }
                            break;
                          case '1 week':
                            if (date.weekday == 1 && date.hour == 0) {
                              return Text(
                                'Mon ${date.day}',
                                style: TextStyle(fontSize: 10),
                              );
                            }
                            break;
                          case '1 month':
                            if (date.day == 1 && date.hour == 0) {
                              return Text(
                                '${date.month}/${date.day}',
                                style: TextStyle(fontSize: 10),
                              );
                            }
                            break;
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
    final maxGapDuration = Duration(hours: 1); // Define maximum allowed gap duration

    if (_selectedSensors.contains('temperaturedht22')) {
      List<FlSpot> spots = [];
      for (int i = 0; i < _sensorData.length; i++) {
        final data = _sensorData[i];
        // Check if time gap with previous point is too large
        if (i > 0 &&
            (data.timestamp.difference(_sensorData[i-1].timestamp) > maxGapDuration)) {
          // Add null spot to create a gap in the line
          spots.add(FlSpot.nullSpot);
        }
        spots.add(FlSpot(
          data.timestamp.millisecondsSinceEpoch.toDouble(),
          data.temperatureDHT22,
        ));
      }
      lines.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        color: sensorColorMap['temperaturedht22'],
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    if (_selectedSensors.contains('temperaturemlx90614')) {
      List<FlSpot> spots = [];
      for (int i = 0; i < _sensorData.length; i++) {
        final data = _sensorData[i];
        if (i > 0 &&
            (data.timestamp.difference(_sensorData[i-1].timestamp) > maxGapDuration)) {
          spots.add(FlSpot.nullSpot);
        }
        spots.add(FlSpot(
          data.timestamp.millisecondsSinceEpoch.toDouble(),
          data.temperatureMLX90614,
        ));
      }
      lines.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        color: sensorColorMap['temperaturemlx90614'],
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    if (_selectedSensors.contains('humidity')) {
      List<FlSpot> spots = [];
      for (int i = 0; i < _sensorData.length; i++) {
        final data = _sensorData[i];
        if (i > 0 &&
            (data.timestamp.difference(_sensorData[i-1].timestamp) > maxGapDuration)) {
          spots.add(FlSpot.nullSpot);
        }
        spots.add(FlSpot(
          data.timestamp.millisecondsSinceEpoch.toDouble(),
          data.humidity,
        ));
      }
      lines.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        color: sensorColorMap['humidity'],
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    if (_selectedSensors.contains('carbonmonoxide')) {
      List<FlSpot> spots = [];
      for (int i = 0; i < _sensorData.length; i++) {
        final data = _sensorData[i];
        if (i > 0 &&
            (data.timestamp.difference(_sensorData[i-1].timestamp) > maxGapDuration)) {
          spots.add(FlSpot.nullSpot);
        }
        spots.add(FlSpot(
          data.timestamp.millisecondsSinceEpoch.toDouble(),
          data.carbonMonoxide,
        ));
      }
      lines.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        color: sensorColorMap['carbonmonoxide'],
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    if (_selectedSensors.contains('indoorairquality')) {
      List<FlSpot> spots = [];
      for (int i = 0; i < _sensorData.length; i++) {
        final data = _sensorData[i];
        if (i > 0 &&
            (data.timestamp.difference(_sensorData[i-1].timestamp) > maxGapDuration)) {
          spots.add(FlSpot.nullSpot);
        }
        spots.add(FlSpot(
          data.timestamp.millisecondsSinceEpoch.toDouble(),
          data.indoorAirQuality,
        ));
      }
      lines.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        color: sensorColorMap['indoorairquality'],
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    if (_selectedSensors.contains('smokelevel')) {
      List<FlSpot> spots = [];
      for (int i = 0; i < _sensorData.length; i++) {
        final data = _sensorData[i];
        if (i > 0 &&
            (data.timestamp.difference(_sensorData[i-1].timestamp) > maxGapDuration)) {
          spots.add(FlSpot.nullSpot);
        }
        spots.add(FlSpot(
          data.timestamp.millisecondsSinceEpoch.toDouble(),
          data.smokeLevel,
        ));
      }
      lines.add(LineChartBarData(
        spots: spots,
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
                  _sensorLabels[sensorKey] ?? sensorKey,
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