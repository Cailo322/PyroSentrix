import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esp_smartconfig/esp_smartconfig.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'custom_app_bar.dart';

class AddDeviceScreen extends StatefulWidget {
  @override
  _AddDeviceScreenState createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _currentStep = 0;
  String? _scannedMacAddress;
  String? _scannedProductId;
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _provisioner = Provisioner.espTouch();
  bool _isProvisioning = false;
  bool _isToastShown = false; // Add this flag


  void _checkUser(BuildContext context) {
    User? user = _auth.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/LoginScreen');
    }
  }

  Future<void> _startProvisioning() async {
    if (_scannedMacAddress == null || _scannedMacAddress!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan a valid QR code.')),
      );
      return;
    }

    setState(() {
      _isProvisioning = true;
    });

    _provisioner.listen((response) {
      Navigator.of(context).pop(response);
    });

    try {
      _provisioner.start(ProvisioningRequest.fromStrings(
        ssid: _ssidController.text,
        bssid: _scannedMacAddress!,
        password: _passwordController.text,
      ));

      ProvisioningResponse? response = await showDialog<ProvisioningResponse>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Provisioning'),
            content: const Text('Provisioning started. Please wait...'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Stop'),
              ),
            ],
          );
        },
      );

      if (_provisioner.running) {
        _provisioner.stop();
      }

      if (response != null) {
        _onDeviceProvisioned(response);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during provisioning: $e')),
      );
    } finally {
      setState(() {
        _isProvisioning = false;
      });
    }
  }

  Future<void> _saveActivationDetails() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        throw Exception("User not logged in");
      }

      String timestamp = DateTime.now().toUtc().toIso8601String();

      await _firestore.collection('ProductActivation').add({
        'mac_address': _scannedMacAddress,
        'product_code': _scannedProductId,
        'user_email': user.email,
        'timestamp': timestamp,
      });

      debugPrint("Activation details saved to Firestore");
    } catch (e) {
      debugPrint("Error saving activation details: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving activation details: $e')),
      );
    }
  }

  void _onDeviceProvisioned(ProvisioningResponse response) async {
    await _saveActivationDetails();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Device provisioned'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Device successfully connected to the ${_ssidController.text} network',
              ),
              const SizedBox(height: 20),
              const Text('Device:'),
              Text('IP: ${response.ipAddressText}'),
              Text('BSSID: ${response.bssidText}'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _currentStep = 3;
                });
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _checkUser(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(),
      endDrawer: CustomDrawer(),
      body: Stepper(
          type: StepperType.horizontal,
          currentStep: _currentStep,
          onStepContinue: () async {
            if (_currentStep == 1 && _scannedMacAddress == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please scan the QR code first')),
              );
              return;
            }
            if (_currentStep == 2) {
              await _startProvisioning();
              return;
            }
            if (_currentStep < 3) {
              setState(() => _currentStep += 1);
            } else if (_currentStep == 3) {
              Navigator.pushReplacementNamed(context, '/DevicesScreen');
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep -= 1);
            }
          },
          controlsBuilder: (BuildContext context, ControlsDetails details) {
            return Center(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_currentStep != 3)
                        ElevatedButton(
                          onPressed: details.onStepCancel,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20), // Oval shape
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Cancel'),
                        ),
                      if (_currentStep != 3) const SizedBox(width: 20),
                      ElevatedButton(
                        onPressed: _isProvisioning ? null : details.onStepContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFDE59), // Consistent button color
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20), // Oval shape
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text(
                          _currentStep == 3 ? 'Done' : 'Continue',
                          style: TextStyle(
                            fontFamily: 'Jost', // Consistent font
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          steps: [
      // Step 1: Instructions
      Step(
      title: const Text(''),
      content: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Instructions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Jost', // Consistent font
                color: Color(0xFF494949), // Consistent text color
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '1. Turn on the fire alarm and ensure that it is near your mobile device during provisioning.\n\n'
                  '2. Scan the QR code that is located on your fire alarm or user manual.\n\n'
                  '3. Enter your network\'s SSID and Password.',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Jost', // Consistent font
                color: Color(0xFF494949), // Consistent text color
              ),
              textAlign: TextAlign.left,
            ),
          ],
        ),
      ),
    ),
    // Step 2: QR Code Scanning
    Step(
    title: const Text(''),
    content: Center(
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
    const Text(
    'Scan QR Code',
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    fontFamily: 'Jost', // Consistent font
    color: Color(0xFF494949), // Consistent text color
    ),
    ),
    const SizedBox(height: 10),
      SizedBox(
        height: 200,
        width: 200,
        child: MobileScanner(
          onDetect: (BarcodeCapture barcodeCapture) {
            if (_isToastShown) return; // Do not show toast again if already shown

            final barcodes = barcodeCapture.barcodes;
            if (barcodes.isNotEmpty) {
              final data = barcodes.first.rawValue;
              if (data != null && data.contains('-')) {
                final parts = data.split('-');
                setState(() {
                  _scannedMacAddress = parts[0];
                  _scannedProductId = parts[1];
                });

                // Show toast only once
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Scanned MAC: $_scannedMacAddress'),
                    duration: const Duration(seconds: 3), // Show for 3 seconds
                  ),
                );

                // Set the flag to true to prevent further toasts
                _isToastShown = true;
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid QR code format')),
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No barcode detected')),
              );
            }
          },
        ),
      ),
    if (_scannedMacAddress != null)
    Text(
    'MAC: $_scannedMacAddress\nProduct ID: $_scannedProductId',
    style: TextStyle(
    fontFamily: 'Jost', // Consistent font
    color: Color(0xFF494949), // Consistent text color
    ),
    ),
    ],
    ),
    ),
    ),
    // Step 3: Wi-Fi Provisioning
    Step(
    title: const Text(''),
    content: Center(
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
    const Text(
    'Wi-Fi Provisioning',
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    fontFamily: 'Jost', // Consistent font
    color: Color(0xFF494949), // Consistent text color
    ),
    ),
    const SizedBox(height: 10),
    _buildTextInput('SSID (Network name)', _ssidController),
    const SizedBox(height: 10),
    _buildTextInput('Password', _passwordController, obscureText: true),
    ],
    ),
    ),
    ),
