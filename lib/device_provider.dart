import 'package:flutter/material.dart';

class DeviceProvider with ChangeNotifier {
  String? _selectedProductCode;

  String? get selectedProductCode => _selectedProductCode;

  void setSelectedProductCode(String productCode) {
    _selectedProductCode = productCode;
    notifyListeners();
  }
}