import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/data/nairobi_corridors_seed.dart';
import 'package:navi_app/data/nairobi_stages_seed.dart';
import 'package:navi_app/models/active_journey.dart';
import 'package:navi_app/models/route_segment.dart';
import 'package:navi_app/models/search_result.dart';
import 'package:navi_app/services/fare_calculator_service.dart';
import 'package:navi_app/services/stage_registry.dart';

class RouteBuilderService {
  static const double kMatatuAvgSpeedKmh = 20.0;
  static const double kWalkSpeedMs = 1.4;
  static const double kTransferWalkThresholdMeters = 800.0;

  /// Direct (crow-flies) distance under which "Prefer walking paths" forces a
  /// walk-only route instead of staging a matatu trip. 1.5 km is a ten-minute
  /// stroll in Nairobi weather — long enough to actually replace a short ride.
  static const double kWalkPreferredDistanceMeters = 1500.0;

  /// When "Avoid busy junctions" is on, how far travellers are willing to walk
  /// away from a busy corridor to board the first stage of a quieter one.
  static const double kBusyCorridorBypassWalkMeters = 1200.0;

  /// Corridors treated as high-volume by the busy-junction heuristic.
  ///
  /// Static dataset heuristic derived from Nairobi's best-known choke points
  /// (CBD + the two busiest arterials). This is a documented placeholder
  /// pending live traffic data; the toggle's label already says "Route around
  /// traffic hotspots", which this set approximates.
  static const Set<String> kBusyCorridorIds = {
    'cbd',
    'ngong_road',
    'mombasa_road',
  };

