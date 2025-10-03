
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:latlong2/latlong.dart';
import 'package:urban_service_traffic_optimization/models/gtfs_models.dart';


/// GTFS Service - FREE implementation
/// Handles GTFS data download, parsing, and local storage
class GTFSService {
  static Database? _database;
  static const String _dhakaGtfsUrl = 'https://example.com/dhaka-gtfs.zip'; // Demo URL

  /// Initialize GTFS database
  static Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize SQLite database for GTFS data
  static Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'gtfs.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create GTFS tables
        await _createTables(db);

        // Load demo data if no real GTFS available
        await _loadDemoGTFSData(db);
      },
    );
  }

  /// Create GTFS tables
  static Future<void> _createTables(Database db) async {
    // Agency table
    await db.execute('''
      CREATE TABLE agency (
        agency_id TEXT PRIMARY KEY,
        agency_name TEXT NOT NULL,
        agency_url TEXT,
        agency_timezone TEXT,
        agency_phone TEXT,
        agency_fare_url TEXT,
        agency_email TEXT
      )
    ''');

    // Stops table
    await db.execute('''
      CREATE TABLE stops (
        stop_id TEXT PRIMARY KEY,
        stop_code TEXT,
        stop_name TEXT NOT NULL,
        stop_desc TEXT,
        stop_lat REAL NOT NULL,
        stop_lon REAL NOT NULL,
        zone_id TEXT,
        stop_url TEXT,
        location_type INTEGER DEFAULT 0,
        parent_station TEXT,
        wheelchair_boarding INTEGER DEFAULT 0
      )
    ''');

    // Routes table
    await db.execute('''
      CREATE TABLE routes (
        route_id TEXT PRIMARY KEY,
        agency_id TEXT,
        route_short_name TEXT,
        route_long_name TEXT,
        route_desc TEXT,
        route_type INTEGER NOT NULL,
        route_url TEXT,
        route_color TEXT,
        route_text_color TEXT,
        route_sort_order INTEGER,
        FOREIGN KEY (agency_id) REFERENCES agency (agency_id)
      )
    ''');

    // Trips table
    await db.execute('''
      CREATE TABLE trips (
        trip_id TEXT PRIMARY KEY,
        route_id TEXT NOT NULL,
        service_id TEXT NOT NULL,
        trip_headsign TEXT,
        trip_short_name TEXT,
        direction_id INTEGER DEFAULT 0,
        block_id TEXT,
        shape_id TEXT,
        wheelchair_accessible INTEGER DEFAULT 0,
        bikes_allowed INTEGER DEFAULT 0,
        FOREIGN KEY (route_id) REFERENCES routes (route_id)
      )
    ''');

    // Stop times table
    await db.execute('''
      CREATE TABLE stop_times (
        trip_id TEXT NOT NULL,
        arrival_time TEXT NOT NULL,
        departure_time TEXT NOT NULL,
        stop_id TEXT NOT NULL,
        stop_sequence INTEGER NOT NULL,
        stop_headsign TEXT,
        pickup_type INTEGER DEFAULT 0,
        drop_off_type INTEGER DEFAULT 0,
        shape_dist_traveled REAL,
        timepoint INTEGER DEFAULT 1,
        PRIMARY KEY (trip_id, stop_sequence),
        FOREIGN KEY (trip_id) REFERENCES trips (trip_id),
        FOREIGN KEY (stop_id) REFERENCES stops (stop_id)
      )
    ''');

    // Calendar table
    await db.execute('''
      CREATE TABLE calendar (
        service_id TEXT PRIMARY KEY,
        monday INTEGER NOT NULL,
        tuesday INTEGER NOT NULL,
        wednesday INTEGER NOT NULL,
        thursday INTEGER NOT NULL,
        friday INTEGER NOT NULL,
        saturday INTEGER NOT NULL,
        sunday INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL
      )
    ''');

    // Shapes table
    await db.execute('''
      CREATE TABLE shapes (
        shape_id TEXT NOT NULL,
        shape_pt_lat REAL NOT NULL,
        shape_pt_lon REAL NOT NULL,
        shape_pt_sequence INTEGER NOT NULL,
        shape_dist_traveled REAL,
        PRIMARY KEY (shape_id, shape_pt_sequence)
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_stops_location ON stops (stop_lat, stop_lon)');
    await db.execute('CREATE INDEX idx_stop_times_stop_id ON stop_times (stop_id)');
    await db.execute('CREATE INDEX idx_stop_times_trip_id ON stop_times (trip_id)');
    await db.execute('CREATE INDEX idx_trips_route_id ON trips (route_id)');
  }

  /// Load demo GTFS data for Dhaka
  static Future<void> _loadDemoGTFSData(Database db) async {
    print('Loading demo GTFS data for Dhaka...');

    // Demo agencies (bus companies)
    await db.insert('agency', {
      'agency_id': 'BRTC',
      'agency_name': 'Bangladesh Road Transport Corporation',
      'agency_url': 'http://brtc.gov.bd',
      'agency_timezone': 'Asia/Dhaka',
      'agency_phone': '+8801700000000',
    });

    await db.insert('agency', {
      'agency_id': 'PRIVATE',
      'agency_name': 'Private Bus Operators',
      'agency_url': 'https://dhaka.gov.bd',
      'agency_timezone': 'Asia/Dhaka',
    });

    // Demo bus stops (major locations in Dhaka)
    final demoStops = [
      {'id': 'motijheel', 'name': 'Motijheel', 'lat': 23.7329, 'lon': 90.4172},
      {'id': 'dhanmondi', 'name': 'Dhanmondi', 'lat': 23.7461, 'lon': 90.3742},
      {'id': 'gulshan', 'name': 'Gulshan Circle 1', 'lat': 23.7806, 'lon': 90.4172},
      {'id': 'uttara', 'name': 'Uttara Sector 7', 'lat': 23.8759, 'lon': 90.3795},
      {'id': 'mirpur', 'name': 'Mirpur 10', 'lat': 23.8069, 'lon': 90.3687},
      {'id': 'farmgate', 'name': 'Farmgate', 'lat': 23.7580, 'lon': 90.3889},
      {'id': 'newmarket', 'name': 'New Market', 'lat': 23.7347, 'lon': 90.3851},
      {'id': 'shahbag', 'name': 'Shahbag', 'lat': 23.7387, 'lon': 90.3956},
      {'id': 'ramna', 'name': 'Ramna Park', 'lat': 23.7367, 'lon': 90.4015},
      {'id': 'tejgaon', 'name': 'Tejgaon', 'lat': 23.7632, 'lon': 90.3930},
      {'id': 'panthapath', 'name': 'Panthapath', 'lat': 23.7520, 'lon': 90.3840},
      {'id': 'elephantroad', 'name': 'Elephant Road', 'lat': 23.7401, 'lon': 90.3832},
      {'id': 'sadarghat', 'name': 'Sadarghat', 'lat': 23.7067, 'lon': 90.4086},
      {'id': 'wari', 'name': 'Wari', 'lat': 23.7195, 'lon': 90.4242},
      {'id': 'banani', 'name': 'Banani', 'lat': 23.7937, 'lon': 90.4066},
    ];

    for (final stop in demoStops) {
      await db.insert('stops', {
        'stop_id': stop['id'],
       'stop_code': (stop['id'] as String).toUpperCase(),

        'stop_name': stop['name'],
       'stop_desc': "Bus stop at ${stop['name']}",

        'stop_lat': stop['lat'],
        'stop_lon': stop['lon'],
        'location_type': 0,
        'wheelchair_boarding': 1,
      });
    }

    // Demo routes (major bus lines)
    final demoRoutes = [
      {
        'id': 'route_1',
        'agency': 'BRTC',
        'short_name': '1',
        'long_name': 'Motijheel - Uttara',
        'desc': 'North-South corridor via Farmgate',
        'color': 'FF0000',
      },
      {
        'id': 'route_2',
        'agency': 'PRIVATE', 
        'short_name': '2',
        'long_name': 'Dhanmondi - Gulshan',
        'desc': 'East-West connector',
        'color': '0000FF',
      },
      {
        'id': 'route_3',
        'agency': 'BRTC',
        'short_name': '3', 
        'long_name': 'Mirpur - Motijheel',
        'desc': 'Circular route via New Market',
        'color': '00FF00',
      },
    ];

    for (final route in demoRoutes) {
      await db.insert('routes', {
        'route_id': route['id'],
        'agency_id': route['agency'],
        'route_short_name': route['short_name'],
        'route_long_name': route['long_name'],
        'route_desc': route['desc'],
        'route_type': 3, // Bus
        'route_color': route['color'],
        'route_text_color': 'FFFFFF',
        'route_sort_order': 0,
      });
    }

    // Demo calendar (daily service)
    await db.insert('calendar', {
      'service_id': 'daily',
      'monday': 1,
      'tuesday': 1, 
      'wednesday': 1,
      'thursday': 1,
      'friday': 1,
      'saturday': 1,
      'sunday': 1,
      'start_date': '20250101',
      'end_date': '20251231',
    });

   final demoTrips = [
  {
    'trip_id': 'trip_1_1',
    'route_id': 'route_1',
    'service_id': 'daily',
    'trip_headsign': 'Uttara',   // ✅ fixed
    'direction_id': 0,
  },
  {
    'trip_id': 'trip_1_2',
    'route_id': 'route_1',
    'service_id': 'daily',
    'trip_headsign': 'Motijheel',
    'direction_id': 1,
  },
  {
    'trip_id': 'trip_2_1',
    'route_id': 'route_2',
    'service_id': 'daily',
    'trip_headsign': 'Gulshan',
    'direction_id': 0,
  },
];


    for (final trip in demoTrips) {
      await db.insert('trips', trip);
    }

    // Demo stop times (simplified schedule)
    final demoStopTimes = [
      // Route 1: Motijheel to Uttara
      {'trip_id': 'trip_1_1', 'stop_id': 'motijheel', 'sequence': 1, 'time': '06:00:00'},
      {'trip_id': 'trip_1_1', 'stop_id': 'farmgate', 'sequence': 2, 'time': '06:20:00'},
      {'trip_id': 'trip_1_1', 'stop_id': 'tejgaon', 'sequence': 3, 'time': '06:30:00'},
      {'trip_id': 'trip_1_1', 'stop_id': 'uttara', 'sequence': 4, 'time': '07:00:00'},

      // Route 1: Uttara to Motijheel
      {'trip_id': 'trip_1_2', 'stop_id': 'uttara', 'sequence': 1, 'time': '07:30:00'},
      {'trip_id': 'trip_1_2', 'stop_id': 'tejgaon', 'sequence': 2, 'time': '08:00:00'},
      {'trip_id': 'trip_1_2', 'stop_id': 'farmgate', 'sequence': 3, 'time': '08:10:00'},
      {'trip_id': 'trip_1_2', 'stop_id': 'motijheel', 'sequence': 4, 'time': '08:30:00'},

      // Route 2: Dhanmondi to Gulshan
      {'trip_id': 'trip_2_1', 'stop_id': 'dhanmondi', 'sequence': 1, 'time': '06:15:00'},
      {'trip_id': 'trip_2_1', 'stop_id': 'panthapath', 'sequence': 2, 'time': '06:25:00'},
      {'trip_id': 'trip_2_1', 'stop_id': 'farmgate', 'sequence': 3, 'time': '06:35:00'},
      {'trip_id': 'trip_2_1', 'stop_id': 'gulshan', 'sequence': 4, 'time': '06:50:00'},
    ];

    for (final stopTime in demoStopTimes) {
      await db.insert('stop_times', {
        'trip_id': stopTime['trip_id'],
        'arrival_time': stopTime['time'],
        'departure_time': stopTime['time'],
        'stop_id': stopTime['stop_id'],
        'stop_sequence': stopTime['sequence'],
        'pickup_type': 0,
        'drop_off_type': 0,
        'timepoint': 1,
      });
    }

    print('Demo GTFS data loaded successfully!');
  }

  /// Download and parse real GTFS data
  static Future<bool> downloadGTFSData(String url) async {
    try {
      print('Downloading GTFS data from: \$url');

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        print('Failed to download GTFS: \${response.statusCode}');
        return false;
      }

      // Extract ZIP file
      final archive = ZipDecoder().decodeBytes(response.bodyBytes);

      final db = await database;

      // Process each GTFS file
      for (final file in archive) {
        if (file.isFile && file.name.endsWith('.txt')) {
          await _processGTFSFile(db, file.name, file.content as List<int>);
        }
      }

      print('GTFS data processed successfully');
      return true;
    } catch (e) {
      print('Error downloading GTFS data: \$e');
      return false;
    }
  }

  /// Process individual GTFS CSV file
  static Future<void> _processGTFSFile(Database db, String filename, List<int> content) async {
    final csvStr = String.fromCharCodes(content);
    final rows = const CsvToListConverter().convert(csvStr);

    if (rows.isEmpty) return;

    final headers = rows[0].map((e) => e.toString()).toList();
    final dataRows = rows.skip(1).toList();

    switch (filename) {
      case 'agency.txt':
        await _insertAgencies(db, headers, dataRows);
        break;
      case 'stops.txt':
        await _insertStops(db, headers, dataRows);
        break;
      case 'routes.txt':
        await _insertRoutes(db, headers, dataRows);
        break;
      case 'trips.txt':
        await _insertTrips(db, headers, dataRows);
        break;
      case 'stop_times.txt':
        await _insertStopTimes(db, headers, dataRows);
        break;
      case 'calendar.txt':
        await _insertCalendar(db, headers, dataRows);
        break;
      case 'shapes.txt':
        await _insertShapes(db, headers, dataRows);
        break;
    }
  }

  /// Insert agencies from CSV
  static Future<void> _insertAgencies(Database db, List<String> headers, List<List> rows) async {
    await db.delete('agency'); // Clear existing data

    for (final row in rows) {
      final data = <String, dynamic>{};
      for (int i = 0; i < headers.length && i < row.length; i++) {
        data[headers[i]] = row[i];
      }

      await db.insert('agency', data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Insert stops from CSV
  static Future<void> _insertStops(Database db, List<String> headers, List<List> rows) async {
    await db.delete('stops');

    for (final row in rows) {
      final data = <String, dynamic>{};
      for (int i = 0; i < headers.length && i < row.length; i++) {
        data[headers[i]] = row[i];
      }

      await db.insert('stops', data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Insert routes from CSV
  static Future<void> _insertRoutes(Database db, List<String> headers, List<List> rows) async {
    await db.delete('routes');

    for (final row in rows) {
      final data = <String, dynamic>{};
      for (int i = 0; i < headers.length && i < row.length; i++) {
        data[headers[i]] = row[i];
      }

      await db.insert('routes', data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Insert trips from CSV
  static Future<void> _insertTrips(Database db, List<String> headers, List<List> rows) async {
    await db.delete('trips');

    for (final row in rows) {
      final data = <String, dynamic>{};
      for (int i = 0; i < headers.length && i < row.length; i++) {
        data[headers[i]] = row[i];
      }

      await db.insert('trips', data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Insert stop times from CSV
  static Future<void> _insertStopTimes(Database db, List<String> headers, List<List> rows) async {
    await db.delete('stop_times');

    final batch = db.batch();
    for (final row in rows) {
      final data = <String, dynamic>{};
      for (int i = 0; i < headers.length && i < row.length; i++) {
        data[headers[i]] = row[i];
      }

      batch.insert('stop_times', data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit();
  }

  /// Insert calendar from CSV
  static Future<void> _insertCalendar(Database db, List<String> headers, List<List> rows) async {
    await db.delete('calendar');

    for (final row in rows) {
      final data = <String, dynamic>{};
      for (int i = 0; i < headers.length && i < row.length; i++) {
        data[headers[i]] = row[i];
      }

      await db.insert('calendar', data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Insert shapes from CSV
  static Future<void> _insertShapes(Database db, List<String> headers, List<List> rows) async {
    await db.delete('shapes');

    final batch = db.batch();
    for (final row in rows) {
      final data = <String, dynamic>{};
      for (int i = 0; i < headers.length && i < row.length; i++) {
        data[headers[i]] = row[i];
      }

      batch.insert('shapes', data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit();
  }

  /// Find nearby stops
  static Future<List<GTFSStop>> findNearbyStops(LatLng location, {double radiusMeters = 1000}) async {
    final db = await database;

    // Simple bounding box search (can be improved with spatial indexing)
    const earthRadius = 6371000; // Earth radius in meters
    final latDelta = radiusMeters / earthRadius * (180 / 3.14159);
    final lonDelta = radiusMeters / (earthRadius * cos(location.latitude * 3.14159 / 180)) * (180 / 3.14159);

    final minLat = location.latitude - latDelta;
    final maxLat = location.latitude + latDelta;
    final minLon = location.longitude - lonDelta;
    final maxLon = location.longitude + lonDelta;

    final results = await db.query(
      'stops',
      where: 'stop_lat BETWEEN ? AND ? AND stop_lon BETWEEN ? AND ?',
      whereArgs: [minLat, maxLat, minLon, maxLon],
      orderBy: 'stop_name',
    );

    final stops = results.map((row) => GTFSStop.fromCsv(row)).toList();

    // Calculate exact distances and filter
    final nearbyStops = <GTFSStop>[];
    for (final stop in stops) {
      final distance = stop.distanceTo(location);
      if (distance <= radiusMeters) {
        nearbyStops.add(stop);
      }
    }

    // Sort by distance
    nearbyStops.sort((a, b) => a.distanceTo(location).compareTo(b.distanceTo(location)));

    return nearbyStops;
  }

  /// Get all routes
  static Future<List<GTFSRoute>> getAllRoutes() async {
    final db = await database;
    final results = await db.query('routes', orderBy: 'route_sort_order, route_short_name');
    return results.map((row) => GTFSRoute.fromCsv(row)).toList();
  }

  /// Get route by ID
  static Future<GTFSRoute?> getRoute(String routeId) async {
    final db = await database;
    final results = await db.query('routes', where: 'route_id = ?', whereArgs: [routeId]);

    if (results.isNotEmpty) {
      return GTFSRoute.fromCsv(results.first);
    }
    return null;
  }

  /// Get stops for a route
  static Future<List<GTFSStop>> getStopsForRoute(String routeId) async {
    final db = await database;

    final results = await db.rawQuery('''
      SELECT DISTINCT s.*
      FROM stops s
      INNER JOIN stop_times st ON s.stop_id = st.stop_id
      INNER JOIN trips t ON st.trip_id = t.trip_id
      WHERE t.route_id = ?
      ORDER BY st.stop_sequence
    ''', [routeId]);

    return results.map((row) => GTFSStop.fromCsv(row)).toList();
  }

  /// Clear all GTFS data
  static Future<void> clearData() async {
    final db = await database;

    await db.delete('shapes');
    await db.delete('stop_times');
    await db.delete('calendar');
    await db.delete('trips');
    await db.delete('routes');
    await db.delete('stops');
    await db.delete('agency');
  }
static Future<Map<String, int>> getDatabaseStats() async {
  final db = await database;
  final stats = <String, int>{};

  final tables = ['agency', 'stops', 'routes', 'trips', 'stop_times', 'calendar', 'shapes'];

  for (final table in tables) {
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
    stats[table] = Sqflite.firstIntValue(result) ?? 0;
  }

  return stats;
}

}
