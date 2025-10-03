import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Weather Service - OpenWeatherMap API (FREE tier)
/// Provides weather impact analysis for route planning
class WeatherService {
  // FREE OpenWeatherMap API key (replace with your own)
  static const String _apiKey = '0e664f60beff9a11c8b89d134637ffec';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';
  
  /// Get current weather for a location
  static Future<WeatherData?> getCurrentWeather(LatLng location) async {
    try {
      final url = '$_baseUrl/weather?lat=${location.latitude}&lon=${location.longitude}&appid=$_apiKey&units=metric';
      
      print('🌦️ Fetching weather data for ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}');
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final weather = WeatherData.fromJson(data);
        
        print('✅ Weather: ${weather.condition}, ${weather.temperature}°C, ${weather.humidity}%');
        return weather;
      } else if (response.statusCode == 401) {
        print('❌ Weather API: Invalid API key. Get one free from openweathermap.org');
        return _getDemoWeatherData(); // Fallback to demo data
      } else {
        print('❌ Weather API error: ${response.statusCode}');
        return _getDemoWeatherData(); // Fallback to demo data
      }
    } catch (e) {
      print('❌ Weather API error: $e');
      return _getDemoWeatherData(); // Fallback to demo data
    }
  }
  
  /// Get weather impact on route
  static Future<WeatherImpact> getWeatherImpact(LatLng start, LatLng end) async {
    try {
      // Get weather at both points and average
      final startWeather = await getCurrentWeather(start);
      final endWeather = await getCurrentWeather(end);
      
      if (startWeather == null && endWeather == null) {
        return WeatherImpact.none();
      }
      
      final weather = startWeather ?? endWeather!;
      return _calculateWeatherImpact(weather);
    } catch (e) {
      print('❌ Error calculating weather impact: $e');
      return WeatherImpact.none();
    }
  }
  
  /// Calculate traffic impact based on weather conditions
  static WeatherImpact _calculateWeatherImpact(WeatherData weather) {
    String impactLevel = 'none';
    int delayMinutes = 0;
    String recommendation = '';
    
    final condition = weather.condition.toLowerCase();
    final main = weather.main.toLowerCase();
    
    // Rain impact
    if (main.contains('rain') || condition.contains('rain')) {
      if (condition.contains('light')) {
        impactLevel = 'light';
        delayMinutes = 7; // 5-10 min delay
        recommendation = 'Light rain may cause minor delays. Drive carefully.';
      } else if (condition.contains('heavy') || condition.contains('thunderstorm')) {
        impactLevel = 'severe';
        delayMinutes = 20; // 15-25 min delay
        recommendation = 'Heavy rain/storms may cause significant delays. Consider postponing or using covered transport.';
      } else {
        impactLevel = 'moderate';
        delayMinutes = 12; // 10-15 min delay
        recommendation = 'Moderate rain may cause delays. Allow extra time and drive safely.';
      }
    }
    // Snow/ice impact (rare in Dhaka but included)
    else if (main.contains('snow') || condition.contains('snow')) {
      impactLevel = 'severe';
      delayMinutes = 30;
      recommendation = 'Snow/ice conditions may cause severe delays. Avoid travel if possible.';
    }
    // Fog impact
    else if (main.contains('mist') || main.contains('fog') || condition.contains('fog')) {
      impactLevel = 'moderate';
      delayMinutes = 10;
      recommendation = 'Low visibility may cause delays. Use headlights and drive slowly.';
    }
    // High temperature impact (common in Dhaka)
    else if (weather.temperature > 35) {
      impactLevel = 'light';
      delayMinutes = 3;
      recommendation = 'High temperature may affect vehicle performance. Stay hydrated.';
    }
    // High humidity impact (very common in Dhaka)
    else if (weather.humidity > 85) {
      impactLevel = 'light';
      delayMinutes = 2;
      recommendation = 'High humidity may cause discomfort. Consider air-conditioned transport.';
    }
    
    return WeatherImpact(
      weather: weather,
      impactLevel: impactLevel,
      delayMinutes: delayMinutes,
      recommendation: recommendation,
    );
  }
  
  /// Demo weather data for testing/fallback
  static WeatherData _getDemoWeatherData() {
    // Typical Dhaka weather patterns
    final hour = DateTime.now().hour;
    
    if (hour >= 14 && hour <= 18) {
      // Afternoon thunderstorms (common in Dhaka)
      return WeatherData(
        temperature: 31.0,
        feelsLike: 37.0,
        humidity: 78,
        condition: 'Light Rain',
        main: 'Rain',
        description: 'light intensity shower rain',
        icon: '10d',
        windSpeed: 3.2,
        pressure: 1008,
      );
    } else if (hour >= 6 && hour <= 10) {
      // Morning clear weather
      return WeatherData(
        temperature: 28.0,
        feelsLike: 32.0,
        humidity: 82,
        condition: 'Clear',
        main: 'Clear',
        description: 'clear sky',
        icon: '01d',
        windSpeed: 2.1,
        pressure: 1012,
      );
    } else {
      // Evening/night
      return WeatherData(
        temperature: 26.0,
        feelsLike: 29.0,
        humidity: 85,
        condition: 'Partly Cloudy',
        main: 'Clouds',
        description: 'scattered clouds',
        icon: '03n',
        windSpeed: 1.8,
        pressure: 1010,
      );
    }
  }
}

