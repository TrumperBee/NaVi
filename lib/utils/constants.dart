import 'package:flutter/material.dart';

class AppConstants {
  // Nairobi Green theme color
  static const Color nairobiGreen = Color(0xFF008751);
  
  // App info
  static const String appName = 'NaVi';
  static const String appTagline = 'Nairobi Matatu Wait Times';
  
  // Map defaults
  static const double defaultMapLat = -1.286389; // Nairobi city center
  static const double defaultMapLng = 36.817223;
  static const double defaultMapZoom = 12.0;
  
  // Time intervals for wait time reporting
  static const List<String> waitTimeRanges = [
    '0-5 min',
    '5-10 min',
    '10-15 min',
    '15+ min'
  ];
  
  // Nairobi corridors
  static const Map<String, List<String>> corridors = {
    'Thika Road': ['Thika Road', 'TR', 'Thika Superhighway'],
    'Mombasa Road': ['Mombasa Road', 'Airport Road'],
    'Waiyaki Way': ['Waiyaki Way', 'Westlands', 'Limuru Road'],
    'Lang\'ata Road': ['Lang\'ata Road', 'Magadi Road'],
    'Jogoo Road': ['Jogoo Road', 'Lunga Lunga'],
    'Ngong Road': ['Ngong Road', 'Dagoretti Road'],
  };
  
  // Default Saccos
  static const List<String> saccos = [
    'Super Metro',
    'Double M',
    'Kenya Bus',
    'Citi Hoppa',
    'Embassava',
    'Rembo Shuttle',
    'Southfield',
    'East Shuttle',
    'KBS',
    'Oxygen',
  ];
}