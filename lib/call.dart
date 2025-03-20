import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher package
import 'custom_app_bar.dart';

class CallHelpScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      endDrawer: CustomDrawer(),
      body: Container(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(height: 5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Image.asset('assets/official-logo.png', height: 100),
                  SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 36),
                        child: Text(
                          'Call Help',
                          style: TextStyle(
                            color: Color(0xFF494949),
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                      SizedBox(height: 2),
                      Container(
                        width: 30, // Width of the underline
                        height: 4, // Height of the underline
                        decoration: BoxDecoration(
                          color: Color(0xFF494949), // Color of the underline
                          borderRadius: BorderRadius.circular(2), // Rounded corners for the underline
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(25),
                margin: EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1), // Shadow color with some opacity
                      spreadRadius: 2, // How much the shadow spreads
                      blurRadius: 4, // How blurred the shadow is
                      offset: Offset(0, 4), // Horizontal and vertical offset of the shadow
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
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF494949),
                              fontFamily: 'Jost',
                            ),
                          ),
                          SizedBox(height: 2), // Space between title and underline
                          Container(
                            height: 2, // Thickness of the underline
                            width: 20, // Width of the underline
                            color: Color(0xFF494949), // Color of the underline
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30),
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
                            return Column(
                              children: [
                                _buildFireStationInfo(
                                  station['name'] ?? 'No Name',
                                  station['contact'] ?? 'No Contact',
                                  station['address'] ?? 'No Address',
                                  station['distance_km'] ?? 'N/A',
                                  station['duration'] ?? 'N/A',
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
    );
  }

  Future<DocumentSnapshot> _getUserData() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance.collection('users').doc(userId).get();
  }

  Widget _buildFireStationInfo(String name, String phone, String address, String distance, String duration) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Fire Station Name with increased space below
        Text(
          name,
          style: TextStyle(
            fontSize: 17, // Increased the font size for the fire station name
            fontWeight: FontWeight.w500,
            color: Color(0xFF494949),
            fontFamily: 'Jost',
          ),
        ),
        SizedBox(height: 20), // Increased space after the fire station name (adjusted this value)

        // Phone number with left padding of 10.0
        Padding(
          padding: const EdgeInsets.only(left: 10.0), // Set left padding for phone number
          child: GestureDetector(
            onTap: () => _makePhoneCall(phone),
            child: Row(
              children: <Widget>[
                Image.asset('assets/chcall.png', width: 20, height: 20), // Custom phone icon
                SizedBox(width: 8),
                Text(
                  phone,
                  style: TextStyle(
                    fontFamily: 'Jost',
                    color: Colors.red, // Make the number red to indicate it's clickable
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 11), // Increased space after the phone number

        // Address with left padding of 10.0
        Padding(
          padding: const EdgeInsets.only(left: 10.0), // Set left padding for address
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Opacity(
                opacity: 0.5, // Reduce the opacity of the location icon
                child: Image.asset('assets/chlocation.png', width: 20, height: 20), // Custom location icon
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: TextStyle(fontFamily: 'Jost'),
                  overflow: TextOverflow.visible,
                  maxLines: 3,
                  softWrap: true,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8), // Increased space after the address

        // Duration with left padding of 7.0
        Padding(
          padding: const EdgeInsets.only(left: 7.0), // Set left padding for duration
          child: Row(
            children: <Widget>[
              Icon(Icons.access_time, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                '$distance km ($duration)', // Adjusted format to remove the "Distance" and "Duration" text
                style: TextStyle(fontFamily: 'Jost'),
              ),
            ],
          ),
        ),
        SizedBox(height: 8), // Increased space after the duration
        _buildShorterDivider(), // The shorter divider
      ],
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final formattedPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), ''); // Remove non-numeric characters
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
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Reduced padding for closer alignment
      child: Container(
        height: 4, // Divider thickness
        decoration: BoxDecoration(
          color: Colors.grey.shade300, // Divider color
          borderRadius: BorderRadius.circular(10), // Rounded corners for the divider
        ),
        margin: const EdgeInsets.only(bottom: 8), // Space between divider and content
        width: 35, // Reduced width to make the divider shorter
      ),
    );
  }
}
