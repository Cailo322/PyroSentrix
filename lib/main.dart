import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'welcome_screen.dart';
import 'register.dart';
import 'devices.dart';
import 'add_device.dart';
import 'monitor.dart';
import 'call.dart';
import 'custom_app_bar.dart';
import 'queries.dart';
import 'login.dart';
import 'notification_service.dart'; // Add the notification service import
import 'about.dart';
import 'reset_system.dart';
import 'imagestream.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize NotificationService
  NotificationService notificationService = NotificationService();
  notificationService.initialize();
  notificationService.requestPermissions();
  notificationService.listenForSensorUpdates();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pyrosentrix',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: SplashScreen(),
      routes: {
        '/AddDeviceScreen': (context) => AddDeviceScreen(),
        '/MonitorScreen': (context) => MonitorScreen(),
        '/CallHelpScreen': (context) => CallHelpScreen(),
        '/QueriesScreen': (context) => QueriesScreen(),
        '/DevicesScreen': (context) => DevicesScreen(),
        '/LoginScreen': (context) => LoginScreen(),
        '/AboutScreen': (context) => AboutScreen(),
        '/ResetSystemScreen': (context) => ResetSystemScreen(),
        '/devices': (context) => DevicesScreen(),
        '/ImageStreamScreen': (context) => ImageStreamScreen(),
      },
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      endDrawer: CustomDrawer(),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const <Widget>[
            Text('Welcome to Pyrosentrix!'),
          ],
        ),
      ),
    );
  }
}
