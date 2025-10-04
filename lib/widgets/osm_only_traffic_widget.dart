import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:urban_service_traffic_optimization/models/osm_route_model.dart';
import 'package:urban_service_traffic_optimization/models/traffic_segment_models.dart';
import 'package:urban_service_traffic_optimization/services/osm_only_traffic_service.dart';

/// Fixed OSM-Only Traffic Widget (100% Free!)
class OSMOnlyTrafficWidget extends StatefulWidget {
  final LatLng? initialCenter;
  final double initialZoom;
  final Function(List<TrafficSegment>)? onTrafficDataReceived;
  final Function(OSMRoute)? onRouteCalculated;

  const OSMOnlyTrafficWidget({
    Key? key,
    this.initialCenter,
    this.initialZoom = 13.0,
    this.onTrafficDataReceived,
    this.onRouteCalculated,
  }) : super(key: key);

  @override
  State<OSMOnlyTrafficWidget> createState() => _OSMOnlyTrafficWidgetState();
}

class _OSMOnlyTrafficWidgetState extends State<OSMOnlyTrafficWidget> {
  final OSMOnlyTrafficService _trafficService = OSMOnlyTrafficService();
  LatLng _center = const LatLng(23.8103, 90.4125); // Default: Dhaka
  bool _showTraffic = false;
  bool _isLoading = false;
  LatLng? _startPoint;
  LatLng? _endPoint;
  List<TrafficSegment> _currentTraffic = [];
  OSMRoute? _currentRoute;

  @override
  void initState() {
    super.initState();
    _center = widget.initialCenter ?? _center;
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    final location = await _trafficService.getCurrentLocation();
    if (location != null && mounted) {
      setState(() {
        _center = location;
      });
      _trafficService.mapController.move(_center, widget.initialZoom);
    }
  }

  void _onTap(TapPosition tapPosition, LatLng point) async {
    if (_startPoint == null) {
      setState(() {
        _startPoint = point;
        _trafficService.clearMarkers();
        _trafficService.addMarker(
          Marker(
            point: point,
            width: 40,
            height: 40,
            child: const Icon(
              Icons.location_on,
              color: Colors.green,
              size: 40,
            ),
          ),
        );
      });
    } else if (_endPoint == null) {
      setState(() {
        _endPoint = point;
        _trafficService.addMarker(
          Marker(
            point: point,
            width: 40,
            height: 40,
            child: const Icon(
              Icons.flag,
              color: Colors.red,
              size: 40,
            ),
          ),
        );
      });

      await _calculateRouteAndTraffic();
    } else {
      _resetRoute();
    }
  }

  Future<void> _calculateRouteAndTraffic() async {
    if (_startPoint == null || _endPoint == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Calculate route
      final route = await _trafficService.calculateRoute(
        start: _startPoint!,
        end: _endPoint!,
      );

      if (route != null) {
        setState(() {
          _currentRoute = route;
        });
        widget.onRouteCalculated?.call(route);

        // Load traffic data for the area
        await _loadTrafficData();

        _showRouteInfo(route);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not calculate route')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTrafficData() async {
    if (_startPoint == null || _endPoint == null) return;

    try {
      // Create bounding box around route
      final minLat = math.min(_startPoint!.latitude, _endPoint!.latitude) - 0.005;
      final maxLat = math.max(_startPoint!.latitude, _endPoint!.latitude) + 0.005;
      final minLng = math.min(_startPoint!.longitude, _endPoint!.longitude) - 0.005;
      final maxLng = math.max(_startPoint!.longitude, _endPoint!.longitude) + 0.005;

      // Get OSM road data
      final roads = await _trafficService.getOSMRoadsInArea(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      if (roads.isNotEmpty) {
        // Generate traffic simulation
        final trafficSegments = _trafficService.generateTrafficSimulation(roads);

        setState(() {
          _currentTraffic = trafficSegments;
          _showTraffic = true;
          _trafficService.updateTrafficVisualization(trafficSegments);
        });

        widget.onTrafficDataReceived?.call(trafficSegments);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loaded ${trafficSegments.length} traffic segments'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No road data available for this area'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading traffic data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Traffic data error: $e')),
        );
      }
    }
  }

  void _showRouteInfo(OSMRoute route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.route, color: Colors.blue),
            SizedBox(width: 8),
            Text('Route Information'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.straighten, 'Distance', route.formattedDistance),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.access_time, 'Duration', route.formattedDuration),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.traffic,
              'Avg Delay',
              '${route.averageDelay.toStringAsFixed(1)}%',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.map, 'Roads Used', '${route.roads.length}'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Traffic simulation based on OpenStreetMap data',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Time-aware congestion patterns',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Road type analysis (motorway, primary, etc.)',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  void _resetRoute() {
    setState(() {
      _startPoint = null;
      _endPoint = null;
      _showTraffic = false;
      _currentTraffic.clear();
      _currentRoute = null;
      _trafficService.clearMarkers();
      _trafficService.updateTrafficVisualization([]);
    });
  }

