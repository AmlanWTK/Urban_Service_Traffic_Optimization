import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Air Quality Service - OpenAQ API (FREE)
/// Provides air quality data from crowd IoT sensors
class AirQualityService {
  static const String _baseUrl = 'https://api.openaq.org/v2';
  
 /// Get air quality for a location
static Future<AirQualityData?> getAirQuality(LatLng location) async {
  try {
    // Build the request URL
    final url = '$_baseUrl/latest?coordinates=${location.latitude},${location.longitude}&radius=50000&limit=10&parameter=pm25';
    print('🌫️ Fetching air quality data for: '
        'Lat=${location.latitude.toStringAsFixed(4)}, '
        'Lng=${location.longitude.toStringAsFixed(4)}');
    print('🔗 URL: $url');
    
    // Send HTTP GET request
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': 'UrbanTrafficApp/1.0 (Educational Use)',
        'Accept': 'application/json',
        'X-API-Key': '5a94635a52f9f54bd68a1804bcc5eb85c3156e59b311260d7682f7fb9e83b314',  
      },
    ).timeout(const Duration(seconds: 15));

    print('📬 HTTP Status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List?;
      print('📊 Results count: ${results?.length ?? 0}');
      
      if (results != null && results.isNotEmpty) {
        // Find the closest and most recent measurement
        final measurement = _findBestMeasurement(results, location);
        if (measurement != null) {
          final airQuality = AirQualityData.fromOpenAQJson(measurement);
          print('✅ Air Quality: PM2.5 ${airQuality.pm25}µg/m³, AQI ${airQuality.aqi}');
          print('📍 Measurement location: ${airQuality.location}');
          print('⏱ Last updated: ${airQuality.lastUpdated}');
          return airQuality;
        }
      }
      
      print('⚠️ No air quality data found nearby. Using demo data.');
      return _getDemoAirQualityData();
    } else {
      print('❌ Air Quality API error. Status code: ${response.statusCode}');
      print('📄 Response body: ${response.body}');
      print('⚠️ Using demo data instead.');
      return _getDemoAirQualityData();
    }
  } catch (e) {
    print('❌ Exception occurred while fetching air quality: $e');
    print('⚠️ Using demo data instead.');
    return _getDemoAirQualityData();
  }
}

  /// Find the best measurement (closest and most recent)
  static Map<String, dynamic>? _findBestMeasurement(List<dynamic> results, LatLng location) {
    Map<String, dynamic>? bestMeasurement;
    double bestScore = double.infinity;
    
    for (final result in results) {
      try {
        final coordinates = result['coordinates'];
        final lat = coordinates['latitude'] as double;
        final lng = coordinates['longitude'] as double;
        
        // Calculate distance score
        final distance = const Distance().as(LengthUnit.Meter, location, LatLng(lat, lng));
        
        // Calculate time score (prefer recent measurements)
        final lastUpdated = DateTime.tryParse(result['date']['utc']);
        final hoursOld = lastUpdated != null 
            ? DateTime.now().difference(lastUpdated).inHours 
            : 24;
        
        // Combined score (distance in km + hours old)
        final score = distance / 1000 + hoursOld;
        
        if (score < bestScore) {
          bestScore = score;
          bestMeasurement = result;
        }
      } catch (e) {
        continue;
      }
    }
    
    return bestMeasurement;
  }
  
  /// Get air quality impact on transport recommendations
  static AirQualityImpact getAirQualityImpact(AirQualityData airQuality) {
    String impactLevel;
    String recommendation;
    String healthConcern;
    
    final aqi = airQuality.aqi;
    final pm25 = airQuality.pm25;
    
    if (aqi <= 50) {
      impactLevel = 'good';
      healthConcern = 'Good';
      recommendation = 'Air quality is good. All transport modes are suitable.';
    } else if (aqi <= 100) {
      impactLevel = 'moderate';
      healthConcern = 'Moderate';
      recommendation = 'Air quality is acceptable. Sensitive individuals may consider covered transport.';
    } else if (aqi <= 150) {
      impactLevel = 'unhealthy_sensitive';
      healthConcern = 'Unhealthy for Sensitive Groups';
      recommendation = 'Consider bus/metro instead of walking or biking. Sensitive individuals should limit outdoor exposure.';
    } else if (aqi <= 200) {
      impactLevel = 'unhealthy';
      healthConcern = 'Unhealthy';
      recommendation = 'Avoid walking or biking. Use enclosed transport (bus, car, metro). Consider wearing a mask.';
    } else if (aqi <= 300) {
      impactLevel = 'very_unhealthy';
      healthConcern = 'Very Unhealthy';
      recommendation = 'Avoid all outdoor activities. Use air-conditioned transport only. Wear N95 mask if necessary.';
    } else {
      impactLevel = 'hazardous';
      healthConcern = 'Hazardous';
      recommendation = 'Avoid travel if possible. If you must travel, use air-conditioned enclosed transport and wear N95 mask.';
    }
    
    return AirQualityImpact(
      airQuality: airQuality,
      impactLevel: impactLevel,
      healthConcern: healthConcern,
      recommendation: recommendation,
    );
  }
  
  /// Demo air quality data for Dhaka (realistic values)
  static AirQualityData _getDemoAirQualityData() {
    // Dhaka typically has poor air quality
    final hour = DateTime.now().hour;
    final random = math.Random();
    
    double pm25;
    double pm10;
    String location;
    
    if (hour >= 7 && hour <= 9) {
      // Morning rush hour - higher pollution
      pm25 = 85 + random.nextDouble() * 30; // 85-115
      pm10 = pm25 * 1.8;
      location = 'Tejgaon Industrial Area';
    } else if (hour >= 17 && hour <= 20) {
      // Evening rush hour - highest pollution
      pm25 = 95 + random.nextDouble() * 40; // 95-135
      pm10 = pm25 * 1.9;
      location = 'Farmgate Traffic Hub';
    } else if (hour >= 22 || hour <= 5) {
      // Night time - better but still poor
      pm25 = 45 + random.nextDouble() * 25; // 45-70
      pm10 = pm25 * 1.7;
      location = 'Dhanmondi Residential';
    } else {
      // Day time - moderate to unhealthy
      pm25 = 65 + random.nextDouble() * 25; // 65-90
      pm10 = pm25 * 1.8;
      location = 'Ramna Park Area';
    }
    
    return AirQualityData(
      pm25: pm25,
      pm10: pm10,
      pm1: pm25 * 0.6, // Estimated
      no2: 35 + random.nextDouble() * 20, // µg/m³
      so2: 15 + random.nextDouble() * 10, // µg/m³
      co: 1200 + random.nextDouble() * 800, // µg/m³
      o3: 80 + random.nextDouble() * 40, // µg/m³
      location: location,
      lastUpdated: DateTime.now().subtract(Duration(minutes: random.nextInt(120))),
      source: 'Dhaka IoT Sensor Network (Demo)',
    );
  }
}

