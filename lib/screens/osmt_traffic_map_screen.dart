import 'package:flutter/material.dart';
import 'package:urban_service_traffic_optimization/models/osm_route_model.dart';
import 'package:urban_service_traffic_optimization/models/traffic_segment_models.dart';
import 'package:urban_service_traffic_optimization/services/osm_only_traffic_service.dart';
import 'package:urban_service_traffic_optimization/widgets/osm_only_traffic_widget.dart';

/// Map page with traffic visualization
class OSMTrafficMapPage extends StatefulWidget {
  const OSMTrafficMapPage({Key? key}) : super(key: key);

  @override
  State<OSMTrafficMapPage> createState() => _OSMTrafficMapPageState();
}

class _OSMTrafficMapPageState extends State<OSMTrafficMapPage> {
  List<TrafficSegment> _currentTraffic = [];
  OSMRoute? _currentRoute;
  bool _showStats = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OSM Traffic Map'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _showStats = !_showStats;
              });
            },
            icon: Icon(_showStats ? Icons.map : Icons.analytics),
            tooltip: _showStats ? 'Show Map' : 'Show Statistics',
          ),
        ],
      ),
      body: _showStats && _currentTraffic.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: OSMTrafficStats(
                segments: _currentTraffic,
                route: _currentRoute,
              ),
            )
          : OSMOnlyTrafficWidget(
              onTrafficDataReceived: (segments) {
                setState(() {
                  _currentTraffic = segments;
                });
              },
              onRouteCalculated: (route) {
                setState(() {
                  _currentRoute = route;
                });
              },
            ),
    );
  }
}
