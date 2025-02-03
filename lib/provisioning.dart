import 'package:flutter/material.dart';
import 'package:esp_smartconfig/esp_smartconfig.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ProvisioningStepperScreen extends StatefulWidget {
  final String title;

  const ProvisioningStepperScreen({super.key, required this.title});

  @override
  State<ProvisioningStepperScreen> createState() =>
      _ProvisioningStepperScreenState();
}

class _ProvisioningStepperScreenState extends State<ProvisioningStepperScreen> {
  int _currentStep = 0;
  String? scannedMacAddress;
  String? scannedProductId;
  final ssidController = TextEditingController();
  final passwordController = TextEditingController();
  final provisioner = Provisioner.espTouch();

  Future<void> _startProvisioning() async {
    if (scannedMacAddress == null || scannedMacAddress!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan a valid QR code.')),
      );
      return;
    }

    provisioner.listen((response) {
      Navigator.of(context).pop(response);
    });

    try {
      provisioner.start(ProvisioningRequest.fromStrings(
        ssid: ssidController.text,
        bssid: scannedMacAddress!,
        password: passwordController.text,
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

      if (provisioner.running) {
        provisioner.stop();
      }

      if (response != null) {
        _onDeviceProvisioned(response);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during provisioning: $e')),
      );
    }
  }

  void _onDeviceProvisioned(ProvisioningResponse response) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Device provisioned'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Device successfully connected to the ${ssidController.text} network',
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0 && scannedMacAddress == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please scan the QR code first')),
            );
            return;
          }
          if (_currentStep < 1) {
            setState(() => _currentStep += 1);
          } else if (_currentStep == 1) {
            _startProvisioning();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        steps: [
          Step(
            title: const Text('Scan QR Code'),
            content: Column(
              children: [
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
                            scannedMacAddress = parts[0];
                            scannedProductId = parts[1];
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Scanned MAC: $scannedMacAddress')),
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
                if (scannedMacAddress != null)
                  Text('MAC: $scannedMacAddress\nProduct ID: $scannedProductId'),
              ],
            ),
          ),
          Step(
            title: const Text('Wi-Fi Provisioning'),
            content: Column(
              children: [
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'SSID (Network name)',
                  ),
                  controller: ssidController,
                ),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Password',
                  ),
                  obscureText: true,
                  controller: passwordController,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    ssidController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}