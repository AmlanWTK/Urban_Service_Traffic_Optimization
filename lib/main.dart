import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:urban_service_traffic_optimization/screens/NewSScreens/about_complete_page.dart';
import 'package:urban_service_traffic_optimization/screens/NewSScreens/integrated_transport_page.dart';
import 'package:urban_service_traffic_optimization/screens/NewSScreens/setting_page.dart';
import 'package:urban_service_traffic_optimization/screens/NewSScreens/transport_homepage.dart';
import 'package:urban_service_traffic_optimization/screens/traffic_stats_page_screen.dart';

import 'package:urban_service_traffic_optimization/services/newservices/gtfs_service.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request permissions
  await _requestPermissions();

  // Initialize services
  await _initializeServices();

  runApp(const MyApp());
}

/// Request necessary permissions
Future<void> _requestPermissions() async {
  await [
    Permission.location,
    Permission.locationWhenInUse,
  ].request();
}

/// Initialize all transport services
Future<void> _initializeServices() async {
  try {
    // Initialize GTFS database with demo data
    await GTFSService.database;
    print('✅ GTFS service initialized');

    // Check database stats
    final stats = await GTFSService.getDatabaseStats();
    print('📊 Database stats: \$stats');

  } catch (e) {
    print('❌ Error initializing services: \$e');
  }
}


class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Complete Transport Solution',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      home: const TransportHomePage(),
      routes: {
        '/transport': (context) => const IntegratedTransportPageComplete(),
        '/about': (context) => const AboutCompletePage(),
        '/settings': (context) => const SettingsPage(),
        '/stats': (context) => const TrafficStatsPage(),
      },
    );
  }
}





