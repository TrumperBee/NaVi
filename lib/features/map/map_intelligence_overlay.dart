import 'package:flutter/material.dart';
import 'package:navi_app/data/databases/stage_database.dart';
import 'package:navi_app/models/stage_record.dart';
import 'package:navi_app/services/reporting/report_service.dart';

class MapIntelligenceOverlay extends StatelessWidget {
  final double centerLatitude;
  final double centerLongitude;
  final double zoomLevel;
  final bool showHeatmap;
  final bool showPopularStages;
  final bool showTrafficOverlay;
  final bool showIncidents;

  const MapIntelligenceOverlay({
    super.key,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.zoomLevel,
    this.showHeatmap = true,
    this.showPopularStages = true,
    this.showTrafficOverlay = true,
    this.showIncidents = true,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Widget>>(
      future: _buildOverlays(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        return Stack(
          children: snapshot.data!,
        );
      },
    );
  }

  Future<List<Widget>> _buildOverlays() async {
    final overlays = <Widget>[];

    if (showPopularStages) {
      overlays.add(_PopularStagesOverlay(
        centerLat: centerLatitude,
        centerLng: centerLongitude,
      ));
    }

    if (showIncidents) {
      overlays.add(_IncidentMarkersOverlay(
        centerLat: centerLatitude,
        centerLng: centerLongitude,
      ));
    }

    return overlays;
  }
}

class _PopularStagesOverlay extends StatelessWidget {
  final double centerLat;
  final double centerLng;

  const _PopularStagesOverlay({
    required this.centerLat,
    required this.centerLng,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StageRecord>>(
      future: StageDatabase().getPopularStages(limit: 10),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _IncidentMarkersOverlay extends StatelessWidget {
  final double centerLat;
  final double centerLng;

  const _IncidentMarkersOverlay({
    required this.centerLat,
    required this.centerLng,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class TrafficHeatmapPainter extends CustomPainter {
  final List<HeatmapPoint> points;

  TrafficHeatmapPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    for (final point in points) {
      final paint = Paint()
        ..color = point.color.withValues(alpha: point.intensity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

      canvas.drawCircle(
        Offset(point.x, point.y),
        point.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TrafficHeatmapPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class HeatmapPoint {
  final double x;
  final double y;
  final double radius;
  final Color color;
  final double intensity;

  HeatmapPoint({
    required this.x,
    required this.y,
    this.radius = 30,
    this.color = Colors.orange,
    this.intensity = 0.5,
  });
}

class TrafficConfidenceIndicator extends StatelessWidget {
  final double confidence;
  final String label;

  const TrafficConfidenceIndicator({
    super.key,
    required this.confidence,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final color = confidence > 0.7
        ? Colors.green
        : confidence > 0.4
            ? Colors.orange
            : Colors.red;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 4),
        Text(
          '$label (${(confidence * 100).toInt()}%)',
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class CongestionOverlayPainter extends CustomPainter {
  final Map<String, double> congestionLevels;

  CongestionOverlayPainter({required this.congestionLevels});

  @override
  void paint(Canvas canvas, Size size) {
    // Render corridor congestion as colored polylines
  }

  @override
  bool shouldRepaint(covariant CongestionOverlayPainter oldDelegate) {
    return oldDelegate.congestionLevels != congestionLevels;
  }
}

class MapIntelligenceController {
  final StageDatabase _stageDb = StageDatabase();
  final ReportService _reportService = ReportService();

  Future<List<StageIntelligence>> getStageIntelligence({
    required double centerLat,
    required double centerLng,
    required double radiusKm,
  }) async {
    final stages = await _stageDb.findNearbyStages(
      latitude: centerLat,
      longitude: centerLng,
      radiusMeters: radiusKm * 1000,
    );

    final intelligence = <StageIntelligence>[];
    for (final stage in stages) {
      final reportCount = _reportService.getReportsNearby(
        stage.latitude, stage.longitude,
        radiusKm: 0.5,
      ).length;

      intelligence.add(StageIntelligence(
        stage: stage,
        popularityScore: stage.popularityScore,
        activeReports: reportCount,
        confidenceLevel: reportCount > 0 ? 0.6 : 0.8,
      ));
    }

    return intelligence;
  }
}

class StageIntelligence {
  final StageRecord stage;
  final double popularityScore;
  final int activeReports;
  final double confidenceLevel;

  StageIntelligence({
    required this.stage,
    required this.popularityScore,
    this.activeReports = 0,
    this.confidenceLevel = 0.5,
  });
}
