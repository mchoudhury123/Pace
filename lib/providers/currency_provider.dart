import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyProvider extends ChangeNotifier {
  String _currencyCode = 'USD';
  String _currencySymbol = '\$';
  
  String get currencyCode => _currencyCode;
  String get currencySymbol => _currencySymbol;

  // Initialize from SharedPreferences
  Future<void> loadSavedCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    _currencyCode = prefs.getString('currencyCode') ?? 'USD';
    _currencySymbol = prefs.getString('currencySymbol') ?? '\$';
    notifyListeners();
  }

  // Update currency settings
  Future<void> setCurrency(String code, String symbol) async {
    _currencyCode = code;
    _currencySymbol = symbol;
    
    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currencyCode', code);
    await prefs.setString('currencySymbol', symbol);
    
    notifyListeners();
  }

  // Format amount according to currency
  String formatAmount(double amount) {
    return '$_currencySymbol${amount.toStringAsFixed(2)}';
  }
} 