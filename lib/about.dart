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
                  Image.asset('assets/flashlogo.png', height: 100), // Logo
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
                        width: 33, // Fixed width for underline
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
              Center(
                child: Text(
                  'Introduction to Pyrosentrix',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF494949),
                  ),
                ),
              ),
              SizedBox(height: 16),
              // First Image (Centered and Rounded)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20), // Rounded corners
                  child: Image.asset(
                    'assets/aboutpic1.png',
                    fit: BoxFit.cover,
                    width: MediaQuery.of(context).size.width * 0.9, // Responsive width
                  ),
                ),
              ),
              SizedBox(height: 16),
              // Descriptive Text with Enlarged Second Image
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text Column
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PyroSentrix is focused on enhancing fire safety through advanced IoT solutions.\n\n'
                              'Our multi-sensor fire detection system, integrated with a mobile app, provides real-time monitoring and alerts from a network of flame sensors.\n\n'
                              'By leveraging cutting-edge technology, PyroSentrix ensures prompt and accurate fire detection, safeguarding lives and property. Our commitment to innovation makes PyroSentrix a leader in the fire safety industry.',
                          style: TextStyle(
                            fontFamily: 'Jost',
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
                        'assets/aboutpic2.png',
                        fit: BoxFit.cover,
                        width: MediaQuery.of(context).size.width * 0.70, // Increased width (greater percentage)
                        height: MediaQuery.of(context).size.width * 0.67, // Maintain aspect ratio
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
