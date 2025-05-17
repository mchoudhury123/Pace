import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import '../models/strava_activity_model.dart';
import '../models/strava_athlete_model.dart';
import 'package:strava_client/strava_client.dart';

enum StravaAuthStatus {
  authenticated,
  unauthenticated,
  error,
  inProgress,
}

class StravaClientService {
  // Strava API credentials
  // static const String _clientId = String.fromEnvironment('STRAVA_CLIENT_ID');
  // static const String _clientSecret = String.fromEnvironment('STRAVA_CLIENT_SECRET');
  static const String _clientId = '150848';
  static const String _clientSecret = '72af103d651584b37d751f899ef80d04f646b6e2';

  // Authentication status
  StravaAuthStatus _authStatus = StravaAuthStatus.unauthenticated;

  StravaAuthStatus get authStatus => _authStatus;

  // StravaClient instance
  final StravaClient _stravaClient;

  // Constructor
  StravaClientService()
      : _stravaClient = StravaClient(
          clientId: _clientId,
          secret: _clientSecret,
        );

  // Authenticate with Strava
  Future<bool> authenticate(BuildContext context) async {
    try {
      _authStatus = StravaAuthStatus.inProgress;

      final result = await _stravaClient.authentication.authenticate(
        redirectUrl: 'fundracer://redirect',
        scopes: [
          AuthenticationScope.read,
          AuthenticationScope.activity_read,
          AuthenticationScope.activity_read_all,
          AuthenticationScope.profile_read_all,
        ],
        callbackUrlScheme: 'fundracer',
      );
      debugPrint('Authentication result: ${result.toJson()}');
      final prefs = await SharedPreferences.getInstance();
      final token = await prefs.setString('strava_access_token', result.accessToken);
      final expiresAt = await prefs.setInt('strava_expires_at', result.expiresAt);
      _authStatus = StravaAuthStatus.authenticated;
      return true;
      // if (result.expiresAt < DateTime.now().millisecondsSinceEpoch ~/ 1000) {
      //   _authStatus = StravaAuthStatus.authenticated;
      //   return true;
      // } else {
      //   _authStatus = StravaAuthStatus.error;
      //   return false;
      // }
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') {
        debugPrint('User canceled Strava login');
        _authStatus = StravaAuthStatus.unauthenticated; // Treat as unauthenticated, not an error
        return false;
      }
      debugPrint('PlatformException during authentication: $e');
      _authStatus = StravaAuthStatus.error;
      return false;
    } on Fault catch (fault) {
      debugPrint('Authentication fault: ${fault.message}');
      _authStatus = StravaAuthStatus.error;
      return false;
    } catch (e) {
      debugPrint('Error during authentication: $e');
      _authStatus = StravaAuthStatus.error;
      return false;
    }
  }

  // Get athlete profile
  Future<StravaAthleteModel?> getAthleteProfile() async {
    try {
      final athlete = await _stravaClient.athletes.getAuthenticatedAthlete();
      return StravaAthleteModel.fromJson(athlete.toJson());
    } catch (e) {
      debugPrint('Error getting athlete profile: $e');
      return null;
    }
  }

  // Get athlete stats
  Future<Map<String, dynamic>?> getAthleteStats() async {
    try {
      final athlete = await _stravaClient.athletes.getAuthenticatedAthlete();
      final stats = await _stravaClient.athletes.getAthleteStats(athlete.id);
      return stats.toJson();
    } catch (e) {
      debugPrint('Error getting athlete stats: $e');
      return null;
    }
  }

  // Get recent activities
  Future<List<StravaActivityModel>> getRecentActivities({int limit = 10}) async {
    try {
      final activities = await _stravaClient.activities.listLoggedInAthleteActivities(
        DateTime.now().subtract(const Duration(days: 30)),
        DateTime.now(),
        1,
        limit,
      );
      return activities.map((activity) => StravaActivityModel.fromJson(activity.toJson())).toList();
    } catch (e) {
      debugPrint('Error getting recent activities: $e');
      return [];
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _stravaClient.authentication.deAuthorize();
      _authStatus = StravaAuthStatus.unauthenticated;
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }
}
