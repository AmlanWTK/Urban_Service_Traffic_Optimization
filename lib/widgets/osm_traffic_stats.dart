
import 'package:flutter/material.dart';
import 'package:urban_service_traffic_optimization/models/osm_route_model.dart';
import 'package:urban_service_traffic_optimization/models/traffic_segment_models.dart';

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