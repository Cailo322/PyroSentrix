import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'splash_screen.dart';
import 'devices.dart';
import 'add_device.dart';
import 'monitor.dart';
import 'call.dart';
import 'custom_app_bar.dart';
import 'queries.dart';
import 'login.dart';
import 'notification_service.dart';
import 'status.dart';
import 'trends.dart';
import 'about.dart';
import 'reset_system.dart';
import 'alarmlogs.dart';
import 'device_provider.dart';
import 'analytics.dart';
import 'profile.dart';
import 'connectivity_service.dart';
import 'no_internet_popup.dart';
import 'tutorial.dart';

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

  final statusMonitor = DeviceStatusMonitor(flutterLocalNotificationsPlugin);
  await statusMonitor.initialize();

  final trendAnalysisService = TrendAnalysisService();
  trendAnalysisService.initialize();

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => DeviceProvider()),
        ChangeNotifierProvider(create: (context) => ConnectivityService()),
        Provider<NotificationService>.value(value: notificationService),
        Provider<DeviceStatusMonitor>.value(value: statusMonitor),
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
      home: isLoggedIn ? InternetWrapper(child: DevicesScreen()) : SplashScreen(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/MonitorScreen':
            final args = settings.arguments as String;
            return _pageRouteBuilder(InternetWrapper(child: MonitorScreen(productCode: args)), settings);
          case '/AlarmLogScreen':
            return _pageRouteBuilder(InternetWrapper(child: AlarmLogScreen()), settings);
          case '/ResetSystemScreen':
            return _pageRouteBuilder(InternetWrapper(child: ResetSystemScreen()), settings);
          default:
            return null;
        }
      },
      routes: {
        '/AddDeviceScreen': (context) => InternetWrapper(child: AddDeviceScreen()),
        '/CallHelpScreen': (context) => InternetWrapper(child: CallHelpScreen()),
        '/QueriesScreen': (context) => InternetWrapper(child: QueriesScreen()),
        '/DevicesScreen': (context) => InternetWrapper(child: DevicesScreen()),
        '/LoginScreen': (context) => LoginScreen(),
        '/AnalyticsScreen': (context) => InternetWrapper(child: AnalyticsScreen()),
        '/AboutScreen': (context) => InternetWrapper(child: AboutScreen()),
        '/ProfileScreen': (context) => InternetWrapper(child: ProfileScreen()),
        '/TutorialScreen': (context) => InternetWrapper(child: TutorialScreen()),      },
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

class InternetWrapper extends StatelessWidget {
  final Widget child;
  const InternetWrapper({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final connectivity = Provider.of<ConnectivityService>(context);

    return Stack(
      children: [
        child,
        if (!connectivity.hasInternet)
          const ModalBarrier(
            color: Colors.black54,
            dismissible: false,
          ),
        if (!connectivity.hasInternet)
          const NoInternetPopup(),
      ],
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