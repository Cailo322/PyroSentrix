import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esp_smartconfig/esp_smartconfig.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'custom_app_bar.dart';

class AddDeviceScreen extends StatefulWidget {
  @override
  _AddDeviceScreenState createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _currentStep = 0;
  String? _scannedMacAddress;
  String? _scannedProductId;
  final _passwordController = TextEditingController();
  final _manualSSIDController = TextEditingController();
  final _provisioner = Provisioner.espTouch();
  bool _isProvisioning = false;
  bool _isToastShown = false;
  bool _showManualSSIDInput = false;
  bool _showPasswordDialog = false;
  late AnimationController _animationController;
  bool _isQrScanned = false;

  // Wi-Fi scanning variables
  List<WiFiAccessPoint> _accessPoints = [];
  bool _isScanning = false;
  String? _selectedSSID;
  String? _selectedBSSID;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndStartScan();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _passwordController.dispose();
    _manualSSIDController.dispose();
    _provisioner.stop();
    super.dispose();
  }

  void _checkUser(BuildContext context) {
    User? user = _auth.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/LoginScreen');
    }
  }

  Future<bool> _checkPermissionsAndStartScan() async {
    final isLocationEnabled = await WiFiScan.instance.canGetScannedResults();
    if (isLocationEnabled == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable location services'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return false;
    }
    return _startScan();
  }

  Future<bool> _startScan() async {
    setState(() => _isScanning = true);
    try {
      final success = await WiFiScan.instance.startScan();
      if (success) {
        final accessPoints = await WiFiScan.instance.getScannedResults();
        setState(() => _accessPoints = accessPoints);
        return true;
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
      return false;
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _startProvisioning() async {
    if (_scannedMacAddress == null || _scannedMacAddress!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan a valid QR code.')),
      );
      return;
    }

    if (_selectedSSID == null || _selectedSSID!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Wi-Fi network.')),
      );
      return;
    }

    setState(() => _isProvisioning = true);

    _provisioner.listen((response) => Navigator.of(context).pop(response));

    try {
      _provisioner.start(ProvisioningRequest.fromStrings(
        ssid: _selectedSSID!,
        bssid: _scannedMacAddress!,
        password: _passwordController.text,
      ));

      ProvisioningResponse? response = await showDialog<ProvisioningResponse>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Provisioning'),
          content: const Text('Provisioning started. Please wait...'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Stop'),
            ),
          ],
        ),
      );

      if (_provisioner.running) _provisioner.stop();
      if (response != null) _onDeviceProvisioned(response);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during provisioning: $e')),
      );
    } finally {
      setState(() => _isProvisioning = false);
    }
  }

  Future<void> _saveActivationDetails() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      await _firestore.collection('ProductActivation').add({
        'mac_address': _scannedMacAddress,
        'product_code': _scannedProductId,
        'user_email': user.email,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving activation details: $e')),
      );
    }
  }

  void _onDeviceProvisioned(ProvisioningResponse response) async {
    await _saveActivationDetails();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Device provisioned'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Device successfully connected to the $_selectedSSID network'),
            const SizedBox(height: 20),
            const Text('Device:'),
            Text('IP: ${response.ipAddressText}'),
            Text('BSSID: ${response.bssidText}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _currentStep = 3);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPasswordInputDialog() {
    setState(() {
      _showPasswordDialog = true;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter password for $_selectedSSID',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() {
                      _showPasswordDialog = false;
                    });
                    await _startProvisioning();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFDE59),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Submit'),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      setState(() {
        _showPasswordDialog = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    _checkUser(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(),
      endDrawer: CustomDrawer(),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: const Color(0xFFFFDE59),
          ),
          canvasColor: Colors.white,
        ),
        child: Builder(
          builder: (context) {
            return Stepper(
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
                  return;
                }
                if (_currentStep < 3) {
                  setState(() => _currentStep += 1);
                } else if (_currentStep == 3) {
                  Navigator.pushReplacementNamed(context, '/DevicesScreen');
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) setState(() => _currentStep -= 1);
              },
              controlsBuilder: (BuildContext context, ControlsDetails details) {
                if (_currentStep == 2) return const SizedBox.shrink();

                return Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_currentStep != 3)
                            TextButton(
                              onPressed: details.onStepCancel,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(color: Color(0xFFD9D9D9)),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                          if (_currentStep != 3) const SizedBox(width: 20),
                          ElevatedButton(
                            onPressed: details.onStepContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFDE59),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: Text(
                              _currentStep == 3 ? 'Done' : 'Continue',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
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
                Step( //step 1
                  title: const SizedBox.shrink(),
                  content: Center(
                    child: Column(
                      children: [
                        const Text(
                          'Instructions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Inter',
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Follow these steps to set up your device',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Jost',
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Column of square boxes with big numbers
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Box 1
                            Container(
                              width: 150,
                              height: 150,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Stack(
                                children: [
                                  // Big number 1
                                  Positioned(
                                    top: 1,
                                    left: 10,
                                    child: Text(
                                      '1',
                                      style: TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Jost',
                                        color: Colors.orange.withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                  // Content
                                  Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.power_settings_new, size: 40, color: Colors.black54),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Turn on the fire alarm and ensure that it is near your mobile device',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontFamily: 'Jost',
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Box 2
                            Container(
                              width: 150,
                              height: 150,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Stack(
                                children: [
                                  // Big number 2
                                  Positioned(
                                    top: 1,
                                    left: 10,
                                    child: Text(
                                      '2',
                                      style: TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Jost',
                                        color: Colors.orange.withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                  // Content
                                  Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.qr_code_scanner, size: 40, color: Colors.black54),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Scan the QR code (located on your fire alarm or user manual)',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontFamily: 'Jost',
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Box 3
                            Container(
                              width: 150,
                              height: 150,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Stack(
                                children: [
                                  // Big number 3
                                  Positioned(
                                    top: 1,
                                    left: 10,
                                    child: Text(
                                      '3',
                                      style: TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Jost',
                                        color: Colors.orange.withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                  // Content
                                  Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.wifi, size: 40, color: Colors.black54),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Select your Wi-Fi network and enter credentials',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontFamily: 'Jost',
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                  isActive: _currentStep == 0,
                ),
                Step( //step 2
                  title: const SizedBox.shrink(),
                  content: Center(
                    child: Column(
                      children: [
                        const Text(
                          'Scan QR Code',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Inter',
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          height: 300,
                          width: 300,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: Stack(
                            children: [
                              MobileScanner(
                                onDetect: (BarcodeCapture barcodeCapture) {
                                  if (_isToastShown) return;
                                  final barcodes = barcodeCapture.barcodes;
                                  if (barcodes.isNotEmpty) {
                                    final data = barcodes.first.rawValue;
                                    if (data != null && data.contains('-')) {
                                      setState(() {
                                        _scannedMacAddress = data.split('-')[0];
                                        _scannedProductId = data.split('-')[1];
                                        _isQrScanned = true;
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Scanned MAC: $_scannedMacAddress'),
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                      _isToastShown = true;
                                    }
                                  }
                                },
                              ),
                              if (!_isQrScanned)
                                AnimatedBuilder(
                                  animation: _animationController,
                                  builder: (context, child) {
                                    return Positioned(
                                      top: _animationController.value * 300,
                                      child: Container(
                                        width: 300,
                                        height: 3,
                                        color: Colors.red,
                                      ),
                                    );
                                  },
                                ),
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: ScannerOverlay(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isQrScanned)
                              const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              _isQrScanned ? 'Scanned Successfully' : 'Align QR code within the frame',
                              style: TextStyle(
                                fontFamily: 'Arimo',
                                fontWeight: FontWeight.w900,
                                color: _isQrScanned ? Colors.green : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        if (_scannedMacAddress != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Text(
                              'MAC: $_scannedMacAddress\nProduct ID: $_scannedProductId',
                              style: const TextStyle(
                                fontFamily: 'Jost',
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                  state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                  isActive: _currentStep == 1,
                ),
                Step( //step 3
                  title: const SizedBox.shrink(),
                  content: Center(
                    child: Column(
                      children: [
                        const Text(
                          'Select Wi-Fi Network',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_isScanning)
                          const CircularProgressIndicator()
                        else
                          Column(
                            children: [
                              Container(
                                height: MediaQuery.of(context).size.height * 0.5,
                                padding: const EdgeInsets.all(8.0),
                                margin: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    if (!_showManualSSIDInput) ...[
                                      Expanded(
                                        child: RefreshIndicator(
                                          onRefresh: _startScan,
                                          child: _accessPoints.isEmpty
                                              ? Center(
                                            child: Text(
                                              'No networks found',
                                              style: TextStyle(
                                                fontFamily: 'Jost',
                                                color: Colors.black,
                                              ),
                                            ),
                                          )
                                              : Scrollbar(
                                            thumbVisibility: true,
                                            child: Card(
                                              color: Colors.grey[100], // Light grey background
                                              margin: const EdgeInsets.all(8.0), // Space around the card
                                              elevation: 3, // Subtle shadow
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(8.0), // Rounded corners
                                                child: ListView.builder(
                                                  itemCount: _accessPoints.length,
                                                  itemBuilder: (context, index) {
                                                    final ap = _accessPoints[index];
                                                    return Column(
                                                      children: [
                                                        ListTile(
                                                          leading: _getWifiIcon(ap.level),
                                                          title: Text(
                                                            ap.ssid,
                                                            style: const TextStyle(color: Colors.black),
                                                          ),
                                                          subtitle: Text(
                                                            'Signal: ${ap.level} dBm',
                                                            style: const TextStyle(color: Colors.black54),
                                                          ),
                                                          trailing: _selectedSSID == ap.ssid
                                                              ? const Icon(Icons.check, color: Colors.green)
                                                              : null,
                                                          onTap: () {
                                                            setState(() {
                                                              _selectedSSID = ap.ssid;
                                                              _selectedBSSID = ap.bssid;
                                                            });
                                                            _showPasswordInputDialog();
                                                          },
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                                                          child: Divider(
                                                            height: 1,
                                                            thickness: 1,
                                                            color: Colors.grey[300], // Lighter divider to match card
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _showManualSSIDInput = true;
                                            _selectedSSID = null;
                                          });
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.black,
                                        ),
                                        child: const Text('Enter SSID manually'),
                                      ),
                                    ] else ...[
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                                                  onPressed: () {
                                                    setState(() {
                                                      _showManualSSIDInput = false;
                                                      _manualSSIDController.clear();
                                                    });
                                                  },
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: TextField(
                                                    controller: _manualSSIDController,
                                                    decoration: const InputDecoration(
                                                      labelText: 'Enter SSID manually',
                                                      border: OutlineInputBorder(),
                                                      labelStyle: TextStyle(color: Colors.black),
                                                    ),
                                                    style: const TextStyle(color: Colors.black),
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _selectedSSID = value;
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 20),
                                            ElevatedButton(
                                              onPressed: () {
                                                if (_manualSSIDController.text.isNotEmpty) {
                                                  _showPasswordInputDialog();
                                                } else {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Please enter an SSID')),
                                                  );
                                                }
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFFFDE59),
                                                foregroundColor: Colors.black,
                                                minimumSize: const Size(double.infinity, 50),
                                              ),
                                              child: const Text('Continue'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (_selectedSSID != null) ...[
                                const SizedBox(height: 20),
                                Text(
                                  'Selected Network: $_selectedSSID',
                                  style: const TextStyle(
                                    fontFamily: 'Jost',
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                  state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                  isActive: _currentStep == 2,
                ),
                Step(//step 4
                  title: const SizedBox.shrink(),
                  content: Center(
                    child: Column(
                      children: [
                        const Text(
                          'Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Jost',
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'MAC Address: $_scannedMacAddress',
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'Jost',
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Product Code: $_scannedProductId',
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'Jost',
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'SSID: $_selectedSSID',
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'Jost',
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  isActive: _currentStep == 3,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _getWifiIcon(int level) {
    if (level >= -50) {
      return const Icon(Icons.wifi, color: Colors.green);
    } else if (level >= -70) {
      return const Icon(Icons.wifi_2_bar, color: Colors.orange);
    } else {
      return const Icon(Icons.wifi_1_bar, color: Colors.red);
    }
  }
}

class ScannerOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15.0;

    final path = Path()
      ..moveTo(0, size.height * 0.3)
      ..lineTo(0, 0)
      ..lineTo(size.width * 0.3, 0);

    final path2 = Path()
      ..moveTo(size.width * 0.7, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.3);

    final path3 = Path()
      ..moveTo(size.width, size.height * 0.7)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.7, size.height);

    final path4 = Path()
      ..moveTo(size.width * 0.3, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, size.height * 0.7);

    canvas.drawPath(path, borderPaint);
    canvas.drawPath(path2, borderPaint);
    canvas.drawPath(path3, borderPaint);
    canvas.drawPath(path4, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}