import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrendAnalysisService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Define thresholds for each sensor
  final Map<String, double> sensorThresholds = {
    'carbon_monoxide': 10.0,
    'indoor_air_quality': 50.0,
    'smoke_level': 0.05,
    'temperature_dht22': 5.0,
    'temperature_mlx90614': 5.0,
  };

  final Set<String> _notifiedSensors = {};
  final Set<String> _monitoredProductCodes = {};
  final Map<String, Timer> _productTimers = {};
  String? _currentUserEmail;

  TrendAnalysisService._privateConstructor();
  static final TrendAnalysisService _instance =
  TrendAnalysisService._privateConstructor();
  factory TrendAnalysisService() => _instance;

  void initialize() {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    flutterLocalNotificationsPlugin.initialize(initializationSettings);
    _currentUserEmail = _auth.currentUser?.email;
    _requestNotificationPermissions();
    _startMonitoringAuthorizedDevices();
  }

  void _requestNotificationPermissions() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('Notification permission status: ${settings.authorizationStatus}');
  }

  void _startMonitoringAuthorizedDevices() {
    _firestore.collection('ProductActivation').snapshots().listen((snapshot) {
      final newProductCodes = snapshot.docs
          .where((doc) => _isUserAuthorized(doc))
          .map((doc) => doc['product_code'] as String)
          .where((code) => code != null)
          .toSet();

      _updateMonitoredProducts(newProductCodes);
    });
  }

  bool _isUserAuthorized(DocumentSnapshot doc) {
    if (_currentUserEmail == null) return false;

    final userEmail = doc['user_email'] as String?;
    final sharedUsers = List<String>.from(doc['shared_users'] ?? []);

    return userEmail == _currentUserEmail ||
        sharedUsers.contains(_currentUserEmail);
  }

  void _updateMonitoredProducts(Set<String> newProductCodes) {
    // Stop monitoring removed products
    final productsToRemove = _monitoredProductCodes.difference(newProductCodes);
    for (final removedCode in productsToRemove) {
      _productTimers[removedCode]?.cancel();
      _productTimers.remove(removedCode);
      _monitoredProductCodes.remove(removedCode);
    }

    // Start monitoring new products
    final productsToAdd = newProductCodes.difference(_monitoredProductCodes);
    for (final newCode in productsToAdd) {
      _startMonitoringProduct(newCode);
      _monitoredProductCodes.add(newCode);
    }
  }

  void _startMonitoringProduct(String productCode) {
    // Start immediately and then every minute
    _analyzeProductTrends(productCode);

    _productTimers[productCode] = Timer.periodic(
      const Duration(minutes: 1),
          (_) => _analyzeProductTrends(productCode),
    );
  }

  Future<void> _analyzeProductTrends(String productCode) async {
    try {
      _notifiedSensors.clear();

      QuerySnapshot snapshot = await _firestore
          .collection('LSTM')
          .doc('Predictions')
          .collection(productCode)
          .orderBy('timestamp', descending: true)
          .limit(4)
          .get();

      if (snapshot.docs.isEmpty) {
        print("No predictions found for $productCode");
        return;
      }

      List<Map<String, dynamic>> predictions = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList()
          .reversed
          .toList();

      _analyzeAndNotifyForSensor(predictions, productCode, 'carbon_monoxide', 'Carbon Monoxide');
      _analyzeAndNotifyForSensor(predictions, productCode, 'indoor_air_quality', 'Indoor Air Quality');
      _analyzeAndNotifyForSensor(predictions, productCode, 'smoke_level', 'Smoke Level');
      _analyzeAndNotifyForSensor(predictions, productCode, 'temperature_dht22', 'Temperature (DHT22)');
      _analyzeAndNotifyForSensor(predictions, productCode, 'temperature_mlx90614', 'Temperature (MLX90614)');
    } catch (error) {
      print("Error analyzing trends for $productCode: $error");
    }
  }

  void _analyzeAndNotifyForSensor(
      List<Map<String, dynamic>> predictions,
      String productCode,
      String sensorKey,
      String sensorName
      ) {
    List<double> sensorValues = predictions
        .map<double>((prediction) => prediction[sensorKey].toDouble())
        .toList();

    if (_isUpwardTrend(sensorValues)) {
      String title = "⚠️ $sensorName Alert ($productCode)";
      String body = "$sensorName is projected to rise in the next 40 seconds!";
      _sendNotification(title, body);
    }

    if (!_notifiedSensors.contains(sensorKey) &&
        _hasPositiveJumpExceedingThreshold(sensorValues, sensorKey)) {
      String title = "⚠️ $sensorName Alert ($productCode)";
      String body = "$sensorName has a significant increase projected!";
      _sendNotification(title, body);
      _notifiedSensors.add(sensorKey);
    }
  }

  bool _isUpwardTrend(List<double> values) {
    for (int i = 1; i < values.length; i++) {
      if (values[i] <= values[i - 1]) return false;
    }
    return true;
  }

  bool _hasPositiveJumpExceedingThreshold(List<double> values, String sensorKey) {
    double threshold = sensorThresholds[sensorKey]!;
    for (int i = 1; i < values.length; i++) {
      if (values[i] - values[i - 1] > threshold) return true;
    }
    return false;
  }

  void _sendNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'trend_channel_id',
      'Trend Alerts',
      channelDescription: 'Channel for trend-based alerts',
      importance: Importance.high,
      priority: Priority.high,
    );

    await flutterLocalNotificationsPlugin.show(
      1,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: 'Trend Alert Payload',
    );
  }

  void dispose() {
    _productTimers.values.forEach((timer) => timer.cancel());
    _productTimers.clear();
    _monitoredProductCodes.clear();
  }
}