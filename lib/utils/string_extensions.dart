import 'package:flutter/material.dart';

extension StringFormatting on String {
  /// Cleans technical disease labels for professional UI display.
  /// Handles CamelCase Rice Fusion labels like "BacterialLeafBlight" → "Bacterial Leaf Blight".
  /// Also handles legacy space/underscore formats as fallback.
  String toDisplayDisease() {
    if (isEmpty) return this;
    // Split CamelCase: insert space before each uppercase letter that follows a lowercase
    String cleaned = replaceAllMapped(
      RegExp(r'(?<=[a-z])(?=[A-Z])'),
      (match) => ' ',
    );
    // Also handle underscores/triple-underscores as fallback
    cleaned = cleaned.replaceAll('___', ' ').replaceAll('_', ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Dynamically maps disease classes to their respective crops.
  String toDisplayCrop() {
    Map<String, String> cropFromClass = {
      'BacterialLeafBlight': 'Rice',
      'BrownSpot': 'Rice',
      'Healthy': 'Rice',
      'LeafBlast': 'Rice',
      'LeafScald': 'Rice',
      'NarrowBrownSpot': 'Rice',
    };
    return cropFromClass[this] ?? 'Rice';
  }

  /// Extracts the disease name from a CamelCase label.
  /// "BacterialLeafBlight" → "Bacterial Leaf Blight"
  /// "Healthy" → "Healthy"
  String toDiseaseOnly() {
    if (isEmpty) return this;
    return toDisplayDisease();
  }
}
