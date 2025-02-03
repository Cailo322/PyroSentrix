import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart'; // Add this import
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import
import 'package:esp_smartconfig/esp_smartconfig.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'custom_app_bar.dart';

class AddDeviceScreen extends StatefulWidget {
  @override
  _AddDeviceScreenState createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance
  int _currentStep = 0; // Stepper state
  String? _scannedMacAddress; // Scanned MAC address
  String? _scannedProductId; // Scanned Product ID
  final _ssidController = TextEditingController(); // Wi-Fi SSID
  final _passwordController = TextEditingController(); // Wi-Fi Password
  final _provisioner = Provisioner.espTouch(); // Provisioner instance
  bool _isProvisioning = false; // Track provisioning state

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
      _isProvisioning = true; // Start provisioning
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
        _isProvisioning = false; // End provisioning
      });
    }
  }

  Future<void> _saveActivationDetails() async {
    try {
      // Get the current user
      User? user = _auth.currentUser;
      if (user == null) {
        throw Exception("User not logged in");
      }

      // Get the current timestamp in the required format
      String timestamp = DateTime.now().toUtc().toIso8601String();

      // Save the activation details to Firestore
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
    // Save activation details to Firestore
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
                // Move to the fourth step after provisioning is complete
                setState(() {
                  _currentStep = 3; // Go to the summary step
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
      appBar: CustomAppBar(), // Retain the CustomAppBar
      endDrawer: CustomDrawer(), // Retain the CustomDrawer
      body: Stepper(
        type: StepperType.horizontal, // Horizontal stepper
        currentStep: _currentStep,
        onStepContinue: () async {
          if (_currentStep == 1 && _scannedMacAddress == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please scan the QR code first')),
            );
            return;
          }
          if (_currentStep == 2) {
            // Start provisioning on the third step
            await _startProvisioning();
            return; // Wait for provisioning to complete
          }
          if (_currentStep < 3) {
            setState(() => _currentStep += 1);
          } else if (_currentStep == 3) {
            // Navigate to devices.dart on the fourth step
            debugPrint("Navigating to /DevicesScreen"); // Debug statement
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
                    if (_currentStep != 3) // Hide Cancel button on the fourth step
                      ElevatedButton(
                        onPressed: details.onStepCancel,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    if (_currentStep != 3) const SizedBox(width: 20),
                    ElevatedButton(
                      onPressed: _isProvisioning ? null : details.onStepContinue, // Disable button during provisioning
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA80000),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(_currentStep == 3 ? 'Done' : 'Continue'),
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
            title: const Text(''), // Empty title to only show the step number
            content: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Instructions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '1. Turn on the fire alarm and ensure that it is near your mobile device during provisioning.\n\n'
                        '2. Scan the QR code that is located on your fire alarm or user manual.\n\n'
                        '3. Enter your network\'s SSID and Password.',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.left,
                  ),
                ],
              ),
            ),
          ),
          // Step 2: QR Code Scanning
          Step(
            title: const Text(''), // Empty title to only show the step number
            content: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Scan QR Code',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 200,
                    width: 200,
                    child: MobileScanner(
                      onDetect: (BarcodeCapture barcodeCapture) {
                        final barcodes = barcodeCapture.barcodes;
                        if (barcodes.isNotEmpty) {
                          final data = barcodes.first.rawValue;
                          if (data != null && data.contains('-')) {
                            final parts = data.split('-');
                            setState(() {
                              _scannedMacAddress = parts[0];
                              _scannedProductId = parts[1];
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Scanned MAC: $_scannedMacAddress')),
                            );
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
                    Text('MAC: $_scannedMacAddress\nProduct ID: $_scannedProductId'),
                ],
              ),
            ),
          ),
          // Step 3: Wi-Fi Provisioning
          Step(
            title: const Text(''), // Empty title to only show the step number
            content: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Wi-Fi Provisioning',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 300,
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'SSID (Network name)',
                      ),
                      controller: _ssidController,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 300,
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Password',
                      ),
                      obscureText: true,
                      controller: _passwordController,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Step 4: Summary
          Step(
            title: const Text(''), // Empty title to only show the step number
            content: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Summary',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'MAC Address: $_scannedMacAddress',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Product Code: $_scannedProductId',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'SSID: ${_ssidController.text}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
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