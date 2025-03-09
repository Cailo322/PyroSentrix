import 'package:flutter/material.dart';
import 'alarmlogs.dart'; // Import the AlarmLogScreen widget
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'monitor.dart'; // Ensure this import is correct for your MonitorScreen
import 'device_provider.dart'; // Import the DeviceProvider from device_provider.dart
import 'package:provider/provider.dart'; // Add this import
import 'package:shared_preferences/shared_preferences.dart'; // Add this import
import 'analytics.dart'; // Import the AnalyticsScreen

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? selectedProductCode;

  CustomAppBar({Key? key, this.selectedProductCode})
      : preferredSize = Size.fromHeight(kToolbarHeight),
        super(key: key);

  @override
  final Size preferredSize;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black),
      actions: [
        Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openEndDrawer();
            },
          ),
        ),
      ],
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: Colors.white,
        ),
      ),
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class CustomDrawer extends StatefulWidget {
  final String? selectedProductCode;

  CustomDrawer({Key? key, this.selectedProductCode}) : super(key: key);

  @override
  _CustomDrawerState createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  String? userName;
  bool isNavigating = false; // Flag to prevent multiple navigation attempts

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  Future<void> _fetchUserName() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        setState(() {
          userName = userDoc['name'];
        });
      }
    } catch (e) {
      print('Error fetching user name: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.6,
      child: Container(
        color: Color(0xFFFFFFFF),
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(width: 8),
                      Text(
                        'Menu',
                        style: TextStyle(
                          fontSize: 35,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 15),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5), // Shadow color
                              spreadRadius: 1, // Spread radius
                              blurRadius: 4, // Blur radius
                              offset: Offset(0, 3), // Shadow offset
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.person,
                                size: 27,
                                color: Colors.amber[600],
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              userName ?? 'Loading...',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildSection('Monitoring', [
              _buildDrawerItem(context, 'Add Device', 'assets/add1.png', '/AddDeviceScreen'),
              _buildDrawerItem(context, 'Analytics', 'assets/analytics.png', '', isAnalytics: true),
              _buildDrawerItem(context, 'Dashboard', 'assets/dashboard.png', '', isMonitor: true),
              _buildDrawerItem(context, 'Devices', 'assets/devices.png', '/DevicesScreen'),
              _buildDrawerItem(context, 'Alarm logs', 'assets/Alarm-Logs.png', '', isAlarmLog: true),
            ]),
            _buildSection('Others', [
              _buildDrawerItem(context, 'System Reset', 'assets/System-Reset.png', '/ResetSystemScreen'),
              _buildDrawerItem(context, 'FAQs', 'assets/FAQs.png', '/QueriesScreen'),
              _buildDrawerItem(context, 'Images', 'assets/gallery.png', '/ImageStreamScreen'),
              _buildDrawerItem(context, 'Call Help', 'assets/call.png', '/CallHelpScreen', isRed: true),
              _buildDrawerItem(context, 'Logout', 'assets/logout.png', '', isLogout: true),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Divider(color: Colors.grey[200], thickness: 2, height: 1),
              SizedBox(height: 20),
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey[400])),
            ],
          ),
        ),
        SizedBox(height: 5),
        ...items,
      ],
    );
  }

  Widget _buildDrawerItem(BuildContext context, String title, String asset, String route, {bool isMonitor = false, bool isAlarmLog = false, bool isAnalytics = false, bool isRed = false, bool isLogout = false}) {
    return ListTile(
      leading: Image.asset(asset, width: 40, height: 27, fit: BoxFit.contain),
      title: Text(title, style: TextStyle(color: isRed ? Colors.red : Color(0xFF494949), fontSize: 17, fontWeight: isRed || isLogout ? FontWeight.bold : FontWeight.normal)),
      onTap: () async {
        if (isNavigating) return; // Prevent multiple navigation attempts
        isNavigating = true;

        if (isMonitor) {
          final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
          if (deviceProvider.selectedProductCode != null) {
            await Navigator.pushNamed(context, '/MonitorScreen', arguments: deviceProvider.selectedProductCode!);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a device first.')));
          }
        } else if (isAlarmLog) {
          final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
          if (deviceProvider.selectedProductCode != null) {
            await Navigator.pushNamed(context, '/AlarmLogScreen', arguments: deviceProvider.selectedProductCode!);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a device first.')));
          }
        } else if (isAnalytics) {
          await Navigator.pushNamed(context, '/AnalyticsScreen');
        } else if (isLogout) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', false);
          await FirebaseAuth.instance.signOut();
          Navigator.of(context).pushReplacementNamed('/LoginScreen');
        } else if (route.isNotEmpty) {
          await Navigator.pushNamed(context, route);
        }

        isNavigating = false; // Reset the flag after navigation
      },
    );
  }
}