/// Air Quality Data Model
class AirQualityData {
  final double pm25; // PM2.5 in µg/m³
  final double pm10; // PM10 in µg/m³
  final double? pm1; // PM1 in µg/m³
  final double? no2; // Nitrogen Dioxide in µg/m³
  final double? so2; // Sulfur Dioxide in µg/m³
  final double? co; // Carbon Monoxide in µg/m³
  final double? o3; // Ozone in µg/m³
  final String location;
  final DateTime lastUpdated;
  final String source;

  AirQualityData({
    required this.pm25,
    required this.pm10,
    this.pm1,
    this.no2,
    this.so2,
    this.co,
    this.o3,
    required this.location,
    required this.lastUpdated,
    required this.source,
  });

  factory AirQualityData.fromOpenAQJson(Map<String, dynamic> json) {
    final measurements = json['measurements'] as List;
    final coordinates = json['coordinates'];
    final location = json['location'] as String? ?? 'Unknown Location';
    final lastUpdated = DateTime.tryParse(json['date']['utc']) ?? DateTime.now();
    
    double pm25 = 0;
    double pm10 = 0;
    double? no2;
    double? so2;
    double? co;
    double? o3;
    
    // Extract measurements
    for (final measurement in measurements) {
      final parameter = measurement['parameter'] as String;
      final value = (measurement['value'] as num).toDouble();
      
      switch (parameter.toLowerCase()) {
        case 'pm25':
          pm25 = value;
          break;
        case 'pm10':
          pm10 = value;
          break;
        case 'no2':
          no2 = value;
          break;
        case 'so2':
          so2 = value;
          break;
        case 'co':
          co = value;
          break;
        case 'o3':
          o3 = value;
          break;
      }
    }
    
    // If PM10 not available, estimate from PM2.5
    if (pm10 == 0 && pm25 > 0) {
      pm10 = pm25 * 1.8; // Typical ratio
    }
    
    return AirQualityData(
      pm25: pm25,
      pm10: pm10,
      pm1: pm25 * 0.6, // Estimated
      no2: no2,
      so2: so2,
      co: co,
      o3: o3,
      location: location,
      lastUpdated: lastUpdated,
      source: 'OpenAQ Sensor Network',
    );
  }

