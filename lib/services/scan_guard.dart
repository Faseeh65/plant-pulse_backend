/// Two-layered defense against false positives from the FastAPI /predict endpoint.

// ─── Custom Exception ─────────────────────────────────────────────────────────

/// Thrown when a scan result fails the confidence or background-class check.
///
/// The scanner UI catches this and renders the rejection screen instead of
/// navigating to ResultsScreen.
class UnrecognizedScanException implements Exception {
  /// User-facing message (English).  Always bilingual in Urdu below.
  final String message;

  /// Raw confidence value that failed the gate (for logging/debug only).
  final double confidence;

  /// Raw label that triggered the rejection.
  final String label;

  const UnrecognizedScanException({
    required this.message,
    required this.confidence,
    required this.label,
  });

  @override
  String toString() =>
      'UnrecognizedScanException: label="$label" '
      'confidence=${(confidence * 100).toStringAsFixed(1)}% — $message';
}

// ─── Guard Service ────────────────────────────────────────────────────────────

class ScanGuard {
  ScanGuard._();
  static final ScanGuard instance = ScanGuard._();

  /// Minimum acceptable model confidence.
  /// Any prediction below this threshold is rejected as unrecognized.
  ///
  /// Set to 0.90 (90%) — calibrated for the 97.9% Rice-Entropy-Fusion model.
  /// Higher threshold ensures only confident rice disease detections reach the user.
  static const double kConfidenceThreshold = 0.90;

  /// Labels that represent the OOD / Background class or backend rejection.
  /// The backend returns 'NoRiceLeafDetected' when entropy is too low or confidence < 95%.
  static const Set<String> _backgroundLabels = {
    '0_background',
    'background',
    'not_a_leaf',
    'noriceleafdetected',
    'unknown',
    'other',
  };

  /// Validates a raw prediction from the FastAPI /predict endpoint.
  ///
  /// Passes silently if the scan is valid.
  /// Throws [UnrecognizedScanException] if:
  ///   - confidence < [kConfidenceThreshold], OR
  ///   - the top label matches a known OOD/background class label.
  ///
  /// ```dart
  /// final raw = await _predictViaApi(imageFile);
  /// ScanGuard.instance.validate(raw['label'], raw['confidence']);
  /// // Safe to proceed — no exception thrown
  /// ```
  void validate(String label, double confidence) {
    final normalizedLabel = label.trim().toLowerCase().replaceAll(' ', '_');

    // ── Layer 2: Background class check (fast path, no threshold needed) ──
    if (_backgroundLabels.contains(normalizedLabel)) {
      throw UnrecognizedScanException(
        label:      label,
        confidence: confidence,
        message:
            'The model identified this image as a non-plant object. '
            'Please scan a real, clearly visible plant leaf.',
      );
    }

    // ── Layer 1: Confidence threshold gate ─────────────────────────────────
    if (confidence < kConfidenceThreshold) {
      throw UnrecognizedScanException(
        label:      label,
        confidence: confidence,
        message:
            'Confidence too low (${(confidence * 100).toStringAsFixed(1)}% '
            '< ${(kConfidenceThreshold * 100).toStringAsFixed(0)}%). '
            'Please ensure a real, single leaf is clearly visible and well-lit.',
      );
    }
  }

  /// Returns true if the label + confidence pair would pass validation.
  /// Use this for unit tests or preview UIs — does not throw.
  bool isValid(String label, double confidence) {
    try {
      validate(label, confidence);
      return true;
    } on UnrecognizedScanException {
      return false;
    }
  }
}