  /// Build an ActiveJourney from origin to destination SearchResult.
  ///
  /// Boarding and alighting stages are anchored to their OWN ends of the trip:
  /// - boarding stage = nearest route-carrying stage to the USER'S ORIGIN;
  /// - alighting stage = destination-side stage (exact pick when the user
  ///   chose a stage, otherwise the nearest stage on the boarding corridor).
  ///
  /// When both resolve to the same stage the trip is genuinely local to one
  /// stage, so a walk-only route is emitted instead of a nonsensical "ride to
  /// the stage you just walked to".
  static Future<ActiveJourney> build({
    required LatLng origin,
    required SearchResult destination,
    bool preferWalkingPaths = false,
    bool avoidBusyJunctions = false,
  }) async {
    final destinationCoord = LatLng(destination.lat, destination.lng);

    // "Prefer walking paths": any trip short enough to walk (<= 1.5 km
    // straight-line) becomes a plain walk — no staging, no matatu hop.
    final directDistance = _haversineDistance(
      origin.latitude, origin.longitude,
      destination.lat, destination.lng,
    );
    if (preferWalkingPaths && directDistance <= kWalkPreferredDistanceMeters) {
      return _walkOnlyRoute(origin, destinationCoord, destination.resolvedLabel);
    }

    // Boarding stage: nearest route-carrying stage to the ORIGIN. The old
    // code resolved this from destination.nearestStageName, which produced
    // absurd routes (walk many km to the destination's stage to board there,
    // then ride to the same stage). Origin-side anchor fixes it.
    final boardingStage = _findNearestStage(origin.latitude, origin.longitude);
    if (boardingStage == null) {
      throw ArgumentError('Could not find a boarding stage near the origin');
    }
    final boardingCorridor = _findCorridorById(boardingStage.corridorId);

    // Alighting stage: anchored to the DESTINATION. The user's exact stage
    // pick (e.g. via the Stage Details sheet) wins when it is a real pick;
    // otherwise the stage on the boarding corridor nearest the destination.
    final declaredDestStage = _findStageById(destination.nearestStageName);
    final alightingStage = _selectAlightingStage(
      boardingStage: boardingStage,
      declaredDestStage: declaredDestStage,
      destinationLat: destination.lat,
      destinationLng: destination.lng,
    );
    if (alightingStage == null) {
      throw ArgumentError('Could not find an alighting stage for the destination');
    }
    final alightingCorridor = _findCorridorById(alightingStage.corridorId);

    // Same-stage guard: origin and destination genuinely share a stage (or the
    // destination IS the boarding stage) — a matatu ride back to the very
    // stage you walked to is never sensible, so the trip is walk-only.
    if (boardingStage.id == alightingStage.id) {
      return _walkOnlyRoute(origin, destinationCoord, destination.resolvedLabel);
    }

    final boardingCoord = boardingStage.location;
    final alightingCoord = alightingStage.location;

    // No-corridor guard: GTFS-only stages may carry no corridor id yet
    // (nothing to slice, no corridor to ride). Ride straight between the two
    // stage coords instead of crashing on a missing corridor.
    if (boardingCorridor == null || alightingCorridor == null) {
      return _buildDirectStageRide(
        origin,
        destinationCoord,
        destination.resolvedLabel,
        boardingStage,
        alightingStage,
      );
    }

    // "Avoid busy junctions": when the boarding corridor is a known busy
    // hotspot but the destination rides a quieter corridor within walking
    // reach of the origin, walk straight to the quieter corridor's nearest
    // stage instead of muscling into the busy junction — a real (if static)
    // re-route around the worst of Nairobi's corridor congestion.
    if (avoidBusyJunctions &&
        boardingStage.corridorId != alightingCorridor.id &&
        kBusyCorridorIds.contains(boardingStage.corridorId) &&
        !kBusyCorridorIds.contains(alightingCorridor.id)) {
      final bypass = _buildBusyCorridorBypass(
        origin,
        destinationCoord,
        destination.resolvedLabel,
        alightingStage,
        alightingCorridor,
      );
      if (bypass != null) return bypass;
    }

    final segments = <RouteSegment>[];

    // Segment 1: Walk from origin to boarding stage (skipped when already there).
    final walkToStage =
        _walkSegment('Walk to ${boardingStage.name}', origin, boardingCoord);
    if (walkToStage.distanceMeters >= 1.0) segments.add(walkToStage);

    // Segment 2: Matatu ride along corridor(s).
    if (boardingStage.corridorId == alightingStage.corridorId) {
      final matatuCoords =
          _getCorridorSlice(boardingCorridor, boardingCoord, alightingCoord);
      if (matatuCoords.length >= 2 && _pathLength(matatuCoords) >= 1.0) {
        final route = _getPrimaryRoute(boardingStage, alightingStage);
        segments.add(_matatuSegment(
          'Ride Route $route to ${alightingStage.name}',
          route,
          matatuCoords,
          boardingCoord,
          alightingCoord,
        ));
      }
    } else {
      segments.addAll(_buildMultiCorridorRoute(
        boardingStage,
        alightingStage,
        boardingCorridor,
        alightingCorridor,
      ));
    }

    // Segment 3: Walk from alighting stage to destination (skipped when the
    // destination sits exactly on the stage).
    final walkFromStage = _walkSegment(
        'Walk to ${destination.resolvedLabel}', alightingCoord, destinationCoord);
    if (walkFromStage.distanceMeters >= 1.0) segments.add(walkFromStage);

    // Nothing rideable left (e.g. boarding and alighting collapsed to a
    // zero-length ride) — fall back to a plain walk.
    if (segments.isEmpty) {
      return _walkOnlyRoute(origin, destinationCoord, destination.resolvedLabel);
    }

    return ActiveJourney(segments: segments);
  }

  /// Walk-only route used whenever origin and destination resolve to the same
  /// stage, or no rideable leg exists.
  static ActiveJourney _walkOnlyRoute(
      LatLng origin, LatLng destination, String destLabel) {
    return ActiveJourney(
      segments: [
        _walkSegment('Walk to $destLabel', origin, destination),
      ],
    );
  }

