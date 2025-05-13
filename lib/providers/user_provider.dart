import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';

class UserProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _repository = UserRepository();
  
  UserModel? _currentUser;
  bool _isLoading = false;
  
  UserModel? get currentUser => _currentUser;
  User? get authUser => _auth.currentUser;
  String? get userId => _auth.currentUser?.uid;
  bool get isLoading => _isLoading;
  
  // Get user-specific key for preferences
  String _getUserSpecificKey(String key) {
    final uid = userId;
    if (uid == null) return key;
    return '${uid}_$key';
  }
  
  // Load current user from Firebase
  Future<void> loadUser() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _currentUser = await _repository.getCurrentUser();
    } catch (e) {
      print('Error loading user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Update user profile
  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? gender,
    DateTime? dateOfBirth,
    String? photoUrl,
  }) async {
    if (_currentUser == null) {
      await loadUser();
      if (_currentUser == null) return;
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final updatedUser = _currentUser!.copyWith(
        firstName: firstName,
        lastName: lastName,
        gender: gender,
        dateOfBirth: dateOfBirth,
        photoUrl: photoUrl,
      );
      
      await _repository.updateUserProfile(updatedUser);
      _currentUser = updatedUser;
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Upload user photo
  Future<String?> uploadPhoto(File imageFile) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final photoUrl = await _repository.uploadUserPhoto(imageFile);
      if (photoUrl != null && _currentUser != null) {
        final updatedUser = _currentUser!.copyWith(photoUrl: photoUrl);
        await _repository.updateUserProfile(updatedUser);
        _currentUser = updatedUser;
      }
      return photoUrl;
    } catch (e) {
      print('Error uploading photo: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Connect to health service
  Future<void> connectHealthService(String serviceName, bool isConnected) async {
    if (_currentUser == null) {
      await loadUser();
      if (_currentUser == null) return;
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      await _repository.updateConnectedHealthService(serviceName, isConnected);
      
      // Update the local user model
      if (serviceName == 'Strava') {
        _currentUser = _currentUser!.copyWith(
          connectedHealthService: isConnected ? serviceName : null,
          isStravaConnected: isConnected,
        );
      } else {
        _currentUser = _currentUser!.copyWith(
          connectedHealthService: isConnected ? serviceName : null,
        );
      }
    } catch (e) {
      print('Error connecting health service: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Save notification preferences
  Future<void> saveNotificationPreferences({
    required bool enabled,
    String? fcmToken,
  }) async {
    if (_currentUser == null) {
      await loadUser();
      if (_currentUser == null) return;
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      await _repository.saveNotificationPreferences(
        enabled: enabled,
        fcmToken: fcmToken,
      );
      
      _currentUser = _currentUser!.copyWith(
        notificationsEnabled: enabled,
        fcmToken: fcmToken ?? _currentUser!.fcmToken,
      );
    } catch (e) {
      print('Error saving notification preferences: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Save country settings
  Future<void> saveCountrySettings({
    required String countryCode,
    required String currencyCode,
    required String currencySymbol,
  }) async {
    if (_currentUser == null) {
      await loadUser();
      if (_currentUser == null) return;
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      await _repository.saveCountrySettings(
        countryCode: countryCode,
        currencyCode: currencyCode,
        currencySymbol: currencySymbol,
      );
      
      _currentUser = _currentUser!.copyWith(
        countryCode: countryCode,
        currencyCode: currencyCode,
        currencySymbol: currencySymbol,
      );
    } catch (e) {
      print('Error saving country settings: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Save card for the specific user
  Future<void> saveUserCard({
    required String cardNumber,
    required String cardExpiry,
    required String cardType,
    required String cardholderName,
  }) async {
    if (userId == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final userCardKey = _getUserSpecificKey('savedCardNumber');
    final userExpiryKey = _getUserSpecificKey('savedCardExpiry');
    final userCardTypeKey = _getUserSpecificKey('savedCardType');
    final userCardholderKey = _getUserSpecificKey('savedCardholderName');
    
    await prefs.setString(userCardKey, cardNumber);
    await prefs.setString(userExpiryKey, cardExpiry);
    await prefs.setString(userCardTypeKey, cardType);
    await prefs.setString(userCardholderKey, cardholderName);
    
    notifyListeners();
  }
  
  // Load card for the specific user
  Future<Map<String, String>?> loadUserCard() async {
    if (userId == null) return null;
    
    final prefs = await SharedPreferences.getInstance();
    final userCardKey = _getUserSpecificKey('savedCardNumber');
    final userExpiryKey = _getUserSpecificKey('savedCardExpiry');
    final userCardTypeKey = _getUserSpecificKey('savedCardType');
    final userCardholderKey = _getUserSpecificKey('savedCardholderName');
    
    final cardNumber = prefs.getString(userCardKey);
    final cardExpiry = prefs.getString(userExpiryKey);
    final cardType = prefs.getString(userCardTypeKey);
    final cardholderName = prefs.getString(userCardholderKey);
    
    if (cardNumber != null && cardExpiry != null) {
      return {
        'number': cardNumber,
        'expiry': cardExpiry,
        'type': cardType ?? 'Unknown',
        'cardholderName': cardholderName ?? '',
      };
    }
    
    return null;
  }
  
  // Remove saved card for the specific user
  Future<void> removeUserCard() async {
    if (userId == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final userCardKey = _getUserSpecificKey('savedCardNumber');
    final userExpiryKey = _getUserSpecificKey('savedCardExpiry');
    final userCardTypeKey = _getUserSpecificKey('savedCardType');
    final userCardholderKey = _getUserSpecificKey('savedCardholderName');
    
    await prefs.remove(userCardKey);
    await prefs.remove(userExpiryKey);
    await prefs.remove(userCardTypeKey);
    await prefs.remove(userCardholderKey);
    
    notifyListeners();
  }
} 