  /// Calculate AQI (Air Quality Index) based on PM2.5
  int get aqi {
    if (pm25 <= 12.0) return ((pm25 / 12.0) * 50).round();
    if (pm25 <= 35.4) return (51 + ((pm25 - 12.1) / (35.4 - 12.1)) * (100 - 51)).round();
    if (pm25 <= 55.4) return (101 + ((pm25 - 35.5) / (55.4 - 35.5)) * (150 - 101)).round();
    if (pm25 <= 150.4) return (151 + ((pm25 - 55.5) / (150.4 - 55.5)) * (200 - 151)).round();
    if (pm25 <= 250.4) return (201 + ((pm25 - 150.5) / (250.4 - 150.5)) * (300 - 201)).round();
    return (301 + ((pm25 - 250.5) / (350.4 - 250.5)) * (400 - 301)).round().clamp(301, 500);
  }

  /// Get AQI category
  String get aqiCategory {
    final aqi = this.aqi;
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy for Sensitive Groups';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }

  /// Get AQI color
  Color get aqiColor {
    final aqi = this.aqi;
    if (aqi <= 50) return const Color(0xFF4CAF50); // Green
    if (aqi <= 100) return const Color(0xFFFFC107); // Yellow
    if (aqi <= 150) return const Color(0xFFFF9800); // Orange
    if (aqi <= 200) return const Color(0xFFF44336); // Red
    if (aqi <= 300) return const Color(0xFF9C27B0); // Purple
    return const Color(0xFF795548); // Brown
  }

  String get formattedPM25 => '${pm25.round()} µg/m³';
  String get formattedPM10 => '${pm10.round()} µg/m³';
  String get formattedAQI => aqi.toString();
  
  String get timeAgo {
    final diff = DateTime.now().difference(lastUpdated);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Air Quality Impact Model
class AirQualityImpact {
  final AirQualityData airQuality;
  final String impactLevel;
  final String healthConcern;
  final String recommendation;

  AirQualityImpact({
    required this.airQuality,
    required this.impactLevel,
    required this.healthConcern,
    required this.recommendation,
  });

  Color get impactColor => airQuality.aqiColor;
  
  String get emoji {
    final aqi = airQuality.aqi;
    if (aqi <= 50) return '😊'; // Good
    if (aqi <= 100) return '😐'; // Moderate
    if (aqi <= 150) return '😷'; // Unhealthy for sensitive
    if (aqi <= 200) return '😨'; // Unhealthy
    if (aqi <= 300) return '😱'; // Very unhealthy
    return '💀'; // Hazardous
  }

  bool get shouldAvoidWalking => airQuality.aqi > 100;
  bool get shouldWearMask => airQuality.aqi > 150;
  bool get shouldAvoidOutdoor => airQuality.aqi > 200;
}