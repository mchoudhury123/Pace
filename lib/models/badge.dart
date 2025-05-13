import 'package:flutter/material.dart';

class Badge {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final double requirement; // The value needed to achieve this badge
  final String type; // 'distance', 'donations', or 'runs'
  final String unit; // 'km', '$', or 'runs'
  final int level; // 1-5, representing bronze, silver, gold, platinum, diamond

  const Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.requirement,
    required this.type,
    required this.unit,
    required this.level,
  });

  String get levelName {
    switch (level) {
      case 1:
        return 'Bronze';
      case 2:
        return 'Silver';
      case 3:
        return 'Gold';
      case 4:
        return 'Platinum';
      case 5:
        return 'Diamond';
      default:
        return 'Unknown';
    }
  }

  Color get levelColor {
    switch (level) {
      case 1:
        return const Color(0xFFCD7F32); // Bronze
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFFFD700); // Gold
      case 4:
        return const Color(0xFFE5E4E2); // Platinum
      case 5:
        return const Color(0xFFB9F2FF); // Diamond
      default:
        return Colors.grey;
    }
  }

  static List<Badge> getAllBadges() {
    return [
      // Distance Badges
      const Badge(
        id: 'distance_1',
        name: 'First Steps',
        description: 'Run your first 5 kilometers',
        icon: Icons.directions_run,
        color: Colors.blue,
        requirement: 5,
        type: 'distance',
        unit: 'km',
        level: 1,
      ),
      const Badge(
        id: 'distance_2',
        name: 'Road Warrior',
        description: 'Complete 25 kilometers',
        icon: Icons.directions_run,
        color: Colors.blue,
        requirement: 25,
        type: 'distance',
        unit: 'km',
        level: 2,
      ),
      const Badge(
        id: 'distance_3',
        name: 'Marathon Master',
        description: 'Run 100 kilometers',
        icon: Icons.directions_run,
        color: Colors.blue,
        requirement: 100,
        type: 'distance',
        unit: 'km',
        level: 3,
      ),
      const Badge(
        id: 'distance_4',
        name: 'Ultra Runner',
        description: 'Complete 250 kilometers',
        icon: Icons.directions_run,
        color: Colors.blue,
        requirement: 250,
        type: 'distance',
        unit: 'km',
        level: 4,
      ),
      const Badge(
        id: 'distance_5',
        name: 'Elite Athlete',
        description: 'Run 500 kilometers',
        icon: Icons.directions_run,
        color: Colors.blue,
        requirement: 500,
        type: 'distance',
        unit: 'km',
        level: 5,
      ),

      // Donation Badges
      const Badge(
        id: 'donation_1',
        name: 'First Gift',
        description: 'Donate your first \$10',
        icon: Icons.favorite,
        color: Colors.red,
        requirement: 10,
        type: 'donations',
        unit: '\$',
        level: 1,
      ),
      const Badge(
        id: 'donation_2',
        name: 'Generous Heart',
        description: 'Reach \$50 in donations',
        icon: Icons.favorite,
        color: Colors.red,
        requirement: 50,
        type: 'donations',
        unit: '\$',
        level: 2,
      ),
      const Badge(
        id: 'donation_3',
        name: 'Charity Champion',
        description: 'Donate \$200 total',
        icon: Icons.favorite,
        color: Colors.red,
        requirement: 200,
        type: 'donations',
        unit: '\$',
        level: 3,
      ),
      const Badge(
        id: 'donation_4',
        name: 'Philanthropy Pro',
        description: 'Reach \$500 in donations',
        icon: Icons.favorite,
        color: Colors.red,
        requirement: 500,
        type: 'donations',
        unit: '\$',
        level: 4,
      ),
      const Badge(
        id: 'donation_5',
        name: 'Legendary Donor',
        description: 'Donate \$1000 total',
        icon: Icons.favorite,
        color: Colors.red,
        requirement: 1000,
        type: 'donations',
        unit: '\$',
        level: 5,
      ),

      // Run Count Badges
      const Badge(
        id: 'runs_1',
        name: 'Getting Started',
        description: 'Complete 5 runs',
        icon: Icons.timer,
        color: Colors.green,
        requirement: 5,
        type: 'runs',
        unit: 'runs',
        level: 1,
      ),
      const Badge(
        id: 'runs_2',
        name: 'Regular Runner',
        description: 'Complete 15 runs',
        icon: Icons.timer,
        color: Colors.green,
        requirement: 15,
        type: 'runs',
        unit: 'runs',
        level: 2,
      ),
      const Badge(
        id: 'runs_3',
        name: 'Dedicated Athlete',
        description: 'Complete 30 runs',
        icon: Icons.timer,
        color: Colors.green,
        requirement: 30,
        type: 'runs',
        unit: 'runs',
        level: 3,
      ),
      const Badge(
        id: 'runs_4',
        name: 'Running Expert',
        description: 'Complete 50 runs',
        icon: Icons.timer,
        color: Colors.green,
        requirement: 50,
        type: 'runs',
        unit: 'runs',
        level: 4,
      ),
      const Badge(
        id: 'runs_5',
        name: 'Running Legend',
        description: 'Complete 100 runs',
        icon: Icons.timer,
        color: Colors.green,
        requirement: 100,
        type: 'runs',
        unit: 'runs',
        level: 5,
      ),
    ];
  }
} 