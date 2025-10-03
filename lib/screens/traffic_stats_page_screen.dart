
import 'package:flutter/material.dart';

/// Statistics page showing traffic analysis
class TrafficStatsPage extends StatelessWidget {
  const TrafficStatsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traffic Statistics'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'How to View Traffic Statistics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      '1. Go to the Traffic Map\n'
                      '2. Tap twice to set a route\n'
                      '3. Wait for traffic data to load\n'
                      '4. Tap the analytics icon in the top-right\n'
                      '5. View detailed traffic statistics',
                      style: TextStyle(fontSize: 16, height: 1.5),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Statistics include:\n'
                      '• Traffic level distribution\n'
                      '• Route analysis\n'
                      '• Speed and delay calculations\n'
                      '• Road type analysis',
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              color: Colors.cyan,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.speed, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Traffic Simulation Accuracy',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Our simulation considers:\n'
                      '• Road hierarchy from OSM data\n'
                      '• Time-based traffic patterns\n'
                      '• Speed limits and lane information\n'
                      '• Realistic congestion modeling',
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/map');
        },
        icon: const Icon(Icons.map),
        label: const Text('View Traffic Map'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