// Step 4: Summary
    Step(
    title: const Text(''),
    content: Center(
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
    const Text(
    'Summary',
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    fontFamily: 'Jost', // Consistent font
    color: Color(0xFF494949), // Consistent text color
    ),
    ),
    const SizedBox(height: 20),
    Text(
    'MAC Address: $_scannedMacAddress',
    style: TextStyle(
    fontSize: 16,
    fontFamily: 'Jost', // Consistent font
    color: Color(0xFF494949), // Consistent text color
    ),
    ),
    const SizedBox(height: 10),
    Text(
    'Product Code: $_scannedProductId',
    style: TextStyle(
    fontSize: 16,
    fontFamily: 'Jost', // Consistent font
    color: Color(0xFF494949), // Consistent text color
    ),
    ),
    const SizedBox(height: 10),
    Text(
    'SSID: ${_ssidController.text}',
    style: TextStyle(
    fontSize: 16,
    fontFamily: 'Jost', // Consistent font
    color: Color(0xFF494949), // Consistent text color
    ),
    ),
    ],
    ),
    ),
    ),
    ],
    ),
    );
  }

  Widget _buildTextInput(String labelText, TextEditingController controller, {bool obscureText = false}) {
    return Container(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelText,
            style: TextStyle(
              fontFamily: 'Jost', // Consistent font
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF494949), // Consistent text color
              shadows: [
                Shadow(
                  blurRadius: 3,
                  color: Colors.black.withOpacity(0.2),
                  offset: Offset(1, 1),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Color(0xFFDDDDDD), // Consistent input field background
              borderRadius: BorderRadius.circular(5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _provisioner.stop();
    super.dispose();
  }
}