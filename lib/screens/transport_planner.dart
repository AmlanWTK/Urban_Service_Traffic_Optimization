import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:urban_service_traffic_optimization/models/gtfs_models.dart';
import 'package:urban_service_traffic_optimization/services/newservices/gtfs_service.dart';
import 'package:url_launcher/url_launcher.dart';


/// Public Transport Planner Service
/// FREE implementation with ride-share deep linking
class PublicTransportPlanner {
  static const double _walkingSpeedKmh = 5.0; // Average walking speed
  static const double _maxWalkingDistanceM = 1000.0; // Max walking distance to stops
  static const int _maxTransfers = 2; // Maximum number of transfers

  /// Plan a multimodal journey
  static Future<List<PublicTransportItinerary>> planJourney({
    required LatLng origin,
    required LatLng destination,
    DateTime? departureTime,
    bool includeWalking = true,
    bool includeRideshare = true,
  }) async {
    final List<PublicTransportItinerary> itineraries = [];
    departureTime ??= DateTime.now();

    print('Planning journey from \${origin.latitude.toStringAsFixed(4)},\${origin.longitude.toStringAsFixed(4)} to \${destination.latitude.toStringAsFixed(4)},\${destination.longitude.toStringAsFixed(4)}');

    try {
      // 1. Walking-only option
      if (includeWalking) {
        final walkingItinerary = await _planWalkingOnlyJourney(origin, destination, departureTime);
        if (walkingItinerary != null) {
          itineraries.add(walkingItinerary);
        }
      }

      // 2. Public transport options
      final transitItineraries = await _planTransitJourneys(origin, destination, departureTime);
      itineraries.addAll(transitItineraries);

      // 3. Ride-share options (deep links)
      if (includeRideshare) {
        final rideshareItineraries = await _createRideshareOptions(origin, destination, departureTime);
        itineraries.addAll(rideshareItineraries);
      }

      // Sort by total duration
      itineraries.sort((a, b) => a.totalDuration.compareTo(b.totalDuration));

      print('Found \${itineraries.length} journey options');
      return itineraries;

    } catch (e) {
      print('Error planning journey: \$e');
      return [];
    }
  }

  /// Plan walking-only journey
  static Future<PublicTransportItinerary?> _planWalkingOnlyJourney(
    LatLng origin, 
    LatLng destination, 
    DateTime departureTime
  ) async {
    final distance = const Distance().as(LengthUnit.Meter, origin, destination);

    // Only suggest walking for reasonable distances (up to 2km)
    if (distance > 2000) return null;

    final duration = Duration(seconds: (distance / (_walkingSpeedKmh * 1000 / 3600)).round());
    final arrivalTime = departureTime.add(duration);

    final walkingLeg = ItineraryLeg(
      mode: TransportMode.walk,
      startTime: departureTime,
      endTime: arrivalTime,
      from: origin,
      to: destination,
      fromName: 'Origin',
      toName: 'Destination',
      duration: duration,
      distance: distance,
      geometry: [origin, destination],
      instructions: 'Walk to destination',
    );

    return PublicTransportItinerary(
      startTime: departureTime,
      endTime: arrivalTime,
      totalDuration: duration,
      totalDistance: distance,
      legs: [walkingLeg],
      transfers: 0,
      walkingDistance: distance,
    );
  }

  /// Plan transit journeys using GTFS data
  static Future<List<PublicTransportItinerary>> _planTransitJourneys(
    LatLng origin,
    LatLng destination, 
    DateTime departureTime
  ) async {
    final List<PublicTransportItinerary> itineraries = [];

    try {
      // Find nearby origin stops
      final originStops = await GTFSService.findNearbyStops(origin, radiusMeters: _maxWalkingDistanceM);
      if (originStops.isEmpty) {
        print('No origin stops found within walking distance');
        return [];
      }

      // Find nearby destination stops
      final destinationStops = await GTFSService.findNearbyStops(destination, radiusMeters: _maxWalkingDistanceM);
      if (destinationStops.isEmpty) {
        print('No destination stops found within walking distance');
        return [];
      }

      print('Found \${originStops.length} origin stops and \${destinationStops.length} destination stops');

      // Try direct routes (no transfers)
      final directItineraries = await _findDirectRoutes(
        origin, destination, originStops, destinationStops, departureTime
      );
      itineraries.addAll(directItineraries);

      // Try routes with one transfer
      if (directItineraries.isEmpty || directItineraries.length < 3) {
        final transferItineraries = await _findRoutesWithTransfers(
          origin, destination, originStops, destinationStops, departureTime, 1
        );
        itineraries.addAll(transferItineraries);
      }

      return itineraries;

    } catch (e) {
      print('Error planning transit journeys: \$e');
      return [];
    }
  }

