import 'dart:io';
import 'package:flutter/material.dart';

class PaymentService {
  // Singleton instance
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();
  
  // Initialize payment methods
  Future<void> initialize(String dummyKey) async {
    debugPrint('Payment service initialized in simulation mode');
  }
  
  // Process regular card payment - simulation only
  Future<PaymentResult> processCardPayment({
    required String cardNumber,
    required String expiryMonth,
    required String expiryYear,
    required String cvc,
    required String cardholderName,
    required double amount,
    required String currency,
  }) async {
    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 2));
    
    debugPrint('SIMULATION: Processing card payment of $currency$amount');
    debugPrint('SIMULATION: Card ending with ${cardNumber.substring(cardNumber.length - 4)}');
    
    // Always succeed in test mode
    return PaymentResult(
      success: true,
      paymentMethodId: 'sim_${DateTime.now().millisecondsSinceEpoch}',
      message: 'Payment simulated successfully - no actual transaction occurred',
    );
  }
}

// Payment result model
class PaymentResult {
  final bool success;
  final String message;
  final String? paymentMethodId;
  
  PaymentResult({
    required this.success,
    required this.message,
    this.paymentMethodId,
  });
} 