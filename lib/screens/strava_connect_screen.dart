import 'package:flutter/material.dart';
import 'package:fundracer_app/providers/strava_provider.dart';
import 'package:fundracer_app/widgets/strava_auth_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class StravaConnectScreen extends StatefulWidget {
  final Function? onConnected;
  
  const StravaConnectScreen({
    Key? key,
    this.onConnected,
  }) : super(key: key);

  @override
  State<StravaConnectScreen> createState() => _StravaConnectScreenState();
}

class _StravaConnectScreenState extends State<StravaConnectScreen> {
  bool _isLoading = true;
  bool _isConnected = false;
  
  @override
  void initState() {
    super.initState();
    _checkConnection();
  }
  
  Future<void> _checkConnection() async {
    final stravaProvider = Provider.of<StravaProvider>(context, listen: false);
    
    if (!stravaProvider.isInitialized) {
      await stravaProvider.initialize();
    }
    
    if (mounted) {
      setState(() {
        _isConnected = stravaProvider.isAuthenticated;
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect with Strava'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<StravaProvider>(
              builder: (context, stravaProvider, _) {
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/api_logo_pwrdBy_strava_stack_orange.png',
                          height: 40,
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'Connect your Strava account to track your runs and activities',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'By connecting your Strava account, you can:',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildFeatureItem(
                          Icons.directions_run,
                          'Track your runs and activities',
                        ),
                        _buildFeatureItem(
                          Icons.bar_chart,
                          'View your running statistics',
                        ),
                        _buildFeatureItem(
                          Icons.history,
                          'Access your activity history',
                        ),
                        _buildFeatureItem(
                          Icons.monetization_on,
                          'Convert your miles into donations',
                        ),
                        const SizedBox(height: 30),
                        stravaProvider.isAuthenticated
                            ? Column(
                                children: [
                                  const Text(
                                    'Your Strava account is connected!',
                                    style: TextStyle(
                                      color: Color(0xFF4CAF50),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: () async {
                                      final Uri stravaUrl = Uri.parse(
                                          'https://www.strava.com/dashboard');
                                      if (await canLaunchUrl(stravaUrl)) {
                                        await launchUrl(stravaUrl,
                                            mode: LaunchMode.externalApplication);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFC5200),
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('View Strava Dashboard'),
                                  ),
                                  const SizedBox(height: 10),
                                  TextButton(
                                    onPressed: () async {
                                      await stravaProvider.logout();
                                      if (mounted) {
                                        setState(() {
                                          _isConnected = false;
                                        });
                                      }
                                    },
                                    child: const Text(
                                      'Disconnect from Strava',
                                      style: TextStyle(
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  StravaAuthButton(
                                    onAuthSuccess: () {
                                      setState(() {
                                        _isConnected = true;
                                      });
                                      widget.onConnected?.call();
                                    },
                                    height: 50,
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'By connecting, you agree to share your Strava activity data with FundRacer',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
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
    );
  }
  
  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFC5200)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