  /// Find direct routes without transfers
  static Future<List<PublicTransportItinerary>> _findDirectRoutes(
    LatLng origin,
    LatLng destination,
    List<GTFSStop> originStops,
    List<GTFSStop> destinationStops,
    DateTime departureTime
  ) async {
    final List<PublicTransportItinerary> itineraries = [];

    try {
      final db = await GTFSService.database;

      // Find routes that serve both origin and destination stops
      for (final originStop in originStops.take(5)) { // Limit to 5 closest stops
        for (final destStop in destinationStops.take(5)) {
          // Query for common routes
          final commonRoutes = await db.rawQuery('''
            SELECT DISTINCT r.*, t1.trip_id as origin_trip, t2.trip_id as dest_trip
            FROM routes r
            INNER JOIN trips tr ON r.route_id = tr.route_id
            INNER JOIN stop_times t1 ON tr.trip_id = t1.trip_id AND t1.stop_id = ?
            INNER JOIN stop_times t2 ON tr.trip_id = t2.trip_id AND t2.stop_id = ?
            WHERE t1.stop_sequence < t2.stop_sequence
            ORDER BY r.route_short_name
          ''', [originStop.id, destStop.id]);

          for (final routeRow in commonRoutes) {
            final route = GTFSRoute.fromCsv(routeRow);

            // Create itinerary for this route
            final itinerary = await _createDirectItinerary(
              origin, destination, originStop, destStop, route, departureTime
            );

            if (itinerary != null) {
              itineraries.add(itinerary);
            }
          }
        }
      }

      return itineraries;

    } catch (e) {
      print('Error finding direct routes: \$e');
      return [];
    }
  }

  /// Create itinerary for direct route
  static Future<PublicTransportItinerary?> _createDirectItinerary(
    LatLng origin,
    LatLng destination,
    GTFSStop originStop,
    GTFSStop destStop,
    GTFSRoute route,
    DateTime departureTime
  ) async {
    try {
      final List<ItineraryLeg> legs = [];
      DateTime currentTime = departureTime;
      double totalDistance = 0;
      double walkingDistance = 0;

      // Walking to origin stop
      final walkToStopDistance = originStop.distanceTo(origin);
      if (walkToStopDistance > 0) {
        final walkToStopDuration = Duration(
          seconds: (walkToStopDistance / (_walkingSpeedKmh * 1000 / 3600)).round()
        );

        legs.add(ItineraryLeg(
          mode: TransportMode.walk,
          startTime: currentTime,
          endTime: currentTime.add(walkToStopDuration),
          from: origin,
          to: originStop.location,
          fromName: 'Origin',
          toName: originStop.name,
          duration: walkToStopDuration,
          distance: walkToStopDistance,
          geometry: [origin, originStop.location],
          instructions: 'Walk to \${originStop.name}',
        ));

        currentTime = currentTime.add(walkToStopDuration);
        totalDistance += walkToStopDistance;
        walkingDistance += walkToStopDistance;
      }

      // Bus journey
      final busDistance = const Distance().as(LengthUnit.Meter, originStop.location, destStop.location);
      final busDuration = Duration(minutes: (busDistance / 1000 / 20 * 60).round()); // Assume 20 km/h average

      // Add waiting time (5-15 minutes based on time of day)
      final waitingTime = _calculateWaitingTime(currentTime);
      currentTime = currentTime.add(waitingTime);

      legs.add(ItineraryLeg(
        mode: TransportMode.bus,
        startTime: currentTime,
        endTime: currentTime.add(busDuration),
        from: originStop.location,
        to: destStop.location,
        fromName: originStop.name,
        toName: destStop.name,
        duration: busDuration,
        distance: busDistance,
        route: route,
        geometry: [originStop.location, destStop.location],
        headsign: 'Route \${route.shortName}',
        instructions: 'Take Route \${route.shortName} to \${destStop.name}',
      ));

      currentTime = currentTime.add(busDuration);
      totalDistance += busDistance;

      // Walking from destination stop
      final walkFromStopDistance = destStop.distanceTo(destination);
      if (walkFromStopDistance > 0) {
        final walkFromStopDuration = Duration(
          seconds: (walkFromStopDistance / (_walkingSpeedKmh * 1000 / 3600)).round()
        );

        legs.add(ItineraryLeg(
          mode: TransportMode.walk,
          startTime: currentTime,
          endTime: currentTime.add(walkFromStopDuration),
          from: destStop.location,
          to: destination,
          fromName: destStop.name,
          toName: 'Destination',
          duration: walkFromStopDuration,
          distance: walkFromStopDistance,
          geometry: [destStop.location, destination],
          instructions: 'Walk to destination',
        ));

        currentTime = currentTime.add(walkFromStopDuration);
        totalDistance += walkFromStopDistance;
        walkingDistance += walkFromStopDistance;
      }

      return PublicTransportItinerary(
        startTime: departureTime,
        endTime: currentTime,
        totalDuration: currentTime.difference(departureTime),
        totalDistance: totalDistance,
        legs: legs,
        transfers: 0,
        walkingDistance: walkingDistance,
      );

    } catch (e) {
      print('Error creating direct itinerary: \$e');
      return null;
    }
  }

