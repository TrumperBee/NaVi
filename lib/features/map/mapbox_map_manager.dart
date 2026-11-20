import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'dart:math' show max;
import 'dart:ui' as ui;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/core/constants.dart';
import 'package:navi_app/design/navi_colors.dart';
import 'package:navi_app/design/navi_marker_theme.dart';
import 'package:navi_app/design/navi_typography.dart';
import 'package:navi_app/models/transport_models.dart';

/// Central manager for all Mapbox map annotations.
class MapboxMapManager {
  MapboxMap? _mapboxMap;
  MapboxMap? get mapboxMap => _mapboxMap;
  PointAnnotationManager? _pointManager;
  PolylineAnnotationManager? _polylineManager;
  CircleAnnotationManager? _circleManager;
  bool _ready = false;
  bool get isReady => _ready;

  /// True while Active Navigation owns the map. In this mode the home screen's
  /// stage/place markers and the legacy journey overlay are suppressed so the
  /// oversized green discs never cover the live blue route.
  bool _activeNavigation = false;

  /// Every annotation write is queued. GPS fixes and theme rebuilds used to
  /// interleave `deleteAll` / `createMulti`, and one empty list could erase a
  /// sibling's line. A generation counter additionally drops writes aimed at
  /// a map instance that has since been replaced.
  int _generation = 0;
  Future<void> _annotationTail = Future.value();

  /// The last line submitted by each owner. Active Navigation wins while it is
  /// on screen, so the home renderer cannot replace the live trimmed line.
  List<PolylineAnnotationOptions>? _lastPolylineOptions;
  List<PolylineAnnotationOptions>? _lastNavigationPolylineOptions;

  Future<void> onMapCreated(MapboxMap map) async {
    final generation = ++_generation;
    // Writes issued while the new native map is still initialising must wait;
    // once ready we replay the cached line instead of silently losing it.
    _ready = false;
    _mapboxMap = map;
    await _applyOrnamentSettings(map);
    if (generation != _generation) return;

    // Manager creation order is z-order: later managers draw on top. The route
    // line is created first so it sits above the map's own road layers but
    // BELOW the puck and any explicit markers.
    final polylineManager =
        await map.annotations.createPolylineAnnotationManager();
    final circleManager = await map.annotations.createCircleAnnotationManager();
    final pointManager = await map.annotations.createPointAnnotationManager();
    if (generation != _generation) return;

    _polylineManager = polylineManager;
    _circleManager = circleManager;
    _pointManager = pointManager;
    // Round caps and joins so every route leg (walk or ride, and the raw
    // fallback connector line) reads as a single continuous stroke rather than
    // separate segments meeting at hard, squared-off junctions.
    try {
      await _polylineManager?.setLineCap(LineCap.ROUND);
      await _polylineManager?.setLineJoin(LineJoin.ROUND);
    } catch (_) {}
    if (generation != _generation) return;

    _ready = true;
    await _reapplyCachedAnnotations(generation);
    if (_activeNavigation) await _configureNavigationLocation();
  }

  /// Runs annotation operations strictly in call order.
  Future<void> _enqueueAnnotations(Future<void> Function() action) async {
    final previous = _annotationTail;
    final completer = Completer<void>();
    _annotationTail = completer.future;
    await previous;
    try {
      await action();
    } catch (_) {
      // A single annotation failure must not poison later GPS updates.
    } finally {
      if (!completer.isCompleted) completer.complete();
    }
  }

  /// Re-applies annotations after a style load or map-instance swap. Mapbox
  /// drops annotation layers when the style changes, so this is the retry the
  /// home screen's `enableLocation()` style hook used to be missing.
  Future<void> _reapplyCachedAnnotations([int? generation]) async {
    final target = generation ?? _generation;
    if (!_ready || target != _generation) return;
    final line = _lastNavigationPolylineOptions ?? _lastPolylineOptions;
    if (line != null) {
      await setPolylineAnnotations(line,
          navigationLine: _lastNavigationPolylineOptions != null);
    }
    if (_activeNavigation) {
      await clearNavigationPoints();
    }
  }

  Future<void> setStyle(String styleUri) async {
    if (!_ready) return;
    try {
      await _mapboxMap?.loadStyleURI(styleUri);
    } catch (_) {}
  }

