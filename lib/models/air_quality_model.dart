import 'dart:ui';

import 'package:urban_service_traffic_optimization/services/newservices/air_quality_service.dart';

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