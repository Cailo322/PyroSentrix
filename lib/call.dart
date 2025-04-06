import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'custom_app_bar.dart';

class CallHelpScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 350;

    return Scaffold(
      appBar: CustomAppBar(),
      endDrawer: CustomDrawer(),
      body: SingleChildScrollView(
        child: Container(
          color: Colors.white,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.02,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(height: screenHeight * 0.01),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Image.asset(
                      'assets/official-logo.png',
                      height: screenHeight * 0.12,
                    ),
                    SizedBox(width: screenWidth * 0.04),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: screenHeight * 0.045),
                          child: Text(
                            'Call Help',
                            style: TextStyle(
                              color: Color(0xFF494949),
                              fontSize: isSmallScreen ? 24 : 30,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                        SizedBox(height: 2),
                        Container(
                          width: 30,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Color(0xFF494949),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.02),
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.06),
                  margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 4,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'Fire Stations Near You',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 18 : 20,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF494949),
                                fontFamily: 'Jost',
                              ),
                            ),
                            SizedBox(height: 2),
                            Container(
                              height: 2,
                              width: 20,
                              color: Color(0xFF494949),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.03),
                      FutureBuilder<DocumentSnapshot>(
                        future: _getUserData(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text('Error loading data'));
                          }
                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return Center(child: Text('No fire stations available'));
                          }

                          List<dynamic> fireStations = snapshot.data!['fire_stations'] ?? [];

                          return Column(
                            children: fireStations.map((station) {
                              dynamic contacts = station['contact'];
                              List<String> contactList = [];

                              if (contacts is String) {
                                contactList = [contacts];
                              } else if (contacts is List) {
                                contactList = List<String>.from(contacts);
                              } else {
                                contactList = ['Not available'];
                              }

                              return Column(
                                children: [
                                  _buildFireStationInfo(
                                    station['name'] ?? 'No Name',
                                    contactList,
                                    station['address'] ?? 'No Address',
                                    station['distance_km'] ?? 'N/A',
                                    station['duration'] ?? 'N/A',
                                    screenWidth,
                                    screenHeight,
                                    isSmallScreen,
                                  ),
                                ],
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<DocumentSnapshot> _getUserData() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance.collection('users').doc(userId).get();
  }

  Widget _buildFireStationInfo(
      String name,
      List<String> contacts,
      String address,
      String distance,
      String duration,
      double screenWidth,
      double screenHeight,
      bool isSmallScreen,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          name,
          style: TextStyle(
            fontSize: isSmallScreen ? 15 : 17,
            fontWeight: FontWeight.w500,
            color: Color(0xFF494949),
            fontFamily: 'Jost',
          ),
        ),
        SizedBox(height: screenHeight * 0.02),
        Padding(
          padding: const EdgeInsets.only(left: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: contacts.map((phone) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: GestureDetector(
                  onTap: () => _makePhoneCall(phone),
                  child: Row(
                    children: <Widget>[
                      Image.asset('assets/chcall.png', width: 20, height: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          phone,
                          style: TextStyle(
                            fontFamily: 'Jost',
                            color: Colors.red,
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: screenHeight * 0.015),
        Padding(
          padding: const EdgeInsets.only(left: 10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Opacity(
                opacity: 0.5,
                child: Image.asset('assets/chlocation.png', width: 20, height: 20),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: TextStyle(
                    fontFamily: 'Jost',
                    fontSize: isSmallScreen ? 14 : 16,
                  ),
                  overflow: TextOverflow.visible,
                  maxLines: 3,
                  softWrap: true,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: screenHeight * 0.01),
        Padding(
          padding: const EdgeInsets.only(left: 7.0),
          child: Row(
            children: <Widget>[
              Icon(Icons.access_time, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                '$distance km ($duration)',
                style: TextStyle(
                  fontFamily: 'Jost',
                  fontSize: isSmallScreen ? 14 : 16,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: screenHeight * 0.01),
        _buildShorterDivider(),
      ],
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber == 'Not available') return;

    final formattedPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: formattedPhoneNumber,
    );
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      throw 'Could not launch $phoneNumber';
    }
  }

  Widget _buildShorterDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.only(bottom: 8),
        width: 35,
      ),
    );
  }
}