import 'package:flutter/material.dart';
import 'package:fundracer_app/models/strava_activity_model.dart';
import 'package:fundracer_app/models/strava_athlete_model.dart';
import 'package:fundracer_app/services/strava_client_service.dart';
import 'package:fundracer_app/widgets/strava_auth_button.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StravaActivitiesScreen extends StatefulWidget {
  const StravaActivitiesScreen({Key? key}) : super(key: key);

  @override
  State<StravaActivitiesScreen> createState() => _StravaActivitiesScreenState();
}

class _StravaActivitiesScreenState extends State<StravaActivitiesScreen> {
  late StravaClientService _stravaService;
  bool _isLoading = true;
  bool _isAuthenticated = false;
  List<StravaActivityModel> _activities = [];
  StravaAthleteModel? _athlete;
  Map<String, dynamic>? _athleteStats;
  bool _isMetric = true; // Default to metric units

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    // final prefs = await SharedPreferences.getInstance();
    _stravaService = StravaClientService();

    // Check if user is authenticated
    final isAuthenticated = await _stravaService.authStatus == StravaAuthStatus.authenticated;

    if (mounted) {
      setState(() {
        _isAuthenticated = isAuthenticated;
      });
    }

    if (isAuthenticated) {
      await _loadData();
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Get athlete profile
      final athlete = await _stravaService.getAthleteProfile();

      // Get athlete stats
      final stats = await _stravaService.getAthleteStats();

      // Get recent activities
      final activities = await _stravaService.getRecentActivities(limit: 20);

      if (mounted) {
        setState(() {
          _athlete = athlete;
          _athleteStats = stats;
          _activities = activities;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading Strava data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading Strava data: $e')),
        );
      }
    }
  }

  void _toggleUnits() {
    setState(() {
      _isMetric = !_isMetric;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Strava Activities'),
        actions: [
          if (_isAuthenticated)
            IconButton(
              icon: Icon(_isMetric ? Icons.straighten : Icons.speed),
              onPressed: _toggleUnits,
              tooltip: 'Toggle units (${_isMetric ? 'Metric' : 'Imperial'})',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isAuthenticated ? _loadData : null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_isAuthenticated
              ? _buildAuthView()
              : _buildActivitiesView(),
    );
  }

  Widget _buildAuthView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Connect with Strava to view your activities',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          StravaAuthButton(
            onAuthSuccess: () {
              setState(() {
                _isAuthenticated = true;
              });
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesView() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          if (_athlete != null) _buildAthleteHeader(),
          if (_athleteStats != null) _buildAthleteStats(),
          _buildActivitiesList(),
        ],
      ),
    );
  }

  Widget _buildAthleteHeader() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_athlete?.profile != null)
              CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(_athlete!.profile!),
              )
            else
              const CircleAvatar(
                radius: 30,
                child: Icon(Icons.person),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_athlete?.firstname} ${_athlete?.lastname}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_athlete?.city != null || _athlete?.country != null)
                    Text(
                      [
                        if (_athlete?.city != null) _athlete!.city,
                        if (_athlete?.country != null) _athlete!.country,
                      ].where((e) => e != null).join(', '),
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
            Image.asset(
              'assets/images/api_logo_pwrdBy_strava_stack_orange.png',
              height: 30,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAthleteStats() {
    final recentRunTotals = _athleteStats?['recent_run_totals'];
    final allRunTotals = _athleteStats?['all_run_totals'];

    if (recentRunTotals == null || allRunTotals == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final recentDistance = _isMetric
        ? (recentRunTotals['distance'] / 1000).toStringAsFixed(1)
        : (recentRunTotals['distance'] / 1609.34).toStringAsFixed(1);
    final allTimeDistance = _isMetric
        ? (allRunTotals['distance'] / 1000).toStringAsFixed(0)
        : (allRunTotals['distance'] / 1609.34).toStringAsFixed(0);

    final distanceUnit = _isMetric ? 'km' : 'mi';

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Stats',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatCard(
                  'Last 4 Weeks',
                  '$recentDistance $distanceUnit',
                  '${recentRunTotals['count']} runs',
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'All Time',
                  '$allTimeDistance $distanceUnit',
                  '${allRunTotals['count']} runs',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivitiesList() {
    if (_activities.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text('No activities found'),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final activity = _activities[index];
          return _buildActivityCard(activity);
        },
        childCount: _activities.length,
      ),
    );
  }

  Widget _buildActivityCard(StravaActivityModel activity) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    final distance = _isMetric
        ? '${activity.distanceInKm.toStringAsFixed(2)} km'
        : '${activity.distanceInMiles.toStringAsFixed(2)} mi';

    final pace = _isMetric
        ? '${activity.formattedPacePerKm} /km'
        : '${activity.formattedPacePerMile} /mi';

    final activityIcon = _getActivityIcon(activity.type);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(activityIcon, color: const Color(0xFFFC5200)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activity.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${dateFormat.format(activity.startDate)} at ${timeFormat.format(activity.startDate)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildActivityStat(Icons.straighten, distance),
                _buildActivityStat(Icons.timer, activity.formattedMovingTime),
                _buildActivityStat(Icons.speed, pace),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'run':
        return Icons.directions_run;
      case 'ride':
        return Icons.directions_bike;
      case 'swim':
        return Icons.pool;
      case 'walk':
        return Icons.directions_walk;
      case 'hike':
        return Icons.terrain;
      default:
        return Icons.fitness_center;
    }
  }
}
