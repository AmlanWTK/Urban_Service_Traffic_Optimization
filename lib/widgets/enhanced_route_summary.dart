import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:urban_service_traffic_optimization/models/air_quality_model.dart';
import 'package:urban_service_traffic_optimization/models/osm_route_model.dart';
import 'package:urban_service_traffic_optimization/services/newservices/air_quality_service.dart';
import 'package:urban_service_traffic_optimization/services/newservices/live_traffic_service.dart';
import 'package:urban_service_traffic_optimization/services/newservices/weather_service.dart';
import '../services/osm_only_traffic_service.dart';


/// Enhanced Route Summary with Live Traffic - PRESERVING ALL EXISTING FEATURES
/// Adds live traffic section below route summary
class EnhancedRouteSummary extends StatefulWidget {
  final OSMRoute route;
  final LatLng startPoint;
  final LatLng endPoint;
  final VoidCallback? onClose;

  const EnhancedRouteSummary({
    Key? key,
    required this.route,
    required this.startPoint,
    required this.endPoint,
    this.onClose,
  }) : super(key: key);

  @override
  State<EnhancedRouteSummary> createState() => _EnhancedRouteSummaryState();
}

class _EnhancedRouteSummaryState extends State<EnhancedRouteSummary> {
  // EXISTING: Weather and air quality data
  WeatherImpact? _weatherImpact;
  AirQualityImpact? _airQualityImpact;
  
