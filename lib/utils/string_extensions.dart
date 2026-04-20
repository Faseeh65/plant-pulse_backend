import 'package:flutter/material.dart';

extension StringFormatting on String {
  /// Cleans technical disease labels for professional UI display.
  /// Handles both "Potato___Early_blight" and "Apple Brown_spot".
  String toDisplayDisease() {
    if (isEmpty) return this;
    // Replace legacy delimiter and underscores with spaces
    String cleaned = replaceAll('___', ' ').replaceAll('_', ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Extracts the crop name (first part).
  /// Handles "Apple Brown_spot" -> "Apple"
  /// Handles "tomato_early_blight" -> "Tomato"
  String toDisplayCrop() {
    if (isEmpty) return this;
    final parts = split(RegExp(r'[ _]'));
    String crop = parts.first;
    if (crop.isEmpty) return 'Unknown';
    return crop[0].toUpperCase() + crop.substring(1).toLowerCase();
  }

  /// Extracts only the disease part (everything after the crop).
  /// Handles "Apple Brown_spot" -> "Brown Spot"
  /// Handles "tomato_early_blight" -> "Early Blight"
  String toDiseaseOnly() {
    if (isEmpty) return this;
    final parts = split(RegExp(r'[ _]'));
    if (parts.length <= 1) return toDisplayDisease(); // Fallback to full if only one word
    
    return parts.skip(1).map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
