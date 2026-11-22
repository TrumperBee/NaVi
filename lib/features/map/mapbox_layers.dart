import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/models/transport_models.dart';
import 'mapbox_map_manager.dart';

/// Helper methods that apply map annotations through MapboxMapManager.
/// Each method takes the manager and annotation data, then calls the
/// appropriate Mapbox API to add/update annotations on the map.
class MapboxLayers {
  /// Fixed emerald departure disc. Never pass a live GPS coordinate here.
  static Future<void> addDepartureMarker(
    MapboxMapManager manager,
    LatLng point,
  ) {
    return manager.addDepartureMarker(point);
  }

  /// Red-outlined destination pin, with an optional preview label chip.
  static Future<void> addDestinationPin(
    MapboxMapManager manager,
    LatLng point, {
    String? label,
  }) {
    return manager.addDestinationPin(
      point,
      label: label ?? '',
    );
  }

  static Future<void> addDestinationMarker(
      MapboxMapManager manager, LatLng point) {
    return manager.addDestinationMarker(point);
  }

  static Future<void> addStageMarkers(
      MapboxMapManager manager, List<StageModel> stages) {
    return manager.addStageMarkers(stages);
  }

  static Future<void> addPlaceMarkers(
      MapboxMapManager manager, List<PlaceModel> places) {
    return manager.addPlaceMarkers(places);
  }

  static Future<void> setRoutePolylines(
    MapboxMapManager manager,
    List<LatLng> points, {
    List<LatLng>? traveledPoints,
    Color color = Colors.blue,
    double width = 5.0,
    Color? casingColor,
    double? casingWidth,
  }) {
    return manager.setRoutePolyline(
      points,
      traveledPoints: traveledPoints,
      color: color,
      width: width,
      casingColor: casingColor,
      casingWidth: casingWidth,
    );
  }

  static Future<void> addUserLocationCircle(
      MapboxMapManager manager, LatLng point) {
    return manager.addUserLocationCircle(point);
  }
}

class PositionData {
  final double latitude;
  final double longitude;

  const PositionData({
    required this.latitude,
    required this.longitude,
  });
}
