import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

/// Fixed OSM Traffic Service - Improved XML parsing and error handling
class OSMOnlyTrafficService {
  final MapController mapController = MapController();
  List<Marker> markers = [];
  List<Polyline> trafficPolylines = [];
  
  // Traffic colors
  static const Map<String, Color> trafficColors = {
    'light': Colors.green,
    'moderate': Color(0xFFFFD700), // Gold
    'heavy': Colors.orange,
    'severe': Colors.red,
  };

  /// Get current location
  Future<LatLng?> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  /// Calculate route between two points
  Future<OSMRoute?> calculateRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    print('Calculating route from ${start.latitude.toStringAsFixed(4)},${start.longitude.toStringAsFixed(4)} to ${end.latitude.toStringAsFixed(4)},${end.longitude.toStringAsFixed(4)}');
    
    try {
      // Get roads in the area between start and end points
      final roads = await getOSMRoadsInArea(
        southwest: LatLng(
          math.min(start.latitude, end.latitude) - 0.01,
          math.min(start.longitude, end.longitude) - 0.01,
        ),
        northeast: LatLng(
          math.max(start.latitude, end.latitude) + 0.01,
          math.max(start.longitude, end.longitude) + 0.01,
        ),
      );
      
      if (roads.isNotEmpty) {
        return _calculateRouteFromRoads(start, end, roads);
      } else {
        print('No roads found, using direct route calculation');
        return _calculateDirectRoute(start, end);
      }
    } catch (e) {
      print('Error calculating route: $e');
      return _calculateDirectRoute(start, end);
    }
  }

  /// Improved OSM road data fetching with better error handling
  Future<List<OSMRoad>> getOSMRoadsInArea({
    required LatLng southwest,
    required LatLng northeast,
  }) async {
    try {
      print('Querying Overpass API for roads in area...');
      print('Query area: $southwest to $northeast');
      
      // More robust Overpass API query with timeout and proper formatting
      final query = '''
[out:xml][timeout:25];
(
  way["highway"]["highway"!="footway"]["highway"!="cycleway"]["highway"!="path"]["highway"!="steps"]["highway"!="corridor"]["highway"!="pedestrian"]
  (${southwest.latitude},${southwest.longitude},${northeast.latitude},${northeast.longitude});
);
out geom;
''';

      final encodedQuery = Uri.encodeComponent(query.trim());
      final url = 'https://overpass-api.de/api/interpreter?data=$encodedQuery';
      
      print('Making Overpass API request...');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'OSMTrafficApp/1.0 (Educational Use)',
          'Accept': 'application/xml, text/xml, */*',
        },
      ).timeout(const Duration(seconds: 30));
      
      print('Overpass API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return _parseOSMResponse(response.body);
      } else {
        print('Overpass API error: ${response.statusCode} - ${response.reasonPhrase}');
        print('Response body: ${response.body.substring(0, math.min(200, response.body.length))}');
        return [];
      }
    } catch (e) {
      print('Error fetching OSM data: $e');
      return [];
    }
  }

  /// Improved XML parsing with better error handling
  List<OSMRoad> _parseOSMResponse(String xmlString) {
    try {
      print('Parsing OSM XML response...');
      
      // Clean the XML string
      String cleanedXml = xmlString.trim();
      
      // Check if the response is actually XML
      if (!cleanedXml.startsWith('<?xml') && !cleanedXml.startsWith('<osm')) {
        print('Response is not XML format: ${cleanedXml.substring(0, math.min(100, cleanedXml.length))}');
        return [];
      }
      
      // Remove any BOM or invisible characters
      cleanedXml = cleanedXml.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
      
      // Parse XML
      final document = XmlDocument.parse(cleanedXml);
      final osmElement = document.rootElement;
      
      if (osmElement.name.local != 'osm') {
        print('Invalid OSM XML: root element is ${osmElement.name.local}');
        return [];
      }
      
      final roads = <OSMRoad>[];
      final ways = osmElement.findElements('way');
      
      print('Found ${ways.length} ways in OSM data');
      
      for (final way in ways) {
        try {
          final road = _parseWayElement(way);
          if (road != null) {
            roads.add(road);
          }
        } catch (e) {
          print('Error parsing way element: $e');
          continue;
        }
      }
      
      print('Successfully parsed ${roads.length} roads from OSM');
      return roads;
    } catch (e) {
      print('Error parsing OSM XML: $e');
      print('XML snippet: ${xmlString.substring(0, math.min(200, xmlString.length))}');
      return [];
    }
  }

  /// Parse individual way element
  OSMRoad? _parseWayElement(XmlElement way) {
    try {
      final id = way.getAttribute('id') ?? '';
      
      // Get highway type
      String highwayType = 'unknown';
      String? name;
      
      for (final tag in way.findElements('tag')) {
        final key = tag.getAttribute('k');
        final value = tag.getAttribute('v');
        
        if (key == 'highway') {
          highwayType = value ?? 'unknown';
        } else if (key == 'name') {
          name = value;
        }
      }
      
      // Skip if not a road
      if (highwayType == 'unknown' || 
          ['footway', 'cycleway', 'path', 'steps', 'corridor', 'pedestrian'].contains(highwayType)) {
        return null;
      }
      
      // Get geometry points
      final points = <LatLng>[];
      for (final nd in way.findElements('nd')) {
        final lat = double.tryParse(nd.getAttribute('lat') ?? '');
        final lon = double.tryParse(nd.getAttribute('lon') ?? '');
        
        if (lat != null && lon != null) {
          points.add(LatLng(lat, lon));
        }
      }
      
      if (points.length < 2) {
        return null;
      }
      
      return OSMRoad(
        id: id,
        name: name ?? 'Unnamed Road',
        highwayType: highwayType,
        points: points,
        speedLimit: _getSpeedLimitForHighway(highwayType),
        maxSpeed: _getMaxSpeedForHighway(highwayType),
      );
    } catch (e) {
      print('Error parsing way element: $e');
      return null;
    }
  }

  /// Calculate route from actual road data
  OSMRoute _calculateRouteFromRoads(LatLng start, LatLng end, List<OSMRoad> roads) {
    print('Using ${roads.length} roads for route calculation');
    
    // Find the closest roads to start and end points
    OSMRoad? startRoad = _findClosestRoad(start, roads);
    OSMRoad? endRoad = _findClosestRoad(end, roads);
    
    List<LatLng> routePoints = [];
    List<OSMRoad> usedRoads = [];
    double totalDistance = 0;
    
    if (startRoad != null && endRoad != null) {
      // Simple routing: use roads in between
      routePoints.addAll([start, ...startRoad.points, ...endRoad.points, end]);
      usedRoads.addAll([startRoad, endRoad]);
      
      // Calculate distance
      for (int i = 0; i < routePoints.length - 1; i++) {
        totalDistance += const Distance().as(
          LengthUnit.Meter,
          routePoints[i],
          routePoints[i + 1],
        );
      }
    } else {
      // Fallback to direct route
      routePoints = [start, end];
      totalDistance = const Distance().as(LengthUnit.Meter, start, end);
    }
    
    // Estimate duration based on road types and traffic
    double estimatedSpeed = _calculateAverageSpeed(usedRoads);
    Duration duration = Duration(
      seconds: (totalDistance / (estimatedSpeed * 1000 / 3600)).round(),
    );
    
    // Calculate traffic delay
    double averageDelay = _calculateTrafficDelay(usedRoads, DateTime.now());
    
    String primaryHighway = usedRoads.isNotEmpty ? usedRoads.first.highwayType : 'direct';
    
    print('Route: ${(totalDistance / 1000).toStringAsFixed(1)}km, ${(duration.inMinutes + duration.inSeconds / 60).toStringAsFixed(1)}min via $primaryHighway');
    
    return OSMRoute(
      points: routePoints,
      distance: totalDistance,
      duration: duration,
      roads: usedRoads,
      averageDelay: averageDelay,
    );
  }

  /// Calculate direct route (fallback)
  OSMRoute _calculateDirectRoute(LatLng start, LatLng end) {
    final distance = const Distance().as(LengthUnit.Meter, start, end);
    
    // Estimate speed based on area (urban vs rural)
    double estimatedSpeed = 25.0; // km/h for urban areas
    
    final duration = Duration(
      seconds: (distance / (estimatedSpeed * 1000 / 3600)).round(),
    );
    
    return OSMRoute(
      points: [start, end],
      distance: distance,
      duration: duration,
      roads: [],
      averageDelay: 15.0, // Assume moderate traffic
    );
  }

  /// Find closest road to a point
  OSMRoad? _findClosestRoad(LatLng point, List<OSMRoad> roads) {
    if (roads.isEmpty) return null;
    
    OSMRoad? closest;
    double minDistance = double.infinity;
    
    for (final road in roads) {
      for (final roadPoint in road.points) {
        final distance = const Distance().as(LengthUnit.Meter, point, roadPoint);
        if (distance < minDistance) {
          minDistance = distance;
          closest = road;
        }
      }
    }
    
    return closest;
  }

  /// Generate traffic simulation for roads
  List<TrafficSegment> generateTrafficSimulation(List<OSMRoad> roads) {
    if (roads.isEmpty) {
      print('No roads available, generating demo roads for visualization');
      roads = _generateDemoRoads();
    }
    
    final DateTime now = DateTime.now();
    print('Generating traffic simulation for ${roads.length} roads at ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
    
    final List<TrafficSegment> segments = [];
    
    for (final road in roads) {
      if (road.points.length < 2) continue;
      
      // Calculate traffic level based on road type and time
      final trafficLevel = _calculateTrafficLevel(road, now);
      final color = trafficColors[trafficLevel] ?? Colors.grey;
      
      // Create segments for each road section
      for (int i = 0; i < road.points.length - 1; i++) {
        segments.add(TrafficSegment(
          start: road.points[i],
          end: road.points[i + 1],
          trafficLevel: trafficLevel,
          color: color,
          roadType: road.highwayType,
          speedLimit: road.speedLimit,
          roadName: road.name,
        ));
      }
    }
    
    print('Generated ${segments.length} traffic segments with current time patterns');
    return segments;
  }

  /// Generate demo roads for testing
  List<OSMRoad> _generateDemoRoads() {
    print('Generating demo roads for traffic simulation');
    
    return [
      OSMRoad(
        id: 'demo_1',
        name: 'Main Avenue',
        highwayType: 'primary',
        points: [
          const LatLng(23.7704, 90.3968),
          const LatLng(23.7804, 90.3968),
          const LatLng(23.7904, 90.3968),
        ],
        speedLimit: 50,
        maxSpeed: 60,
      ),
      OSMRoad(
        id: 'demo_2',
        name: 'Central Road',
        highwayType: 'secondary',
        points: [
          const LatLng(23.7704, 90.3968),
          const LatLng(23.7754, 90.4018),
          const LatLng(23.7804, 90.4068),
        ],
        speedLimit: 40,
        maxSpeed: 50,
      ),
      OSMRoad(
        id: 'demo_3',
        name: 'Express Way',
        highwayType: 'trunk',
        points: [
          const LatLng(23.7854, 90.3968),
          const LatLng(23.7954, 90.4018),
          const LatLng(23.8054, 90.4068),
        ],
        speedLimit: 60,
        maxSpeed: 80,
      ),
      OSMRoad(
        id: 'demo_4',
        name: 'Local Street',
        highwayType: 'residential',
        points: [
          const LatLng(23.7804, 90.3918),
          const LatLng(23.7854, 90.3968),
          const LatLng(23.7904, 90.4018),
        ],
        speedLimit: 30,
        maxSpeed: 40,
      ),
      OSMRoad(
        id: 'demo_5',
        name: 'Commercial Road',
        highwayType: 'tertiary',
        points: [
          const LatLng(23.7954, 90.3918),
          const LatLng(23.8004, 90.3968),
          const LatLng(23.8054, 90.4018),
        ],
        speedLimit: 35,
        maxSpeed: 45,
      ),
    ];
  }

  /// Calculate traffic level based on road type and time
  String _calculateTrafficLevel(OSMRoad road, DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    final totalMinutes = hour * 60 + minute;
    
    // Base traffic level by road type
    double baseTraffic = 0.3; // Default moderate
    
    switch (road.highwayType) {
      case 'motorway':
      case 'trunk':
        baseTraffic = 0.4;
        break;
      case 'primary':
        baseTraffic = 0.5;
        break;
      case 'secondary':
        baseTraffic = 0.4;
        break;
      case 'tertiary':
        baseTraffic = 0.3;
        break;
      case 'residential':
        baseTraffic = 0.2;
        break;
      default:
        baseTraffic = 0.3;
    }
    
    // Time-based multipliers
    double timeMultiplier = 1.0;
    
    // Morning rush (7:00-9:30)
    if (totalMinutes >= 420 && totalMinutes <= 570) {
      timeMultiplier = 1.8;
    }
    // Evening rush (17:00-19:30)
    else if (totalMinutes >= 1020 && totalMinutes <= 1170) {
      timeMultiplier = 1.7;
    }
    // Lunch time (12:00-14:00)
    else if (totalMinutes >= 720 && totalMinutes <= 840) {
      timeMultiplier = 1.3;
    }
    // Late night (22:00-6:00)
    else if (totalMinutes >= 1320 || totalMinutes <= 360) {
      timeMultiplier = 0.4;
    }
    // Weekend effect (reduce traffic)
    if (time.weekday >= 6) {
      timeMultiplier *= 0.7;
    }
    
    // Add some randomness
    final random = math.Random();
    double randomFactor = 0.8 + random.nextDouble() * 0.4; // 0.8 to 1.2
    
    final finalTraffic = baseTraffic * timeMultiplier * randomFactor;
    
    // Convert to traffic levels
    if (finalTraffic < 0.3) return 'light';
    if (finalTraffic < 0.6) return 'moderate';
    if (finalTraffic < 0.9) return 'heavy';
    return 'severe';
  }

  /// Calculate average speed for roads
  double _calculateAverageSpeed(List<OSMRoad> roads) {
    if (roads.isEmpty) return 25.0; // Default urban speed
    
    double totalSpeed = 0;
    for (final road in roads) {
      totalSpeed += road.speedLimit.toDouble();
    }
    
    return totalSpeed / roads.length;
  }

  /// Calculate traffic delay
  double _calculateTrafficDelay(List<OSMRoad> roads, DateTime time) {
    if (roads.isEmpty) return 15.0; // Default delay
    
    double totalDelay = 0;
    for (final road in roads) {
      final trafficLevel = _calculateTrafficLevel(road, time);
      switch (trafficLevel) {
        case 'light':
          totalDelay += 5.0;
          break;
        case 'moderate':
          totalDelay += 15.0;
          break;
        case 'heavy':
          totalDelay += 30.0;
          break;
        case 'severe':
          totalDelay += 50.0;
          break;
      }
    }
    
    return totalDelay / roads.length;
  }

  /// Get speed limit for highway type
  int _getSpeedLimitForHighway(String highway) {
    switch (highway) {
      case 'motorway': return 80;
      case 'trunk': return 60;
      case 'primary': return 50;
      case 'secondary': return 40;
      case 'tertiary': return 35;
      case 'residential': return 30;
      case 'living_street': return 20;
      default: return 30;
    }
  }

  /// Get max speed for highway type
  int _getMaxSpeedForHighway(String highway) {
    return (_getSpeedLimitForHighway(highway) * 1.2).round();
  }

  /// Update traffic visualization
  void updateTrafficVisualization(List<TrafficSegment> segments) {
    trafficPolylines.clear();
    
    for (final segment in segments) {
      trafficPolylines.add(
        Polyline(
          points: [segment.start, segment.end],
          strokeWidth: 6.0,
          color: segment.color,
        ),
      );
    }
  }

  /// Add marker to map
  void addMarker(Marker marker) {
    markers.add(marker);
  }

  /// Clear all markers
  void clearMarkers() {
    markers.clear();
  }

  /// Clear all traffic data
  void clearTrafficData() {
    trafficPolylines.clear();
  }
}

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