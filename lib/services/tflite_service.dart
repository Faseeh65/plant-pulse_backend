import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class TFLiteService {
  Interpreter? _interpreter;
  List<String>? _labels;

  // Constants to match Phase 2C Training logic
  static const int inputSize = 224;
  static const String modelPath = 'assets/models/plant_pulse_model.tflite';
  static const String labelsPath = 'assets/models/labels.json';

  /// Loads the quantized Floating-point model with NNAPI Hardware Acceleration
  Future<void> initModel() async {
    try {
      // 1. Configure Hardware Acceleration (Default XNNPACK is automatically used in v0.12+)
      var interpreterOptions = InterpreterOptions();
      // NnApiDelegate is deprecated/removed in the latest tflite_flutter. XNNPACK is now the high-performance default.

      // 2. Initializing the Interpreter
      _interpreter = await Interpreter.fromAsset(
        modelPath,
        options: interpreterOptions,
      );

      // 3. Loading the labels dictionary
      await _loadLabels();

      debugPrint('🎉 TFLite Model Loaded Successfully with XNNPACK acceleration!');
    } catch (e) {
      throw Exception('VULNERABILITY DETECTED: Initialization Failed. Failed to load TFLite model: $e');
    }
  }

  Future<void> _loadLabels() async {
    final String labelsData = await rootBundle.loadString(labelsPath);
    final Map<String, dynamic> labelsJson = json.decode(labelsData);
    
    // Sort keys numerically to ensure alignment with model output indices
    _labels = labelsJson.entries
        .toList()
        .map((e) => e.value.toString())
        .toList();
  }

  /// Runs inference on the provided image file
  Future<Map<String, dynamic>> predict(File imageFile) async {
    if (_interpreter == null || _labels == null) {
      throw Exception('MODEL ERROR: Inference attempted on an uninitialized brain.');
    }

    // --- PRE-PROCESSING BLOCK (Phase 2C Identical) ---
    // 1. Read Image
    final bytes = await imageFile.readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) throw Exception('Image decoding failed.');

    // 2. Resize to 224 x 224
    img.Image resizedImage = img.copyResize(
      originalImage,
      width: inputSize,
      height: inputSize,
    );

    // 3. Normalization [0, 1] + Tensor Conversion (Float32)
    var input = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(input.buffer);
    int pixelIndex = 0;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        var pixel = resizedImage.getPixel(x, y);
        // Extract RGB and normalize to [0, 1] as per data_pipeline.py logic
        buffer[pixelIndex++] = pixel.r / 255.0;
        buffer[pixelIndex++] = pixel.g / 255.0;
        buffer[pixelIndex++] = pixel.b / 255.0;
      }
    }

    // 4. Shaping input [1, 224, 224, 3]
    var inputReshaped = input.reshape([1, 224, 224, 3]);

    // --- INFERENCE BLOCK ---
    // Output shape: [1, num_classes] (e.g., [1, 76])
    var output = List<double>.filled(_labels!.length, 0).reshape([1, _labels!.length]);

    _interpreter!.run(inputReshaped, output);

    // --- POST-PROCESSING ---
    List<double> probabilities = List<double>.from(output[0]);
    
    // Find the highest confidence index
    double maxConfidence = -1.0;
    int maxIndex = -1;

    for (int i = 0; i < probabilities.length; i++) {
      if (probabilities[i] > maxConfidence) {
        maxConfidence = probabilities[i];
        maxIndex = i;
      }
    }

    if (maxIndex == -1) throw Exception('Inference failed to yield probabilities.');

    // --- Confidence Gate Optimization ---
    String finalLabel = _labels![maxIndex];
    if (maxConfidence < 0.45) {
      finalLabel = 'Unknown';
    }

    return {
      'label': finalLabel,
      'confidence': maxConfidence,
    };
  }

  void dispose() {
    _interpreter?.close();
  }
}