  /// Ride straight between an origin stage and an alighting stage when at least
  /// one of them has no assigned corridor (GTFS-only stop with no polyline to
  /// slice). Uses the direct great-circle line between the two stage coords.
  static ActiveJourney _buildDirectStageRide(
    LatLng origin,
    LatLng destinationCoord,
    String destLabel,
    StageData boardingStage,
    StageData alightingStage,
  ) {
    final segments = <RouteSegment>[];
    final boardingCoord = boardingStage.location;
    final alightingCoord = alightingStage.location;

    final walkToStage =
        _walkSegment('Walk to ${boardingStage.name}', origin, boardingCoord);
    if (walkToStage.distanceMeters >= 1.0) segments.add(walkToStage);

    final rideCoords = [boardingCoord, alightingCoord];
    if (rideCoords.length >= 2 && _pathLength(rideCoords) >= 1.0) {
      final route = _getPrimaryRoute(boardingStage, alightingStage);
      segments.add(_matatuSegment(
        'Ride Route $route to ${alightingStage.name}',
        route,
        rideCoords,
        boardingCoord,
        alightingCoord,
      ));
    }

    final walkFromStage = _walkSegment(
        'Walk to $destLabel', alightingCoord, destinationCoord);
    if (walkFromStage.distanceMeters >= 1.0) segments.add(walkFromStage);

    if (segments.isEmpty) {
      return _walkOnlyRoute(origin, destinationCoord, destLabel);
    }
    return ActiveJourney(segments: segments);
  }

  /// Re-routes a trip whose boarding corridor is a busy hotspot onto the
  /// quieter alighting corridor's nearest stage — by walking there first.
  /// Returns null when the bypass does not apply (quiet corridor too far,
  /// nothing rideable from the alternative stage, same corridor).
  static ActiveJourney? _buildBusyCorridorBypass(
    LatLng origin,
    LatLng destination,
    String destLabel,
    StageData alightingStage,
    CorridorData alightingCorridor,
  ) {
    if (kBusyCorridorIds.contains(alightingCorridor.id)) return null;

    final nearest = _findNearestStageOnCorridor(
        alightingCorridor.id, origin.latitude, origin.longitude);
    if (nearest == null) return null;

    final walkToAltDist = _haversineDistance(
        origin.latitude, origin.longitude, nearest.lat, nearest.lng);

    // Only worth it when the quieter corridor is genuinely close by.
    if (walkToAltDist > kBusyCorridorBypassWalkMeters) return null;

    final alightingCoord = alightingStage.location;
    final matatuCoords =
        _getCorridorSlice(alightingCorridor, nearest.location, alightingCoord);
    if (matatuCoords.length < 2 || _pathLength(matatuCoords) < 1.0) return null;

    final segments = <RouteSegment>[];

    final walkToAlt = _walkSegment('Walk to ${nearest.name}', origin, nearest.location);
    if (walkToAlt.distanceMeters >= 1.0) segments.add(walkToAlt);

    final route = _getPrimaryRoute(nearest, alightingStage);
    segments.add(_matatuSegment(
      'Ride Route $route to ${alightingStage.name}',
      route,
      matatuCoords,
      nearest.location,
      alightingCoord,
    ));

    final walkToDest =
        _walkSegment('Walk to $destLabel', alightingCoord, destination);
    if (walkToDest.distanceMeters >= 1.0) segments.add(walkToDest);

    return segments.isEmpty ? null : ActiveJourney(segments: segments);
  }

  static RouteSegment _walkSegment(String label, LatLng from, LatLng to) {
    final segment = RouteSegment.walk(
      label: label,
      coordinates: _createWalkPath(from, to),
      startPoint: from,
      endPoint: to,
    );
    return segment.copyWith(
        fareEstimate: FareCalculatorService.calculateFare(segment));
  }

  static RouteSegment _matatuSegment(
    String label,
    String routeNumber,
    List<LatLng> coordinates,
    LatLng from,
    LatLng to,
  ) {
    final segment = RouteSegment.matatu(
      label: label,
      coordinates: coordinates,
      routeNumber: routeNumber,
      startPoint: from,
      endPoint: to,
    );
    return segment.copyWith(
        fareEstimate: FareCalculatorService.calculateFare(segment));
  }

