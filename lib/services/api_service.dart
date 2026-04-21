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
  Future<DiseaseResult> fetchDiagnosisDetails(String diseaseId, {double acres = 1.0, String lang = 'en'}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/treatment/$diseaseId?acres=$acres'),
        headers: {
          'Content-Type': 'application/json',
          'lang': lang,
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
      if (e.toString().contains('Timeout') || e.toString().contains('SocketException')) {
        throw Exception('CONNECTION_FAILED');
      }
      rethrow;
    }
  }

  /// Silently saves a completed scan to the cloud via the FastAPI backend.
  Future<bool> saveScanResult({
    required String userId,
    required String plantName,
    required String diseaseResult,
    required double confidenceScore,
  }) async {
    if (userId.isEmpty) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/history/save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id':          userId,
          'crop_name':        plantName,
          'disease_result':   diseaseResult,
          'confidence_score': confidenceScore,
        }),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('saveScanResult failed: $e');
      return false;
    }
  }

  Future<List<dynamic>> getHistory(String userId) async {
    if (userId.isEmpty) return [];
    final uri = Uri.parse('$baseUrl/history/$userId');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return decoded['scans'] ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('getHistory failed: $e');
      return [];
    }
  }


  /// Fetches aggregated crop statistics for the authenticated user.
  Future<CropSummary> fetchCropSummary(String userId) async {
    if (userId.isEmpty) {
      return const CropSummary(
        totalScans: 0, healthyCount: 0, diseasedCount: 0,
        healthyPct: 0.0, diseasedPct: 0.0, topDiseases: [],
      );
    }

    final uri = Uri.parse('$baseUrl/stats') 
        .replace(queryParameters: {'user_id': userId});
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return CropSummary.fromJson(decoded);
      }
      return const CropSummary(
        totalScans: 0, healthyCount: 0, diseasedCount: 0,
        healthyPct: 0.0, diseasedPct: 0.0, topDiseases: [],
      );
    } catch (e) {
      debugPrint('fetchCropSummary failed: $e');
      return const CropSummary(
        totalScans: 0, healthyCount: 0, diseasedCount: 0,
        healthyPct: 0.0, diseasedPct: 0.0, topDiseases: [],
      );
    }
  }

  /// Fetches all upcoming reminders for this user from the backend.
  Future<List<SprayReminder>> fetchActiveReminders(String userId) async {
    if (userId.isEmpty) return [];

    final uri = Uri.parse('$baseUrl/reminders') 
        .replace(queryParameters: {'user_id': userId});
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final list = (decoded['reminders'] as List?) ?? [];
        return list.map((e) => SprayReminder.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('fetchActiveReminders failed: $e');
      return [];
    }
  }

  /// Schedules a new spray reminder via the backend.
  Future<String?> createReminder({
    required String userId,
    required String plantName,
    required String diseaseName,
    required String treatmentType,
    required DateTime scheduledTime,
  }) async {
    if (userId.isEmpty) return null;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reminders'), 
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id':        userId,
          'plant_name':     plantName,
          'disease_name':   diseaseName,
          'treatment_type': treatmentType,
          'scheduled_time': scheduledTime.toUtc().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return decoded['record_id'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('createReminder failed: $e');
      return null;
    }
  }

  /// Marks a reminder as completed.
  Future<bool> markReminderComplete(String reminderId, String userId) async {
    if (userId.isEmpty) return false;
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/reminders/$reminderId/complete')
            .replace(queryParameters: {'user_id': userId}),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('markReminderComplete failed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    if (userId.isEmpty) return null;
    final uri = Uri.parse('$baseUrl/profile/$userId');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('fetchUserProfile failed: $e');
      return null;
    }
  }

  Future<bool> updateUserProfile({
    required String userId,
    String? fullName,
    String? phone,
    String? location,
  }) async {
    if (userId.isEmpty) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/profile/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id':   userId,
          'full_name': fullName ?? '',
          'phone':     phone ?? '',
          'location':  location ?? '',
        }),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('updateUserProfile failed: $e');
      return false;
    }
  }
}

class SprayReminder {
  final String id;
  final String plantName;
  final String diseaseName;
  final String treatmentType;
  final DateTime scheduledTime;
  final bool isCompleted;

  const SprayReminder({
    required this.id,
    required this.plantName,
    required this.diseaseName,
    required this.treatmentType,
    required this.scheduledTime,
    required this.isCompleted,
  });

  factory SprayReminder.fromJson(Map<String, dynamic> j) => SprayReminder(
        id:            j['id'] as String,
        plantName:     j['plant_name'] as String? ?? '',
        diseaseName:   j['disease_name'] as String? ?? '',
        treatmentType: j['treatment_type'] as String? ?? '',
        scheduledTime: DateTime.parse(j['scheduled_time'] as String),
        isCompleted:   j['is_completed'] as bool? ?? false,
      );

  int get notifId => id.hashCode.abs() % 2147483647;
}

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
