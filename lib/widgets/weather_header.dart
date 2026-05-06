import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
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

        if (provider.error != null) {
          return _buildErrorState(provider.error!);
        }

        if (provider.currentWeather == null) {
          return const SizedBox.shrink();
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
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : const Color(0xFFE8F5E9).withOpacity(0.5),
        borderRadius: BorderRadius.circular(32),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E5E32))),
    );
  }

  Widget _buildWeatherCard(WeatherData weather) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMM d').format(now);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1B5E20), // Deep green
            Color(0xFF7CB342), // Bright yellow-green
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Metrics
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _metricRow('💧', '${weather.humidity}%'),
                      const SizedBox(height: 8),
                      _metricRow('💨', '${weather.windSpeed.toStringAsFixed(1)}m/s'),
                    ],
                  ),
                ),
                // Right Column: Temp & Location
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _getWeatherIcon(weather.main),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${weather.temp.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '°C',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        weather.locationName,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        dateStr,
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Inset Status Bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF154317).withOpacity(0.6), // Darker green inset
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white70, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Environmental conditions are currently stable.',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricRow(String emoji, String text) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _getWeatherIcon(String main) {
    IconData icon;
    switch (main.toLowerCase()) {
      case 'rain':
        icon = Icons.cloudy_snowing;
        break;
      case 'clouds':
        icon = Icons.cloud_outlined;
        break;
      case 'clear':
        icon = Icons.sunny;
        break;
      default:
        icon = Icons.wb_cloudy_outlined;
    }
    return Icon(icon, color: Colors.white, size: 40);
  }

  Widget _buildErrorState(String error) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.transparent),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF6CFB7B) : const Color(0xFF2E5E32), size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Weather data unavailable',
              style: GoogleFonts.inter(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2E5E32), 
                fontWeight: FontWeight.bold
              ),
            ),
          ),
          IconButton(
            onPressed: () => context.read<WeatherProvider>().refreshWeather(),
            icon: Icon(Icons.refresh_rounded, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF6CFB7B) : const Color(0xFF2E5E32)),
          ),
        ],
      ),
    );
  }
}