/// Weather Data Model
class WeatherData {
  final double temperature;
  final double feelsLike;
  final int humidity;
  final String condition;
  final String main;
  final String description;
  final String icon;
  final double windSpeed;
  final int pressure;

  WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.condition,
    required this.main,
    required this.description,
    required this.icon,
    required this.windSpeed,
    required this.pressure,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final weather = json['weather'][0];
    final main = json['main'];
    final wind = json['wind'];
    
    return WeatherData(
      temperature: (main['temp'] as num).toDouble(),
      feelsLike: (main['feels_like'] as num).toDouble(),
      humidity: main['humidity'] as int,
      condition: weather['main'] as String,
      main: weather['main'] as String,
      description: weather['description'] as String,
      icon: weather['icon'] as String,
      windSpeed: (wind['speed'] as num?)?.toDouble() ?? 0.0,
      pressure: main['pressure'] as int,
    );
  }

  String get weatherEmoji {
    final main = this.main.toLowerCase();
    final condition = this.condition.toLowerCase();
    
    if (main.contains('rain') || condition.contains('rain')) {
      if (condition.contains('light')) return '🌦️';
      if (condition.contains('heavy')) return '⛈️';
      return '🌧️';
    } else if (main.contains('snow')) return '🌨️';
    else if (main.contains('cloud')) return '☁️';
    else if (main.contains('clear')) return '☀️';
    else if (main.contains('mist') || main.contains('fog')) return '🌫️';
    else if (main.contains('thunderstorm')) return '⛈️';
    else return '🌤️';
  }

  String get formattedTemperature => '${temperature.round()}°C';
  String get formattedHumidity => '$humidity%';
  String get formattedCondition => condition;
}

/// Weather Impact Model
class WeatherImpact {
  final WeatherData weather;
  final String impactLevel; // none, light, moderate, severe
  final int delayMinutes;
  final String recommendation;

  WeatherImpact({
    required this.weather,
    required this.impactLevel,
    required this.delayMinutes,
    required this.recommendation,
  });

  factory WeatherImpact.none() {
    return WeatherImpact(
      weather: WeatherData(
        temperature: 30.0,
        feelsLike: 33.0,
        humidity: 75,
        condition: 'Clear',
        main: 'Clear',
        description: 'clear sky',
        icon: '01d',
        windSpeed: 2.0,
        pressure: 1012,
      ),
      impactLevel: 'none',
      delayMinutes: 0,
      recommendation: 'Good weather conditions for travel.',
    );
  }

  bool get hasImpact => impactLevel != 'none' && delayMinutes > 0;

  String get delayText {
    if (delayMinutes == 0) return 'No weather delays expected';
    if (delayMinutes <= 5) return 'May cause ${delayMinutes}min extra delay';
    if (delayMinutes <= 10) return 'May cause ${delayMinutes-2}–${delayMinutes+2}min extra delay';
    if (delayMinutes <= 20) return 'May cause ${delayMinutes-5}–${delayMinutes+5}min extra delay';
    return 'May cause ${delayMinutes-10}–${delayMinutes+10}min extra delay';
  }

  Color get impactColor {
    switch (impactLevel) {
      case 'light': return const Color(0xFFFFC107); // Amber
      case 'moderate': return const Color(0xFFFF9800); // Orange
      case 'severe': return const Color(0xFFF44336); // Red
      default: return const Color(0xFF4CAF50); // Green
    }
  }
}