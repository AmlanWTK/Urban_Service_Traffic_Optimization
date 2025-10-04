import 'package:latlong2/latlong.dart';

/// OSM Road model
class OSMRoad {
  final String id;
  final String name;
  final String highwayType;
  final List<LatLng> points;
  final int speedLimit;
  final int maxSpeed;

  OSMRoad({
    required this.id,
    required this.name,
    required this.highwayType,
    required this.points,
    required this.speedLimit,
    required this.maxSpeed,
  });
}