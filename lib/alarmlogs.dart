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
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'custom_app_bar.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:flutter/rendering.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:typed_data';

class AlarmLogScreen extends StatefulWidget {
  const AlarmLogScreen({Key? key}) : super(key: key);

  @override
  _AlarmLogScreenState createState() => _AlarmLogScreenState();
}

class _AlarmLogScreenState extends State<AlarmLogScreen> {
  double minX = 0;
  double maxX = 0;
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
  bool _isGeneratingPdf = false;

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

  Future<void> _generatePdfReport(Map<String, dynamic> alarm) async {
    if (_isGeneratingPdf) return;

    setState(() {
      _isGeneratingPdf = true;
    });

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Generating PDF report...'),
          ],
        ),
      ),
    );

    try {
      final pdf = pw.Document();
      final logoImage = await rootBundle.load('assets/official-logo.png');
      final logoImageBytes = logoImage.buffer.asUint8List();

      String formattedTimestamp;
      try {
        DateTime dateTime = DateTime.parse(alarm['timestamp']);
        final DateFormat dateFormatter = DateFormat('MMMM d, yyyy h:mm a');
        formattedTimestamp = dateFormatter.format(dateTime);
      } catch (e) {
        formattedTimestamp = "Invalid timestamp";
      }

      final thresholdDoc = await _firestore.collection('Threshold').doc('Proxy').get();
      final thresholds = thresholdDoc.data() ?? {
        'co_threshold': 15,
        'humidity_threshold': 30,
        'iaq_threshold': 350,
        'smoke_threshold': 91,
        'temp_threshold': 58,
      };

      final currentData = alarm['analyticsData']?['current'] ?? {};
      final historyData = alarm['analyticsData']?['history'] ?? [];
      final timestamp = DateTime.parse(alarm['timestamp']);

      // Capture charts as images with larger size
      Uint8List? lineChartImage;
      Uint8List? tempHumidityChartImage;
      Uint8List? tempCoChartImage;
      Uint8List? tempSmokeChartImage;
      Uint8List? humidityAqiChartImage;

      try {
        final image = await _captureWidgetToImage(
          _buildPdfLineChart(alarm, timestamp, historyData),
          width: 1800,
          height: 600,
        );
        if (image != null) {
          lineChartImage = image;
        }
      } catch (e) {
        print("Error capturing line chart: $e");
      }

      try {
        tempHumidityChartImage = await _captureWidgetToImage(
          _buildPdfCorrelationChart(
            "Temperature vs Humidity",
            currentData['temperaturedht22'],
            currentData['humidity'],
            "Temperature (°C)",
            "Humidity (%)",
            _safeDouble(currentData['temperaturedht22']),
            _safeDouble(currentData['humidity']),
          ),
          width: 1200,
          height: 800,
        );
      } catch (e) {
        print("Error capturing temp-humidity chart: $e");
      }

      try {
        tempCoChartImage = await _captureWidgetToImage(
          _buildPdfCorrelationChart(
            "Temperature vs CO",
            currentData['temperaturedht22'],
            currentData['carbonmonoxide'],
            "Temperature (°C)",
            "CO (ppm)",
            _safeDouble(currentData['temperaturedht22']),
            _safeDouble(currentData['carbonmonoxide']),
          ),
          width: 1000,
          height: 700,
        );
      } catch (e) {
        print("Error capturing temp-CO chart: $e");
      }

      try {
        tempSmokeChartImage = await _captureWidgetToImage(
          _buildPdfCorrelationChart(
            "Temperature vs Smoke",
            currentData['temperaturedht22'],
            currentData['smokelevel'],
            "Temperature (°C)",
            "Smoke (µg/m³)",
            _safeDouble(currentData['temperaturedht22']),
            _safeDouble(currentData['smokelevel']),
          ),
          width: 1000,
          height: 700,
        );
      } catch (e) {
        print("Error capturing temp-smoke chart: $e");
      }

      try {
        humidityAqiChartImage = await _captureWidgetToImage(
          _buildPdfCorrelationChart(
            "Humidity vs Air Quality",
            currentData['humidity'],
            currentData['indoorairquality'],
            "Humidity (%)",
            "Air Quality Index",
            _safeDouble(currentData['humidity']),
            _safeDouble(currentData['indoorairquality']),
          ),
          width: 1000,
          height: 700,
        );
      } catch (e) {
        print("Error capturing humidity-AQI chart: $e");
      }

      // Add helper methods for the Event Analysis content
      String _getPotentialCauses(Map<String, dynamic> alarm, Map<String, dynamic> thresholds) {
        final currentData = alarm['analyticsData']?['current'] ?? {};
        String potentialCauses = "";

        if (currentData['smokelevel'] != null && currentData['smokelevel'] > (thresholds['smoke_threshold'] ?? 91)) {
          potentialCauses += "• Smoke detected suggests possible fire or combustion\n";
        }
        if (currentData['indoorairquality'] != null && currentData['indoorairquality'] > (thresholds['iaq_threshold'] ?? 350)) {
          potentialCauses += "• Poor air quality indicates potential environmental hazards\n";
        }
        if (currentData['carbonmonoxide'] != null && currentData['carbonmonoxide'] > (thresholds['co_threshold'] ?? 15)) {
          potentialCauses += "• Elevated CO levels indicate incomplete combustion\n";
        }
        if (currentData['temperaturedht22'] != null && currentData['temperaturedht22'] > (thresholds['temp_threshold'] ?? 58)) {
          potentialCauses += "• High temperature suggests heat source nearby (DHT22)\n";
        }
        if (currentData['temperaturemlx90614'] != null && currentData['temperaturemlx90614'] > (thresholds['temp_threshold'] ?? 58)) {
          potentialCauses += "• High temperature suggests heat source nearby (MLX90614)\n";
        }
        if (potentialCauses.isEmpty) {
          potentialCauses = "• Possible false alarm or sensor malfunction\n";
        }

        return potentialCauses;
      }

      String _getRecommendedActions(Map<String, dynamic> alarm, Map<String, dynamic> thresholds) {
        final currentData = alarm['analyticsData']?['current'] ?? {};
        String recommendedActions = "";
        bool hasCriticalIssue = false;
        bool hasWarningIssue = false;

        if ((currentData['smokelevel'] != null && currentData['smokelevel'] > (thresholds['smoke_threshold'] ?? 91)) ||
            (currentData['carbonmonoxide'] != null && currentData['carbonmonoxide'] > (thresholds['co_threshold'] ?? 15))) {
          hasCriticalIssue = true;
        }

        if ((currentData['temperaturedht22'] != null && currentData['temperaturedht22'] > (thresholds['temp_threshold'] ?? 58)) ||
            (currentData['temperaturemlx90614'] != null && currentData['temperaturemlx90614'] > (thresholds['temp_threshold'] ?? 58)) ||
            (currentData['indoorairquality'] != null && currentData['indoorairquality'] > (thresholds['iaq_threshold'] ?? 350))) {
          hasWarningIssue = true;
        }

        if (hasCriticalIssue) {
          recommendedActions += "• Evacuate the area immediately\n";
          recommendedActions += "• Contact emergency services\n";
          recommendedActions += "• Check for visible signs of fire or smoke\n";
        } else if (hasWarningIssue) {
          recommendedActions += "• Investigate the area for potential hazards\n";
          recommendedActions += "• Ventilate the area if safe to do so\n";
          recommendedActions += "• Monitor sensor readings closely\n";
        } else {
          recommendedActions += "• Check device placement and ventilation\n";
          recommendedActions += "• Monitor for recurring alarms\n";
          recommendedActions += "• Consider sensor calibration if false alarms persist\n";
        }
        return recommendedActions;
      }

      // Add the first page with alarm details
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 50,
                      height: 50,
                      child: pw.Image(pw.MemoryImage(logoImageBytes)),
                    ),
                    pw.SizedBox(width: 15),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Pyrosentrix Alarm Report',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          alarm['id'] ?? 'Unknown Alarm',
                          style: pw.TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Alarm Details',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Timestamp: $formattedTimestamp',
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Sensor Readings at Time of Alarm',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFD3D3D3), width: 0.5),
                  children: _buildSensorReadingRows(alarm, thresholds),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Threshold Values',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFD3D3D3), width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFD3D3D3)),
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text(
                            'Parameter',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text(
                            'Threshold Value',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text('Max Temperature'),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text('${thresholds['temp_threshold'] ?? 58}°C'),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text('Min Humidity'),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text('${thresholds['humidity_threshold'] ?? 30}%'),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text('Max CO'),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text('${thresholds['co_threshold'] ?? 15}ppm'),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text('Max AQI'),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text('${thresholds['iaq_threshold'] ?? 350}'),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text('Max Smoke'),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text('${thresholds['smoke_threshold'] ?? 91}µg/m³'),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  "Event Analysis",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                // Potential Causes
                pw.Text(
                  "Potential Causes:",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 5),
                pw.Text(_getPotentialCauses(alarm, thresholds)),
                pw.SizedBox(height: 10),
                // Recommended Actions
                pw.Text(
                  "Recommended Actions:",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 5),
                pw.Text(_getRecommendedActions(alarm, thresholds)),
              ],
            );
          },
        ),
      );

      // Add charts page if we have any charts
      if (lineChartImage != null) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.all(20),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Sensor Trends Analysis",
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    "The following chart shows sensor readings before and during the alarm event.",
                    style: pw.TextStyle(fontSize: 14),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Center(
                    child: pw.Container(
                      width: PdfPageFormat.a4.width - 40,
                      height: 500,
                      child: pw.Image(pw.MemoryImage(lineChartImage!)),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  _buildPdfLegend([
                    {'color': PdfColors.blue, 'label': 'Temperature (DHT22)'},
                    {'color': PdfColors.red, 'label': 'Temperature (MLX90614)'},
                    {'color': PdfColors.green, 'label': 'Humidity'},
                    {'color': PdfColors.orange, 'label': 'Carbon Monoxide'},
                    {'color': PdfColors.purple, 'label': 'Air Quality'},
                    {'color': PdfColors.brown, 'label': 'Smoke Level'},
                  ]),
                ],
              );
            },
          ),
        );
      }

      if (tempHumidityChartImage != null || tempCoChartImage != null ||
          tempSmokeChartImage != null || humidityAqiChartImage != null) {
        // In the correlation charts PDF page, update the container sizes:
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.all(20),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Sensor Correlations Analysis",
                    style: pw.TextStyle(
                      fontSize: 18, // Larger title
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    "The following charts show relationships between different sensor readings at the time of the alarm.",
                    style: pw.TextStyle(fontSize: 14), // Larger text
                  ),
                  pw.SizedBox(height: 20),

                  // First row - Temperature vs Humidity and Temperature vs CO
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      if (tempHumidityChartImage != null)
                        pw.Container(
                          width: (PdfPageFormat.a4.width - 40) / 2 ,
                          child: pw.Column(
                            children: [
                              pw.Text("Temperature vs Humidity",
                                  style: pw.TextStyle(fontSize: 14)), // Larger title
                              pw.SizedBox(height: 8),
                              pw.Image(pw.MemoryImage(tempHumidityChartImage!),
                                width: (PdfPageFormat.a4.width - 40) / 2 - 10,
                                height: 250, // Increased from 200
                              ),
                            ],
                          ),
                        ),
                      if (tempCoChartImage != null)
                        pw.Container(
                          width: (PdfPageFormat.a4.width - 40) / 2 - 10,
                          child: pw.Column(
                            children: [
                              pw.Text("Temperature vs CO",
                                  style: pw.TextStyle(fontSize: 14)), // Larger title
                              pw.SizedBox(height: 8),
                              pw.Image(pw.MemoryImage(tempCoChartImage!),
                                width: (PdfPageFormat.a4.width - 40) / 2 - 10,
                                height: 250, // Increased from 200
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 20),

                  // Second row - Temperature vs Smoke and Humidity vs AQI
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      if (tempSmokeChartImage != null)
                        pw.Container(
                          width: (PdfPageFormat.a4.width - 40) / 2 - 10,
                          child: pw.Column(
                            children: [
                              pw.Text("Temperature vs Smoke",
                                  style: pw.TextStyle(fontSize: 14)), // Larger title
                              pw.SizedBox(height: 8),
                              pw.Image(pw.MemoryImage(tempSmokeChartImage!),
                                width: (PdfPageFormat.a4.width - 40) / 2 - 10,
                                height: 250, // Increased from 200
                              ),
                            ],
                          ),
                        ),
                      if (humidityAqiChartImage != null)
                        pw.Container(
                          width: (PdfPageFormat.a4.width - 40) / 2 - 10,
                          child: pw.Column(
                            children: [
                              pw.Text("Humidity vs Air Quality",
                                  style: pw.TextStyle(fontSize: 14)), // Larger title
                              pw.SizedBox(height: 8),
                              pw.Image(pw.MemoryImage(humidityAqiChartImage!),
                                width: (PdfPageFormat.a4.width - 40) / 2 - 10,
                                height: 250, // Increased from 200
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      }

      // Add image page if available
      if (alarm['imageUrl'] != null) {
        try {
          final response = await http.get(Uri.parse(alarm['imageUrl']));
          if (response.statusCode == 200) {
            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                margin: pw.EdgeInsets.all(20),
                build: (pw.Context context) {
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "Image Captured During Alarm",
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        "The following image was captured by the device when the alarm was triggered.",
                        style: pw.TextStyle(fontSize: 12),
                      ),
                      pw.SizedBox(height: 20),
                      pw.Center(
                        child: pw.Container(
                          constraints: pw.BoxConstraints(
                            maxWidth: 500,
                            maxHeight: 500,
                          ),
                          child: pw.Image(
                            pw.MemoryImage(response.bodyBytes),
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          }
        } catch (e) {
          print("Error adding image to PDF: $e");
        }
      }

      // Save PDF to file
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/${alarm['id'].replaceAll(' ', '_')}_report.pdf");
      await file.writeAsBytes(await pdf.save());

      // Close the loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Download the file
      await _downloadFile(file.path, "${alarm['id'].replaceAll(' ', '_')}_report.pdf");
    } catch (e) {
      print("Error generating PDF: $e");
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to generate PDF report")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  pw.Widget _buildPdfLegend(List<Map<String, dynamic>> items) {
    return pw.Wrap(
      children: items.map((item) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(4.0),
          child: pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Container(
                width: 10,
                height: 10,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: item['color'],
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Text(
                item['label'],
                style: pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  List<pw.TableRow> _buildSensorReadingRows(Map<String, dynamic> alarm, Map<String, dynamic> thresholds) {
    final Map<String, Map<String, String>> sensorDetails = {
      'humidity_dht22': {'name': 'Humidity', 'unit': '%'},
      'temperature_dht22': {'name': 'Temperature 1', 'unit': '°C'},
      'temperature_mlx90614': {'name': 'Temperature 2', 'unit': '°C'},
      'smoke_level': {'name': 'Smoke', 'unit': 'µg/m³'},
      'indoor_air_quality': {'name': 'Air Quality', 'unit': 'AQI'},
      'carbon_monoxide': {'name': 'Carbon Monoxide', 'unit': 'ppm'},
    };

    return (alarm['values'] is Map ? (alarm['values'] as Map<String, dynamic>).entries.map<pw.TableRow>((entry) {
      if (entry.key == 'timestamp') return pw.TableRow(children: [pw.SizedBox.shrink(), pw.SizedBox.shrink(), pw.SizedBox.shrink()]);

      var sensorInfo = sensorDetails[entry.key] ?? {'name': entry.key, 'unit': ''};
      String sensorName = sensorInfo['name']!;
      String sensorUnit = sensorInfo['unit']!;
      bool exceedsThreshold = _exceedsThresholdForSensor(entry.key, entry.value, thresholds);

      // Safely parse the value
      double? value;
      try {
        value = double.tryParse(entry.value.toString());
      } catch (e) {
        value = null;
      }

      return pw.TableRow(
        decoration: exceedsThreshold
            ? pw.BoxDecoration(color: PdfColors.red100)
            : null,
        children: [
          pw.Padding(
            padding: pw.EdgeInsets.all(5),
            child: pw.Text(sensorName),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.all(5),
            child: pw.Text(
              value != null ? "${value.toStringAsFixed(1)} $sensorUnit" : "N/A $sensorUnit",
            ),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.all(5),
            child: pw.Text(
              exceedsThreshold ? "CRITICAL" : "Normal",
              style: pw.TextStyle(
                color: exceedsThreshold ? PdfColors.red : PdfColors.green,
                fontWeight: exceedsThreshold ? pw.FontWeight.bold : null,
              ),
            ),
          ),
        ],
      );
    }).toList() : []);
  }

  Future<void> _downloadFile(String filePath, String fileName) async {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      // Check and request storage permission
      if (Platform.isAndroid) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          scaffold.showSnackBar(
            const SnackBar(content: Text('Storage permission required to save reports')),
          );
          return;
        }
      }

      // Get the download directory
      Directory directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download/Pyrosentrix');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final savePath = '${directory.path}/$fileName';
      final savedFile = File(savePath);

      // Copy the file
      await File(filePath).copy(savedFile.path);

      // Open the PDF automatically
      final openResult = await OpenFile.open(savedFile.path);

      if (openResult.type != ResultType.done) {
        scaffold.showSnackBar(
          SnackBar(content: Text('Failed to open PDF: ${openResult.message}')),
        );
      }

    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
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
            'analyticsData': data['analyticsData'] ?? {},
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

            // Get historical data for analytics
            var historyData = await _firestore
                .collection('SensorData')
                .doc('FireAlarm')
                .collection(_selectedProductCode!)
                .where('timestamp', isGreaterThanOrEqualTo:
            DateTime.now().subtract(Duration(hours:1)).toIso8601String())
                .orderBy('timestamp')
                .get();

            var analyticsDataPoints = historyData.docs.map((doc) {
              var data = doc.data();
              return {
                'timestamp': data['timestamp'],
                'temperaturedht22': data['temperature_dht22'],
                'temperaturemlx90614': data['temperature_mlx90614'],
                'humidity': data['humidity_dht22'],
                'carbonmonoxide': data['carbon_monoxide'],
                'indoorairquality': data['indoor_air_quality'],
                'smokelevel': data['smoke_level'],
              };
            }).toList();

            var alarmData = {
              'id': 'Alarm $alarmCount',
              'timestamp': data['timestamp'],
              'values': data,
              'sensorDataDocId': sensorDataDocId,
              'imageUrl': imageUrl,
              'analyticsData': {
                'current': {
                  'temperaturedht22': data['temperature_dht22'],
                  'temperaturemlx90614': data['temperature_mlx90614'],
                  'humidity': data['humidity_dht22'],
                  'carbonmonoxide': data['carbon_monoxide'],
                  'indoorairquality': data['indoor_air_quality'],
                  'smokelevel': data['smoke_level'],
                },
                'history': analyticsDataPoints,
              },
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

  Future<Uint8List?> _captureWidgetToImage(Widget widget, {double width = 600, double height = 400}) async {
    try {
      final controller = ScreenshotController();
      return await controller.captureFromWidget(
        MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            padding: EdgeInsets.zero,
            devicePixelRatio: 3.0,
            textScaleFactor: 1.0,
          ),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Container(
                  width: width,
                  height: height,
                  color: Colors.white,
                  child: widget,
                ),
              ),
            ),
          ),
        ),
        pixelRatio: 3.0,
      );
    } catch (e) {
      print("Error capturing widget: $e");
      return null;
    }
  }

  Widget _buildPdfLineChart(Map<String, dynamic> alarm, DateTime alarmTime, List<dynamic> historyData) {
    final currentData = alarm['analyticsData']?['current'] ?? {};
    final alarmX = alarmTime.millisecondsSinceEpoch.toDouble();

    List<FlSpot> tempDHT22Spots = [];
    List<FlSpot> tempMLXSpots = [];
    List<FlSpot> humiditySpots = [];
    List<FlSpot> coSpots = [];
    List<FlSpot> aqiSpots = [];
    List<FlSpot> smokeSpots = [];

    for (var dataPoint in historyData) {
      final pointTime = DateTime.parse(dataPoint['timestamp']);
      final xValue = pointTime.millisecondsSinceEpoch.toDouble();

      if (dataPoint['temperaturedht22'] != null) {
        tempDHT22Spots.add(FlSpot(xValue, (dataPoint['temperaturedht22'] as num).toDouble()));
      }
      if (dataPoint['temperaturemlx90614'] != null) {
        tempMLXSpots.add(FlSpot(xValue, (dataPoint['temperaturemlx90614'] as num).toDouble()));
      }
      if (dataPoint['humidity'] != null) {
        humiditySpots.add(FlSpot(xValue, (dataPoint['humidity'] as num).toDouble()));
      }
      if (dataPoint['carbonmonoxide'] != null) {
        coSpots.add(FlSpot(xValue, (dataPoint['carbonmonoxide'] as num).toDouble()));
      }
      if (dataPoint['indoorairquality'] != null) {
        aqiSpots.add(FlSpot(xValue, (dataPoint['indoorairquality'] as num).toDouble()));
      }
      if (dataPoint['smokelevel'] != null) {
        smokeSpots.add(FlSpot(xValue, (dataPoint['smokelevel'] as num).toDouble()));
      }
    }

    if (currentData['temperaturedht22'] != null) {
      tempDHT22Spots.add(FlSpot(alarmX, (currentData['temperaturedht22'] as num).toDouble()));
    }
    if (currentData['temperaturemlx90614'] != null) {
      tempMLXSpots.add(FlSpot(alarmX, (currentData['temperaturemlx90614'] as num).toDouble()));
    }
    if (currentData['humidity'] != null) {
      humiditySpots.add(FlSpot(alarmX, (currentData['humidity'] as num).toDouble()));
    }
    if (currentData['carbonmonoxide'] != null) {
      coSpots.add(FlSpot(alarmX, (currentData['carbonmonoxide'] as num).toDouble()));
    }
    if (currentData['indoorairquality'] != null) {
      aqiSpots.add(FlSpot(alarmX, (currentData['indoorairquality'] as num).toDouble()));
    }
    if (currentData['smokelevel'] != null) {
      smokeSpots.add(FlSpot(alarmX, (currentData['smokelevel'] as num).toDouble()));
    }

    minX = alarmTime.subtract(Duration(hours: 1)).millisecondsSinceEpoch.toDouble();
    maxX = alarmTime.add(Duration(hours: 1)).millisecondsSinceEpoch.toDouble();

    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var spot in [...tempDHT22Spots, ...tempMLXSpots, ...humiditySpots, ...coSpots, ...aqiSpots, ...smokeSpots]) {
      if (spot.y < minY) minY = spot.y;
      if (spot.y > maxY) maxY = spot.y;
    }

    minY = minY - (maxY - minY) * 0.1;
    maxY = maxY + (maxY - minY) * 0.1;
    if (minY < 0) minY = 0;

    return SizedBox(
      width: 1000,
      height: 600,
      child: LineChart(
        LineChartData(
          backgroundColor: Colors.white,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            drawHorizontalLine: true,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.3),
              strokeWidth: 1,
            ),
            getDrawingVerticalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.3),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              axisNameWidget: Text('Time', style: TextStyle(fontSize: 16)),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: (maxX - minX) / 3,
                getTitlesWidget: (value, meta) {
                  final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                  return Text(
                    DateFormat('HH:mm').format(date.add(Duration(hours: 4))),
                    style: TextStyle(fontSize: 14),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: Text('Sensor Values', style: TextStyle(fontSize: 16)),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                interval: (maxY - minY) / 4,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1),
                    style: TextStyle(fontSize: 14),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            if (tempDHT22Spots.isNotEmpty)
              LineChartBarData(
                spots: tempDHT22Spots,
                color: Colors.blue,
                barWidth: 3,
                isCurved: true,
                curveSmoothness: 0.5,
                dotData: FlDotData(show: false),
              ),
            if (tempMLXSpots.isNotEmpty)
              LineChartBarData(
                spots: tempMLXSpots,
                color: Colors.red,
                barWidth: 3,
                isCurved: true,
                curveSmoothness: 0.5,
                dotData: FlDotData(show: false),
              ),
            if (humiditySpots.isNotEmpty)
              LineChartBarData(
                spots: humiditySpots,
                color: Colors.green,
                barWidth: 3,
                isCurved: true,
                curveSmoothness: 0.5,
                dotData: FlDotData(show: false),
              ),
            if (coSpots.isNotEmpty)
              LineChartBarData(
                spots: coSpots,
                color: Colors.orange,
                barWidth: 3,
                isCurved: true,
                curveSmoothness: 0.5,
                dotData: FlDotData(show: false),
              ),
            if (aqiSpots.isNotEmpty)
              LineChartBarData(
                spots: aqiSpots,
                color: Colors.purple,
                barWidth: 3,
                isCurved: true,
                curveSmoothness: 0.5,
                dotData: FlDotData(show: false),
              ),
            if (smokeSpots.isNotEmpty)
              LineChartBarData(
                spots: smokeSpots,
                color: Colors.brown,
                barWidth: 3,
                isCurved: true,
                curveSmoothness: 0.5,
                dotData: FlDotData(show: false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfCorrelationChart(
      String title,
      dynamic xValue,
      dynamic yValue,
      String xLabel,
      String yLabel,
      double xValueSafe,
      double yValueSafe,
      ) {
    final x = _safeDouble(xValue) ?? 0;
    final y = _safeDouble(yValue) ?? 0;

    // Calculate dynamic ranges
    double minX = (x * 0.8).clamp(0, double.infinity);
    double maxX = (x * 1.2).clamp(x, double.infinity);
    double minY = (y * 0.8).clamp(0, double.infinity);
    double maxY = (y * 1.2).clamp(y, double.infinity);

    // Ensure visible range
    if ((maxX - minX) < 5) {
      minX = (x - 5).clamp(0, double.infinity);
      maxX = (x + 5).clamp(x, double.infinity);
    }
    if ((maxY - minY) < 10) {
      minY = (y - 10).clamp(0, double.infinity);
      maxY = (y + 10).clamp(y, double.infinity);
    }

    return SizedBox(
      width: 1200, // Fixed size for consistent PDF layout
      height: 700,
      child: Column(
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(12.0),
              child: ScatterChart(
                ScatterChartData(
                  scatterSpots: [ScatterSpot(x, y)],
                  minX: minX,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  borderData: FlBorderData(show: true),
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: true,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withOpacity(0.3),
                      strokeWidth: 1,
                    ),
                    getDrawingVerticalLine: (value) => FlLine(
                      color: Colors.grey.withOpacity(0.3),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: (maxX - minX) / 3,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              value.toStringAsFixed(1),
                              style: TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: Padding(
                        padding: const EdgeInsets.only(right: 16.0), // Increased right padding
                        child: Text(yLabel, style: TextStyle(fontSize: 14)),
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40, // Increased from 32 for more padding
                        interval: (maxY - minY) / 4, // Exactly 5 labels
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 16.0), // Increased from 8.0
                            child: Text(
                              value.toStringAsFixed(1),
                              style: TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

  Widget _buildAnalyticsSnapshot(BuildContext context, Map<String, dynamic> alarm) {
    final currentData = alarm['analyticsData']?['current'] ?? {};
    final historyData = alarm['analyticsData']?['history'] ?? [];
    final timestamp = DateTime.parse(alarm['timestamp']);

    if (currentData.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(thickness: 1, color: Colors.grey),
        SizedBox(height: 10),
        Text(
          "Analytics Snapshot",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 10),
        _buildMiniLineChart(alarm, timestamp, historyData),
        SizedBox(height: 10),
        _buildCompactCorrelationCharts(currentData),
        SizedBox(height: 10),
        _buildSummarySection(alarm),
      ],
    );
  }

  Widget _buildMiniLineChart(Map<String, dynamic> alarm, DateTime alarmTime, List<dynamic> historyData) {
    final currentData = alarm['analyticsData']?['current'] ?? {};
    final alarmX = alarmTime.millisecondsSinceEpoch.toDouble();

    List<FlSpot> tempDHT22Spots = [];
    List<FlSpot> tempMLXSpots = [];
    List<FlSpot> humiditySpots = [];
    List<FlSpot> coSpots = [];
    List<FlSpot> aqiSpots = [];
    List<FlSpot> smokeSpots = [];

    for (var dataPoint in historyData) {
      final pointTime = DateTime.parse(dataPoint['timestamp']);
      final xValue = pointTime.millisecondsSinceEpoch.toDouble();

      if (dataPoint['temperaturedht22'] != null) {
        tempDHT22Spots.add(FlSpot(xValue, (dataPoint['temperaturedht22'] as num).toDouble()));
      }
      if (dataPoint['temperaturemlx90614'] != null) {
        tempMLXSpots.add(FlSpot(xValue, (dataPoint['temperaturemlx90614'] as num).toDouble()));
      }
      if (dataPoint['humidity'] != null) {
        humiditySpots.add(FlSpot(xValue, (dataPoint['humidity'] as num).toDouble()));
      }
      if (dataPoint['carbonmonoxide'] != null) {
        coSpots.add(FlSpot(xValue, (dataPoint['carbonmonoxide'] as num).toDouble()));
      }
      if (dataPoint['indoorairquality'] != null) {
        aqiSpots.add(FlSpot(xValue, (dataPoint['indoorairquality'] as num).toDouble()));
      }
      if (dataPoint['smokelevel'] != null) {
        smokeSpots.add(FlSpot(xValue, (dataPoint['smokelevel'] as num).toDouble()));
      }
    }

    // Add alarm point data
    if (currentData['temperaturedht22'] != null) {
      tempDHT22Spots.add(FlSpot(alarmX, (currentData['temperaturedht22'] as num).toDouble()));
    }
    if (currentData['temperaturemlx90614'] != null) {
      tempMLXSpots.add(FlSpot(alarmX, (currentData['temperaturemlx90614'] as num).toDouble()));
    }
    if (currentData['humidity'] != null) {
      humiditySpots.add(FlSpot(alarmX, (currentData['humidity'] as num).toDouble()));
    }
    if (currentData['carbonmonoxide'] != null) {
      coSpots.add(FlSpot(alarmX, (currentData['carbonmonoxide'] as num).toDouble()));
    }
    if (currentData['indoorairquality'] != null) {
      aqiSpots.add(FlSpot(alarmX, (currentData['indoorairquality'] as num).toDouble()));
    }
    if (currentData['smokelevel'] != null) {
      smokeSpots.add(FlSpot(alarmX, (currentData['smokelevel'] as num).toDouble()));
    }

    minX = alarmTime.subtract(Duration(hours: 1)).millisecondsSinceEpoch.toDouble();
    maxX = alarmTime.add(Duration(hours: 1)).millisecondsSinceEpoch.toDouble();

    // Calculate dynamic Y-axis range based on all sensor values
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var spot in [...tempDHT22Spots, ...tempMLXSpots, ...humiditySpots, ...coSpots, ...aqiSpots, ...smokeSpots]) {
      if (spot.y < minY) minY = spot.y;
      if (spot.y > maxY) maxY = spot.y;
    }

    // Add some padding to the Y-axis range
    minY = minY - (maxY - minY) * 0.1;
    maxY = maxY + (maxY - minY) * 0.1;
    if (minY < 0) minY = 0;

    // Calculate intervals for Y-axis
    double yRange = maxY - minY;
    double yInterval = yRange / 4; // Creates 4 intervals (5 labels total)

    return Container(
      height: 250,
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Text(
            "Sensor Trends Around Alarm Time",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: LineChart(
                LineChartData(
                  backgroundColor: Colors.white,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    drawHorizontalLine: true,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withOpacity(0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      axisNameWidget: Text('Time', style: TextStyle(fontSize: 12)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: (maxX - minX) / 3,
                        getTitlesWidget: (value, meta) {
                          final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                          return Transform.translate(
                            offset: Offset(0, 10),
                            child: Text(
                              DateFormat('HH:mm').format(date.add(Duration(hours: 4))),
                              style: TextStyle(fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: Text('Sensor Values', style: TextStyle(fontSize: 12)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        interval: yInterval,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: _getTitlePadding(value, minY, maxY),
                            child: Text(
                              value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1),
                              style: TextStyle(fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: minX,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    if (tempDHT22Spots.isNotEmpty)
                      LineChartBarData(
                        spots: tempDHT22Spots,
                        color: Colors.blue,
                        barWidth: 2,
                        isCurved: true,
                        curveSmoothness: 0.5, // Increased smoothness
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                    if (tempMLXSpots.isNotEmpty)
                      LineChartBarData(
                        spots: tempMLXSpots,
                        color: Colors.red,
                        barWidth: 2,
                        isCurved: true,
                        curveSmoothness: 0.5, // Increased smoothness
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                    if (humiditySpots.isNotEmpty)
                      LineChartBarData(
                        spots: humiditySpots,
                        color: Colors.green,
                        barWidth: 2,
                        isCurved: true,
                        curveSmoothness: 0.5, // Increased smoothness
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                    if (coSpots.isNotEmpty)
                      LineChartBarData(
                        spots: coSpots,
                        color: Colors.orange,
                        barWidth: 2,
                        isCurved: true,
                        curveSmoothness: 0.5, // Increased smoothness
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                    if (aqiSpots.isNotEmpty)
                      LineChartBarData(
                        spots: aqiSpots,
                        color: Colors.purple,
                        barWidth: 2,
                        isCurved: true,
                        curveSmoothness: 0.5, // Increased smoothness
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                    if (smokeSpots.isNotEmpty)
                      LineChartBarData(
                        spots: smokeSpots,
                        color: Colors.brown,
                        barWidth: 2,
                        isCurved: true,
                        curveSmoothness: 0.5, // Increased smoothness
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 5,
            children: [
              _buildLegendItem(Colors.blue, "Temp (DHT22)"),
              _buildLegendItem(Colors.red, "Temp (MLX)"),
              _buildLegendItem(Colors.green, "Humidity"),
              _buildLegendItem(Colors.orange, "CO"),
              _buildLegendItem(Colors.purple, "AQI"),
              _buildLegendItem(Colors.brown, "Smoke"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCorrelationCharts(Map<String, dynamic> currentData) {
    return Column(
      children: [
        // First row with two charts
        Row(
          children: [
            Expanded(
              child: _buildCompactCorrelationChart(
                "Temp vs Humidity",
                currentData['temperaturedht22'],
                currentData['humidity'],
                "Temp (°C)",
                "Humidity (%)",
                _safeDouble(currentData['temperaturedht22']),
                _safeDouble(currentData['humidity']),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildCompactCorrelationChart(
                "Temp vs CO",
                currentData['temperaturedht22'],
                currentData['carbonmonoxide'],
                "Temp (°C)",
                "CO (ppm)",
                _safeDouble(currentData['temperaturedht22']),
                _safeDouble(currentData['carbonmonoxide']),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        // Second row with two charts
        Row(
          children: [
            Expanded(
              child: _buildCompactCorrelationChart(
                "Temp vs Smoke",
                currentData['temperaturedht22'],
                currentData['smokelevel'],
                "Temp (°C)",
                "Smoke (µg/m³)",
                _safeDouble(currentData['temperaturedht22']),
                _safeDouble(currentData['smokelevel']),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildCompactCorrelationChart(
                "Humidity vs AQI",
                currentData['humidity'],
                currentData['indoorairquality'],
                "Humidity (%)",
                "AQI",
                _safeDouble(currentData['humidity']),
                _safeDouble(currentData['indoorairquality']),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactCorrelationChart(
      String title,
      dynamic xValue,
      dynamic yValue,
      String xLabel,
      String yLabel,
      double xValueSafe,
      double yValueSafe,
      ) {
    // Safely parse the values
    final x = _safeDouble(xValue) ?? 0;
    final y = _safeDouble(yValue) ?? 0;

    // Calculate dynamic ranges with padding
    double minX = (x * 0.8).clamp(0, double.infinity);
    double maxX = (x * 1.2).clamp(x, double.infinity);
    double minY = (y * 0.8).clamp(0, double.infinity);
    double maxY = (y * 1.2).clamp(y, double.infinity);

    // Ensure we have some visible range
    if ((maxX - minX) < 5) {
      minX = (x - 5).clamp(0, double.infinity);
      maxX = (x + 5).clamp(x, double.infinity);
    }
    if ((maxY - minY) < 10) {
      minY = (y - 10).clamp(0, double.infinity);
      maxY = (y + 10).clamp(y, double.infinity);
    }

    return Container(
      height: 180,
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Expanded(
            child: ScatterChart(
              ScatterChartData(
                scatterSpots: [ScatterSpot(x, y)],
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
                    color: Colors.grey.withOpacity(0.3),
                    strokeWidth: 0.5,
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.3),
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: AxisTitles(
                    axisNameWidget: Text(yLabel, style: TextStyle(fontSize: 8)),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (maxY - minY) / 2,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(
                          value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1),
                          style: TextStyle(fontSize: 8),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: Text(xLabel, style: TextStyle(fontSize: 8)),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      interval: (maxX - minX) / 2,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(
                          value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1),
                          style: TextStyle(fontSize: 8),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                scatterTouchData: ScatterTouchData(
                  enabled: true,
                  touchCallback: (FlTouchEvent event, ScatterTouchResponse? touchResponse) {},
                  handleBuiltInTouches: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Widget _buildSummarySection(Map<String, dynamic> alarm) {
    final currentData = alarm['analyticsData']?['current'] ?? {};
    final values = alarm['values'] ?? {};
    final thresholdDoc = _firestore.collection('Threshold').doc('Proxy');

    return FutureBuilder<DocumentSnapshot>(
      future: thresholdDoc.get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }

        final thresholds = snapshot.data!.data() as Map<String, dynamic>? ?? {
          'co_threshold': 50,
          'humidity_threshold': 30,
          'iaq_threshold': 100,
          'smoke_threshold': 10,
          'temp_threshold': 40,
        };

        // Calculate potential causes
        String potentialCauses = "";
        if (currentData['smokelevel'] != null && currentData['smokelevel'] > (thresholds['smoke_threshold'] ?? 91)) {
          potentialCauses += "• Smoke detected suggests possible fire or combustion\n";
        }
        if (currentData['indoorairquality'] != null && currentData['indoorairquality'] > (thresholds['iaq_threshold'] ?? 350)) {
          potentialCauses += "• Smoke detected suggests possible fire or combustion\n";
        }
        if (currentData['carbonmonoxide'] != null && currentData['carbonmonoxide'] > (thresholds['co_threshold'] ?? 15)) {
          potentialCauses += "• Elevated CO levels indicate incomplete combustion\n";
        }
        if (currentData['temperaturedht22'] != null && currentData['temperaturedht22'] > (thresholds['temp_threshold'] ?? 58)) {
          potentialCauses += "• High temperature suggests heat source nearby. Detected by DHT22.\n";
        }
        if (currentData['temperaturemlx90614'] != null && currentData['temperaturemlx90614'] > (thresholds['temp_threshold'] ?? 58)) {
          potentialCauses += "• High temperature suggests heat source nearby. Detected by MLX90614.\n";
        }
        if (potentialCauses.isEmpty) {
          potentialCauses = "• Possible false alarm or sensor malfunction\n";
        }

        // Calculate recommended actions based on threshold breaches
        String recommendedActions = "";
        bool hasCriticalIssue = false;
        bool hasWarningIssue = false;

        if ((currentData['smokelevel'] != null && currentData['smokelevel'] > (thresholds['smoke_threshold'] ?? 91)) ||
            (currentData['carbonmonoxide'] != null && currentData['carbonmonoxide'] > (thresholds['co_threshold'] ?? 15))) {
          hasCriticalIssue = true;
        }

        if ((currentData['temperaturedht22'] != null && currentData['temperaturedht22'] > (thresholds['temp_threshold'] ?? 58)) ||
            (currentData['temperaturemlx90614'] != null && currentData['temperaturemlx90614'] > (thresholds['temp_threshold'] ?? 58)) ||
            (currentData['indoorairquality'] != null && currentData['indoorairquality'] > (thresholds['iaq_threshold'] ?? 350))) {
          hasWarningIssue = true;
        }

        if (hasCriticalIssue) {
          recommendedActions += "• Evacuate the area immediately\n";
          recommendedActions += "• Contact emergency services\n";
          recommendedActions += "• Check for visible signs of fire or smoke\n";
        } else if (hasWarningIssue) {
          recommendedActions += "• Investigate the area for potential hazards\n";
          recommendedActions += "• Ventilate the area if safe to do so\n";
          recommendedActions += "• Monitor sensor readings closely\n";
        } else {
          recommendedActions += "• Check device placement and ventilation\n";
          recommendedActions += "• Monitor for recurring alarms\n";
          recommendedActions += "• Consider sensor calibration if false alarms persist\n";
        }

        return Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Event Analysis",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 15),

              // Potential Causes
              Text(
                "Potential Causes:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5),
              Text(potentialCauses),
              SizedBox(height: 10),

              // Recommended Actions
              Text(
                "Recommended Actions:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5),
              Text(recommendedActions),
              SizedBox(height: 15),

              // Technical Details
              Text(
                "Technical Details:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5),
              _buildStatRow('Temperature (DHT22)', '${currentData['temperaturedht22']?.toStringAsFixed(1) ?? "N/A"}°C'),
              _buildStatRow('Temperature (MLX90614)', '${currentData['temperaturemlx90614']?.toStringAsFixed(1) ?? "N/A"}°C'),
              _buildStatRow('Humidity', '${currentData['humidity']?.toStringAsFixed(1) ?? "N/A"}%'),
              _buildStatRow('Carbon Monoxide', '${currentData['carbonmonoxide']?.toStringAsFixed(1) ?? "N/A"}ppm'),
              _buildStatRow('Air Quality', '${currentData['indoorairquality']?.toStringAsFixed(1) ?? "N/A"} AQI'),
              _buildStatRow('Smoke Level', '${currentData['smokelevel']?.toStringAsFixed(1) ?? "N/A"}µg/m³'),

              SizedBox(height: 10),
              Text(
                "Threshold Values:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5),
              _buildStatRow('Max Temperature', '${thresholds['temp_threshold'] ?? 58}°C'),
              _buildStatRow('Min Humidity', '${thresholds['humidity_threshold'] ?? 30}%'),
              _buildStatRow('Max CO', '${thresholds['co_threshold'] ?? 15}ppm'),
              _buildStatRow('Max AQI', '${thresholds['smoke_threshold'] ?? 350}AQI'),
              _buildStatRow('Max Smoke', '${thresholds['smoke_threshold'] ?? 91}µg/m³'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  EdgeInsets _getTitlePadding(double value, double minY, double maxY) {
    return EdgeInsets.only(
      right: 4.0,
      bottom: (value - minY).abs() < 0.001 ? 0 : 8.0,
      top: (value - maxY).abs() < 0.001 ? 0 : 8.0,
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
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(alarm['id'],
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800)),
                        IconButton(
                          icon: Icon(Icons.download),
                          onPressed: () => _generatePdfReport(alarm),
                          tooltip: 'Download Report',
                        ),
                      ],
                    ),
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
                                builder: (context, setState) {
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
    print("[DEBUG] Alarm data: $alarm");
    if (alarm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: Invalid alarm data")),
      );
      return;
    }

    try {
      final thresholdDoc = await _firestore.collection('Threshold').doc('Proxy').get();
      final thresholds = thresholdDoc.data() ?? {
        'co_threshold': 15,
        'humidity_threshold': 30,
        'iaq_threshold': 350,
        'smoke_threshold': 91,
        'temp_threshold': 58,
      };

      String formattedTimestamp;
      try {
        formattedTimestamp = _formatTimestamp(alarm['timestamp'] ?? '');
      } catch (e) {
        formattedTimestamp = "Invalid timestamp";
      }

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
        builder: (context) => Dialog(
          backgroundColor: Colors.white,
          insetPadding: EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alarm['id'] ?? 'Unknown Alarm',
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
                                fontFamily: 'Arimo',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),

                        ...(alarm['values'] is Map ? (alarm['values'] as Map<String, dynamic>).entries.map<Widget>((entry) {
                          if (entry.key == 'timestamp') return SizedBox.shrink();

                          var sensorInfo = sensorDetails[entry.key] ?? {'name': entry.key, 'unit': ''};
                          String sensorName = sensorInfo['name']!;
                          String sensorUnit = sensorInfo['unit']!;
                          bool exceedsThreshold = _exceedsThresholdForSensor(entry.key, entry.value, thresholds);

                          // Safely parse the value
                          double? value;
                          try {
                            value = double.tryParse(entry.value.toString());
                          } catch (e) {
                            value = null;
                          }

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
                                  value != null ? "${value.toStringAsFixed(1)} $sensorUnit" : "N/A $sensorUnit",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: exceedsThreshold ? Colors.red[700] : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList() : []),

                        if (alarm['analyticsData'] != null) ...[
                          SizedBox(height: 20),
                          _buildAnalyticsSnapshot(context, alarm),
                        ],

                        if (alarm['imageUrl'] != null) ...[
                          SizedBox(height: 20),
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
                          Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: 300,
                                maxWidth: MediaQuery.of(context).size.width * 0.8,
                              ),
                              child: GestureDetector(
                                onTap: () => _showFullScreenImage(context, alarm['imageUrl']),
                                child: Image.network(
                                  alarm['imageUrl'],
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Text('Failed to load image');
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor, // Changed to theme primary color
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Close',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      print("Error showing sensor values: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error displaying alarm details")),
      );
    }
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
    if (sensorValue == null) return false;

    switch (sensorKey) {
      case 'carbon_monoxide':
        return sensorValue > (thresholds['co_threshold'] ?? 15);
      case 'humidity_dht22':
        return sensorValue < (thresholds['humidity_threshold'] ?? 30);
      case 'indoor_air_quality':
        return sensorValue > (thresholds['iaq_threshold'] ?? 350);
      case 'smoke_level':
        return sensorValue > (thresholds['smoke_threshold'] ?? 91);
      case 'temperature_mlx90614':
      case 'temperature_dht22':
        return sensorValue > (thresholds['temp_threshold'] ?? 58);
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