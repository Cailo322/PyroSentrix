import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:audioplayers/audioplayers.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer(); // Audio player instance
  NotificationService._privateConstructor();
  static final NotificationService _instance = NotificationService._privateConstructor();
  factory NotificationService() => _instance;

  Set<String> _acknowledgedAlerts = {}; // To track acknowledged alerts

  // Initialize the notification plugin
  void initialize() {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // Start listening for sensor data updates and compare with thresholds
  void listenForSensorUpdates() {
    // Monitor the first collection: HpLk33atBI
    _monitorProductCode('HpLk33atBI');

    // Monitor the second collection: oURnq0vZrP
    _monitorProductCode('oURnq0vZrP');
  }

  // Monitor a specific product code's sensor data
  void _monitorProductCode(String productCode) {
    print("Setting up listener for product code: $productCode");

    _firestore
        .collection('SensorData')
        .doc('FireAlarm')
        .collection(productCode)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        var latestData = snapshot.docs.first.data();
        print("New sensor data received for $productCode: $latestData");

        _firestore.collection('Threshold').doc('Proxy').get().then((thresholdDoc) {
          var thresholds = thresholdDoc.data();

          if (thresholds != null) {
            print("Thresholds found: $thresholds");
            _compareSensorValues(latestData, thresholds);
          } else {
            print("No thresholds found for $productCode");
          }
        }).catchError((error) {
          print("Error fetching thresholds: $error");
        });
      } else {
        print("No documents found in the $productCode subcollection");
      }
    }, onError: (error) {
      print("Error listening to $productCode: $error");
    });
  }

  // Compare sensor values with the threshold values
  void _compareSensorValues(Map<String, dynamic> latestData, Map<String, dynamic> thresholds) {
    print("Comparing sensor values with thresholds...");
    print("Latest Data: $latestData");
    print("Thresholds: $thresholds");

    List<String> alerts = [];

    if (latestData['carbon_monoxide'] > thresholds['co_threshold']) {
      alerts.add("🔴 CO levels are too high!");
    }
    if (latestData['smoke_level'] > thresholds['smoke_threshold']) {
      alerts.add("🔴 Smoke levels are too high!");
    }
    if (latestData['humidity_dht22'] < thresholds['humidity_threshold']) {
      alerts.add("🔴 Humidity levels are critically low!");
    }
    if (latestData['indoor_air_quality'] > thresholds['iaq_threshold']) {
      alerts.add("🔴 Indoor air quality is poor!");
    }
    if (latestData['temperature_dht22'] > thresholds['temp_threshold']) {
      alerts.add("🔴 Temperature is too high!");
    }
    if (latestData['temperature_mlx90614'] > thresholds['temp_threshold']) {
      alerts.add("🔴 Temperature is too high!");
    }

    if (alerts.isNotEmpty) {
      print("Alerts triggered: $alerts");
      Set<String> currentAlerts = alerts.toSet();

      if (!_acknowledgedAlerts.containsAll(currentAlerts)) {
        String title = "Alert: Sensor Levels Exceeded";
        String body = alerts.length <= 3
            ? alerts.join('\n')
            : "${alerts.take(3).join('\n')}\n\nAnd ${alerts.length - 3} more alerts...";

        print("Sending notification: $title - $body");
        sendNotification(title, body);
        _acknowledgedAlerts = currentAlerts;
      } else {
        print("Alerts already acknowledged: $alerts");
      }
    } else {
      print("No alerts triggered.");
    }
  }

  // Acknowledge the current alerts
  void acknowledgeAlerts() {
    _acknowledgedAlerts.clear(); // Reset the acknowledged alerts
    stopAlarmSound(); // Stop any ongoing alarm sound
  }

  // Send a push notification and play alarm sound
  void sendNotification(String title, String body) async {
    var androidPlatformChannelSpecifics = const AndroidNotificationDetails(
      'channel_id',
      'channel_name',
      channelDescription: 'Channel for sensor alerts',
      importance: Importance.high,
      priority: Priority.high,
    );

    var platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'Notification Payload',
    );

    _playAlarmSound();
  }

  // Play alarm sound on repeat
  void _playAlarmSound() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('alarm.mp3'));
      print("Alarm sound started.");
    } catch (e) {
      print("Error playing alarm sound: $e");
    }
  }

  // Stop alarm sound
  void stopAlarmSound() async {
    try {
      await _audioPlayer.stop();
      print("Alarm sound stopped.");
    } catch (e) {
      print("Error stopping alarm sound: $e");
    }
  }

  // Request notification permissions
  void requestPermissions() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User declined or has not accepted permission');
    }
  }
}