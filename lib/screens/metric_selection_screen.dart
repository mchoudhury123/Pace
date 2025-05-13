import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/metric_provider.dart';
import '../main.dart';
import 'notification_permission_screen.dart';
import 'connect_health_screen.dart';

class MetricSelectionScreen extends StatefulWidget {
  const MetricSelectionScreen({super.key});

  @override
  State<MetricSelectionScreen> createState() => _MetricSelectionScreenState();
}

class _MetricSelectionScreenState extends State<MetricSelectionScreen> {
  String? _selectedMetric;
  bool _stravaMetricChecked = false;

  final List<Map<String, dynamic>> metricOptions = [
    {
      'text': 'Kilometers',
      'icon': Icons.straighten_rounded,
      'description': 'Use kilometers for distance tracking',
      'value': 'km'
    },
    {
      'text': 'Miles',
      'icon': Icons.speed_rounded,
      'description': 'Use miles for distance tracking',
      'value': 'mi'
    },
  ];

  bool get canContinue => _selectedMetric != null;

  Future<void> _checkStravaMetric() async {
    if (!_stravaMetricChecked && _selectedMetric != null) {
      // TODO: Implement actual Strava metric check
      // For now, we'll simulate that Strava uses kilometers
      const stravaUsesMetric = true; // This should come from Strava API
      final selectedIsMetric = _selectedMetric == 'km';

      if (stravaUsesMetric != selectedIsMetric) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Metric Mismatch'),
            content: Text(
              'Your selected metric (${_selectedMetric == 'km' ? 'kilometers' : 'miles'}) '
              'does not match with your Strava settings '
              '(${stravaUsesMetric ? 'kilometers' : 'miles'}). '
              'Are you sure you want to proceed?'
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Change Selection',
                  style: TextStyle(color: AppColors.textGrey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Proceed Anyway'),
              ),
            ],
          ),
        );

        if (proceed != true) {
          return;
        }
      }
    }
    _stravaMetricChecked = true;

    // Save metric preference using the provider
    await Provider.of<MetricProvider>(context, listen: false).setMetric(_selectedMetric!);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const NotificationPermissionScreen(),
        ),
      );
    }
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
              MaterialPageRoute(builder: (context) => const ConnectHealthScreen()),
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
                          'Choose your\npreferred metric',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepBlue,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select how you want to measure your distances',
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
                child: Column(
                  children: metricOptions.map((metric) {
                    final isSelected = _selectedMetric == metric['value'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMetric = metric['value'];
                          _stravaMetricChecked = false;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: isSelected 
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
                                color: isSelected
                                    ? AppColors.primaryBlue.withOpacity(0.1)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                metric['icon'],
                                size: 28,
                                color: isSelected
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
                                    metric['text'],
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppColors.textBlack,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    metric['description'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
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
                    );
                  }).toList(),
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
              child: Container(
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
                  onPressed: canContinue ? _checkStravaMetric : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    disabledBackgroundColor: Colors.transparent,
                  ),
                  child: Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: canContinue ? Colors.white : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
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