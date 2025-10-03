import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:urban_service_traffic_optimization/services/newservices/gtfs_service.dart';

/// Settings page
class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _showTraffic = true;
  bool _showStops = true;
  bool _includeWalking = true;
  bool _includeRideshare = true;
  double _maxWalkingDistance = 1000;

  Future<Map<String, int>>? _statsFuture;

  @override
  void initState() {
    super.initState();
    // Cache the future so it runs only once
    _statsFuture = GTFSService.getDatabaseStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:  Text('Settings', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),),
        backgroundColor: Colors.blue.shade700,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Map Display
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'Map Display',
                    style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Show Traffic'),
                    subtitle: const Text('Display real-time traffic simulation'),
                    value: _showTraffic,
                    onChanged: (value) {
                      setState(() {
                        _showTraffic = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Show Bus Stops'),
                    subtitle: const Text('Display public transport stops'),
                    value: _showStops,
                    onChanged: (value) {
                      setState(() {
                        _showStops = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Journey Planning
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'Journey Planning',
                    style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Include Walking'),
                    subtitle: const Text('Show walking-only routes'),
                    value: _includeWalking,
                    onChanged: (value) {
                      setState(() {
                        _includeWalking = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Include Ride-share'),
                    subtitle: const Text('Show Pathao, Uber, Shohoz options'),
                    value: _includeRideshare,
                    onChanged: (value) {
                      setState(() {
                        _includeRideshare = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Max Walking Distance: ${_maxWalkingDistance.toInt()}m',
                    style:  GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  Slider(
                    value: _maxWalkingDistance,
                    min: 500,
                    max: 2000,
                    // Removed divisions for smooth sliding
                    label: '${_maxWalkingDistance.toInt()}m',
                    onChanged: (value) {
                      setState(() {
                        _maxWalkingDistance = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // System Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'System Information',
                    style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<Map<String, int>>(
                    future: _statsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else if (snapshot.hasData) {
                        final stats = snapshot.data!;
                        return Column(
                          children: [
                            _buildStatRow('Bus Routes', '${stats['routes'] ?? 0}'),
                            _buildStatRow('Bus Stops', '${stats['stops'] ?? 0}'),
                            _buildStatRow('Agencies', '${stats['agency'] ?? 0}'),
                            _buildStatRow('Trips', '${stats['trips'] ?? 0}'),
                          ],
                        );
                      } else {
                        return const Text('No data available');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
