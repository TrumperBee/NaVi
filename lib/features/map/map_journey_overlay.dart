import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/core/constants.dart';
import 'package:navi_app/features/journey/models/journey_models.dart';
import 'package:navi_app/providers/journey_provider.dart';
import 'mapbox_map_manager.dart';

/// Applies journey-phase-specific markers and polylines to the map
/// via MapboxMapManager based on the current journey phase.
class JourneyMapLayers {
  static Future<void> applyToMap({
    required MapboxMapManager manager,
    required JourneyProvider journey,
    required LatLng? userLocation,
    required LatLng? destinationPoint,
    bool drawPaths = true,
  }) async {
    final fromLoc = journey.fromStageLocation;
    final toLoc = journey.toStageLocation;

    switch (journey.currentPhase) {
      case JourneyPhase.walkingToStage:
        if (fromLoc != null && userLocation != null && drawPaths) {
          await manager.addWalkingPath(userLocation, fromLoc);
        }
        if (fromLoc != null) {
          await manager.addBoardingMarker(fromLoc);
        }
        break;

      case JourneyPhase.waitingForMatatu:
        if (fromLoc != null) {
          await manager.addBoardingMarker(fromLoc);
        }
        break;

      case JourneyPhase.riding:
      case JourneyPhase.approachingDestination:
        if (fromLoc != null) {
          await manager.addBoardingMarker(fromLoc);
        }
        if (toLoc != null) {
          await manager.addAlightingMarker(toLoc);
        }
        if (fromLoc != null && toLoc != null && drawPaths) {
          await manager.addRidingPath([fromLoc, toLoc]);
        }
        break;

      case JourneyPhase.alighting:
        if (toLoc != null) {
          await manager.addAlightingMarker(toLoc);
        }
        if (toLoc != null && destinationPoint != null && drawPaths) {
          await manager.addWalkingPath(toLoc, destinationPoint);
        }
        break;

      case JourneyPhase.finalWalking:
        if (toLoc != null && destinationPoint != null && drawPaths) {
          await manager.addWalkingPath(toLoc, destinationPoint);
        }
        break;

      case JourneyPhase.journeyComplete:
      case JourneyPhase.beforeTravel:
        break;
    }
  }

  static Map<JourneyPhase, Color> get phaseColors => {
    JourneyPhase.beforeTravel: Colors.grey,
    JourneyPhase.walkingToStage: Colors.blue,
    JourneyPhase.waitingForMatatu: Colors.orange,
    JourneyPhase.riding: AppConstants.nairobiGreen,
    JourneyPhase.approachingDestination: Colors.red,
    JourneyPhase.alighting: Colors.redAccent,
    JourneyPhase.finalWalking: Colors.blue,
    JourneyPhase.journeyComplete: AppConstants.nairobiGreen,
  };
}
