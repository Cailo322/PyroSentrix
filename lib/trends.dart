import 'dart:async'; // Import for Timer
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';


class TrendAnalysisService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Define thresholds for each sensor
  final Map<String, double> sensorThresholds = {
    'carbon_monoxide': 10.0,       // Threshold: 10
    'indoor_air_quality': 50.0,    // Threshold: 50
    'smoke_level': 0.05,            // Threshold: 0.05 (added this sensor)
    'temperature_dht22': 5.0,       // Threshold: 5
    'temperature_mlx90614': 5.0,    // Threshold: 5
  };

  // Track sensors that have already triggered a notification in the current window
  final Set<String> _notifiedSensors = {};

  TrendAnalysisService._privateConstructor();
  static final TrendAnalysisService _instance = TrendAnalysisService._privateConstructor();
  factory TrendAnalysisService() => _instance;

  // Initialize the notification plugin and FirebaseMessaging
  void initialize() {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Request notification permissions for FirebaseMessaging
    _requestNotificationPermissions();
  }

  // Request notification permissions
  void _requestNotificationPermissions() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission for notifications');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional permission for notifications');
    } else {
      print('User declined or has not accepted permission for notifications');
    }
  }

  // Start analyzing trends every 1 minute
  void startTrendAnalysis() {
    // Analyze trends immediately when the function is called
    analyzeTrendsAndNotify();

    // Set up a periodic timer to analyze trends every 1 minute
    const Duration interval = Duration(minutes: 1);
    Timer.periodic(interval, (Timer timer) async {
      await analyzeTrendsAndNotify();
    });
  }

  // Fetch the latest 4 predictions and analyze trends
  Future<void> analyzeTrendsAndNotify() async {
    try {
      // Reset the notified sensors set at the start of each analysis cycle
      _notifiedSensors.clear();

      // Fetch the latest 4 predictions ordered by timestamp (descending)
      QuerySnapshot snapshot = await _firestore
          .collection('LSTM')
          .doc('Predictions')
          .collection('HpLk33atBI')
          .orderBy('timestamp', descending: true)
          .limit(4)
          .get();

      if (snapshot.docs.isEmpty) {
        print("No predictions found.");
        return;
      }

      // Extract predictions and reverse to get ascending order (oldest first)
      List<Map<String, dynamic>> predictions = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList()
          .reversed
          .toList();

      // Analyze trends for each sensor
      _analyzeAndNotifyForSensor(predictions, 'carbon_monoxide', 'Carbon Monoxide');
      _analyzeAndNotifyForSensor(predictions, 'indoor_air_quality', 'Indoor Air Quality');
      _analyzeAndNotifyForSensor(predictions, 'smoke_level', 'Smoke Level');
      _analyzeAndNotifyForSensor(predictions, 'temperature_dht22', 'Temperature (DHT22)');
      _analyzeAndNotifyForSensor(predictions, 'temperature_mlx90614', 'Temperature (MLX90614)');
    } catch (error) {
      print("Error analyzing trends: $error");
    }
  }

  // Analyze trend for a specific sensor and send notification if on upward trend or jump exceeds threshold
  void _analyzeAndNotifyForSensor(List<Map<String, dynamic>> predictions, String sensorKey, String sensorName) {
    // Explicitly cast the mapped values to List<double>
    List<double> sensorValues = predictions.map<double>((prediction) => prediction[sensorKey].toDouble()).toList();

    // Method 1: Check for upward trend
    if (_isUpwardTrend(sensorValues)) {
      String title = "⚠️ $sensorName Alert";
      String body = "$sensorName is projected to rise in the next 40 seconds! Please inspect your surroundings";
      print("$sensorName is on an upward trend. Sending notification...");
      _sendNotification(title, body);
    }

    // Method 2: Check for positive jumps exceeding the threshold
    if (!_notifiedSensors.contains(sensorKey) && _hasPositiveJumpExceedingThreshold(sensorValues, sensorKey)) {
      String title = "⚠️ $sensorName Alert";
      String body = "$sensorName is projected to rise in the next 40 seconds! Please inspect your surroundings";
      print("$sensorName has a positive jump exceeding the threshold. Sending notification...");
      _sendNotification(title, body);

      // Mark this sensor as notified for the current window
      _notifiedSensors.add(sensorKey);
    }
  }

  // Method 1: Check if the values are consistently increasing
  bool _isUpwardTrend(List<double> values) {
    for (int i = 1; i < values.length; i++) {
      if (values[i] <= values[i - 1]) {
        return false; // Not an upward trend
      }
    }
    return true; // All values are increasing
  }

  // Method 2: Check if any positive jump exceeds the threshold
  bool _hasPositiveJumpExceedingThreshold(List<double> values, String sensorKey) {
    double threshold = sensorThresholds[sensorKey]!;

    for (int i = 1; i < values.length; i++) {
      double jump = values[i] - values[i - 1]; // Positive jumps only
      if (jump > threshold) {
        return true; // Positive jump exceeds the threshold
      }
    }
    return false; // No positive jump exceeds the threshold
  }

  // Send a push notification
  void _sendNotification(String title, String body) async {
    var androidPlatformChannelSpecifics = const AndroidNotificationDetails(
      'trend_channel_id',
      'Trend Alerts',
      channelDescription: 'Channel for trend-based alerts',
      importance: Importance.high,
      priority: Priority.high,
    );

    var platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      1,
      title,
      body,
      platformChannelSpecifics,
      payload: 'Trend Alert Payload',
    );

    // Optionally, send a Firebase Cloud Message (FCM)
    await _sendFirebaseNotification(title, body);
  }

  // Send a Firebase Cloud Message (FCM)
  Future<void> _sendFirebaseNotification(String title, String body) async {
    try {
      // Replace with your FCM server logic or use Firebase Cloud Functions to send notifications
      print("Sending Firebase notification: $title - $body");
    } catch (error) {
      print("Error sending Firebase notification: $error");
    }
  }
}