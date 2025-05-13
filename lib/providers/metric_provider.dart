import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MetricProvider with ChangeNotifier {
  bool _isMetric = true; // Default to metric (kilometers)
  
  bool get isMetric => _isMetric;
  String get distanceUnit => _isMetric ? 'km' : 'mi';
  double get conversionFactor => _isMetric ? 1000.0 : 1609.34; // meters to km or mi

  Future<void> loadSavedMetric() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMetric = prefs.getString('preferredMetric');
    if (savedMetric != null) {
      _isMetric = savedMetric == 'km';
      notifyListeners();
    }
  }

  Future<void> setMetric(String unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferredMetric', unit);
    _isMetric = unit == 'km';
    notifyListeners();
  }

  // Helper method to convert distances
  double convertDistance(double meters) {
    return meters / conversionFactor;
  }
} 