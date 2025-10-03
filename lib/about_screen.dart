import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('How It Works'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.psychology, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Intelligent Traffic Simulation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This app uses OpenStreetMap data to simulate realistic traffic patterns without requiring paid APIs:',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    _buildStep(
                      '1',
                      'Road Analysis',
                      'Analyzes OSM highway tags (motorway, primary, secondary, etc.) to understand road hierarchy and capacity.',
                      Colors.blue,
                    ),
                    _buildStep(
                      '2',
                      'Time Patterns',
                      'Applies realistic traffic patterns based on time of day (rush hours), day of week, and seasonal variations.',
                      Colors.green,
                    ),
                    _buildStep(
                      '3',
                      'Speed Calculation',
                      'Calculates current speeds based on road type, traffic level, speed limits, and number of lanes.',
                      Colors.orange,
                    ),
                    _buildStep(
                      '4',
                      'Visualization',
                      'Displays traffic conditions using color coding: green (light), yellow (moderate), orange (heavy), red (severe).',
                      Colors.red,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.data_usage, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Data Sources (100% Free)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDataSource(
                      'OpenStreetMap Tiles',
                      'Free map tiles from the global OSM community',
                      'tile.openstreetmap.org',
                      Colors.green,
                    ),
                    _buildDataSource(
                      'Overpass API',
                      'Free access to OSM road data and attributes',
                      'overpass-api.de',
                      Colors.blue,
                    ),
                    _buildDataSource(
                      'OSM Highway Tags',
                      'Road classification and speed limit data',
                      'wiki.openstreetmap.org',
                      Colors.orange,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.traffic, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Traffic Factors Considered',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildFactor('Road Type', 'Motorways vs residential streets'),
                    _buildFactor('Time of Day', 'Rush hours, lunch time, late night'),
                    _buildFactor('Day of Week', 'Weekdays vs weekends'),
                    _buildFactor('Number of Lanes', 'Multi-lane vs single lane roads'),
                    _buildFactor('Speed Limits', 'Higher speed roads congest differently'),
                    _buildFactor('Random Variation', 'Realistic traffic unpredictability'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.eco, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Why This Approach Works',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'While not using real-time sensor data, this simulation approach provides valuable insights by:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    _buildBenefit('✅', 'Showing realistic traffic patterns based on road types'),
                    _buildBenefit('✅', 'Identifying congestion-prone areas'),
                    _buildBenefit('✅', 'Providing time-aware route suggestions'),
                    _buildBenefit('✅', 'Working offline with cached data'),
                    _buildBenefit('✅', 'Requiring zero setup or API keys'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String title, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSource(String title, String description, String source, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(Icons.link, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  source,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactor(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefit(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
