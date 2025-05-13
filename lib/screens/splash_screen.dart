import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../main.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Create fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    // Start animation
    _controller.forward();

    // Navigate after delay
    Timer(const Duration(seconds: 3), () {
      _navigateToNextScreen();
    });
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // User is logged in, navigate to home screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      // User is not logged in, navigate to onboarding screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget mainContent = Scaffold(
      backgroundColor: const Color(0xFFE3F2FD), // Light blue color
      body: Stack(
        children: [
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // FundRacer Logo
                  Image.asset(
                    'assets/images/fundracer.png',
                    width: 200,
                    height: 200,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'FundRacer',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Run for a Cause',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Powered by Strava at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/api_logo_pwrdBy_strava_stack_orange.png',
                      height: 24,
                    ),
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // If web, wrap in a phone-sized container
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