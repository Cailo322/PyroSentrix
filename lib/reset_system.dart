import 'dart:async'; // Import Timer
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'notification_service.dart'; // Import the NotificationService

class ResetSystemScreen extends StatelessWidget {
  final String productCode; // Add productCode parameter
  final NotificationService _notificationService = NotificationService(); // Instance of NotificationService
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance
  ResetSystemScreen({required this.productCode}); // Update constructor

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
                  _showCountdownDialog(context); // Show the countdown dialog
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

  // Show a countdown dialog
  void _showCountdownDialog(BuildContext context) {
    int countdown = 5; // Start countdown from 5 seconds

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing the dialog by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Resetting System"),
          content: Text("The application and fire alarm will reset in $countdown seconds."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text("CANCEL"),
            ),
          ],
        );
      },
    );

    // Start the countdown timer
    Timer.periodic(Duration(seconds: 1), (Timer timer) async {
      if (countdown > 0) {
        // Update the dialog content
        Navigator.of(context).pop(); // Close the current dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Resetting System"),
              content: Text("The application and fire alarm will reset in $countdown seconds."),
              actions: [
                TextButton(
                  onPressed: () {
                    timer.cancel(); // Stop the timer
                    Navigator.of(context).pop(); // Close the dialog
                  },
                  child: Text("CANCEL"),
                ),
              ],
            );
          },
        );
        countdown--;
      } else {
        timer.cancel(); // Stop the timer
        Navigator.of(context).pop(); // Close the dialog

        // Perform reset actions
        _resetNotifications();
        _resetHushedStatus();
        _resetAlarmLoggingStatus(); // Reset the alarm logging status in Firestore
        _resetDialogStatus(); // Reset the Dialogpop field in DialogStatus collection
        _resetNotifStatus(); // Reset the notif field in NotifStatus collection

        // Restart the app on Android
        SystemNavigator.pop(); // Closes the app on Android
      }
    });
  }

  // Reset the acknowledged alerts in NotificationService
  void _resetNotifications() {
    _notificationService.acknowledgeAlerts(); // Reset acknowledged alerts
  }

  // Update isHushed in Firestore
  void _resetHushedStatus() async {
    DocumentReference alarmRef = _firestore.collection('BooleanConditions').doc('Alarm');

    try {
      // Fetch the current value of isHushed
      DocumentSnapshot docSnapshot = await alarmRef.get();
      if (docSnapshot.exists) {
        bool isHushed = docSnapshot.get('isHushed');

        // Only update if isHushed is true
        if (isHushed) {
          await alarmRef.update({'isHushed': false});
          print("isHushed reset to false");
        } else {
          print("isHushed is already false, no update needed.");
        }
      }
    } catch (e) {
      print("Error updating isHushed: $e");
    }
  }

  // Reset the alarm logging status in Firestore
  void _resetAlarmLoggingStatus() async {
    try {
      // Reset the 'logged' field to false for all alarms in SensorData > AlarmLogs > {productCode}
      var snapshot = await _firestore
          .collection('SensorData')
          .doc('AlarmLogs')
          .collection(productCode) // Use the passed productCode
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.update({'logged': false});
      }
      print("All 'logged' fields reset to false in SensorData > AlarmLogs > $productCode.");

      // Reset AlarmLogged for HpLk33atBI
      await _firestore
          .collection('AlarmStatus')
          .doc('HpLk33atBI')
          .update({'AlarmLogged': false});
      print("AlarmLogged reset to false for HpLk33atBI.");

      // Reset AlarmLogged for oURnq0vZrP
      await _firestore
          .collection('AlarmStatus')
          .doc('oURnq0vZrP')
          .update({'AlarmLogged': false});
      print("AlarmLogged reset to false for oURnq0vZrP.");
    } catch (e) {
      print("Error resetting alarm logging status: $e");
    }
  }

  // Reset the Dialogpop field in DialogStatus collection
  void _resetDialogStatus() async {
    try {
      // Reset Dialogpop for HpLk33atBI
      await _firestore
          .collection('DialogStatus')
          .doc('HpLk33atBI')
          .update({'Dialogpop': false});
      print("Dialogpop reset to false for HpLk33atBI.");

      // Reset Dialogpop for oURnq0vZrP
      await _firestore
          .collection('DialogStatus')
          .doc('oURnq0vZrP')
          .update({'Dialogpop': false});
      print("Dialogpop reset to false for oURnq0vZrP.");
    } catch (e) {
      print("Error resetting Dialogpop: $e");
    }
  }

  // Reset the notif field in NotifStatus collection
  void _resetNotifStatus() async {
    try {
      // Reset the notif field for the specific productCode
      await _firestore
          .collection('NotifStatus')
          .doc(productCode)
          .update({'notif': false});
      print("notif reset to false for $productCode.");
    } catch (e) {
      print("Error resetting notif field: $e");
    }
  }
}