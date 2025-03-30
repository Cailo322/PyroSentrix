import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
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
import 'profile.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FlutterDownloader.initialize();

  // Initialize services
  final notificationService = NotificationService();
  notificationService.initialize();

  final trendAnalysisService = TrendAnalysisService();
  trendAnalysisService.initialize();

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
      debugShowCheckedModeBanner: false, // This removes the debug banner
      title: 'Pyrosentrix',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: isLoggedIn ? DevicesScreen() : SplashScreen(),
      // Update the onGenerateRoute section:
      onGenerateRoute: (settings) {
        if (settings.name == '/MonitorScreen') {
          final args = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => MonitorScreen(productCode: args),
            settings: settings, // Important for route tracking
          );
        }
        if (settings.name == '/AlarmLogScreen') {
          return MaterialPageRoute(
            builder: (context) => AlarmLogScreen(),
            settings: settings, // Important for route tracking
          );
        }
        if (settings.name == '/ResetSystemScreen') {
          return MaterialPageRoute(
            builder: (context) => ResetSystemScreen(),
            settings: settings, // Important for route tracking
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
        '/ProfileScreen': (context) => ProfileScreen(),
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