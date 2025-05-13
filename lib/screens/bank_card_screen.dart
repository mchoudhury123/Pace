import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_credit_card/flutter_credit_card.dart';
import '../widgets/onboarding_progress_bar.dart';
import 'gender_selection_screen.dart';

class BankCardScreen extends StatefulWidget {
  final String? initialCardNumber;
  final String? initialCardholderName;
  final String? initialExpiry;
  final bool isEditing;

  const BankCardScreen({
    super.key,
    this.initialCardNumber,
    this.initialCardholderName,
    this.initialExpiry,
    this.isEditing = false,
  });

  @override
  State<BankCardScreen> createState() => _BankCardScreenState();
}

class _BankCardScreenState extends State<BankCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String _cardNumber = '';
  String _expiryDate = '';
  String _cardHolderName = '';
  String _cvvCode = '';
  bool _isCvvFocused = false;
  CardType _cardType = CardType.visa;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with existing card data if editing
    if (widget.isEditing) {
      if (widget.initialCardNumber != null) {
        _cardNumberController.text = widget.initialCardNumber!;
        _cardNumber = widget.initialCardNumber!;
        _cardType = _getCardTypeFromNumber(_cardNumber);
      }
      
      if (widget.initialCardholderName != null) {
        _nameController.text = widget.initialCardholderName!;
        _cardHolderName = widget.initialCardholderName!;
      }
      
      if (widget.initialExpiry != null) {
        _expiryController.text = widget.initialExpiry!;
        _expiryDate = widget.initialExpiry!;
      }
    }

    _cardNumberController.addListener(_onCardNumberChange);
    _expiryController.addListener(_onExpiryChange);
    _cvvController.addListener(_onCvvChange);
    _nameController.addListener(_onNameChange);
  }

  void _onCardNumberChange() {
    setState(() {
      _cardNumber = _cardNumberController.text;
      _cardType = _getCardTypeFromNumber(_cardNumber);
    });
  }

  void _onExpiryChange() {
    setState(() {
      _expiryDate = _expiryController.text;
    });
  }

  void _onCvvChange() {
    setState(() {
      _cvvCode = _cvvController.text;
    });
  }

  void _onNameChange() {
    setState(() {
      _cardHolderName = _nameController.text;
    });
  }

  CardType _getCardTypeFromNumber(String number) {
    if (number.startsWith('4')) {
      return CardType.visa;
    } else if (number.startsWith('5')) {
      return CardType.mastercard;
    } else if (number.startsWith('3')) {
      return CardType.americanExpress;
    } else if (number.startsWith('6')) {
      return CardType.discover;
    }
    return CardType.visa;
  }

  bool _isValidCardNumber(String number) {
    if (number.isEmpty) return false;
    number = number.replaceAll(' ', '');
    if (number.length != 16) return false;
    return true;
  }

  bool _isValidExpiryDate(String date) {
    if (date.isEmpty) return false;
    if (!RegExp(r'^(0[1-9]|1[0-2])\/([0-9]{2})$').hasMatch(date)) return false;
    
    final parts = date.split('/');
    final month = int.parse(parts[0]);
    final year = int.parse(parts[1]);
    
    final now = DateTime.now();
    final currentYear = now.year % 100;
    final currentMonth = now.month;
    
    if (year < currentYear || (year == currentYear && month < currentMonth)) {
      return false;
    }
    
    return true;
  }

  String? _validateCardNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your card number';
    }
    if (value.replaceAll(' ', '').length != 16) {
      return 'Please enter a valid 16-digit card number';
    }
    if (!_isValidCardNumber(value)) {
      return 'Please enter a valid card number';
    }
    return null;
  }

  String? _validateExpiry(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter expiry date';
    }
    if (!RegExp(r'^(0[1-9]|1[0-2])\/([0-9]{2})$').hasMatch(value)) {
      return 'Please enter a valid expiry date (MM/YY)';
    }
    if (!_isValidExpiryDate(value)) {
      return 'Please enter a valid expiry date';
    }
    return null;
  }

  String? _validateCVV(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter CVV';
    }
    if (value.length != 3) {
      return 'Please enter a valid 3-digit CVV';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter cardholder name';
    }
    return null;
  }

  Widget _buildCustomCard() {
    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _cardType.toString().split('.').last.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF4A67FF),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                _cardType == CardType.visa ? Icons.credit_card : 
                _cardType == CardType.mastercard ? Icons.credit_card : 
                _cardType == CardType.americanExpress ? Icons.credit_card :
                Icons.credit_card,
                color: const Color(0xFF4A67FF),
                size: 32,
              ),
            ],
          ),
          Text(
            _cardNumber.isEmpty ? 'XXXX XXXX XXXX XXXX' : _cardNumber,
            style: const TextStyle(
              color: Color(0xFF4A67FF),
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CARD HOLDER',
                    style: TextStyle(
                      color: Color(0xFF4A67FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _cardHolderName.isEmpty ? 'YOUR NAME' : _cardHolderName,
                    style: const TextStyle(
                      color: Color(0xFF4A67FF),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EXPIRES',
                    style: TextStyle(
                      color: Color(0xFF4A67FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _expiryDate.isEmpty ? 'MM/YY' : _expiryDate,
                    style: const TextStyle(
                      color: Color(0xFF4A67FF),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const phoneWidth = 393.0;
    const phoneHeight = 852.0;

    Widget mainContent = Container(
      width: phoneWidth,
      height: phoneHeight,
      color: const Color(0xFF4A67FF),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.isEditing ? 'Edit Your\nCard Details' : 'Add Your\nCard Details',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const Text(
                        'Add Your\nCard Details',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Securely save your card to make donations easier',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildCustomCard(),
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _cardNumberController,
                                decoration: InputDecoration(
                                  labelText: 'Card Number',
                                  prefixIcon: const Icon(Icons.credit_card),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFF4A67FF).withOpacity(0.1),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(16),
                                ],
                                validator: _validateCardNumber,
                                onChanged: (value) {
                                  if (value.length == 16) {
                                    setState(() {
                                      _cardNumberController.text = value.replaceAllMapped(
                                        RegExp(r'.{4}'),
                                        (match) => '${match.group(0)} ',
                                      );
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _expiryController,
                                      decoration: InputDecoration(
                                        labelText: 'Expiry Date (MM/YY)',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFF4A67FF).withOpacity(0.1),
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(4),
                                      ],
                                      validator: _validateExpiry,
                                      onChanged: (value) {
                                        if (value.length == 4) {
                                          setState(() {
                                            _expiryController.text = '${value.substring(0, 2)}/${value.substring(2)}';
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _cvvController,
                                      decoration: InputDecoration(
                                        labelText: 'CVV',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFF4A67FF).withOpacity(0.1),
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(3),
                                      ],
                                      validator: _validateCVV,
                                      obscureText: true,
                                      onTap: () {
                                        setState(() {
                                          _isCvvFocused = true;
                                        });
                                      },
                                      onEditingComplete: () {
                                        setState(() {
                                          _isCvvFocused = false;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: 'Cardholder Name',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFF4A67FF).withOpacity(0.1),
                                ),
                                textCapitalization: TextCapitalization.characters,
                                validator: _validateName,
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : () async {
                                    if (_formKey.currentState!.validate()) {
                                      setState(() {
                                        _isLoading = true;
                                      });
                                      
                                      try {
                                        // Here you would typically make an API call to update the card
                                        // For now, we'll just simulate a delay
                                        await Future.delayed(const Duration(seconds: 1));
                                        
                                        if (!mounted) return;
                                        
                                        // Return true to indicate successful edit
                                        Navigator.pop(context, true);
                                      } catch (e) {
                                        if (!mounted) return;
                                        
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error: ${e.toString()}'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() {
                                            _isLoading = false;
                                          });
                                        }
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4A67FF),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        widget.isEditing ? 'Save Changes' : 'Add Card',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                ),
                              ),
                              const SizedBox(
                                height: 16,
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const GenderSelectionScreen(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF4A67FF),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text(
                                  'Skip for now',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (kIsWeb) {
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

    return Scaffold(
      backgroundColor: const Color(0xFF4A67FF),
      body: mainContent,
    );
  }
} 