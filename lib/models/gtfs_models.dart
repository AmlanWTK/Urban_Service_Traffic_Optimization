import 'package:latlong2/latlong.dart';

/// GTFS Data Models for Public Transport
/// Free implementation - no API keys required!

/// GTFS Agency (Bus companies)
class GTFSAgency {
  final String id;
  final String name;
  final String url;
  final String timezone;
  final String? phone;
  final String? fareUrl;
  final String? email;

  GTFSAgency({
    required this.id,
    required this.name,
    required this.url,
    required this.timezone,
    this.phone,
    this.fareUrl,
    this.email,
  });

  factory GTFSAgency.fromCsv(Map<String, dynamic> row) {
    return GTFSAgency(
      id: row['agency_id'] ?? '',
      name: row['agency_name'] ?? '',
      url: row['agency_url'] ?? '',
      timezone: row['agency_timezone'] ?? 'Asia/Dhaka',
      phone: row['agency_phone'],
      fareUrl: row['agency_fare_url'],
      email: row['agency_email'],
    );
  }
}

/// GTFS Stop (Bus stops)
class GTFSStop {
  final String id;
  final String code;
  final String name;
  final String description;
  final LatLng location;
  final String? zoneId;
  final String? url;
  final int locationType;
  final String? parentStation;
  final int wheelchairBoarding;

  GTFSStop({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.location,
    this.zoneId,
    this.url,
    this.locationType = 0,
    this.parentStation,
    this.wheelchairBoarding = 0,
  });

  factory GTFSStop.fromCsv(Map<String, dynamic> row) {
    return GTFSStop(
      id: row['stop_id'] ?? '',
      code: row['stop_code'] ?? '',
      name: row['stop_name'] ?? '',
      description: row['stop_desc'] ?? '',
      location: LatLng(
        double.tryParse(row['stop_lat'].toString()) ?? 0.0,
        double.tryParse(row['stop_lon'].toString()) ?? 0.0,
      ),
      zoneId: row['zone_id'],
      url: row['stop_url'],
      locationType: int.tryParse(row['location_type'].toString()) ?? 0,
      parentStation: row['parent_station'],
      wheelchairBoarding: int.tryParse(row['wheelchair_boarding'].toString()) ?? 0,
    );
  }

  /// Calculate distance to another point
  double distanceTo(LatLng point) {
    return const Distance().as(LengthUnit.Meter, location, point);
  }
}

/// GTFS Route (Bus lines)
class GTFSRoute {
  final String id;
  final String agencyId;
  final String shortName;
  final String longName;
  final String description;
  final int type;
  final String? url;
  final String? color;
  final String? textColor;
  final int sortOrder;

  GTFSRoute({
    required this.id,
    required this.agencyId,
    required this.shortName,
    required this.longName,
    required this.description,
    required this.type,
    this.url,
    this.color,
    this.textColor,
    this.sortOrder = 0,
  });

  factory GTFSRoute.fromCsv(Map<String, dynamic> row) {
    return GTFSRoute(
      id: row['route_id'] ?? '',
      agencyId: row['agency_id'] ?? '',
      shortName: row['route_short_name'] ?? '',
      longName: row['route_long_name'] ?? '',
      description: row['route_desc'] ?? '',
      type: int.tryParse(row['route_type'].toString()) ?? 3, // Bus = 3
      url: row['route_url'],
      color: row['route_color'] ?? 'FF0000',
      textColor: row['route_text_color'] ?? 'FFFFFF',
      sortOrder: int.tryParse(row['route_sort_order'].toString()) ?? 0,
    );
  }

  /// Get route type name
  String get typeName {
    switch (type) {
      case 0: return 'Tram';
      case 1: return 'Subway';
      case 2: return 'Rail';
      case 3: return 'Bus';
      case 4: return 'Ferry';
      case 5: return 'Cable car';
      case 6: return 'Gondola';
      case 7: return 'Funicular';
      default: return 'Unknown';
    }
  }
}

/// GTFS Trip (Individual bus journeys)
class GTFSTrip {
  final String id;
  final String routeId;
  final String serviceId;
  final String headsign;
  final String shortName;
  final int directionId;
  final String? blockId;
  final String? shapeId;
  final int wheelchairAccessible;
  final int bikesAllowed;

