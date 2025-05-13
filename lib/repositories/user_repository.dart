import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Get current user data from both Auth and Firestore
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      
      final docSnapshot = await _firestore.collection('users').doc(user.uid).get();
      return UserModel.fromFirebase(user, docSnapshot.data());
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }
  
  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final docSnapshot = await _firestore.collection('users').doc(userId).get();
      final user = _auth.currentUser;
      
      if (user?.uid == userId) {
        return UserModel.fromFirebase(user!, docSnapshot.data());
      } else {
        // If it's not the current user, we don't have Auth data
        final userData = docSnapshot.data();
        if (userData != null) {
          return UserModel(
            id: userId,
            email: userData['email'] ?? '',
            firstName: userData['firstName'],
            lastName: userData['lastName'],
            gender: userData['gender'],
            photoUrl: userData['photoUrl'],
            dateOfBirth: userData['dateOfBirth'] != null 
                ? (userData['dateOfBirth'] as Timestamp).toDate() 
                : null,
            notificationsEnabled: userData['notificationsEnabled'] ?? false,
            fcmToken: userData['fcmToken'],
            countryCode: userData['countryCode'],
            currencyCode: userData['currencyCode'],
            currencySymbol: userData['currencySymbol'],
            connectedHealthService: userData['connectedHealthService'],
            isStravaConnected: userData['isStravaConnected'] ?? false,
            createdAt: userData['createdAt'] != null 
                ? (userData['createdAt'] as Timestamp).toDate() 
                : null,
            updatedAt: userData['updatedAt'] != null 
                ? (userData['updatedAt'] as Timestamp).toDate() 
                : null,
          );
        }
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }
  
  // Update user profile in both Auth and Firestore
  Future<void> updateUserProfile(UserModel user) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No authenticated user');
      
      // Update Auth profile if needed
      if (user.displayName != currentUser.displayName || user.photoUrl != currentUser.photoURL) {
        await currentUser.updateDisplayName(user.displayName);
        if (user.photoUrl != null && user.photoUrl != currentUser.photoURL) {
          await currentUser.updatePhotoURL(user.photoUrl);
        }
      }
      
      // Update Firestore document
      await _firestore.collection('users').doc(user.id).set(
        user.toFirestore(),
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }
  
  // Upload user photo and return the URL
  Future<String?> uploadUserPhoto(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      
      // Create a reference to the user's profile picture
      final storageRef = _storage.ref().child('profile_pictures/${user.uid}');
      
      // Upload the file with metadata
      final uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );
      
      // Get download URL after upload completes
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading user photo: $e');
      return null;
    }
  }
  
  // Update connected health service
  Future<void> updateConnectedHealthService(String serviceName, bool isConnected) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      
      // Special handling for Strava
      if (serviceName == 'Strava') {
        await _firestore.collection('users').doc(user.uid).set({
          'connectedHealthService': isConnected ? serviceName : null,
          'isStravaConnected': isConnected,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await _firestore.collection('users').doc(user.uid).set({
          'connectedHealthService': isConnected ? serviceName : null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error updating connected health service: $e');
      rethrow;
    }
  }
  
  // Save notification preferences
  Future<void> saveNotificationPreferences({
    required bool enabled,
    String? fcmToken,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      
      Map<String, dynamic> data = {
        'notificationsEnabled': enabled,
        'notificationPreferenceSetAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (fcmToken != null) {
        data['fcmToken'] = fcmToken;
      }
      
      await _firestore.collection('users').doc(user.uid).set(
        data,
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error saving notification preferences: $e');
      rethrow;
    }
  }
  
  // Save country and currency settings
  Future<void> saveCountrySettings({
    required String countryCode,
    required String currencyCode,
    required String currencySymbol,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      
      await _firestore.collection('users').doc(user.uid).set({
        'countryCode': countryCode,
        'currencyCode': currencyCode,
        'currencySymbol': currencySymbol,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving country settings: $e');
      rethrow;
    }
  }
} 