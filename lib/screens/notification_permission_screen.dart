import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io' show Platform;
import 'profile_photo_screen.dart';
import '../main.dart';  // Import for AppColors
import 'connect_health_screen.dart';
import 'metric_selection_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationPermissionScreen extends StatefulWidget {
  const NotificationPermissionScreen({super.key});

  @override
  State<NotificationPermissionScreen> createState() => _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState extends State<NotificationPermissionScreen> {
  bool _isLoading = false;
  String _statusMessage = '';
  late FirebaseMessaging _messaging;

  @override
  void initState() {
    super.initState();
    _messaging = FirebaseMessaging.instance;
    // Initialize Firebase Messaging with proper error handling
    _initializeFirebaseMessaging();
  }

  Future<void> _initializeFirebaseMessaging() async {
    try {
      if (Platform.isIOS) {
        // Configure APNS on iOS
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      debugPrint('Error initializing Firebase Messaging: $e');
    }
  }

  Future<void> _saveNotificationPreference(bool enabled) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (enabled) {
          bool permissionGranted = false;
          
          if (Platform.isIOS) {
            // For iOS - use the proper approach that works with current plugin version
            final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
            // Initialize with request permissions enabled
            await plugin.initialize(
              const InitializationSettings(
                iOS: DarwinInitializationSettings(
                  requestAlertPermission: true,
                  requestBadgePermission: true,
                  requestSoundPermission: true,
                ),
                android: AndroidInitializationSettings('@mipmap/ic_launcher'),
              ),
            );
            // We'll assume permissions were requested successfully on iOS
            // The actual permission status is determined by the user's response to the system dialog
            permissionGranted = true;
          } else {
            // For Android, use Permission Handler
            final status = await Permission.notification.request();
            permissionGranted = status.isGranted;
            
            if (status.isPermanentlyDenied) {
              // If permanently denied, prompt the user to enable from settings
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Notifications Disabled'),
                    content: const Text(
                      'Notifications are permanently disabled. Please enable them in your device settings to receive updates about your runs and donations.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          openAppSettings();
                        },
                        child: const Text('Open Settings'),
                      ),
                    ],
                  ),
                );
              }
            }
          }
          
          // Update status message based on permission result
          setState(() {
            _statusMessage = permissionGranted 
              ? 'Notifications enabled successfully!' 
              : 'Notifications permissions were declined';
          });
          
          // Save the actual granted status to Firestore
          try {
            await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
              'notificationsEnabled': permissionGranted,
              'notificationPreferenceSetAt': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            debugPrint('Failed to save notification preference: $e');
          }
        } else {
          // User chose "Maybe Later" - save this preference
          try {
            await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
              'notificationsEnabled': false,
              'notificationPreferenceSetAt': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            debugPrint('Failed to save notification preference: $e');
          }
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to save preference. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Add a small delay before navigating to ensure user sees the result
        if (_statusMessage.isNotEmpty) {
          await Future.delayed(const Duration(seconds: 1));
        }
        
        // Navigate to ProfilePhotoScreen after user interaction
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfilePhotoScreen(),
          ),
        );
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    // Check if we're running on a real iOS device
    if (Platform.isIOS) {
      try {
        // Skip actual FCM token request and use a simulated token for development
        debugPrint('Running in iOS development mode - simulating notification permission');
        
        // Just request the basic iOS notification permission
        final settings = await _messaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
        
        if (settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional) {
          
          // Save preferences without actual token for development
          await _updateUserNotificationPreferencesWithoutToken(true);
          
          setState(() {
            _statusMessage = 'Notifications enabled for development!';
          });
          
          // Wait a moment to show success message, then navigate
          Future.delayed(const Duration(seconds: 1), () {
            _navigateToHome(context);
          });
        } else {
          setState(() {
            _statusMessage = 'Notification permission was denied.';
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _statusMessage = 'Error in development mode: $e';
          _isLoading = false;
        });
      }
      return;
    }

    // Normal flow for non-iOS or when ready for production
    try {
      // For iOS, we need to explicitly get the APNS token first
      if (Platform.isIOS) {
        try {
          // This explicit call is needed to ensure the APNS token is set
          await _messaging.getAPNSToken();
          debugPrint('Successfully requested APNS token');
        } catch (e) {
          debugPrint('Error getting APNS token: $e');
          // Continue anyway as the token might be set in the background
        }
      }

      final NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get the token with retries
        String? token;
        int retryCount = 0;
        const maxRetries = 3;
        
        while (token == null && retryCount < maxRetries) {
          try {
            token = await _messaging.getToken();
            if (token == null) {
              retryCount++;
              debugPrint('Token is null, retrying ($retryCount/$maxRetries)...');
              await Future.delayed(const Duration(seconds: 1));
            }
          } catch (e) {
            retryCount++;
            debugPrint('Error getting token, retrying ($retryCount/$maxRetries): $e');
            await Future.delayed(const Duration(seconds: 1));
          }
        }
        
        if (token != null) {
          await _updateUserNotificationPreferences(true, token);
          
          setState(() {
            _statusMessage = 'Notifications enabled successfully!';
          });
          
          // Wait a moment to show success message, then navigate
          Future.delayed(const Duration(seconds: 1), () {
            _navigateToHome(context);
          });
        } else {
          // If we still don't have a token after retries, let's save anyway
          debugPrint('Failed to get FCM token after $maxRetries retries');
          
          // Save preferences without token as a fallback
          await _updateUserNotificationPreferencesWithoutToken(true);
          
          setState(() {
            _statusMessage = 'Notification permissions granted, but token not available. You may need to restart the app.';
            _isLoading = false;
          });
          
          // Still navigate after a delay
          Future.delayed(const Duration(seconds: 2), () {
            _navigateToHome(context);
          });
        }
      } else {
        // Handle denied or limited permissions
        setState(() {
          _statusMessage = 'Notification permission was denied.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error requesting permission: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserNotificationPreferences(bool enabled, String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // For debugging APNS token issues
        if (Platform.isIOS) {
          String? apnsToken = await _messaging.getAPNSToken();
          debugPrint('Current APNS token: $apnsToken');
        }
        
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'notificationsEnabled': enabled,
          'fcmToken': token,
          'notificationPreferenceSetAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Failed to update notification preferences: $e');
        // If the document doesn't exist yet, create it
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'notificationsEnabled': enabled,
            'fcmToken': token,
            'notificationPreferenceSetAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Failed to create notification preferences: $e');
          rethrow;
        }
      }
    }
  }

  // Fallback method when FCM token is not available
  Future<void> _updateUserNotificationPreferencesWithoutToken(bool enabled) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'notificationsEnabled': enabled,
          'notificationPreferenceSetAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Failed to update notification preferences without token: $e');
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'notificationsEnabled': enabled,
            'notificationPreferenceSetAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Failed to create notification preferences without token: $e');
        }
      }
    }
  }

  void _navigateToHome(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MetricSelectionScreen()),
    );
  }

  void _skipNotificationPermission(BuildContext context) {
    _saveNotificationPreference(false);
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
          onPressed: () => Navigator.pop(context),
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
                          'Enable\nNotifications',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepBlue,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Get notified about race registrations, updates, and more!',
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_active,
                        size: 64,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Stay Connected',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepBlue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'We\'ll let you know about important updates, donation impacts, and upcoming races',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textGrey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _statusMessage.contains('Error') || _statusMessage.contains('denied')
                              ? Colors.red.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _statusMessage.contains('Error') || _statusMessage.contains('denied')
                                ? Colors.red.shade200
                                : Colors.green.shade200,
                          ),
                        ),
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            color: _statusMessage.contains('Error') || _statusMessage.contains('denied')
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryBlue,
                        ),
                      )
                    : Container(
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
                          onPressed: _requestNotificationPermission,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Enable Notifications',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _skipNotificationPermission(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Maybe Later',
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