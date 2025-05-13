import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/strava_service.dart';
import '../main.dart';
import 'notification_permission_screen.dart';
import 'country_selection_screen.dart';
import 'metric_selection_screen.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConnectHealthScreen extends StatefulWidget {
  const ConnectHealthScreen({super.key});

  @override
  State<ConnectHealthScreen> createState() => _ConnectHealthScreenState();
}

class _ConnectHealthScreenState extends State<ConnectHealthScreen> {
  bool _isLoading = false;
  bool _isSelected = false;
  String _statusMessage = '';
  String? _selectedApp;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  late StravaService _stravaService;
  bool _isStravaConnected = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    _stravaService = StravaService(prefs);
    await _checkStravaConnection();
  }

  Future<void> _checkStravaConnection() async {
    final isAuthenticated = await _stravaService.isAuthenticated;
    setState(() {
      _isStravaConnected = isAuthenticated;
    });
  }

  Future<void> _connectStrava() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authResult = await _stravaService.authenticate();
      
      if (!mounted) return;
      
      switch (authResult) {
        case StravaAuthResult.success:
          debugPrint('Successfully connected to Strava');
          await _checkStravaConnection();
          await _saveHealthConnectionStatus('Strava');
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationPermissionScreen(),
              ),
            );
          }
          break;
          
        case StravaAuthResult.cancelled:
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Strava connection was cancelled'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          break;
          
        case StravaAuthResult.networkError:
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Network Error'),
                content: const Text('Please check your internet connection and try again.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          break;
          
        case StravaAuthResult.timeout:
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Connection Timeout'),
                content: const Text('The connection to Strava timed out. Please try again later.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          break;
          
        case StravaAuthResult.failed:
        default:
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Connection Failed'),
                content: const Text('Failed to connect to Strava. Please try again.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          break;
      }
    } catch (e) {
      debugPrint('Error connecting to Strava: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: const Text('Failed to connect to Strava. Please try again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _launchStravaProfile() async {
    final Uri stravaUrl = Uri.parse('https://www.strava.com/dashboard');
    if (await canLaunchUrl(stravaUrl)) {
      await launchUrl(stravaUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _saveHealthConnectionStatus(String appName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'healthAppConnected': true,
          'healthAppName': appName,
          'healthConnectedAt': FieldValue.serverTimestamp(),
        });
        
        // Also update the UserProvider
        if (mounted) {
          Provider.of<UserProvider>(context, listen: false)
              .connectHealthService(appName, true);
        }
      }
    } catch (e) {
      debugPrint('Error saving health connection status: $e');
      // Handle error if needed
    }
  }

  bool get canContinue => _isSelected;

  Widget _buildStravaSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.directions_run,
                color: const Color(0xFFFC5200),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Strava',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connect to track your runs and activities',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_isStravaConnected)
            Center(
              child: GestureDetector(
                onTap: _isLoading ? null : _connectStrava,
                child: Image.asset(
                  'assets/images/btn_strava_connect_with_orange_x2.png',
                  height: 48,
                ),
              ),
            )
          else
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/api_logo_pwrdBy_strava_stack_orange.png',
                      height: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _launchStravaProfile,
                  child: Text(
                    'View on Strava',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFC5200),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
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
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CountrySelectionScreen()),
            );
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
                          'Connect Strava',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepBlue,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Link your Strava account to track your runs and activities',
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
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSelected = !_isSelected;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: _isSelected 
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
                            color: _isSelected
                                ? AppColors.primaryBlue.withOpacity(0.1)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.directions_run_rounded,
                            size: 28,
                            color: _isSelected
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
                                'Strava',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textBlack,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Connect with Strava to sync your activities',
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
                                child: const Text(
                                  'All platforms',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF4A67FF),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isSelected)
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
                      onPressed: _isLoading 
                          ? null 
                          : (_isSelected ? _connectStrava : null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        disabledBackgroundColor: Colors.transparent,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Connect Strava',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: _isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isLoading 
                        ? null 
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const MetricSelectionScreen()),
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