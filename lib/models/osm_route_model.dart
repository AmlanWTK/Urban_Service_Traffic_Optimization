import 'package:latlong2/latlong.dart';
import 'package:urban_service_traffic_optimization/models/osm_road_model.dart';

/// Route model
class OSMRoute {
  final List<LatLng> points;
  final double distance; // in meters
  final Duration duration;
  final List<OSMRoad> roads;
  final double averageDelay; // percentage

  OSMRoute({
    required this.points,
    required this.distance,
    required this.duration,
    required this.roads,
    required this.averageDelay,
  });

  String get formattedDistance {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    } else {
      return '${distance.toInt()} m';
    }
  }

  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes}min';
    }
  }
}

