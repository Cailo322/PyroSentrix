import 'package:flutter/material.dart';
import 'about.dart';
import 'custom_app_bar.dart';
import 'tutorial.dart';

class QueriesScreen extends StatefulWidget {
  @override
  _QueriesScreenState createState() => _QueriesScreenState();
}

class _QueriesScreenState extends State<QueriesScreen> {
  List<bool> _isExpanded = [false, false, false, false, false];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(),
      endDrawer: CustomDrawer(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Image.asset('assets/official-logo.png', height: 100),
                  SizedBox(width: 20),
                  Padding(
                    padding: const EdgeInsets.only(top: 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FAQs',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF494949),
                          ),
                        ),
                        SizedBox(height: 2),
                        Container(
                          width: 25,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Color(0xFF494949),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _buildSectionTitle('About PyroSentrix'),
              _buildListTile('assets/OL_NB_Black.png', 'About PyroSentrix'),
              _buildListTileWithIcon(Icons.phone_android, 'Video Tutorials'),
              SizedBox(height: 16),
              _buildSectionTitle('Often Asked Questions'),
              _buildFaqTile(0, 'How to setup the Iot device?'),
              _buildFaqTile(1, 'How does the alarm system works?'),
              _buildFaqTile(2, 'Can a single device be setup on multiple phones?'),
              _buildFaqTile(3, 'Can I add my other family members to connect to the Iot device?'),
              _buildFaqTile(4, 'Can I add another Iot device?'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF8D8D8D),
        ),
      ),
    );
  }

  Widget _buildListTile(String iconPath, String title) {
    return ListTile(
      leading: Image.asset(iconPath, height: 28, width: 28),
      title: Text(
        title,
        style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: Colors.black),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.black),
      onTap: () {
        if (title == 'About PyroSentrix') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AboutScreen()),
          );
        }
      },
    );
  }

  Widget _buildListTileWithIcon(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(
        title,
        style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: Colors.black),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.black),
      onTap: () {
        if (title == 'About PyroSentrix') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AboutScreen()),
          );
        } else if (title == 'Video Tutorials') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TutorialScreen()),
          );
        }
      },
    );
  }

  Widget _buildFaqTile(int index, String question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(Icons.question_answer, color: Colors.black),
          title: Text(
            question,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Colors.black),
          ),
          trailing: Icon(
            _isExpanded[index] ? Icons.expand_less : Icons.chevron_right,
            color: Colors.black,
          ),
          onTap: () {
            setState(() {
              _isExpanded[index] = !_isExpanded[index];
            });
          },
        ),
        if (_isExpanded[index])
          Padding(
            padding: const EdgeInsets.only(left: 60.0, right: 60.0, bottom: 16.0),
            child: Text(
              question == 'How does the alarm system works?'
                  ? '''Our alarm system consists of an IoT-enabled fire alarm device that connects directly to your mobile application. The device continuously monitors sensor values, including temperature, carbon monoxide (CO), smoke, humidity, and indoor air quality. These sensor readings are displayed in real-time on the Monitoring tab in your app.

If any of the sensors detect readings that exceed a safe threshold, the fire alarm device will trigger an alert, and your mobile app will sound an alarm as well. You'll also receive an immediate notification on your phone.

In case of an emergency, the app provides a list of nearby fire stations based on the address you've entered, so you can quickly contact them for assistance.

Stay safe!'''
                  : question == 'Can a single device be setup on multiple phones?'
                  ? '''Yes, you can use multiple phones to monitor your IoT device/fire alarm. Just login your same account that is connected to your Iot device.'''
                  : question == 'How to setup the Iot device?'
                  ? '''Go to the Add device screen, turn on your iot device, scan the qr code, and then connect it to your wifi.'''
                  : question == 'Can I add my other family members to connect to the Iot device?'
                  ? '''Yes. Just simply go to the Devices screen and click the three dots on the device card, and click add people and enter their registered email address.'''
                  : question == 'Can I add another Iot device?'
                  ? '''Yes just simple scan the qr code again and connect it your wifi, just make sure your are using the same account so the devices you are adding will reflect on the Devices screen'''
                  : 'Your content for this FAQ goes here.',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: Colors.black),
            ),
          ),
      ],
    );
  }
}