  /// Hides Mapbox's built-in ornaments that sit against the top of the map
  /// view, i.e. under the Android status bar on the edge-to-edge screens.
  ///
  /// Both are native views pinned to the map view's own corner (scale bar
  /// top-left, compass top-right), so they rendered behind the clock, signal,
  /// wifi and battery icons and made them unreadable. The app never shows a
  /// scale bar, and Active Navigation already ships its own compass button, so
  /// both built-ins are switched off here.
  ///
  /// The Mapbox logo and attribution button are deliberately left enabled -
  /// Mapbox's terms require them - and they stay in the bottom corners, clear
  /// of the status bar.
  ///
  /// Called from [onMapCreated] for every map instance: a theme switch
  /// recreates the MapWidget (new native map), so the settings have to be
  /// re-applied each time rather than once at startup.
  Future<void> _applyOrnamentSettings(MapboxMap map) async {
    try {
      await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    } catch (_) {}
    try {
      await map.compass.updateSettings(
        CompassSettings(enabled: false, visibility: false),
      );
    } catch (_) {}
  }

  /// Enables the live location puck.
  ///
  /// Must be called after the map style has loaded — Mapbox drops location
  /// settings when the style is not yet ready (see home_screen wiring via
  /// [MapWidget.onStyleLoadedListener]). Outside navigation this keeps the
  /// original signal-blue puck. During Active Navigation it swaps in the
  /// compact 20dp blue dot, white ring, translucent pulse and heading arrow.
  Future<void> enableLocation({bool followUser = true}) async {
    if (_mapboxMap == null) return;
    if (_activeNavigation) {
      await _configureNavigationLocation();
    } else {
      await _configureDefaultLocation();
    }
    // The style load that triggers this call also wipes annotation layers.
    await _reapplyCachedAnnotations();
  }

  /// Hands the map to Active Navigation. Home keeps owning the MapWidget, but
  /// from here on its green stage/place markers and legacy route strokes are
  /// ignored until [setActiveNavigationMode] is called with `false`.
  Future<void> setActiveNavigationMode(bool enabled) async {
    if (_activeNavigation == enabled) return;
    _activeNavigation = enabled;
    if (enabled) {
      await clearNavigationPoints();
      await _configureNavigationLocation();
      await _reapplyCachedAnnotations();
    } else {
      _lastNavigationPolylineOptions = null;
      await _configureDefaultLocation();
    }
  }

  bool get activeNavigationMode => _activeNavigation;

  Future<void> _configureDefaultLocation() async {
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

  /// Compact signal-blue puck used only while navigating: a 20dp dot with a
  /// 3dp white ring, a 20%-opacity blue pulse, and a heading arrow image that
  /// Mapbox rotates from the GPS course. The PNGs are rendered at 3x and the
  /// scale expression divides that back out so the puck stays ~20dp.
  Future<void> _configureNavigationLocation() async {
    if (_mapboxMap == null) return;
    try {
      final dot = await _navigationPuckImage(isArrow: false);
      final arrow = await _navigationPuckImage(isArrow: true);
      if (dot == null || arrow == null) return;
      const pixelRatio = 3.0;
      final scale = (1.0 / pixelRatio).toString();
      final scaleExpression =
          '["interpolate",["linear"],["zoom"],0,$scale,24,$scale]';

      await _mapboxMap!.location.updateSettings(LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingColor: NaviColors.signalBlue.withValues(alpha: 0.2).toARGB32(),
        pulsingMaxRadius: 18.0,
        showAccuracyRing: false,
        puckBearingEnabled: true,
        puckBearing: PuckBearing.HEADING,
        locationPuck: LocationPuck(
          locationPuck2D: LocationPuck2D(
            topImage: dot,
            bearingImage: arrow,
            scaleExpression: scaleExpression,
          ),
        ),
      ));
    } catch (_) {}
  }

