import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import '../widgets/screen_layout.dart';
import 'dart:async';  // Add Timer import
import 'email_auth_screen.dart';  // Add import for EmailAuthScreen
import '../main.dart';  // Import for AppColors

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  final List<Map<String, String>> _slides = [
    {
      'title': '*** TEST SLIDE ***\nSLIDE 1 of 5\nWAIT 3 SECONDS',
      'subtitle': 'This is a test slide - swipe or wait',
      'image': 'assets/images/running_vector.png',
    },
    {
      'title': 'MAKE YOUR MILES\nCOUNT FOR A\nGOOD CAUSE',
      'subtitle': 'Start making a difference',
      'image': 'assets/images/running_vector.png',
    },
    {
      'title': 'TRANSFORM YOUR\nRUNS INTO\nDONATIONS',
      'subtitle': 'Every step counts',
      'image': 'assets/images/running_vector.png',
    },
    {
      'title': 'JOIN A COMMUNITY\nOF IMPACT\nRUNNERS',
      'subtitle': 'Run together, change together',
      'image': 'assets/images/running_vector.png',
    },
    {
      'title': 'TRACK YOUR\nCHARITABLE\nIMPACT',
      'subtitle': 'See your difference grow',
      'image': 'assets/images/running_vector.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Start the timer when the screen initializes
    _startTimer();
  }

  void _startTimer() {
    // Cancel any existing timer
    _timer?.cancel();
    
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_currentPage < _slides.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _handlePhoneSignIn() {
    // TODO: Implement phone sign in
  }

  void _handleEmailSignIn() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EmailAuthScreen()),
    );
  }

  void _handleAltSignIn() {
    // TODO: Implement alternative sign in
  }

  void _handleTermsClick() {
    // TODO: Navigate to terms screen
  }

  void _handlePrivacyClick() {
    // TODO: Navigate to privacy screen
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: SizedBox(
            height: size.height - padding.top - padding.bottom,
            child: Column(
              children: [
                SizedBox(height: padding.top > 20 ? 20 : 0),
                Expanded(
                  flex: 3,
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (int page) {
                      setState(() {
                        _currentPage = page;
                      });
                      // Reset timer when page is manually changed
                      _startTimer();
                    },
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTapDown: (_) {
                          _timer?.cancel();  // Pause timer when user taps
                        },
                        onTapUp: (_) {
                          _startTimer();  // Resume timer when user releases
                        },
                        child: Container(
                          width: size.width,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _slides[index]['title']!,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                  color: AppColors.deepBlue,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: size.height * 0.22,
                                child: Image.asset(
                                  _slides[index]['image']!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Text(
                                _slides[index]['subtitle']!,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Page indicator dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? AppColors.primaryBlue
                            : AppColors.primaryBlue.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: size.width,
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _handleEmailSignIn,
                              borderRadius: BorderRadius.circular(30),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.email,
                                    color: AppColors.primaryBlue,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Sign in with Email',
                                    style: TextStyle(
                                      color: AppColors.textBlack,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Sign in with',
                          style: TextStyle(
                            color: AppColors.deepBlue,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildSocialIconButton(Icons.apple),
                            _buildSocialIconButton(Icons.facebook),
                            _buildSocialIconButton(Icons.g_mobiledata, size: 40),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _handlePhoneSignIn,
                              borderRadius: BorderRadius.circular(30),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.phone,
                                    color: AppColors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Sign in with Phone',
                                    style: TextStyle(
                                      color: AppColors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            text: 'By continuing, you agree to our ',
                            style: TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 12,
                            ),
                            children: [
                              TextSpan(
                                text: 'Terms of Service',
                                style: TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = _handleTermsClick,
                              ),
                              const TextSpan(
                                text: ' and ',
                              ),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = _handlePrivacyClick,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialIconButton(IconData icon, {double size = 30}) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleAltSignIn,
          borderRadius: BorderRadius.circular(30),
          child: Icon(
            icon,
            size: size,
            color: AppColors.primaryBlue,
          ),
        ),
      ),
    );
  }
} 