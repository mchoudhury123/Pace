import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../providers/currency_provider.dart';
import '../providers/metric_provider.dart';
import '../services/strava_service.dart';
import '../main.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'run_intention_screen.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'charities_screen.dart';
import 'home_screen.dart';
import 'payment_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Add notification service initialization
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class RunTrackingScreen extends StatefulWidget {
  static _RunTrackingScreenState? currentState;
  static List<Map<String, dynamic>> donatedActivities = [];
  static Map<String, int> activityRates = {};
  static Function? onActivitiesUpdated;
  static Function(double totalDonations, double totalDistance)? onStatsUpdated;
  static DateTime? lastRunStartTime;
  static bool isDevMode = true; // Add development mode flag

  final Function(Map<String, dynamic>, int) onActivityDonated;
  final Function() onPaymentComplete;
  final int initialTabIndex;

  const RunTrackingScreen({
    Key? key,
    required this.onActivityDonated,
    required this.onPaymentComplete,
    this.initialTabIndex = 0,
  }) : super(key: key);

  // Public method to show donation details from any screen
  static void showDonationDetails(BuildContext context, Map<String, dynamic> activity) {
    if (currentState != null) {
      currentState!._showDonationDetailsDialog(activity);
    } else {
      print("RunTrackingScreen state is not available");
    }
  }

  @override
  _RunTrackingScreenState createState() => _RunTrackingScreenState();
}

