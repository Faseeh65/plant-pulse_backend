import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/weather_provider.dart';
import '../models/weather_data.dart';
import '../utils/rice_health_logic.dart';

class WeatherHeader extends StatefulWidget {
  const WeatherHeader({super.key});

  @override
  State<WeatherHeader> createState() => _WeatherHeaderState();
}

class _WeatherHeaderState extends State<WeatherHeader> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeatherProvider>().refreshWeather();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WeatherProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return _buildLoading();
        }

        if (provider.error != null || provider.currentWeather == null) {
          return const SizedBox.shrink(); // Hide if error or no data
        }

        return _buildWeatherCard(provider.currentWeather!);
      },
    );
  }

  Widget _buildLoading() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6CFB7B))),
    );
  }

  Widget _buildWeatherCard(WeatherData weather) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMM d').format(now);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1B5E20).withOpacity(0.8),
            const Color(0xFF2E7D32).withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // --- Left Side: Temperature & Location ---
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${weather.temp.toStringAsFixed(0)}°C',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                        ),
                      ),
                      Text(
                        weather.locationName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                      ),
                    ],
                  ),

                  // --- Center: Icon ---
                  _getWeatherIcon(weather.main),

                  // --- Right Side: Risk Column ---
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _riskItem(Icons.water_drop_outlined, '${weather.humidity}%', 'Humidity'),
                      const SizedBox(height: 12),
                      _riskItem(Icons.air, '${weather.windSpeed.toStringAsFixed(1)}m/s', 'Wind'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // --- Agri-Smart Logic (Bottom Alert) ---
              _buildAgriAlert(weather),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgriAlert(WeatherData weather) {
    final alert = RiceHealthLogic.getEnvironmentalAlert(weather.humidity, weather.temp);
    final Color color = alert['color'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), // Light background tint
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(alert['icon'], color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              alert['message'],
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getWeatherIcon(String main) {
    IconData icon;
    Color color = Colors.white;

    switch (main.toLowerCase()) {
      case 'rain':
        icon = Icons.cloudy_snowing;
        color = Colors.lightBlueAccent;
        break;
      case 'clouds':
        icon = Icons.cloud_queue_rounded;
        break;
      case 'clear':
        icon = Icons.sunny;
        color = Colors.orangeAccent;
        break;
      default:
        icon = Icons.wb_cloudy_outlined;
    }

    return Icon(icon, color: color, size: 64);
  }

  Widget _riskItem(IconData icon, String val, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(width: 8),
            Icon(icon, color: const Color(0xFF6CFB7B), size: 16),
          ],
        ),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
      ],
    );
  }
}