  void _toggleTraffic() {
    setState(() {
      _showTraffic = !_showTraffic;
    });
  }

  void _refreshTraffic() async {
    if (_currentTraffic.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });

      await _loadTrafficData();

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Traffic data refreshed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _trafficService.mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.initialZoom,
              onTap: _onTap,
            ),
            children: [
              // OpenStreetMap tiles (completely free!)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.osm_traffic_app',
                maxZoom: 19,
              ),

              // Traffic polylines
              if (_showTraffic && _currentTraffic.isNotEmpty)
                PolylineLayer(
                  polylines: _trafficService.trafficPolylines,
                ),

              // Route polyline
              if (_currentRoute != null && _currentRoute!.points.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _currentRoute!.points,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                      borderColor: Colors.white,
                      borderStrokeWidth: 2.0,
                    ),
                  ],
                ),

              // Markers
              MarkerLayer(
                markers: _trafficService.markers,
              ),
            ],
          ),

          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading traffic data from OpenStreetMap...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Traffic info panel (legend)
          if (_showTraffic && _currentTraffic.isNotEmpty)
            Positioned(
              top: 50,
              right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Traffic Legend',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildLegendItem(Colors.green, 'Light'),
                      _buildLegendItem(Colors.yellow.shade700, 'Moderate'),
                      _buildLegendItem(Colors.orange, 'Heavy'),
                      _buildLegendItem(Colors.red, 'Severe'),
                    ],
                  ),
                ),
              ),
            ),

          // Instructions
          if (_startPoint == null)
            const Positioned(
              top: 50,
              left: 16,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text(
                    '1. Tap to set start point\n'
                    '2. Tap again to set destination\n'
                    '3. View real-time traffic simulation',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Current location
          FloatingActionButton(
            heroTag: "location",
            onPressed: _getCurrentLocation,
            tooltip: 'My Location',
            backgroundColor: Colors.blue,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 8),

          // Toggle traffic
          if (_currentTraffic.isNotEmpty)
            FloatingActionButton(
              heroTag: "traffic_toggle",
              onPressed: _toggleTraffic,
              tooltip: 'Toggle Traffic',
              backgroundColor: Colors.green,
              child: Icon(_showTraffic ? Icons.traffic : Icons.traffic_outlined),
            ),
          if (_currentTraffic.isNotEmpty) const SizedBox(height: 8),

          // Refresh traffic
          if (_currentTraffic.isNotEmpty)
            FloatingActionButton(
              heroTag: "refresh",
              onPressed: _refreshTraffic,
              tooltip: 'Refresh Traffic',
              backgroundColor: Colors.orange,
              child: const Icon(Icons.refresh),
            ),
          if (_currentTraffic.isNotEmpty) const SizedBox(height: 8),

          // Clear route
          FloatingActionButton(
            heroTag: "clear",
            onPressed: _resetRoute,
            tooltip: 'Clear Route',
            backgroundColor: Colors.red,
            child: const Icon(Icons.clear),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Fixed Traffic statistics widget
class OSMTrafficStats extends StatelessWidget {
  final List<TrafficSegment> segments;
  final OSMRoute? route;

  const OSMTrafficStats({
    Key? key,
    required this.segments,
    this.route,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No traffic data available'),
        ),
      );
    }

    final stats = _calculateStats();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Traffic Analysis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatRow('Light Traffic', '${stats['light']}%', icon: Icons.traffic),
            _buildStatRow('Moderate Traffic', '${stats['moderate']}%', icon: Icons.alt_route),
            _buildStatRow('Heavy Traffic', '${stats['heavy']}%', icon: Icons.directions_car),
            _buildStatRow('Severe Congestion', '${stats['severe']}%', icon: Icons.warning),
            if (route != null) ...[
              const Divider(),
              _buildStatRow('Route Distance', route!.formattedDistance),
              _buildStatRow('Estimated Time', route!.formattedDuration),
              _buildStatRow('Average Delay', '${route!.averageDelay.toStringAsFixed(1)}%'),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '✅ Data Source: OpenStreetMap\n'
                '✅ Simulation: Time-based patterns\n'
                '✅ Cost: 100% FREE forever!',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, int> _calculateStats() {
    final total = segments.length;
    if (total == 0) return {'light': 0, 'moderate': 0, 'heavy': 0, 'severe': 0};

    int light = 0, moderate = 0, heavy = 0, severe = 0;

    for (final segment in segments) {
      switch (segment.trafficLevel) {
        case 'light':
          light++;
          break;
        case 'moderate':
          moderate++;
          break;
        case 'heavy':
          heavy++;
          break;
        case 'severe':
          severe++;
          break;
      }
    }

    return {
      'light': ((light / total) * 100).round(),
      'moderate': ((moderate / total) * 100).round(),
      'heavy': ((heavy / total) * 100).round(),
      'severe': ((severe / total) * 100).round(),
    };
  }

  Widget _buildStatRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) Icon(icon, size: 20, color: Colors.blue),
              if (icon != null) const SizedBox(width: 6),
              Text(label),
            ],
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}