class _RunTrackingScreenState extends State<RunTrackingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final StravaService _stravaService;
  List<Map<String, dynamic>> _activities = [];
  Set<String> _donatedActivityIds = {};
  bool _isMetric = true;
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasActiveRun = false;
  double _selectedRate = 0.0;
  int _ratePerUnit = 10;
  int _selectedIndex = 0;
  Map<String, dynamic>? _savedCharity;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TabController get tabController => _tabController;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    RunTrackingScreen.currentState = this;
    _loadSavedRuns();
    _loadSelectedCharity();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _startNewRun,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.directions_run, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Start Run',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
            Row(
              children: [
                      IconButton(
                        icon: Icon(
                          Icons.bug_report,
                          color: RunTrackingScreen.isDevMode ? Colors.amber : Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            RunTrackingScreen.isDevMode = !RunTrackingScreen.isDevMode;
                          });
                        },
                        tooltip: RunTrackingScreen.isDevMode ? 'Development Mode On' : 'Development Mode Off',
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _isRefreshing ? null : _refreshActivities,
                        tooltip: 'Refresh Activities',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildNotDonatedTab(),
                  _buildDonatedTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Not Donated'),
          Tab(text: 'Donated'),
        ],
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 16,
        ),
        indicatorWeight: 3,
      ),
    );
  }

  Widget _buildNotDonatedTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final notDonatedActivities = _activities.where((activity) {
      return !RunTrackingScreen.donatedActivities
          .any((donated) => donated['id'] == activity['id']);
    }).toList();

    if (notDonatedActivities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.directions_run_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No runs available for donation',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notDonatedActivities.length,
      itemBuilder: (context, index) {
        final activity = notDonatedActivities[index];
        return _buildActivityCard(activity);
      },
    );
  }

  Widget _buildDonatedTab() {
    if (RunTrackingScreen.donatedActivities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.volunteer_activism_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No donated runs yet',
              style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: RunTrackingScreen.donatedActivities.length,
      itemBuilder: (context, index) {
        final activity = RunTrackingScreen.donatedActivities[index];
        return _buildDonatedActivityCard(activity);
      },
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    // Check if this activity is in the donated runs
    final donatedActivity = RunTrackingScreen.donatedActivities
        .firstWhere(
          (donated) => donated['id'].toString() == activity['id'].toString(),
          orElse: () => {'id': ''}, // Default empty map for non-donated runs
        );
    final isDonated = donatedActivity['id'] != '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          if (isDonated) {
            // Show donation details for donated runs using the actual donated activity data
            _showDonationDetailsDialog(donatedActivity);
          } else {
            // Show regular run details for non-donated runs
            _showRunDetailsDialog(activity);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(activity['start_date']),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isDonated)
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
                            '${Provider.of<CurrencyProvider>(context, listen: false).currencySymbol}${donatedActivity['donation_amount'].toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => _showDonationDialog(activity),
                      child: const Text('Donate'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Distance: ${_formatDistance(activity['distance'])}',
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                'Duration: ${_formatDuration(activity['moving_time'])}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDonatedActivityCard(Map<String, dynamic> activity) {
    final donationDate = DateTime.parse(activity['donation_date']);
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final donationAmount = (activity['donation_amount'] as double).toStringAsFixed(2);
    final totalImpact = (double.parse(donationAmount) * 2).toStringAsFixed(2);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showDonationDetailsDialog(activity),
        child: Padding(
          padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                    _formatDate(activity['start_date']),
                    style: const TextStyle(
                      fontSize: 16,
                fontWeight: FontWeight.bold,
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
                          '${currencyProvider.currencySymbol}$totalImpact',
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
              Text(
                'Distance: ${_formatDistance(activity['distance'])}',
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                'Donated on ${DateFormat('MMM d, y').format(donationDate)}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
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
                    'Tap to see donation details',
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

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return DateFormat('EEEE, MMM d, y').format(date);
  }

  String _formatDistance(double distance) {
    if (_isMetric) {
      return '${(distance / 1000).toStringAsFixed(2)} km';
    } else {
      return '${(distance / 1609.34).toStringAsFixed(2)} miles';
    }
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else {
      return '${minutes}m ${secs}s';
    }
  }

  Future<void> _startNewRun() async {
    // Check if a charity is selected
    if (_savedCharity == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select a Charity'),
          content: const Text('Please select a charity before starting a run.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Navigate to Charities screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CharitiesScreen(
                      onCharitySelected: (charity) async {
                        setState(() {
                          _savedCharity = charity;
                        });
                        // Save the selected charity
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('selectedCharity', charity['name']);
                        // Start the run after selecting charity
                        _continueStartRun();
                      },
                      onTabChange: (index) {},
                    ),
                  ),
                );
              },
              child: const Text('Select Charity'),
            ),
          ],
        ),
      );
      return;
    }

    _continueStartRun();
  }

  Future<void> _continueStartRun() async {
    if (RunTrackingScreen.isDevMode) {
      final rate = await Navigator.push<double>(
        context,
        MaterialPageRoute(
          builder: (context) => const RunIntentionScreen(),
        ),
      );

      if (rate != null) {
        setState(() {
          _selectedRate = rate;
          RunTrackingScreen.lastRunStartTime = DateTime.now();
        });
        _showRunDetectedDialog(_generateTestActivity());
      }
      return;
    }

    if (!(await _stravaService.isAuthenticated)) {
      _showStravaAuthDialog();
      return;
    }

    final rate = await Navigator.push<double>(
      context,
      MaterialPageRoute(
        builder: (context) => const RunIntentionScreen(),
      ),
    );

    if (rate != null) {
      setState(() {
        _selectedRate = rate;
        RunTrackingScreen.lastRunStartTime = DateTime.now();
      });
    }
  }

  Map<String, dynamic> _generateTestActivity() {
    final random = Random();
    final now = DateTime.now();
    
    // Generate random distance between 2-10 km (in meters)
    final distance = (random.nextDouble() * 8000 + 2000);
    
    // Generate random duration between 15-60 minutes (in seconds)
    final duration = random.nextInt(2700) + 900;
    
    // Calculate average speed (meters per second)
    final averageSpeed = distance / duration;

    return {
      'id': 'test_${now.millisecondsSinceEpoch}',
      'name': 'Test Run',
      'distance': distance,
      'moving_time': duration,
      'average_speed': averageSpeed,
      'start_date': now.toIso8601String(),
      'type': 'Run'
    };
  }

  Future<void> _refreshActivities() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final activities = await _stravaService.getRecentActivities();
      setState(() {
        _activities = activities;
      });

      if (RunTrackingScreen.lastRunStartTime != null) {
        final newRuns = activities.where((activity) {
          final activityDate = DateTime.parse(activity['start_date']);
          return activityDate.isAfter(RunTrackingScreen.lastRunStartTime!);
        }).toList();

        if (newRuns.isNotEmpty) {
          _showRunDetectedDialog(newRuns.first);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch activities: $e')),
      );
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  void _showStravaAuthDialog() {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
        title: const Text('Connect with Strava'),
        content: const Text('You need to connect with Strava to start a new run.'),
                        actions: [
                          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _stravaService.authenticate();
                _startNewRun();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to authenticate: $e')),
                );
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _showRunDetectedDialog(Map<String, dynamic> activity) {
    final distance = activity['distance'] as double;
    final metricProvider = Provider.of<MetricProvider>(context, listen: false);
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final isMetric = metricProvider.isMetric;
    
    // Update _isMetric state to match provider
    setState(() {
      _isMetric = isMetric;
    });
    
    final donationAmount = isMetric
        ? (distance / 1000) * _selectedRate
        : (distance / 1609.34) * _selectedRate;

    // Create an activity with donation details
    final activityWithDonation = {
      ...activity,
      'donation_amount': donationAmount,
      'donation_date': DateTime.now().toIso8601String(),
      'rate': _selectedRate,
      'charity': _savedCharity,
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Donation Details',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Run Details section
            const Text(
              'Run Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text('Date: ${DateFormat('d/M/y').format(DateTime.parse(activity['start_date']))}'),
            Text('Distance: ${_formatDistance(distance)}'),
            Text('Duration: ${_formatDuration(activity['moving_time'])}'),
            Text('Rate: ${currencyProvider.currencySymbol}${_selectedRate.toStringAsFixed(1)} per km'),
            
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.favorite, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text(
                  _savedCharity?['name'] ?? 'Save the Children',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Donation Breakdown section
            const Text(
              'Donation Breakdown',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Your donation:'),
                Text(
                  '${currencyProvider.currencySymbol}${donationAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('FundRacer match:'),
                Text(
                  '${currencyProvider.currencySymbol}${donationAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Impact:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${currencyProvider.currencySymbol}${(donationAmount * 2).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToPayment(activityWithDonation, donationAmount);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Proceed to Payment',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToPayment(
    Map<String, dynamic> activity,
    double donationAmount,
  ) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          key: Key('payment_${activity['id']}'),
          activity: activity,
          donationAmount: donationAmount,
          selectedRate: _selectedRate,
          onPaymentComplete: widget.onPaymentComplete,
        ),
      ),
    );

    if (result == true) {
      _showThankYouDialog(activity, donationAmount);
    }
  }

  Future<void> _loadSelectedCharity() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedCharityName = prefs.getString('selectedCharity');
    if (selectedCharityName != null) {
      final charity = CharitiesScreen.charities.firstWhere(
        (charity) => charity['name'] == selectedCharityName,
        orElse: () => CharitiesScreen.charities.first,
      );
      if (mounted) {
        setState(() {
          _savedCharity = charity;
        });
      }
    }
  }

  void _showThankYouDialog(Map<String, dynamic> activity, double donationAmount) {
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final totalImpact = donationAmount * 2;
    
    // Ensure we have the latest selected charity
    _loadSelectedCharity();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: EdgeInsets.zero,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.favorite,
                        color: Colors.blue[700],
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Thank You!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Charity section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.favorite,
                              color: Colors.blue[700],
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Selected Charity',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _savedCharity?['name'] ?? 'Loading...',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Donation Impact section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[100]!),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Your donation:',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${currencyProvider.currencySymbol}${donationAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'FundRacer match:',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${currencyProvider.currencySymbol}${donationAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Impact:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${currencyProvider.currencySymbol}${totalImpact.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Create a serializable version of the charity data
              final serializableCharity = _savedCharity != null ? {
                'name': _savedCharity!['name'],
                'description': _savedCharity!['description'],
                'category': _savedCharity!['category'],
                'website': _savedCharity!['website'],
              } : null;
              
              // Create the new activity entry
              final newActivity = {
                ...activity,
                'donation_amount': donationAmount,
                'donation_date': DateTime.now().toIso8601String(),
                'charity': serializableCharity,
              };

              try {
                // First, save to Firestore
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await _firestore
                      .collection('users')
                      .doc(user.uid)
                      .collection('donated_runs')
                      .doc(newActivity['id'].toString())
                      .set(newActivity);
                }
                
                // Add to the static list
                setState(() {
                  RunTrackingScreen.donatedActivities.insert(0, newActivity);
                });
                
                // Save to persistent storage and update stats
                await _saveDonatedActivities();
                
                // Calculate new totals
                double totalDonations = 0;
                double totalDistance = 0;
                for (var activity in RunTrackingScreen.donatedActivities) {
                  totalDonations += activity['donation_amount'] as double;
                  totalDistance += (activity['distance'] as num).toDouble() / 1000;
                }
                
                // Update HomeScreen stats
                if (RunTrackingScreen.onStatsUpdated != null) {
                  RunTrackingScreen.onStatsUpdated!(totalDonations, totalDistance);
                }
                
                // Notify parent of the new donation
                widget.onActivityDonated(newActivity, _selectedRate.toInt());
                
                // Force immediate refresh of stats and UI
                widget.onPaymentComplete();
                
                // Force tab refresh
                setState(() {});

              } catch (e) {
                print('Error saving donation: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error saving donation: $e')),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue[700],
            ),
            child: const Text(
              'Done',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDonatedActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Sort activities by date (most recent first)
      RunTrackingScreen.donatedActivities.sort((a, b) {
        final dateA = DateTime.parse(a['donation_date']);
        final dateB = DateTime.parse(b['donation_date']);
        return dateB.compareTo(dateA);
      });

      // Calculate total stats
      double totalDonations = 0;
      double totalDistance = 0;

      for (var activity in RunTrackingScreen.donatedActivities) {
        totalDonations += activity['donation_amount'] as double;
        totalDistance += (activity['distance'] as num).toDouble() / 1000;
      }

      // Update SharedPreferences
      final String userKey = 'user_${user.uid}';
      await prefs.setDouble('${userKey}_total_donated', totalDonations);
      await prefs.setDouble('${userKey}_total_distance', totalDistance);

      // Notify listeners of updated stats
      if (RunTrackingScreen.onStatsUpdated != null) {
        RunTrackingScreen.onStatsUpdated!(totalDonations, totalDistance);
      }
    } catch (e) {
      print('Error saving donated activities: $e');
      rethrow;
    }
  }

  void _showRunDetailsDialog(Map<String, dynamic> activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Run Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${_formatDate(activity['start_date'])}'),
            Text('Distance: ${_formatDistance(activity['distance'])}'),
            Text('Duration: ${_formatDuration(activity['moving_time'])}'),
            Text(
              'Average Speed: ${_formatSpeed(activity['average_speed'])}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showDonationDialog(activity);
            },
            child: const Text('Donate'),
          ),
        ],
      ),
    );
  }

  String _formatSpeed(double speed) {
    if (_isMetric) {
      return '${(speed * 3.6).toStringAsFixed(2)} km/h';
    } else {
      return '${(speed * 2.237).toStringAsFixed(2)} mph';
    }
  }

  void _showDonationDetailsDialog(Map<String, dynamic> activity) {
    if (activity['donation_amount'] == null) {
      print('Error: Invalid donation data');
      return;
    }

    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final donationAmount = activity['donation_amount'] as double;
    final distance = activity['distance'] as num;
    final distanceInKm = distance / 1000.0;
    final rate = activity['rate'] as double;
    final donationDate = activity['donation_date'] != null 
        ? DateTime.parse(activity['donation_date'])
        : DateTime.now();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Donation Details',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Run Details section
            const Text(
              'Run Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text('Date: ${DateFormat('d/M/y').format(DateTime.parse(activity['start_date']))}'),
            Text('Distance: ${_formatDistance(distance.toDouble())}'),
            Text('Duration: ${_formatDuration(activity['moving_time'])}'),
            Text('Rate: ${currencyProvider.currencySymbol}${rate.toStringAsFixed(1)} per km'),
            
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.favorite, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text(
                  activity['charity']?['name'] ?? 'Save the Children',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Donation Breakdown section
            const Text(
              'Donation Breakdown',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Your donation:'),
                Text(
                  '${currencyProvider.currencySymbol}${donationAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('FundRacer match:'),
                Text(
                  '${currencyProvider.currencySymbol}${donationAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Impact:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${currencyProvider.currencySymbol}${(donationAmount * 2).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
                    style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
                            ),
                ),
              ],
    );
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    _stravaService = StravaService(prefs);
    _isMetric = Provider.of<MetricProvider>(context, listen: false).isMetric;
  }

  Future<void> _fetchActivities() async {
    try {
      final activities = await _stravaService.getRecentActivities();
      setState(() {
        _activities = activities;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch activities: $e')),
      );
    }
  }

  Future<void> _showDonationDialog(Map<String, dynamic> activity) async {
    // TODO: Implement donation dialog
  }

  Future<void> _loadSavedRuns() async {
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
        });
      }
    } catch (e) {
      print('Error loading saved runs: $e');
    }
  }

  List<Map<String, dynamic>> getRecentDonatedRuns() {
    // Get the 3 most recent donated runs
    return RunTrackingScreen.donatedActivities.take(3).toList();
  }

  Widget _buildRecentDonatedRunCard(Map<String, dynamic> activity) {
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final donationAmount = activity['donation_amount'] as double;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showDonationDetailsDialog(activity),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(activity['start_date']),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
                          '${currencyProvider.currencySymbol}${donationAmount.toStringAsFixed(2)}',
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
              Text(
                'Distance: ${_formatDistance(activity['distance'])}',
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                'Duration: ${_formatDuration(activity['moving_time'])}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 