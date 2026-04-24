class WeatherData {
  final double temp;
  final int humidity;
  final String main;
  final String description;
  final String icon;
  final String locationName;
  final double windSpeed;

  WeatherData({
    required this.temp,
    required this.humidity,
    required this.main,
    required this.description,
    required this.icon,
    required this.locationName,
    required this.windSpeed,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temp: (json['main']['temp'] as num).toDouble() - 273.15,
      humidity: json['main']['humidity'] as int,
      main: json['weather'][0]['main'] as String,
      description: json['weather'][0]['description'] as String,
      icon: json['weather'][0]['icon'] as String,
      locationName: json['name'] as String,
      windSpeed: (json['wind']['speed'] as num).toDouble(),
    );
  }
}
