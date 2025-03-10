import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'device_provider.dart'; // Import DeviceProvider
import 'analytics.dart'; // Import AnalyticsScreen
import 'devices.dart'; // Import DevicesScreen
import 'add_device.dart';
import 'alarmlogs.dart';
import 'reset_system.dart';
import 'queries.dart';
import 'imagestream.dart';
import 'call.dart';
import 'login.dart';
import 'monitor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    ChangeNotifierProvider(
      create: (context) => DeviceProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pyrosentrix',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: DevicesScreen(),
      routes: {
        '/AddDeviceScreen': (context) => AddDeviceScreen(),
        '/DevicesScreen': (context) => DevicesScreen(),
        '/ResetSystemScreen': (context) => ResetSystemScreen(),
        '/QueriesScreen': (context) => QueriesScreen(),
        '/ImageStreamScreen': (context) => ImageStreamScreen(),
        '/CallHelpScreen': (context) => CallHelpScreen(),
        '/AnalyticsScreen': (context) => AnalyticsScreen(),
        '/LoginScreen': (context) => LoginScreen(),
      },
      onGenerateRoute: (settings) {
        // Handle AlarmLogScreen with productCode argument
        if (settings.name == '/AlarmLogScreen') {
          final String productCode = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => AlarmLogScreen(productCode: productCode),
          );
        }
        // Handle MonitorScreen with productCode argument
        if (settings.name == '/MonitorScreen') {
          final String productCode = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => MonitorScreen(productCode: productCode),
          );
        }
        return null;
      },
    );
  }
}