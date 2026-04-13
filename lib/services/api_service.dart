import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/disease_result.dart';

class ApiService {
  // Use public IPv4 for global accessibility (Delivery Mode)
  static const String baseUrl = "https://plant-pulsebackend-production.up.railway.app";
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
  /// Silently saves a completed scan to the cloud via the FastAPI backend.
  ///
  /// Returns [true] on success, [false] on any network or server error.
  /// Never throws — caller shows a subtle SnackBar on false.
  Future<bool> saveScanResult({
    required String userId,
    required String plantName,
    required String diseaseResult,
    required double confidenceScore,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/scans/save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id':          userId,
          'plant_name':       plantName,
          'disease_result':   diseaseResult,
          'confidence_score': confidenceScore,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('✅ Scan saved to cloud history.');
        return true;
      } else {
        debugPrint('⚠️ saveScanResult HTTP ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('⚠️ saveScanResult failed (network): $e');
      return false;
    }
  }
  /// Fetches aggregated crop statistics for the authenticated user.
  /// Throws [Exception] on network or server failure.
  Future<CropSummary> fetchCropSummary(String userId) async {
    final uri = Uri.parse('$baseUrl/api/v1/stats/crop-summary')
        .replace(queryParameters: {'user_id': userId});
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return CropSummary.fromJson(decoded);
      } else {
        throw Exception('STATS_ERROR_${response.statusCode}');
      }
    } catch (e) {
      debugPrint('fetchCropSummary failed: $e');
      rethrow;
    }
  }
}

// ─── Data Models ──────────────────────────────────────────────────────────────

class TopDisease {
  final String disease;
  final int count;
  final double percentage;

  const TopDisease({
    required this.disease,
    required this.count,
    required this.percentage,
  });

  factory TopDisease.fromJson(Map<String, dynamic> j) => TopDisease(
        disease:    j['disease'] as String? ?? 'Unknown',
        count:      (j['count'] as num?)?.toInt() ?? 0,
        percentage: (j['percentage'] as num?)?.toDouble() ?? 0.0,
      );
}

class CropSummary {
  final int totalScans;
  final int healthyCount;
  final int diseasedCount;
  final double healthyPct;
  final double diseasedPct;
  final List<TopDisease> topDiseases;

  const CropSummary({
    required this.totalScans,
    required this.healthyCount,
    required this.diseasedCount,
    required this.healthyPct,
    required this.diseasedPct,
    required this.topDiseases,
  });

  factory CropSummary.fromJson(Map<String, dynamic> j) => CropSummary(
        totalScans:    (j['total_scans']    as num?)?.toInt() ?? 0,
        healthyCount:  (j['healthy_count']  as num?)?.toInt() ?? 0,
        diseasedCount: (j['diseased_count'] as num?)?.toInt() ?? 0,
        healthyPct:    (j['healthy_pct']    as num?)?.toDouble() ?? 0.0,
        diseasedPct:   (j['diseased_pct']   as num?)?.toDouble() ?? 0.0,
        topDiseases:   ((j['top_diseases'] as List?) ?? [])
            .map((e) => TopDisease.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

