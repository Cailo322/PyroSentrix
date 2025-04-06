import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';

class DeviceStatusMonitor {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin;

  String? _currentUserEmail;
  late SharedPreferences _prefs;
  final Map<String, StreamSubscription<DocumentSnapshot>> _statusSubscriptions = {};
  final Map<String, bool?> _lastKnownStatus = {};

  DeviceStatusMonitor(this._notificationsPlugin);

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);
    _currentUserEmail = _auth.currentUser?.email;
    _prefs = await SharedPreferences.getInstance();
    _requestNotificationPermissions();
    _setupNotificationChannels();
    _listenForActiveDevices();
  }

  Future<void> _requestNotificationPermissions() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('Notification permission status: ${settings.authorizationStatus}');
  }

  void _setupNotificationChannels() {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'device_status_channel',
      'Device Status',
      importance: Importance.high,
    );

    _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _listenForActiveDevices() {
    _firestore.collection('ProductActivation').snapshots().listen((snapshot) {
      final activeDevices = snapshot.docs
          .where((doc) => _isUserAuthorized(doc))
          .map((doc) => doc['product_code'] as String)
          .where((code) => code != null)
          .toSet();

      _updateStatusSubscriptions(activeDevices);
    });
  }

  bool _isUserAuthorized(DocumentSnapshot doc) {
    if (_currentUserEmail == null) return false;
    final userEmail = doc['user_email'] as String?;
    final sharedUsers = List<String>.from(doc['shared_users'] ?? []);
    return userEmail == _currentUserEmail || sharedUsers.contains(_currentUserEmail);
  }

  void _updateStatusSubscriptions(Set<String> activeDevices) {
    _statusSubscriptions.keys.toSet().difference(activeDevices).forEach((device) {
      _statusSubscriptions[device]?.cancel();
      _statusSubscriptions.remove(device);
      _lastKnownStatus.remove(device);
    });

    activeDevices.difference(_statusSubscriptions.keys.toSet()).forEach((device) {
      _statusSubscriptions[device] = _monitorDeviceStatus(device);
    });
  }

  StreamSubscription<DocumentSnapshot> _monitorDeviceStatus(String deviceId) {
    return _firestore.collection('DeviceStatus').doc(deviceId).snapshots().listen(
          (snapshot) async {
        if (snapshot.exists) {
          final isOnline = snapshot['online'] ?? true;

          if (_lastKnownStatus[deviceId] == null || isOnline != _lastKnownStatus[deviceId]) {
            await _sendStatusNotification(deviceId, isOnline);
          }

          _lastKnownStatus[deviceId] = isOnline;
        }
      },
      onError: (error) => print('Error monitoring device status: $error'),
    );
  }

  Future<String> _getDeviceName(String deviceId) async {
    try {
      return _prefs.getString('device_name_$deviceId') ?? 'Device $deviceId';
    } catch (e) {
      return 'Device $deviceId';
    }
  }

  Future<void> _sendStatusNotification(String deviceId, bool isOnline) async {
    try {
      final deviceName = await _getDeviceName(deviceId);
      final title = '$deviceName Device Status Update';
      final String body;

      if (isOnline) {
        body = '🟢Device is back online and monitoring as expected.';
      } else {
        body = '🔴Device is offline. Network or power may be disconnected. Please verify.';
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'device_status_channel',
        'Device Status',
        channelDescription: 'Notifications for device status changes',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      );

      await _notificationsPlugin.show(
        deviceId.hashCode,
        title,
        body,
        const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      print('Error sending status notification: $e');
    }
  }

  Future<void> dispose() async {
    _statusSubscriptions.values.forEach((sub) => sub.cancel());
    _statusSubscriptions.clear();
    _lastKnownStatus.clear();
  }
}