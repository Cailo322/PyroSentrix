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
import 'notification_service.dart';
import 'trends.dart';
import 'about.dart';
import 'reset_system.dart';
import 'alarmlogs.dart';
import 'device_provider.dart';
import 'analytics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize services
  final notificationService = NotificationService();
  await notificationService.initialize(); // Added await for proper initialization

  final trendAnalysisService = TrendAnalysisService();
  trendAnalysisService.initialize(); // Added await for proper initialization

  // Check login state
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => DeviceProvider()),
        Provider<NotificationService>.value(value: notificationService),
        Provider<TrendAnalysisService>.value(value: trendAnalysisService),
      ],
      child: MyApp(isLoggedIn: isLoggedIn),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({Key? key, required this.isLoggedIn}) : super(key: key);

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
        if (settings.name == '/MonitorScreen') {
          final args = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => MonitorScreen(productCode: args),
          );
        }
        if (settings.name == '/AlarmLogScreen') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => AlarmLogScreen(productCode: args['productCode']),
          );
        }
        if (settings.name == '/ResetSystemScreen') {
          final args = settings.arguments as String;
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
      },
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({Key? key}) : super(key: key);

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