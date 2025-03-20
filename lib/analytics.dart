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
                carbonMonoxide: data['carbon_monoxide'],
                humidity: data['humidity_dht22'],
                indoorAirQuality: data['indoor_air_quality'],
                smokeLevel: data['smoke_level'],
                temperatureDHT22: data['temperature_dht22'],
                temperatureMLX90614: data['temperature_mlx90614'],
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
                carbonMonoxide: data['carbon_monoxide'],
                humidity: data['humidity_dht22'],
                indoorAirQuality: data['indoor_air_quality'],
                smokeLevel: data['smoke_level'],
                temperatureDHT22: data['temperature_dht22'],
                temperatureMLX90614: data['temperature_mlx90614'],
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

  Widget _buildSensorChecklistDropdown() {
    final sensorMap = {
      'Temperature (DHT22)': 'temperaturedht22',
      'Temperature (MLX90614)': 'temperaturemlx90614',
      'Humidity': 'humidity',
      'Carbon Monoxide': 'carbonmonoxide',
      'Indoor Air Quality': 'indoorairquality',
      'Smoke Level': 'smokelevel',
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
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          _buildSensorChecklistDropdown(),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedProductCode,
                    hint: const Text('Select a device'),
                    items: _devices.map((device) {
                      return DropdownMenuItem<String>(
                        value: device.productCode,
                        child: Text(device.name),
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
                SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedTimeRange,
                    hint: const Text('Select time range'),
                    items: _timeRanges.map((range) {
                      return DropdownMenuItem<String>(
                        value: range,
                        child: Text(range),
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
              ],
            ),
          ),
          Expanded(
            child: _selectedProductCode == null
                ? const Center(child: Text('Please select a device'))
                : _sensorData.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _buildChartWithLegend(),
          ),
        ],
      ),
    );
  }

  Widget _buildChartWithLegend() {
    final minX = _sensorData.last.timestamp.millisecondsSinceEpoch.toDouble();
    final maxX = _sensorData.first.timestamp.millisecondsSinceEpoch.toDouble();

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
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
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                minX: minX,
                maxX: maxX,
                minY: 0,
                maxY: 100,
                lineBarsData: _getLineBarsData(),
              ),
            ),
          ),
        ),
        _buildLegend(),
      ],
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
        dotData: FlDotData(show: _selectedTimeRange == 'Current'),
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
        dotData: FlDotData(show: _selectedTimeRange == 'Current'),
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
        dotData: FlDotData(show: _selectedTimeRange == 'Current'),
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
        dotData: FlDotData(show: _selectedTimeRange == 'Current'),
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
        dotData: FlDotData(show: _selectedTimeRange == 'Current'),
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
        dotData: FlDotData(show: _selectedTimeRange == 'Current'),
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
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sensorColorMap[sensorKey],
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  sensorKey,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }
    });

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
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