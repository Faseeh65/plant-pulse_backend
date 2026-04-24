import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/database_service.dart';
import '../models/map_marker_data.dart';

class MapProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  LatLng? _userLocation;
  LatLng? get userLocation => _userLocation;

  Set<Marker> _markers = {};
  Set<Marker> get markers => _markers;

  List<MapMarkerData> _allScans = [];
  String _selectedDisease = 'Show All';
  String get selectedDisease => _selectedDisease;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  MapProvider() {
    _initLocation();
    refreshData();
  }

  Future<void> _initLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      _userLocation = LatLng(pos.latitude, pos.longitude);
      notifyListeners();

      Geolocator.getPositionStream().listen((pos) {
        _userLocation = LatLng(pos.latitude, pos.longitude);
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
      _applyFilters();
    } catch (e) {
      debugPrint('MapProvider refresh error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _applyFilters() {
    final filtered = _allScans.where((s) {
      if (_selectedDisease == 'Show All') return true;
      return s.diseaseType == _selectedDisease;
    }).toList();

    _markers = filtered.map((data) {
      return Marker(
        markerId: MarkerId(data.id),
        position: LatLng(data.lat, data.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(_getHueForDisease(data.diseaseType)),
        infoWindow: InfoWindow(
          title: data.diseaseType,
          snippet: 'Confidence: ${(data.confidence * 100).toStringAsFixed(1)}%',
        ),
      );
    }).toSet();

    notifyListeners();
  }

  double _getHueForDisease(String type) {
    final t = type.toLowerCase();
    if (t.contains('bacterial')) return BitmapDescriptor.hueRed;
    if (t.contains('brown')) return BitmapDescriptor.hueOrange;
    if (t.contains('tungro')) return BitmapDescriptor.hueViolet;
    return BitmapDescriptor.hueGreen;
  }
}
