import 'package:flutter/material.dart';
import 'custom_app_bar.dart'; // Import your custom app bar

class AboutScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background
      appBar: CustomAppBar(), // Custom app bar
      endDrawer: CustomDrawer(), // Custom drawer
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with logo and title
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Image.asset('assets/official-logo.png', height: 100), // Logo
                  SizedBox(width: 16), // Space between logo and text
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 35), // Add extra space to push the title lower
                      Text(
                        'About',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF494949),
                        ),
                      ),
                      SizedBox(height: 2), // Minimal spacing between text and underline
                      Container(
                        width: 25, // Fixed width for underline
                        height: 4, // Height of underline
                        decoration: BoxDecoration(
                          color: Color(0xFF494949), // Solid color for underline
                          borderRadius: BorderRadius.circular(4), // Rounded corners
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 24),
              // Section Title
              Center(),
              SizedBox(height: 3),
              // First Image (Centered and Rounded)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20), // Rounded corners
                  child: Image.asset(
                    'assets/Header1.png',
                    fit: BoxFit.cover,
                    width: MediaQuery.of(context).size.width * 10, // Responsive width
                    height: MediaQuery.of(context).size.height * 0.2, // Responsive height
                  ),
                ),
              ),
              SizedBox(height: 30),
              // Descriptive Text with Enlarged Second Image
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text Column
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PyroSentrix is an IoT-based fire monitoring system with a mobile app designed to enhance household safety. It uses multiple sensors to detect fire hazards like smoke, temperature spikes, and poor air quality, providing real-time alerts.\n\n'
                              'Beyond instant alarms, PyroSentrix features AI-driven sensor reading predictions for smarter prevention. With its user-friendly app, homeowners can monitor their environment anytime, ensuring a safer living space.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            color: Color(0xFF494949),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16), // Space between text and image
                  // Second Image (Rounded and Larger)
                  Expanded(
                    flex: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20), // Rounded corners
                      child: Image.asset(
                        'assets/About-pic1.jpg',
                        fit: BoxFit.cover,
                        width: MediaQuery.of(context).size.width * 0.70, // Increased width (greater percentage)
                        height: MediaQuery.of(context).size.width * 0.70, // Maintain aspect ratio
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 30),
              // Line divider before new contents
              Divider(
                color: Color(0xFFC54B00),
                thickness: 2,
              ),
              SizedBox(height: 16),
              // Additional Content: Firemonitor.png (First New Section)
              Center(
                child: Image.asset(
                  'assets/Firemonitor.png',
                  height: 100, // Adjust height as needed
                ),
              ),
              SizedBox(height: 16),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Real-time and effortless monitoring of six sensor values from the IoT device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      color: Color(0xFF494949),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Divider(
                color: Color(0xFFC54B00),
                thickness: 2,
              ),
              SizedBox(height: 16),
              // Additional Content: Alarm.png
              Center(
                child: Image.asset(
                  'assets/Alarm.png',
                  height: 100, // Adjust height as needed
                ),
              ),
              SizedBox(height: 16),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Instant alarm notifications when sensor values exceed predefined thresholds on both the mobile application and IoT device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      color: Color(0xFF494949),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Divider(
                color: Color(0xFFC54B00),
                thickness: 2,
              ),
              SizedBox(height: 16),
              // Additional Content: firestation.png
              Center(
                child: Image.asset(
                  'assets/firestation.png',
                  height: 100, // Adjust height as needed
                ),
              ),
              SizedBox(height: 16),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Displays the two nearest fire stations based on your location using Google Maps and Google Places API.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      color: Color(0xFF494949),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Divider(
                color: Color(0xFFC54B00),
                thickness: 2,
              ),
              SizedBox(height: 16),
              // Additional Content: Firemonitor.png (Second New Section)
              Center(
                child: Image.asset(
                  'assets/insight.png',
                  height: 100, // Adjust height as needed
                ),
              ),
              SizedBox(height: 16),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Integrated with the LSTM algorithm, PyroSentrix predicts rising sensor trends over the next 40 seconds, providing early notifications to keep users aware of potential risks.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: Color(0xFF494949),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}