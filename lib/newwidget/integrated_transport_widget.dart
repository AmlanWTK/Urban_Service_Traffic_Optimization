import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import 'package:urban_service_traffic_optimization/models/gtfs_models.dart';
import 'package:urban_service_traffic_optimization/models/osm_route_model.dart';
import 'package:urban_service_traffic_optimization/services/newservices/gtfs_service.dart';
import 'package:urban_service_traffic_optimization/services/osm_only_traffic_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;


import '../screens/transport_planner.dart';

/// Integrated Transport Widget
/// Combines OSM Traffic + Public Transport + Ride-share
class IntegratedTransportWidget extends StatefulWidget {
  final LatLng? initialCenter;
  final double initialZoom;

  const IntegratedTransportWidget({
    Key? key,
    this.initialCenter,
    this.initialZoom = 13.0,
  }) : super(key: key);

  @override
  State<IntegratedTransportWidget> createState() => _IntegratedTransportWidgetState();
}

class _IntegratedTransportWidgetState extends State<IntegratedTransportWidget> {
  // Services
  final OSMOnlyTrafficService _trafficService = OSMOnlyTrafficService();

  // Map state
  LatLng _center = const LatLng(23.8103, 90.4125); // Dhaka center
  bool _isLoading = false;

  // Route planning
  LatLng? _startPoint;
  LatLng? _endPoint;

  // Transport modes
  TransportModeType _selectedMode = TransportModeType.driving;

  // Results
  OSMRoute? _drivingRoute;
  List<PublicTransportItinerary> _transitItineraries = [];
  List<GTFSStop> _nearbyStops = [];
  List<GTFSRoute> _busRoutes = [];

  // UI state
  bool _showTraffic = true;
  bool _showStops = true;
  bool _showRoutes = false;
  int _selectedItineraryIndex = 0;

  @override
  void initState() {
    super.initState();
    _center = widget.initialCenter ?? _center;
    _initializeServices();
    _loadNearbyStops();
    _loadBusRoutes();
  }

  Future<void> _initializeServices() async {
    try {
      await GTFSService.database; // Initialize GTFS database
      print('Transport services initialized');
    } catch (e) {
      print('Error initializing services: \$e');
    }
  }

  Future<void> _loadNearbyStops() async {
    try {
      final stops = await GTFSService.findNearbyStops(_center, radiusMeters: 2000);
      setState(() {
        _nearbyStops = stops;
      });
      print('Loaded \${stops.length} nearby stops');
    } catch (e) {
      print('Error loading stops: \$e');
    }
  }

  Future<void> _loadBusRoutes() async {
    try {
      final routes = await GTFSService.getAllRoutes();
      setState(() {
        _busRoutes = routes;
      });
      print('Loaded \${routes.length} bus routes');
    } catch (e) {
      print('Error loading routes: \$e');
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

      await _planAllRoutes();
    } else {
      _resetRoute();
    }
  }

