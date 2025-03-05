import 'package:flutter/material.dart';
import 'about.dart'; // Import the AboutScreen here
import 'custom_app_bar.dart'; // Import your custom app bar here

class QueriesScreen extends StatefulWidget {
  @override
  _QueriesScreenState createState() => _QueriesScreenState();
}

class _QueriesScreenState extends State<QueriesScreen> {
  // Manage the expanded state for each item
  List<bool> _isExpanded = [false, false, false];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Set the background color to white
      appBar: CustomAppBar(), // Use the updated custom app bar
      endDrawer: CustomDrawer(), // Add the custom drawer here
      body: SingleChildScrollView(  // Use SingleChildScrollView to make the entire body scrollable
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column( // Change ListView to Column inside SingleChildScrollView
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Image.asset('assets/official-logo.png', height: 100), // Logo size from CallHelpScreen
                  SizedBox(width: 20), // Space between logo and text
                  Padding(
                    padding: const EdgeInsets.only(top: 36), // Align text similar to CallHelpScreen
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FAQs',
                          style: TextStyle(
                            fontFamily: 'Poppins', // Use Poppins font
                            fontSize: 30, // Title size from CallHelpScreen
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF494949), // Text color
                          ),
                        ),
                        SizedBox(height: 2),
                        Container(
                          width: 25, // Width of the underline
                          height: 4, // Height of the underline
                          decoration: BoxDecoration(
                            color: Color(0xFF494949), // Color of the underline
                            borderRadius: BorderRadius.circular(2), // Rounded corners for the underline
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16), // Space between logo-title and the list
              _buildSectionTitle('About PyroSentrix'),
              _buildListTile('assets/OL_NB_Black.png', 'About PyroSentrix'), // Using the OL_NB_Black for About PyroSentrix
              _buildListTileWithIcon(Icons.phone_android, 'Application Features'), // Restoring the phone icon for Application Features
              SizedBox(height: 16),
              _buildSectionTitle('Often Asked Questions'),
              _buildFaqTile(0, 'How to setup the device?'),
              _buildFaqTile(1, 'How does the alarm system works?'),
              _buildFaqTile(2, 'Can a single device be setup on multiple phones?'),
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
          fontFamily: 'Poppins', // Use Poppins Bold for section titles
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF8D8D8D), // Updated color code
        ),
      ),
    );
  }

  // Updated method for list tile with image
  Widget _buildListTile(String iconPath, String title) {
    return ListTile(
      leading: Image.asset(iconPath, height: 28, width: 28), // Use image for "About PyroSentrix"
      title: Text(
        title,
        style: TextStyle(
            fontFamily: 'Poppins', // Use Poppins SemiBold for dropdown titles
            fontWeight: FontWeight.w600,
            color: Colors.black), // Ensure text is black
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.black), // Ensure trailing icon is black
      onTap: () {
        if (title == 'About PyroSentrix') {
          // Navigate to AboutScreen when About PyroSentrix is tapped
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AboutScreen()), // Navigate to AboutScreen
          );
        }
      },
    );
  }

  // Updated method for list tile with icon (Application Features)
  Widget _buildListTileWithIcon(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.black), // Ensure icons are black
      title: Text(
        title,
        style: TextStyle(
            fontFamily: 'Poppins', // Use Poppins SemiBold for dropdown titles
            fontWeight: FontWeight.w600,
            color: Colors.black), // Ensure text is black
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.black), // Ensure trailing icon is black
      onTap: () {
        if (title == 'About PyroSentrix') {
          // Navigate to AboutScreen when About PyroSentrix is tapped
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AboutScreen()), // Navigate to AboutScreen
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
          leading: Icon(Icons.question_answer, color: Colors.black), // Ensure icon is black
          title: Text(
            question,
            style: TextStyle(
                fontFamily: 'Poppins', // Use Poppins SemiBold for FAQ titles
                fontWeight: FontWeight.w600,
                color: Colors.black), // Ensure text is black
          ),
          trailing: Icon(
            _isExpanded[index] ? Icons.expand_less : Icons.chevron_right,
            color: Colors.black, // Ensure trailing icon is black
          ),
          onTap: () {
            setState(() {
              _isExpanded[index] = !_isExpanded[index]; // Toggle expanded state
            });
          },
        ),
        if (_isExpanded[index])
          Padding(
            padding: const EdgeInsets.only(left: 60.0, right: 60.0, bottom: 16.0), // Added both left and right right padding
            child: Text(
              question == 'How does the alarm system works?'
                  ? '''Our alarm system consists of an IoT-enabled fire alarm device that connects directly to your mobile application. The device continuously monitors sensor values, including temperature, carbon monoxide (CO), smoke, humidity, and indoor air quality. These sensor readings are displayed in real-time on the Monitoring tab in your app.

If any of the sensors detect readings that exceed a safe threshold, the fire alarm device will trigger an alert, and your mobile app will sound an alarm as well. You'll also receive an immediate notification on your phone.

In case of an emergency, the app provides a list of nearby fire stations based on the address you've entered, so you can quickly contact them for assistance.

Stay safe!'''
                  : question == 'Can a single device be setup on multiple phones?'
                  ? '''Yes, you can use multiple phones to monitor your IoT device/fire alarm. Simply ensure that each phone is registered and the product code for the fire alarm is entered. This way, all linked phones will have access to the device’s data and alerts.'''
                  : 'Your content for this FAQ goes here.', // Add other FAQ content if needed
              style: TextStyle(
                  fontFamily: 'Poppins', // Use Poppins Light for dropdown content
                  fontWeight: FontWeight.w500, // Set text weight to w500
                  fontSize: 14,
                  color: Colors.black), // Content text color changed to black
            ),
          ),
      ],
    );
  }
}
