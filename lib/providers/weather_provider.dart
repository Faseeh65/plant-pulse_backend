import 'package:flutter/material.dart';
import '../models/weather_data.dart';
import '../services/weather_service.dart';
import 'package:geolocator/geolocator.dart';

class WeatherProvider extends ChangeNotifier {
  final WeatherService _service = WeatherService();
  
  WeatherData? _currentWeather;
  WeatherData? get currentWeather => _currentWeather;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> refreshWeather() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Position? position;
      
      // 1. Check Permissions & Get Location
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 10),
          );
        }
      } catch (gpsError) {
        debugPrint("Location services unavailable, using regional fallback: $gpsError");
      }

      // 2. Fetch Weather (Use 31.5204, 74.3587 [Lahore] as fallback for Punjab farmers)
      final lat = position?.latitude ?? 31.5204;
      final lon = position?.longitude ?? 74.3587;
      
      final data = await _service.fetchWeather(lat, lon);
      
      if (data != null) {
        _currentWeather = data;
      } else {
        _error = "Server connectivity issue";
      }
    } catch (e) {
      debugPrint("Weather Provider Error: $e");
      _error = "Could not sync weather";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
