import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/core/constants.dart';
import 'package:navi_app/design/navi_colors.dart';
import 'package:navi_app/models/transport_models.dart';

/// Central manager for all Mapbox map annotations.
class MapboxMapManager {
  MapboxMap? _mapboxMap;
  MapboxMap? get mapboxMap => _mapboxMap;
  PointAnnotationManager? _pointManager;
  PolylineAnnotationManager? _polylineManager;
  CircleAnnotationManager? _circleManager;
  bool _ready = false;

  Future<void> onMapCreated(MapboxMap map) async {
    _mapboxMap = map;
    _pointManager = await map.annotations.createPointAnnotationManager();
    _polylineManager = await map.annotations.createPolylineAnnotationManager();
    _circleManager = await map.annotations.createCircleAnnotationManager();
    // Round caps and joins so every route leg (walk dashes, matatu ride, raw
    // OSRM line) reads as a single continuous stroke rather than separate
    // segments meeting at hard, squared-off junctions.
    try {
      await _polylineManager?.setLineCap(LineCap.ROUND);
      await _polylineManager?.setLineJoin(LineJoin.ROUND);
    } catch (_) {}
    _ready = true;
  }

  Future<void> setStyle(String styleUri) async {
    if (!_ready) return;
    try {
      await _mapboxMap?.loadStyleURI(styleUri);
    } catch (_) {}
  }

