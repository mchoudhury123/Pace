import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../providers/metric_provider.dart';
import '../providers/user_provider.dart';
import '../utils/card_utils.dart';
import '../services/payment_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'charities_screen.dart';
import 'dart:io' show Platform;
import 'bank_card_screen.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> activity;
  final double donationAmount;
  final double selectedRate;
  final Function()? onPaymentComplete;

  const PaymentScreen({
    super.key,
    required this.activity,
    required this.donationAmount,
    required this.selectedRate,
    this.onPaymentComplete,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String? _selectedPaymentMethod;
  bool _isProcessing = false;
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _cardholderNameController = TextEditingController();
  Map<String, dynamic>? _savedCharity;
  Map<String, String>? _savedCard;
  bool _shouldSaveCard = true;
  double _currentRate = 0.0;
  double _currentDonationAmount = 0.0;
  String _cardType = "Unknown";

  @override
  void initState() {
    super.initState();
    _loadSavedCharity();
    _loadSavedCard();
    _currentRate = widget.selectedRate;
    _currentDonationAmount = widget.donationAmount;
    
    _cardNumberController.addListener(_updateCardType);
  }

  void _updateCardType() {
    final cardNumber = _cardNumberController.text;
    if (cardNumber.isNotEmpty) {
      setState(() {
        _cardType = CardUtils.getCardTypeFrmNumber(cardNumber);
      });
    } else {
      setState(() {
        _cardType = "Unknown";
      });
    }
  }

  @override
  void dispose() {
    _cardNumberController.removeListener(_updateCardType);
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardholderNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCharity() async {
    final prefs = await SharedPreferences.getInstance();
    final charityName = prefs.getString('selectedCharity');
    if (charityName != null) {
      setState(() {
        _savedCharity = CharitiesScreen.charities.firstWhere(
          (charity) => charity['name'] == charityName,
          orElse: () => {
            'name': charityName,
            'description': 'Supporting great causes',
            'icon': Icons.favorite,
            'color': Colors.red,
          },
        );
      });
    }
  }

  Future<void> _loadSavedCard() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final card = await userProvider.loadUserCard();
    
    if (card != null) {
      setState(() {
        _savedCard = card;
        _selectedPaymentMethod = 'Saved Card';
      });
    }
  }

  Future<void> _saveCard() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.saveUserCard(
      cardNumber: _cardNumberController.text,
      cardExpiry: _expiryController.text,
      cardType: _cardType,
      cardholderName: _cardholderNameController.text,
    );
  }

  Future<void> _removeSavedCard() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Card'),
        content: const Text('Are you sure you want to remove this saved card?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
    
    // Only proceed if user confirmed
    if (confirmed == true) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.removeUserCard();
      setState(() {
        _savedCard = null;
        if (_selectedPaymentMethod == 'Saved Card') {
          _selectedPaymentMethod = null;
        }
      });
    }
  }

  List<String> _getAvailablePaymentMethods() {
    final methods = <String>[];
    
    if (_savedCard != null) {
      methods.add('Saved Card');
    }
    if (Platform.isAndroid) {
      methods.add('Google Pay');
      if (_isDeviceSamsung()) {
        methods.add('Samsung Pay');
      }
    }
    methods.add('Credit/Debit Card');
    
    return methods;
  }

  bool _isDeviceSamsung() {
    // In a real app, you would check the device manufacturer
    return false;
  }

  bool _validateCardDetails() {
    final cardNumber = _cardNumberController.text.replaceAll(' ', '');
    final expiry = _expiryController.text;
    final cvv = _cvvController.text;

    if (cardNumber.length != 16 || !_isValidLuhn(cardNumber)) {
      _showError('Invalid card number');
      return false;
    }

    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(expiry)) {
      _showError('Invalid expiry date (MM/YY)');
      return false;
    }

    final parts = expiry.split('/');
    final month = int.parse(parts[0]);
    final year = int.parse('20${parts[1]}');
    final now = DateTime.now();

    if (month < 1 || month > 12 || 
        DateTime(year, month).isBefore(DateTime(now.year, now.month))) {
      _showError('Card has expired');
      return false;
    }

    if (cvv.length != 3 || !RegExp(r'^\d{3}$').hasMatch(cvv)) {
      _showError('Invalid CVV');
      return false;
    }

    return true;
  }

  bool _isValidLuhn(String number) {
    int sum = 0;
    bool alternate = false;
    
    for (int i = number.length - 1; i >= 0; i--) {
      int n = int.parse(number[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) {
          n = (n % 10) + 1;
        }
      }
      sum += n;
      alternate = !alternate;
    }
    
    return sum % 10 == 0;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> _processPayment() async {
    if (_selectedPaymentMethod == null) {
      _showError('Please select a payment method');
      return false;
    }

    if (_selectedPaymentMethod == 'Credit/Debit Card') {
      if (!_validateCardDetails()) {
        return false;
      }

      if (_cardholderNameController.text.trim().isEmpty) {
        _showError('Please enter the cardholder name');
        return false;
      }
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      PaymentResult? result;
      final paymentService = PaymentService();
      
      if (_selectedPaymentMethod == 'Credit/Debit Card') {
        // Extract expiry month and year
        final expiryParts = _expiryController.text.split('/');
        final expiryMonth = expiryParts[0];
        final expiryYear = '20${expiryParts[1]}';
        
        result = await paymentService.processCardPayment(
          cardNumber: _cardNumberController.text.replaceAll(' ', ''),
          expiryMonth: expiryMonth,
          expiryYear: expiryYear,
          cvc: _cvvController.text,
          cardholderName: _cardholderNameController.text,
          amount: _currentDonationAmount,
          currency: Provider.of<CurrencyProvider>(context, listen: false).currencyCode,
        );
      } else if (_selectedPaymentMethod == 'Saved Card') {
        // Simulate processing with saved card
        await Future.delayed(const Duration(seconds: 2));
        result = PaymentResult(
          success: true,
          message: 'Payment simulated successfully - no actual transaction occurred',
        );
      } else {
        await Future.delayed(const Duration(seconds: 2));
        result = PaymentResult(
          success: true,
          message: 'Payment simulated successfully - no actual transaction occurred',
        );
      }
      
      if (result.success) {
        if (widget.onPaymentComplete != null) {
          widget.onPaymentComplete!();
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message)),
          );
          Navigator.pop(context, true);
        }
        return true;
      } else {
        if (mounted) {
          _showError(result.message);
        }
        return false;
      }
    } catch (e) {
      if (mounted) {
        _showError('Payment failed: $e');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String _formatDistance(double distanceInMeters) {
    final isMetric = Provider.of<MetricProvider>(context, listen: false).isMetric;
    if (isMetric) {
      return '${(distanceInMeters / 1000).toStringAsFixed(2)} km';
    } else {
      return '${(distanceInMeters / 1609.34).toStringAsFixed(2)} mi';
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

  String _formatSpeed(double speedInMetersPerSecond) {
    final isMetric = Provider.of<MetricProvider>(context, listen: false).isMetric;
    if (isMetric) {
      // Convert to km/h
      final speedKmh = speedInMetersPerSecond * 3.6;
      return '${speedKmh.toStringAsFixed(1)} km/h';
    } else {
      // Convert to mph
      final speedMph = speedInMetersPerSecond * 2.23694;
      return '${speedMph.toStringAsFixed(1)} mph';
    }
  }

  String _formatCurrency(double amount) {
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final exchangeRate = 1.0; // TODO: Implement actual exchange rate conversion
    final convertedAmount = amount * exchangeRate;
    return '${currencyProvider.currencySymbol}${convertedAmount.toStringAsFixed(2)}';
  }

  void _showEditRateDialog() {
    final isMetric = Provider.of<MetricProvider>(context, listen: false).isMetric;
    final unitAbbr = isMetric ? 'km' : 'mile';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Rate per $unitAbbr'),
        content: TextField(
          controller: TextEditingController(text: _currentRate.toStringAsFixed(2)),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: Provider.of<CurrencyProvider>(context, listen: false).currencySymbol,
            labelText: 'Rate per $unitAbbr',
          ),
          autofocus: true,
          onChanged: (value) {
            final rate = double.tryParse(value);
            if (rate != null && rate > 0) {
              final distance = widget.activity['distance'] as double;
              setState(() {
                _currentRate = rate;
                _currentDonationAmount = isMetric
                    ? rate * (distance / 1000)
                    : rate * (distance / 1609.34);
              });
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_currentRate > 0) {
                Navigator.pop(context);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _editSavedCard(BuildContext context) async {
    if (_savedCard == null) return;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BankCardScreen(
          initialCardNumber: _savedCard!['number'],
          initialCardholderName: _savedCard!['cardholderName'],
          initialExpiry: _savedCard!['expiry'],
          isEditing: true,
        ),
      ),
    );
    
    if (result == true) {
      // Reload saved card after editing
      await _loadSavedCard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Donation'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Charity Section
            if (_savedCharity != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _savedCharity!['icon'] as IconData,
                        color: _savedCharity!['color'] as Color,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _savedCharity!['name'] as String,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _savedCharity!['description'] as String,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Run Stats Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.directions_run, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Run Stats',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Distance',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        _formatDistance(widget.activity['distance']),
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
                        'Duration',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        _formatDuration(widget.activity['moving_time']),
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
                        'Average Speed',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        _formatSpeed(widget.activity['average_speed']),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Impact Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[100]!),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.stars, color: Colors.amber),
                      SizedBox(width: 8),
                      Text(
                        'Your Impact',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Donation rate (${Provider.of<MetricProvider>(context, listen: false).isMetric ? "per km" : "per mile"}):',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${Provider.of<CurrencyProvider>(context, listen: false).currencySymbol}${_currentRate.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: _showEditRateDialog,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                splashRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Your Donation:'),
                      Text(
                        _formatCurrency(_currentDonationAmount),
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
                      const Text('FundRacer Donation:'),
                      Text(
                        _formatCurrency(_currentDonationAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
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
                        _formatCurrency(_currentDonationAmount * 2),
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
            const SizedBox(height: 24),

            // Matching Message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber[100]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.amber[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'FundRacer matches every donation 100%! Your generosity goes twice as far.',
                      style: TextStyle(
                        color: Colors.amber[900],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment Method Section
            Text(
              'Payment Method',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ..._getAvailablePaymentMethods().map((method) => Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: _selectedPaymentMethod == method
                      ? Theme.of(context).primaryColor
                      : Colors.grey[300]!,
                ),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: method,
                    groupValue: _selectedPaymentMethod,
                    onChanged: (value) {
                      setState(() {
                        _selectedPaymentMethod = value;
                      });
                    },
                    title: Row(
                      children: [
                        Icon(_getPaymentIcon(method)),
                        const SizedBox(width: 8),
                        Text(method),
                        if (method == 'Saved Card') ...[
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 80,
                                  minHeight: 36,
                                ),
                                child: TextButton(
                                  onPressed: () => _editSavedCard(context),
                                  child: const Text('Edit'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                ),
                              ),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 80,
                                  minHeight: 36,
                                ),
                                child: TextButton(
                                  onPressed: _removeSavedCard,
                                  child: const Text('Remove'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    secondary: method == 'Saved Card'
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('****${_savedCard!['number']!.substring(_savedCard!['number']!.length - 4)}'),
                              if (_savedCard!['type'] != null && _savedCard!['type'] != 'Unknown')
                                Text(
                                  _savedCard!['type']!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          )
                        : null,
                  ),
                ],
              ),
            )),

            if (_selectedPaymentMethod == 'Credit/Debit Card') ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _cardholderNameController,
                      decoration: const InputDecoration(
                        labelText: 'Cardholder Name',
                        hintText: 'John Smith',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _cardNumberController,
                      decoration: InputDecoration(
                        labelText: 'Card Number',
                        hintText: '1234 5678 9012 3456',
                        suffixIcon: _cardType != "Unknown" 
                          ? Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(_cardType, style: TextStyle(color: Colors.grey[700])),
                            ) 
                          : null,
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 19,
                      onChanged: (value) {
                        if (value.length > 16) return;
                        final numbers = value.replaceAll(' ', '');
                        if (numbers.length % 4 == 0 && numbers.length < 16) {
                          _cardNumberController.text = numbers.replaceAllMapped(
                            RegExp(r'.{4}'),
                            (match) => '${match.group(0)} ',
                          );
                          _cardNumberController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _cardNumberController.text.length),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _expiryController,
                            decoration: const InputDecoration(
                              labelText: 'Expiry Date',
                              hintText: 'MM/YY',
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 5,
                            onChanged: (value) {
                              if (value.length == 2 && !value.contains('/')) {
                                _expiryController.text = '$value/';
                                _expiryController.selection = TextSelection.fromPosition(
                                  TextPosition(offset: _expiryController.text.length),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _cvvController,
                            decoration: const InputDecoration(
                              labelText: 'CVV',
                              hintText: '123',
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 3,
                            obscureText: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: _shouldSaveCard,
                      onChanged: (value) {
                        setState(() {
                          _shouldSaveCard = value ?? false;
                        });
                      },
                      title: const Text('Save card for future donations'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'TEST MODE - No actual transaction will be processed',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Donate Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : () async {
                  if (_currentDonationAmount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid donation amount')),
                    );
                    return;
                  }
                  if (await _processPayment()) {
                    if (_selectedPaymentMethod == 'Credit/Debit Card' && _shouldSaveCard) {
                      await _saveCard();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Donate ${_formatCurrency(_currentDonationAmount)} (Test Mode)',
                        style: const TextStyle(fontSize: 18),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPaymentIcon(String method) {
    switch (method) {
      case 'Apple Pay':
        return Icons.apple;
      case 'Google Pay':
        return Icons.g_mobiledata;
      case 'Samsung Pay':
        return Icons.payment;
      case 'Credit/Debit Card':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }
} 