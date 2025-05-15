import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/strava_service.dart';
import '../services/strava_client_service.dart';
import '../main.dart';
import './onboarding_screen.dart';
import './edit_profile_screen.dart';
import './settings_screen.dart';
import './strava_connect_screen.dart';
import './strava_activities_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/strava_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isStravaConnected = false;
  bool _isConnecting = false;
  late StravaService _stravaService;
  bool _isLoading = false;
  String? _photoUrl;
  String _displayName = 'User';

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initializeUserData();
    _loadUserData();
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
      _isConnecting = true;
    });

    try {
      final authResult = await _stravaService.authenticate();

      if (!mounted) return;

      // Handle different authentication results
      switch (authResult) {
        case StravaAuthResult.success:
          debugPrint('Successfully connected to Strava from profile');
          await _checkStravaConnection();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully connected to Strava'),
              duration: Duration(seconds: 2),
            ),
          );
          break;

        case StravaAuthResult.cancelled:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Strava connection was cancelled'),
              duration: Duration(seconds: 2),
            ),
          );
          break;

        case StravaAuthResult.networkError:
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Network Error'),
              content: const Text(
                  'Please check your internet connection and try again.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          break;

        case StravaAuthResult.timeout:
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Connection Timeout'),
              content: const Text(
                  'The connection to Strava timed out. Please try again later.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          break;

        case StravaAuthResult.failed:
        default:
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Connection Failed'),
              content:
                  const Text('Failed to connect to Strava. Please try again.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          break;
      }
    } catch (e) {
      debugPrint('Error connecting to Strava: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content:
                const Text('Failed to connect to Strava. Please try again.'),
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
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Reload user data to ensure we have the latest
      await user.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;
      if (updatedUser != null && mounted) {
        setState(() {
          _displayName = updatedUser.displayName ?? 'User';
          _photoUrl = updatedUser.photoURL;
        });
      }
    }
  }

  Future<void> _initializeUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _displayName = user.displayName ?? 'User';
        _photoUrl = user.photoURL;
      });
    }
  }

  Widget _buildProfileButton({
    required String text,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    if (text.contains('Strava')) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            if (!_isStravaConnected)
              GestureDetector(
                onTap: onTap,
                child: Image.asset(
                  'assets/images/btn_strava_connect_with_orange_x2.png',
                  height: 48,
                ),
              )
            else
              Column(
                children: [
                  Image.asset(
                    'assets/images/api_logo_pwrdBy_strava_stack_orange.png',
                    height: 24,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () async {
                      final Uri stravaUrl =
                          Uri.parse('https://www.strava.com/dashboard');
                      if (await canLaunchUrl(stravaUrl)) {
                        await launchUrl(stravaUrl,
                            mode: LaunchMode.externalApplication);
                      }
                    },
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: iconColor),
        title: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }

  Widget _buildBadge(Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: color,
          width: 2,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.star,
          color: color,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: _photoUrl != null
            ? Image.network(
                _photoUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.person,
                  size: 50,
                  color: AppColors.primaryBlue,
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                ),
                child: Icon(
                  Icons.person,
                  size: 50,
                  color: AppColors.primaryBlue,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: AppColors.textBlack,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profile',
          style: TextStyle(
            color: AppColors.textBlack,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileImage(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textBlack,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Progress Section
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '42.5 km',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                    Text(
                                      ' total distance',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: AppColors.textGrey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Progress Bar
                                Stack(
                                  children: [
                                    Container(
                                      height: 6,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    Container(
                                      height: 6,
                                      width:
                                          150, // This would be dynamic based on progress
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryBlue,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '7.5 km to next level',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Badges
                            Row(
                              children: [
                                _buildBadge(Colors.blue),
                                const SizedBox(width: 8),
                                _buildBadge(Colors.green),
                                const SizedBox(width: 8),
                                _buildBadge(Colors.orange),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '+3 more',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textGrey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons Section
                _buildProfileButton(
                  text: _isStravaConnected
                      ? 'Connected to Strava'
                      : 'Connect to Strava',
                  icon: Icons.directions_run,
                  iconColor: const Color(0xFFFC4C02),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StravaConnectScreen(),
                      ),
                    ).then((_) => _checkStravaConnection());
                  },
                ),
                if (_isStravaConnected)
                  _buildProfileButton(
                    text: 'View Strava Activities',
                    icon: Icons.bar_chart,
                    iconColor: const Color(0xFFFC4C02),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StravaActivitiesScreen(),
                        ),
                      );
                    },
                  ),
                _buildProfileButton(
                  text: 'Edit Profile',
                  icon: Icons.edit,
                  iconColor: AppColors.primaryBlue,
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfileScreen(),
                      ),
                    );
                    if (result == true) {
                      // Reload user data if profile was updated
                      _loadUserData();
                    }
                  },
                ),
                _buildProfileButton(
                  text: 'Settings',
                  icon: Icons.settings,
                  iconColor: AppColors.primaryBlue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                _buildProfileButton(
                  text: 'Notifications',
                  icon: Icons.notifications,
                  iconColor: AppColors.primaryBlue,
                  onTap: () {
                    // Handle notifications
                  },
                ),
                _buildProfileButton(
                  text: 'Privacy Center',
                  icon: Icons.security,
                  iconColor: AppColors.primaryBlue,
                  onTap: () {
                    // Handle privacy
                  },
                ),
                _buildProfileButton(
                  text: 'Help',
                  icon: Icons.help,
                  iconColor: AppColors.primaryBlue,
                  onTap: () {
                    // Handle help
                  },
                ),
                const SizedBox(height: 20),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const OnboardingScreen()),
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Log Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
}

class ActivityItem extends StatelessWidget {
  final double miles;
  final String date;

  const ActivityItem({
    super.key,
    required this.miles,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFFE51B23),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              '(RED)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          '$miles miles did on $date',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class BarChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE51B23)
      ..style = PaintingStyle.fill;

    // Sample data for the bars (normalized to fit the height)
    final data = [0.3, 0.2, 0.3, 0.2, 0.6, 0.8, 0.4];
    final barWidth = size.width / (data.length * 2);

    for (var i = 0; i < data.length; i++) {
      final barHeight = size.height * data[i];
      final left = i * (size.width / data.length) +
          (size.width / data.length - barWidth) / 2;

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(left, size.height - barHeight, barWidth, barHeight),
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