  // NEW: Live traffic data
  LiveTrafficData? _liveTrafficData;
  
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEnvironmentalData();
    _loadLiveTrafficData(); // NEW: Load live traffic data
  }

  // EXISTING: Load weather and air quality data (PRESERVED)
  Future<void> _loadEnvironmentalData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load weather and air quality data in parallel
      final weatherFuture = WeatherService.getWeatherImpact(widget.startPoint, widget.endPoint);
      final airQualityFuture = AirQualityService.getAirQuality(widget.startPoint);

      final results = await Future.wait([weatherFuture, airQualityFuture]);
      
      final weatherImpact = results[0] as WeatherImpact;
      final airQualityData = results[1] as AirQualityData?;

      setState(() {
        _weatherImpact = weatherImpact;
        _airQualityImpact = airQualityData != null 
            ? AirQualityService.getAirQualityImpact(airQualityData)
            : null;
        _isLoading = false;
      });

      print('✅ Environmental data loaded successfully');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      print('❌ Error loading environmental data: $e');
    }
  }

  // NEW: Load live traffic data
  Future<void> _loadLiveTrafficData() async {
    try {
      print('🔴 Loading live traffic data for route...');
      
      final liveTraffic = await LiveTrafficService.getLiveTrafficForRoute(
        routePoints: widget.route.points,
        routeName: widget.route.roads.isNotEmpty ? widget.route.roads.first.name : 'Selected Route',
      );

      if (mounted) {
        setState(() {
          _liveTrafficData = liveTraffic;
        });
        print('✅ Live traffic data loaded: ${liveTraffic?.incidents.length ?? 0} incidents');
      }
    } catch (e) {
      print('❌ Error loading live traffic data: $e');
    }
  }

  // NEW: Refresh live traffic data
  Future<void> _refreshLiveTraffic() async {
    setState(() {
      _liveTrafficData = null;
    });
    await _loadLiveTrafficData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔄 Live traffic data refreshed'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                const Icon(Icons.route, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                 Text(
                  'Route Summary',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // EXISTING: Basic Route Info (PRESERVED)
                  _buildRouteInfoCard(),
                  
                  const SizedBox(height: 16),
                  
                  // NEW: Live Traffic Section (ADDED BELOW ROUTE SUMMARY)
                  if (_liveTrafficData != null)
                    _buildLiveTrafficCard(_liveTrafficData!),
                  
                  const SizedBox(height: 16),
                  
                  // EXISTING: Weather Impact Section (PRESERVED)
                  if (_isLoading)
                    _buildLoadingCard()
                  else if (_error != null)
                    _buildErrorCard()
                  else ...[
                    if (_weatherImpact != null)
                      _buildWeatherCard(_weatherImpact!),
                    
                    const SizedBox(height: 16),
                    
                    // EXISTING: Air Quality Section (PRESERVED)
                    if (_airQualityImpact != null)
                      _buildAirQualityCard(_airQualityImpact!),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // EXISTING: Action buttons (PRESERVED)
                  _buildActionButtons(),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // EXISTING: Route info card (PRESERVED)
  Widget _buildRouteInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
              children: [
                Icon(Icons.navigation, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text(
                  '📍 Route Summary',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Basic route metrics
            Row(
              children: [
                Expanded(
                  child: _buildRouteMetric(
                    'Distance',
                    widget.route.formattedDistance,
                  ),
                ),
                Expanded(
                  child: _buildRouteMetric(
                    'Duration',
                    widget.route.formattedDuration,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(
                  child: _buildRouteMetric(
                    'Average Delay',
                    '+${widget.route.averageDelay.round()}min',
                  ),
                ),
                Expanded(
                  child: _buildRouteMetric(
                    'Roads Used',
                    widget.route.roads.isNotEmpty 
                        ? widget.route.roads.first.name
                        : 'Main Routes',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // NEW: Live Traffic Card
  Widget _buildLiveTrafficCard(LiveTrafficData liveTraffic) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with refresh button
            Row(
              children: [
                const Icon(Icons.traffic, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                 Text(
                  '🔴 Live Traffic',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _refreshLiveTraffic,
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Refresh traffic data',
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Congestion information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: liveTraffic.congestionData.levelColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: liveTraffic.congestionData.levelColor.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        liveTraffic.congestionData.levelEmoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Congestion: ${liveTraffic.congestionData.levelText}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: liveTraffic.congestionData.levelColor,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Speed and delay info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Average Speed:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            liveTraffic.congestionData.formattedAverageSpeed,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Traffic Delay:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            liveTraffic.congestionData.formattedDelayMinutes,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: liveTraffic.congestionData.hasCongestion 
                                  ? Colors.orange 
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  if (liveTraffic.congestionData.speedReductionPercent > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Speed reduced by ${liveTraffic.congestionData.speedReductionPercent}% due to traffic',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Traffic incidents (if any)
            if (liveTraffic.hasIncidents) ...[
              const SizedBox(height: 12),
              Text(
                'Traffic Incidents (${liveTraffic.incidents.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...liveTraffic.incidents.take(3).map((incident) => _buildIncidentItem(incident)),
              
              if (liveTraffic.incidents.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+ ${liveTraffic.incidents.length - 3} more incidents',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
            
            // Data source and timestamp
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Source: Mapbox Traffic API',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  'Updated: ${liveTraffic.timeAgo}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Traffic incident item
  Widget _buildIncidentItem(TrafficIncident incident) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: incident.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: incident.color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            incident.icon,
            color: incident.color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  incident.description,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (incident.delayMinutes > 0)
                  Text(
                    '+${incident.delayMinutes}min delay • ${incident.severityText} severity',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // EXISTING: Weather card (PRESERVED)
  Widget _buildWeatherCard(WeatherImpact weatherImpact) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  weatherImpact.weather.weatherEmoji,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                 Text(
                  '🌦️ Weather Impact',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Weather condition
            Row(
              children: [
                const Text('Condition: ', style: TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  '${weatherImpact.weather.weatherEmoji} ${weatherImpact.weather.formattedCondition}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            
            const SizedBox(height: 6),
            
            // Temperature and humidity
            Row(
              children: [
                const Text('Temperature: ', style: TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  '${weatherImpact.weather.formattedTemperature}, Humidity: ${weatherImpact.weather.formattedHumidity}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            
            // Weather impact warning
            if (weatherImpact.hasImpact) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: weatherImpact.impactColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: weatherImpact.impactColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: weatherImpact.impactColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ ${weatherImpact.delayText}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: weatherImpact.impactColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Recommendation
            if (weatherImpact.recommendation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                weatherImpact.recommendation,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // EXISTING: Air quality card (PRESERVED)
  Widget _buildAirQualityCard(AirQualityImpact airQualityImpact) {
    final aq = airQualityImpact.airQuality;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  airQualityImpact.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                 Text(
                  '🌫️ Environment (Crowd IoT Sensors)',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // AQI and PM2.5
            Row(
              children: [
                const Text('Air Quality Index: ', style: TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  '${aq.formattedAQI} (${aq.aqiCategory})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: aq.aqiColor,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 6),
            
            Row(
              children: [
                const Text('PM2.5: ', style: TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  aq.formattedPM25,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: aq.aqiColor,
                  ),
                ),
              ],
            ),
            
            // Data source and time
            const SizedBox(height: 8),
            Text(
              'Source: ${aq.source} (${aq.timeAgo})',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
            
            // Recommendation
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: aq.aqiColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: aq.aqiColor.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.health_and_safety, color: aq.aqiColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recommendation:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: aq.aqiColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          airQualityImpact.recommendation,
                          style: TextStyle(
                            fontSize: 13,
                            color: aq.aqiColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // EXISTING: Loading card (PRESERVED)
  Widget _buildLoadingCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Loading weather and air quality data...',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // EXISTING: Error card (PRESERVED)
  Widget _buildErrorCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.error, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Environmental Data',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Could not load weather and air quality data. Using traffic analysis only.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _loadEnvironmentalData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // EXISTING: Action buttons (PRESERVED)
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // Show detailed route info
              _showDetailedRouteInfo();
            },
            icon: const Icon(Icons.info),
            label:  Text('Route Details',style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // Start navigation (placeholder)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Navigation feature coming soon!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            icon: const Icon(Icons.navigation),
            label:  Text('Start Route',style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  // EXISTING: Show detailed route info (PRESERVED)
  void _showDetailedRouteInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:  Text('Detailed Route Information', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Distance', widget.route.formattedDistance),
              _buildDetailRow('Duration', widget.route.formattedDuration),
              _buildDetailRow('Average Delay', '${widget.route.averageDelay.round()}%'),
              _buildDetailRow('Roads Count', '${widget.route.roads.length}'),
              if (widget.route.roads.isNotEmpty) ...[
                const SizedBox(height: 8),
                 Text(
                  'Main Roads:',
                  style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...widget.route.roads.take(3).map((road) => 
                  Text('• ${road.name} (${road.highwayType})')),
              ],
              const SizedBox(height: 12),
              const Text(
                '✅ Data Source: OpenStreetMap\n'
                '✅ Simulation: Time-based patterns\n'
                '✅ Weather: OpenWeatherMap\n'
                '✅ Air Quality: OpenAQ Network\n'
                '✅ Live Traffic: Mapbox Traffic API',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}