  /// Destination-side alighting resolution. An explicit stage pick wins unless
  /// it is the boarding stage itself; otherwise fall back to the boarding
  /// corridor's nearest stage, then any nearest stage.
  static StageData? _selectAlightingStage({
    required StageData boardingStage,
    StageData? declaredDestStage,
    required double destinationLat,
    required double destinationLng,
  }) {
    final declared = declaredDestStage;
    if (declared != null && declared.id != boardingStage.id) {
      return declared;
    }
    return _findNearestStageOnCorridor(
            boardingStage.corridorId, destinationLat, destinationLng) ??
        _findNearestStage(destinationLat, destinationLng);
  }

  static StageData? _findStageById(String name) {
    for (final stage in StageRegistry.all) {
      if (stage.name == name) return stage;
    }
    return null;
  }

  static CorridorData? _findCorridorById(String? corridorId) {
    if (corridorId == null) return null;
    for (final corridor in nairobiCorridors.values) {
      if (corridor.id == corridorId) return corridor;
    }
    return null;
  }

  static StageData? _findNearestStageOnCorridor(String corridorId, double lat, double lng) {
    final corridorStages = StageRegistry.all
        .where((s) => s.corridorId == corridorId && s.routeNumbers.isNotEmpty)
        .toList();
    if (corridorStages.isEmpty) return null;

    StageData? nearest;
    double minDistance = double.infinity;

    for (final stage in corridorStages) {
      final distance = _haversineDistance(lat, lng, stage.lat, stage.lng);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = stage;
      }
    }
    return nearest;
  }

  /// Nearest route-carrying stage to an arbitrary coordinate (any corridor).
  /// POI-only stages with no matatu routes are not valid boarding/alighting
  /// points and are skipped.
  static StageData? _findNearestStage(double lat, double lng) {
    StageData? nearest;
    double minDistance = double.infinity;
    for (final stage in StageRegistry.all) {
      if (stage.routeNumbers.isEmpty) continue;
      final distance = _haversineDistance(lat, lng, stage.lat, stage.lng);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = stage;
      }
    }
    return nearest;
  }

  static double _pathLength(List<LatLng> coordinates) {
    double total = 0;
    for (int i = 0; i < coordinates.length - 1; i++) {
      total += _haversineDistance(
        coordinates[i].latitude, coordinates[i].longitude,
        coordinates[i + 1].latitude, coordinates[i + 1].longitude,
      );
    }
    return total;
  }

  static List<LatLng> _createWalkPath(LatLng from, LatLng to) {
    // Simple direct path for walking - could be enhanced with OSRM walking profile
    return [from, to];
  }

  static List<LatLng> _getCorridorSlice(
    CorridorData corridor,
    LatLng from,
    LatLng to,
  ) {
    if (corridor.polyline.length < 2) return [from, to];

    // Find indices in polyline closest to from and to
    int fromIdx = 0, toIdx = corridor.polyline.length - 1;
    double minFromDist = double.infinity, minToDist = double.infinity;

    for (int i = 0; i < corridor.polyline.length; i++) {
      final fromDist = _haversineDistance(
        from.latitude, from.longitude,
        corridor.polyline[i].latitude, corridor.polyline[i].longitude,
      );
      if (fromDist < minFromDist) {
        minFromDist = fromDist;
        fromIdx = i;
      }

      final toDist = _haversineDistance(
        to.latitude, to.longitude,
        corridor.polyline[i].latitude, corridor.polyline[i].longitude,
      );
      if (toDist < minToDist) {
        minToDist = toDist;
        toIdx = i;
      }
    }

    // Ensure correct order
    if (fromIdx > toIdx) {
      final temp = fromIdx;
      fromIdx = toIdx;
      toIdx = temp;
    }

    // Return slice (including endpoints)
    final slice = corridor.polyline.sublist(fromIdx, toIdx + 1);
    return [from, ...slice, to];
  }

  static String _getPrimaryRoute(StageData from, StageData to) {
    final commonRoutes = from.routeNumbers.where((r) => to.routeNumbers.contains(r)).toList();
    return commonRoutes.isNotEmpty ? commonRoutes.first : (from.routeNumbers.isNotEmpty ? from.routeNumbers.first : 'N/A');
  }

  static List<RouteSegment> _buildMultiCorridorRoute(
    StageData boardingStage,
    StageData alightingStage,
    CorridorData boardingCorridor,
    CorridorData alightingCorridor,
  ) {
    final segments = <RouteSegment>[];

    // Ride first corridor to its end/transfer point
    final boardingCoord = boardingStage.location;
    final transferStage = _findTransferStage(boardingCorridor, alightingCorridor);
    if (transferStage == null) {
      // Fallback: direct ride to alighting stage if no transfer found
      final matatuCoords = _getCorridorSlice(boardingCorridor, boardingCoord, alightingStage.location);
      if (matatuCoords.length >= 2 && _pathLength(matatuCoords) >= 1.0) {
        final route = _getPrimaryRoute(boardingStage, alightingStage);
        segments.add(_matatuSegment(
          'Ride Route $route to ${alightingStage.name}',
          route,
          matatuCoords,
          boardingCoord,
          alightingStage.location,
        ));
      }
      return segments;
    }

    final transferCoord = transferStage.location;

    // Ride to transfer point
    final matatuCoords1 = _getCorridorSlice(boardingCorridor, boardingCoord, transferCoord);
    if (matatuCoords1.length >= 2 && _pathLength(matatuCoords1) >= 1.0) {
      final route = _getPrimaryRoute(boardingStage, transferStage);
      segments.add(_matatuSegment(
        'Ride Route $route to ${transferStage.name}',
        route,
        matatuCoords1,
        boardingCoord,
        transferCoord,
      ));
    }

    // Transfer walk segment
    final nextCorridorStage = _findNearestStageOnCorridor(
      alightingCorridor.id,
      transferCoord.latitude,
      transferCoord.longitude,
    );
    if (nextCorridorStage != null) {
      final transferDist = _haversineDistance(
        transferCoord.latitude, transferCoord.longitude,
        nextCorridorStage.lat, nextCorridorStage.lng,
      );

      if (transferDist > kTransferWalkThresholdMeters) {
        segments.add(_walkSegment(
          'Walk to ${nextCorridorStage.name}',
          transferCoord,
          nextCorridorStage.location,
        ));
      }

      // Ride second corridor
      final matatuCoords2 = _getCorridorSlice(
        alightingCorridor,
        nextCorridorStage.location,
        alightingStage.location,
      );
      if (matatuCoords2.length >= 2 && _pathLength(matatuCoords2) >= 1.0) {
        final route = _getPrimaryRoute(nextCorridorStage, alightingStage);
        segments.add(_matatuSegment(
          'Ride Route $route to ${alightingStage.name}',
          route,
          matatuCoords2,
          nextCorridorStage.location,
          alightingStage.location,
        ));
      }
    }

    return segments;
  }

  static StageData? _findTransferStage(CorridorData fromCorridor, CorridorData toCorridor) {
    // Find stages that serve both corridors or are very close
    for (final fromStage in StageRegistry.all.where((s) => s.corridorId == fromCorridor.id)) {
      for (final toStage in StageRegistry.all.where((s) => s.corridorId == toCorridor.id)) {
        final dist = _haversineDistance(
          fromStage.lat, fromStage.lng,
          toStage.lat, toStage.lng,
        );
        if (dist <= kTransferWalkThresholdMeters) {
          // Return the fromStage as transfer point
          return fromStage;
        }
      }
    }
    return null;
  }

  static double _haversineDistance(
    double lat1, double lng1, double lat2, double lng2,
  ) {
    const double R = 6371000;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLng / 2) * sin(dLng / 2);
    return 2 * atan2(sqrt(a), sqrt(1 - a)) * R;
  }
}