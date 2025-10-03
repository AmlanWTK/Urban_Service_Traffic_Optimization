import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:urban_service_traffic_optimization/screens/transport_planner.dart';
import 'dart:math' as math;

// Import your existing OSM traffic service
import 'package:urban_service_traffic_optimization/services/osm_only_traffic_service.dart';

// Import new transport services
import 'package:urban_service_traffic_optimization/services/newservices/gtfs_service.dart';

import 'package:urban_service_traffic_optimization/models/gtfs_models.dart';

/// Fixed Integrated Transport Page - with working ride-share deep links
class IntegratedTransportPage extends StatefulWidget {
  const IntegratedTransportPage({Key? key}) : super(key: key);

  @override
  State<IntegratedTransportPage> createState() => _IntegratedTransportPageState();
}

class _IntegratedTransportPageState extends State<IntegratedTransportPage> {
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
  bool _showTraffic = false;
  bool _showStops = true;
  bool _showRoutes = false;
  List<TrafficSegment> _currentTraffic = [];
  int _selectedItineraryIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _initializeServices();
    _getCurrentLocation();
    _loadNearbyStops();
    _loadBusRoutes();
  }
  
  Future<void> _initializeServices() async {
    try {
      await GTFSService.database; // Initialize GTFS database
      print('✅ Transport services initialized');
    } catch (e) {
      print('❌ Error initializing services: $e');
    }
  }
  
  Future<void> _getCurrentLocation() async {
    final location = await _trafficService.getCurrentLocation();
    if (location != null && mounted) {
      setState(() {
        _center = location;
      });
      _trafficService.mapController.move(_center, 13.0);
    }
  }
  
  Future<void> _loadNearbyStops() async {
    try {
      final stops = await GTFSService.findNearbyStops(_center, radiusMeters: 2000);
      setState(() {
        _nearbyStops = stops;
      });
      print('✅ Loaded ${stops.length} nearby stops');
    } catch (e) {
      print('❌ Error loading stops: $e');
    }
  }
  
  Future<void> _loadBusRoutes() async {
    try {
      final routes = await GTFSService.getAllRoutes();
      setState(() {
        _busRoutes = routes;
      });
      print('✅ Loaded ${routes.length} bus routes');
    } catch (e) {
      print('❌ Error loading routes: $e');
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
      
      // Show helpful message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Start point set! Tap again to set destination'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
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
      print('🚀 Planning routes for mode: ${_selectedMode.name}');
      
      // Plan driving route with traffic
      if (_selectedMode == TransportModeType.driving || _selectedMode == TransportModeType.all) {
        final drivingRoute = await _trafficService.calculateRoute(
          start: _startPoint!,
          end: _endPoint!,
        );
        
        setState(() {
          _drivingRoute = drivingRoute;
        });
        
        // Show route info dialog immediately for driving (like your current app)
        if (drivingRoute != null && _selectedMode == TransportModeType.driving) {
          _showRouteInfoDialog(drivingRoute);
        }
      }
      
      // Plan public transport and ride-share routes
      if (_selectedMode == TransportModeType.transit || 
          _selectedMode == TransportModeType.rideshare || 
          _selectedMode == TransportModeType.all) {
        
        print('🚌 Planning public transport and ride-share options...');
        
        final transitItineraries = await PublicTransportPlanner.planJourney(
          origin: _startPoint!,
          destination: _endPoint!,
          departureTime: DateTime.now(),
          includeWalking: _selectedMode == TransportModeType.transit || _selectedMode == TransportModeType.all,
          includeRideshare: _selectedMode == TransportModeType.rideshare || _selectedMode == TransportModeType.all,
        );
        
        setState(() {
          _transitItineraries = transitItineraries;
        });
        
        print('✅ Found ${transitItineraries.length} transport options');
        
        // For ride-share only mode, show ride-share dialog immediately
        if (_selectedMode == TransportModeType.rideshare && transitItineraries.isNotEmpty) {
          _showRideshareDialog(transitItineraries.where((i) => 
            i.legs.any((leg) => leg.mode == TransportMode.rideshare)).toList());
        }
      }
      
      // Load traffic data for visualization
      await _loadTrafficData();
      
      // Show results for multimodal
      if (_selectedMode == TransportModeType.all) {
        _showResultsDialog();
      } else if (_selectedMode == TransportModeType.transit && _transitItineraries.isNotEmpty) {
        _showTransitDialog(_transitItineraries.where((i) => 
          i.legs.any((leg) => leg.mode == TransportMode.bus)).toList());
      }
      
    } catch (e) {
      print('❌ Error planning routes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error planning routes: $e')),
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
          _currentTraffic = trafficSegments;
          _showTraffic = true;
          _trafficService.updateTrafficVisualization(trafficSegments);
        });
      }
    } catch (e) {
      print('❌ Error loading traffic data: $e');
    }
  }

  // FIXED: Ride-share dialog with working deep links
  void _showRideshareDialog(List<PublicTransportItinerary> rideshareOptions) {
    print('🚕 Showing ride-share dialog with ${rideshareOptions.length} options');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.local_taxi, color: Colors.orange),
            SizedBox(width: 8),
            Text('Ride-share Options'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose your ride-sharing service:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              
              // Pathao Option
              _buildRideshareOption(
                icon: Icons.local_taxi,
                title: 'Pathao',
                subtitle: 'Most popular in Bangladesh',
                color: Colors.green,
                onTap: () async {
                  Navigator.pop(context);
                  print('🚕 Opening Pathao app...');
                  await PublicTransportPlanner.openRideshareApp('pathao', _startPoint!, _endPoint!);
                },
              ),
              
              const SizedBox(height: 12),
              
              // Uber Option
              _buildRideshareOption(
                icon: Icons.directions_car,
                title: 'Uber',
                subtitle: 'Global ride-sharing service',
                color: Colors.black,
                onTap: () async {
                  Navigator.pop(context);
                  print('🚕 Opening Uber app...');
                  await PublicTransportPlanner.openRideshareApp('uber', _startPoint!, _endPoint!);
                },
              ),
              
              const SizedBox(height: 12),
              
              // Shohoz Option
              _buildRideshareOption(
                icon: Icons.local_taxi,
                title: 'Shohoz',
                subtitle: 'Local ride-sharing option',
                color: Colors.orange,
                onTap: () async {
                  Navigator.pop(context);
                  print('🚕 Opening Shohoz app...');
                  await PublicTransportPlanner.openRideshareApp('shohoz', _startPoint!, _endPoint!);
                },
              ),
              
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "💡 Tip: If the app doesn\\'t open, you\\'ll be redirected to install it from the Play Store.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRideshareOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  // Transit-only dialog
  void _showTransitDialog(List<PublicTransportItinerary> transitOptions) {
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
                    const Icon(Icons.directions_bus, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text(
                      'Public Transport Options',
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
                    if (transitOptions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'No public transport routes found for this journey.\n\nTry a shorter distance or different locations.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    else
                      ...List.generate(transitOptions.length, (index) {
                        final itinerary = transitOptions[index];
                        return _buildTransitOption(itinerary, index);
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Route Info Dialog - exactly like your current app
  void _showRouteInfoDialog(OSMRoute route) {
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
                      'All Transport Options',
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
                        'Other Transport Options',
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
          Navigator.pop(context);
          _showRouteInfoDialog(route);
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
                      '${route.formattedDistance} • ${route.formattedDuration}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (route.averageDelay > 0)
                      Text(
                        'Traffic delay: ${route.averageDelay.toStringAsFixed(1)}%',
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
    // Determine the main mode for this itinerary
    final hasRideshare = itinerary.legs.any((leg) => leg.mode == TransportMode.rideshare);
    final hasBus = itinerary.legs.any((leg) => leg.mode == TransportMode.bus);
    final isWalkingOnly = itinerary.legs.every((leg) => leg.mode == TransportMode.walk);
    
    IconData icon;
    Color color;
    String mode;
    VoidCallback? onTap;
    
    if (hasRideshare) {
      icon = Icons.local_taxi;
      color = Colors.orange;
      mode = 'Ride-share';
      // FIXED: Add tap handler for ride-share
      onTap = () async {
        // Get the ride-share service name from the leg instructions
        final rideLeg = itinerary.legs.firstWhere((leg) => leg.mode == TransportMode.rideshare);
        String service = 'pathao'; // default
        
        if (rideLeg.instructions?.toLowerCase().contains('uber') == true) {
          service = 'uber';
        } else if (rideLeg.instructions?.toLowerCase().contains('shohoz') == true) {
          service = 'shohoz';
        }
        
        print('🚕 Opening $service from transit option...');
        await PublicTransportPlanner.openRideshareApp(service, _startPoint!, _endPoint!);
      };
    } else if (hasBus) {
      icon = Icons.directions_bus;
      color = Colors.green;
      mode = 'Public Transport';
    } else if (isWalkingOnly) {
      icon = Icons.directions_walk;
      color = Colors.blue;
      mode = 'Walking';
    } else {
      icon = Icons.help;
      color = Colors.grey;
      mode = 'Mixed';
    }
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    mode,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    itinerary.formattedDuration,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hasRideshare) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.open_in_new, size: 16, color: Colors.orange),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    itinerary.formattedDistance,
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (itinerary.transfers > 0) ...[
                    const Text(' • '),
                    Text(
                      '${itinerary.transfers} transfer${itinerary.transfers > 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                  if (hasRideshare) ...[
                    const Text(' • '),
                    const Text(
                      'Tap to open app',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _resetRoute() {
    setState(() {
      _startPoint = null;
      _endPoint = null;
      _drivingRoute = null;
      _transitItineraries.clear();
      _selectedItineraryIndex = 0;
      _showTraffic = false;
      _currentTraffic.clear();
      _trafficService.clearMarkers();
      _trafficService.updateTrafficVisualization([]);
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Route cleared. Tap to set new start point'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  void _toggleMode(TransportModeType mode) {
    setState(() {
      _selectedMode = mode;
    });
    
    print('🔄 Switched to mode: ${mode.name}');
    
    if (_startPoint != null && _endPoint != null) {
      _planAllRoutes();
    }
  }

  // Traffic Legend Widget - exactly like your current app
  Widget _buildTrafficLegend() {
    return Positioned(
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Transport'),
        backgroundColor: Colors.green.shade700,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/transport-settings');
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _trafficService.mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13.0,
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
              if (_showTraffic && _currentTraffic.isNotEmpty)
                PolylineLayer(
                  polylines: _trafficService.trafficPolylines,
                ),
              
              // Route polyline
              if (_drivingRoute != null && _drivingRoute!.points.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _drivingRoute!.points,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                      borderColor: Colors.white,
                      borderStrokeWidth: 2.0,
                    ),
                  ],
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
          
          // Traffic Legend - exactly like your current app
          if (_showTraffic && _currentTraffic.isNotEmpty)
            _buildTrafficLegend(),
          
          // Instructions overlay
          if (_startPoint == null)
            Positioned(
              top: 50,
              left: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Complete Transport Guide:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text('1. Select transport mode below'),
                      Text('2. Tap to set start point'),
                      Text('3. Tap again for destination'),
                      Text('4. Get route + ride-share options!'),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '🚕 Ride mode opens apps directly!',
                          style: TextStyle(fontSize: 10, color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
        ],
      ),
      
      // Bottom controls with mode selection
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
                    TransportModeType.transit,
                    Icons.directions_bus,
                    'Transit',
                    Colors.green,
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
              style: TextStyle(
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