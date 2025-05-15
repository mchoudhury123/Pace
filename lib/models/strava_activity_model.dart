import 'package:strava_client/strava_client.dart';

class StravaActivityModel {
  final int id;
  final String name;
  final String type;
  final DateTime startDate;
  final double distance; // in meters
  final int movingTime; // in seconds
  final int elapsedTime; // in seconds
  final double elevationGain; // in meters
  final String? mapPolyline;
  final double? averageSpeed; // in meters per second
  final double? maxSpeed; // in meters per second
  final int? averageHeartrate;
  final int? maxHeartrate;
  final double? calories;

  StravaActivityModel({
    required this.id,
    required this.name,
    required this.type,
    required this.startDate,
    required this.distance,
    required this.movingTime,
    required this.elapsedTime,
    required this.elevationGain,
    this.mapPolyline,
    this.averageSpeed,
    this.maxSpeed,
    this.averageHeartrate,
    this.maxHeartrate,
    this.calories,
  });

  // Convert from dynamic JSON to our model
  factory StravaActivityModel.fromJson(Map<String, dynamic> json) {
    return StravaActivityModel(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String,
      startDate: DateTime.parse(json['start_date']),
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      movingTime: (json['moving_time'] as num?)?.toInt() ?? 0,
      elapsedTime: (json['elapsed_time'] as num?)?.toInt() ?? 0,
      elevationGain: (json['total_elevation_gain'] as num?)?.toDouble() ?? 0.0,
      mapPolyline: json['map']?['polyline'] as String?,
      averageSpeed: (json['average_speed'] as num?)?.toDouble(),
      maxSpeed: (json['max_speed'] as num?)?.toDouble(),
      averageHeartrate: (json['average_heartrate'] as num?)?.toInt(),
      maxHeartrate: (json['max_heartrate'] as num?)?.toInt(),
      calories: (json['calories'] as num?)?.toDouble(),
    );
  }

  // Convert to a Map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'startDate': startDate.toIso8601String(),
      'distance': distance,
      'movingTime': movingTime,
      'elapsedTime': elapsedTime,
      'elevationGain': elevationGain,
      'mapPolyline': mapPolyline,
      'averageSpeed': averageSpeed,
      'maxSpeed': maxSpeed,
      'averageHeartrate': averageHeartrate,
      'maxHeartrate': maxHeartrate,
      'calories': calories,
    };
  }

  // Create from a Map (e.g., from storage)
  factory StravaActivityModel.fromMap(Map<String, dynamic> map) {
    return StravaActivityModel(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      startDate: DateTime.parse(map['startDate']),
      distance: map['distance'],
      movingTime: map['movingTime'],
      elapsedTime: map['elapsedTime'],
      elevationGain: map['elevationGain'],
      mapPolyline: map['mapPolyline'],
      averageSpeed: map['averageSpeed'],
      maxSpeed: map['maxSpeed'],
      averageHeartrate: map['averageHeartrate'],
      maxHeartrate: map['maxHeartrate'],
      calories: map['calories'],
    );
  }

  // Helper methods

  // Get distance in kilometers
  double get distanceInKm => distance / 1000;

  // Get distance in miles
  double get distanceInMiles => distance / 1609.34;

  // Get pace in minutes per kilometer
  double get pacePerKm {
    if (distance == 0) return 0;
    return (movingTime / 60) / (distance / 1000);
  }

  // Get pace in minutes per mile
  double get pacePerMile {
    if (distance == 0) return 0;
    return (movingTime / 60) / (distance / 1609.34);
  }

  // Format pace as mm:ss
  String formatPace(double paceInMinutes) {
    final minutes = paceInMinutes.floor();
    final seconds = ((paceInMinutes - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // Get formatted pace per km
  String get formattedPacePerKm => formatPace(pacePerKm);

  // Get formatted pace per mile
  String get formattedPacePerMile => formatPace(pacePerMile);

  // Get moving time in hours:minutes:seconds format
  String get formattedMovingTime {
    final hours = (movingTime / 3600).floor();
    final minutes = ((movingTime % 3600) / 60).floor();
    final seconds = movingTime % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
