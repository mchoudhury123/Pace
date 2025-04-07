import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/health_service.dart';
import '../services/samsung_health_service.dart';
import '../services/google_fit_service.dart';
import '../services/strava_service.dart';
import '../main.dart';
import 'notification_permission_screen.dart';
import 'gender_selection_screen.dart';

class ConnectHealthScreen extends StatefulWidget {
  const ConnectHealthScreen({super.key});

  @override
  State<ConnectHealthScreen> createState() => _ConnectHealthScreenState();
}

class _ConnectHealthScreenState extends State<ConnectHealthScreen> {
  String? _selectedOption;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  List<Map<String, dynamic>> _healthOptions = [];

  @override
  void initState() {
    super.initState();
    _initializeHealthOptions();
  }

  Future<void> _initializeHealthOptions() async {
    final isSamsungDevice = await _isSamsungDevice();
    final healthService = HealthService();
    final samsungHealthService = SamsungHealthService();
    final googleFitService = GoogleFitService();
    final prefs = await SharedPreferences.getInstance();
    final stravaService = StravaService(prefs);
    
    setState(() {
      _healthOptions = [
        if (!kIsWeb && Platform.isIOS)
          {
            'text': 'Apple Health',
            'icon': Icons.health_and_safety_rounded,
            'description': 'Connect with Apple Health to sync your health and fitness data',
            'platform': 'iOS',
            'connect': () async {
              try {
                final authorized = await healthService.requestAuthorization();
                if (!authorized) {
                  throw Exception('Health data access not authorized');
                }
                
                // Test connection by fetching today's steps
                final steps = await healthService.getStepsForDay(DateTime.now());
                debugPrint('Successfully connected to Apple Health. Steps today: $steps');
                return true;
              } catch (e) {
                debugPrint('Error connecting to Apple Health: $e');
                return false;
              }
            },
          },
        if (!kIsWeb && Platform.isAndroid && isSamsungDevice)
          {
            'text': 'Samsung Health',
            'icon': Icons.favorite_rounded,
            'description': 'Connect with Samsung Health to sync your health and fitness data',
            'platform': 'Samsung',
            'connect': () async {
              try {
                final authorized = await samsungHealthService.requestAuthorization();
                if (!authorized) {
                  throw Exception('Samsung Health data access not authorized');
                }
                
                // Test connection by fetching today's steps
                final steps = await samsungHealthService.getStepsForDay(DateTime.now());
                debugPrint('Successfully connected to Samsung Health. Steps today: $steps');
                return true;
              } catch (e) {
                debugPrint('Error connecting to Samsung Health: $e');
                return false;
              }
            },
          },
        {
          'text': 'Google Fit',
          'icon': Icons.monitor_heart_rounded,
          'description': 'Connect with Google Fit to sync your activities and health data',
          'platform': 'All',
          'connect': () async {
            try {
              final authorized = await googleFitService.requestAuthorization();
              if (!authorized) {
                throw Exception('Google Fit data access not authorized');
              }
              
              // Test connection by fetching today's steps
              final steps = await googleFitService.getStepsForDay(DateTime.now());
              debugPrint('Successfully connected to Google Fit. Steps today: $steps');
              return true;
            } catch (e) {
              debugPrint('Error connecting to Google Fit: $e');
              return false;
            }
          },
        },
        {
          'text': 'Strava',
          'icon': Icons.directions_run_rounded,
          'description': 'Connect with Strava to sync your activities',
          'platform': 'All',
          'connect': () async {
            try {
              await stravaService.authenticate();
              final isConnected = await stravaService.isAuthenticated;
              if (!isConnected) {
                throw Exception('Failed to connect to Strava');
              }
              
              // Test connection by fetching athlete stats
              final stats = await stravaService.getAthleteStats();
              debugPrint('Successfully connected to Strava. Recent runs: ${stats['recent_runs']}');
              return true;
            } catch (e) {
              debugPrint('Error connecting to Strava: $e');
              return false;
            }
          },
        },
        {
          'text': 'Garmin Connect',
          'icon': Icons.watch_rounded,
          'description': 'Connect with Garmin to sync your activities and health data',
          'platform': 'All',
          'connect': () async {
            try {
              // TODO: Implement Garmin Connect integration
              // You'll need to:
              // 1. Set up Garmin Connect API access
              // 2. Implement OAuth flow
              // 3. Create a GarminService class similar to StravaService
              throw Exception('Garmin Connect integration not implemented yet');
              return false;
            } catch (e) {
              debugPrint('Error connecting to Garmin: $e');
              return false;
            }
          },
        },
      ];
    });
  }

  Future<bool> _isSamsungDevice() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final androidInfo = await _deviceInfo.androidInfo;
      return androidInfo.manufacturer?.toLowerCase().contains('samsung') ?? false;
    } catch (e) {
      debugPrint('Error detecting Samsung device: $e');
      return false;
    }
  }

  bool get canContinue => _selectedOption != null;

  // Modified onPressed handler for the continue button
  Future<void> _connectToSelectedService() async {
    if (_selectedOption == null) return;

    final selectedService = _healthOptions.firstWhere(
      (option) => option['text'] == _selectedOption
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await selectedService['connect']();
      Navigator.pop(context); // Remove loading dialog

      if (success) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NotificationPermissionScreen()),
        );
      } else {
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Connection Failed'),
            content: Text('Failed to connect to ${selectedService['text']}. Please try again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Remove loading dialog
      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('An error occurred: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget mainContent = Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: AppColors.textBlack,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.lightBlue,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade100.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connect your\nhealth data',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepBlue,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose how you want to track your activities',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textGrey,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: _healthOptions.map((option) {
                    final isSelected = _selectedOption == option['text'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedOption = option['text'];
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: isSelected 
                                ? AppColors.primaryBlue
                                : AppColors.lightBlue,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.shade100.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryBlue.withOpacity(0.1)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                option['icon'],
                                size: 28,
                                color: isSelected
                                    ? AppColors.primaryBlue
                                    : AppColors.textGrey,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option['text'],
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppColors.textBlack,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    option['description'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      option['platform'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primaryBlue,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check,
                                  color: AppColors.primaryBlue,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: AppColors.lightBlue,
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryBlue,
                          AppColors.primaryBlue.withBlue(255),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: canContinue
                          ? _connectToSelectedService
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        disabledBackgroundColor: Colors.transparent,
                      ),
                      child: Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: canContinue ? Colors.white : Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationPermissionScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(
                      'Skip for now',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (kIsWeb) {
      const phoneWidth = 393.0;
      const phoneHeight = 852.0;

      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Container(
            width: phoneWidth,
            height: phoneHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: mainContent,
            ),
          ),
        ),
      );
    }

    return mainContent;
  }
} 