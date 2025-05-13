import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/metric_provider.dart';
import '../providers/currency_provider.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isChangingPassword = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showSnackBar('Please fill in all password fields');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar('New passwords do not match');
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showSnackBar('Password must be at least 6 characters');
      return;
    }

    setState(() {
      _isChangingPassword = true;
    });

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Create a credential with email and current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );

      // Reauthenticate with current password
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(_newPasswordController.text);

      // Clear password fields
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      _showSnackBar('Password changed successfully');
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'wrong-password':
          message = 'Current password is incorrect';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Try again later';
          break;
        default:
          message = 'Error: ${e.message}';
      }
      _showSnackBar(message);
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isChangingPassword = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _changeMetric(bool isMetric) {
    final metricProvider = Provider.of<MetricProvider>(context, listen: false);
    metricProvider.setMetric(isMetric ? 'km' : 'mi');
  }

  void _changeCurrency(String code, String symbol) {
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    currencyProvider.setCurrency(code, symbol);
  }

  Widget _buildPasswordSection() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Change Password',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _currentPasswordController,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showCurrentPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _showCurrentPassword = !_showCurrentPassword;
                    });
                  },
                ),
              ),
              obscureText: !_showCurrentPassword,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showNewPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _showNewPassword = !_showNewPassword;
                    });
                  },
                ),
              ),
              obscureText: !_showNewPassword,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _showConfirmPassword = !_showConfirmPassword;
                    });
                  },
                ),
              ),
              obscureText: !_showConfirmPassword,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isChangingPassword ? null : _changePassword,
                child: _isChangingPassword
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Update Password'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricSection() {
    final metricProvider = Provider.of<MetricProvider>(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Distance Units',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Kilometers (km)'),
                    value: true,
                    groupValue: metricProvider.isMetric,
                    onChanged: (value) => _changeMetric(true),
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Miles (mi)'),
                    value: false,
                    groupValue: metricProvider.isMetric,
                    onChanged: (value) => _changeMetric(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This will affect how distances are displayed throughout the app.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencySection() {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    
    // Define available currencies
    final currencies = [
      {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
      {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
      {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
      {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar'},
      {'code': 'CAD', 'symbol': 'C\$', 'name': 'Canadian Dollar'},
    ];
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Currency',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Map<String, String>>(
              decoration: const InputDecoration(
                labelText: 'Select Currency',
                border: OutlineInputBorder(),
              ),
              value: currencies.firstWhere(
                (c) => c['code'] == currencyProvider.currencyCode,
                orElse: () => currencies[0],
              ),
              items: currencies.map((currency) {
                return DropdownMenuItem<Map<String, String>>(
                  value: currency,
                  child: Text('${currency['symbol']} ${currency['name']} (${currency['code']})'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  _changeCurrency(value['code']!, value['symbol']!);
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              'This will change the currency used for donations and payments.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Account Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.deepBlue,
              ),
            ),
            const SizedBox(height: 16),
            _buildPasswordSection(),
            const SizedBox(height: 24),
            const Text(
              'App Preferences',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.deepBlue,
              ),
            ),
            const SizedBox(height: 16),
            _buildMetricSection(),
            const SizedBox(height: 16),
            _buildCurrencySection(),
          ],
        ),
      ),
    );
  }
} 