  /// Find routes with transfers
  static Future<List<PublicTransportItinerary>> _findRoutesWithTransfers(
    LatLng origin,
    LatLng destination,
    List<GTFSStop> originStops,
    List<GTFSStop> destinationStops,
    DateTime departureTime,
    int maxTransfers
  ) async {
    // Simplified transfer routing - in a real implementation, this would be more sophisticated
    final List<PublicTransportItinerary> itineraries = [];

    try {
      // Find potential transfer stops
      final allStops = await GTFSService.findNearbyStops(
        LatLng(
          (origin.latitude + destination.latitude) / 2,
          (origin.longitude + destination.longitude) / 2,
        ),
        radiusMeters: 5000, // 5km radius for transfer stops
      );

      // Try routes via major transfer stops
      for (final transferStop in allStops.take(10)) {
        // Find route from origin to transfer stop
        final firstLegItineraries = await _findDirectRoutes(
          origin, transferStop.location, originStops, [transferStop], departureTime
        );

        if (firstLegItineraries.isNotEmpty) {
          final firstLeg = firstLegItineraries.first;

          // Find route from transfer stop to destination
          final secondLegItineraries = await _findDirectRoutes(
            transferStop.location, destination, [transferStop], destinationStops, firstLeg.endTime.add(Duration(minutes: 5))
          );

          if (secondLegItineraries.isNotEmpty) {
            final secondLeg = secondLegItineraries.first;

            // Combine legs for transfer itinerary
            final combinedLegs = [...firstLeg.legs, ...secondLeg.legs];

            final transferItinerary = PublicTransportItinerary(
              startTime: firstLeg.startTime,
              endTime: secondLeg.endTime,
              totalDuration: secondLeg.endTime.difference(firstLeg.startTime),
              totalDistance: firstLeg.totalDistance + secondLeg.totalDistance,
              legs: combinedLegs,
              transfers: 1,
              walkingDistance: firstLeg.walkingDistance + secondLeg.walkingDistance,
            );

            itineraries.add(transferItinerary);
          }
        }
      }

      return itineraries;

    } catch (e) {
      print('Error finding transfer routes: \$e');
      return [];
    }
  }

