import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/weather_data.dart';

class WeatherService {
  final String _apiKey = dotenv.env['OPENWEATHER_API_KEY'] ?? '';

  Future<WeatherData?> fetchWeather(double lat, double lon) async {
    if (_apiKey.isEmpty) return null;

    final url = 'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return WeatherData.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 401) {
        debugPrint('Weather API Error: Invalid API Key');
        return null;
      } else if (response.statusCode == 404) {
        debugPrint('Weather API Error: Location Not Found');
        return null;
      } else {
        debugPrint('Weather API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Weather Network Error: $e');
      return null;
    }
  }
}
