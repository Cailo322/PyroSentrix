import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  final StreamController<Set<String>> _alertedDevicesController =
  StreamController<Set<String>>.broadcast();

  NotificationService._privateConstructor();
  static final NotificationService _instance =
  NotificationService._privateConstructor();
  factory NotificationService() => _instance;

  Set<String> _alertedProductCodes = {};
  Set<String> _activeProductCodes = {};
  Map<String, StreamSubscription<QuerySnapshot>> _productSubscriptions = {};
  String? _currentUserEmail;

  Stream<Set<String>> get alertedDevices => _alertedDevicesController.stream;

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    await requestPermissions();
    _currentUserEmail = _auth.currentUser?.email;
    _listenForActiveProducts();
  }

  Future<void> requestPermissions() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: true,
    );
    print('Notification permission status: ${settings.authorizationStatus}');
  }

  void _listenForActiveProducts() {
    _firestore.collection('ProductActivation').snapshots().listen((snapshot) {
      final newProductCodes = snapshot.docs
          .where((doc) => _isUserAuthorized(doc))
          .map((doc) => doc['product_code'] as String)
          .where((code) => code != null)
          .toSet();

      _updateProductSubscriptions(newProductCodes);
    });
  }

  bool _isUserAuthorized(DocumentSnapshot doc) {
    if (_currentUserEmail == null) return false;

    final userEmail = doc['user_email'] as String?;
    final sharedUsers = List<String>.from(doc['shared_users'] ?? []);

    return userEmail == _currentUserEmail ||
        sharedUsers.contains(_currentUserEmail);
  }

  void _updateProductSubscriptions(Set<String> newProductCodes) {
    _activeProductCodes.difference(newProductCodes).forEach((removedCode) {
      _productSubscriptions[removedCode]?.cancel();
      _productSubscriptions.remove(removedCode);
    });

    newProductCodes.difference(_activeProductCodes).forEach((newCode) {
      _productSubscriptions[newCode] = _monitorProductCode(newCode);
    });

    _activeProductCodes = newProductCodes;
  }

  StreamSubscription<QuerySnapshot> _monitorProductCode(String productCode) {
    return _firestore
        .collection('SensorData')
        .doc('FireAlarm')
        .collection(productCode)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final latestData = snapshot.docs.first.data();
        await _checkThresholds(latestData, productCode);
      }
    });
  }

  Future<void> _checkThresholds(
      Map<String, dynamic> data, String productCode) async {
    try {
      final thresholdDoc = await _firestore.collection('Threshold').doc('Proxy').get();
      final thresholds = thresholdDoc.data();

      if (thresholds != null) {
        final combinedData = {...data, ...thresholds};
        final isAlert = _isThresholdExceeded(combinedData);
        if (isAlert) {
          await _handleAlert(productCode);
        }
      }
    } catch (e) {
      print('Error checking thresholds: $e');
    }
  }

  bool _isThresholdExceeded(Map<String, dynamic> combinedData) {
    return (combinedData['carbon_monoxide'] > combinedData['co_threshold']) ||
        (combinedData['smoke_level'] > combinedData['smoke_threshold']) ||
        (combinedData['humidity_dht22'] < combinedData['humidity_threshold']) ||
        (combinedData['indoor_air_quality'] > combinedData['iaq_threshold']) ||
        (combinedData['temperature_dht22'] > combinedData['temp_threshold']) ||
        (combinedData['temperature_mlx90614'] > combinedData['temp_threshold']);
  }

  Future<void> _handleAlert(String productCode) async {
    if (!_alertedProductCodes.contains(productCode)) {
      _alertedProductCodes.add(productCode);
      _alertedDevicesController.add(_alertedProductCodes);

      final notifStatus = await _firestore.collection('NotifStatus').doc(productCode).get();
      if (!(notifStatus.exists && notifStatus.data()?['notif'] == true)) {
        await _sendNotification(productCode);
        await _firestore.collection('NotifStatus').doc(productCode).set({
          'notif': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<String> _getDeviceName(String productCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('device_name_$productCode') ?? 'Device';
    } catch (e) {
      print('Error getting device name: $e');
      return 'Device';
    }
  }

  Future<Map<String, dynamic>> _getLatestSensorData(String productCode) async {
    try {
      final snapshot = await _firestore
          .collection('SensorData')
          .doc('FireAlarm')
          .collection(productCode)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty ? snapshot.docs.first.data() : {};
    } catch (e) {
      print('Error getting sensor data: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getThresholdValues() async {
    try {
      final snapshot = await _firestore.collection('Threshold').doc('Proxy').get();
      return snapshot.data() ?? {};
    } catch (e) {
      print('Error getting thresholds: $e');
      return {};
    }
  }

  Future<void> _sendNotification(String productCode) async {
    try {
      final deviceName = await _getDeviceName(productCode);
      final latestData = await _getLatestSensorData(productCode);
      final thresholds = await _getThresholdValues();

      if (latestData.isEmpty || thresholds.isEmpty) return;

      final combinedData = {...latestData, ...thresholds};
      final exceededThresholds = _getExceededThresholds(combinedData);

      if (exceededThresholds.isEmpty) return;

      final title = "$deviceName: Fire Alert!";
      final body = _createNotificationBody(exceededThresholds);

      const androidDetails = AndroidNotificationDetails(
        'channel_id',
        'channel_name',
        channelDescription: 'Threshold alerts',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      await flutterLocalNotificationsPlugin.show(
        0,
        title,
        body,
        const NotificationDetails(android: androidDetails),
      );

      await _playAlarmSound();
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  List<String> _getExceededThresholds(Map<String, dynamic> combinedData) {
    final List<String> exceeded = [];

    if (combinedData['carbon_monoxide'] > combinedData['co_threshold']) {
      exceeded.add('Carbon monoxide');
    }
    if (combinedData['smoke_level'] > combinedData['smoke_threshold']) {
      exceeded.add('Smoke level');
    }
    if (combinedData['humidity_dht22'] < combinedData['humidity_threshold']) {
      exceeded.add('Humidity');
    }
    if (combinedData['indoor_air_quality'] > combinedData['iaq_threshold']) {
      exceeded.add('Air quality');
    }
    if (combinedData['temperature_dht22'] > combinedData['temp_threshold']) {
      exceeded.add('Temperature');
    }
    if (combinedData['temperature_mlx90614'] > combinedData['temp_threshold']) {
      exceeded.add('Infrared temperature');
    }

    return exceeded;
  }

  String _createNotificationBody(List<String> exceededThresholds) {
    if (exceededThresholds.isEmpty) {
      return "Sensor readings are normal";
    }

    if (exceededThresholds.length == 1) {
      return "${exceededThresholds[0]} has exceeded the safe threshold!";
    }

    return "Multiple thresholds exceeded (${exceededThresholds.join(', ')})";
  }

  Future<void> _playAlarmSound() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('alarm.mp3'));
    } catch (e) {
      print('Error playing alarm: $e');
    }
  }

  Future<void> stopAlarmSound() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      print('Error stopping alarm: $e');
    }
  }

  Future<void> acknowledgeAlerts() async {
    _alertedProductCodes.clear();
    _alertedDevicesController.add(_alertedProductCodes);
    await stopAlarmSound();
  }

  Future<void> dispose() async {
    _productSubscriptions.values.forEach((sub) => sub.cancel());
    await _audioPlayer.dispose();
    await _alertedDevicesController.close();
  }
}