  GTFSTrip({
    required this.id,
    required this.routeId,
    required this.serviceId,
    required this.headsign,
    required this.shortName,
    required this.directionId,
    this.blockId,
    this.shapeId,
    this.wheelchairAccessible = 0,
    this.bikesAllowed = 0,
  });

  factory GTFSTrip.fromCsv(Map<String, dynamic> row) {
    return GTFSTrip(
      id: row['trip_id'] ?? '',
      routeId: row['route_id'] ?? '',
      serviceId: row['service_id'] ?? '',
      headsign: row['trip_headsign'] ?? '',
      shortName: row['trip_short_name'] ?? '',
      directionId: int.tryParse(row['direction_id'].toString()) ?? 0,
      blockId: row['block_id'],
      shapeId: row['shape_id'],
      wheelchairAccessible: int.tryParse(row['wheelchair_accessible'].toString()) ?? 0,
      bikesAllowed: int.tryParse(row['bikes_allowed'].toString()) ?? 0,
    );
  }
}

/// GTFS Stop Time (Bus schedule at stops)
class GTFSStopTime {
  final String tripId;
  final String arrivalTime;
  final String departureTime;
  final String stopId;
  final int stopSequence;
  final String? headsign;
  final int pickupType;
  final int dropOffType;
  final double? shapeDistTraveled;
  final int timepoint;

  GTFSStopTime({
    required this.tripId,
    required this.arrivalTime,
    required this.departureTime,
    required this.stopId,
    required this.stopSequence,
    this.headsign,
    this.pickupType = 0,
    this.dropOffType = 0,
    this.shapeDistTraveled,
    this.timepoint = 1,
  });

  factory GTFSStopTime.fromCsv(Map<String, dynamic> row) {
    return GTFSStopTime(
      tripId: row['trip_id'] ?? '',
      arrivalTime: row['arrival_time'] ?? '',
      departureTime: row['departure_time'] ?? '',
      stopId: row['stop_id'] ?? '',
      stopSequence: int.tryParse(row['stop_sequence'].toString()) ?? 0,
      headsign: row['stop_headsign'],
      pickupType: int.tryParse(row['pickup_type'].toString()) ?? 0,
      dropOffType: int.tryParse(row['drop_off_type'].toString()) ?? 0,
      shapeDistTraveled: double.tryParse(row['shape_dist_traveled'].toString()),
      timepoint: int.tryParse(row['timepoint'].toString()) ?? 1,
    );
  }

  /// Parse time string to Duration
  Duration get arrivalDuration => _parseTime(arrivalTime);
  Duration get departureDuration => _parseTime(departureTime);

  Duration _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 3) return Duration.zero;

    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    final seconds = int.tryParse(parts[2]) ?? 0;

    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }
}

/// GTFS Calendar (Service days)
class GTFSCalendar {
  final String serviceId;
  final bool monday;
  final bool tuesday;
  final bool wednesday;
  final bool thursday;
  final bool friday;
  final bool saturday;
  final bool sunday;
  final DateTime startDate;
  final DateTime endDate;

  GTFSCalendar({
    required this.serviceId,
    required this.monday,
    required this.tuesday,
    required this.wednesday,
    required this.thursday,
    required this.friday,
    required this.saturday,
    required this.sunday,
    required this.startDate,
    required this.endDate,
  });

  factory GTFSCalendar.fromCsv(Map<String, dynamic> row) {
    return GTFSCalendar(
      serviceId: row['service_id'] ?? '',
      monday: row['monday'] == '1',
      tuesday: row['tuesday'] == '1',
      wednesday: row['wednesday'] == '1',
      thursday: row['thursday'] == '1',
      friday: row['friday'] == '1',
      saturday: row['saturday'] == '1',
      sunday: row['sunday'] == '1',
      startDate: _parseDate(row['start_date'] ?? ''),
      endDate: _parseDate(row['end_date'] ?? ''),
    );
  }

  static DateTime _parseDate(String dateStr) {
    if (dateStr.length != 8) return DateTime.now();

    final year = int.tryParse(dateStr.substring(0, 4)) ?? DateTime.now().year;
    final month = int.tryParse(dateStr.substring(4, 6)) ?? 1;
    final day = int.tryParse(dateStr.substring(6, 8)) ?? 1;

    return DateTime(year, month, day);
  }

