import 'dart:ui';

import 'package:latlong2/latlong.dart';

/// Traffic segment model
class TrafficSegment {
  final LatLng start;
  final LatLng end;
  final String trafficLevel;
  final Color color;
  final String roadType;
  final int speedLimit;
  final String roadName;

  TrafficSegment({
    required this.start,
    required this.end,
    required this.trafficLevel,
    required this.color,
    required this.roadType,
    required this.speedLimit,
    required this.roadName,
  });
}