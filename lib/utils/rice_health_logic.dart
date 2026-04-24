import 'package:flutter/material.dart';

class RiceHealthLogic {
  /// Analyzes environmental data to provide actionable agricultural alerts.
  /// Logic based on humidity levels and temperature thresholds for common rice diseases.
  static Map<String, dynamic> getEnvironmentalAlert(int humidity, double temp) {
    
    // 1. Critical Fungal Risk (Humidity > 85%)
    if (humidity > 85) {
      return {
        "message": "CRITICAL: High Fungal Risk. Monitor for Blast.",
        "color": Colors.redAccent,
        "icon": Icons.warning_amber_rounded,
      };
    } 
    
    // 2. High Bacterial Risk (High Temp + High Humidity)
    else if (humidity > 75 && temp > 28) {
      return {
        "message": "WARNING: Warm & Humid. Check for Leaf Blight.",
        "color": Colors.orangeAccent,
        "icon": Icons.thermostat_rounded,
      };
    } 
    
    // 3. Perfect Growing Conditions
    else if (humidity >= 50 && humidity <= 70) {
      return {
        "message": "Healthy Environment: Ideal for rice growth.",
        "color": const Color(0xFF6CFB7B), // Matching app primary green
        "icon": Icons.check_circle_outline,
      };
    } 
    
    // 4. Default Stable state
    else {
      return {
        "message": "Environmental conditions are currently stable.",
        "color": Colors.blueAccent,
        "icon": Icons.info_outline,
      };
    }
  }
}
