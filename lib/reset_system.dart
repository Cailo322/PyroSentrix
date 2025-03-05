import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'notification_service.dart'; // Import the NotificationService

class ResetSystemScreen extends StatelessWidget {
  final NotificationService _notificationService = NotificationService(); // Instance of NotificationService

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.grey[300], // Gray background for the app bar
        elevation: 0, // Removes the shadow
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20), // Adding margins from left and right
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start, // Align content to the top
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Enlarged reset.png icon at the top, moved higher
              Padding(
                padding: const EdgeInsets.only(top: 150, bottom: 20), // Add some top padding and reduce bottom padding
                child: Image.asset('assets/reset.png', width: 150, height: 150),
              ),

              // Information text with justified alignment
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 600), // Restrict the width for better readability
                  child: Text.rich(
                    TextSpan(
                      text:
                      'The Pyrosentrix app features a management system that prevents redundant alert notifications when the fire alarm is triggered. This ensures that your mobile device won\'t receive repetitive alerts or alarms during an emergency.\n\nAlert management begins when you click either the ',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'Jost', // Use Jost font family
                        fontWeight: FontWeight.w500, // Normal font weight for body text
                        color: Color(0xFF414141),
                      ),
                      children: [
                        TextSpan(
                          text: 'HUSH',
                          style: TextStyle(
                            fontWeight: FontWeight.bold, // Make HUSH bold
                          ),
                        ),
                        TextSpan(
                          text: ' or ',
                        ),
                        TextSpan(
                          text: 'CALL FIRESTATION',
                          style: TextStyle(
                            fontWeight: FontWeight.bold, // Make CALL FIRESTATION bold
                          ),
                        ),
                        TextSpan(
                          text:
                          ' button, confirming the notification alert. Once confirmed, you will not receive the same notification again until it is reset.\n\nTo restart the system, simply click the reset button, which will refresh the notification and alarm system, ensuring it operates from that point forward.',
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center, // Center the text
                  ),
                ),
              ),

              // Reset button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // Red background
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  _resetNotifications();

                  // Restart the app on Android
                  SystemNavigator.pop(); // Closes the app on Android
                },
                child: Text(
                  'RESET',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Reset the acknowledged alerts in NotificationService
  void _resetNotifications() {
    _notificationService.acknowledgeAlerts(); // Reset acknowledged alerts
  }
}
