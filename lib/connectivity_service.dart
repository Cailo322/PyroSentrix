import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService with ChangeNotifier {
  bool _hasInternet = true;
  bool get hasInternet => _hasInternet;

  ConnectivityService() {
    _init();
  }

  Future<void> _init() async {
    final connectivity = Connectivity();
    // Check initial state
    var result = await connectivity.checkConnectivity();
    _updateConnectionStatus(result);

    // Listen for changes
    connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateConnectionStatus(results);
    });
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    bool newStatus;
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      newStatus = false;
    } else {
      // We have some connection (mobile, wifi, etc.)
      newStatus = true;
    }

    if (newStatus != _hasInternet) {
      _hasInternet = newStatus;
      notifyListeners();
    }
  }

  Future<bool> checkConnection() async {
    final connectivity = Connectivity();
    var results = await connectivity.checkConnectivity();
    return results.isNotEmpty && !results.contains(ConnectivityResult.none);
  }
}