import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/strava_service.dart';
import '../main.dart';
import 'profile_screen.dart';
import 'run_tracking_screen.dart';
import 'charities_screen.dart';
import 'dart:math' as math;
import 'dart:convert' show json;
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../providers/metric_provider.dart';
import '../models/badge.dart' as achievement;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  final Function(double totalDonations, double totalDistance)? onStatsUpdated;
  final List<Map<String, dynamic>> donatedActivities;
  final Map<String, double> activityRates;

  const HomeScreen({
    super.key,
    this.onStatsUpdated,
    this.donatedActivities = const [],
    this.activityRates = const {},
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _steps = 0;
  double _totalDistance = 0;
  int _totalRuns = 0;
  int _weeklyRuns = 0;
  double _weeklyDistance = 0;
  double _weeklyDonations = 0;
  Health? _health;
  bool _isLoading = true;
  late StravaService _stravaService;
  bool _isStravaConnected = false;
  final List<Map<String, dynamic>> _runHistory = [];
  double _totalDonated = 0;
  double _conversionRate = 10.0; // Default rate per km
  String _selectedCharityName = 'Feeding America';
  Map<String, double> _activityRates = {};
  List<Map<String, dynamic>> _recentDonatedRuns = [];

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadSelectedCharity();
    _loadStats();
    _loadDonatedRuns();
    _loadWeeklyStats();
    _activityRates = Map<String, double>.from(widget.activityRates);
    RunTrackingScreen.onStatsUpdated = _updateStats;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadStats();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    _stravaService = StravaService(prefs);
    
    if (!kIsWeb) {
      _health = Health();
    }
    
    await _requestPermissionsAndFetchData();
    await _checkStravaConnection();
    await _loadDonatedActivitiesStats();
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
      final metricProvider = Provider.of<MetricProvider>(context, listen: false);
      setState(() {
        _totalDistance = metricProvider.convertDistance((stats['total_distance'] as num).toDouble());
        _totalRuns = stats['total_runs'] as int;
      });
    } catch (e) {
      print('Error fetching Strava data: $e');
    }
  }

  Future<void> _connectStrava() async {
    try {
      final authResult = await _stravaService.authenticate();
      
      if (!mounted) return;
      
      // Handle different authentication results
      switch (authResult) {
        case StravaAuthResult.success:
          debugPrint('Successfully connected to Strava from home screen');
          await _checkStravaConnection();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Successfully connected to Strava'),
                duration: Duration(seconds: 2),
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

  Future<void> _loadDonatedActivitiesStats() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final activities = widget.donatedActivities;
    final activityRates = widget.activityRates;
    
    // Load existing totals from SharedPreferences
    final String userKey = 'user_${user.uid}';
    _totalDonated = prefs.getDouble('${userKey}_total_donated') ?? 0.0;
    _totalDistance = prefs.getDouble('${userKey}_total_distance') ?? 0.0;
    
    // Get the list of already processed activities
    final processedActivities = prefs.getStringList('${userKey}_processed_activities') ?? [];
    
    if (activities.isNotEmpty) {
      double newDonations = 0;
      double newDistance = 0;
      final List<String> newProcessedActivities = List.from(processedActivities);
      
      for (var activity in activities) {
        final activityId = activity['id'].toString();
        // Only process activities we haven't counted before
        if (!processedActivities.contains(activityId)) {
          final bool isActivityMetric = activity['is_metric'] != null ? activity['is_metric'] as bool : true;
          final conversionFactor = isActivityMetric ? 1000.0 : 1609.34;
          final distance = (activity['distance'] as num).toDouble() / conversionFactor;
          final rate = activityRates[activityId] ?? 10.0;
          
          // Always convert distance to kilometers for consistent storage
          final distanceInKm = isActivityMetric ? distance : distance * 1.60934;
          
          newDonations += distance * rate;
          newDistance += distanceInKm;
          newProcessedActivities.add(activityId);
        }
      }
      
      // Update totals with new activities
      final updatedTotalDonated = _totalDonated + newDonations;
      final updatedTotalDistance = _totalDistance + newDistance;
      
      // Save updated totals and processed activities list
      await prefs.setDouble('${userKey}_total_donated', updatedTotalDonated);
      await prefs.setDouble('${userKey}_total_distance', updatedTotalDistance);
      await prefs.setStringList('${userKey}_processed_activities', newProcessedActivities);
      
      if (mounted) {
        setState(() {
          _totalDonated = updatedTotalDonated;
          _totalDistance = updatedTotalDistance;
          _runHistory.clear(); // Clear sample data since we have real data
        });
      }
    }

    // Also update from RunTrackingScreen's static list
    if (RunTrackingScreen.donatedActivities.isNotEmpty) {
      double totalDonations = 0;
      double totalDistance = 0;

      for (var activity in RunTrackingScreen.donatedActivities) {
        totalDonations += activity['donation_amount'] as double;
        totalDistance += (activity['distance'] as num).toDouble() / 1000; // Convert to km
      }

      if (mounted) {
        setState(() {
          _totalDonated = totalDonations;
          _totalDistance = totalDistance;
        });
      }

      // Update SharedPreferences with the latest totals
      await prefs.setDouble('${userKey}_total_donated', totalDonations);
      await prefs.setDouble('${userKey}_total_distance', totalDistance);
    }
  }

  Future<void> _resetUserStats() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String userKey = 'user_${user.uid}';
    await prefs.remove('${userKey}_total_donated');
    await prefs.remove('${userKey}_total_distance');
    await prefs.remove('${userKey}_processed_activities');
  }

  Future<void> _loadRunHistory() async {
    // In a real app, this would fetch from Strava API or local storage
    // For demo purposes, we'll generate some sample data
    final prefs = await SharedPreferences.getInstance();
    final donatedIds = prefs.getStringList('donated_activity_ids') ?? [];
    
    // Only load sample data if there are no real donated activities
    if (_runHistory.isEmpty && donatedIds.isEmpty) {
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

  void _shareProgress() {
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    String message = 'I\'ve donated ${currencyProvider.currencySymbol}${_totalDonated.toStringAsFixed(2)} to $_selectedCharityName through my runs with FundRacer! 🏃‍♂️❤️ Join me in making a difference with every step.';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing to social media: $message'),
        duration: const Duration(seconds: 3),
      ),
    );
    
    // In a real app, you would implement platform-specific sharing here
  }

  Future<void> _loadStats() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String userKey = 'user_${user.uid}';
    
    try {
      // Get donated activities from Firestore instead of SharedPreferences
      final donatedRunsDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('donated_runs')
          .orderBy('donation_date', descending: true)
          .get();

      final activities = donatedRunsDoc.docs.map((doc) => doc.data()).toList();
      
      if (activities.isNotEmpty) {
        // Calculate total donations and distance from all activities
        double newTotalDonated = 0;
        double newTotalDistance = 0;
        
        for (var activity in activities) {
          newTotalDonated += activity['donation_amount'] as double;
          newTotalDistance += (activity['distance'] as num).toDouble() / 1000;
        }

        if (mounted) {
          setState(() {
            _totalDonated = newTotalDonated;
            _totalDistance = newTotalDistance;
            _recentDonatedRuns = activities.take(3).toList();
          });
        }

        // Update SharedPreferences with the latest totals
        await prefs.setDouble('${userKey}_total_donated', newTotalDonated);
        await prefs.setDouble('${userKey}_total_distance', newTotalDistance);
      }
    } catch (e) {
      print('Error loading stats: $e');
    }
  }

  void _updateStats(double totalDonations, double totalDistance) async {
    if (!mounted) return;
    
    // Update the totals immediately
    setState(() {
      _totalDonated = totalDonations;
      _totalDistance = totalDistance;
    });
    
    // Load weekly stats after updating
    await _loadWeeklyStats();
    
    // Fetch the latest runs from Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final donatedRunsDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('donated_runs')
            .orderBy('donation_date', descending: true)
            .limit(3)  // Only get the 3 most recent runs
            .get();

        if (mounted) {
          setState(() {
            _recentDonatedRuns = donatedRunsDoc.docs.map((doc) => doc.data()).toList();
          });
        }
      } catch (e) {
        print('Error updating recent runs: $e');
      }
    }
  }

  Future<void> _loadDonatedRuns() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final donatedRunsDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('donated_runs')
          .orderBy('donation_date', descending: true)
          .get();

      final runs = donatedRunsDoc.docs.map((doc) => doc.data()).toList();
      
      if (mounted) {
        setState(() {
          RunTrackingScreen.donatedActivities = runs;
          _recentDonatedRuns = runs.take(3).toList();
        });
      }
    } catch (e) {
      print('Error loading donated runs: $e');
    }
  }

  Future<void> _saveDonatedRun(Map<String, dynamic> activity) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('donated_runs')
          .doc(activity['id'].toString())
          .set({
        ...activity,
        'user_id': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Immediately reload stats after saving
      await _loadStats();
      await _loadDonatedRuns();
    } catch (e) {
      print('Error saving donated run: $e');
    }
  }

  Future<void> _loadWeeklyStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get current week's start date (Sunday)
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday % 7));
      final startDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
      
      // Get weekly runs from Firestore
      final weeklyRunsDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('donated_runs')
          .where('start_date', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .get();

      final runs = weeklyRunsDoc.docs.map((doc) => doc.data()).toList();
      
      if (runs.isNotEmpty) {
        double totalDistance = 0;
        double totalDonations = 0;
        
        for (var run in runs) {
          totalDistance += (run['distance'] as num).toDouble() / 1000; // Convert to km
          totalDonations += run['donation_amount'] as double;
        }
        
        if (mounted) {
          setState(() {
            _weeklyRuns = runs.length;
            _weeklyDistance = totalDistance;
            _weeklyDonations = totalDonations;
          });
        }
      }
    } catch (e) {
      print('Error loading weekly stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('FundRacer'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          RunTrackingScreen(
            onActivityDonated: (activity, rate) async {
              await _saveDonatedRun(activity);
              await _loadDonatedActivitiesStats();
              await _loadStats();
              await _loadDonatedRuns();
              if (mounted) {
                setState(() {});
              }
            },
            onPaymentComplete: () async {
              await _loadDonatedActivitiesStats();
              await _loadStats();
              await _loadDonatedRuns();
              if (mounted) {
                setState(() {});
              }
            },
          ),
          CharitiesScreen(
            onTabChange: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            onCharitySelected: (charity) {
              setState(() {
                _selectedCharityName = charity['name'];
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run),
            label: 'Run',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Charities',
          ),
        ],
        selectedItemColor: AppColors.primaryBlue,
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildBadgesSection(),
          _buildDonationSummary(), 
          _buildRecentRunsSection(),
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
            children: [
              Expanded(
                child: Column(
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
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIndex = 2;  // Switch to the Charity tab
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite,
                        color: AppColors.primaryBlue,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.3, // 30% of screen width
                        ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This Week\'s Stats',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textBlack,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildInfoItem(
                      title: '$_weeklyRuns',
                      subtitle: 'Runs',
                      icon: Icons.directions_run,
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: AppColors.lightBlue,
                    ),
                    _buildInfoItem(
                      title: '${_weeklyDistance.toStringAsFixed(1)} km',
                      subtitle: 'Distance',
                      icon: Icons.straighten,
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: AppColors.lightBlue,
                    ),
                    _buildInfoItem(
                      title: '${Provider.of<CurrencyProvider>(context).currencySymbol}${_weeklyDonations.toStringAsFixed(0)}',
                      subtitle: 'Donated',
                      icon: Icons.volunteer_activism,
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: AppColors.lightBlue,
                    ),
                    _buildInfoItem(
                      title: '${Provider.of<CurrencyProvider>(context).currencySymbol}${(_weeklyDonations * 2).toStringAsFixed(0)}',
                      subtitle: 'Impact',
                      icon: Icons.monetization_on,
                    ),
                  ],
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
    final metricProvider = Provider.of<MetricProvider>(context);
    if (subtitle == 'Weekly Distance') {
      title = '${_weeklyDistance.toStringAsFixed(1)} ${metricProvider.distanceUnit}';
    }
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

  Widget _buildBadgesSection() {
    final badges = achievement.Badge.getAllBadges();
    final earnedBadges = _getEarnedBadges();
    final nextBadges = _getNextBadges();
    final metricProvider = Provider.of<MetricProvider>(context);
    
    // Calculate total progress for the current level
    final currentLevelBadge = nextBadges.isNotEmpty ? nextBadges[0] : null;
    final progress = currentLevelBadge != null ? _getBadgeProgress(currentLevelBadge) : 0.0;
    final remainingDistance = currentLevelBadge != null 
      ? (currentLevelBadge.requirement - _totalDistance).toStringAsFixed(1)
      : "0";

              return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
        color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
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
                    'Level Progress',
                    style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                      color: AppColors.textBlack,
                        ),
                      ),
                        const SizedBox(height: 4),
                  Row(
                    children: [
                        Text(
                        '${_totalDistance.toStringAsFixed(1)} ${metricProvider.distanceUnit}',
                        style: TextStyle(
                            fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      Text(
                        ' total distance',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textGrey,
                          ),
                        ),
                      ],
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  // TODO: Navigate to detailed badges screen
                },
                icon: Icon(
                  Icons.emoji_events,
                  color: AppColors.primaryBlue,
                  size: 18,
                ),
                label: Text(
                  'View All',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
          ),
        ),
      ],
          ),
          const SizedBox(height: 12),
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
                width: MediaQuery.of(context).size.width * progress,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (currentLevelBadge != null)
            Text(
              '$remainingDistance ${metricProvider.distanceUnit} to ${currentLevelBadge.name}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textGrey,
              ),
            ),
          const SizedBox(height: 12),
          // Earned Badges
          if (earnedBadges.isNotEmpty)
            Row(
              children: [
                ...earnedBadges.take(3).map((badge) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: badge.levelColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: badge.levelColor,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        badge.icon,
                        color: badge.color,
                        size: 16,
                      ),
                    ),
                  ),
                )).toList(),
                if (earnedBadges.length > 3)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '+${earnedBadges.length - 3} more',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            )
          else
            Row(
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 16,
                  color: AppColors.textGrey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Complete runs to earn badges',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<achievement.Badge> _getEarnedBadges() {
    final badges = achievement.Badge.getAllBadges();
    return badges.where((badge) {
      switch (badge.type) {
        case 'distance':
          return _totalDistance >= badge.requirement;
        case 'donations':
          return _totalDonated >= badge.requirement;
        case 'runs':
          return _totalRuns >= badge.requirement.toInt();
        default:
          return false;
      }
    }).toList();
  }

  List<achievement.Badge> _getNextBadges() {
    final badges = achievement.Badge.getAllBadges();
    final earnedBadges = _getEarnedBadges();
    
    // Get the next unearned badge for each type
    final nextBadges = <achievement.Badge>[];
    for (final type in ['distance', 'donations', 'runs']) {
      final typeBadges = badges.where((b) => b.type == type).toList()
        ..sort((a, b) => a.requirement.compareTo(b.requirement));
      
      final nextBadge = typeBadges.firstWhere(
        (badge) {
          switch (badge.type) {
            case 'distance':
              return _totalDistance < badge.requirement;
            case 'donations':
              return _totalDonated < badge.requirement;
            case 'runs':
              return _totalRuns < badge.requirement.toInt();
            default:
              return false;
          }
        },
        orElse: () => typeBadges.last,
      );
      
      if (!earnedBadges.contains(nextBadge)) {
        nextBadges.add(nextBadge);
      }
    }
    
    return nextBadges;
  }

  double _getBadgeProgress(achievement.Badge badge) {
    switch (badge.type) {
      case 'distance':
        return (_totalDistance / badge.requirement).clamp(0.0, 1.0);
      case 'donations':
        return (_totalDonated / badge.requirement).clamp(0.0, 1.0);
      case 'runs':
        return (_totalRuns / badge.requirement).clamp(0.0, 1.0);
      default:
        return 0.0;
    }
  }

  Widget _buildDonationSummary() {
    final metricProvider = Provider.of<MetricProvider>(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final totalImpact = _totalDonated * 2; // Include FundRacer match

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
                      'Total Impact',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${currencyProvider.currencySymbol}${totalImpact.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
                      '${_totalDistance.toStringAsFixed(1)} ${metricProvider.distanceUnit}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRunsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Runs',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 1; // Switch to Run tab
                  });
                  // Access the RunTrackingScreen's tab controller through the current state
                  final runTrackingState = RunTrackingScreen.currentState;
                  if (runTrackingState != null) {
                    runTrackingState.tabController.animateTo(1); // Switch to Donated tab
                  }
                },
                child: const Text('See All'),
              ),
            ],
          ),
          if (_recentDonatedRuns.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'No donated runs yet. Start your first run!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            )
          else
            Column(
              children: _recentDonatedRuns.map((activity) {
                return _buildActivityCard(activity);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final metricProvider = Provider.of<MetricProvider>(context);
    final distance = (activity['distance'] as num).toDouble() / 1000;
    final formattedDistance = metricProvider.isMetric
        ? '${distance.toStringAsFixed(2)} km'
        : '${(distance * 0.621371).toStringAsFixed(2)} mi';
    final donationAmount = activity['donation_amount'] as double;
    final totalImpact = donationAmount * 2; // User donation + FundRacer match

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showDonationDetails(context, activity),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${activity['charity']['name']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.volunteer_activism,
                          size: 16,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${currencyProvider.currencySymbol}${totalImpact.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.straighten,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formattedDistance,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM d').format(DateTime.parse(activity['start_date'])),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.touch_app,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tap for details',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDonationDetails(BuildContext context, Map<String, dynamic> activity) {
    // Use the RunTrackingScreen's public method to show donation details
    RunTrackingScreen.showDonationDetails(context, activity);
  }
  
  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
} 