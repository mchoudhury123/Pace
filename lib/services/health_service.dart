import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'dart:io' show Platform;

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health health = Health();

  // Types of data to request from HealthKit
  static final List<HealthDataType> _dataTypes = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
    HealthDataType.WORKOUT,
  ];

  // Request authorization for health data
  Future<bool> requestAuthorization() async {
    if (!Platform.isIOS) return false;

    try {
      final types = _dataTypes;
      final granted = await health.requestAuthorization(types, permissions: [
        HealthDataAccess.READ,
        HealthDataAccess.WRITE,
      ]);
      debugPrint('Health data authorization granted: $granted');
      return granted;
    } catch (e) {
      debugPrint('Error requesting health authorization: $e');
      return false;
    }
  }

  // Fetch health data for a specific type and time range
  Future<List<HealthDataPoint>> fetchHealthData(
    HealthDataType type,
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      final data = await health.getHealthDataFromTypes(
        startTime: startTime,
        endTime: endTime,
        types: [type],
      );
      return data;
    } catch (e) {
      debugPrint('Error fetching health data: $e');
      return [];
    }
  }

  // Get step count for a specific day
  Future<int> getStepsForDay(DateTime date) async {
    try {
      final midnight = DateTime(date.year, date.month, date.day);
      final now = DateTime.now();
      final endTime = date.day == now.day ? now : DateTime(date.year, date.month, date.day, 23, 59, 59);

      final steps = await fetchHealthData(
        HealthDataType.STEPS,
        midnight,
        endTime,
      );

      int totalSteps = 0;
      for (var step in steps) {
        totalSteps += (step.value as NumericHealthValue).numericValue.toInt();
      }
      return totalSteps;
    } catch (e) {
      debugPrint('Error getting steps: $e');
      return 0;
    }
  }

  // Get distance walked/run for a specific day (in meters)
  Future<double> getDistanceForDay(DateTime date) async {
    try {
      final midnight = DateTime(date.year, date.month, date.day);
      final now = DateTime.now();
      final endTime = date.day == now.day ? now : DateTime(date.year, date.month, date.day, 23, 59, 59);

      final distance = await fetchHealthData(
        HealthDataType.DISTANCE_WALKING_RUNNING,
        midnight,
        endTime,
      );

      double totalDistance = 0;
      for (var d in distance) {
        totalDistance += (d.value as NumericHealthValue).numericValue;
      }
      return totalDistance;
    } catch (e) {
      debugPrint('Error getting distance: $e');
      return 0;
    }
  }

  // Get calories burned for a specific day
  Future<double> getCaloriesForDay(DateTime date) async {
    try {
      final midnight = DateTime(date.year, date.month, date.day);
      final now = DateTime.now();
      final endTime = date.day == now.day ? now : DateTime(date.year, date.month, date.day, 23, 59, 59);

      final calories = await fetchHealthData(
        HealthDataType.ACTIVE_ENERGY_BURNED,
        midnight,
        endTime,
      );

      double totalCalories = 0;
      for (var c in calories) {
        totalCalories += (c.value as NumericHealthValue).numericValue;
      }
      return totalCalories;
    } catch (e) {
      debugPrint('Error getting calories: $e');
      return 0;
    }
  }

  // Get average heart rate for a specific day
  Future<double> getAverageHeartRateForDay(DateTime date) async {
    try {
      final midnight = DateTime(date.year, date.month, date.day);
      final now = DateTime.now();
      final endTime = date.day == now.day ? now : DateTime(date.year, date.month, date.day, 23, 59, 59);

      final heartRates = await fetchHealthData(
        HealthDataType.HEART_RATE,
        midnight,
        endTime,
      );

      if (heartRates.isEmpty) return 0;

      double totalHeartRate = 0;
      for (var hr in heartRates) {
        totalHeartRate += (hr.value as NumericHealthValue).numericValue;
      }
      return totalHeartRate / heartRates.length;
    } catch (e) {
      debugPrint('Error getting heart rate: $e');
      return 0;
    }
  }
} 