  Future<void> _planAllRoutes() async {
    if (_startPoint == null || _endPoint == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Plan driving route with traffic
      if (_selectedMode == TransportModeType.driving || _selectedMode == TransportModeType.all) {
        final drivingRoute = await _trafficService.calculateRoute(
          start: _startPoint!,
          end: _endPoint!,
        );

        setState(() {
          _drivingRoute = drivingRoute;
        });
      }

      // Plan public transport routes
      if (_selectedMode == TransportModeType.transit || _selectedMode == TransportModeType.all) {
        final transitItineraries = await PublicTransportPlanner.planJourney(
          origin: _startPoint!,
          destination: _endPoint!,
          departureTime: DateTime.now(),
          includeWalking: true,
          includeRideshare: true,
        );

        setState(() {
          _transitItineraries = transitItineraries;
        });
      }

      // Load traffic data for visualization
      await _loadTrafficData();

      _showResultsDialog();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error planning routes: \$e')),
      );
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
          _trafficService.updateTrafficVisualization(trafficSegments);
        });
      }
    } catch (e) {
      print('Error loading traffic data: \$e');
    }
  }

  void _showResultsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.route, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'Route Options',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Driving option
                    if (_drivingRoute != null)
                      _buildDrivingOption(_drivingRoute!),

                    const SizedBox(height: 16),

                    // Public transport options
                    if (_transitItineraries.isNotEmpty) ...[
                      const Text(
                        'Public Transport Options',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      ...List.generate(_transitItineraries.length, (index) {
                        final itinerary = _transitItineraries[index];
                        return _buildTransitOption(itinerary, index);
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrivingOption(OSMRoute route) {
    return Card(
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          // Show driving route on map
          Navigator.pop(context);
          _showDrivingRoute();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_car,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Driving',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\${route.formattedDistance} • \${route.formattedDuration}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (route.averageDelay > 0)
                      Text(
                        'Traffic delay: \${route.averageDelay.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransitOption(PublicTransportItinerary itinerary, int index) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() {
            _selectedItineraryIndex = index;
          });
          Navigator.pop(context);
          _showTransitRoute(itinerary);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icons
              Row(
                children: [
                  ...itinerary.legs.map((leg) {
                    IconData icon;
                    Color color;

                    switch (leg.mode) {
                      case TransportMode.walk:
                        icon = Icons.directions_walk;
                        color = Colors.green;
                        break;
                      case TransportMode.bus:
                        icon = Icons.directions_bus;
                        color = Colors.blue;
                        break;
                      case TransportMode.rideshare:
                        icon = Icons.local_taxi;
                        color = Colors.orange;
                        break;
                      default:
                        icon = Icons.help;
                        color = Colors.grey;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(icon, color: color, size: 20),
                    );
                  }).toList(),

                  const Spacer(),

                  Text(
                    itinerary.formattedDuration,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Distance and cost
              Row(
                children: [
                  Text(
                    itinerary.formattedDistance,
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (itinerary.estimatedCost > 0) ...[
                    const Text(' • '),
                    Text(
                      '৳\${itinerary.estimatedCost.toInt()}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                  if (itinerary.transfers > 0) ...[
                    const Text(' • '),
                   Text(
  '${itinerary.transfers} transfer${itinerary.transfers > 1 ? 's' : ''}',
  style: const TextStyle(fontSize: 14),
),

                  ],
                ],
              ),

              const SizedBox(height: 8),

              // Detailed steps
              ...itinerary.legs.asMap().entries.map((entry) {
                final index = entry.key;
                final leg = entry.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '\${index + 1}.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          leg.instructions ?? '\${leg.mode.name} to \${leg.toName}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      if (leg.mode == TransportMode.rideshare)
                        TextButton(
                          onPressed: () => _openRideshareApp(leg),
                          child: const Text('Open App'),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  void _showDrivingRoute() {
    // Implementation to show driving route on map
    setState(() {
      _showTraffic = true;
      _showStops = false;
      _showRoutes = false;
    });
  }

  void _showTransitRoute(PublicTransportItinerary itinerary) {
    // Implementation to show transit route on map
    setState(() {
      _showTraffic = false;
      _showStops = true;
      _showRoutes = true;
    });

    // Add route polylines to map
    _addTransitRouteToMap(itinerary);
  }

  void _addTransitRouteToMap(PublicTransportItinerary itinerary) {
    _trafficService.clearMarkers();

    // Add start marker
    _trafficService.addMarker(
      Marker(
        point: _startPoint!,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_on, color: Colors.green, size: 40),
      ),
    );

    // Add end marker
    _trafficService.addMarker(
      Marker(
        point: _endPoint!,
        width: 40,
        height: 40,
        child: const Icon(Icons.flag, color: Colors.red, size: 40),
      ),
    );

    // Add stop markers for bus legs
    for (final leg in itinerary.legs) {
      if (leg.mode == TransportMode.bus) {
        _trafficService.addMarker(
          Marker(
            point: leg.from,
            width: 30,
            height: 30,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.directions_bus, color: Colors.white, size: 16),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openRideshareApp(ItineraryLeg leg) async {
    // Determine which ride-share service based on leg details
    String service = 'pathao'; // Default to Pathao

    if (leg.instructions?.contains('Uber') == true) {
      service = 'uber';
    } else if (leg.instructions?.contains('Shohoz') == true) {
      service = 'shohoz';
    }

    await PublicTransportPlanner.openRideshareApp(service, leg.from, leg.to);
  }

  void _resetRoute() {
    setState(() {
      _startPoint = null;
      _endPoint = null;
      _drivingRoute = null;
      _transitItineraries.clear();
      _selectedItineraryIndex = 0;
      _trafficService.clearMarkers();
      _trafficService.updateTrafficVisualization([]);
    });
  }

  void _toggleMode(TransportModeType mode) {
    setState(() {
      _selectedMode = mode;
    });

    if (_startPoint != null && _endPoint != null) {
      _planAllRoutes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _trafficService.mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.initialZoom,
              onTap: _onTap,
            ),
            children: [
              // Base map tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.integrated_transport_app',
                maxZoom: 19,
              ),

              // Traffic visualization
              if (_showTraffic && _trafficService.trafficPolylines.isNotEmpty)
                PolylineLayer(
                  polylines: _trafficService.trafficPolylines,
                ),

              // Bus stop markers
              if (_showStops)
                MarkerLayer(
                  markers: _nearbyStops.map((stop) => Marker(
                    point: stop.location,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.directions_bus,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  )).toList(),
                ),

              // Route and user markers
              MarkerLayer(
                markers: _trafficService.markers,
              ),
            ],
          ),

          // Loading overlay
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
                        Text('Planning routes...'),
                        SizedBox(height: 8),
                        Text(
                          'Analyzing traffic + public transport + ride-share',
                          style: TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Instructions overlay
          if (_startPoint == null)
            Positioned(
              top: 50,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Integrated Transport Planner',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '🆓 100% FREE solution combining:',
                        style: TextStyle(fontSize: 12),
                      ),
                      const Text(
                        '• Traffic simulation (OSM data)',
                        style: TextStyle(fontSize: 12),
                      ),
                      const Text(
                        '• Public transport (GTFS data)',
                        style: TextStyle(fontSize: 12),
                      ),
                      const Text(
                        '• Ride-share deep links',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '📍 Tap twice to plan your journey',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),

      // Mode selection and controls
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Transport mode selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildModeButton(
                    TransportModeType.driving,
                    Icons.directions_car,
                    'Drive',
                    Colors.blue,
                  ),
                
                  _buildModeButton(
                    TransportModeType.rideshare,
                    Icons.local_taxi,
                    'Ride',
                    Colors.orange,
                  ),
                  _buildModeButton(
                    TransportModeType.all,
                    Icons.compare_arrows,
                    'All',
                    Colors.purple,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _resetRoute,
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final location = await _trafficService.getCurrentLocation();
                        if (location != null) {
                          setState(() {
                            _center = location;
                          });
                          _trafficService.mapController.move(location, 15);
                          _loadNearbyStops();
                        }
                      },
                      icon: const Icon(Icons.my_location),
                      label: const Text('My Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(TransportModeType mode, IconData icon, String label, Color color) {
    final isSelected = _selectedMode == mode;

    return InkWell(
      onTap: () => _toggleMode(mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.playfairDisplay(
                fontSize: 12,
                color: isSelected ? color : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Transport mode types
enum TransportModeType {
  driving,
  transit,
  rideshare,
  all,
}

extension TransportModeTypeExtension on TransportModeType {
  String get name {
    switch (this) {
      case TransportModeType.driving:
        return 'Driving';
      case TransportModeType.transit:
        return 'Public Transport';
      case TransportModeType.rideshare:
        return 'Ride-share';
      case TransportModeType.all:
        return 'All Options';
    }
  }
}
