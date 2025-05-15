import 'package:flutter/material.dart';
import 'package:fundracer_app/services/strava_client_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StravaAuthButton extends StatefulWidget {
  final Function? onAuthSuccess;
  final Function? onAuthFailure;
  final bool showConnectedState;
  final double height;
  
  const StravaAuthButton({
    Key? key,
    this.onAuthSuccess,
    this.onAuthFailure,
    this.showConnectedState = true,
    this.height = 48,
  }) : super(key: key);

  @override
  State<StravaAuthButton> createState() => _StravaAuthButtonState();
}

class _StravaAuthButtonState extends State<StravaAuthButton> {
  late StravaClientService _stravaService;
  bool _isConnected = false;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _initializeService();
  }
  
  Future<void> _initializeService() async {
    final prefs = await SharedPreferences.getInstance();
    _stravaService = StravaClientService();
    await _checkConnection();
  }
  
  Future<void> _checkConnection() async {
    final isAuthenticated = _stravaService.authStatus == StravaAuthStatus.authenticated;
    if (mounted) {
      setState(() {
        _isConnected = isAuthenticated;
      });
    }
  }
  
  Future<void> _connectStrava() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await _stravaService.authenticate(context);
      
      if (mounted) {
        setState(() {
          _isConnected = success;
          _isLoading = false;
        });
      }
      
      if (success) {
        widget.onAuthSuccess?.call();
      } else {
        widget.onAuthFailure?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting to Strava: $e')),
        );
      }
      
      widget.onAuthFailure?.call();
    }
  }
  
  Future<void> _disconnectStrava() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _stravaService.logout();
      
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error disconnecting from Strava: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFC5200)),
          ),
        ),
      );
    }
    
    if (_isConnected && widget.showConnectedState) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/api_logo_pwrdBy_strava_stack_orange.png',
            height: 24,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _disconnectStrava,
            child: const Text(
              'Disconnect from Strava',
              style: TextStyle(
                color: Color(0xFFFC5200),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }
    
    return GestureDetector(
      onTap: _connectStrava,
      child: Image.asset(
        'assets/images/btn_strava_connect_with_orange_x2.png',
        height: widget.height,
      ),
    );
  }
}