  /// Enables the live location puck.
  ///
  /// Must be called after the map style has loaded — Mapbox drops location
  /// settings when the style is not yet ready (see home_screen wiring via
  /// [MapWidget.onStyleLoadedListener]). The puck is 2D, pulses in signal blue
  /// (the reserved GPS accent) and carries an accuracy ring and heading-bearing.
  Future<void> enableLocation({bool followUser = true}) async {
    if (_mapboxMap == null) return;
    try {
      await _mapboxMap!.location.updateSettings(LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingColor: NaviColors.signalBlue.toARGB32(),
        pulsingMaxRadius: 2.0,
        showAccuracyRing: true,
        accuracyRingColor: NaviColors.signalBlue.toARGB32(),
        accuracyRingBorderColor: Colors.white.toARGB32(),
        puckBearingEnabled: true,
        puckBearing: PuckBearing.HEADING,
      ));
    } catch (_) {}
  }

  Future<void> clearAll() async {
    if (!_ready) return;
    await _pointManager?.deleteAll();
    await _polylineManager?.deleteAll();
    await _circleManager?.deleteAll();
  }

  Future<void> addDestinationMarker(LatLng point) async {
    if (!_ready) return;
    try {
      final icon = await _createMarkerImage(
        color: Colors.red,
        icon: Icons.location_on,
        size: 40,
      );
      if (icon == null) return;
      await _pointManager?.createMulti([
        PointAnnotationOptions(
          geometry: _pointToJson(point),
          iconSize: 1.0,
          iconImage: icon,
        ),
      ]);
    } catch (_) {}
  }

  Future<void> addStageMarkers(List<StageModel> stages) async {
    if (!_ready || stages.isEmpty) return;
    try {
      final icon = await _createMarkerImage(
        color: AppConstants.nairobiGreen,
        icon: Icons.directions_bus,
        size: 36,
      );
      if (icon == null) return;
      final options = stages.map((s) => PointAnnotationOptions(
        geometry: _pointToJson(s.location),
        iconSize: 1.0,
        iconImage: icon,
      )).toList();
      await _pointManager?.createMulti(options);
    } catch (_) {}
  }

  Future<void> addPlaceMarkers(List<PlaceModel> places) async {
    if (!_ready || places.isEmpty) return;
    try {
      final icon = await _createMarkerImage(
        color: Colors.blue,
        icon: Icons.place,
        size: 32,
      );
      if (icon == null) return;
      final options = places.map((p) => PointAnnotationOptions(
        geometry: _pointToJson(p.location),
        iconSize: 1.0,
        iconImage: icon,
      )).toList();
      await _pointManager?.createMulti(options);
    } catch (_) {}
  }

  Future<void> setRoutePolyline(
    List<LatLng> points, {
    List<LatLng>? traveledPoints,
    Color color = Colors.blue,
    double width = 5.0,
    double opacity = 0.8,
  }) async {
    if (!_ready || points.length < 2) return;
    await _polylineManager?.deleteAll();
    try {
      final options = <PolylineAnnotationOptions>[];
      if (traveledPoints != null && traveledPoints.length >= 2) {
        options.add(PolylineAnnotationOptions(
          lineColor: Colors.grey.toARGB32(),
          lineWidth: width,
          lineOpacity: 0.5,
          geometry: _lineStringToJson(traveledPoints),
        ));
      }
      options.add(PolylineAnnotationOptions(
        lineColor: color.withValues(alpha: opacity).toARGB32(),
        lineWidth: width,
        lineOpacity: opacity,
        geometry: _lineStringToJson(points),
      ));
      await _polylineManager?.createMulti(options);
    } catch (_) {}
  }

  Future<void> setPolylineAnnotations(List<PolylineAnnotationOptions> options) async {
    if (!_ready) return;
    await _polylineManager?.deleteAll();
    if (options.isEmpty) return;
    try {
      await _polylineManager?.createMulti(options);
    } catch (_) {}
  }

  Future<void> addUserLocationCircle(LatLng point) async {
    if (!_ready) return;
    await _circleManager?.deleteAll();
    try {
      final fill = Colors.blue.withValues(alpha: 0.2);
      await _circleManager?.createMulti([
        CircleAnnotationOptions(
          circleColor: fill.toARGB32(),
          circleRadius: 30,
          circleStrokeWidth: 3,
          circleStrokeColor: Colors.blue.toARGB32(),
          geometry: _pointToJson(point),
        ),
      ]);
    } catch (_) {}
  }

  Future<void> addBoardingMarker(LatLng point) async {
    if (!_ready) return;
    try {
      final icon = await _createMarkerImage(
        color: AppConstants.nairobiGreen,
        icon: Icons.directions_bus,
        size: 36,
      );
      if (icon == null) return;
      await _pointManager?.createMulti([
        PointAnnotationOptions(
          geometry: _pointToJson(point),
          iconSize: 1.0,
          iconImage: icon,
        ),
      ]);
    } catch (_) {}
  }

  Future<void> addAlightingMarker(LatLng point) async {
    if (!_ready) return;
    try {
      final icon = await _createMarkerImage(
        color: Colors.red,
        icon: Icons.flag,
        size: 36,
      );
      if (icon == null) return;
      await _pointManager?.createMulti([
        PointAnnotationOptions(
          geometry: _pointToJson(point),
          iconSize: 1.0,
          iconImage: icon,
        ),
      ]);
    } catch (_) {}
  }

  Future<void> addWalkingPath(LatLng from, LatLng to) async {
    if (!_ready) return;
    try {
      final lineColor = Colors.blue.withValues(alpha: 0.6);
      await _polylineManager?.createMulti([
        PolylineAnnotationOptions(
          lineColor: lineColor.toARGB32(),
          lineWidth: 4,
          lineOpacity: 0.6,
          geometry: _lineStringToJson([from, to]),
        ),
      ]);
    } catch (_) {}
  }

  Future<void> addRidingPath(List<LatLng> points) async {
    if (!_ready || points.length < 2) return;
    try {
      final lineColor = AppConstants.nairobiGreen.withValues(alpha: 0.8);
      await _polylineManager?.createMulti([
        PolylineAnnotationOptions(
          lineColor: lineColor.toARGB32(),
          lineWidth: 6,
          lineOpacity: 0.8,
          geometry: _lineStringToJson(points),
        ),
      ]);
    } catch (_) {}
  }

  Future<void> flyTo(LatLng center, {double zoom = 15}) async {
    await _mapboxMap?.flyTo(
      CameraOptions(
        center: Point.fromJson(_pointToMap(center)),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: 1000, startDelay: 0),
    );
  }

  Map<String, dynamic> _pointToMap(LatLng point) {
    return {
      'type': 'Point',
      'coordinates': [point.longitude, point.latitude],
    };
  }

  Map<String, dynamic> _lineStringToMap(List<LatLng> points) {
    return {
      'type': 'LineString',
      'coordinates': points
          .map((p) => [p.longitude, p.latitude])
          .toList(),
    };
  }

  Point _pointToJson(LatLng point) => Point.fromJson(_pointToMap(point));

  LineString _lineStringToJson(List<LatLng> points) =>
      LineString.fromJson(_lineStringToMap(points));

  Future<String?> _createMarkerImage({
    required Color color,
    required IconData icon,
    double size = 36,
  }) async {
    final key = 'marker_${color.toARGB32()}_${icon.codePoint}_${size.toInt()}';
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final pixelRatio = 3.0;
      final w = (size * pixelRatio).toInt();
      final h = (size * pixelRatio).toInt();

      canvas.scale(pixelRatio);

      final bgPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 1, bgPaint);

      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 2, borderPaint);

      final picture = recorder.endRecording();
      final img = await picture.toImage(w, h);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final bytes = byteData.buffer.asUint8List();

      await _mapboxMap?.style.addStyleImage(
        key,
        1.0,
        MbxImage(width: w, height: h, data: bytes),
        false,
        [],
        [],
        null,
      );
      return key;
    } catch (_) {
      return null;
    }
  }
}