  /// Check if service runs on given date
  bool runsOnDate(DateTime date) {
    if (date.isBefore(startDate) || date.isAfter(endDate)) return false;

    switch (date.weekday) {
      case DateTime.monday: return monday;
      case DateTime.tuesday: return tuesday;
      case DateTime.wednesday: return wednesday;
      case DateTime.thursday: return thursday;
      case DateTime.friday: return friday;
      case DateTime.saturday: return saturday;
      case DateTime.sunday: return sunday;
      default: return false;
    }
  }
}

/// GTFS Shape (Route geometry)
class GTFSShape {
  final String id;
  final double lat;
  final double lon;
  final int sequence;
  final double? distTraveled;

  GTFSShape({
    required this.id,
    required this.lat,
    required this.lon,
    required this.sequence,
    this.distTraveled,
  });

  factory GTFSShape.fromCsv(Map<String, dynamic> row) {
    return GTFSShape(
      id: row['shape_id'] ?? '',
      lat: double.tryParse(row['shape_pt_lat'].toString()) ?? 0.0,
      lon: double.tryParse(row['shape_pt_lon'].toString()) ?? 0.0,
      sequence: int.tryParse(row['shape_pt_sequence'].toString()) ?? 0,
      distTraveled: double.tryParse(row['shape_dist_traveled'].toString()),
    );
  }

  LatLng get location => LatLng(lat, lon);
}

/// Public Transport Journey Itinerary
class PublicTransportItinerary {
  final DateTime startTime;
  final DateTime endTime;
  final Duration totalDuration;
  final double totalDistance;
  final List<ItineraryLeg> legs;
  final int transfers;
  final double walkingDistance;

  PublicTransportItinerary({
    required this.startTime,
    required this.endTime,
    required this.totalDuration,
    required this.totalDistance,
    required this.legs,
    required this.transfers,
    required this.walkingDistance,
  });

  /// Get formatted duration
  String get formattedDuration {
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Get formatted distance
  String get formattedDistance {
    if (totalDistance >= 1000) {
      return '${(totalDistance / 1000).toStringAsFixed(1)} km';
    } else {
      return '${totalDistance.toInt()} m';
    }
  }

  /// Get total cost estimate (in BDT)
  double get estimatedCost {
    double cost = 0;
    for (final leg in legs) {
      if (leg.mode == TransportMode.bus) {
        cost += 25; // Average bus fare in Dhaka
      }
    }
    return cost;
  }
}

/// Individual leg of a journey
class ItineraryLeg {
  final TransportMode mode;
  final DateTime startTime;
  final DateTime endTime;
  final LatLng from;
  final LatLng to;
  final String fromName;
  final String toName;
  final Duration duration;
  final double distance;
  final GTFSRoute? route;
  final GTFSTrip? trip;
  final List<LatLng> geometry;
  final String? headsign;
  final String? instructions;

  ItineraryLeg({
    required this.mode,
    required this.startTime,
    required this.endTime,
    required this.from,
    required this.to,
    required this.fromName,
    required this.toName,
    required this.duration,
    required this.distance,
    this.route,
    this.trip,
    this.geometry = const [],
    this.headsign,
    this.instructions,
  });
}

/// Transport modes
enum TransportMode {
  walk,
  bus,
  rail,
  ferry,
  rideshare,
}

extension TransportModeExtension on TransportMode {
  String get name {
    switch (this) {
      case TransportMode.walk:
        return 'Walk';
      case TransportMode.bus:
        return 'Bus';
      case TransportMode.rail:
        return 'Rail';
      case TransportMode.ferry:
        return 'Ferry';
      case TransportMode.rideshare:
        return 'Ride-share';
    }
  }

  String get icon {
    switch (this) {
      case TransportMode.walk:
        return '🚶';
      case TransportMode.bus:
        return '🚌';
      case TransportMode.rail:
        return '🚊';
      case TransportMode.ferry:
        return '⛴️';
      case TransportMode.rideshare:
        return '🚗';
    }
  }
}
