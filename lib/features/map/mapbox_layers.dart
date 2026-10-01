import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/models/transport_models.dart';
import 'mapbox_map_manager.dart';

/// Helper methods that apply map annotations through MapboxMapManager.
/// Each method takes the manager and annotation data, then calls the
/// appropriate Mapbox API to add/update annotations on the map.
class MapboxLayers {
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
  }) {
    return manager.setRoutePolyline(
      points,
      traveledPoints: traveledPoints,
      color: color,
      width: width,
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
