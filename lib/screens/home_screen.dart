import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/strava_service.dart';
import '../main.dart';
import 'profile_screen.dart';
import 'run_tracking_screen.dart';
import 'charities_screen.dart';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _steps = 0;
  double _totalDistance = 0;
  int _totalRuns = 0;
  Health? _health;
  bool _isLoading = true;
  late StravaService _stravaService;
  bool _isStravaConnected = false;
  final List<Map<String, dynamic>> _runHistory = [];
  double _totalDonated = 405.0; // Starting with $405 as shown in the screenshot
  double _conversionRate = 10.0; // $10 per km
  String _selectedCharityName = 'Feeding America';

  final List<Map<String, dynamic>> _stories = [
    {
      'color': Color(0xFFFF9838),
      'title': 'Daily Goal',
      'subtitle': '10,000 steps'
    },
    {
      'color': Color(0xFF4CAF50),
      'title': 'New 🎉',
      'subtitle': 'Weekly Challenge'
    },
    {
      'color': Color(0xFF2196F3),
      'title': 'Podcast',
      'subtitle': 'Running Tips'
    },
    {
      'color': Color(0xFFE91E63),
      'title': 'New 🎉',
      'subtitle': 'Achievement'
    },
  ];

  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadSelectedCharity();
    _loadRunHistory();
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    _stravaService = StravaService(prefs);
    
    if (!kIsWeb) {
      _health = Health();
    }
    
    await _requestPermissionsAndFetchData();
    await _checkStravaConnection();
  }

  Future<void> _checkStravaConnection() async {
    final isAuthenticated = await _stravaService.isAuthenticated;
    setState(() {
      _isStravaConnected = isAuthenticated;
    });
    if (isAuthenticated) {
      await _fetchStravaData();
    }
  }

  Future<void> _fetchStravaData() async {
    try {
      final stats = await _stravaService.getAthleteStats();
      setState(() {
        _totalDistance = (stats['total_distance'] as num).toDouble() / 1000; // Convert to km
        _totalRuns = stats['total_runs'] as int;
      });
    } catch (e) {
      print('Error fetching Strava data: $e');
    }
  }

  Future<void> _connectStrava() async {
    try {
      await _stravaService.authenticate();
      await _checkStravaConnection();
    } catch (e) {
      print('Error connecting to Strava: $e');
      // Show error dialog
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
    }
  }

  Future<void> _requestPermissionsAndFetchData() async {
    if (kIsWeb) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Request activity recognition permission on Android
    if (!Platform.isIOS) {
      final status = await Permission.activityRecognition.request();
      if (status.isDenied) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    // Get steps for today
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    try {
      // Request authorization
      final authorized = await _health?.hasPermissions([HealthDataType.STEPS]) ?? false;

      if (authorized) {
        // Fetch steps
        final healthData = await _health?.getHealthDataFromTypes(
          startTime: midnight,
          endTime: now,
          types: [HealthDataType.STEPS],
        );
        
        if (healthData != null && healthData.isNotEmpty) {
          final totalSteps = healthData
              .map((e) => num.tryParse(e.value.toString()) ?? 0)
              .fold<int>(0, (sum, value) => sum + value.toInt());
              
          setState(() {
            _steps = totalSteps;
            _isLoading = false;
          });
        }
      } else {
        final granted = await _health?.requestAuthorization([HealthDataType.STEPS]) ?? false;
        if (granted) {
          await _requestPermissionsAndFetchData();
        }
      }
    } catch (e) {
      debugPrint('Error fetching steps: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadSelectedCharity() async {
    final prefs = await SharedPreferences.getInstance();
    final charity = prefs.getString('selectedCharity');
    if (charity != null) {
      setState(() {
        _selectedCharityName = charity;
      });
    }
  }

  Future<void> _saveSelectedCharity(String charity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedCharity', charity);
    setState(() {
      _selectedCharityName = charity;
    });
  }

  Future<void> _loadRunHistory() async {
    // In a real app, this would fetch from Strava API or local storage
    // For demo purposes, we'll generate some sample data
    if (_runHistory.isEmpty) {
      final now = DateTime.now();
      final random = math.Random();
      
      // Generate 10 run entries for the past 30 days
      for (int i = 0; i < 10; i++) {
        final daysAgo = random.nextInt(30);
        final distance = (random.nextDouble() * 10).roundToDouble();
        final duration = Duration(minutes: (distance * 6).round()); // ~6 min/km pace
        final date = now.subtract(Duration(days: daysAgo));
        
        _runHistory.add({
          'date': date,
          'distance': distance, // km
          'duration': duration,
          'calories': (distance * 65).round(), // ~65 calories per km
          'donation': distance * _conversionRate, // $10 per km
        });
      }
      
      // Sort by most recent
      _runHistory.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      
      // Calculate total donation
      _totalDonated = _runHistory.fold<double>(
        0, (sum, run) => sum + (run['donation'] as double)
      );
      
      setState(() {});
    }
  }

  void _shareToSocialMedia(String platform) {
    String message = 'I\'ve donated \$${_totalDonated.toStringAsFixed(2)} to $_selectedCharityName through my runs with FundRacer! 🏃‍♂️❤️ Join me in making a difference with every step.';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing to $platform: $message'),
        duration: const Duration(seconds: 3),
      ),
    );
    
    // In a real app, you would implement platform-specific sharing here
  }

  void _updateStats(double totalDonations, double totalDistance) {
    setState(() {
      _totalDonated = totalDonations;
      _totalDistance = totalDistance;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildHomeTab(),
      RunTrackingScreen(
        onStatsUpdated: _updateStats,
      ),
      CharitiesScreen(
        onTabChange: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        onCharitySelected: (charity) async {
          setState(() {
            _selectedCharityName = charity['name'] as String;
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('selectedCharity', charity['name'] as String);
        },
      ),
    ];

    return MaterialApp(
      debugShowCheckedModeBanner: false,  // Remove the debug banner
      home: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('FundRacer'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: screens,
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      backgroundColor: AppColors.primaryBlue,
      selectedItemColor: AppColors.white,
      unselectedItemColor: AppColors.white.withOpacity(0.6),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.directions_run),
          label: 'Runs',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.favorite),
          label: 'Charity',
        ),
      ],
    );
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildStoriesSection(),
          _buildDonationSummary(), 
          _buildRecentActivitySection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lightBlue,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${FirebaseAuth.instance.currentUser?.displayName?.split(' ').first ?? 'Runner'}!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Let\'s make an impact today',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIndex = 2;  // Switch to the Charity tab
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(maxWidth: 150), // Limit the width
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // Make row wrap its content
                    children: [
                      Icon(
                        Icons.favorite,
                        color: AppColors.primaryBlue,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _selectedCharityName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textBlack,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem(
                  title: '$_steps',
                  subtitle: 'Steps Today',
                  icon: Icons.directions_walk,
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: AppColors.lightBlue,
                ),
                _buildInfoItem(
                  title: '${_totalDistance.toStringAsFixed(1)} km',
                  subtitle: 'Total Distance',
                  icon: Icons.straighten,
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: AppColors.lightBlue,
                ),
                _buildInfoItem(
                  title: '$_totalRuns',
                  subtitle: 'Total Runs',
                  icon: Icons.directions_run,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppColors.primaryBlue,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.deepBlue,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildStoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Activities For You',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.deepBlue,
            ),
          ),
        ),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _stories.length,
            itemBuilder: (context, index) {
              final story = _stories[index];
              return Container(
                width: 120,
                margin: const EdgeInsets.only(right: 12, bottom: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: story['color'] as Color,
                  boxShadow: [
                    BoxShadow(
                      color: (story['color'] as Color).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        story['title'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (story['subtitle'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          story['subtitle'] as String,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDonationSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4A67FF).withOpacity(0.8),
            const Color(0xFF4A67FF),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Donated',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${_totalDonated.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'to $_selectedCharityName',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withOpacity(0.3),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Distance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_totalDistance.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.directions_run,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_totalRuns runs',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Every 1 km = \$10 donation',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Runs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepBlue,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to runs history page
                  setState(() {
                    _selectedIndex = 1;
                  });
                },
                child: Text(
                  'See All',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        _runHistory.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.directions_run,
                        size: 48,
                        color: AppColors.lightBlue,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No runs yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start your first run to make an impact',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textGrey,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RunTrackingScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.directions_run),
                        label: const Text('Start Running'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _runHistory.length > 3 ? 3 : _runHistory.length, // Show only 3 most recent runs
                itemBuilder: (context, index) {
                  final run = _runHistory[index];
                  final date = run['date'] as DateTime;
                  final distance = run['distance'] as double;
                  final duration = run['duration'] as Duration;
                  final donation = run['donation'] as double;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.lightBlue,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.directions_run,
                              color: AppColors.primaryBlue,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${date.day}/${date.month}/${date.year}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textBlack,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${distance.toStringAsFixed(1)} km • ${duration.inMinutes} min',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${donation.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Donated',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }
} 