import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

enum StravaAuthResult {
  success,
  cancelled,
  failed,
  networkError,
  timeout
}

class StravaService {
  static const String _clientId = '150848';
  static const String _clientSecret = '72af103d651584b37d751f899ef80d04f646b6e2';
  static const String _redirectUrl = 'https://dc67-92-29-210-187.ngrok-free.app/callback';
  static const String _authUrl = 'https://www.strava.com/oauth/authorize';
  static const String _tokenUrl = 'https://www.strava.com/oauth/token';
  static const String _scope = 'read,activity:read,activity:read_all,profile:read_all';

  final SharedPreferences _prefs;

  StravaService(this._prefs);

  Future<bool> get isAuthenticated async {
    final token = _prefs.getString('strava_access_token');
    final expiresAt = _prefs.getInt('strava_expires_at');
    if (token == null || expiresAt == null) return false;
    return DateTime.now().millisecondsSinceEpoch < expiresAt;
  }

  Future<StravaAuthResult> authenticate() async {
    try {
      final state = DateTime.now().millisecondsSinceEpoch.toString();
      
      final authorizeUrl = Uri.parse(_authUrl).replace(queryParameters: {
        'client_id': _clientId,
        'redirect_uri': _redirectUrl,
        'response_type': 'code',
        'scope': _scope,
        'approval_prompt': 'auto',
        'state': state,
      });

      debugPrint('Starting Strava authentication...');
      debugPrint('Authorization URL: ${authorizeUrl.toString()}');

      final result = await FlutterWebAuth2.authenticate(
        url: authorizeUrl.toString(),
        callbackUrlScheme: 'fundracer',
      );

      debugPrint('Auth result: $result');

      if (result.isEmpty) {
        debugPrint('Authentication was cancelled');
        return StravaAuthResult.cancelled;
      }

      final uri = Uri.parse(result);
      final code = uri.queryParameters['code'];
      final returnedState = uri.queryParameters['state'];
      final error = uri.queryParameters['error'];

      if (error != null) {
        debugPrint('Error received from Strava: $error');
        return StravaAuthResult.failed;
      }

      if (code == null) {
        debugPrint('No authorization code received');
        return StravaAuthResult.failed;
      }

      if (returnedState != state) {
        debugPrint('State mismatch. Expected: $state, Got: $returnedState');
        return StravaAuthResult.failed;
      }

      debugPrint('Exchanging code for token...');
      final tokenResponse = await http.post(
        Uri.parse(_tokenUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'code': code,
          'grant_type': 'authorization_code',
          'redirect_uri': _redirectUrl,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Token exchange timed out');
        },
      );

      debugPrint('Token response status: ${tokenResponse.statusCode}');

      if (tokenResponse.statusCode != 200) {
        debugPrint('Failed to get access token: ${tokenResponse.body}');
        return StravaAuthResult.failed;
      }

      final tokenData = json.decode(tokenResponse.body);
      await _prefs.setString('strava_access_token', tokenData['access_token']);
      await _prefs.setInt('strava_expires_at', tokenData['expires_at'] * 1000);
      await _prefs.setString('strava_refresh_token', tokenData['refresh_token']);
      
      debugPrint('Authentication completed successfully');
      return StravaAuthResult.success;
    } on TimeoutException {
      debugPrint('Strava authentication timed out');
      return StravaAuthResult.timeout;
    } catch (e) {
      if (e.toString().contains('Connection failed') || 
          e.toString().contains('SocketException')) {
        debugPrint('Network error during Strava authentication: $e');
        return StravaAuthResult.networkError;
      }
      debugPrint('Error during Strava authentication: $e');
      return StravaAuthResult.failed;
    }
  }

  Future<Map<String, dynamic>> getAthleteStats() async {
    try {
      final token = await _getValidToken();
      if (token == null) throw Exception('Not authenticated with Strava');

      // First get the athlete ID
      final athleteResponse = await http.get(
        Uri.parse('https://www.strava.com/api/v3/athlete'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (athleteResponse.statusCode != 200) {
        throw Exception('Failed to get athlete data');
      }

      final athleteData = json.decode(athleteResponse.body);
      final athleteId = athleteData['id'];

      // Then get the stats
      final statsResponse = await http.get(
        Uri.parse('https://www.strava.com/api/v3/athletes/$athleteId/stats'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (statsResponse.statusCode != 200) {
        throw Exception('Failed to get athlete stats');
      }

      final stats = json.decode(statsResponse.body);
      return {
        'total_distance': stats['all_run_totals']['distance'] ?? 0,
        'total_runs': stats['all_run_totals']['count'] ?? 0,
        'recent_runs': stats['recent_run_totals']['count'] ?? 0,
        'ytd_distance': stats['ytd_run_totals']['distance'] ?? 0,
      };
    } catch (e) {
      debugPrint('Error getting athlete stats: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getRecentActivities() async {
    try {
      final token = await _getValidToken();
      if (token == null) throw Exception('Not authenticated with Strava');

      final response = await http.get(
        Uri.parse('https://www.strava.com/api/v3/athlete/activities')
            .replace(queryParameters: {
          'per_page': '10',
          'after': (DateTime.now()
                      .subtract(const Duration(days: 30))
                      .millisecondsSinceEpoch ~/
                  1000)
              .toString(),
        }),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get activities');
      }

      final activities = json.decode(response.body) as List;
      return activities.map((activity) => activity as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error getting recent activities: $e');
      rethrow;
    }
  }

  Future<String?> _getValidToken() async {
    final token = _prefs.getString('strava_access_token');
    final expiresAt = _prefs.getInt('strava_expires_at');
    final refreshToken = _prefs.getString('strava_refresh_token');

    if (token == null || expiresAt == null || refreshToken == null) {
      return null;
    }

    // If token is expired, refresh it
    if (DateTime.now().millisecondsSinceEpoch >= expiresAt) {
      final response = await http.post(
        Uri.parse(_tokenUrl),
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode != 200) {
        await logout();
        return null;
      }

      final tokenData = json.decode(response.body);
      await _prefs.setString('strava_access_token', tokenData['access_token']);
      await _prefs.setInt('strava_expires_at', tokenData['expires_at'] * 1000);
      await _prefs.setString('strava_refresh_token', tokenData['refresh_token']);
      return tokenData['access_token'];
    }

    return token;
  }

  Future<void> logout() async {
    await _prefs.remove('strava_access_token');
    await _prefs.remove('strava_expires_at');
    await _prefs.remove('strava_refresh_token');
  }
} 