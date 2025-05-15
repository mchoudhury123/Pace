import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fundracer_app/models/strava_activity_model.dart';
import 'package:fundracer_app/models/strava_athlete_model.dart';
import 'package:fundracer_app/services/strava_client_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StravaProvider with ChangeNotifier {
  late StravaClientService _stravaService;
  bool _isInitialized = false;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  List<StravaActivityModel> _activities = [];
  StravaAthleteModel? _athlete;
  Map<String, dynamic>? _athleteStats;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  List<StravaActivityModel> get activities => _activities;
  StravaAthleteModel? get athlete => _athlete;
  Map<String, dynamic>? get athleteStats => _athleteStats;

  // Initialize the provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _stravaService = StravaClientService();

      // Check if user is authenticated
      _isAuthenticated = await _stravaService.authStatus ==
          StravaAuthStatus.authenticated;

      if (_isAuthenticated) {
        await _loadData();
      } else {
        // If not authenticated, clear data
        _activities = [];
        _athlete = null;
        _athleteStats = null;
      }

      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing Strava provider: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Authenticate with Strava
  Future<bool> authenticate(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _stravaService.authenticate(context);

      if (success) {
        _isAuthenticated = true;
        await _loadData();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('Error authenticating with Strava: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Load Strava data
  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Get athlete profile
      final athlete = await _stravaService.getAthleteProfile();

      // Get athlete stats
      final stats = await _stravaService.getAthleteStats();

      // Get recent activities
      final activities = await _stravaService.getRecentActivities(limit: 20);

      _athlete = athlete;
      _athleteStats = stats;
      _activities = activities;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading Strava data: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh data
  Future<void> refreshData() async {
    if (!_isAuthenticated) return;
    await _loadData();
  }

  // Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _stravaService.logout();

      _isAuthenticated = false;
      _activities = [];
      _athlete = null;
      _athleteStats = null;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error logging out from Strava: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get recent activities
  Future<List<StravaActivityModel>> getRecentActivities(
      {int limit = 10}) async {
    if (!_isAuthenticated) return [];

    try {
      return await _stravaService.getRecentActivities(limit: limit);
    } catch (e) {
      debugPrint('Error getting recent activities: $e');
      return [];
    }
  }
}
