import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/disease_result.dart';

class ApiService {
  // Use public IPv4 for global accessibility (Delivery Mode)
  static const String baseUrl = "http://192.168.1.220:8000";
  bool _hasLoggedSuccess = false;

  /// Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Verifies connectivity to the FastAPI server
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('FastAPI Health Check Failed: $e');
      return false;
    }
  }

  /// Fetches structured diagnosis data from FastAPI backend
  /// Replaces direct Supabase/Local calls for Phase 8 Architecture
  Future<DiseaseResult> fetchDiagnosisDetails(String diseaseId, {double acres = 1.0, String lang = 'en'}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/treatment/$diseaseId?acres=$acres'),
        headers: {
          'Content-Type': 'application/json',
          'lang': lang, // Bilingual Middleware trigger
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        if (!_hasLoggedSuccess) {
          _hasLoggedSuccess = true;
          debugPrint('✅ Successfully connected to FastAPI at $baseUrl');
        }
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return DiseaseResult.fromJson(decoded);
      } else {
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('API_ERROR_${response.statusCode}');
      }
    } catch (e) {
      debugPrint('FastAPI communication error: $e');
      // Special flag for connection-level failures (timeouts, socket errors)
      if (e.toString().contains('Timeout') || e.toString().contains('SocketException')) {
        throw Exception('CONNECTION_FAILED');
      }
      rethrow;
    }
  }
}