  Future<Uint8List?> _navigationPuckImage({required bool isArrow}) async {
    const size = 20.0;
    const pixelRatio = 3.0;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(pixelRatio);
      const center = Offset(size / 2, size / 2);

      if (isArrow) {
        final path = ui.Path()
          ..moveTo(center.dx, 1.5)
          ..lineTo(size - 1.5, size - 2.5)
          ..lineTo(center.dx, size - 5.5)
          ..lineTo(1.5, size - 2.5)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeJoin = ui.StrokeJoin.round,
        );
        canvas.drawPath(path, Paint()..color = NaviColors.signalBlue);
      } else {
        canvas.drawCircle(
          center,
          8.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        canvas.drawCircle(center, 7, Paint()..color = NaviColors.signalBlue);
      }

      final image = await recorder.endRecording().toImage(
            (size * pixelRatio).round(),
            (size * pixelRatio).round(),
          );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Removes every point/circle annotation without touching the active route
  /// line. Used when entering navigation so pre-trip green dots cannot linger.
  Future<void> clearNavigationPoints() => _enqueueAnnotations(() async {
        if (!_ready) return;
        await _pointManager?.deleteAll();
        await _circleManager?.deleteAll();
      });

  Future<void> clearAll() => _enqueueAnnotations(() async {
        if (!_ready) return;
        await _pointManager?.deleteAll();
        await _circleManager?.deleteAll();
        // Home calls this on every position-driven rebuild. During navigation
        // the line is renderer-owned, so only clear it on an explicit
        // `setPolylineAnnotations([])` from the journey view model.
        if (!_activeNavigation) await _polylineManager?.deleteAll();
      });

  Future<void> clearPoints() => _enqueueAnnotations(() async {
        if (!_ready) return;
        await _pointManager?.deleteAll();
      });

  Future<void> addStartDot(LatLng point) async {
    if (!_ready || _activeNavigation) return;
    try {
      final icon = await _createMarkerImage(
        color: AppConstants.nairobiGreen,
        icon: Icons.circle,
        size: 28,
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

  /// The blue "you are here" dot used by the Route Preview.
  Future<void> addPreviewUserDot(LatLng point) async {
    if (!_ready || _activeNavigation) return;
    try {
      final icon = await _createMarkerImage(
        color: NaviColors.signalBlue,
        icon: Icons.circle,
        size: 20,
        displayScale: 3.0,
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

  /// A coloured pin with a white label chip baked above it, used by the Route
  /// Preview for the boarding stage (emerald) and the destination (red).
  ///
  /// The annotation is bottom-anchored so the pin's tip — not the chip — sits
  /// exactly on [point].
  Future<void> addLabeledPin(
    LatLng point, {
    required Color color,
    required String label,
  }) async {
    if (!_ready || _activeNavigation) return;
    try {
      final icon = await _createLabeledMarkerImage(color: color, label: label);
      if (icon == null) return;
      await _pointManager?.createMulti([
        PointAnnotationOptions(
          geometry: _pointToJson(point),
          iconSize: 1.0,
          iconImage: icon,
          iconAnchor: IconAnchor.BOTTOM,
        ),
      ]);
    } catch (_) {}
  }

  Future<void> addDestinationMarker(LatLng point) async {
    if (!_ready || _activeNavigation) return;
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
    if (!_ready || _activeNavigation || stages.isEmpty) return;
    try {
      final icon = await _createMarkerImage(
        color: AppConstants.nairobiGreen,
        icon: Icons.directions_bus,
        size: 36,
      );
      if (icon == null) return;
      final options = stages
          .map((s) => PointAnnotationOptions(
                geometry: _pointToJson(s.location),
                iconSize: 1.0,
                iconImage: icon,
              ))
          .toList();
      await _pointManager?.createMulti(options);
    } catch (_) {}
  }

  Future<void> addPlaceMarkers(List<PlaceModel> places) async {
    if (!_ready || _activeNavigation || places.isEmpty) return;
    try {
      final icon = await _createMarkerImage(
        color: Colors.blue,
        icon: Icons.place,
        size: 32,
      );
      if (icon == null) return;
      final options = places
          .map((p) => PointAnnotationOptions(
                geometry: _pointToJson(p.location),
                iconSize: 1.0,
                iconImage: icon,
              ))
          .toList();
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
    if (!_ready || _activeNavigation || points.length < 2) return;
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

  /// Replaces the route line atomically. `navigationLine` marks writes from
  /// the live journey view model; while navigation is active those take
  /// precedence over the home renderer's preview/live writes.
  Future<void> setPolylineAnnotations(
    List<PolylineAnnotationOptions> options, {
    bool navigationLine = false,
  }) async {
    final cached = List<PolylineAnnotationOptions>.unmodifiable(options);
    if (navigationLine) {
      _lastNavigationPolylineOptions = cached;
    } else {
      _lastPolylineOptions = cached;
    }
    if (_activeNavigation && !navigationLine) return;

    final generation = _generation;
    await _enqueueAnnotations(() async {
      if (!_ready || generation != _generation) return;
      await _polylineManager?.deleteAll();
      if (generation != _generation) return;
      if (cached.isEmpty) return;
      await _polylineManager?.createMulti(cached);
    });
  }

  Future<void> addUserLocationCircle(LatLng point) async {
    if (!_ready || _activeNavigation) return;
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
    if (!_ready || _activeNavigation) return;
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
    if (!_ready || _activeNavigation) return;
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
    if (!_ready || _activeNavigation) return;
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
    if (!_ready || _activeNavigation || points.length < 2) return;
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
    // Home's pre-trip fly is ignored once navigation owns the camera; the view
    // model's route-ahead framing is the single source of live camera motion.
    if (_activeNavigation) return;
    await _mapboxMap?.flyTo(
      CameraOptions(
        center: Point.fromJson(_pointToMap(center)),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: 1000, startDelay: 0),
    );
  }

  /// Linear camera chase used outside navigation. During navigation the view
  /// model calls [followJourney] instead so the route ahead stays in frame.
  Future<void> easeToCenter(LatLng center,
      {double zoom = 15, int durationMs = 500}) async {
    if (_activeNavigation) return;
    await _mapboxMap?.easeTo(
      CameraOptions(
        center: Point.fromJson(_pointToMap(center)),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: durationMs, startDelay: 0),
    );
  }

  /// Zoom cap for the on-foot camera — close enough for the next turn.
  static const double navigationWalkZoom = 16.2;

  /// Zoom cap for a matatu leg — slightly wider to read as a corridor.
  static const double navigationRideZoom = 15.0;

  /// Bottom-heavy inset: the puck sits in the lower third and the next 300 m
  /// of route fits in the freed upper part of the viewport.
  static MbxEdgeInsets navigationPadding(Size size) => MbxEdgeInsets(
        top: size.height * 0.10,
        left: 40,
        right: 40,
        bottom: size.height * 0.58,
      );

  /// Zoom cap for the active mode. Ride legs are deliberately wider.
  static double navigationZoom({required bool riding}) =>
      riding ? navigationRideZoom : navigationWalkZoom;

  /// Every live camera move is north-up and flat.
  static CameraOptions navigationBaseCameraOptions() =>
      CameraOptions(bearing: 0, pitch: 0);

  /// Frames the traveller and the next stretch of route with a bottom-heavy
  /// inset, which puts the blue dot in the lower third and leaves the road
  /// ahead visible. Bearing is pinned to north; the matatu cap is slightly
  /// wider so a ride reads as a corridor rather than a close-up street.
  Future<void> followJourney(
    LatLng user, {
    required List<LatLng> ahead,
    bool riding = false,
    int durationMs = 450,
  }) async {
    if (!_activeNavigation || !_ready || _mapboxMap == null) return;
    final map = _mapboxMap!;
    final points = <LatLng>[user, ...ahead];
    try {
      final size = await map.getSize();
      final camera = await map.cameraForCoordinatesPadding(
        [for (final p in points) _pointToJson(p)],
        navigationBaseCameraOptions(),
        navigationPadding(size),
        navigationZoom(riding: riding),
        null,
      );
      await map.easeTo(
        CameraOptions(
          center: camera.center,
          zoom: camera.zoom,
          bearing: 0,
          pitch: 0,
        ),
        MapAnimationOptions(duration: durationMs, startDelay: 0),
      );
    } catch (_) {
      // If bounds framing is unavailable, keep the user centred and north-up.
      try {
        await map.easeTo(
          CameraOptions(
            center: _pointToJson(user),
            zoom: navigationZoom(riding: riding),
            bearing: 0,
            pitch: 0,
          ),
          MapAnimationOptions(duration: durationMs, startDelay: 0),
        );
      } catch (_) {}
    }
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
      'coordinates': points.map((p) => [p.longitude, p.latitude]).toList(),
    };
  }

  Point _pointToJson(LatLng point) => Point.fromJson(_pointToMap(point));

  LineString _lineStringToJson(List<LatLng> points) =>
      LineString.fromJson(_lineStringToMap(points));

  Future<String?> _createMarkerImage({
    required Color color,
    required IconData icon,
    double size = 36,
    double displayScale = 1.0,
  }) async {
    final key = 'marker_${color.toARGB32()}_${icon.codePoint}_'
        '${size.toInt()}_${displayScale.toInt()}';
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
        displayScale,
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

  /// Bakes a 32dp pin + label chip into one Mapbox style image. The chip is
  /// centred above the pin with a small tail pointing at it; the annotation is
  /// bottom-anchored so the pin's tip — not the chip — sits on [point].
  ///
  /// The PNG is rendered at 3x for crisp text but registered at the same 3x
  /// scale, so Mapbox displays it at logical dp/sp sizes (registering it at
  /// 1.0 previously made every label and pin three times too large).
  Future<String?> _createLabeledMarkerImage({
    required Color color,
    required String label,
  }) async {
    final key = 'preview_pin_${color.toARGB32()}_${label.hashCode}_'
        '${NaviMarkerTheme.isDark}';
    try {
      const pixelRatio = 3.0;
      const chipFontSize = NaviMarkerTheme.chipFontSize;
      const chipHPad = NaviMarkerTheme.chipHorizontalPadding;
      const chipVPad = NaviMarkerTheme.chipVerticalPadding;
      const chipMaxWidth = NaviMarkerTheme.chipMaxWidth;
      const pinHeight = NaviMarkerTheme.pinHeight;
      const pinWidth = NaviMarkerTheme.pinWidth;
      const tailHeight = NaviMarkerTheme.chipTailHeight;
      const gap = NaviMarkerTheme.chipGap;

      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: NaviType.uiFontFamily,
            fontSize: chipFontSize,
            fontWeight: FontWeight.w600,
            color: NaviMarkerTheme.chipText,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: chipMaxWidth - chipHPad * 2);

      final chipWidth = painter.width + chipHPad * 2;
      final chipHeight = painter.height + chipVPad * 2;
      final width = max(chipWidth, pinWidth + 2);
      final height = chipHeight + tailHeight + gap + pinHeight;
      final centerX = width / 2;
      final pinTop = chipHeight + tailHeight + gap;
      final pinTip = pinTop + pinHeight;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(pixelRatio);

      final chipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH((width - chipWidth) / 2, 0, chipWidth, chipHeight),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        chipRect,
        Paint()..color = NaviMarkerTheme.chipBackground,
      );
      canvas.drawRRect(
        chipRect,
        Paint()
          ..color = NaviMarkerTheme.chipBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
      painter.paint(
        canvas,
        Offset((width - chipWidth) / 2 + chipHPad, chipVPad),
      );

      // Small tail from the chip straight down to the pin.
      final tail = ui.Path()
        ..moveTo(centerX - 4, chipHeight - 0.5)
        ..lineTo(centerX + 4, chipHeight - 0.5)
        ..lineTo(centerX, chipHeight + tailHeight)
        ..close();
      canvas.drawPath(tail, Paint()..color = NaviMarkerTheme.chipBackground);

      // A real pin silhouette (rounded head, pointed tip), not a plain circle.
      final pin = ui.Path()
        ..moveTo(centerX, pinTop)
        ..cubicTo(
          centerX + pinWidth * 0.56,
          pinTop + pinHeight * 0.06,
          centerX + pinWidth * 0.5,
          pinTop + pinHeight * 0.56,
          centerX,
          pinTip,
        )
        ..cubicTo(
          centerX - pinWidth * 0.5,
          pinTop + pinHeight * 0.56,
          centerX - pinWidth * 0.56,
          pinTop + pinHeight * 0.06,
          centerX,
          pinTop,
        )
        ..close();
      canvas.drawPath(pin, Paint()..color = color);
      canvas.drawPath(
        pin,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(
        (width * pixelRatio).round(),
        (height * pixelRatio).round(),
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      await _mapboxMap?.style.addStyleImage(
        key,
        pixelRatio,
        MbxImage(
          width: (width * pixelRatio).round(),
          height: (height * pixelRatio).round(),
          data: byteData.buffer.asUint8List(),
        ),
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
