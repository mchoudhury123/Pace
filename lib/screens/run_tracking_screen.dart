import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/strava_service.dart';
import '../main.dart';
import 'dart:convert';

class PaymentConfirmationScreen extends StatefulWidget {
  final Map<String, dynamic> activity;
  final Function(int selectedRate) onPaymentComplete;

  const PaymentConfirmationScreen({
    super.key,
    required this.activity,
    required this.onPaymentComplete,
  });

  @override
  State<PaymentConfirmationScreen> createState() => _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  final List<int> _rates = [1, 2, 5, 10, 20];
  int _selectedRate = 10; // Default rate

  @override
  Widget build(BuildContext context) {
    final distance = (widget.activity['distance'] as num).toDouble() / 1000;
    final donationAmount = (distance * _selectedRate).toStringAsFixed(2);
    final activityName = widget.activity['name'] as String;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donation Confirmation'),
        backgroundColor: AppColors.primaryBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm Donation',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.deepBlue,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activityName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textBlack,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${distance.toStringAsFixed(1)} kilometers',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Rate selection dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primaryBlue),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<int>(
                        value: _selectedRate,
                        isExpanded: true,
                        underline: Container(),
                        items: _rates.map((rate) {
                          return DropdownMenuItem<int>(
                            value: rate,
                            child: Text('\$$rate per kilometer'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRate = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Donation Amount:',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textGrey,
                          ),
                        ),
                        Text(
                          '\$$donationAmount',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepBlue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Payment method card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.primaryBlue, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.credit_card,
                      color: AppColors.primaryBlue,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Credit Card',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '**** **** **** 4242',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Radio(
                      value: true,
                      groupValue: true,
                      onChanged: (_) {},
                      activeColor: AppColors.primaryBlue,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Simulate payment processing
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const AlertDialog(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Processing payment...'),
                        ],
                      ),
                    ),
                  );

                  // Simulate network delay
                  Future.delayed(const Duration(seconds: 2), () {
                    Navigator.pop(context); // Close progress dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Payment Successful'),
                        content: const Text('Thank you for your donation!'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context); // Close success dialog
                              Navigator.pop(context); // Return to run screen
                              widget.onPaymentComplete(_selectedRate); // Pass back the selected rate
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Confirm Payment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RunTrackingScreen extends StatefulWidget {
  final Function(double totalDonations, double totalDistance)? onStatsUpdated;

  const RunTrackingScreen({
    super.key,
    this.onStatsUpdated,
  });

  @override
  State<RunTrackingScreen> createState() => _RunTrackingScreenState();
}

class _RunTrackingScreenState extends State<RunTrackingScreen> {
  bool _isLoading = true;
  late StravaService _stravaService;
  List<Map<String, dynamic>> _activities = [];
  Set<String> _donatedActivityIds = {};
  int _selectedIndex = 0; // 0 for Not Donated, 1 for Donated
  Map<String, int> _activityRates = {}; // Store donation rates for each activity

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadDonatedActivities();
    _loadActivityRates();
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    _stravaService = StravaService(prefs);
    await _loadStravaActivities();
  }

  Future<void> _loadDonatedActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final donatedIds = prefs.getStringList('donated_activity_ids') ?? [];
    setState(() {
      _donatedActivityIds = Set<String>.from(donatedIds);
    });
  }

  Future<void> _loadActivityRates() async {
    final prefs = await SharedPreferences.getInstance();
    final rates = prefs.getString('activity_rates') ?? '{}';
    _activityRates = Map<String, int>.from(
      Map<String, dynamic>.from(json.decode(rates))
        .map((key, value) => MapEntry(key, value as int))
    );
  }

  Future<void> _saveActivityRate(String activityId, int rate) async {
    final prefs = await SharedPreferences.getInstance();
    _activityRates[activityId] = rate;
    await prefs.setString('activity_rates', json.encode(_activityRates));
  }

  void _updateHomeScreenStats() {
    if (widget.onStatsUpdated != null) {
      double totalDonations = 0;
      double totalDistance = 0;
      
      for (var activity in _donatedActivities) {
        final distance = (activity['distance'] as num).toDouble() / 1000;
        final activityId = activity['id'].toString();
        final rate = _activityRates[activityId] ?? 10;
        totalDonations += distance * rate;
        totalDistance += distance;
      }
      
      widget.onStatsUpdated!(totalDonations, totalDistance);
    }
  }

  Future<void> _markActivityAsDonated(String activityId, int rate) async {
    final prefs = await SharedPreferences.getInstance();
    final donatedIds = prefs.getStringList('donated_activity_ids') ?? [];
    
    if (!donatedIds.contains(activityId)) {
      donatedIds.add(activityId);
      await prefs.setStringList('donated_activity_ids', donatedIds);
      await _saveActivityRate(activityId, rate);
    }
    
    setState(() {
      _donatedActivityIds.add(activityId);
      _activityRates[activityId] = rate;
    });
    
    _updateHomeScreenStats();
  }

  Future<void> _loadStravaActivities() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final isAuthenticated = await _stravaService.isAuthenticated;
      // For testing, we'll add sample activities regardless of authentication
      final sampleActivities = [
        {
          'id': '1',
          'name': 'Morning Run in Central Park',
          'distance': 8500.0, // 8.5 km
          'moving_time': 2700, // 45 minutes
          'start_date': '2024-03-10T08:30:00Z',
        },
        {
          'id': '2',
          'name': 'Evening Jog by the River',
          'distance': 5000.0, // 5 km
          'moving_time': 1800, // 30 minutes
          'start_date': '2024-03-09T18:00:00Z',
        },
        {
          'id': '3',
          'name': 'Weekend Long Run',
          'distance': 15000.0, // 15 km
          'moving_time': 5400, // 1.5 hours
          'start_date': '2024-03-08T09:00:00Z',
        },
        {
          'id': '4',
          'name': 'Quick Lunch Break Run',
          'distance': 3000.0, // 3 km
          'moving_time': 900, // 15 minutes
          'start_date': '2024-03-07T12:30:00Z',
        },
        {
          'id': '5',
          'name': 'Trail Running Adventure',
          'distance': 12000.0, // 12 km
          'moving_time': 4500, // 1.25 hours
          'start_date': '2024-03-06T07:00:00Z',
        },
      ];

      setState(() {
        _activities = sampleActivities;
        _isLoading = false;
      });

      // Load donated activities and rates
      await _loadDonatedActivities();
      await _loadActivityRates();
      
      // Update home screen stats
      _updateHomeScreenStats();
    } catch (e) {
      print('Error loading Strava activities: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }

  List<Map<String, dynamic>> get _donatedActivities {
    return _activities.where((activity) => 
      _donatedActivityIds.contains(activity['id'].toString())).toList();
  }
  
  List<Map<String, dynamic>> get _notDonatedActivities {
    return _activities.where((activity) => 
      !_donatedActivityIds.contains(activity['id'].toString())).toList();
  }

  Widget _buildActivityCard(Map<String, dynamic> activity, bool isDonated) {
    final activityId = activity['id'].toString();
    final distance = (activity['distance'] as num).toDouble() / 1000;
    final duration = activity['moving_time'] as int;
    final date = activity['start_date'] as String;
    final name = activity['name'] as String;
    final rate = _activityRates[activityId] ?? 10; // Default to $10 if not found
    
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
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textBlack,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(date)} • ${distance.toStringAsFixed(1)} km • ${_formatDuration(duration)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            isDonated 
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${(distance * rate).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$$rate/km',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                )
              : ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentConfirmationScreen(
                          activity: activity,
                          onPaymentComplete: (selectedRate) {
                            _markActivityAsDonated(activityId, selectedRate);
                          },
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Donate'),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_run,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect with Strava to import your activities',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedIndex = 0;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedIndex == 0 ? AppColors.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  'Not Donated',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedIndex == 0 ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedIndex = 1;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedIndex == 1 ? AppColors.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  'Donated',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedIndex == 1 ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Your Runs'),
        backgroundColor: AppColors.primaryBlue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header section with title
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text(
                    'Strava Activities',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Segment control
                _buildSegmentedControl(),
                const SizedBox(height: 16),
                // Runs section
                Expanded(
                  child: _selectedIndex == 0
                      ? _notDonatedActivities.isEmpty
                          ? _buildEmptyState('No runs to donate')
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              itemCount: _notDonatedActivities.length,
                              itemBuilder: (context, index) {
                                return _buildActivityCard(_notDonatedActivities[index], false);
                              },
                            )
                      : _donatedActivities.isEmpty
                          ? _buildEmptyState('No donated runs yet')
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              itemCount: _donatedActivities.length,
                              itemBuilder: (context, index) {
                                return _buildActivityCard(_donatedActivities[index], true);
                              },
                            ),
                ),
              ],
            ),
      floatingActionButton: !_isLoading && _activities.isEmpty
          ? FloatingActionButton(
              onPressed: _loadStravaActivities,
              backgroundColor: AppColors.primaryBlue,
              child: const Icon(Icons.refresh),
            )
          : null,
    );
  }
} 