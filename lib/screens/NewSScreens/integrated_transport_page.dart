import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:urban_service_traffic_optimization/models/osm_route_model.dart';
import 'package:urban_service_traffic_optimization/models/traffic_segment_models.dart';
import 'package:urban_service_traffic_optimization/screens/transport_planner.dart';
import 'package:urban_service_traffic_optimization/services/newservices/gtfs_service.dart';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';

// Import your existing OSM traffic service
import 'package:urban_service_traffic_optimization/services/osm_only_traffic_service.dart';

// Import new transport services

import 'package:urban_service_traffic_optimization/models/gtfs_models.dart';

// Import new environmental services

import 'package:urban_service_traffic_optimization/widgets/enhanced_route_summary.dart';

/// Complete Integrated Transport Page - WITH Traffic Legend and Deep Blue Route
class IntegratedTransportPageComplete extends StatefulWidget {
  const IntegratedTransportPageComplete({Key? key}) : super(key: key);

  @override
  State<IntegratedTransportPageComplete> createState() => _IntegratedTransportPageCompleteState();
}

class _IntegratedTransportPageCompleteState extends State<IntegratedTransportPageComplete> {
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
  
  // UI state - FIXED: Traffic legend always shows when traffic data is available
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
      await GTFSService.database;
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Start point set! Tap again to set destination'),
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
      
      // ALWAYS load traffic data first to show the traffic legend
      await _loadTrafficData();
      