  /// Calculate waiting time based on time of day
  static Duration _calculateWaitingTime(DateTime time) {
    final hour = time.hour;

    // Peak hours: shorter waiting time
    if ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)) {
      return Duration(minutes: 5 + math.Random().nextInt(5)); // 5-10 minutes
    }

    // Off-peak: longer waiting time
    return Duration(minutes: 10 + math.Random().nextInt(10)); // 10-20 minutes
  }

  /// Create ride-share options with deep links
  static Future<List<PublicTransportItinerary>> _createRideshareOptions(
    LatLng origin,
    LatLng destination,
    DateTime departureTime
  ) async {
    final List<PublicTransportItinerary> itineraries = [];

    try {
      final distance = const Distance().as(LengthUnit.Meter, origin, destination);

      // Estimate duration based on distance and traffic
      final baseDuration = Duration(seconds: (distance / (25 * 1000 / 3600)).round()); // 25 km/h in traffic

      // Pathao option
      final pathaoItinerary = _createRideshareItinerary(
        origin, destination, departureTime, baseDuration, distance,
        'Pathao', 'pathao', Colors.green
      );
      itineraries.add(pathaoItinerary);

      // Uber option
      final uberItinerary = _createRideshareItinerary(
        origin, destination, departureTime, baseDuration, distance,
        'Uber', 'uber', Colors.black
      );
      itineraries.add(uberItinerary);

      // Local ride-share options
      final shohozItinerary = _createRideshareItinerary(
        origin, destination, departureTime, baseDuration, distance,
        'Shohoz', 'shohoz', Colors.orange
      );
      itineraries.add(shohozItinerary);

      return itineraries;

    } catch (e) {
      print('Error creating rideshare options: \$e');
      return [];
    }
  }

  /// Create individual ride-share itinerary
  static PublicTransportItinerary _createRideshareItinerary(
    LatLng origin,
    LatLng destination,
    DateTime departureTime,
    Duration baseDuration,
    double distance,
    String serviceName,
    String serviceId,
    Color serviceColor
  ) {
    // Add waiting time for ride-share
    final waitingTime = Duration(minutes: 3 + math.Random().nextInt(7)); // 3-10 minutes
    final startTime = departureTime.add(waitingTime);
    final endTime = startTime.add(baseDuration);

    final rideLeg = ItineraryLeg(
      mode: TransportMode.rideshare,
      startTime: startTime,
      endTime: endTime,
      from: origin,
      to: destination,
      fromName: 'Origin',
      toName: 'Destination',
      duration: baseDuration,
      distance: distance,
      geometry: [origin, destination],
      instructions: 'Ride with \$serviceName',
    );

    return PublicTransportItinerary(
      startTime: departureTime,
      endTime: endTime,
      totalDuration: endTime.difference(departureTime),
      totalDistance: distance,
      legs: [rideLeg],
      transfers: 0,
      walkingDistance: 0,
    );
  }

  /// Open ride-share app with destination
  static Future<void> openRideshareApp(String service, LatLng origin, LatLng destination) async {
    String? url;

    switch (service.toLowerCase()) {
      case 'pathao':
        // Pathao deep link (if supported)
        url = 'pathao://ride?pickup_lat=\${origin.latitude}&pickup_lng=\${origin.longitude}&destination_lat=\${destination.latitude}&destination_lng=\${destination.longitude}';
        break;

      case 'uber':
        // Uber deep link
        url = 'uber://?action=setPickup&pickup_lat=\${origin.latitude}&pickup_lng=\${origin.longitude}&dropoff_lat=\${destination.latitude}&dropoff_lng=\${destination.longitude}';
        break;

      case 'shohoz':
        // Shohoz deep link (if supported)
        url = 'shohoz://ride?from_lat=\${origin.latitude}&from_lng=\${origin.longitude}&to_lat=\${destination.latitude}&to_lng=\${destination.longitude}';
        break;
    }

    if (url != null) {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          print('Opened \$service app');
          return;
        }
      } catch (e) {
        print('Error opening \$service app: \$e');
      }
    }

    // Fallback to app store or web
    await _openAppStoreFallback(service);
  }

  /// Open app store as fallback
  static Future<void> _openAppStoreFallback(String service) async {
    String? fallbackUrl;

    switch (service.toLowerCase()) {
      case 'pathao':
        fallbackUrl = 'https://play.google.com/store/apps/details?id=com.pathao.user';
        break;
      case 'uber':
        fallbackUrl = 'https://play.google.com/store/apps/details?id=com.ubercab';
        break;
      case 'shohoz':
        fallbackUrl = 'https://play.google.com/store/apps/details?id=com.shohoz.user';
        break;
    }

    if (fallbackUrl != null) {
      try {
        final uri = Uri.parse(fallbackUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('Opened app store for \$service');
      } catch (e) {
        print('Error opening app store: \$e');
      }
    }
  }

  /// Calculate real-time estimates using traffic data
  static Future<Duration> calculateRealTimeDuration(
    LatLng origin,
    LatLng destination,
    TransportMode mode
  ) async {
    // This would integrate with your existing OSM traffic simulation
    final distance = const Distance().as(LengthUnit.Meter, origin, destination);

    switch (mode) {
      case TransportMode.walk:
        return Duration(seconds: (distance / (_walkingSpeedKmh * 1000 / 3600)).round());

      case TransportMode.bus:
        // Simulate traffic-aware bus speed
        final hour = DateTime.now().hour;
        double speedKmh = 25; // Base speed

        // Adjust for traffic (integrate with your OSM traffic system)
        if ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)) {
          speedKmh = 15; // Rush hour
        } else if (hour >= 22 || hour <= 6) {
          speedKmh = 35; // Night time
        }

        return Duration(seconds: (distance / (speedKmh * 1000 / 3600)).round());

      case TransportMode.rideshare:
        // Use similar logic to your OSM traffic simulation
        return Duration(seconds: (distance / (20 * 1000 / 3600)).round()); // Traffic-aware

      default:
        return Duration(seconds: (distance / (25 * 1000 / 3600)).round());
    }
  }

  /// Get service status for real-time updates
  static Future<Map<String, String>> getServiceStatus() async {
    // This could integrate with real-time feeds if available
    return {
      'buses': 'Normal service',
      'pathao': 'Available',
      'uber': 'Available', 
      'shohoz': 'Available',
      'last_updated': DateTime.now().toIso8601String(),
    };
  }
}
