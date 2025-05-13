import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? photoUrl;
  final bool notificationsEnabled;
  final String? fcmToken;
  final String? countryCode;
  final String? currencyCode;
  final String? currencySymbol;
  final String? connectedHealthService;
  final bool isStravaConnected;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.gender,
    this.dateOfBirth,
    this.photoUrl,
    this.notificationsEnabled = false,
    this.fcmToken,
    this.countryCode,
    this.currencyCode,
    this.currencySymbol,
    this.connectedHealthService,
    this.isStravaConnected = false,
    this.createdAt,
    this.updatedAt,
  });

  String? get displayName {
    if (firstName != null || lastName != null) {
      return [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');
    }
    return null;
  }

  // Factory constructor from Firebase Auth + Firestore
  factory UserModel.fromFirebase(User authUser, Map<String, dynamic>? firestoreData) {
    final data = firestoreData ?? {};
    
    // Extract firstName and lastName from displayName if not in Firestore
    String? firstName = data['firstName'];
    String? lastName = data['lastName'];
    
    if ((firstName == null || lastName == null) && authUser.displayName != null) {
      final nameParts = authUser.displayName!.split(' ');
      if (nameParts.isNotEmpty) {
        firstName ??= nameParts[0];
        if (nameParts.length > 1) {
          lastName ??= nameParts.sublist(1).join(' ');
        }
      }
    }

    return UserModel(
      id: authUser.uid,
      email: authUser.email ?? '',
      firstName: firstName,
      lastName: lastName,
      gender: data['gender'],
      dateOfBirth: data['dateOfBirth'] != null 
          ? (data['dateOfBirth'] as Timestamp).toDate() 
          : null,
      photoUrl: authUser.photoURL,
      notificationsEnabled: data['notificationsEnabled'] ?? false,
      fcmToken: data['fcmToken'],
      countryCode: data['countryCode'],
      currencyCode: data['currencyCode'],
      currencySymbol: data['currencySymbol'],
      connectedHealthService: data['connectedHealthService'],
      isStravaConnected: data['isStravaConnected'] ?? false,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : null,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'gender': gender,
      'dateOfBirth': dateOfBirth,
      'notificationsEnabled': notificationsEnabled,
      'fcmToken': fcmToken,
      'countryCode': countryCode,
      'currencyCode': currencyCode,
      'currencySymbol': currencySymbol,
      'connectedHealthService': connectedHealthService,
      'isStravaConnected': isStravaConnected,
      'updatedAt': DateTime.now(),
    };
  }

  // Create a copy with updated fields
  UserModel copyWith({
    String? firstName,
    String? lastName,
    String? gender,
    DateTime? dateOfBirth,
    String? photoUrl,
    bool? notificationsEnabled,
    String? fcmToken,
    String? countryCode,
    String? currencyCode,
    String? currencySymbol,
    String? connectedHealthService,
    bool? isStravaConnected,
  }) {
    return UserModel(
      id: this.id,
      email: this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      photoUrl: photoUrl ?? this.photoUrl,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      fcmToken: fcmToken ?? this.fcmToken,
      countryCode: countryCode ?? this.countryCode,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      connectedHealthService: connectedHealthService ?? this.connectedHealthService,
      isStravaConnected: isStravaConnected ?? this.isStravaConnected,
      createdAt: this.createdAt,
      updatedAt: DateTime.now(),
    );
  }
} 