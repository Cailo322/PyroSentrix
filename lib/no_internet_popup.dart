import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'connectivity_service.dart';

class NoInternetPopup extends StatefulWidget {
  const NoInternetPopup({Key? key}) : super(key: key);

  @override
  State<NoInternetPopup> createState() => _NoInternetPopupState();
}

class _NoInternetPopupState extends State<NoInternetPopup> {
  bool _isRetrying = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 50, color: Colors.red),
              const SizedBox(height: 15),
              const Text(
                'Oops!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'You don\'t have an internet connection.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 5),
              const Text(
                'Please check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isRetrying ? null : _retryConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFDE59),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    disabledBackgroundColor: const Color(0xFFFFDE59).withOpacity(0.5),
                  ),
                  child: _isRetrying
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                      : const Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _retryConnection() async {
    setState(() => _isRetrying = true);
    final connectivity = Provider.of<ConnectivityService>(context, listen: false);

    // Wait for 5 seconds
    await Future.delayed(const Duration(seconds: 5));

    final hasConnection = await connectivity.checkConnection();
    setState(() => _isRetrying = false);

    if (!hasConnection) {
      // You might want to show a snackbar or other feedback here
    }
  }
}