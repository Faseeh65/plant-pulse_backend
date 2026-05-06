import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import '../services/database_service.dart';
import '../models/map_marker_data.dart';
import 'dart:math';

enum MapLayerType { street, satellite, heatmap }

class MapProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  ll.LatLng? _userLocation;
  ll.LatLng? get userLocation => _userLocation;

  List<MapMarkerData> _markers = [];
  List<MapMarkerData> get markers => _markers;

  List<MapMarkerData> _allScans = [];
  String _selectedDisease = 'Show All';
  String get selectedDisease => _selectedDisease;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  MapLayerType _currentLayer = MapLayerType.street;
  MapLayerType get currentLayer => _currentLayer;

  MapProvider() {
    _initLocation();
    refreshData();
  }

  Future<void> _initLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      _userLocation = ll.LatLng(pos.latitude, pos.longitude);
      notifyListeners();

      Geolocator.getPositionStream().listen((pos) {
        _userLocation = ll.LatLng(pos.latitude, pos.longitude);
        notifyListeners();
      });
    } catch (e) {
      debugPrint('MapProvider location error: $e');
    }
  }

  void setFilter(String disease) {
    _selectedDisease = disease;
    _applyFilters();
  }

  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final rawScans = await _dbService.getUserScanHistory();
      _allScans = rawScans
          .where((s) => s['lat'] != null && s['lng'] != null)
          .map((s) => MapMarkerData.fromLocal(s))
          .toList();

      // Fallback: Add sample regional intelligence if history is empty
      if (_allScans.isEmpty) {
        _allScans = _getSampleIntelligence();
      }

      _applyFilters();
    } catch (e) {
      debugPrint('MapProvider refresh error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<MapMarkerData> _getSampleIntelligence() {
    final base = _userLocation ?? ll.LatLng(30.3753, 69.3451);
    return [
      MapMarkerData(
        id: 'sample1',
        lat: base.latitude + 0.012,
        lng: base.longitude + 0.008,
        diseaseType: 'Bacterial Blight',
        confidence: 0.94,
        date: DateTime.now(),
      ),
      MapMarkerData(
        id: 'sample2',
        lat: base.latitude - 0.005,
        lng: base.longitude + 0.015,
        diseaseType: 'Brown Spot',
        confidence: 0.88,
        date: DateTime.now(),
      ),
      MapMarkerData(
        id: 'sample3',
        lat: base.latitude + 0.008,
        lng: base.longitude - 0.012,
        diseaseType: 'Tungro',
        confidence: 0.91,
        date: DateTime.now(),
      ),
      MapMarkerData(
        id: 'sample4',
        lat: base.latitude - 0.015,
        lng: base.longitude - 0.005,
        diseaseType: 'Bacterial Blight',
        confidence: 0.96,
        date: DateTime.now(),
      ),
    ];
  }

  void _applyFilters() {
    _markers = _allScans.where((s) {
      if (_selectedDisease == 'Show All') return true;
      return s.diseaseType.toLowerCase() == _selectedDisease.toLowerCase();
    }).toList();

    notifyListeners();
  }

  void toggleLayer() {
    int nextIndex = (_currentLayer.index + 1) % MapLayerType.values.length;
    _currentLayer = MapLayerType.values[nextIndex];
    notifyListeners();
  }
}

