import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'splash_screen.dart';
import 'devices.dart';
import 'add_device.dart';
import 'monitor.dart';
import 'call.dart';
import 'custom_app_bar.dart';
import 'queries.dart';
import 'login.dart';
import 'notification_service.dart'; // Import the notification service
import 'trends.dart'; // Import the trend analysis service
import 'about.dart';
import 'reset_system.dart';
import 'imagestream.dart';
import 'alarmlogs.dart';
import 'device_provider.dart'; // Import your DeviceProvider
import 'analytics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize NotificationService
  NotificationService notificationService = NotificationService();
  notificationService.initialize(); // Initialize the notification plugin
  notificationService.requestPermissions(); // Request notification permissions
  notificationService.listenForSensorUpdates(); // Start listening for sensor updates

  // Initialize TrendAnalysisService
  TrendAnalysisService trendAnalysisService = TrendAnalysisService();
  trendAnalysisService.initialize(); // Initialize the trend analysis service
  trendAnalysisService.startTrendAnalysis(); // Start analyzing trends every 1 minute

  // Check login state
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(
    // Wrap your app with the DeviceProvider
    ChangeNotifierProvider(
      create: (context) => DeviceProvider(), // Create an instance of DeviceProvider
      child: MyApp(isLoggedIn: isLoggedIn),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pyrosentrix',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: isLoggedIn ? DevicesScreen() : SplashScreen(),
      onGenerateRoute: (settings) {
        // Handle arguments for MonitorScreen
        if (settings.name == '/MonitorScreen') {
          final args = settings.arguments as String; // productCode is passed as a String
          return MaterialPageRoute(
            builder: (context) => MonitorScreen(productCode: args),
          );
        }
        // Handle arguments for AlarmLogScreen
        if (settings.name == '/AlarmLogScreen') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => AlarmLogScreen(productCode: args['productCode']),
          );
        }
        // Handle arguments for ResetSystemScreen
        if (settings.name == '/ResetSystemScreen') {
          final args = settings.arguments as String; // productCode is passed as a String
          return MaterialPageRoute(
            builder: (context) => ResetSystemScreen(productCode: args),
          );
        }

        return null;
      },
      routes: {
        '/AddDeviceScreen': (context) => AddDeviceScreen(),
        '/CallHelpScreen': (context) => CallHelpScreen(),
        '/QueriesScreen': (context) => QueriesScreen(),
        '/DevicesScreen': (context) => DevicesScreen(),
        '/LoginScreen': (context) => LoginScreen(),
        '/AnalyticsScreen': (context) => AnalyticsScreen(),
        '/AboutScreen': (context) => AboutScreen(),
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