      // Plan driving route with traffic
      if (_selectedMode == TransportModeType.driving || _selectedMode == TransportModeType.all) {
        final drivingRoute = await _trafficService.calculateRoute(
          start: _startPoint!,
          end: _endPoint!,
        );
        
        setState(() {
          _drivingRoute = drivingRoute;
        });
        
        // Show enhanced route summary immediately for driving
        if (drivingRoute != null && _selectedMode == TransportModeType.driving) {
          _showEnhancedRouteSummary(drivingRoute);
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
  
  // ENHANCED: Load traffic data and ALWAYS show traffic legend
  Future<void> _loadTrafficData() async {
    if (_startPoint == null || _endPoint == null) return;
    
    try {
      print('🚦 Loading traffic data for route area...');
      
      // Create larger bounding box around route for better traffic visualization
      final minLat = math.min(_startPoint!.latitude, _endPoint!.latitude) - 0.01;
      final maxLat = math.max(_startPoint!.latitude, _endPoint!.latitude) + 0.01;
      final minLng = math.min(_startPoint!.longitude, _endPoint!.longitude) - 0.01;
      final maxLng = math.max(_startPoint!.longitude, _endPoint!.longitude) + 0.01;
      
      final roads = await _trafficService.getOSMRoadsInArea(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      
      if (roads.isNotEmpty) {
        final trafficSegments = _trafficService.generateTrafficSimulation(roads);
        
        setState(() {
          _currentTraffic = trafficSegments;
          _showTraffic = true; // ALWAYS show traffic when available
          _trafficService.updateTrafficVisualization(trafficSegments);
        });
        
        print('✅ Traffic visualization ready: ${trafficSegments.length} segments');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Traffic data loaded: ${trafficSegments.length} road segments'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('⚠️ No roads found for traffic visualization');
      }
    } catch (e) {
      print('❌ Error loading traffic data: $e');
    }
  }

  // ENHANCED: Show route summary with weather and environment impact
  void _showEnhancedRouteSummary(OSMRoute route) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => EnhancedRouteSummary(
          route: route,
          startPoint: _startPoint!,
          endPoint: _endPoint!,
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
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
              
              // Enhanced Uber Option with prefilled coordinates
              _buildRideshareOption(
                icon: Icons.directions_car,
                title: 'Uber',
                subtitle: '🎯 Auto-fills pickup & destination',
                color: Colors.black,
                onTap: () async {
                  Navigator.pop(context);
                  print('🚕 Opening Uber with prefilled locations...');
                  await _openUberWithCoordinates(_startPoint!, _endPoint!);
                },
              ),
              
              const SizedBox(height: 12),
              
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
                  '💡 Tip: Uber will auto-fill your pickup and drop-off locations!',
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

  // Enhanced Uber deep link with coordinate prefill
  Future<void> _openUberWithCoordinates(LatLng pickup, LatLng dropoff) async {
    try {
      final url = 'https://m.uber.com/ul/?action=setPickup'
          '&pickup[latitude]=${pickup.latitude}'
          '&pickup[longitude]=${pickup.longitude}'
          '&dropoff[latitude]=${dropoff.latitude}'
          '&dropoff[longitude]=${dropoff.longitude}';
      
      print('🚕 Opening Uber with URL: $url');
      
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚗 Opening Uber with your pickup and destination pre-filled!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error opening Uber: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open Uber: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  // Other dialog methods (simplified for space)
  void _showTransitDialog(List<PublicTransportItinerary> transitOptions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.directions_bus, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text(
                      'Public Transport Options',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (transitOptions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'No public transport routes found for this journey.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    else
                      ...transitOptions.map((itinerary) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.directions_bus, color: Colors.green, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Public Transport',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  Text(itinerary.formattedDuration),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Distance: ${itinerary.formattedDistance}'),
                              if (itinerary.transfers > 0)
                                Text('Transfers: ${itinerary.transfers}'),
                            ],
                          ),
                        ),
                      )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showResultsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.route, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'All Transport Options',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Driving option
                    if (_drivingRoute != null)
                      _buildDrivingOption(_drivingRoute!),
                    
                    const SizedBox(height: 16),
                    
                    // Other options
                    if (_transitItineraries.isNotEmpty) ...[
                      const Text(
                        'Other Transport Options',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          _showEnhancedRouteSummary(route); // Show enhanced summary
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
                child: const Icon(Icons.directions_car, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Driving', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${route.formattedDistance} • ${route.formattedDuration}'),
                    if (route.averageDelay > 0)
                      Text(
                        'Traffic delay: ${route.averageDelay.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 12, color: Colors.orange),
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
    final hasRideshare = itinerary.legs.any((leg) => leg.mode == TransportMode.rideshare);
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: hasRideshare ? () async {
          final rideLeg = itinerary.legs.firstWhere((leg) => leg.mode == TransportMode.rideshare);
          String service = 'pathao';
          
          if (rideLeg.instructions?.toLowerCase().contains('uber') == true) {
            service = 'uber';
          } else if (rideLeg.instructions?.toLowerCase().contains('shohoz') == true) {
            service = 'shohoz';
          }
          
          if (service == 'uber') {
            await _openUberWithCoordinates(_startPoint!, _endPoint!);
          } else {
            await PublicTransportPlanner.openRideshareApp(service, _startPoint!, _endPoint!);
          }
        } : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasRideshare ? Icons.local_taxi : Icons.directions_bus,
                    color: hasRideshare ? Colors.orange : Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasRideshare ? 'Ride-share' : 'Public Transport',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(itinerary.formattedDuration),
                  if (hasRideshare) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.open_in_new, size: 16, color: Colors.orange),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(itinerary.formattedDistance),
                  if (itinerary.transfers > 0) ...[
                    const Text(' • '),
                    Text('${itinerary.transfers} transfer${itinerary.transfers > 1 ? 's' : ''}'),
                  ],
                  if (hasRideshare) ...[
                    const Text(' • '),
                    const Text(
                      'Tap to open app',
                      style: TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic),
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
          content: Text('✅ Route cleared. Tap to set new start point'),
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

  // RESTORED: Traffic Legend Widget - exactly like your original design
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
        title: const Text('OSM Traffic Map'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/transport-settings');
            },
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
          // Options menu like your original design
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'about':
                  Navigator.pushNamed(context, '/about');
                  break;
                case 'stats':
                  Navigator.pushNamed(context, '/stats');
                  break;
                case 'home':
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'stats',
                child: ListTile(
                  leading: Icon(Icons.analytics, color: Colors.purple),
                  title: Text('Statistics'),
                  dense: true,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'about',
                child: ListTile(
                  leading: Icon(Icons.info, color: Colors.blue),
                  title: Text('About'),
                  dense: true,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'home',
                child: ListTile(
                  leading: Icon(Icons.home, color: Colors.orange),
                  title: Text('Home'),
                  dense: true,
                ),
              ),
            ],
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
              
              // FIXED: Traffic visualization layer ALWAYS shows when available
              if (_showTraffic && _currentTraffic.isNotEmpty)
                PolylineLayer(
                  polylines: _trafficService.trafficPolylines,
                ),
              
              // ENHANCED: Deep blue route line for selected route
              if (_drivingRoute != null && _drivingRoute!.points.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _drivingRoute!.points,
                      strokeWidth: 6.0,
                      color: const Color(0xFF1976D2), // Deep blue color
                      borderColor: Colors.white,
                      borderStrokeWidth: 2.0,
                      pattern: StrokePattern.solid(),
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
              
              // Route markers (start/end points)
              MarkerLayer(
                markers: _trafficService.markers,
              ),
            ],
          ),
          
          // RESTORED: Traffic Legend - exactly like your beautiful original design
          if (_showTraffic && _currentTraffic.isNotEmpty)
            _buildTrafficLegend(),
          
          // Instructions overlay
          if (_startPoint == null)
            Positioned(
              top: 50,
              left: 16,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Complete Transport Guide:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('1. Select transport mode below', style: TextStyle(fontSize: 12)),
                      const Text('2. Tap to set start point', style: TextStyle(fontSize: 12)),
                      const Text('3. Tap again for destination', style: TextStyle(fontSize: 12)),
                      const Text('4. See route + traffic + weather!', style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '🔵 Deep blue line shows best route',
                          style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
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
                          'Analyzing traffic + weather + air quality + ride-share',
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
                  _buildModeButton(TransportModeType.driving, Icons.directions_car, 'Drive', Colors.blue),
                  _buildModeButton(TransportModeType.transit, Icons.directions_bus, 'Transit', Colors.green),
                  _buildModeButton(TransportModeType.rideshare, Icons.local_taxi, 'Ride', Colors.orange),
                  _buildModeButton(TransportModeType.all, Icons.compare_arrows, 'All', Colors.purple),
                ],
              ),
              const SizedBox(height: 12),
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