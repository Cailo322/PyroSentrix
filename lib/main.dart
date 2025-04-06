import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'splash_screen.dart';
import 'devices.dart';
import 'add_device.dart';
import 'monitor.dart';
import 'call.dart';
import 'custom_app_bar.dart';
import 'queries.dart';
import 'login.dart';
import 'notification_service.dart';
import 'status.dart'; // Add this import
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

  // Initialize notifications plugin
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Initialize services
  final notificationService = NotificationService();
  await notificationService.initialize();

  final statusMonitor = DeviceStatusMonitor(flutterLocalNotificationsPlugin); // New
  await statusMonitor.initialize(); // New

  final trendAnalysisService = TrendAnalysisService();
  trendAnalysisService.initialize();

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => DeviceProvider()),
        Provider<NotificationService>.value(value: notificationService),
        Provider<DeviceStatusMonitor>.value(value: statusMonitor), // New
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
      debugShowCheckedModeBanner: false,
      title: 'Pyrosentrix',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: isLoggedIn ? DevicesScreen() : SplashScreen(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/MonitorScreen':
            final args = settings.arguments as String;
            return _pageRouteBuilder(MonitorScreen(productCode: args), settings);
          case '/AlarmLogScreen':
            return _pageRouteBuilder(AlarmLogScreen(), settings);
          case '/ResetSystemScreen':
            return _pageRouteBuilder(ResetSystemScreen(), settings);
          default:
            return null;
        }
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

  PageRouteBuilder _pageRouteBuilder(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      settings: settings,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
    );
  }
}

// Rest of your code remains the same...
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