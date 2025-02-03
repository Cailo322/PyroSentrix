import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  final Size preferredSize;

  CustomAppBar({Key? key})
      : preferredSize = Size.fromHeight(kToolbarHeight),
        super(key: key);

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
  @override
  _CustomDrawerState createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  String? userName;

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
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(width: 8),
                      Text(
                        'Menu',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey,
                              child: Icon(
                                Icons.person,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              userName ?? 'Loading...',
                              style: TextStyle(
                                fontSize: 20,
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
            ListTile(
              leading: Image.asset(
                'assets/add1.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
              title: Text('Add Device',
                  style: TextStyle(color: Color(0xFF494949), fontSize: 18)),
              onTap: () {
                Navigator.pushNamed(context, '/AddDeviceScreen');
              },
            ),
            ListTile(
              leading: Image.asset(
                'assets/setthreshold.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
              title: Text('System Reset',
                  style: TextStyle(color: Color(0xFF494949), fontSize: 18)),
              onTap: () {
                Navigator.pushNamed(context, '/ResetSystemScreen');
              },
            ),
            ListTile(
              leading: Image.asset(
                'assets/analytics.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
              title: Text('Analytics',
                  style: TextStyle(color: Color(0xFF494949), fontSize: 18)),
              onTap: () {
                // Handle navigation
              },
            ),
            ListTile(
              leading: Image.asset(
                'assets/monitoring.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
              title: Text('Monitoring',
                  style: TextStyle(color: Color(0xFF494949), fontSize: 18)),
              onTap: () {
                Navigator.pushNamed(context, '/MonitorScreen');
              },
            ),
            ListTile(
              leading: Image.asset(
                'assets/queries.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
              title: Text('Queries',
                  style: TextStyle(color: Color(0xFF494949), fontSize: 18)),
              onTap: () {
                Navigator.pushNamed(context, '/QueriesScreen');
              },
            ),
            ListTile(
              leading: Image.asset(
                'assets/call.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
              title: Text(
                'Call Help',
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
              onTap: () {
                Navigator.pushNamed(context, '/CallHelpScreen');
              },
            ),
            ListTile(
              leading: Image.asset(
                'assets/devices.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
              title: Text('Devices',
                  style: TextStyle(color: Color(0xFF494949), fontSize: 18)),
              onTap: () {
                Navigator.pushNamed(context, '/DevicesScreen');
              },
            ),
            ListTile(
              leading: Image.asset(
                'assets/gallery.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
              title: Text('Images',
                  style: TextStyle(color: Color(0xFF494949), fontSize: 18)),
              onTap: () {
                Navigator.pushNamed(context, '/ImageStreamScreen');
              },
            ),
            ListTile(
              leading: Image.asset(
                'assets/logout.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
              title: Text(
                'Logout',
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
              onTap: () async {
                try {
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).pop();
                  Navigator.of(context)
                      .pushReplacementNamed('/LoginScreen');
                } catch (e) {
                  print('Logout error: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Logout failed. Please try again.'),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
